import SwiftUI
import PhotosUI
import UIKit

enum RecordEntryMode: String, CaseIterable, Identifiable {
    case manual = "手动录入"
    case ocr = "账单识别"

    var id: String { rawValue }
}

fileprivate enum RecordDraftIntent {
    case automatic
    case note
    case category
}

final class RecordTabSession: ObservableObject {
    @Published var selectedEntryMode: RecordEntryMode = .manual
    @Published var scenePackExpanded = false
    @Published var scenePackVariants: [String: Int] = [:]
    @Published var amountPadActive = false
    @Published var categoryGridExpanded = false
    @Published var noteEditorExpanded = false
    @Published var datePanelExpanded = false
    @Published var previewLineWasRotated = false
    @Published var activeScenePack: ScenePackDefinition?
    @Published var didAutoFocusAmountPad = false
    @Published fileprivate var lastDraftIntent: RecordDraftIntent = .automatic
    @Published var userNoteAnchorTitle: String?
    @Published var ocrQuotaUpsellVisibleThisSession = false
    @Published var suppressNextNoteSemanticUnlock = false

    func resetAfterCommittedDraft() {
        selectedEntryMode = .manual
        scenePackExpanded = false
        scenePackVariants = [:]
        amountPadActive = false
        categoryGridExpanded = false
        noteEditorExpanded = false
        datePanelExpanded = false
        previewLineWasRotated = false
        activeScenePack = nil
        didAutoFocusAmountPad = false
        lastDraftIntent = .automatic
        userNoteAnchorTitle = nil
        ocrQuotaUpsellVisibleThisSession = false
        suppressNextNoteSemanticUnlock = false
    }
}

struct RecordView: View {
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var tabSession: RecordTabSession
    var onSaved: ((LifeMarkSceneRewardPrompt?) -> Void)? = nil
    var onShowMemberPricing: ((MemberPricingEntryContext) -> Void)? = nil
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isOCRRecognizing = false
    @State private var ocrProgress = 0.0
    @State private var ocrConfirmDrafts: [OCRReceiptDraft] = []
    @State private var showOCRConfirmSheet = false
    @State private var didImportOCRConfirmSheet = false
    @State private var ocrDraftStageDismissed = false
    @State private var showScenePackAngleSheet = false
    @State private var opensMemberPricingAfterScenePackDismiss = false
    @State private var recommendedCategoryRefreshTask: Task<Void, Never>?
    @State private var preparedPreviewLifeMarkKey: RecordPreviewLifeMarkKey?
    @State private var previewLifeMarkTextSnapshot: String?
    @State private var scenePackFeedback: String?
    @State private var freeScenePackRefreshToken = 0
    @State private var freeLockedSceneHint: ScenePackAngleSheet.LockedSceneHint?
    @AppStorage("scene_pack_order_v1") private var scenePackOrderStorage = ""
    @AppStorage("scene_pack_manual_order_v1") private var scenePackManualOrderEnabled = false
    @AppStorage("scene_pack_more_expanded_v1") private var scenePackMoreExpanded = false
    @AppStorage("scene_pack_usage_v1") private var scenePackUsageStorage = ""
    @AppStorage("scene_pack_pinned_v1") private var scenePackPinnedStorage = ""
    @AppStorage("ocr_import_member_upsell_last_shown_at") private var ocrImportMemberUpsellLastShownAt = 0.0
    @FocusState private var focusedField: RecordField?

    private enum RecordField {
        case amount
        case note
    }

    private enum ScenePackNoteRelation: Equatable {
        case aligned
        case related
        case conflict
    }

    private enum NoteRewriteDecision {
        case categoryCopy(anchorTitle: String?)
        case scenePackCopy(ScenePackDefinition, anchorTitle: String?)
    }

    private let draftClock = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    private let recordAccent = AppColors.accent
    private let recordInk = AppColors.text
    private let freeScenePackService = FreeScenePackService.shared
    private let lifeMarkSceneRewardService = LifeMarkSceneRewardService.shared
    private let dailyQuotaStore = DailyFeatureQuotaStore()
    private let extensionScenePackIds: Set<String> = ["travel", "family"]
    private let scenePackSilenceInterval: TimeInterval = 7 * 24 * 60 * 60
    private let ocrImportUpsellCooldown: TimeInterval = 3 * 24 * 60 * 60

    private var selectedEntryMode: RecordEntryMode {
        get { tabSession.selectedEntryMode }
        nonmutating set { tabSession.selectedEntryMode = newValue }
    }

    private var scenePackExpanded: Bool {
        get { tabSession.scenePackExpanded }
        nonmutating set { tabSession.scenePackExpanded = newValue }
    }

    private var scenePackVariants: [String: Int] {
        get { tabSession.scenePackVariants }
        nonmutating set { tabSession.scenePackVariants = newValue }
    }

    private var amountPadActive: Bool {
        get { tabSession.amountPadActive }
        nonmutating set { tabSession.amountPadActive = newValue }
    }

    private var categoryGridExpanded: Bool {
        get { tabSession.categoryGridExpanded }
        nonmutating set { tabSession.categoryGridExpanded = newValue }
    }

    private var noteEditorExpanded: Bool {
        get { tabSession.noteEditorExpanded }
        nonmutating set { tabSession.noteEditorExpanded = newValue }
    }

    private var datePanelExpanded: Bool {
        get { tabSession.datePanelExpanded }
        nonmutating set { tabSession.datePanelExpanded = newValue }
    }

    private var previewLineWasRotated: Bool {
        get { tabSession.previewLineWasRotated }
        nonmutating set { tabSession.previewLineWasRotated = newValue }
    }

    private var activeScenePack: ScenePackDefinition? {
        get { tabSession.activeScenePack }
        nonmutating set { tabSession.activeScenePack = newValue }
    }

    private var didAutoFocusAmountPad: Bool {
        get { tabSession.didAutoFocusAmountPad }
        nonmutating set { tabSession.didAutoFocusAmountPad = newValue }
    }

    private var lastDraftIntent: RecordDraftIntent {
        get { tabSession.lastDraftIntent }
        nonmutating set { tabSession.lastDraftIntent = newValue }
    }

    private var userNoteAnchorTitle: String? {
        get { tabSession.userNoteAnchorTitle }
        nonmutating set { tabSession.userNoteAnchorTitle = newValue }
    }

    private var ocrQuotaUpsellVisibleThisSession: Bool {
        get { tabSession.ocrQuotaUpsellVisibleThisSession }
        nonmutating set { tabSession.ocrQuotaUpsellVisibleThisSession = newValue }
    }

    private var suppressNextNoteSemanticUnlock: Bool {
        get { tabSession.suppressNextNoteSemanticUnlock }
        nonmutating set { tabSession.suppressNextNoteSemanticUnlock = newValue }
    }

    private struct ScenePackUsageStat {
        var count: Int
        var lastUsedAt: TimeInterval
    }

    private var visibleScenePacks: [ScenePackDefinition] {
        let orderIds = scenePackOrderIds
        return ScenePackCopyPool.definitions.sorted { lhs, rhs in
            if scenePackManualOrderEnabled {
                return scenePackManualSortRank(lhs, orderIds: orderIds) < scenePackManualSortRank(rhs, orderIds: orderIds)
            }
            return scenePackUsageSortRank(lhs) < scenePackUsageSortRank(rhs)
        }
    }

    private var primaryScenePacks: [ScenePackDefinition] {
        return visibleScenePacks.filter { pack in
            !shouldFoldScenePack(pack)
        }
    }

    private var secondaryScenePacks: [ScenePackDefinition] {
        return visibleScenePacks.filter { pack in
            shouldFoldScenePack(pack)
        }
    }

    private var freeScenePacks: [ScenePackDefinition] {
        _ = freeScenePackRefreshToken
        return freeScenePackService.orderedFreePacks(from: visibleScenePacks)
    }

    private var pendingLifeMarkSceneReward: LifeMarkSceneReward? {
        _ = freeScenePackRefreshToken
        return lifeMarkSceneRewardService.pendingReward(from: visibleScenePacks)
    }

    private var activeLifeMarkSceneReward: LifeMarkSceneReward? {
        _ = freeScenePackRefreshToken
        return lifeMarkSceneRewardService.activeReward(from: visibleScenePacks)
    }

    private var activeLifeMarkRewardPack: ScenePackDefinition? {
        guard let reward = activeLifeMarkSceneReward else { return nil }
        return visibleScenePacks.first { $0.id == reward.packId }
    }

    private var freeScenePacksForUse: [ScenePackDefinition] {
        var packs = freeScenePacks
        if let activePack = activeLifeMarkRewardPack,
           !packs.contains(where: { $0.id == activePack.id }) {
            packs.insert(activePack, at: 0)
        }
        return packs
    }

    private var freeMoreScenePacks: [ScenePackDefinition] {
        var freeIds = Set(freeScenePacks.map(\.id))
        if let activePack = activeLifeMarkRewardPack {
            freeIds.insert(activePack.id)
        }
        return visibleScenePacks.filter { !freeIds.contains($0.id) }
    }

    private var freeReplaceableScenePacks: [ScenePackDefinition] {
        _ = freeScenePackRefreshToken
        return freeScenePackService.replaceableCandidates(from: visibleScenePacks)
    }

    private var freeScenePackIds: Set<String> {
        Set(freeScenePacksForUse.map(\.id))
    }

    private var implicitScenePacksForCurrentAccess: [ScenePackDefinition] {
        isMember ? visibleScenePacks : freeScenePacksForUse
    }

    private var shouldShowOCRQuotaUpsell: Bool {
        guard isOCRQuotaExhausted else { return false }
        if ocrQuotaUpsellVisibleThisSession { return true }
        return Date().timeIntervalSince1970 >= ocrImportMemberUpsellLastShownAt + ocrImportUpsellCooldown
    }

    private var isOCRQuotaExhausted: Bool {
        !isMember && dailyQuotaStore.ocrRemaining(isMember: false) == 0
    }

    private var freeScenePackLimitText: String? {
        guard !isMember, freeScenePackService.isInFirstWeek() else { return nil }
        let days = freeScenePackService.daysUntilExtensionLock()
        return days <= 1
            ? "出去玩、娃和毛孩等扩展角度今天后会锁定"
            : "出去玩、娃和毛孩等扩展角度还有 \(days) 天锁定"
    }

    private var scenePackOrderIds: [String] {
        scenePackOrderStorage
            .split(separator: ",")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private func scenePackManualSortRank(_ pack: ScenePackDefinition, orderIds: [String]) -> Int {
        if let index = orderIds.firstIndex(of: pack.id) {
            return index
        }
        let defaultIndex = ScenePackCopyPool.definitions.firstIndex { $0.id == pack.id } ?? 999
        return 1_000 + defaultIndex
    }

    private func scenePackUsageSortRank(_ pack: ScenePackDefinition) -> Int {
        let defaultIndex = ScenePackCopyPool.definitions.firstIndex { $0.id == pack.id } ?? 999
        guard let stat = scenePackUsageStats[pack.id] else {
            return 200_000 + defaultIndex
        }
        let usageGroup = isScenePackInSilence(stat) ? 1 : 0
        return usageGroup * 100_000 - min(stat.count, 999) * 100 + defaultIndex
    }

    private func reorderScenePacks(orderedPackIds: [String], movedPackIds: Set<String>) {
        guard !orderedPackIds.isEmpty else { return }
        let orderedSet = Set(orderedPackIds)
        var orderedIterator = orderedPackIds.makeIterator()
        let allVisibleIds = visibleScenePacks.map(\.id)
        let reorderedIds = allVisibleIds.map { id in
            orderedSet.contains(id) ? (orderedIterator.next() ?? id) : id
        }
        scenePackManualOrderEnabled = true
        scenePackOrderStorage = reorderedIds.prefix(12).joined(separator: ",")

        let movedExtensionIds = movedPackIds.intersection(extensionScenePackIds)
        guard !movedExtensionIds.isEmpty else { return }
        let movedOrderedIds = orderedPackIds.filter { movedExtensionIds.contains($0) }
        var pinnedIds = scenePackPinnedIds.filter { !movedExtensionIds.contains($0) }
        pinnedIds.insert(contentsOf: movedOrderedIds, at: 0)
        scenePackPinnedStorage = pinnedIds.prefix(12).joined(separator: ",")
    }

    private func shouldFoldScenePack(_ pack: ScenePackDefinition) -> Bool {
        guard !scenePackManualOrderEnabled else { return false }
        if scenePackPinnedIds.contains(pack.id) { return false }
        guard let stat = scenePackUsageStats[pack.id] else {
            return extensionScenePackIds.contains(pack.id)
        }
        return isScenePackInSilence(stat)
    }

    private func isScenePackInSilence(_ stat: ScenePackUsageStat) -> Bool {
        guard stat.lastUsedAt > 0 else { return true }
        let lastUsed = Date(timeIntervalSince1970: stat.lastUsedAt)
        return Date().timeIntervalSince(lastUsed) > scenePackSilenceInterval
    }

    private var scenePackPinnedIds: [String] {
        scenePackPinnedStorage
            .split(separator: ",")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private var scenePackUsageStats: [String: ScenePackUsageStat] {
        scenePackUsageStorage
            .split(separator: ";")
            .reduce(into: [String: ScenePackUsageStat]()) { result, chunk in
                let parts = chunk.split(separator: "|")
                guard parts.count == 3,
                      let count = Int(parts[1]),
                      let lastUsedAt = TimeInterval(String(parts[2])) else { return }
                result[String(parts[0])] = ScenePackUsageStat(count: count, lastUsedAt: lastUsedAt)
            }
    }

    private func markScenePackUsed(_ pack: ScenePackDefinition) {
        var stats = scenePackUsageStats
        let current = stats[pack.id] ?? ScenePackUsageStat(count: 0, lastUsedAt: 0)
        stats[pack.id] = ScenePackUsageStat(
            count: current.count + 1,
            lastUsedAt: Date().timeIntervalSince1970
        )
        scenePackUsageStorage = stats
            .sorted { $0.key < $1.key }
            .map { "\($0.key)|\($0.value.count)|\(Int($0.value.lastUsedAt))" }
            .joined(separator: ";")
    }

    private var isMember: Bool {
        settingsViewModel.settings.hasMemberAccess
    }

    private func guessScenePackId() -> String {
        let amount = inputAmountValue
        let isLateNight = Calendar.current.component(.hour, from: homeViewModel.selectedDate) < 6
        if isLateNight, homeViewModel.selectedCategory == .dining {
            return availableScenePackId("food")
        }
        if isLateNight,
           homeViewModel.selectedCategory == .other,
           amount <= 45,
           !hasTravelContextForCurrentRecord {
            return availableScenePackId("food")
        }
        if homeViewModel.selectedCategory == .other {
            if hasTravelContextForCurrentRecord {
                return availableScenePackId("travel")
            }
            if amount <= 45 { return availableScenePackId("food") }
            if amount <= 120 { return availableScenePackId("supply", fallback: "home") }
            return availableScenePackId("home")
        }

        if homeViewModel.selectedCategory == .entertainment {
            if hasTravelContextForCurrentRecord {
                return availableScenePackId("travel")
            }
            return amount <= 80 ? availableScenePackId("food") : availableScenePackId("social", fallback: "supply")
        }

        let note = homeViewModel.inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if containsPetKeyword(note) || containsBabyKeyword(note) {
            return availableScenePackId("family", fallback: "supply")
        }

        let categoryToPackId: [HomeItem.Category: String] = [
            .dining: "food",
            .transport: "commute",
            .shopping: "shopping",
            .daily: "supply",
            .lodging: "travel",
            .health: "care",
            .home: "home",
            .social: "social",
        ]
        if let packId = categoryToPackId[homeViewModel.selectedCategory],
           visibleScenePacks.contains(where: { $0.id == packId }) {
            return packId
        }

        if amount <= 15 { return "commute" }
        if amount <= 45 { return "food" }
        if amount <= 120 { return "supply" }
        return "home"
    }

    private func availableScenePackId(_ preferred: String, fallback: String = "food") -> String {
        if visibleScenePacks.contains(where: { $0.id == preferred }) {
            return preferred
        }
        return fallback
    }

    private func canUseScenePackForCurrentAccess(_ pack: ScenePackDefinition) -> Bool {
        isMember || freeScenePacksForUse.contains { $0.id == pack.id }
    }

    private var hasTravelContextForCurrentRecord: Bool {
        let note = homeViewModel.inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return containsTravelKeyword(note)
    }

    private func containsTravelKeyword(_ text: String) -> Bool {
        let keywords = ["旅行", "旅途", "景区", "景点", "行程", "酒店", "民宿", "住宿", "机票", "高铁", "机场", "返程", "摆渡"]
        return keywords.contains { text.contains($0) }
    }

    private func prepareFreeLockedSceneHintIfNeeded() {
        guard !isMember, hasValidAmount, !freeScenePackService.isInFirstWeek() else {
            freeLockedSceneHint = nil
            return
        }
        guard let pack = lockedScenePackForCurrentRecord(),
              freeScenePackService.canShowLockedSceneHint(for: pack.id) else {
            freeLockedSceneHint = nil
            return
        }
        freeLockedSceneHint = ScenePackAngleSheet.LockedSceneHint(
            pack: pack,
            title: lockedSceneHintTitle(for: pack),
            detail: lockedSceneHintDetail(for: pack)
        )
        freeScenePackService.recordLockedSceneHintShown(for: pack.id)
    }

    private func lockedScenePackForCurrentRecord() -> ScenePackDefinition? {
        let text = homeViewModel.inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetId: String?
        if containsPetKeyword(text) || containsBabyKeyword(text) {
            targetId = "family"
        } else if containsFitnessKeyword(text) {
            targetId = "care"
        } else if homeViewModel.selectedCategory == .lodging || containsTravelKeyword(text) {
            targetId = "travel"
        } else {
            targetId = nil
        }
        guard let targetId,
              !freeScenePackIds.contains(targetId),
              let pack = visibleScenePacks.first(where: { $0.id == targetId }),
              freeScenePackService.isExtensionLockedPack(pack) else { return nil }
        return pack
    }

    private func containsPetKeyword(_ text: String) -> Bool {
        let petName = settingsViewModel.petNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return SemanticBoundaryGuard.matchesPetSupply(text, petName: petName)
    }

    private func containsBabyKeyword(_ text: String) -> Bool {
        SemanticBoundaryGuard.matchesBabySupply(text)
    }

    private func containsFitnessKeyword(_ text: String) -> Bool {
        let keywords = ["运动", "健身", "锻炼", "训练", "跑步", "瑜伽", "游泳", "球场", "私教", "护具", "运动鞋", "运动服", "健身卡", "健身房"]
        return keywords.contains { text.contains($0) }
    }

    private func containsTelecomBillKeyword(_ text: String) -> Bool {
        containsAny(text, ["话费", "话费券", "话费充值", "手机话费", "手机充值", "通讯费", "通信费", "中国移动", "中国移动通信集团", "中国联通", "中国电信", "移动通信", "运营商缴费", "telecom_bill"])
    }

    private func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private func lockedSceneHintTitle(for pack: ScenePackDefinition) -> String {
        switch pack.id {
        case "travel":
            return "更像出去玩订酒店买票"
        case "family":
            return "更像娃和毛孩的补给站"
        case "care":
            return "更像看病买药健身恢复"
        default:
            return "可以换个生活角度"
        }
    }

    private func lockedSceneHintDetail(for pack: ScenePackDefinition) -> String {
        switch pack.id {
        case "travel":
            return "会员可直接换到出去玩这一包，把路费、住宿和门票放回同一段行程里。"
        case "family":
            return "会员可直接换到娃和毛孩这一包，奶粉尿不湿、宠物粮猫砂和宠物洗护就医都能放回照护场景。"
        case "care":
            return "会员可直接换到身体相关角度，区分健身房、运动装备、理疗和恢复。"
        default:
            return "会员可打开全部生活角度，不只停在 3 个常用包。"
        }
    }

    private func applyScenePack(
        _ pack: ScenePackDefinition,
        keepSelectedCategory: Bool = false,
        trackMemberSceneUsage: Bool = true
    ) {
        dismissKeyboard()
        let shouldPreserveUserNote = shouldPreserveUserNoteWhenChangingAngle
        if !shouldPreserveUserNote {
            lastDraftIntent = .category
        }
        if trackMemberSceneUsage {
            markScenePackUsed(pack)
        }
        let amount = Double(homeViewModel.inputAmount.replacingOccurrences(of: ",", with: "")) ?? 0
        let categoryContext = keepSelectedCategory ? homeViewModel.selectedCategory : pack.category
        let variantKey = scenePackVariantKey(
            pack: pack,
            amount: amount,
            category: categoryContext,
            date: homeViewModel.selectedDate
        )
        let variant = scenePackVariants[variantKey, default: 0]
        scenePackVariants[variantKey] = variant + 1
        let title = ScenePackCopyPool.note(
            for: pack,
            amount: amount,
            date: homeViewModel.selectedDate,
            categoryContext: categoryContext,
            petName: settingsViewModel.petNickname,
            historyItems: homeViewModel.items,
            allowPetCopy: settingsViewModel.petCompanionEnabled,
            variant: variant,
            allowTravelSpecificCopy: !keepSelectedCategory || containsTravelKeyword(homeViewModel.inputTitle),
            factText: homeViewModel.inputTitle
        )
        if !keepSelectedCategory {
            activeScenePack = pack
            if shouldPreserveUserNote {
                rememberUserNoteAnchor(homeViewModel.inputTitle)
                homeViewModel.applyScenePackCategory(pack.category)
            } else {
                userNoteAnchorTitle = nil
                homeViewModel.applyScenePackDraft(title: title, category: pack.category)
            }
        } else {
            if shouldPreserveUserNote {
                rememberUserNoteAnchor(homeViewModel.inputTitle)
                activeScenePack = pack
                homeViewModel.applyScenePackCategory(pack.category)
            } else {
                userNoteAnchorTitle = nil
                activeScenePack = nil
                homeViewModel.inputTitle = title
            }
        }
        if !keepSelectedCategory {
            showScenePackAppliedFeedback(pack)
        }
    }

    private var shouldPreserveUserNoteWhenChangingAngle: Bool {
        let title = homeViewModel.inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        return lastDraftIntent == .note || noteHasSpecificSemantics(title)
    }

    private func rememberUserNoteAnchor(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        userNoteAnchorTitle = trimmed.isEmpty ? nil : trimmed
    }

    private func manualNoteOverrideCategory(_ title: String) -> HomeItem.Category? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !homeViewModel.categoryLockedByUser else { return nil }
        guard let category = RecordSemanticLexicon.strongManualNoteCategory(of: trimmed),
              category != homeViewModel.selectedCategory else {
            return nil
        }
        return category
    }

    private func scenePackVariantKey(
        pack: ScenePackDefinition,
        amount: Double,
        category: HomeItem.Category,
        date: Date
    ) -> String {
        let day = Calendar.current.startOfDay(for: date).timeIntervalSince1970
        let hour = Calendar.current.component(.hour, from: date)
        let amountBucket = Int((amount * 100).rounded())
        return "\(pack.id)|\(category.rawValue)|\(amountBucket)|\(Int(day))|\(hour)"
    }

    private func scenePackDesc(_ pack: ScenePackDefinition) -> String {
        ScenePackCopyPool.renderPetName(pack.desc, petName: settingsViewModel.petNickname)
    }

    private func scenePackReason(_ pack: ScenePackDefinition) -> String {
        let hour = Calendar.current.component(.hour, from: homeViewModel.selectedDate)
        if pack.category == homeViewModel.selectedCategory {
            if pack.id == "food", hour >= 22 || hour < 6 {
                return "深夜 · \(pack.category.label)"
            }
            return "当前分类"
        }
        if pack.id == "travel", hasTravelContextForCurrentRecord {
            return "旅途线索"
        }
        if scenePackUsageStats[pack.id] != nil {
            return "常用靠前"
        }
        return pack.category.label
    }

    private var hasValidAmount: Bool {
        guard let v = Double(homeViewModel.inputAmount.replacingOccurrences(of: ",", with: "")) else { return false }
        return v > 0
    }

    private var inputAmountValue: Double {
        Double(homeViewModel.inputAmount.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    private var previewBrand: MerchantBrandDefinition? {
        let title = homeViewModel.inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if let brand = MerchantBrandCatalog.matchBrand(in: title) {
            return brand
        }
        if let title = compatiblePrefillTitle {
            return MerchantBrandCatalog.matchBrand(in: title)
        }
        return nil
    }

    private var prefillResultMatchesSelectedCategory: Bool {
        guard let result = homeViewModel.recordPrefillResult else { return false }
        return result.category == nil || result.category == homeViewModel.selectedCategory
    }

    private var compatiblePrefillTitle: String? {
        if noteEditorExpanded,
           homeViewModel.inputTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
        }
        guard let result = homeViewModel.recordPrefillResult,
              prefillResultMatchesSelectedCategory,
              let title = homeViewModel.recordPrefillResult?.title?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty,
              RecordSemanticLexicon.canDisplayPrefillTitle(
                title,
                category: homeViewModel.selectedCategory,
                source: result.source
              ) else {
            return nil
        }
        return title
    }

    private var inputTitleCompatibleWithSelectedCategory: Bool {
        let title = homeViewModel.inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        return RecordSemanticLexicon.isTitle(title, compatibleWith: homeViewModel.selectedCategory)
    }

    private var hasPreviewNote: Bool {
        inputTitleCompatibleWithSelectedCategory
            || (lastDraftIntent == .note && !homeViewModel.inputTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            || compatiblePrefillTitle != nil
    }

    private var noteWasExplicitlyCleared: Bool {
        noteEditorExpanded
            && homeViewModel.inputTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasExplicitCopyIntent: Bool {
        !noteWasExplicitlyCleared
            && (homeViewModel.categoryLockedByUser || previewLineWasRotated || activeScenePack != nil)
    }

    private var shouldUseNeutralRemarkFallback: Bool {
        homeViewModel.inputTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && compatiblePrefillTitle == nil
            && !hasExplicitCopyIntent
    }

    private var previewTitleIsExplicitUserEdit: Bool {
        let title = homeViewModel.inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty,
              inputTitleCompatibleWithSelectedCategory || lastDraftIntent == .note else { return false }
        if title == homeViewModel.recordPrefillResult?.title?.trimmingCharacters(in: .whitespacesAndNewlines) {
            return false
        }
        return noteEditorExpanded || homeViewModel.categoryLockedByUser
    }

    private var categoryLockedForCurrentIntent: Bool {
        homeViewModel.categoryLockedByUser
    }

    private var activeScenePackIdForCurrentRecord: String? {
        guard let activeScenePack,
              activeScenePack.category == homeViewModel.selectedCategory else { return nil }
        return activeScenePack.id
    }

    private var previewHeadline: String {
        let title = homeViewModel.inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty, inputTitleCompatibleWithSelectedCategory || lastDraftIntent == .note { return title }
        if shouldUseNeutralRemarkFallback {
            return RecordSemanticLexicon.emptyNoteTitle
        }
        if let prefillTitle = compatiblePrefillTitle {
            return prefillTitle
        }
        return previewFallbackTitle(for: homeViewModel.selectedCategory)
    }

    private var previewDraftResolution: RecordDraftResolution? {
        guard !shouldUseNeutralRemarkFallback else { return nil }
        let title = homeViewModel.inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let draftTitle = title.isEmpty ? previewHeadline : title
        return RecordDraftResolutionService.resolve(
            RecordDraftResolutionInput(
                rawTitle: draftTitle,
                fallbackCategory: homeViewModel.selectedCategory,
                amount: inputAmountValue,
                date: homeViewModel.selectedDate,
                merchantBrandId: previewBrand?.id,
                categoryLockedByUser: categoryLockedForCurrentIntent,
                userEditedTitle: previewTitleIsExplicitUserEdit,
                source: "preview",
                scenePackId: activeScenePackIdForCurrentRecord
            )
        )
    }

    private var previewEmotion: String {
        if shouldUseNeutralRemarkFallback {
            return ""
        }
        guard let resolution = previewDraftResolution else { return "" }
        return previewEmotionTag(for: resolution)
    }

    private var previewLifeMarkText: String? {
        guard let key = previewLifeMarkPreparationKey,
              preparedPreviewLifeMarkKey == key else {
            return nil
        }
        return previewLifeMarkTextSnapshot
    }

    private var previewLifeMarkPreparationKey: RecordPreviewLifeMarkKey? {
        guard previewTier == .confirm, hasValidAmount, focusedField != .note else { return nil }
        let category = previewDraftResolution?.category ?? homeViewModel.selectedCategory
        let rawTitle = homeViewModel.inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = previewSemanticTitle(rawTitle.isEmpty ? previewHeadline : rawTitle)
        return RecordPreviewLifeMarkKey(
            ledgerRevision: homeViewModel.recordInputAssistanceRevision,
            title: title,
            amount: inputAmountValue,
            category: category,
            createdAt: homeViewModel.selectedDate,
            emotionTag: previewEmotion,
            merchantBrandID: previewBrand?.id,
            scenePackID: activeScenePackIdForCurrentRecord,
            isMember: isMember
        )
    }

    private func preparePreviewLifeMark(for key: RecordPreviewLifeMarkKey?) async {
        guard let key else { return }
        guard preparedPreviewLifeMarkKey != key else { return }
        let draft = HomeItem(
            title: key.title,
            amount: key.amount,
            category: key.category,
            createdAt: key.createdAt,
            emotionTag: key.emotionTag,
            merchantBrandId: key.merchantBrandID,
            scenePackId: key.scenePackID
        )
        let input = RecordPreviewLifeMarkPreparationInput(
            key: key,
            draft: draft,
            allItems: homeViewModel.items + [draft],
            isMember: key.isMember
        )
        let text = await withTaskGroup(
            of: String?.self,
            returning: String?.self
        ) { group in
            group.addTask(priority: .utility) {
                guard !Task.isCancelled else { return nil }
                return RecordInputAssistanceComputation.previewLifeMarkText(input)
            }
            return await group.next() ?? nil
        }
        guard !Task.isCancelled,
              previewLifeMarkPreparationKey == key else {
            return
        }
        preparedPreviewLifeMarkKey = key
        previewLifeMarkTextSnapshot = text
    }

    private var previewLearningHint: String? {
        let currentTitle = homeViewModel.inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if let anchor = previewSemanticAnchorTitle,
           noteHasSpecificSemantics(anchor) {
            return nil
        }
        if noteHasSpecificSemantics(currentTitle) {
            return nil
        }
        return homeViewModel.recordLearningHint
    }

    private var previewSemanticAnchorTitle: String? {
        let current = homeViewModel.inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let anchor = userNoteAnchorTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !anchor.isEmpty, anchor != current else { return nil }
        guard noteHasSpecificSemantics(anchor) else { return nil }
        return anchor
    }

    private func previewSemanticTitle(_ title: String) -> String {
        guard let anchor = previewSemanticAnchorTitle else { return title }
        return "\(title) \(anchor)"
    }

    private func previewEmotionTag(for resolution: RecordDraftResolution) -> String {
        guard let anchor = previewSemanticAnchorTitle else { return resolution.emotionTag }
        let resolved = NarrativeCopyResolver.resolveEmotionTag(
            context: NarrativeCopyResolver.Context(
                brandId: resolution.merchantBrandId,
                category: resolution.category,
                amount: inputAmountValue,
                date: homeViewModel.selectedDate,
                seed: "\(resolution.title)|\(anchor)",
                note: "\(resolution.title) \(anchor)",
                scenePackId: activeScenePackIdForCurrentRecord
            )
        )
        return RecordSemanticLexicon.isTitle(resolved, compatibleWith: resolution.category)
            ? resolved
            : resolution.emotionTag
    }

    private func noteHasSpecificSemantics(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return !RecordSemanticLexicon.matchingCategories(in: trimmed).isEmpty
            || !RecordSemanticLexicon.matchingEmotionRuleIDs(in: trimmed).isEmpty
    }

    private func markOCRQuotaUpsellShown() {
        ocrQuotaUpsellVisibleThisSession = true
        let now = Date().timeIntervalSince1970
        if now >= ocrImportMemberUpsellLastShownAt + ocrImportUpsellCooldown {
            ocrImportMemberUpsellLastShownAt = now
        }
    }

    private func dismissOCRQuotaUpsell() {
        ocrQuotaUpsellVisibleThisSession = false
        ocrImportMemberUpsellLastShownAt = Date().timeIntervalSince1970
    }

    private var previewMeta: String {
        let displayCategory = previewDraftResolution?.category ?? homeViewModel.selectedCategory
        if let activeScenePack,
           activeScenePack.category == displayCategory,
           !homeViewModel.inputTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(activeScenePack.emoji) \(activeScenePack.label) · \(homeViewModel.selectedDate.zhBillDateTime)"
        }
        return "\(displayCategory.displayName) · \(homeViewModel.selectedDate.zhBillDateTime)"
    }

    private var previewTier: RecordPreviewTier {
        RecordPreviewTier.resolve(
            .init(
                amount: inputAmountValue,
                itemsCount: homeViewModel.items.count,
                hasBrand: !shouldUseNeutralRemarkFallback && !homeViewModel.categoryLockedByUser && (previewBrand != nil || homeViewModel.recordPrefillResult?.source == "brand"),
                hasNote: hasPreviewNote,
                previewLineWasRotated: previewLineWasRotated,
                isEditing: false,
                prefillSource: shouldUseNeutralRemarkFallback ? nil : homeViewModel.recordPrefillResult?.source,
                prefillConfidence: shouldUseNeutralRemarkFallback ? nil : homeViewModel.recordPrefillResult?.confidence
            )
        )
    }

    private var previewCardMeta: String {
        switch previewTier {
        case .hidden:
            return ""
        case .whisper:
            return homeViewModel.selectedDate.zhBillDateTime
        case .confirm:
            return previewMeta
        }
    }

    private var previewHint: String? {
        guard previewTier == .confirm else { return nil }
        return currentTitleShouldBeUserEdited ? "会像这样留在账本里" : "分类不对？点下方「改分类」即可"
    }

    private var currentTitleShouldBeUserEdited: Bool {
        guard noteEditorExpanded else { return false }
        let title = homeViewModel.inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        if title == homeViewModel.recordPrefillResult?.title?.trimmingCharacters(in: .whitespacesAndNewlines) {
            return false
        }
        return lastDraftIntent == .note
    }

    private var previewQuickActionTitle: String {
        if !shouldUseNeutralRemarkFallback,
           previewBrand != nil || homeViewModel.recordPrefillResult?.source == "brand" {
            return "换说法"
        }
        return previewTier == .confirm ? "换一句" : "帮我写一句"
    }

    private var hasAmountDraft: Bool {
        !homeViewModel.inputAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasUncommittedManualDraft: Bool {
        hasAmountDraft
            || !homeViewModel.inputTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || homeViewModel.categoryLockedByUser
            || homeViewModel.selectedDateEditedByUser
            || activeScenePack != nil
    }

    private var shouldShowAmountQuickKeys: Bool {
        selectedEntryMode == .manual && amountPadActive
    }

    private var recordContentBottomPadding: CGFloat {
        if focusedField == .note {
            return 520
        }
        return amountPadActive ? 430 : 120
    }

    private func dismissKeyboard() {
        amountPadActive = false
        focusedField = nil
    }

    private func focusAmountPad(delay: Double = 0.18) {
        guard selectedEntryMode == .manual else { return }
        focusedField = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard selectedEntryMode == .manual else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                amountPadActive = true
            }
        }
    }

    private func scrollNoteFieldIntoView(_ proxy: ScrollViewProxy) {
        scrollNoteFieldIntoView(proxy, delay: 0.18)
        scrollNoteFieldIntoView(proxy, delay: 0.42)
    }

    private func scrollNoteFieldIntoView(_ proxy: ScrollViewProxy, delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard focusedField == .note else { return }
            withAnimation(.easeInOut(duration: 0.24)) {
                proxy.scrollTo("recordNoteField", anchor: .center)
            }
        }
    }

    private func openNoteEditor() {
        dismissKeyboard()
        withAnimation(.easeInOut(duration: 0.2)) {
            noteEditorExpanded = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            focusedField = .note
        }
    }

    private func saveManualRecord() {
        guard hasValidAmount else { return }
        dismissKeyboard()
        let didSave = homeViewModel.addManualRecord(
            userEditedTitle: currentTitleShouldBeUserEdited,
            preserveEmptyTitle: shouldUseNeutralRemarkFallback,
            categoryLockedForSave: categoryLockedForCurrentIntent,
            scenePackId: activeScenePackIdForCurrentRecord
        )
        guard didSave else {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.84)) {
                noteEditorExpanded = true
            }
            return
        }
        tabSession.resetAfterCommittedDraft()
        let savedItem = homeViewModel.items.first
        onSaved?(nil)
        if let savedItem {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                guard let rewardPrompt = prepareLifeMarkSceneRewardPromptIfNeeded(
                    for: savedItem,
                    refreshScenePackState: false
                ) else {
                    return
                }
                onSaved?(rewardPrompt)
            }
        }
    }

    private func prepareLifeMarkSceneRewardPromptIfNeeded(
        for item: HomeItem,
        refreshScenePackState: Bool = true
    ) -> LifeMarkSceneRewardPrompt? {
        guard !isMember else { return nil }
        if let reward = lifeMarkSceneRewardService.registerRewardIfNeeded(
            for: item,
            allItems: homeViewModel.items,
            currentPackIds: Set(freeScenePacks.map(\.id)),
            definitions: visibleScenePacks,
            isMember: isMember
        ) {
            if refreshScenePackState {
                freeScenePackRefreshToken += 1
            }
            return LifeMarkSceneRewardPrompt(
                id: reward.id,
                title: "新的生活线索诞生",
                badge: "奖励一次免费体验",
                detail: reward.detail,
                primaryTitle: "立即体验",
                secondaryTitle: "稍后再说",
                kind: .reward(reward)
            )
        }

        guard lifeMarkSceneRewardService.shouldShowColdStartGuide(
            after: item,
            allItems: homeViewModel.items,
            isMember: isMember
        ) else { return nil }
        return LifeMarkSceneRewardPrompt(
            id: "cold_start_scene_pack_guide",
            title: "新的生活线索诞生",
            badge: "先选 3 个常用场景包",
            detail: "这条记录已经长成生活线索了。可以先把最常用的 3 个场景包选好，之后记账会更贴近你的日常。",
            primaryTitle: "去看看",
            secondaryTitle: "知道了",
            kind: .coldStart
        )
    }

    private func previewFallbackTitle(for category: HomeItem.Category) -> String {
        RecordSemanticLexicon.fallbackTitle(
            for: category,
            amount: inputAmountValue,
            date: homeViewModel.selectedDate
        )
    }

    private func baseScenePack(for category: HomeItem.Category) -> ScenePackDefinition? {
        let note = homeViewModel.inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let packId: String?
        switch category {
        case .dining: packId = "food"
        case .transport: packId = containsTravelKeyword(note) ? "travel" : "commute"
        case .shopping: packId = "shopping"
        case .lodging: packId = "travel"
        case .health: packId = "care"
        case .home: packId = "home"
        case .social: packId = "social"
        case .daily: packId = containsPetKeyword(note) || containsBabyKeyword(note) ? "family" : "supply"
        case .entertainment: packId = containsTravelKeyword(note) ? "travel" : nil
        case .other: packId = nil
        }
        guard let packId else { return nil }
        return implicitScenePacksForCurrentAccess.first { $0.id == packId }
    }

    private func nextCategoryCopyTitle(anchorTitle: String? = nil) -> String {
        let amount = inputAmountValue
        let category = homeViewModel.selectedCategory
        let variantKey = categoryCopyVariantKey(
            category: category,
            amount: amount,
            date: homeViewModel.selectedDate
        )
        let variant = scenePackVariants[variantKey, default: 0]
        let currentTitle = homeViewModel.inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        for offset in 0..<8 {
            let candidate = categoryCopyTitle(
                category: category,
                amount: amount,
                date: homeViewModel.selectedDate,
                variant: variant + offset,
                anchorTitle: anchorTitle
            )
            if candidate != currentTitle || offset == 7 {
                scenePackVariants[variantKey] = variant + offset + 1
                return candidate
            }
        }
        scenePackVariants[variantKey] = variant + 1
        return previewFallbackTitle(for: category)
    }

    private func categoryCopyTitle(
        category: HomeItem.Category,
        amount: Double,
        date: Date,
        variant: Int,
        anchorTitle: String?
    ) -> String {
        if let anchorTitle,
           let anchored = anchoredCategoryCopy(
            from: anchorTitle,
            categoryContext: category,
            variant: variant
           ) {
            return anchored
        }

        return polishedRecordNoteCopy(genericCategoryCopy(
            for: category,
            amount: amount,
            date: date,
            variant: variant
        ))
    }

    private func categoryCopyVariantKey(
        category: HomeItem.Category,
        amount: Double,
        date: Date
    ) -> String {
        let day = Calendar.current.startOfDay(for: date).timeIntervalSince1970
        let hour = Calendar.current.component(.hour, from: date)
        let amountBucket = Int((amount * 100).rounded())
        return "category|\(category.rawValue)|\(amountBucket)|\(Int(day))|\(hour)"
    }

    private func genericCategoryCopy(
        for category: HomeItem.Category,
        amount: Double,
        date: Date,
        variant: Int
    ) -> String {
        let notes: [String]
        switch category {
        case .dining:
            let hour = Calendar.current.component(.hour, from: date)
            switch hour {
            case 5..<10:
                notes = ["早餐先记下", "早上吃点热乎的", "早餐补点能量", "出门前吃一口"]
            case 10..<14:
                notes = ["午餐先记下", "中午简单吃好", "饭点补点能量", "这顿先安排"]
            case 14..<17:
                notes = ["下午补点吃的", "便利店小食记下", "忙到一半补一口", "喝点吃点补上"]
            case 17..<21:
                notes = ["晚饭先安排", "下班后吃点热乎的", "晚餐记下来", "这顿吃好一点"]
            default:
                notes = ["夜里吃点热乎的", "晚归路上补一口", "深夜小食记下", "加班后补点能量"]
            }
        case .transport:
            notes = ["通勤路上", "路上花费补上", "今天出行记下", "这趟走完了", "出门这段记下"]
        case .shopping:
            notes = amount <= 80
                ? ["买到常用的小东西", "下单一个需要的", "快递路上记下", "买点实用的", "小物件补上"]
                : ["买到需要的", "添点常用装备", "这次下单记下", "常用物件买回来了", "购物安排补上"]
        case .daily:
            notes = amount <= 50
                ? ["日用小补给", "日常小物补上", "刚好需要的小东西", "小补给记下来", "常用的先补一点", "便利袋里的一点日常"]
                : ["日常用品补齐", "把常用的补上", "日用品换新一点", "常用物件买回来了", "日常安排补上", "家用小物补齐"]
        case .entertainment:
            notes = ["这次放松安排", "给自己留点轻松", "娱乐小消费记下", "留点休闲时间", "放松一下也记下", "今天的娱乐安排"]
        case .lodging:
            notes = ["今晚住在这里", "住宿安排记下", "短住一晚记下", "这次住处放好"]
        case .health:
            notes = ["健康相关补上", "身体相关记下", "健康事项留个记录", "护理恢复补上"]
        case .home:
            notes = ["家里需要的补上", "住处日常账单", "居家安排补上", "给住处添点实用的"]
        case .social:
            notes = ["这份心意记下", "人情往来放好", "见面留个记录", "关系里的往来记下"]
        case .other:
            notes = ["先放进账本", "日常小记录", "临时花费补上", "单独记录一下", "今天补上一条", "小额支出记下", "这条记录已放好", "简单留个记录"]
        }
        guard !notes.isEmpty else { return previewFallbackTitle(for: category) }
        return notes[variant % notes.count]
    }

    private func handlePreviewQuickAction() {
        dismissKeyboard()
        guard hasValidAmount else { return }
        guard isMember else {
            withAnimation(.easeInOut(duration: 0.2)) {
                noteEditorExpanded = true
            }
            return
        }
        let sourceTitle = homeViewModel.inputTitle
        let sourceWasManualNote = lastDraftIntent == .note
        previewLineWasRotated = true
        applyNoteRewriteDecision(
            resolveNoteRewriteDecision(
                sourceTitle: sourceTitle,
                sourceWasManualNote: sourceWasManualNote
            ),
            sourceTitle: sourceTitle
        )
        lastDraftIntent = .category
    }

    private func handleFreePreviewQuickAction() {
        dismissKeyboard()
        guard hasValidAmount else { return }

        let sourceTitle = homeViewModel.inputTitle
        let sourceWasManualNote = lastDraftIntent == .note
        previewLineWasRotated = true

        applyNoteRewriteDecision(
            resolveNoteRewriteDecision(
                sourceTitle: sourceTitle,
                sourceWasManualNote: sourceWasManualNote
            ),
            sourceTitle: sourceTitle
        )
        lastDraftIntent = .category
    }

    private func resolveNoteRewriteDecision(
        sourceTitle: String,
        sourceWasManualNote: Bool
    ) -> NoteRewriteDecision {
        let anchorTitle = currentUserNoteAnchorTitle(
            sourceTitle: sourceTitle,
            sourceWasManualNote: sourceWasManualNote
        )
        if let pack = activeScenePack {
            if let anchorTitle {
                switch noteRelation(anchorTitle, to: pack, categoryContext: homeViewModel.selectedCategory) {
                case .aligned, .related:
                    return .scenePackCopy(pack, anchorTitle: anchorTitle)
                case .conflict:
                    // 用户已通过「换个角度」选定场景包，换句时不再跳到别的 pack。
                    return .scenePackCopy(pack, anchorTitle: anchorTitle)
                }
            }
            return .scenePackCopy(pack, anchorTitle: nil)
        }
        return .categoryCopy(anchorTitle: anchorTitle)
    }

    private func applyNoteRewriteDecision(
        _ decision: NoteRewriteDecision,
        sourceTitle: String
    ) {
        switch decision {
        case let .categoryCopy(anchorTitle):
            activeScenePack = nil
            homeViewModel.inputTitle = nextCategoryCopyTitle(anchorTitle: anchorTitle)
        case let .scenePackCopy(pack, anchorTitle):
            activeScenePack = pack
            applyScenePackCopy(pack, sourceTitle: sourceTitle, anchorTitle: anchorTitle)
        }
    }

    private func applyScenePackCopy(
        _ pack: ScenePackDefinition,
        sourceTitle: String,
        anchorTitle: String?
    ) {
        let amount = inputAmountValue
        let category = homeViewModel.selectedCategory
        let variantKey = scenePackVariantKey(
            pack: pack,
            amount: amount,
            category: category,
            date: homeViewModel.selectedDate
        )
        let variant = scenePackVariants[variantKey, default: 0]
        scenePackVariants[variantKey] = variant + 1
        homeViewModel.inputTitle = scenePackCopyTitle(
            for: pack,
            amount: amount,
            categoryContext: category,
            variant: variant,
            sourceTitle: anchorTitle ?? sourceTitle
        )
    }

    private func currentUserNoteAnchorTitle(
        sourceTitle: String,
        sourceWasManualNote: Bool
    ) -> String? {
        let source = sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if sourceWasManualNote, !source.isEmpty {
            userNoteAnchorTitle = source
            return source
        }
        let anchor = userNoteAnchorTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return anchor.isEmpty ? nil : anchor
    }

    private func scenePackCopyTitle(
        for pack: ScenePackDefinition,
        amount: Double,
        categoryContext: HomeItem.Category,
        variant: Int,
        sourceTitle: String
    ) -> String {
        if let anchored = anchoredScenePackCopy(
            from: sourceTitle,
            pack: pack,
            categoryContext: categoryContext,
            variant: variant
        ) {
            return polishedRecordNoteCopy(anchored)
        }
        let note = ScenePackCopyPool.note(
            for: pack,
            amount: amount,
            date: homeViewModel.selectedDate,
            categoryContext: categoryContext,
            petName: settingsViewModel.petNickname,
            historyItems: homeViewModel.items,
            allowPetCopy: settingsViewModel.petCompanionEnabled,
            variant: variant,
            allowTravelSpecificCopy: containsTravelKeyword(sourceTitle),
            factText: sourceTitle
        )
        return polishedRecordNoteCopy(note)
    }

    private func polishedRecordNoteCopy(_ note: String) -> String {
        note
            .replacingOccurrences(of: "这一笔", with: "这条记录")
            .replacingOccurrences(of: "这笔记录", with: "这条记录")
            .replacingOccurrences(of: "这笔先", with: "先")
            .replacingOccurrences(of: "这笔给", with: "给")
            .replacingOccurrences(of: "这笔留给", with: "留给")
            .replacingOccurrences(of: "这笔行程", with: "这次行程")
            .replacingOccurrences(of: "记一笔", with: "记下")
            .replacingOccurrences(of: "留一笔", with: "留个记录")
            .replacingOccurrences(of: "补上一笔", with: "补上")
            .replacingOccurrences(of: "一笔小", with: "一点小")
            .replacingOccurrences(of: "一笔日常", with: "日常")
            .replacingOccurrences(of: "一笔重要", with: "重要")
            .replacingOccurrences(of: "一笔大", with: "大")
            .replacingOccurrences(of: "一笔记录", with: "记录")
            .replacingOccurrences(of: "的一笔", with: "的记录")
    }

    private func anchoredCategoryCopy(
        from sourceTitle: String,
        categoryContext: HomeItem.Category,
        variant: Int
    ) -> String? {
        let title = sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        if let semanticCopy = anchoredSemanticCategoryCopy(
            from: title,
            variant: variant
        ) {
            return semanticCopy
        }
        guard let pack = scenePackForTitle(title) ?? baseScenePack(for: categoryContext) else { return nil }
        return anchoredScenePackCopy(
            from: title,
            pack: pack,
            categoryContext: categoryContext,
            variant: variant
        )
    }

    private func anchoredSemanticCategoryCopy(
        from sourceTitle: String,
        variant: Int
    ) -> String? {
        let normalized = sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }
        let notes: [String]?
        if containsTelecomBillKeyword(normalized) {
            notes = ["手机话费缴好了", "话费这笔记下", "这个月话费缴好", "通信账单补上"]
        } else if containsAny(normalized, ["猫砂", "尿垫"]) {
            notes = ["猫砂日常补上", "毛孩子日常补给", "猫砂用品补上", "猫砂清爽补上"]
        } else if containsAny(normalized, ["狗粮", "猫粮", "宠物粮", "宠物口粮"]) {
            notes = ["毛孩子口粮补上", "毛孩子饭碗续上", "宠物口粮补上", "给毛孩子备点口粮"]
        } else if containsPetKeyword(normalized) {
            notes = ["毛孩子用品补充", "宠物用品补上", "给毛孩子备一点", "毛孩子日常补给"]
        } else if containsBabyKeyword(normalized) {
            notes = ["宝宝用品补充", "照护用品补上", "给宝宝备一点", "成长里的小补给"]
        } else if containsAny(normalized, ["游泳", "泳池", "泳馆", "泳票", "泳道"]) {
            notes = ["今天下水一回", "游泳安排记下", "游泳相关补上", "下水这次记下"]
        } else if containsAny(normalized, ["洗牙", "配镜", "验光"]) {
            notes = ["身体检查补上", "护理这次记下", "健康相关补上", "身体这条线记下"]
        } else if containsAny(normalized, ["医美", "医美脱毛", "光子嫩肤", "水光针"]) {
            notes = ["身体护理安排", "护理这次记下", "健康相关补上", "身体这条线记下"]
        } else if containsFitnessKeyword(normalized) {
            notes = ["运动安排记下", "运动后补给一下", "训练相关补上", "身体这条线记下"]
        } else if containsAny(normalized, ["茶叶蛋", "饭团", "关东煮", "肠粉", "黄焖鸡", "冒菜", "生煎", "锅贴"]) {
            notes = ["这口吃的记下", "热乎一份记下", "饭点补上一口", "这一份先垫一下"]
        } else if containsAny(normalized, ["鸡蛋", "牛奶", "鲜奶", "纯牛奶", "酸奶", "山姆", "永辉", "大润发", "钱大妈"]) {
            notes = ["家里吃的补上", "日常食材补上", "给家里补点吃的", "冰箱补一点"]
        } else if containsAny(normalized, ["搬家", "搬家公司", "货拉拉搬家"]) {
            notes = ["搬家安排记下", "住处换一段", "搬家这笔补上", "居家大事办完"]
        } else if containsAny(normalized, ["保洁", "家政", "钟点工", "开荒保洁", "上门保洁", "深度保洁", "擦玻璃", "清洗油烟机", "空调清洗"]) {
            notes = ["家里清洁一回", "住处收拾一下", "居家安排补上", "家里这件事办完"]
        } else if containsAny(normalized, ["暖气费", "取暖费", "供暖费", "采暖费", "热力费", "供热费", "暖气缴费", "热力公司"]) {
            notes = ["供暖账单记下", "家里运转一笔", "冬天这笔补上", "居家账单补上"]
        } else if containsAny(normalized, ["洗车", "汽车保养", "车辆保养", "保养车", "etc", "充车", "充电桩", "电车充电", "汽车充电", "车辆充电", "新能源充电", "补能"]) {
            notes = ["车主日常记下", "车这边安排好", "路上相关补上", "用车这笔记下"]
        } else if containsAny(normalized, ["b站会员", "哔哩哔哩会员", "爱奇艺会员", "腾讯视频会员", "优酷会员", "芒果tv会员", "网易云会员", "网易云音乐会员", "qq音乐会员", "喜马拉雅会员", "百度网盘会员", "wps会员", "icloud订阅", "apple music", "office 365", "microsoft 365", "adobe订阅", "creative cloud", "notion订阅", "notion会员"]) {
            notes = ["数字订阅续上", "这次续费记下", "常用服务安排好", "这份订阅补上"]
        } else if containsAny(normalized, ["网吧", "网咖", "上网费"]) {
            notes = ["上网娱乐一回", "这次开机记下", "游戏时间记下", "放松这一段"]
        } else if containsAny(normalized, ["电竞酒店"]) {
            notes = ["电竞酒店一晚", "住宿这次记下", "这晚落脚记下", "住宿安排补上"]
        } else if containsAny(normalized, ["直播打赏", "主播打赏", "抖音打赏", "直播礼物"]) {
            notes = ["直播互动记下", "这次打赏记下", "娱乐互动补上", "这份支持记下"]
        } else if containsAny(normalized, ["模型", "手办", "谷子", "潮玩", "吧唧", "徽章", "亚克力", "立牌", "盲盒", "泡泡玛特", "pop mart", "popmart", "labubu", "棉花娃娃", "痛包", "同人本", "乙游周边", "漫展周边"]) {
            notes = ["潮玩谷子补上", "喜欢的小物记下", "兴趣添置补上", "这份收藏记下"]
        } else if containsAny(normalized, ["路亚", "渔具", "鱼竿", "鱼线", "鱼饵", "钓箱", "钓椅"]) {
            notes = ["钓鱼装备补充", "给钓鱼添点装备", "路亚装备补上", "喜欢的装备补上"]
        } else if containsAny(normalized, ["白事", "白事随礼", "奠仪", "帛金", "花圈"]) {
            notes = ["重要人情记下", "这份心意记下", "人情往来补上", "这次礼数记下"]
        } else if containsAny(normalized, ["驾校", "驾校报名费", "驾考", "学车"]) {
            notes = ["学车安排记下", "驾校这笔补上", "考试准备记下", "这项学习安排好"]
        } else if containsAny(normalized, ["彩票", "福彩", "体彩", "刮刮乐"]) {
            notes = ["这笔单独记下", "小额尝试记下", "临时一笔补上", "这次记录留底"]
        } else {
            notes = nil
        }
        guard let notes, !notes.isEmpty else { return nil }
        return notes[variant % notes.count]
    }

    private func anchoredScenePackCopy(
        from sourceTitle: String,
        pack: ScenePackDefinition,
        categoryContext: HomeItem.Category,
        variant: Int
    ) -> String? {
        let title = sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        guard titleIsCompatibleWithScenePack(title, pack: pack, categoryContext: categoryContext) else {
            return nil
        }
        let normalized = title.lowercased()
        let notes: [String]?
        switch pack.id {
        case "shopping":
            if containsAny(normalized, ["路亚", "渔具", "鱼竿", "鱼线", "鱼饵", "钓箱", "钓椅"]) {
                notes = ["钓鱼装备补充", "给钓鱼添点装备", "路亚装备补上", "喜欢的装备补上"]
            } else if containsAny(normalized, ["露营", "帐篷", "天幕", "睡袋"]) {
                notes = ["露营装备补充", "给露营添点装备", "户外装备补上", "下次出发用得上"]
            } else if containsAny(normalized, ["骑行", "头盔", "码表"]) {
                notes = ["骑行装备补充", "给骑行添点装备", "路上用得上的小升级", "骑行小物补上"]
            } else if containsAny(normalized, ["摄影", "相机", "镜头"]) {
                notes = ["摄影装备补充", "给拍照添点装备", "镜头和器材补上", "喜欢的器材小升级"]
            } else if containsAny(normalized, ["乐器", "吉他", "键盘"]) {
                notes = ["乐器装备补充", "给练习添点装备", "音乐爱好里的小投入", "喜欢的声音留住"]
            } else {
                notes = nil
            }
        case "family":
            if containsBabyKeyword(normalized) {
                notes = ["宝宝用品补充", "照护用品补上", "给宝宝备一点", "成长里的小补给"]
            } else if containsPetKeyword(normalized) {
                if containsAny(normalized, ["猫砂", "尿垫"]) {
                    notes = ["猫砂日常补上", "毛孩子日常补给", "猫砂用品补上", "猫砂清爽补上"]
                } else if containsAny(normalized, ["狗粮", "猫粮", "宠物粮", "宠物口粮"]) {
                    notes = ["毛孩子口粮补上", "毛孩子饭碗续上", "宠物口粮补上", "给毛孩子备点口粮"]
                } else {
                    notes = ["毛孩子用品补充", "宠物用品补上", "给毛孩子备一点", "毛孩子日常补给"]
                }
            } else {
                notes = nil
            }
        case "food":
            if containsAny(normalized, ["咖啡", "拿铁", "美式"]) {
                notes = ["咖啡续上", "今天这杯咖啡", "给自己补杯咖啡", "咖啡时间记下"]
            } else if containsAny(normalized, ["奶茶", "饮品", "饮料", "茶饮"]) {
                notes = ["买杯喝的", "饮品补一点", "今天这杯记下", "给自己添杯饮品"]
            } else if containsAny(normalized, ["茶叶蛋", "饭团", "关东煮", "便当", "三明治", "热食", "小食", "肠粉", "黄焖鸡", "冒菜", "生煎", "锅贴"]) {
                notes = ["便利店小食记下", "路过买点吃的", "便利店热食在手边", "小食先垫一下"]
            } else if containsAny(normalized, ["早餐", "早饭", "包子", "豆浆"]) {
                notes = ["早餐先记下", "早上吃点热乎的", "早餐补点能量", "早饭安排好"]
            } else if containsAny(normalized, ["午餐", "午饭", "食堂", "简餐", "外卖"]) {
                notes = ["午餐先记下", "中午简单吃好", "简单吃一顿", "饭点补点能量"]
            } else if containsAny(normalized, ["晚餐", "晚饭", "夜宵", "宵夜"]) {
                notes = ["晚饭先安排", "夜里吃点热乎的", "这顿先记下", "晚点补点能量"]
            } else {
                notes = nil
            }
        case "supply":
            if containsTelecomBillKeyword(normalized) {
                notes = ["手机话费缴好了", "话费这笔记下", "这个月话费缴好", "通信账单补上"]
            } else if containsAny(normalized, ["买菜", "生鲜", "水果", "蔬菜", "肉", "鸡蛋", "牛奶", "鲜奶", "纯牛奶", "酸奶", "盒马", "叮咚", "山姆", "永辉", "大润发", "钱大妈"]) {
                notes = ["给家里补点吃的", "买菜补齐", "冰箱补一点", "日常食材补上"]
            } else if containsAny(normalized, ["纸巾", "抽纸", "卷纸", "洗衣", "清洁", "垃圾袋", "日化"]) {
                notes = ["日用品补上", "家用消耗品补齐", "清洁日用补齐", "常用的先备好"]
            } else if containsAny(normalized, ["超市", "便利店", "日用品", "家用", "补货"]) {
                notes = ["日常补货补上", "给家里补一点", "常用小物补上", "补点日常"]
            } else {
                notes = nil
            }
        case "care":
            if containsAny(normalized, ["健身", "运动", "训练", "跑步", "瑜伽", "游泳"]) {
                notes = ["训练安排补上", "运动安排留好", "给身体的一次投入", "健身相关补上"]
            } else if containsAny(normalized, ["买药", "药店", "药房", "用药", "医院", "挂号", "问诊", "理疗", "康复", "洗牙", "配镜", "验光", "医美", "医美脱毛", "光子嫩肤", "水光针"]) {
                notes = ["身体相关补上", "健康相关补上", "身体护理留个记录", "健康事项留个记录"]
            } else {
                notes = nil
            }
        case "travel":
            if containsTravelKeyword(normalized) {
                notes = ["行程里的小安排", "出去玩相关记下", "路上安排补上", "这段出行留个底"]
            } else {
                notes = nil
            }
        case "commute":
            if containsAny(normalized, ["地铁", "公交", "打车", "花小猪", "停车", "加油", "洗车", "汽车保养", "车辆保养", "保养车", "etc", "通勤", "上班", "下班"]) {
                notes = ["通勤路上", "路上花费补上", "今天出行记下", "这趟走完了"]
            } else {
                notes = nil
            }
        case "home":
            if containsAny(normalized, ["房租", "租金", "租房"]) {
                notes = ["房租安排好", "住处固定支出", "这个月房租放好", "给住处留个记录"]
            } else if containsAny(normalized, ["水电", "电费", "燃气", "煤气", "物业", "宽带", "暖气费", "取暖费", "供暖费", "采暖费", "热力费", "供热费", "暖气缴费", "热力公司", "网上国网", "国网"]) {
                notes = ["住处日常账单", "家里固定账单补上", "水电物业补上", "住处运转日常"]
            } else if containsAny(normalized, ["搬家", "搬家公司", "货拉拉搬家"]) {
                notes = ["搬家安排记下", "住处换一段", "搬家这笔补上", "居家大事办完"]
            } else if containsAny(normalized, ["保洁", "家政", "钟点工", "开荒保洁", "上门保洁", "深度保洁", "擦玻璃", "清洗油烟机", "空调清洗"]) {
                notes = ["家里清洁一回", "住处收拾一下", "居家安排补上", "家里这件事办完"]
            } else if containsAny(normalized, ["维修", "家电", "家具", "床品", "收纳", "厨房"]) {
                notes = ["给住处添点实用的", "家里需要的补上", "居家安排补上", "住处小调整记下"]
            } else {
                notes = nil
            }
        case "social":
            if containsAny(normalized, ["红包", "随礼", "份子钱"]) {
                notes = ["人情往来记下", "这份心意记下", "重要日子里的心意", "关系里的往来放好"]
            } else if containsAny(normalized, ["白事", "白事随礼", "奠仪", "帛金", "花圈"]) {
                notes = ["重要人情记下", "这份心意记下", "人情往来补上", "这次礼数记下"]
            } else if containsAny(normalized, ["礼物", "送礼", "伴手礼"]) {
                notes = ["给对方带点心意", "礼物准备好", "这份心意补上", "见面前准备一下"]
            } else if containsAny(normalized, ["请客", "聚会", "朋友", "同事"]) {
                notes = ["这次相聚记下", "一起吃顿饭", "见面留个记录", "关系里的热闹记下"]
            } else if containsAny(normalized, ["探望", "看望", "拜访", "家人", "父母"]) {
                notes = ["去见重要的人", "探望安排记下", "给牵挂的人留个记录", "这次见面记下"]
            } else {
                notes = nil
            }
        default:
            notes = nil
        }
        guard let notes, !notes.isEmpty else { return nil }
        return notes[variant % notes.count]
    }

    private func titleIsCompatibleWithScenePack(
        _ title: String,
        pack: ScenePackDefinition,
        categoryContext: HomeItem.Category
    ) -> Bool {
        noteRelation(title, to: pack, categoryContext: categoryContext) != .conflict
    }

    private func noteRelation(
        _ title: String,
        to pack: ScenePackDefinition,
        categoryContext: HomeItem.Category
    ) -> ScenePackNoteRelation {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .related }
        let matches = RecordSemanticLexicon.matchingCategories(in: title)
        guard !matches.isEmpty else { return .related }
        if pack.id == "travel", containsTravelKeyword(title) { return .aligned }
        if pack.id == "family", containsBabyKeyword(title) || containsPetKeyword(title) { return .aligned }
        let compatibleCategories = scenePackSemanticCategories(for: pack)
        if !matches.isDisjoint(with: compatibleCategories) { return .aligned }
        if compatibleCategories.contains(categoryContext),
           RecordSemanticLexicon.isTitle(title, compatibleWith: categoryContext) {
            return .related
        }
        return .conflict
    }

    private func scenePackForTitle(_ title: String) -> ScenePackDefinition? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let packId: String?
        if containsPetKeyword(trimmed) || containsBabyKeyword(trimmed) {
            packId = "family"
        } else if containsTravelKeyword(trimmed) {
            packId = "travel"
        } else if let category = RecordSemanticLexicon.bestMatchingCategory(in: trimmed) {
            switch category {
            case .dining:
                packId = "food"
            case .transport:
                packId = "commute"
            case .shopping:
                packId = "shopping"
            case .daily:
                packId = "supply"
            case .lodging:
                packId = "travel"
            case .health:
                packId = "care"
            case .home:
                packId = "home"
            case .social:
                packId = "social"
            case .entertainment:
                packId = containsTravelKeyword(trimmed) ? "travel" : nil
            case .other:
                packId = nil
            }
        } else {
            packId = nil
        }
        guard let packId else { return nil }
        return implicitScenePacksForCurrentAccess.first { $0.id == packId }
    }

    private func scenePackSemanticCategories(for pack: ScenePackDefinition) -> Set<HomeItem.Category> {
        switch pack.id {
        case "travel":
            return [.transport, .lodging, .entertainment, .dining]
        case "family":
            return [.daily]
        case "shopping":
            return [.shopping, .daily]
        case "supply":
            return [.daily, .shopping, .home]
        case "home":
            return [.home, .daily]
        case "social":
            return [.social]
        default:
            return [pack.category]
        }
    }

    private func clearActiveScenePackIfManualNoteMovedAway() {
        guard lastDraftIntent == .note,
              let pack = activeScenePack else { return }
        let title = homeViewModel.inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        if !titleIsCompatibleWithScenePack(title, pack: pack, categoryContext: homeViewModel.selectedCategory) {
            activeScenePack = nil
        }
    }

    private func openFreeScenePackAngleSheet() {
        dismissKeyboard()
        prepareFreeLockedSceneHintIfNeeded()
        showScenePackAngleSheet = true
    }

    private func preferredFreeScenePack() -> ScenePackDefinition? {
        let packs = freeScenePacksForUse
        guard !packs.isEmpty else { return nil }

        let guessedPackId = guessScenePackId()
        if let guessedPack = packs.first(where: { $0.id == guessedPackId }) {
            return guessedPack
        }

        if let compatiblePack = packs.first(where: { $0.category == homeViewModel.selectedCategory }) {
            return compatiblePack
        }

        let amount = inputAmountValue
        let variantKey = "free-scene-pack|\(homeViewModel.selectedCategory.rawValue)|\(Int((amount * 100).rounded()))"
        let variant = scenePackVariants[variantKey, default: 0]
        scenePackVariants[variantKey] = variant + 1
        return packs[variant % packs.count]
    }

    private func refreshRecommendedCategory(debounced: Bool = false) {
        if debounced {
            recommendedCategoryRefreshTask?.cancel()
            recommendedCategoryRefreshTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 220_000_000)
                guard !Task.isCancelled else { return }
                refreshRecommendedCategoryNow()
            }
            return
        }
        recommendedCategoryRefreshTask?.cancel()
        refreshRecommendedCategoryNow()
    }

    private func refreshRecommendedCategoryNow() {
        guard selectedEntryMode == .manual else { return }
        homeViewModel.refreshRecordWarmupSuggestions()
        guard !homeViewModel.categoryLockedByUser else { return }
        guard !(previewLineWasRotated && lastDraftIntent == .category) else { return }
        homeViewModel.refreshRecordPrefill()
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 12) {
                    // ── Record Panel (matching web recordPage) ──
                    VStack(alignment: .leading, spacing: 14) {
                        recordPanelHeader

                        if selectedEntryMode == .manual {
                            manualForm
                        } else {
                            ocrForm
                        }
                    }
                    .recordEntryPanel(radius: 24, padding: 22)
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, recordContentBottomPadding)
                .frame(maxWidth: 430)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if shouldShowAmountQuickKeys {
                    amountKeyboardDock
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.18), value: shouldShowAmountQuickKeys)
            .task(id: previewLifeMarkPreparationKey) {
                await preparePreviewLifeMark(for: previewLifeMarkPreparationKey)
            }
            .onChange(of: selectedPhoto) { _, newValue in
                guard let newValue else { return }
                Task {
                    await MainActor.run {
                        isOCRRecognizing = true
                        ocrProgress = 0.12
                    }
                    let progressTask = Task {
                        while !Task.isCancelled {
                            try? await Task.sleep(nanoseconds: 180_000_000)
                            await MainActor.run {
                                ocrProgress = min(0.88, ocrProgress + 0.08)
                            }
                        }
                    }
                    var drafts: [OCRReceiptDraft] = []
                    if let data = try? await newValue.loadTransferable(type: Data.self) {
                        drafts = await homeViewModel.recognizeOCRDrafts(imageData: data, isMember: isMember)
                    }
                    progressTask.cancel()
                    await MainActor.run {
                        ocrProgress = 1
                        if !drafts.isEmpty {
                            ocrConfirmDrafts = drafts
                            showOCRConfirmSheet = true
                        }
                    }
                    try? await Task.sleep(nanoseconds: 180_000_000)
                    await MainActor.run {
                        isOCRRecognizing = false
                        ocrProgress = 0
                        selectedPhoto = nil
                    }
                }
            }
            .onChange(of: homeViewModel.inputAmount) { _, _ in
                if !hasValidAmount {
                    previewLineWasRotated = false
                    lastDraftIntent = .automatic
                    userNoteAnchorTitle = nil
                    activeScenePack = nil
                    categoryGridExpanded = false
                    noteEditorExpanded = false
                    datePanelExpanded = false
                } else if previewLineWasRotated,
                          !noteEditorExpanded,
                          activeScenePack == nil {
                    homeViewModel.inputTitle = ""
                    previewLineWasRotated = false
                    lastDraftIntent = .automatic
                }
                refreshRecommendedCategory()
            }
            .onChange(of: homeViewModel.inputTitle) { _, _ in
                if homeViewModel.inputTitle.count > 32 {
                    homeViewModel.inputTitle = String(homeViewModel.inputTitle.prefix(32))
                    return
                }
                if focusedField == .note {
                    if lastDraftIntent != .note {
                        lastDraftIntent = .note
                    }
                    if suppressNextNoteSemanticUnlock {
                        suppressNextNoteSemanticUnlock = false
                    } else if let category = manualNoteOverrideCategory(homeViewModel.inputTitle) {
                        homeViewModel.applyRecommendedCategory(category)
                    }
                    rememberUserNoteAnchor(homeViewModel.inputTitle)
                } else if suppressNextNoteSemanticUnlock {
                    suppressNextNoteSemanticUnlock = false
                }
                homeViewModel.clearRecordInputMessage()
                refreshRecommendedCategory(debounced: focusedField == .note)
            }
            .onChange(of: homeViewModel.selectedDate) { _, _ in
                refreshRecommendedCategory()
            }
            .onChange(of: homeViewModel.recordInputAssistanceRevision) { _, _ in
                refreshRecommendedCategory()
            }
            .onChange(of: selectedEntryMode) { _, newValue in
                if newValue == .manual {
                    focusAmountPad(delay: 0.08)
                } else {
                    dismissKeyboard()
                }
            }
            .onChange(of: focusedField) { _, newValue in
                if newValue == .note {
                    amountPadActive = false
                    scrollNoteFieldIntoView(scrollProxy)
                } else {
                    refreshRecommendedCategory()
                }
            }
            .onReceive(draftClock) { now in
                guard selectedEntryMode == .manual else { return }
                guard !hasUncommittedManualDraft else { return }
                homeViewModel.refreshDraftSelectedDate(now: now)
            }
            .onAppear {
                freeScenePackService.recordFirstOpenIfNeeded()
                if !hasUncommittedManualDraft {
                    homeViewModel.refreshDraftSelectedDate(force: true)
                }
                refreshRecommendedCategory()
                guard !didAutoFocusAmountPad else { return }
                didAutoFocusAmountPad = true
                focusAmountPad()
            }
            .onDisappear {
                recommendedCategoryRefreshTask?.cancel()
                recommendedCategoryRefreshTask = nil
                homeViewModel.cancelRecordInputAssistancePreparation()
            }
            .sheet(isPresented: $showOCRConfirmSheet) {
                OCRConfirmSheet(drafts: ocrConfirmDrafts) { selectedDrafts, sendToDrafts in
                    let importedCount = homeViewModel.importOCRDrafts(
                        selectedDrafts,
                        isMember: isMember,
                        sendToDrafts: sendToDrafts
                    )
                    if importedCount > 0 {
                        didImportOCRConfirmSheet = true
                        if sendToDrafts {
                            ocrDraftStageDismissed = false
                        }
                    }
                    return importedCount
                }
            }
            .sheet(isPresented: $showScenePackAngleSheet, onDismiss: {
                let shouldOpenMemberPricing = opensMemberPricingAfterScenePackDismiss
                opensMemberPricingAfterScenePackDismiss = false
                if shouldOpenMemberPricing {
                    onShowMemberPricing?(.scenePack(nil))
                }
            }) {
                if isMember {
                    ScenePackAngleSheet(
                        primaryScenePacks: primaryScenePacks,
                        secondaryScenePacks: secondaryScenePacks,
                        isMoreExpanded: $scenePackMoreExpanded,
                        scenePackDesc: scenePackDesc,
                        onReorderPacks: { orderedPackIds, movedPackIds in
                            reorderScenePacks(orderedPackIds: orderedPackIds, movedPackIds: movedPackIds)
                        },
                        onSelectPack: { pack in
                            previewLineWasRotated = true
                            applyScenePack(pack)
                        }
                    )
                } else {
                    ScenePackAngleSheet(
                        freeScenePacks: freeScenePacks,
                        moreScenePacks: freeMoreScenePacks,
                        replaceableScenePacks: freeReplaceableScenePacks,
                        lockedSceneHint: freeLockedSceneHint,
                        pendingLifeMarkReward: pendingLifeMarkSceneReward,
                        activeLifeMarkReward: activeLifeMarkSceneReward,
                        isInFirstWeek: freeScenePackService.isInFirstWeek(),
                        daysUntilExtensionLock: freeScenePackService.daysUntilExtensionLock(),
                        canReplacePackCombination: freeScenePackService.canReplacePackCombination(),
                        nextReplaceAvailableAt: freeScenePackService.nextReplaceAvailableAt(),
                        isReplaceWindowActive: freeScenePackService.isReplaceWindowActive(),
                        replaceWindowEndsAt: freeScenePackService.replaceWindowEndsAt(),
                        scenePackDesc: scenePackDesc,
                        isExtensionLockedPack: { pack in
                            freeScenePackService.isExtensionLockedPack(pack)
                        },
                        onReorderFreePacks: { orderedPackIds in
                            freeScenePackService.reorderFreePacks(orderedPackIds, from: visibleScenePacks)
                            freeScenePackRefreshToken += 1
                        },
                        onSelectFreePack: { pack in
                            previewLineWasRotated = true
                            applyScenePack(pack, trackMemberSceneUsage: false)
                        },
                        onReplaceFreePack: { slot, oldId, newPack in
                            freeScenePackService.replacePack(atSlot: slot, oldId: oldId, newId: newPack.id, from: visibleScenePacks)
                            freeScenePackRefreshToken += 1
                        },
                        onClaimLifeMarkReward: { reward in
                            claimLifeMarkSceneReward(reward, shouldApplyPack: false)
                        },
                        onShowMemberPricing: {
                            opensMemberPricingAfterScenePackDismiss = onShowMemberPricing != nil
                            showScenePackAngleSheet = false
                        }
                    )
                }
            }
            .overlay(alignment: .top) {
                if let scenePackFeedback {
                    scenePackFeedbackToast(scenePackFeedback)
                        .padding(.top, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onChange(of: showOCRConfirmSheet) { _, isPresented in
                if !isPresented {
                    ocrConfirmDrafts = []
                    if !didImportOCRConfirmSheet {
                        homeViewModel.clearOCRRecognitionStatus()
                    }
                    didImportOCRConfirmSheet = false
                }
            }
        }
    }
    // MARK: - Segment

    private var recordPanelHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("把生活放进账本")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppColors.accent.opacity(0.78))

            Text(hasAmountDraft ? "先放进账本" : "先记金额")
                .font(.title3.weight(.bold))
                .foregroundStyle(recordInk)

            Text(hasAmountDraft ? "先落到账本，之后可以回看。" : "先敲金额，分类和备注会跟着浮出来。")
                .font(.footnote)
                .foregroundStyle(AppColors.subtext)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var recordModeSegment: some View {
        HStack(spacing: 4) {
            ForEach(RecordEntryMode.allCases) { mode in
                recordModeButton(mode)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.25))
        )
    }

    private func recordModeButton(_ mode: RecordEntryMode) -> some View {
        let isSelected = selectedEntryMode == mode
        return Button {
            dismissKeyboard()
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                selectedEntryMode = mode
            }
            if mode == .manual {
                focusAmountPad(delay: 0.12)
            }
        } label: {
            recordModeLabel(mode, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.rawValue)
        .accessibilityValue(isSelected ? "已选中" : "")
        .accessibilityHint(mode == .manual ? "切换到手动记录" : "切换到账单截图识别")
    }

    private func recordModeLabel(_ mode: RecordEntryMode, isSelected: Bool) -> some View {
        let weight: Font.Weight = isSelected ? .semibold : .regular
        let shadow = isSelected ? Color.black.opacity(0.08) : Color.clear
        return Text(mode.rawValue)
            .font(.body.weight(weight))
            .foregroundStyle(recordInk)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 10)
            .background(recordModeBackground(isSelected: isSelected))
            .shadow(color: shadow, radius: 2, y: 1)
    }

    private func recordModeBackground(isSelected: Bool) -> some View {
        let fill = isSelected ? Color.white.opacity(0.85) : Color.clear
        return RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(fill)
    }

    // MARK: - Manual Form

    @ViewBuilder
    private var manualForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            amountField
            if hasValidAmount {
                lifeEntryPreview
            }
            if !amountPadActive {
                saveRow
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            if RecordFlowVisibilityPolicy.showsOCRSideDoor(hasAmountDraft: hasAmountDraft) {
                ocrSideDoor
            }
            if hasValidAmount {
                recordDateQuietActions
                if datePanelExpanded {
                    WarmRecordDatePanel(selection: recordDateBinding) {
                        dismissKeyboard()
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            if hasValidAmount {
                expandedDetails
            }
        }
    }

    private var recordWarmupSuggestions: [HomeViewModel.FrequentRecordAmountSuggestion] {
        homeViewModel.recordWarmupSuggestions
    }

    private var lifeEntryPreview: some View {
        LifeEntryPreviewCard(
            tier: previewTier,
            headline: previewHeadline,
            hint: previewHint,
            learningHint: previewLearningHint,
            lifeMarkText: previewLifeMarkText,
            emotion: previewTier == .whisper ? "" : previewEmotion,
            meta: previewCardMeta,
            amountText: inputAmountValue.formatted(.cny),
            primaryActionTitle: previewQuickActionTitle,
            showsPrimaryAction: isMember,
            showAngleAction: isMember && previewLineWasRotated && previewTier == .confirm,
            showsFreePrimaryAction: !isMember && hasValidAmount && previewTier == .confirm,
            showFreeAngleAction: !isMember && hasValidAmount && previewTier == .confirm,
            freeScenePackLimitText: freeScenePackLimitText,
            onTap: {
                openNoteEditor()
            },
            onChangeCategory: {
                dismissKeyboard()
                withAnimation(.easeInOut(duration: 0.2)) {
                    categoryGridExpanded = true
                }
            },
            onPrimaryAction: handlePreviewQuickAction,
            onWriteOwn: {
                openNoteEditor()
            },
            onAngleAction: {
                dismissKeyboard()
                showScenePackAngleSheet = true
            },
            onFreePrimaryAction: handleFreePreviewQuickAction,
            onFreeAngleAction: {
                openFreeScenePackAngleSheet()
            }
        )
    }

    private func claimLifeMarkSceneReward(_ reward: LifeMarkSceneReward, shouldApplyPack: Bool) {
        guard let activeReward = lifeMarkSceneRewardService.claimReward(reward, from: visibleScenePacks) else { return }
        freeScenePackRefreshToken += 1
        guard shouldApplyPack,
              let pack = visibleScenePacks.first(where: { $0.id == activeReward.packId }) else { return }
        guard hasValidAmount else {
            openFreeScenePackAngleSheet()
            return
        }
        previewLineWasRotated = true
        applyScenePack(pack, trackMemberSceneUsage: false)
        scenePackFeedback = "已领取 7 天体验：\(pack.label)"
    }

    private var ocrSideDoor: some View {
        Button {
            dismissKeyboard()
            selectedEntryMode = .ocr
        } label: {
            Text("有账单截图？从截图导入 →")
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppColors.subtext)
                .frame(minHeight: 44)
                .padding(.horizontal, 12)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.48))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(AppColors.line.opacity(0.52), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("账单识别")
        .accessibilityHint("从微信或支付宝账单截图导入")
    }

    @ViewBuilder
    private var expandedDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            if categoryGridExpanded { categorySection }
            if noteEditorExpanded { noteSection }
        }
    }

    // MARK: - Amount Field

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            amountStage
            if !hasAmountDraft, !recordWarmupSuggestions.isEmpty {
                amountWarmupChips
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Text(hasValidAmount ? "金额先记下，之后可以按日期和分类回看。" : emptyAmountWhisper)
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext.opacity(0.76))
                .frame(maxWidth: .infinity, alignment: hasAmountDraft ? .leading : .center)
                .multilineTextAlignment(hasAmountDraft ? .leading : .center)
        }
    }

    private var amountWarmupChips: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("这个时段常记")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.subtext.opacity(0.68))
                .padding(.horizontal, 12)

            HStack(spacing: 8) {
                ForEach(recordWarmupSuggestions) { suggestion in
                    Button {
                        homeViewModel.inputAmount = amountInputText(suggestion.amount)
                        homeViewModel.applyRecommendedCategory(suggestion.category)
                        focusAmountPad(delay: 0.02)
                    } label: {
                        Text("¥\(amountChipText(suggestion.amount))")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(recordInk.opacity(0.78))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.50))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(AppColors.line.opacity(0.42), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
        }
    }

    private func amountChipText(_ amount: Double) -> String {
        if amount.rounded() == amount {
            return String(format: "%.0f", amount)
        }
        return String(format: "%.2f", amount)
    }

    private func amountInputText(_ amount: Double) -> String {
        if amount.rounded() == amount {
            return String(format: "%.0f", amount)
        }
        return String(format: "%.2f", amount)
    }

    private var amountStage: some View {
        ZStack {
            if !hasAmountDraft {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [AppColors.accent.opacity(0.14), AppColors.accent.opacity(0.0)],
                            center: .center,
                            startRadius: 4,
                            endRadius: 135
                        )
                    )
                    .frame(height: 96)
                    .blur(radius: 4)
                    .padding(.horizontal, 10)
                    .allowsHitTesting(false)
            }

            Button {
                focusedField = nil
                withAnimation(.easeInOut(duration: 0.16)) {
                    amountPadActive = true
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("¥")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.subtext.opacity(hasAmountDraft ? 0.74 : 0.68))
                        .padding(.trailing, 2)
                        .offset(y: 1)

                    if shouldShowAmountCursor && !hasAmountDraft {
                        amountCursor
                            .offset(y: 6)
                            .transition(.opacity)
                    }

                    Text(homeViewModel.inputAmount.isEmpty ? "0.00" : homeViewModel.inputAmount)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(amountDisplayTextColor(isPlaceholder: homeViewModel.inputAmount.isEmpty))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .contentTransition(.numericText())

                    if shouldShowAmountCursor && hasAmountDraft {
                        amountCursor
                            .offset(y: 6)
                            .transition(.opacity)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 72)
                .contentShape(RoundedRectangle(cornerRadius: amountFieldRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .background(amountFieldBackground)
            .overlay(amountFieldBorder)
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(Color.white.opacity(hasAmountDraft ? 0.24 : 0.36))
                    .frame(height: 1)
                    .padding(.horizontal, 18)
                    .padding(.top, 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: AppColors.accent.opacity(hasAmountDraft ? 0.07 : 0.12), radius: 18, x: 0, y: 8)
            .contentShape(RoundedRectangle(cornerRadius: amountFieldRadius, style: .continuous))
            .padding(.horizontal, 12)
        }
        .frame(height: 90)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private var shouldShowAmountCursor: Bool {
        selectedEntryMode == .manual && amountPadActive
    }

    private var amountCursor: some View {
        TimelineView(.periodic(from: .now, by: 0.56)) { context in
            let tick = Int(context.date.timeIntervalSinceReferenceDate / 0.56)
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(recordAccent.opacity(0.72))
                .frame(width: 2, height: 42)
                .opacity(tick.isMultiple(of: 2) ? 1 : 0.16)
                .animation(.easeInOut(duration: 0.18), value: tick)
        }
        .frame(width: 7, height: 46, alignment: .center)
        .accessibilityHidden(true)
    }

    private var amountFieldRadius: CGFloat {
        20
    }

    private var amountFieldBackground: some View {
        RoundedRectangle(cornerRadius: amountFieldRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: amountFieldBackgroundColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(
                RoundedRectangle(cornerRadius: amountFieldRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(alignment: .topLeading) {
                LinearGradient(
                    colors: [
                        Color.white.opacity(hasAmountDraft ? 0.58 : 0.42),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 42)
                .clipShape(RoundedRectangle(cornerRadius: amountFieldRadius, style: .continuous))
            }
    }

    private var amountFieldBorder: some View {
        RoundedRectangle(cornerRadius: amountFieldRadius, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(hasAmountDraft ? 0.74 : 0.56),
                        AppColors.accent.opacity(hasAmountDraft ? 0.24 : 0.34),
                        AppColors.paperBorder.opacity(hasAmountDraft ? 0.12 : 0.20)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    private var amountFieldBackgroundColors: [Color] {
        if hasAmountDraft {
            return [
                Color.white.opacity(0.72),
                AppColors.paperWarm.opacity(0.30),
                AppColors.tracePlaybackButtonBg.opacity(0.22)
            ]
        }
        return [
            AppColors.paperWarm.opacity(0.58),
            AppColors.paperMist.opacity(0.42),
            Color.white.opacity(0.50)
        ]
    }

    private var emptyAmountWhisper: String {
        let lines = [
            "金额填上后，再补分类和备注。",
            "先从数字开始，记录就有了位置。",
            "不用想完整，先把金额记下来。",
            "数额在这就行，后面再补一句记录。"
        ]
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return lines[day % lines.count]
    }

    // MARK: - Amount Quick Keys

    private var amountKeyboardDock: some View {
        VStack(spacing: 10) {
            if hasValidAmount {
                amountAccessoryBar
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: 8) {
                quickKeyButton(".00") { applyDot00() }
                quickKeyButton("+10") { applyAmountDelta(10) }
                quickKeyButton("+50") { applyAmountDelta(50) }
                keyboardCloseButton
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                spacing: 8
            ) {
                ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9"], id: \.self) { key in
                    amountPadButton(key) { appendAmountKey(key) }
                }
                amountPadButton(".") { appendAmountKey(".") }
                amountPadButton("0") { appendAmountKey("0") }
                amountPadButton("⌫", isAccent: true) { deleteAmountKey() }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(AppColors.paperMist.opacity(0.64))
                .overlay(Color.white.opacity(0.18))
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppColors.line.opacity(0.55))
                .frame(height: 1)
        }
        .shadow(color: Color(red: 43/255, green: 66/255, blue: 58/255).opacity(0.10), radius: 18, x: 0, y: -6)
    }

    private var amountAccessoryBar: some View {
        HStack {
            Spacer(minLength: 0)
            Button {
                saveManualRecord()
            } label: {
                Text("放进账本")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(hasValidAmount ? .white : AppColors.accent.opacity(0.58))
                    .frame(minWidth: 112)
                    .padding(.vertical, 10)
                    .background(accessorySaveBackground)
                    .overlay(accessorySaveBorder)
            }
            .buttonStyle(.plain)
            .disabled(!hasValidAmount)
            .opacity(hasValidAmount ? 1 : 0.72)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 0)
    }

    private var keyboardCloseButton: some View {
        let foreground = amountKeyboardTextColor(isAccent: true)
        let fill = amountKeyboardKeyFill(isAccent: true)
        return Button {
            dismissKeyboard()
        } label: {
            Image(systemName: "keyboard.chevron.compact.down")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(fill)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("收起键盘")
    }

    private var accessorySaveBackground: some View {
        Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: hasValidAmount
                        ? [Color(red: 0.52, green: 0.72, blue: 0.66).opacity(0.94), recordAccent.opacity(0.86)]
                        : [Color.white.opacity(0.76), AppColors.paperWarm.opacity(0.42)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var accessorySaveBorder: some View {
        Capsule(style: .continuous)
            .stroke(hasValidAmount ? Color.white.opacity(0.30) : AppColors.accent.opacity(0.16), lineWidth: 1)
    }

    private func amountPadButton(_ title: String, isAccent: Bool = false, action: @escaping () -> Void) -> some View {
        let foreground = amountPadForeground(isAccent: isAccent)
        let fill = amountPadFill(isAccent: isAccent)
        let stroke = amountPadStroke(isAccent: isAccent)

        return Button(action: action) {
            Text(title)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(fill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(stroke, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 1, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func amountPadForeground(isAccent: Bool) -> Color {
        amountKeyboardTextColor(isAccent: isAccent)
    }

    private func amountDisplayTextColor(isPlaceholder: Bool) -> Color {
        if colorScheme == .dark {
            return isPlaceholder
                ? Color(red: 0.28, green: 0.25, blue: 0.19).opacity(0.64)
                : Color(red: 0.10, green: 0.09, blue: 0.07)
        }
        return isPlaceholder ? AppColors.subtext.opacity(0.46) : recordInk
    }

    private func amountPadFill(isAccent: Bool) -> Color {
        amountKeyboardKeyFill(isAccent: isAccent)
    }

    private func amountPadStroke(isAccent: Bool) -> Color {
        amountKeyboardKeyStroke(isAccent: isAccent)
    }

    private func quickKeyButton(_ title: String, isAccent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            quickKeyButtonLabel(title, isAccent: isAccent)
        }
        .buttonStyle(.plain)
    }

    private func quickKeyButtonLabel(_ title: String, isAccent: Bool) -> some View {
        let foreground = amountKeyboardTextColor(isAccent: isAccent)
        return Text(title)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(quickKeyButtonBackground(isAccent: isAccent))
            .overlay(quickKeyButtonBorder(isAccent: isAccent))
    }

    private func quickKeyButtonBackground(isAccent: Bool) -> some View {
        let fill = amountKeyboardKeyFill(isAccent: isAccent)
        return RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(fill)
    }

    private func quickKeyButtonBorder(isAccent: Bool) -> some View {
        let stroke = amountKeyboardKeyStroke(isAccent: isAccent)
        return RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(stroke, lineWidth: 1)
    }

    private func amountKeyboardTextColor(isAccent: Bool) -> Color {
        if colorScheme == .dark {
            return isAccent
                ? Color(red: 0.47, green: 0.34, blue: 0.12)
                : Color(red: 0.13, green: 0.12, blue: 0.10)
        }
        return isAccent ? recordAccent : recordInk.opacity(0.92)
    }

    private func amountKeyboardKeyFill(isAccent: Bool) -> Color {
        if colorScheme == .dark {
            return isAccent
                ? Color(red: 0.92, green: 0.86, blue: 0.74).opacity(0.94)
                : Color(red: 0.95, green: 0.94, blue: 0.90).opacity(0.96)
        }
        return isAccent ? Color.white.opacity(0.72) : Color.white.opacity(0.92)
    }

    private func amountKeyboardKeyStroke(isAccent: Bool) -> Color {
        if colorScheme == .dark {
            return isAccent
                ? Color(red: 0.58, green: 0.43, blue: 0.17).opacity(0.34)
                : Color.black.opacity(0.12)
        }
        return isAccent ? recordAccent.opacity(0.25) : AppColors.line.opacity(0.76)
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("分类（点一下即可）")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(recordInk.opacity(0.82))

            let recommended = homeViewModel.recordRecommendedCategory
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 100, maximum: 180), spacing: 10)],
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(HomeItem.Category.allCases) { category in
                    categoryChip(category: category, isRecommended: recommended == category)
                }
            }
        }
    }

    private func categoryChip(category: HomeItem.Category, isRecommended: Bool) -> some View {
        let isSelected = homeViewModel.selectedCategory == category
        return Button {
            dismissKeyboard()
            withAnimation(.easeInOut(duration: 0.12)) {
                if !shouldPreserveUserNoteWhenChangingAngle {
                    lastDraftIntent = .category
                    userNoteAnchorTitle = nil
                } else {
                    rememberUserNoteAnchor(homeViewModel.inputTitle)
                }
                activeScenePack = nil
                homeViewModel.selectCategory(category)
                categoryGridExpanded = false
            }
        } label: {
            categoryChipLabel(category: category, isRecommended: isRecommended, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func categoryChipLabel(
        category: HomeItem.Category,
        isRecommended: Bool,
        isSelected: Bool
    ) -> some View {
        let foreground = isSelected ? AppColors.accent.opacity(0.84) : recordInk
        return HStack(spacing: 4) {
            Text(category.displayName)
                .font(.system(size: 14, weight: .medium))
            if isRecommended {
                Text("推荐")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.subtext)
            }
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(categoryChipBackground(isSelected: isSelected))
        .overlay(categoryChipBorder(isSelected: isSelected))
        .scaleEffect(isSelected ? 1.03 : 1.0)
    }

    private func categoryChipBackground(isSelected: Bool) -> some View {
        let fill = isSelected ? AppColors.accent.opacity(0.16) : Color.white.opacity(0.62)
        return Capsule(style: .continuous)
            .fill(fill)
    }

    private func categoryChipBorder(isSelected: Bool) -> some View {
        let stroke = isSelected ? AppColors.accent.opacity(0.45) : Color.white.opacity(0.45)
        return Capsule(style: .continuous)
            .stroke(stroke, lineWidth: 1)
    }

    // MARK: - Note Section

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(
                "",
                text: $homeViewModel.inputTitle,
                prompt: Text("已归类到「\(homeViewModel.selectedCategory.label)」，可补充点细节（不填也能保存）")
                    .foregroundStyle(AppColors.subtext.opacity(0.72))
            )
            .focused($focusedField, equals: .note)
            .submitLabel(.done)
            .onSubmit { dismissKeyboard() }
            .font(.system(size: 16))
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.62))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
            )

            if let message = homeViewModel.recordInputMessage {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext.opacity(0.82))
                    .padding(.horizontal, 2)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(homeViewModel.noteSuggestions(for: homeViewModel.selectedCategory, at: homeViewModel.selectedDate), id: \.self) { suggestion in
                        Button(suggestion) {
                            dismissKeyboard()
                            lastDraftIntent = .category
                            rememberUserNoteAnchor(suggestion)
                            if homeViewModel.inputTitle != suggestion {
                                suppressNextNoteSemanticUnlock = true
                                homeViewModel.inputTitle = suggestion
                            } else {
                                suppressNextNoteSemanticUnlock = false
                            }
                            clearActiveScenePackIfManualNoteMovedAway()
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(recordInk.opacity(0.88))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            Capsule(style: .continuous)
                                .fill(.thinMaterial)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        )
                    }
                }
            }
        }
        .id("recordNoteField")
    }

    // MARK: - Save Row

    private var saveRow: some View {
        Button {
            saveManualRecord()
        } label: {
            ZStack {
                if hasValidAmount {
                    LinearGradient(
                        colors: [
                            Color(red: 0.57, green: 0.75, blue: 0.69).opacity(0.90),
                            recordAccent.opacity(0.78)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(Capsule(style: .continuous))
                } else {
                    LinearGradient(
                        colors: [
                            AppColors.paperWarm.opacity(0.74),
                            AppColors.tracePlaybackButtonBg.opacity(0.46),
                            Color.white.opacity(0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(Capsule(style: .continuous))
                }

                Text("放进账本")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(hasValidAmount ? Color.white.opacity(0.95) : AppColors.accent.opacity(0.66))
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .overlay(
                Capsule(style: .continuous)
                    .stroke(hasValidAmount ? Color.white.opacity(0.26) : AppColors.accent.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: hasValidAmount ? recordAccent.opacity(0.18) : AppColors.accent.opacity(0.06), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .disabled(!hasValidAmount)
        .opacity(1)
        .padding(.top, 6)
    }

    private var recordDateQuietActions: some View {
        HStack {
            Spacer()
            Button {
                dismissKeyboard()
                withAnimation(.easeInOut(duration: 0.2)) {
                    datePanelExpanded.toggle()
                }
            } label: {
                Text(homeViewModel.selectedDate.zhBillDateTime)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(recordAccent.opacity(0.9))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("修改时间，当前 \(homeViewModel.selectedDate.zhBillDateTime)")
            Spacer()
        }
        .padding(.top, -4)
    }

    private var recordDateBinding: Binding<Date> {
        Binding(
            get: { homeViewModel.selectedDate },
            set: { homeViewModel.updateSelectedDate($0, userInitiated: true) }
        )
    }

    private func showScenePackAppliedFeedback(_ pack: ScenePackDefinition) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeInOut(duration: 0.18)) {
            scenePackFeedback = "已换到 \(pack.emoji) \(pack.label)"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
            withAnimation(.easeInOut(duration: 0.18)) {
                if scenePackFeedback?.contains(pack.label) == true {
                    scenePackFeedback = nil
                }
            }
        }
    }

    private func scenePackFeedbackToast(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppColors.text.opacity(0.88))
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(AppColors.accent.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: AppColors.subtext.opacity(0.12), radius: 12, y: 6)
    }

    // MARK: - Member Scene Packs

    @ViewBuilder
    private var memberScenePackSection: some View {
        ScenePackSectionView(
            primaryScenePacks: primaryScenePacks,
            secondaryScenePacks: secondaryScenePacks,
            isExpanded: scenePackExpanded,
            isMoreExpanded: scenePackMoreExpanded,
            isPetMode: settingsViewModel.petCompanionEnabled,
            recordInk: recordInk,
            badgeText: "会员可用",
            onQuickGenerate: {
                dismissKeyboard()
                previewLineWasRotated = true
                lastDraftIntent = .category
                activeScenePack = nil
                homeViewModel.inputTitle = nextCategoryCopyTitle()
            },
            onToggleExpanded: {
                dismissKeyboard()
                withAnimation(.easeInOut(duration: 0.2)) { scenePackExpanded.toggle() }
            },
            onToggleMore: {
                withAnimation(.easeInOut(duration: 0.18)) { scenePackMoreExpanded.toggle() }
            },
            onSelectPack: { pack in
                applyScenePack(pack)
            },
            scenePackDesc: scenePackDesc,
            scenePackReason: scenePackReason
        )
    }

    // MARK: - OCR Form

    private var hasOCRDraftItems: Bool {
        !homeViewModel.ocrDraftItems.isEmpty
    }

    private var isOCRDraftStageVisible: Bool {
        hasOCRDraftItems && !ocrDraftStageDismissed
    }

    @ViewBuilder
    private var ocrForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isOCRDraftStageVisible {
                ocrDraftStageLayer
                    .zIndex(2)

                ocrImportControlsLayer
                    .zIndex(0)
                    .frame(maxHeight: 132, alignment: .top)
                    .clipped()
                    .transition(.opacity.combined(with: .offset(y: -8)))
            } else {
                ocrImportControlsLayer
                    .zIndex(1)

                if hasOCRDraftItems {
                    resumeOCRDraftStageButton
                        .zIndex(1)
                } else {
                    ocrDraftStageLayer
                        .zIndex(0)
                }
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.84), value: isOCRDraftStageVisible)
    }

    private var ocrDraftStageLayer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if hasOCRDraftItems {
                HStack(spacing: 8) {
                    Image(systemName: "tray.full.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("待整理区")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(recordAccent.opacity(0.92))
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(AppColors.panelStrong.opacity(0.82))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.42), lineWidth: 1)
                        )
                )
                .shadow(color: recordAccent.opacity(0.16), radius: 12, y: 5)
                .transition(.opacity.combined(with: .offset(y: 6)))
            }

            OCRDraftPanel(
                items: homeViewModel.ocrDraftItems,
                onToggleResolved: { id, isResolved in homeViewModel.updateOCRDraftStatus(id: id, isResolved: isResolved) },
                onCategoryChange: { id, category in homeViewModel.updateOCRDraftCategory(id: id, category: category) },
                onAmountChange: { id, amount in homeViewModel.updateOCRDraftAmount(id: id, amount: amount) },
                onTitleCommit: { id, title in homeViewModel.updateOCRDraftTitle(id: id, title: title) },
                onUpdateItem: { item in _ = homeViewModel.updateItem(item) },
                onDelete: { id in homeViewModel.deleteOCRDraftItem(id: id) },
                onClearResolved: homeViewModel.clearResolvedOCRDrafts,
                onClose: { ocrDraftStageDismissed = true }
            )
        }
        .padding(.top, isOCRDraftStageVisible ? 0 : 6)
        .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .top)))
    }

    private var resumeOCRDraftStageButton: some View {
            Button {
                withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86)) {
                    ocrDraftStageDismissed = false
                }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "tray.full.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(recordAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("继续整理 \(homeViewModel.ocrDraftItems.count) 笔")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.text)
                    Text("关闭只是收起，待整理账单还在。")
                        .font(.footnote)
                        .foregroundStyle(AppColors.subtext)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppColors.subtext)
            }
            .frame(minHeight: 44)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.70))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppColors.accent.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var ocrImportControlsLayer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                dismissKeyboard()
                selectedEntryMode = .manual
            } label: {
                Text("回到手动记录 →")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppColors.subtext)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)

            Text("导入微信/支付宝账单列表或单笔详情截图，识别后先确认，再写入账单。")
                .font(.subheadline)
                .foregroundStyle(AppColors.subtext)

            Text("请保证每笔完整在画面内，上下留一点边；首尾笔被裁切可能漏识别。")
                .font(.footnote)
                .foregroundStyle(AppColors.subtext)

            PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                Label("导入账单截图", systemImage: "photo")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(
                        LinearGradient(
                            colors: [recordAccent.opacity(0.92), recordAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .shadow(color: recordAccent.opacity(0.25), radius: 8, y: 4)
            }
            .disabled(isOCRRecognizing)

            if isOCRRecognizing {
                ComputationLoadingView(
                    message: "正在辨认账单里的每一笔…",
                    detail: "识别完成后会先给你确认，不会直接写入",
                    presentation: .card,
                    progress: ocrProgress
                )
            }

            #if DEBUG
            Button("使用演示 OCR 结果") {
                ocrConfirmDrafts = homeViewModel.makeDemoOCRDrafts()
                showOCRConfirmSheet = true
            }
            .font(.system(size: 14))
            .foregroundStyle(recordAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(recordAccent.opacity(0.5), lineWidth: 1)
            )
            #endif

            if !homeViewModel.ocrStatus.isEmpty {
                Text(homeViewModel.ocrStatus)
                    .font(.system(
                        .footnote,
                        design: .default,
                        weight: isOCRQuotaExhausted ? .semibold : .regular
                    ))
                    .foregroundStyle(isOCRQuotaExhausted ? recordAccent : AppColors.subtext)
                    .padding(.top, 4)
                    .accessibilityLabel("识别状态，\(homeViewModel.ocrStatus)")
            }

            if shouldShowOCRQuotaUpsell {
                ocrQuotaUpsellCard
                    .padding(.top, 2)
                    .onAppear {
                        markOCRQuotaUpsellShown()
                    }
            }
        }
        .padding(isOCRDraftStageVisible ? 12 : 0)
        .background(ocrSecondaryLayerBackground)
        .scaleEffect(reduceMotion ? 1 : (isOCRDraftStageVisible ? 0.92 : 1), anchor: .top)
        .offset(y: reduceMotion ? 0 : (isOCRDraftStageVisible ? -6 : 0))
        .opacity(isOCRDraftStageVisible ? 0.28 : 1)
        .saturation(isOCRDraftStageVisible ? 0.62 : 1)
        .allowsHitTesting(!isOCRDraftStageVisible)
    }

    private var ocrSecondaryLayerBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(isOCRDraftStageVisible ? AppColors.panelStrong.opacity(0.34) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isOCRDraftStageVisible ? AppColors.line.opacity(0.30) : Color.clear, lineWidth: 1)
            )
    }

    private var ocrQuotaUpsellCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(recordAccent)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(recordAccent.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(ExperienceRuleCopy.ocrUpsellHeadline)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.text)
                    Text(ExperienceRuleCopy.ocrUpsellDetail)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.subtext)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 6)

                Button {
                    dismissOCRQuotaUpsell()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppColors.subtext)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭会员提示")
            }

            Button {
                dismissOCRQuotaUpsell()
                onShowMemberPricing?(.ocrImport)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "crown")
                        .font(.system(size: 13, weight: .semibold))
                    Text(ExperienceRuleCopy.ocrUpsellCTA)
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(recordAccent)
                )
            }
            .buttonStyle(.plain)
            .accessibilityHint("打开会员页继续使用账单识别")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(recordAccent.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(recordAccent.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Amount helpers

    private func appendAmountKey(_ key: String) {
        var value = homeViewModel.inputAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        if key == "." {
            guard !value.contains(".") else { return }
            homeViewModel.inputAmount = value.isEmpty ? "0." : value + "."
            return
        }

        if value == "0" {
            value = ""
        }
        let next = value + key
        guard isValidAmountDraft(next) else { return }
        homeViewModel.inputAmount = next
    }

    private func deleteAmountKey() {
        guard !homeViewModel.inputAmount.isEmpty else { return }
        homeViewModel.inputAmount.removeLast()
    }

    private func isValidAmountDraft(_ value: String) -> Bool {
        guard value.count <= 9 else { return false }
        if let dotIndex = value.firstIndex(of: ".") {
            let decimals = value[value.index(after: dotIndex)...]
            return decimals.count <= 2
        }
        return true
    }

    private func applyAmountDelta(_ delta: Double) {
        let base = Double(homeViewModel.inputAmount.replacingOccurrences(of: ",", with: "")) ?? 0
        let next = max(0, base + delta)
        homeViewModel.inputAmount = String(format: "%.2f", next)
    }

    private func applyDot00() {
        let base = Double(homeViewModel.inputAmount.replacingOccurrences(of: ",", with: "")) ?? 0
        homeViewModel.inputAmount = String(format: "%.2f", base)
    }
}

private struct RecordEntryPanel: ViewModifier {
    var radius: CGFloat = 24
    var padding: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .appSurface(.record, radius: radius, padding: padding, tint: AppColors.accent)
    }
}

private extension View {
    func recordEntryPanel(radius: CGFloat = 24, padding: CGFloat = 24) -> some View {
        modifier(RecordEntryPanel(radius: radius, padding: padding))
    }
}
