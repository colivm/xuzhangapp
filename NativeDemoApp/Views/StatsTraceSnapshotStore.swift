import Foundation

final class TraceSnapshotStore {
    private var chapterCache: [String: TraceChapterSnapshot] = [:]
    private var chapterCacheOrder: [String] = []
    private let chapterCacheLimit = 8

    private var clueCache: [String: TraceClueSnapshot] = [:]
    private var clueCacheOrder: [String] = []
    private let clueCacheLimit = 24

    func chapterSnapshot(for key: String) -> TraceChapterSnapshot? {
        chapterCache[key]
    }

    func storeChapterSnapshot(_ snapshot: TraceChapterSnapshot, for key: String) {
        guard chapterCache[key] == nil else { return }
        chapterCache[key] = snapshot
        chapterCacheOrder.append(key)
        while chapterCacheOrder.count > chapterCacheLimit {
            let staleKey = chapterCacheOrder.removeFirst()
            chapterCache.removeValue(forKey: staleKey)
        }
    }

    func clueSnapshot(for key: String) -> TraceClueSnapshot? {
        clueCache[key]
    }

    func storeClueSnapshot(_ snapshot: TraceClueSnapshot, for key: String) {
        guard clueCache[key] == nil else { return }
        clueCache[key] = snapshot
        clueCacheOrder.append(key)
        while clueCacheOrder.count > clueCacheLimit {
            let staleKey = clueCacheOrder.removeFirst()
            clueCache.removeValue(forKey: staleKey)
        }
    }

    func invalidateAll() {
        chapterCache.removeAll()
        chapterCacheOrder.removeAll()
        invalidateClueCache()
    }

    func invalidateClueCache() {
        clueCache.removeAll()
        clueCacheOrder.removeAll()
    }
}
