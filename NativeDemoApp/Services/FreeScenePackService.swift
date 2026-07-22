import Foundation

struct LifeMarkSceneReward: Identifiable, Codable, Equatable {
    let id: String
    let groupId: String
    let packId: String
    let title: String
    let detail: String
    let createdAt: TimeInterval
    let expiresAt: TimeInterval
}

struct LifeMarkSceneRewardPrompt: Identifiable, Equatable {
    enum Kind: Equatable {
        case reward(LifeMarkSceneReward)
        case coldStart
    }

    let id: String
    let title: String
    let badge: String
    let detail: String
    let primaryTitle: String
    let secondaryTitle: String
    let kind: Kind
}

struct LifeMarkSceneRewardPreparationInput: @unchecked Sendable {
    let item: HomeItem
    let allItems: [HomeItem]
    let currentPackIds: Set<String>
    let definitions: [ScenePackDefinition]
    let isMember: Bool
}

enum LifeMarkSceneRewardPreparationResult: @unchecked Sendable {
    case reward(LifeMarkSceneReward)
    case coldStart
    case none
}

final class LifeMarkSceneRewardService: @unchecked Sendable {
    static let shared = LifeMarkSceneRewardService()

    private struct RewardCandidate {
        let groupId: String
        let packId: String
        let keywords: [String]
        let title: String
        let detail: String
    }

    private let defaults: UserDefaults
    private let now: () -> Date
    private let rewardDecisionLock = NSLock()

    private let pendingKey = "life_mark_scene_reward_pending_v1"
    private let activeKey = "life_mark_scene_reward_active_v1"
    private let claimedGroupsKey = "life_mark_scene_reward_claimed_groups_v1"
    private let coldStartGuideSeenKey = "life_mark_scene_reward_cold_start_seen_v1"
    private let lastRewardCreatedDayKey = "life_mark_scene_reward_last_created_day_v1"
    private let rewardDuration: TimeInterval = 7 * 24 * 60 * 60

    init(
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.now = now
    }

    func pendingReward(from definitions: [ScenePackDefinition]) -> LifeMarkSceneReward? {
        guard let reward = decodeReward(forKey: pendingKey),
              definitions.contains(where: { $0.id == reward.packId }) else { return nil }
        return reward
    }

    func activeReward(from definitions: [ScenePackDefinition]) -> LifeMarkSceneReward? {
        guard let reward = decodeReward(forKey: activeKey),
              definitions.contains(where: { $0.id == reward.packId }) else { return nil }
        guard now().timeIntervalSince1970 < reward.expiresAt else {
            defaults.removeObject(forKey: activeKey)
            return nil
        }
        return reward
    }

    func prepareRewardDecision(
        _ input: LifeMarkSceneRewardPreparationInput
    ) -> LifeMarkSceneRewardPreparationResult {
        rewardDecisionLock.lock()
        defer { rewardDecisionLock.unlock() }
        guard !input.isMember else { return .none }
        if let reward = registerRewardIfNeeded(
            for: input.item,
            allItems: input.allItems,
            currentPackIds: input.currentPackIds,
            definitions: input.definitions,
            isMember: input.isMember
        ) {
            return .reward(reward)
        }
        if shouldShowColdStartGuide(
            after: input.item,
            allItems: input.allItems,
            isMember: input.isMember
        ) {
            return .coldStart
        }
        return .none
    }

    @discardableResult
    func registerRewardIfNeeded(
        for item: HomeItem,
        allItems: [HomeItem],
        currentPackIds: Set<String>,
        definitions: [ScenePackDefinition],
        isMember: Bool
    ) -> LifeMarkSceneReward? {
        guard !isMember else { return nil }
        guard pendingReward(from: definitions) == nil else { return nil }
        let active = activeReward(from: definitions)
        let claimedGroups = claimedGroupIds()
        let currentDayKey = dayKey(for: now())
        guard defaults.string(forKey: lastRewardCreatedDayKey) != currentDayKey else { return nil }
        guard let candidate = rewardCandidate(for: item) else { return nil }
        guard !currentPackIds.contains(candidate.packId) else { return nil }
        guard active?.groupId != candidate.groupId else { return nil }
        guard !claimedGroups.contains(candidate.groupId) else { return nil }
        guard definitions.contains(where: { $0.id == candidate.packId }) else { return nil }
        guard isFirstStrongLifeMark(item: item, allItems: allItems, candidate: candidate) else { return nil }

        let current = now().timeIntervalSince1970
        let reward = LifeMarkSceneReward(
            id: "\(candidate.groupId)_\(Int(current))",
            groupId: candidate.groupId,
            packId: candidate.packId,
            title: candidate.title,
            detail: candidate.detail,
            createdAt: current,
            expiresAt: current + rewardDuration
        )
        encodeReward(reward, forKey: pendingKey)
        defaults.set(currentDayKey, forKey: lastRewardCreatedDayKey)
        return reward
    }

    @discardableResult
    func claimReward(_ reward: LifeMarkSceneReward, from definitions: [ScenePackDefinition]) -> LifeMarkSceneReward? {
        guard definitions.contains(where: { $0.id == reward.packId }) else { return nil }
        var claimedGroups = claimedGroupIds()
        claimedGroups.insert(reward.groupId)
        defaults.set(Array(claimedGroups).sorted(), forKey: claimedGroupsKey)

        let current = now().timeIntervalSince1970
        let active = LifeMarkSceneReward(
            id: reward.id,
            groupId: reward.groupId,
            packId: reward.packId,
            title: reward.title,
            detail: reward.detail,
            createdAt: current,
            expiresAt: current + rewardDuration
        )
        encodeReward(active, forKey: activeKey)
        defaults.removeObject(forKey: pendingKey)
        return active
    }

    func shouldShowColdStartGuide(
        after item: HomeItem,
        allItems: [HomeItem],
        isMember: Bool
    ) -> Bool {
        guard !isMember, !defaults.bool(forKey: coldStartGuideSeenKey) else { return false }
        let currentContext = LifeMarkService.prepareAggregationContext(
            allItems: allItems,
            periodItems: [item]
        )
        let currentMarks = LifeMarkService.aggregates(
            for: [item],
            preparedContext: currentContext,
            isMember: true,
            limit: 1
        )
        guard !currentMarks.isEmpty else { return false }
        let previousItems = allItems.filter { $0.id != item.id }
        let previousContext = LifeMarkService.prepareAggregationContext(
            allItems: previousItems,
            periodItems: previousItems
        )
        let previousMarks = LifeMarkService.aggregates(
            for: previousItems,
            preparedContext: previousContext,
            isMember: true,
            limit: 1
        )
        return previousMarks.isEmpty
    }

    func markColdStartGuideSeen() {
        defaults.set(true, forKey: coldStartGuideSeenKey)
    }

    private func rewardCandidate(for item: HomeItem) -> RewardCandidate? {
        let text = semanticText(for: item)
        if SemanticBoundaryGuard.matchesBabySupply(text) {
            return RewardCandidate(
                groupId: "family_baby",
                packId: "family",
                keywords: SemanticBoundaryGuard.babyStrongKeywords,
                title: "宝宝照护这条线开始了",
                detail: "奖励体验「娃和毛孩」场景包 7 天，把奶粉、尿不湿和照护用品放到同一条生活线里。"
            )
        }
        if SemanticBoundaryGuard.matchesPetSupply(text) {
            return RewardCandidate(
                groupId: "family_pet",
                packId: "family",
                keywords: SemanticBoundaryGuard.petStrongKeywords,
                title: "毛孩子照护这条线开始了",
                detail: "奖励体验「娃和毛孩」场景包 7 天，把口粮、猫砂、宠物洗护和就医都放回照护日常。"
            )
        }
        if containsAny(text, ["露营", "帐篷", "天幕", "睡袋", "渔具", "鱼竿", "鱼线", "鱼饵", "骑行", "摄影", "相机", "镜头", "乐器", "吉他", "键盘"]) {
            return RewardCandidate(
                groupId: "interest_gear",
                packId: "shopping",
                keywords: ["露营", "帐篷", "天幕", "睡袋", "渔具", "鱼竿", "鱼线", "鱼饵", "骑行", "摄影", "相机", "镜头", "乐器", "吉他", "键盘"],
                title: "新的爱好线索被记下来了",
                detail: "奖励体验「网购与装备」场景包 7 天，让露营、渔具、摄影这类兴趣投入不只停在购物分类。"
            )
        }
        if containsAny(text, ["健身", "健身训练", "跑步", "瑜伽", "游泳", "私教", "健身卡", "健身房", "理疗", "康复", "护具", "运动鞋", "运动服", "运动装备"]) {
            return RewardCandidate(
                groupId: "care_fitness",
                packId: "care",
                keywords: ["健身", "健身训练", "跑步", "瑜伽", "游泳", "私教", "健身卡", "健身房", "理疗", "康复", "护具", "运动鞋", "运动服", "运动装备"],
                title: "身体照护这条线开始了",
                detail: "奖励体验「看病买药健身恢复」场景包 7 天，记录训练、恢复和身体状态的连续变化。"
            )
        }
        if containsAny(text, ["酒店", "民宿", "住宿", "机票", "高铁", "火车", "机场", "景区", "景点", "门票", "旅行", "旅游", "露营地"]) {
            return RewardCandidate(
                groupId: "travel_trip",
                packId: "travel",
                keywords: ["酒店", "民宿", "住宿", "机票", "高铁", "火车", "机场", "景区", "景点", "门票", "旅行", "旅游", "露营地"],
                title: "一段出行线索被记下来了",
                detail: "奖励体验「出去玩订酒店买票」场景包 7 天，把路费、住宿和门票连成一段行程。"
            )
        }
        return nil
    }

    private func isFirstStrongLifeMark(
        item: HomeItem,
        allItems: [HomeItem],
        candidate: RewardCandidate
    ) -> Bool {
        let previousItems = allItems.filter { $0.id != item.id }
        return !previousItems.contains { previous in
            containsAny(semanticText(for: previous), candidate.keywords)
        }
    }

    private func semanticText(for item: HomeItem) -> String {
        [
            item.title,
            item.displayEmotionTag,
            item.memoryContext?.semanticPlace ?? "",
            item.memoryContext?.cityName ?? ""
        ].joined(separator: " ")
    }

    private func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private func decodeReward(forKey key: String) -> LifeMarkSceneReward? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(LifeMarkSceneReward.self, from: data)
    }

    private func encodeReward(_ reward: LifeMarkSceneReward, forKey key: String) {
        guard let data = try? JSONEncoder().encode(reward) else { return }
        defaults.set(data, forKey: key)
    }

    private func claimedGroupIds() -> Set<String> {
        Set(defaults.stringArray(forKey: claimedGroupsKey) ?? [])
    }

    private func dayKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}

final class FreeScenePackService {
    static let shared = FreeScenePackService()

    private let defaults: UserDefaults
    private let now: () -> Date

    private let packIdsKey = "free_scene_pack_ids_v1"
    private let firstOpenKey = "free_scene_pack_first_open_at"
    private let lastReplaceKey = "free_scene_pack_last_replace_at"
    private let replaceWindowStartedKey = "free_scene_pack_replace_window_started_at"
    private let orderKey = "free_scene_pack_order_v1"
    private let lockedHintKey = "free_scene_pack_locked_hint_v1"

    private let firstWeekInterval: TimeInterval = 7 * 24 * 60 * 60
    private let replaceCooldownInterval: TimeInterval = 30 * 24 * 60 * 60
    private let replaceWindowInterval: TimeInterval = 24 * 60 * 60
    private let lockedHintCooldownInterval: TimeInterval = 3 * 24 * 60 * 60
    private let extensionLockedIds: Set<String> = ["travel", "family"]

    init(
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.now = now
    }

    func defaultPackIds() -> [String] {
        ["commute", "food", "supply"]
    }

    func recordFirstOpenIfNeeded() {
        guard defaults.double(forKey: firstOpenKey) <= 0 else { return }
        defaults.set(now().timeIntervalSince1970, forKey: firstOpenKey)
    }

    func currentPackIds() -> [String] {
        currentPackIds(from: ScenePackCopyPool.definitions)
    }

    func currentPackIds(from definitions: [ScenePackDefinition]) -> [String] {
        let validIds = Set(definitions.map(\.id))
        let storedIds = decodeIds(defaults.string(forKey: packIdsKey))
        if isValidPackSet(storedIds, validIds: validIds) {
            return storedIds
        }

        let fallbackIds = repairedDefaultIds(validIds: validIds, definitions: definitions)
        persistPackIds(fallbackIds)
        return fallbackIds
    }

    func isInFirstWeek() -> Bool {
        recordFirstOpenIfNeeded()
        let firstOpen = defaults.double(forKey: firstOpenKey)
        guard firstOpen > 0 else { return true }
        return now().timeIntervalSince1970 < firstOpen + firstWeekInterval
    }

    func daysUntilExtensionLock() -> Int {
        recordFirstOpenIfNeeded()
        let firstOpen = defaults.double(forKey: firstOpenKey)
        guard firstOpen > 0 else { return 7 }
        let remaining = max(0, firstOpen + firstWeekInterval - now().timeIntervalSince1970)
        guard remaining > 0 else { return 0 }
        return max(1, Int(ceil(remaining / 86_400)))
    }

    func canReplacePackCombination() -> Bool {
        if isInFirstWeek() { return true }
        let current = now().timeIntervalSince1970
        let windowStart = defaults.double(forKey: replaceWindowStartedKey)
        if windowStart > 0 {
            if current < windowStart + replaceWindowInterval {
                return true
            }
            return current >= windowStart + replaceWindowInterval + replaceCooldownInterval
        }

        let legacyLastReplace = defaults.double(forKey: lastReplaceKey)
        guard legacyLastReplace > 0 else { return true }
        return current >= legacyLastReplace + replaceCooldownInterval
    }

    func daysUntilNextReplace() -> Int {
        if isInFirstWeek() || canReplacePackCombination() { return 0 }
        let remaining = secondsUntilNextReplace()
        return max(1, Int(ceil(remaining / 86_400)))
    }

    func secondsUntilNextReplace() -> TimeInterval {
        if isInFirstWeek() || canReplacePackCombination() { return 0 }
        let current = now().timeIntervalSince1970
        return max(0, nextReplaceAvailableAt() - current)
    }

    func nextReplaceAvailableAt() -> TimeInterval {
        let windowStart = defaults.double(forKey: replaceWindowStartedKey)
        if windowStart > 0 {
            return windowStart + replaceWindowInterval + replaceCooldownInterval
        }
        let legacyLastReplace = defaults.double(forKey: lastReplaceKey)
        guard legacyLastReplace > 0 else { return now().timeIntervalSince1970 }
        return legacyLastReplace + replaceCooldownInterval
    }

    func isReplaceWindowActive() -> Bool {
        guard !isInFirstWeek() else { return false }
        let windowStart = defaults.double(forKey: replaceWindowStartedKey)
        guard windowStart > 0 else { return false }
        let current = now().timeIntervalSince1970
        return current < windowStart + replaceWindowInterval
    }

    func replaceWindowRemainingHours() -> Int {
        guard isReplaceWindowActive() else { return 0 }
        let windowStart = defaults.double(forKey: replaceWindowStartedKey)
        let remaining = max(0, windowStart + replaceWindowInterval - now().timeIntervalSince1970)
        return max(1, Int(ceil(remaining / 3_600)))
    }

    func replaceWindowRemainingSeconds() -> TimeInterval {
        guard isReplaceWindowActive() else { return 0 }
        return max(0, replaceWindowEndsAt() - now().timeIntervalSince1970)
    }

    func replaceWindowEndsAt() -> TimeInterval {
        let windowStart = defaults.double(forKey: replaceWindowStartedKey)
        guard windowStart > 0 else { return 0 }
        return windowStart + replaceWindowInterval
    }

    func replacePack(atSlot slot: Int, oldId: String, newId: String, from definitions: [ScenePackDefinition]) {
        var ids = currentPackIds(from: definitions)
        guard ids.indices.contains(slot), ids[slot] == oldId, !ids.contains(newId) else { return }
        guard isInFirstWeek() || canReplacePackCombination() else { return }
        guard isInFirstWeek() || !extensionLockedIds.contains(newId) else { return }
        guard definitions.contains(where: { $0.id == newId }) else { return }

        ids[slot] = newId
        persistPackIds(ids)
        persistOrderedIds(ids)

        if !isInFirstWeek(), !isReplaceWindowActive() {
            defaults.set(now().timeIntervalSince1970, forKey: replaceWindowStartedKey)
        }
    }

    func reorderFreePacks(_ orderedIds: [String], from definitions: [ScenePackDefinition]) {
        let currentIds = currentPackIds(from: definitions)
        let currentSet = Set(currentIds)
        var nextIds = orderedIds.filter { currentSet.contains($0) }
        nextIds.append(contentsOf: currentIds.filter { !nextIds.contains($0) })
        persistOrderedIds(Array(nextIds.prefix(3)))
    }

    func orderedFreePacks(from definitions: [ScenePackDefinition]) -> [ScenePackDefinition] {
        let ids = currentPackIds(from: definitions)
        let idSet = Set(ids)
        let orderedIds = decodeIds(defaults.string(forKey: orderKey)).filter { idSet.contains($0) }
        let finalIds = orderedIds + ids.filter { !orderedIds.contains($0) }
        let definitionById = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0) })
        return finalIds.compactMap { definitionById[$0] }
    }

    func replaceableCandidates(from definitions: [ScenePackDefinition]) -> [ScenePackDefinition] {
        let currentIds = Set(currentPackIds(from: definitions))
        let allowsExtensionPacks = isInFirstWeek()
        return definitions.filter { pack in
            !currentIds.contains(pack.id) && (allowsExtensionPacks || !extensionLockedIds.contains(pack.id))
        }
    }

    func isExtensionLockedPack(_ pack: ScenePackDefinition) -> Bool {
        extensionLockedIds.contains(pack.id)
    }

    func canShowLockedSceneHint(for packId: String) -> Bool {
        guard extensionLockedIds.contains(packId) else { return false }
        let lastShownAt = lockedHintTimestamps()[packId] ?? 0
        return now().timeIntervalSince1970 >= lastShownAt + lockedHintCooldownInterval
    }

    func recordLockedSceneHintShown(for packId: String) {
        guard extensionLockedIds.contains(packId) else { return }
        var timestamps = lockedHintTimestamps()
        timestamps[packId] = now().timeIntervalSince1970
        defaults.set(encodeLockedHintTimestamps(timestamps), forKey: lockedHintKey)
    }

    private func decodeIds(_ storage: String?) -> [String] {
        (storage ?? "")
            .split(separator: ",")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private func isValidPackSet(_ ids: [String], validIds: Set<String>) -> Bool {
        ids.count == 3 && Set(ids).count == 3 && ids.allSatisfy { validIds.contains($0) }
    }

    private func repairedDefaultIds(validIds: Set<String>, definitions: [ScenePackDefinition]) -> [String] {
        var ids = defaultPackIds().filter { validIds.contains($0) }
        let fillIds = definitions
            .map(\.id)
            .filter { validIds.contains($0) && !extensionLockedIds.contains($0) && !ids.contains($0) }
        ids.append(contentsOf: fillIds)
        return Array(ids.prefix(3))
    }

    private func persistPackIds(_ ids: [String]) {
        defaults.set(ids.prefix(3).joined(separator: ","), forKey: packIdsKey)
    }

    private func persistOrderedIds(_ ids: [String]) {
        defaults.set(ids.prefix(3).joined(separator: ","), forKey: orderKey)
    }

    private func lockedHintTimestamps() -> [String: TimeInterval] {
        (defaults.string(forKey: lockedHintKey) ?? "")
            .split(separator: ";")
            .reduce(into: [String: TimeInterval]()) { result, chunk in
                let parts = chunk.split(separator: "|")
                guard parts.count == 2,
                      let timestamp = TimeInterval(String(parts[1])) else { return }
                result[String(parts[0])] = timestamp
            }
    }

    private func encodeLockedHintTimestamps(_ timestamps: [String: TimeInterval]) -> String {
        timestamps
            .filter { extensionLockedIds.contains($0.key) }
            .sorted { $0.key < $1.key }
            .map { "\($0.key)|\(Int($0.value))" }
            .joined(separator: ";")
    }
}
