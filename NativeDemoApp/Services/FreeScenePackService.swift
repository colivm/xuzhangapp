import Foundation

final class FreeScenePackService {
    static let shared = FreeScenePackService()

    private let defaults: UserDefaults
    private let now: () -> Date

    private let packIdsKey = "free_scene_pack_ids_v1"
    private let firstOpenKey = "free_scene_pack_first_open_at"
    private let lastReplaceKey = "free_scene_pack_last_replace_at"
    private let orderKey = "free_scene_pack_order_v1"
    private let lockedHintKey = "free_scene_pack_locked_hint_v1"

    private let firstWeekInterval: TimeInterval = 7 * 24 * 60 * 60
    private let replaceCooldownInterval: TimeInterval = 30 * 24 * 60 * 60
    private let lockedHintCooldownInterval: TimeInterval = 3 * 24 * 60 * 60
    private let extensionLockedIds: Set<String> = ["travel", "pet", "baby", "fitness"]

    init(
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.now = now
    }

    func defaultPackIds() -> [String] {
        ["commute", "food", "home"]
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
        let lastReplace = defaults.double(forKey: lastReplaceKey)
        guard lastReplace > 0 else { return true }
        return now().timeIntervalSince1970 >= lastReplace + replaceCooldownInterval
    }

    func daysUntilNextReplace() -> Int {
        if isInFirstWeek() || canReplacePackCombination() { return 0 }
        let lastReplace = defaults.double(forKey: lastReplaceKey)
        let remaining = max(0, lastReplace + replaceCooldownInterval - now().timeIntervalSince1970)
        return max(1, Int(ceil(remaining / 86_400)))
    }

    func replacePack(atSlot slot: Int, oldId: String, newId: String, from definitions: [ScenePackDefinition]) {
        var ids = currentPackIds(from: definitions)
        guard ids.indices.contains(slot), ids[slot] == oldId, !ids.contains(newId) else { return }
        guard isInFirstWeek() || !extensionLockedIds.contains(newId) else { return }
        guard definitions.contains(where: { $0.id == newId }) else { return }

        ids[slot] = newId
        persistPackIds(ids)
        persistOrderedIds(ids)

        if !isInFirstWeek() {
            defaults.set(now().timeIntervalSince1970, forKey: lastReplaceKey)
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
