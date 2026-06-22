import SwiftUI
import PhotosUI
import UIKit

struct RecordView: View {
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @Environment(\.colorScheme) private var colorScheme
    var onSaved: (() -> Void)? = nil
    var onShowMemberPricing: (() -> Void)? = nil
    @State private var selectedEntryMode: EntryMode = .manual
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isOCRRecognizing = false
    @State private var ocrProgress = 0.0
    @State private var ocrConfirmDrafts: [OCRReceiptDraft] = []
    @State private var showOCRConfirmSheet = false
    @State private var didImportOCRConfirmSheet = false
    @State private var scenePackExpanded = false
    @State private var scenePackVariants: [String: Int] = [:]
    @State private var amountPadActive = false
    @State private var recordDetailsExpanded = false
    @State private var categoryGridExpanded = false
    @State private var noteEditorExpanded = false
    @State private var datePanelExpanded = false
    @State private var previewLineWasRotated = false
    @State private var showScenePackAngleSheet = false
    @State private var activeScenePack: ScenePackDefinition?
    @State private var scenePackFeedback: String?
    @State private var didAutoFocusAmountPad = false
    @State private var lastDraftIntent: RecordDraftIntent = .automatic
    @State private var freeScenePackRefreshToken = 0
    @State private var freeLockedSceneHint: ScenePackAngleSheet.LockedSceneHint?
    @State private var ocrQuotaUpsellVisibleThisSession = false
    @AppStorage("scene_pack_order_v1") private var scenePackOrderStorage = ""
    @AppStorage("scene_pack_more_expanded_v1") private var scenePackMoreExpanded = false
    @AppStorage("scene_pack_usage_v1") private var scenePackUsageStorage = ""
    @AppStorage("scene_pack_pinned_v1") private var scenePackPinnedStorage = ""
    @AppStorage("ocr_import_member_upsell_last_shown_at") private var ocrImportMemberUpsellLastShownAt = 0.0
    @FocusState private var focusedField: RecordField?

    private enum RecordField {
        case amount
        case note
    }

    private enum RecordDraftIntent {
        case automatic
        case note
        case category
    }

    private let draftClock = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    private let recordAccent = AppColors.accent
    private let recordInk = AppColors.text
    private let freeScenePackService = FreeScenePackService.shared
    private let dailyQuotaStore = DailyFeatureQuotaStore()
    private let extensionScenePackIds: Set<String> = ["travel", "family"]
    private let scenePackSilenceInterval: TimeInterval = 45 * 24 * 60 * 60
    private let ocrImportUpsellCooldown: TimeInterval = 3 * 24 * 60 * 60

    private struct ScenePackUsageStat {
        var count: Int
        var lastUsedAt: TimeInterval
    }

    private var visibleScenePacks: [ScenePackDefinition] {
        let orderIds = scenePackOrderIds
        return ScenePackCopyPool.definitions.sorted { lhs, rhs in
            scenePackSortRank(lhs, orderIds: orderIds) < scenePackSortRank(rhs, orderIds: orderIds)
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

    private var freeMoreScenePacks: [ScenePackDefinition] {
        let freeIds = Set(freeScenePacks.map(\.id))
        return visibleScenePacks.filter { !freeIds.contains($0.id) }
    }

    private var freeReplaceableScenePacks: [ScenePackDefinition] {
        _ = freeScenePackRefreshToken
        return freeScenePackService.replaceableCandidates(from: visibleScenePacks)
    }

    private var freeScenePackIds: Set<String> {
        Set(freeScenePacks.map(\.id))
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

    private func scenePackSortRank(_ pack: ScenePackDefinition, orderIds: [String]) -> Int {
        if let index = orderIds.firstIndex(of: pack.id) {
            return index
        }
        let defaultIndex = ScenePackCopyPool.definitions.firstIndex { $0.id == pack.id } ?? 999
        return 1_000 + defaultIndex
    }

    private func promoteScenePack(_ pack: ScenePackDefinition) {
        var orderIds = scenePackOrderIds.filter { $0 != pack.id }
        orderIds.insert(pack.id, at: 0)
        scenePackOrderStorage = orderIds.prefix(12).joined(separator: ",")
    }

    private func reorderScenePacks(orderedPackIds: [String], movedPackIds: Set<String>) {
        guard !orderedPackIds.isEmpty else { return }
        let orderedSet = Set(orderedPackIds)
        var orderedIterator = orderedPackIds.makeIterator()
        let allVisibleIds = visibleScenePacks.map(\.id)
        let reorderedIds = allVisibleIds.map { id in
            orderedSet.contains(id) ? (orderedIterator.next() ?? id) : id
        }
        scenePackOrderStorage = reorderedIds.prefix(12).joined(separator: ",")

        let movedExtensionIds = movedPackIds.intersection(extensionScenePackIds)
        guard !movedExtensionIds.isEmpty else { return }
        let movedOrderedIds = orderedPackIds.filter { movedExtensionIds.contains($0) }
        var pinnedIds = scenePackPinnedIds.filter { !movedExtensionIds.contains($0) }
        pinnedIds.insert(contentsOf: movedOrderedIds, at: 0)
        scenePackPinnedStorage = pinnedIds.prefix(12).joined(separator: ",")
    }

    private func shouldFoldScenePack(_ pack: ScenePackDefinition) -> Bool {
        guard extensionScenePackIds.contains(pack.id) else { return false }
        if scenePackPinnedIds.contains(pack.id) { return false }
        guard let stat = scenePackUsageStats[pack.id] else { return true }
        if stat.count >= 3 { return false }
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
        if !petName.isEmpty, text.contains(petName) { return true }
        let keywords = ["宠物", "猫粮", "狗粮", "猫砂", "狗窝", "猫窝", "牵引绳", "冻干", "驱虫", "宠物医院", "洗护美容", "毛孩子", "毛孩"]
        return keywords.contains { text.contains($0) }
    }

    private func containsBabyKeyword(_ text: String) -> Bool {
        let keywords = ["宝宝", "孩子", "婴儿", "奶粉", "尿不湿", "纸尿裤", "辅食", "湿巾", "童装", "早教", "儿童座椅", "推车"]
        return keywords.contains { text.contains($0) }
    }

    private func containsFitnessKeyword(_ text: String) -> Bool {
        let keywords = ["运动", "健身", "锻炼", "训练", "跑步", "瑜伽", "游泳", "球场", "私教", "护具", "运动鞋", "运动服", "健身卡", "健身房"]
        return keywords.contains { text.contains($0) }
    }

    private func lockedSceneHintTitle(for pack: ScenePackDefinition) -> String {
        switch pack.id {
        case "travel":
            return "这笔更像出去玩订酒店买票"
        case "family":
            return "这笔更像娃和毛孩的补给站"
        case "care":
            return "这笔更像看病买药健身恢复"
        default:
            return "这笔可以换个生活角度"
        }
    }

    private func lockedSceneHintDetail(for pack: ScenePackDefinition) -> String {
        switch pack.id {
        case "travel":
            return "会员可直接换到出去玩这一包，把路费、住宿和门票放回同一段行程里。"
        case "family":
            return "会员可直接换到娃和毛孩这一包，奶粉尿不湿、宠物粮猫砂和洗护就医都能放回照护场景。"
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
        lastDraftIntent = .category
        if trackMemberSceneUsage {
            promoteScenePack(pack)
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
            allowTravelSpecificCopy: !keepSelectedCategory || containsTravelKeyword(homeViewModel.inputTitle)
        )
        if !keepSelectedCategory {
            activeScenePack = pack
            homeViewModel.applyScenePackDraft(title: title, category: pack.category)
        } else {
            activeScenePack = nil
            homeViewModel.inputTitle = title
        }
        if !keepSelectedCategory {
            showScenePackAppliedFeedback(pack)
        }
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

    enum EntryMode: String, CaseIterable, Identifiable {
        case manual = "手动录入"
        case ocr = "智能导入"
        var id: String { rawValue }
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
        homeViewModel.categoryLockedByUser && lastDraftIntent != .note
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
                source: "preview"
            )
        )
    }

    private var previewEmotion: String {
        if shouldUseNeutralRemarkFallback {
            return ""
        }
        return previewDraftResolution?.emotionTag ?? ""
    }

    private var previewLifeMarkText: String? {
        guard previewTier == .confirm, hasValidAmount else { return nil }
        let category = previewDraftResolution?.category ?? homeViewModel.selectedCategory
        let rawTitle = homeViewModel.inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = rawTitle.isEmpty ? previewHeadline : rawTitle
        let draft = HomeItem(
            title: title,
            amount: inputAmountValue,
            category: category,
            createdAt: homeViewModel.selectedDate,
            emotionTag: previewEmotion,
            merchantBrandId: previewBrand?.id
        )
        guard let mark = LifeMarkService.aggregates(
            for: [draft],
            allItems: homeViewModel.items + [draft],
            isMember: isMember,
            limit: 1
        ).first else {
            return nil
        }
        switch mark.kind {
        case .milestone, .context, .streak:
            return "生活印记 · \(mark.title)"
        case .scene:
            return "会进入「\(mark.label)」印记"
        }
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
        let brandId = MerchantBrandCatalog.matchBrand(in: title)?.id
        let draft = HomeItem(
            title: title,
            amount: inputAmountValue,
            category: homeViewModel.selectedCategory,
            createdAt: homeViewModel.selectedDate,
            emotionTag: previewEmotion,
            merchantBrandId: brandId,
            userEditedTitle: true
        )
        return EchoAnchorService.shared.isEligibleLifeTraceTitle(title, item: draft)
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
            scenePackId: activeScenePack?.category == homeViewModel.selectedCategory ? activeScenePack?.id : nil
        )
        guard didSave else {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.84)) {
                recordDetailsExpanded = true
                noteEditorExpanded = true
            }
            return
        }
        recordDetailsExpanded = false
        categoryGridExpanded = false
        noteEditorExpanded = false
        datePanelExpanded = false
        lastDraftIntent = .automatic
        onSaved?()
    }

    private func previewFallbackTitle(for category: HomeItem.Category) -> String {
        RecordSemanticLexicon.fallbackTitle(
            for: category,
            amount: inputAmountValue,
            date: homeViewModel.selectedDate
        )
    }

    private func baseScenePack(for category: HomeItem.Category) -> ScenePackDefinition? {
        let packId: String?
        switch category {
        case .dining: packId = "food"
        case .transport: packId = "commute"
        case .shopping: packId = "shopping"
        case .lodging: packId = "travel"
        case .health: packId = "care"
        case .home: packId = "home"
        case .social: packId = "social"
        case .daily: packId = "supply"
        case .entertainment, .other: packId = nil
        }
        guard let packId else { return nil }
        return visibleScenePacks.first { $0.id == packId }
    }

    private func nextCategoryCopyTitle() -> String {
        let amount = inputAmountValue
        let category = homeViewModel.selectedCategory
        let variantKey = categoryCopyVariantKey(
            category: category,
            amount: amount,
            date: homeViewModel.selectedDate
        )
        let variant = scenePackVariants[variantKey, default: 0]
        scenePackVariants[variantKey] = variant + 1

        if let pack = baseScenePack(for: category) {
            return ScenePackCopyPool.note(
                for: pack,
                amount: amount,
                date: homeViewModel.selectedDate,
                categoryContext: category,
                petName: settingsViewModel.petNickname,
                historyItems: homeViewModel.items,
                allowPetCopy: settingsViewModel.petCompanionEnabled,
                variant: variant,
                allowTravelSpecificCopy: containsTravelKeyword(homeViewModel.inputTitle)
            )
        }

        return genericCategoryCopy(
            for: category,
            amount: amount,
            date: homeViewModel.selectedDate,
            variant: variant
        )
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
        case .daily:
            notes = amount <= 50
                ? ["日用小补给", "日常小物补上", "刚好需要的小东西", "小补给记下来", "常用的先补一点", "便利袋里的一点日常"]
                : ["日常用品补齐", "把常用的补上", "日用品换新一点", "这笔给日常用品", "常用物件买回来了", "日常安排记一笔"]
        case .entertainment:
            notes = ["这次放松安排", "给自己留点轻松", "娱乐小消费记下", "这一段休闲时间", "放松一下也记下", "今天的娱乐安排"]
        case .other:
            notes = ["这笔先放进账本", "日常小记录", "临时花了一笔", "这一笔先记下", "单独记录一下", "今天补上一笔", "小额支出记下", "这笔记录已放好"]
        default:
            notes = [previewFallbackTitle(for: category)]
        }
        guard !notes.isEmpty else { return previewFallbackTitle(for: category) }
        return notes[variant % notes.count]
    }

    private func handlePreviewQuickAction() {
        dismissKeyboard()
        guard hasValidAmount else { return }
        guard isMember else {
            withAnimation(.easeInOut(duration: 0.2)) {
                recordDetailsExpanded = true
                noteEditorExpanded = true
            }
            return
        }
        refreshRecommendedCategory()
        previewLineWasRotated = true
        lastDraftIntent = .category
        activeScenePack = nil
        homeViewModel.inputTitle = nextCategoryCopyTitle()
    }

    private func handleFreePreviewQuickAction() {
        dismissKeyboard()
        guard hasValidAmount else { return }

        refreshRecommendedCategory()
        previewLineWasRotated = true
        lastDraftIntent = .category
        activeScenePack = nil

        if let pack = preferredFreeScenePack() {
            applyScenePack(pack, keepSelectedCategory: true, trackMemberSceneUsage: false)
            return
        }

        let amount = inputAmountValue
        let category = homeViewModel.selectedCategory
        let variantKey = categoryCopyVariantKey(
            category: category,
            amount: amount,
            date: homeViewModel.selectedDate
        )
        let variant = scenePackVariants[variantKey, default: 0]
        scenePackVariants[variantKey] = variant + 1
        homeViewModel.inputTitle = genericCategoryCopy(
            for: category,
            amount: amount,
            date: homeViewModel.selectedDate,
            variant: variant
        )
    }

    private func openFreeScenePackAngleSheet() {
        dismissKeyboard()
        prepareFreeLockedSceneHintIfNeeded()
        showScenePackAngleSheet = true
    }

    private func preferredFreeScenePack() -> ScenePackDefinition? {
        let packs = freeScenePacks
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

    private func refreshRecommendedCategory() {
        guard selectedEntryMode == .manual else { return }
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
                    lastDraftIntent = .note
                    homeViewModel.preferNoteSemanticsForCurrentDraft()
                }
                homeViewModel.clearRecordInputMessage()
                refreshRecommendedCategory()
            }
            .onChange(of: homeViewModel.selectedDate) { _, _ in
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
                }
            }
            .onReceive(draftClock) { now in
                guard selectedEntryMode == .manual else { return }
                homeViewModel.refreshDraftSelectedDate(now: now)
            }
            .onAppear {
                freeScenePackService.recordFirstOpenIfNeeded()
                homeViewModel.refreshDraftSelectedDate(force: true)
                guard !didAutoFocusAmountPad else { return }
                didAutoFocusAmountPad = true
                focusAmountPad()
            }
            .sheet(isPresented: $showOCRConfirmSheet) {
                OCRConfirmSheet(drafts: ocrConfirmDrafts) { selectedDrafts in
                    let importedCount = homeViewModel.importOCRDrafts(selectedDrafts, isMember: isMember)
                    if importedCount > 0 {
                        didImportOCRConfirmSheet = true
                    }
                    return importedCount
                }
            }
            .sheet(isPresented: $showScenePackAngleSheet) {
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
                            applyScenePack(pack, keepSelectedCategory: true, trackMemberSceneUsage: false)
                        },
                        onReplaceFreePack: { slot, oldId, newPack in
                            freeScenePackService.replacePack(atSlot: slot, oldId: oldId, newId: newPack.id, from: visibleScenePacks)
                            freeScenePackRefreshToken += 1
                        },
                        onShowMemberPricing: {
                            onShowMemberPricing?()
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
            Text("把一笔生活放进账本")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.accent.opacity(0.78))

            Text("记下这一笔")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(recordInk)

            Text(hasAmountDraft ? "这一笔会先落到账本，再长成回望。" : "先敲金额，分类和备注会跟着浮出来。")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: 17, alignment: .leading)
        }
    }

    private var recordModeSegment: some View {
        HStack(spacing: 4) {
            ForEach(EntryMode.allCases) { mode in
                recordModeButton(mode)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.25))
        )
    }

    private func recordModeButton(_ mode: EntryMode) -> some View {
        let isSelected = selectedEntryMode == mode
        return Button {
            dismissKeyboard()
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedEntryMode = mode
            }
            if mode == .manual {
                focusAmountPad(delay: 0.12)
            }
        } label: {
            recordModeLabel(mode, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func recordModeLabel(_ mode: EntryMode, isSelected: Bool) -> some View {
        let weight: Font.Weight = isSelected ? .semibold : .regular
        let shadow = isSelected ? Color.black.opacity(0.08) : Color.clear
        return Text(mode.rawValue)
            .font(.system(size: 15, weight: weight))
            .foregroundStyle(recordInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
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
            ocrSideDoor
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
        homeViewModel.frequentRecordAmountSuggestions(at: homeViewModel.selectedDate)
    }

    private var lifeEntryPreview: some View {
        LifeEntryPreviewCard(
            tier: previewTier,
            headline: previewHeadline,
            hint: previewHint,
            learningHint: homeViewModel.recordLearningHint,
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

    private var ocrSideDoor: some View {
        Button {
            dismissKeyboard()
            selectedEntryMode = .ocr
        } label: {
            Text("有账单截图？从截图导入 →")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.subtext.opacity(0.86))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
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
    }

    @ViewBuilder
    private var expandedDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            if categoryGridExpanded { categorySection }
            if noteEditorExpanded { noteSection }
        }
    }

    private var recordDetailsFold: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                dismissKeyboard()
                withAnimation(.easeInOut(duration: 0.2)) {
                    recordDetailsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("补充细节")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(recordInk.opacity(0.88))
                        Text("不急，想补再补。")
                            .font(.system(size: 11))
                            .foregroundStyle(AppColors.subtext.opacity(0.78))
                    }
                    Spacer()
                    Image(systemName: recordDetailsExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppColors.subtext.opacity(0.72))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.54))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.46), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if recordDetailsExpanded {
                HStack(spacing: 8) {
                    detailToggleButton("改分类", isActive: categoryGridExpanded) {
                        withAnimation(.easeInOut(duration: 0.16)) { categoryGridExpanded.toggle() }
                    }
                    detailToggleButton("写点细节", isActive: noteEditorExpanded) {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            noteEditorExpanded.toggle()
                            if noteEditorExpanded {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                                    focusedField = .note
                                }
                            }
                        }
                    }
                }

                if categoryGridExpanded { categorySection }
                if noteEditorExpanded { noteSection }
            }
        }
    }

    private func detailToggleButton(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            dismissKeyboard()
            action()
        }) {
            detailToggleLabel(title, isActive: isActive)
        }
        .buttonStyle(.plain)
    }

    private func detailToggleLabel(_ title: String, isActive: Bool) -> some View {
        let foreground = isActive ? AppColors.accent.opacity(0.9) : recordInk.opacity(0.78)
        return Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(detailToggleBackground(isActive: isActive))
            .overlay(detailToggleBorder(isActive: isActive))
    }

    private func detailToggleBackground(isActive: Bool) -> some View {
        let fill = isActive ? AppColors.accent.opacity(0.12) : Color.white.opacity(0.58)
        return Capsule(style: .continuous)
            .fill(fill)
    }

    private func detailToggleBorder(isActive: Bool) -> some View {
        let stroke = isActive ? AppColors.accent.opacity(0.25) : Color.white.opacity(0.48)
        return Capsule(style: .continuous)
            .stroke(stroke, lineWidth: 1)
    }

    // MARK: - Amount Field

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            amountStage
            if !hasAmountDraft, !recordWarmupSuggestions.isEmpty {
                amountWarmupChips
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Text(hasValidAmount ? "金额只是刻度，这一笔会长成一句生活记录。" : emptyAmountWhisper)
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext.opacity(0.76))
                .frame(maxWidth: .infinity, alignment: hasAmountDraft ? .leading : .center)
                .multilineTextAlignment(hasAmountDraft ? .leading : .center)
        }
    }

    private var amountWarmupChips: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("常记金额")
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
            "先从数字开始，这一笔就有了位置。",
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
                .frame(width: 42, height: 34)
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

            let recommended = homeViewModel.recommendCategory(for: homeViewModel.inputAmount)
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
                lastDraftIntent = .category
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
                            lastDraftIntent = .note
                            homeViewModel.preferNoteSemanticsForCurrentDraft()
                            homeViewModel.inputTitle = suggestion
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

    @ViewBuilder
    private var ocrForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                dismissKeyboard()
                selectedEntryMode = .manual
            } label: {
                Text("回到手动记一笔 →")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.subtext.opacity(0.86))
            }
            .buttonStyle(.plain)

            Text("导入微信/支付宝账单列表或单笔详情截图，识别后先确认，再写入账单。")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.subtext)

            Text("请保证每笔完整在画面内，上下留一点边；首尾笔被裁切可能漏识别。")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext.opacity(0.86))

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
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: ocrProgress)
                        .tint(recordAccent)
                    Text("正在识别账单，请稍候…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.subtext)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.68))
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
                    .font(.system(size: 12, weight: isOCRQuotaExhausted ? .semibold : .regular))
                    .foregroundStyle(isOCRQuotaExhausted ? recordAccent : AppColors.subtext)
                    .padding(.top, 4)
            }

            if shouldShowOCRQuotaUpsell {
                ocrQuotaUpsellCard
                    .padding(.top, 2)
                    .onAppear {
                        markOCRQuotaUpsellShown()
                    }
            }

            OCRDraftPanel(
                items: homeViewModel.ocrDraftItems,
                onToggleResolved: { id, isResolved in homeViewModel.updateOCRDraftStatus(id: id, isResolved: isResolved) },
                onCategoryChange: { id, category in homeViewModel.updateOCRDraftCategory(id: id, category: category) },
                onAmountChange: { id, amount in homeViewModel.updateOCRDraftAmount(id: id, amount: amount) },
                onDelete: { id in homeViewModel.deleteOCRDraftItem(id: id) },
                onClearResolved: homeViewModel.clearResolvedOCRDrafts,
                onResolveAllPending: homeViewModel.resolveAllPendingOCRDrafts
            )
            .padding(.top, 6)
        }
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
                    Text("今日免费导入已用完")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.text)
                    Text("明天会刷新 3 次。经常导入微信/支付宝截图的话，会员可连续整理，不用被次数打断。")
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
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }

            Button {
                dismissOCRQuotaUpsell()
                onShowMemberPricing?()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "crown")
                        .font(.system(size: 13, weight: .semibold))
                    Text("开通会员，连续导入")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(recordAccent)
                )
            }
            .buttonStyle(.plain)
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
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColors.tracePlaybackButtonBg.opacity(0.48),
                                AppColors.paperWarm.opacity(0.50),
                                Color.white.opacity(0.72)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(.thinMaterial)
                    )
            )
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(AppColors.accent.opacity(0.24))
                    .frame(width: 34, height: 3)
                    .padding(.top, 16)
                    .padding(.leading, 22)
                    .allowsHitTesting(false)
            }
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.58),
                                AppColors.accent.opacity(0.16),
                                AppColors.paperBorder.opacity(0.16)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            )
            .shadow(color: AppColors.accent.opacity(0.08), radius: 24, x: 0, y: 10)
            .shadow(color: Color(red: 128/255, green: 106/255, blue: 82/255).opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

private extension View {
    func recordEntryPanel(radius: CGFloat = 24, padding: CGFloat = 24) -> some View {
        modifier(RecordEntryPanel(radius: radius, padding: padding))
    }
}
