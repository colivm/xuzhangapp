import Foundation

#if DEBUG
struct LedgerPersistenceStoreContext {
    let documentsURL: URL
    let defaults: UserDefaults
    let homeItemsBackupKey: String
    let homeItemsFile: String
    let preImageMigrationBackupFile: String
}
#endif

/// Serializes the expensive local ledger write path away from the main actor.
/// The writer intentionally keeps the existing repository contract unchanged so
/// metadata, image files and orphan cleanup remain one ordered transaction.
actor LedgerPersistenceWriter {
    private let repository: LedgerHomeItemsRepository

    init(repository: LedgerHomeItemsRepository? = nil) {
        self.repository = repository ?? LedgerPersistenceWriter.makeRepository()
    }

    func saveChanges(
        _ changes: LedgerHomeItemsChangeSet,
        currentItemsForFallback: [HomeItem]
    ) -> LedgerPersistenceSaveResult {
        repository.saveChanges(changes, currentItemsForFallback: currentItemsForFallback)
    }

    private static func makeRepository() -> LedgerHomeItemsRepository {
        #if DEBUG
        if let context = LocalStore.releaseFixtureStoreContextForPersistenceWriter() {
            return LedgerHomeItemsRepository(
                documentsURL: context.documentsURL,
                defaults: context.defaults,
                homeItemsBackupKey: context.homeItemsBackupKey,
                homeItemsFile: context.homeItemsFile,
                preImageMigrationBackupFile: context.preImageMigrationBackupFile
            )
        }
        #endif
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return LedgerHomeItemsRepository(
            documentsURL: documentsURL,
            defaults: .standard
        )
    }
}

/// Foundation-only revision gate used by the main-actor completion handler.
enum LedgerPersistenceRevisionPolicy {
    static func acceptsCompletion(completionRevision: UInt64, currentRevision: UInt64) -> Bool {
        completionRevision == currentRevision
    }

    /// A record can have multiple writes in flight. A completion may publish
    /// its per-record result only while it is still the latest write for that
    /// record. Older completions must not clear or overwrite newer state.
    static func ownsRecordCompletion(
        completionRevision: UInt64,
        latestRevisionForRecord: UInt64?
    ) -> Bool {
        latestRevisionForRecord == completionRevision
    }
}

extension LedgerHomeItemsChangeSet: @unchecked Sendable {}
extension HomeItem: @unchecked Sendable {}
extension LedgerHomeItemsLoadResult: @unchecked Sendable {}
