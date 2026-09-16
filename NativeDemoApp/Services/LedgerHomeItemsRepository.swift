import Foundation

struct LedgerHomeItemsLoadResult {
    var items: [HomeItem]
    var issueMessage: String?
    var writesBlocked: Bool
}

struct LedgerHomeItemsChangeSet {
    var upserts: [HomeItem] = []
    var deletedIDs: Set<UUID> = []

    var isEmpty: Bool { upserts.isEmpty && deletedIDs.isEmpty }
}

/// Result of a local write. `persistedItems` is deliberately metadata-only so
/// callers can replace their in-memory projection and release original image
/// bytes immediately after the write succeeds.
struct LedgerPersistenceSaveResult: @unchecked Sendable {
    let success: Bool
    let persistedItems: [HomeItem]
}

final class LedgerHomeItemsRepository {
    private enum LegacyPayloadState {
        case missing
        case valid(Data)
        case unreadable
    }

    private let fileManager: FileManager
    private let defaults: UserDefaults
    private let documentsURL: URL
    private let homeItemsBackupKey: String
    private let homeItemsFile: String
    private let preImageMigrationBackupFile: String
    private let imageStore: LedgerImageStore
    private let metadataStore: LedgerMetadataStore

    init(
        documentsURL: URL,
        defaults: UserDefaults,
        homeItemsBackupKey: String = "home_items_v1_backup",
        homeItemsFile: String = "home_items_v1.json",
        preImageMigrationBackupFile: String = "home_items_v1.pre_image_migration.json",
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.defaults = defaults
        self.documentsURL = documentsURL.standardizedFileURL
        self.homeItemsBackupKey = homeItemsBackupKey
        self.homeItemsFile = homeItemsFile
        self.preImageMigrationBackupFile = preImageMigrationBackupFile
        let storeRoot = self.documentsURL
            .appendingPathComponent(LedgerStorageSchema.storeDirectoryName, isDirectory: true)
        self.imageStore = LedgerImageStore(storeRootURL: storeRoot, fileManager: fileManager)
        self.metadataStore = LedgerMetadataStore(storeRootURL: storeRoot, fileManager: fileManager)
    }

    func load() -> LedgerHomeItemsLoadResult {
        do {
            if let manifest = try metadataStore.loadManifest(), manifest.activeStore == .metadataV2 {
                do {
                    let items = try metadataStore.loadItems()
                    return LedgerHomeItemsLoadResult(
                        items: items,
                        issueMessage: nil,
                        writesBlocked: false
                    )
                } catch {
                    return recoverFromActiveMetadataFailure(error)
                }
            }
        } catch {
            return recoverFromActiveMetadataFailure(error)
        }

        switch legacyPayloadState() {
        case .missing:
            do {
                let emptyData = try encodedLegacyData([])
                try metadataStore.activate(items: [], sourceDigest: LedgerMetadataStore.sha256Hex(emptyData))
                return LedgerHomeItemsLoadResult(items: [], issueMessage: nil, writesBlocked: false)
            } catch {
                print("Failed to initialize metadata ledger: \(error)")
                return LedgerHomeItemsLoadResult(
                    items: [],
                    issueMessage: "本机账本仍使用兼容存储，新记录会继续保存在本机。",
                    writesBlocked: false
                )
            }

        case .unreadable:
            return unreadableResult()

        case .valid(let payload):
            guard let decodedItems = try? JSONDecoder().decode([HomeItem].self, from: payload) else {
                return unreadableResult()
            }
            do {
                let externalized: [HomeItem]
                let migrationPayload: Data
                if needsImageExternalization(decodedItems) {
                    try preservePreImageMigrationBackup(payload)
                    externalized = try imageStore.prepareForPersistence(decodedItems)
                    migrationPayload = try persistLegacy(externalized)
                } else {
                    externalized = decodedItems
                    migrationPayload = payload
                }
                try metadataStore.activate(
                    items: externalized,
                    sourceDigest: LedgerMetadataStore.sha256Hex(migrationPayload)
                )
                try imageStore.cleanupOrphans(keeping: imageStore.referencedPaths(in: externalized))
                return LedgerHomeItemsLoadResult(
                    items: imageStore.metadataOnly(externalized),
                    issueMessage: nil,
                    writesBlocked: false
                )
            } catch {
                print("Failed to activate metadata ledger: \(error)")
                return LedgerHomeItemsLoadResult(
                    items: imageStore.metadataOnly(decodedItems),
                    issueMessage: "本机账本暂时使用兼容存储，原数据仍保留。",
                    writesBlocked: false
                )
            }
        }
    }

    @discardableResult
    func save(_ items: [HomeItem]) -> Bool {
        do {
            let manifest = try metadataStore.loadManifest()
            let usesActiveMetadata = manifest?.activeStore == .metadataV2
            let externalized = try imageStore.prepareForPersistence(items)
            if usesActiveMetadata {
                do {
                    _ = try metadataStore.reconcile(externalized)
                    try imageStore.cleanupOrphans(keeping: imageStore.referencedPaths(in: externalized))
                    return true
                } catch {
                    print("Failed to incrementally save metadata ledger: \(error)")
                    guard canUseLegacyFallback(legacyPayloadState()) else { return false }
                    return try persistEmergencyLegacy(externalized)
                }
            }

            let legacyStateBeforeSave = legacyPayloadState()
            guard canUseLegacyFallback(legacyStateBeforeSave) else {
                print("Blocked ledger save because both retained legacy sources are unreadable.")
                return false
            }
            do {
                let sourceData = try encodedLegacyData(externalized)
                try metadataStore.activate(
                    items: externalized,
                    sourceDigest: LedgerMetadataStore.sha256Hex(sourceData)
                )
                try imageStore.cleanupOrphans(keeping: imageStore.referencedPaths(in: externalized))
                return true
            } catch {
                print("Failed to activate metadata ledger while saving: \(error)")
                return try persistEmergencyLegacy(externalized)
            }
        } catch {
            print("Failed to save home items: \(error)")
            return false
        }
    }

    func saveChanges(
        _ changes: LedgerHomeItemsChangeSet,
        currentItemsForFallback: [HomeItem]
    ) -> LedgerPersistenceSaveResult {
        guard !changes.isEmpty else { return LedgerPersistenceSaveResult(success: true, persistedItems: []) }
        do {
            let manifest = try metadataStore.loadManifest()
            guard manifest?.activeStore == .metadataV2 else {
                let fallbackItems = applying(changes, to: currentItemsForFallback)
                let projectionItems = uniqueUpserts(in: changes)
                let externalizedForProjection = try imageStore.prepareForPersistence(projectionItems)
                let success = save(fallbackItems)
                return LedgerPersistenceSaveResult(
                    success: success,
                    persistedItems: success ? imageStore.metadataOnly(externalizedForProjection) : []
                )
            }
            let externalized = try imageStore.prepareForPersistence(changes.upserts)
            _ = try metadataStore.applyChanges(
                upserts: externalized,
                deletedIDs: changes.deletedIDs
            )
            for item in externalized {
                do {
                    try imageStore.cleanupRecordOrphans(
                        recordID: item.id,
                        keeping: Set(item.memoryImageReferences.filter { !$0.isEmpty })
                    )
                } catch {
                    print("Failed to clean changed record images \(item.id): \(error)")
                }
            }
            let upsertedIDs = Set(externalized.map(\.id))
            for id in changes.deletedIDs.subtracting(upsertedIDs) {
                do {
                    try imageStore.removeRecordFiles(recordID: id)
                } catch {
                    print("Failed to remove deleted record images \(id): \(error)")
                }
            }
            return LedgerPersistenceSaveResult(
                success: true,
                persistedItems: imageStore.metadataOnly(externalized)
            )
        } catch {
            print("Failed to save changed ledger records: \(error)")
            let fallbackItems = applying(changes, to: currentItemsForFallback)
            let success = save(fallbackItems)
            let projectionItems = uniqueUpserts(in: changes)
            let externalizedForProjection = (try? imageStore.prepareForPersistence(projectionItems)) ?? projectionItems
            return LedgerPersistenceSaveResult(
                success: success,
                persistedItems: success ? imageStore.metadataOnly(externalizedForProjection) : []
            )
        }
    }

    func loadImageData(reference: String, variant: LedgerImageLoadVariant) -> Data? {
        imageStore.loadData(reference: reference, variant: variant)
    }

    func prewarmThumbnails(for items: [HomeItem]) {
        for item in items where !item.memoryImageReferences.isEmpty {
            for reference in item.memoryImageReferences where !reference.isEmpty {
                imageStore.prewarmThumbnail(reference: reference)
            }
        }
    }

    private func recoverFromActiveMetadataFailure(_ error: Error) -> LedgerHomeItemsLoadResult {
        print("Failed to load active metadata ledger: \(error)")
        switch legacyPayloadState() {
        case .valid(let payload):
            guard let items = try? JSONDecoder().decode([HomeItem].self, from: payload) else {
                return unreadableResult()
            }
            try? metadataStore.markLegacyActive(
                items: items,
                sourceDigest: LedgerMetadataStore.sha256Hex(payload)
            )
            return LedgerHomeItemsLoadResult(
                items: imageStore.metadataOnly(items),
                issueMessage: "增量账本暂时无法打开，已使用本机保留账本，原文件没有被覆盖。",
                writesBlocked: false
            )
        case .missing, .unreadable:
            return unreadableResult()
        }
    }

    private func unreadableResult() -> LedgerHomeItemsLoadResult {
        LedgerHomeItemsLoadResult(
            items: [],
            issueMessage: "本机账本暂时无法读取，原文件已保留。请重启后再试，暂时不要新增或修改记录。",
            writesBlocked: true
        )
    }

    private func persistEmergencyLegacy(_ items: [HomeItem]) throws -> Bool {
        let payload = try persistLegacy(items)
        try metadataStore.markLegacyActive(
            items: items,
            sourceDigest: LedgerMetadataStore.sha256Hex(payload)
        )
        try imageStore.cleanupOrphans(keeping: imageStore.referencedPaths(in: items))
        return true
    }

    private func canUseLegacyFallback(_ state: LegacyPayloadState) -> Bool {
        switch state {
        case .missing, .valid:
            return true
        case .unreadable:
            return false
        }
    }

    /// Applies a change set to the last visible snapshot before writing the
    /// compatibility JSON path. This keeps legacy and emergency writes
    /// semantically equivalent to the metadata change-set path.
    private func applying(
        _ changes: LedgerHomeItemsChangeSet,
        to currentItems: [HomeItem]
    ) -> [HomeItem] {
        var result = currentItems.filter { !changes.deletedIDs.contains($0.id) }
        var indexByID: [UUID: Int] = [:]
        for (index, item) in result.enumerated() {
            indexByID[item.id] = index
        }
        for item in changes.upserts {
            if let index = indexByID[item.id] {
                result[index] = item
            } else {
                indexByID[item.id] = result.count
                result.append(item)
            }
        }
        return result
    }

    /// A malformed/duplicated change set can fail metadata validation. Keep
    /// the returned in-memory projection unique so a successful legacy
    /// fallback cannot crash its caller while reporting the committed items.
    private func uniqueUpserts(in changes: LedgerHomeItemsChangeSet) -> [HomeItem] {
        var result: [HomeItem] = []
        var indexByID: [UUID: Int] = [:]
        for item in changes.upserts {
            if let index = indexByID[item.id] {
                result[index] = item
            } else {
                indexByID[item.id] = result.count
                result.append(item)
            }
        }
        return result
    }

    @discardableResult
    private func persistLegacy(_ items: [HomeItem]) throws -> Data {
        let data = try encodedLegacyData(items)
        defaults.set(data, forKey: homeItemsBackupKey)
        try fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        try data.write(to: documentsURL.appendingPathComponent(homeItemsFile), options: .atomic)
        return data
    }

    private func encodedLegacyData(_ items: [HomeItem]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(items)
    }

    private func legacyPayloadState() -> LegacyPayloadState {
        var foundUnreadablePayload = false
        let fileURL = documentsURL.appendingPathComponent(homeItemsFile)
        if fileManager.fileExists(atPath: fileURL.path) {
            if let data = try? Data(contentsOf: fileURL), isValidLegacyPayload(data) {
                return .valid(data)
            }
            foundUnreadablePayload = true
        }

        if let backup = defaults.data(forKey: homeItemsBackupKey) {
            if isValidLegacyPayload(backup) {
                return .valid(backup)
            }
            foundUnreadablePayload = true
        }
        return foundUnreadablePayload ? .unreadable : .missing
    }

    private func isValidLegacyPayload(_ data: Data) -> Bool {
        (try? JSONDecoder().decode([HomeItem].self, from: data)) != nil
    }

    private func preservePreImageMigrationBackup(_ data: Data) throws {
        let backupURL = documentsURL.appendingPathComponent(preImageMigrationBackupFile)
        guard !fileManager.fileExists(atPath: backupURL.path) else { return }
        try fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        try data.write(to: backupURL, options: .atomic)
    }

    private func needsImageExternalization(_ items: [HomeItem]) -> Bool {
        items.contains { item in
            let images = item.memoryImages
            guard !images.isEmpty else { return false }
            return item.memoryImageReferences.count != images.count
                || item.memoryImageReferences.contains(where: \.isEmpty)
        }
    }
}
