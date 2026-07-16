import CryptoKit
import Foundation
import SQLite3

enum LedgerMetadataStoreError: LocalizedError {
    case databaseOpenFailed(String)
    case sqliteFailure(operation: String, message: String)
    case invalidSchema(Int32)
    case integrityCheckFailed(String)
    case invalidRecord(String)
    case auditMismatch(String)

    var errorDescription: String? {
        switch self {
        case .databaseOpenFailed(let message):
            return "账本数据库无法打开：\(message)"
        case .sqliteFailure(let operation, let message):
            return "账本数据库执行 \(operation) 失败：\(message)"
        case .invalidSchema(let version):
            return "账本数据库版本不兼容：\(version)"
        case .integrityCheckFailed(let message):
            return "账本数据库完整性检查失败：\(message)"
        case .invalidRecord(let message):
            return "账本数据库存在无效记录：\(message)"
        case .auditMismatch(let message):
            return "账本迁移校验不一致：\(message)"
        }
    }
}

struct LedgerMetadataWriteSummary: Equatable {
    var inserted: Int
    var updated: Int
    var deleted: Int
    var unchanged: Int
}

final class LedgerMetadataStore {
    private struct ExistingAsset {
        var relativePath: String
        var byteCount: Int64
        var mediaType: String
    }

    private struct DatabaseStats {
        var recordCount: Int
        var imageCount: Int
        var amountMinorUnitTotal: Int64
    }

    private struct ExistingRecordVersion {
        var updatedAt: Double
    }

    private struct ExistingRecordStats {
        var amountMinorUnits: Int64
        var imageCount: Int
    }

    private let fileManager: FileManager
    let storeRootURL: URL
    let databaseURL: URL
    let manifestURL: URL
    let migrationDirectoryURL: URL
    let stagingDatabaseURL: URL

    init(storeRootURL: URL, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.storeRootURL = storeRootURL.standardizedFileURL
        self.databaseURL = self.storeRootURL
            .appendingPathComponent(LedgerStorageSchema.metadataDatabaseName)
        self.manifestURL = self.storeRootURL.appendingPathComponent("manifest.json")
        self.migrationDirectoryURL = self.storeRootURL
            .appendingPathComponent(LedgerStorageSchema.migrationDirectoryName, isDirectory: true)
        self.stagingDatabaseURL = self.migrationDirectoryURL
            .appendingPathComponent("\(LedgerStorageSchema.metadataDatabaseName).staging")
    }

    func loadManifest() throws -> LedgerStoreManifest? {
        guard fileManager.fileExists(atPath: manifestURL.path) else { return nil }
        let data = try Data(contentsOf: manifestURL)
        return try JSONDecoder().decode(LedgerStoreManifest.self, from: data)
    }

    func loadItems() throws -> [HomeItem] {
        guard fileManager.fileExists(atPath: databaseURL.path) else {
            throw LedgerMetadataStoreError.databaseOpenFailed("数据库文件不存在")
        }
        return try withDatabase(at: databaseURL, createIfNeeded: false) { database in
            try validateDatabase(database)
            return try readItems(from: database)
        }
    }

    func activate(items: [HomeItem], sourceDigest: String) throws {
        try validateExternalizedItems(items)
        try fileManager.createDirectory(at: storeRootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: migrationDirectoryURL, withIntermediateDirectories: true)
        try removeSQLiteFiles(at: stagingDatabaseURL)

        try withDatabase(at: stagingDatabaseURL, createIfNeeded: true) { database in
            try execute(database, sql: "PRAGMA journal_mode = DELETE", operation: "设置迁移日志模式")
            try createSchema(in: database)
            try inTransaction(database) {
                for item in items {
                    try upsert(item, in: database)
                }
            }
            try audit(items: items, in: database)
            try execute(database, sql: "PRAGMA wal_checkpoint(TRUNCATE)", operation: "完成迁移检查点")
        }

        let stagedData = try Data(contentsOf: stagingDatabaseURL)
        try removeSQLiteSidecars(at: databaseURL)
        try stagedData.write(to: databaseURL, options: .atomic)
        let stats = try databaseStats(at: databaseURL)
        try writeManifest(
            LedgerStoreManifest(
                schemaVersion: LedgerStorageSchema.targetVersion,
                activeStore: .metadataV2,
                sourceDigest: sourceDigest,
                recordCount: stats.recordCount,
                imageCount: stats.imageCount,
                amountMinorUnitTotal: stats.amountMinorUnitTotal,
                completedAt: Date()
            )
        )
        try? removeSQLiteFiles(at: stagingDatabaseURL)
    }

    func reconcile(_ items: [HomeItem]) throws -> LedgerMetadataWriteSummary {
        try validateExternalizedItems(items)
        let existingManifest = try loadManifest()
        let sourceDigest = existingManifest?.sourceDigest ?? Self.sha256Hex(Data("metadata-v2".utf8))

        let summary = try withDatabase(at: databaseURL, createIfNeeded: false) { database in
            try validateDatabase(database)
            try execute(database, sql: "PRAGMA journal_mode = WAL", operation: "启用增量写入日志")
            let existingVersions = try readRecordVersions(from: database)
            let incomingByID = try itemsByID(items)
            let deletedIDs = Set(existingVersions.keys).subtracting(incomingByID.keys)
            let changedIDs = incomingByID.keys.filter { id in
                guard let existing = existingVersions[id], let item = incomingByID[id] else { return true }
                return existing.updatedAt != item.updatedAt.timeIntervalSinceReferenceDate
            }
            let inserted = changedIDs.filter { existingVersions[$0] == nil }.count
            let updated = changedIDs.count - inserted

            try inTransaction(database) {
                for id in deletedIDs {
                    try deleteRecord(id: id, from: database)
                }
                for id in changedIDs {
                    guard let item = incomingByID[id] else { continue }
                    try upsert(item, in: database)
                }
            }

            return LedgerMetadataWriteSummary(
                inserted: inserted,
                updated: updated,
                deleted: deletedIDs.count,
                unchanged: items.count - changedIDs.count
            )
        }

        let stats = try databaseStats(at: databaseURL)
        try writeManifest(
            LedgerStoreManifest(
                schemaVersion: LedgerStorageSchema.targetVersion,
                activeStore: .metadataV2,
                sourceDigest: sourceDigest,
                recordCount: stats.recordCount,
                imageCount: stats.imageCount,
                amountMinorUnitTotal: stats.amountMinorUnitTotal,
                completedAt: Date()
            )
        )
        return summary
    }

    func applyChanges(
        upserts: [HomeItem],
        deletedIDs: Set<UUID>
    ) throws -> LedgerMetadataWriteSummary {
        try validateExternalizedItems(upserts)
        let incomingByID = try itemsByID(upserts)
        let incomingIDs = Set(incomingByID.keys)
        let normalizedDeletedIDs = Set(deletedIDs.map { $0.uuidString.lowercased() })
            .subtracting(incomingIDs)
        guard !incomingByID.isEmpty || !normalizedDeletedIDs.isEmpty else {
            return LedgerMetadataWriteSummary(inserted: 0, updated: 0, deleted: 0, unchanged: 0)
        }

        guard let manifest = try loadManifest(), manifest.activeStore == .metadataV2 else {
            throw LedgerMetadataStoreError.databaseOpenFailed("增量账本尚未激活")
        }

        var existingStats: [String: ExistingRecordStats] = [:]
        let summary = try withDatabase(at: databaseURL, createIfNeeded: false) { database in
            try validateSchemaVersion(database)
            try execute(database, sql: "PRAGMA journal_mode = WAL", operation: "启用变化集写入日志")
            for id in incomingIDs.union(normalizedDeletedIDs) {
                if let stats = try readRecordStats(id: id, from: database) {
                    existingStats[id] = stats
                }
            }

            try inTransaction(database) {
                for id in normalizedDeletedIDs {
                    try deleteRecord(id: id, from: database)
                }
                for item in incomingByID.values {
                    try upsert(item, in: database)
                }
            }

            return LedgerMetadataWriteSummary(
                inserted: incomingIDs.filter { existingStats[$0] == nil }.count,
                updated: incomingIDs.filter { existingStats[$0] != nil }.count,
                deleted: normalizedDeletedIDs.filter { existingStats[$0] != nil }.count,
                unchanged: 0
            )
        }

        var recordCount = manifest.recordCount
        var imageCount = manifest.imageCount
        var amountMinorUnitTotal = manifest.amountMinorUnitTotal
        for id in normalizedDeletedIDs {
            guard let previous = existingStats[id] else { continue }
            recordCount -= 1
            imageCount -= previous.imageCount
            amountMinorUnitTotal -= previous.amountMinorUnits
        }
        for (id, item) in incomingByID {
            let previous = existingStats[id]
            if previous == nil { recordCount += 1 }
            imageCount += item.memoryImageReferences.count - (previous?.imageCount ?? 0)
            amountMinorUnitTotal += Self.minorUnits(item.amount) - (previous?.amountMinorUnits ?? 0)
        }
        try writeManifest(
            LedgerStoreManifest(
                schemaVersion: LedgerStorageSchema.targetVersion,
                activeStore: .metadataV2,
                sourceDigest: manifest.sourceDigest,
                recordCount: max(0, recordCount),
                imageCount: max(0, imageCount),
                amountMinorUnitTotal: amountMinorUnitTotal,
                completedAt: Date()
            )
        )
        return summary
    }

    func markLegacyActive(items: [HomeItem], sourceDigest: String) throws {
        let imageCount = items.reduce(0) { $0 + $1.memoryImageReferences.count }
        let total = items.reduce(Int64(0)) { $0 + Self.minorUnits($1.amount) }
        try writeManifest(
            LedgerStoreManifest(
                schemaVersion: LedgerStorageSchema.targetVersion,
                activeStore: .legacyJSON,
                sourceDigest: sourceDigest,
                recordCount: items.count,
                imageCount: imageCount,
                amountMinorUnitTotal: total,
                completedAt: nil
            )
        )
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func minorUnits(_ amount: Double) -> Int64 {
        Int64((amount * 100).rounded())
    }

    private func withDatabase<T>(
        at url: URL,
        createIfNeeded: Bool,
        _ body: (OpaquePointer) throws -> T
    ) throws -> T {
        if !createIfNeeded, !fileManager.fileExists(atPath: url.path) {
            throw LedgerMetadataStoreError.databaseOpenFailed("数据库文件不存在")
        }
        if createIfNeeded {
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        }

        var database: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX | (createIfNeeded ? SQLITE_OPEN_CREATE : 0)
        let result = sqlite3_open_v2(url.path, &database, flags, nil)
        guard result == SQLITE_OK, let database else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "SQLite code \(result)"
            if let database { sqlite3_close(database) }
            throw LedgerMetadataStoreError.databaseOpenFailed(message)
        }
        defer { sqlite3_close(database) }

        sqlite3_busy_timeout(database, 3_000)
        try execute(database, sql: "PRAGMA foreign_keys = ON", operation: "启用外键")
        return try body(database)
    }

    private func createSchema(in database: OpaquePointer) throws {
        try execute(
            database,
            sql: """
            CREATE TABLE IF NOT EXISTS records (
                id TEXT PRIMARY KEY NOT NULL,
                title TEXT NOT NULL,
                amount_minor_units INTEGER NOT NULL,
                amount_value REAL NOT NULL,
                category TEXT NOT NULL,
                source TEXT NOT NULL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL,
                emotion_tag TEXT NOT NULL,
                merchant_brand_id TEXT,
                draft_batch_id TEXT,
                draft_imported_at REAL,
                draft_status TEXT,
                user_edited_title INTEGER,
                user_edited_category INTEGER,
                category_correction_from TEXT,
                memory_weather_kind TEXT,
                memory_temperature_celsius REAL,
                memory_city_name TEXT,
                memory_semantic_place TEXT,
                scene_pack_id TEXT,
                cover_image_ordinal INTEGER,
                memory_anchor_role TEXT,
                memory_anchor_scene_hint TEXT,
                memory_anchor_caption TEXT,
                memory_anchor_created_at REAL,
                record_fingerprint TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS image_assets (
                id TEXT PRIMARY KEY NOT NULL,
                record_id TEXT NOT NULL REFERENCES records(id) ON DELETE CASCADE,
                ordinal INTEGER NOT NULL,
                relative_path TEXT NOT NULL,
                sha256 TEXT NOT NULL,
                byte_count INTEGER NOT NULL,
                media_type TEXT NOT NULL,
                UNIQUE(record_id, ordinal)
            );
            CREATE INDEX IF NOT EXISTS records_created_at_desc ON records(created_at DESC, updated_at DESC);
            CREATE INDEX IF NOT EXISTS records_category_created_at ON records(category, created_at DESC);
            CREATE INDEX IF NOT EXISTS records_draft_status ON records(draft_status, created_at DESC);
            CREATE INDEX IF NOT EXISTS image_assets_record_ordinal ON image_assets(record_id, ordinal);
            PRAGMA user_version = 2;
            """,
            operation: "创建账本结构"
        )
    }

    private func validateDatabase(_ database: OpaquePointer) throws {
        try validateSchemaVersion(database)
        let integrity = try singleText(database, sql: "PRAGMA quick_check(1)", operation: "检查账本完整性")
        guard integrity == "ok" else {
            throw LedgerMetadataStoreError.integrityCheckFailed(integrity)
        }
    }

    private func validateSchemaVersion(_ database: OpaquePointer) throws {
        let version = try singleInt(database, sql: "PRAGMA user_version", operation: "读取账本版本")
        guard version == Int64(LedgerStorageSchema.targetVersion) else {
            throw LedgerMetadataStoreError.invalidSchema(Int32(version))
        }
    }

    private func upsert(_ item: HomeItem, in database: OpaquePointer) throws {
        let sql = """
        INSERT INTO records (
            id, title, amount_minor_units, amount_value, category, source, created_at, updated_at, emotion_tag,
            merchant_brand_id, draft_batch_id, draft_imported_at, draft_status,
            user_edited_title, user_edited_category, category_correction_from,
            memory_weather_kind, memory_temperature_celsius, memory_city_name, memory_semantic_place,
            scene_pack_id, cover_image_ordinal, memory_anchor_role, memory_anchor_scene_hint,
            memory_anchor_caption, memory_anchor_created_at, record_fingerprint
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            title = excluded.title,
            amount_minor_units = excluded.amount_minor_units,
            amount_value = excluded.amount_value,
            category = excluded.category,
            source = excluded.source,
            created_at = excluded.created_at,
            updated_at = excluded.updated_at,
            emotion_tag = excluded.emotion_tag,
            merchant_brand_id = excluded.merchant_brand_id,
            draft_batch_id = excluded.draft_batch_id,
            draft_imported_at = excluded.draft_imported_at,
            draft_status = excluded.draft_status,
            user_edited_title = excluded.user_edited_title,
            user_edited_category = excluded.user_edited_category,
            category_correction_from = excluded.category_correction_from,
            memory_weather_kind = excluded.memory_weather_kind,
            memory_temperature_celsius = excluded.memory_temperature_celsius,
            memory_city_name = excluded.memory_city_name,
            memory_semantic_place = excluded.memory_semantic_place,
            scene_pack_id = excluded.scene_pack_id,
            cover_image_ordinal = excluded.cover_image_ordinal,
            memory_anchor_role = excluded.memory_anchor_role,
            memory_anchor_scene_hint = excluded.memory_anchor_scene_hint,
            memory_anchor_caption = excluded.memory_anchor_caption,
            memory_anchor_created_at = excluded.memory_anchor_created_at,
            record_fingerprint = excluded.record_fingerprint
        """
        let statement = try prepare(database, sql: sql, operation: "写入账单")
        defer { sqlite3_finalize(statement) }

        var index: Int32 = 1
        try bind(item.id.uuidString.lowercased(), statement: statement, index: &index)
        try bind(item.title, statement: statement, index: &index)
        try bind(Self.minorUnits(item.amount), statement: statement, index: &index)
        try bind(item.amount, statement: statement, index: &index)
        try bind(item.category.rawValue, statement: statement, index: &index)
        try bind(item.source.rawValue, statement: statement, index: &index)
        try bind(item.createdAt.timeIntervalSinceReferenceDate, statement: statement, index: &index)
        try bind(item.updatedAt.timeIntervalSinceReferenceDate, statement: statement, index: &index)
        try bind(item.emotionTag, statement: statement, index: &index)
        try bind(item.merchantBrandId, statement: statement, index: &index)
        try bind(item.draftMeta?.batchId, statement: statement, index: &index)
        try bind(item.draftMeta?.importedAt.timeIntervalSinceReferenceDate, statement: statement, index: &index)
        try bind(item.draftMeta?.status.rawValue, statement: statement, index: &index)
        try bind(item.userEditedTitle, statement: statement, index: &index)
        try bind(item.userEditedCategory, statement: statement, index: &index)
        try bind(item.categoryCorrectionFrom?.rawValue, statement: statement, index: &index)
        try bind(item.memoryContext?.weatherKind, statement: statement, index: &index)
        try bind(item.memoryContext?.temperatureCelsius, statement: statement, index: &index)
        try bind(item.memoryContext?.cityName, statement: statement, index: &index)
        try bind(item.memoryContext?.semanticPlace, statement: statement, index: &index)
        try bind(item.scenePackId, statement: statement, index: &index)
        try bind(item.normalizedCoverMemoryImageIndex.map { Int64($0) }, statement: statement, index: &index)
        try bind(item.memoryAnchorRole?.rawValue, statement: statement, index: &index)
        try bind(item.memoryAnchorSceneHint?.rawValue, statement: statement, index: &index)
        try bind(item.memoryAnchorCaption, statement: statement, index: &index)
        try bind(item.memoryAnchorCreatedAt?.timeIntervalSinceReferenceDate, statement: statement, index: &index)
        try bind(recordFingerprint(item), statement: statement, index: &index)
        try stepDone(statement, database: database, operation: "写入账单")

        try replaceImageAssets(for: item, in: database)
    }

    private func replaceImageAssets(for item: HomeItem, in database: OpaquePointer) throws {
        let recordID = item.id.uuidString.lowercased()
        let existingAssets = try readExistingAssets(recordID: recordID, from: database)
        let deleteStatement = try prepare(
            database,
            sql: "DELETE FROM image_assets WHERE record_id = ?",
            operation: "更新图片引用"
        )
        defer { sqlite3_finalize(deleteStatement) }
        var deleteIndex: Int32 = 1
        try bind(recordID, statement: deleteStatement, index: &deleteIndex)
        try stepDone(deleteStatement, database: database, operation: "更新图片引用")

        let references = item.memoryImageReferences
        guard references.count == item.memoryImageCount else {
            throw LedgerMetadataStoreError.invalidRecord("\(recordID) 的图片引用数量不一致")
        }

        let insertSQL = """
        INSERT INTO image_assets (id, record_id, ordinal, relative_path, sha256, byte_count, media_type)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """
        for (ordinal, reference) in references.enumerated() {
            let hash = try imageHash(from: reference, recordID: recordID, ordinal: ordinal)
            let existing = existingAssets[ordinal]
            let byteCount = imageByteCount(
                item: item,
                ordinal: ordinal,
                reference: reference,
                existing: existing
            )
            let assetID = Self.sha256Hex(Data("\(recordID)|\(ordinal)|\(hash)".utf8))
            let statement = try prepare(database, sql: insertSQL, operation: "写入图片引用")
            defer { sqlite3_finalize(statement) }
            var index: Int32 = 1
            try bind(assetID, statement: statement, index: &index)
            try bind(recordID, statement: statement, index: &index)
            try bind(Int64(ordinal), statement: statement, index: &index)
            try bind(reference, statement: statement, index: &index)
            try bind(hash, statement: statement, index: &index)
            try bind(byteCount, statement: statement, index: &index)
            try bind(existing?.mediaType ?? "image/jpeg", statement: statement, index: &index)
            try stepDone(statement, database: database, operation: "写入图片引用")
        }
    }

    private func imageHash(from reference: String, recordID: String, ordinal: Int) throws -> String {
        let filename = URL(fileURLWithPath: reference).deletingPathExtension().lastPathComponent.lowercased()
        let isHexDigest = filename.count == 64 && filename.allSatisfy { $0.isHexDigit }
        guard isHexDigest else {
            throw LedgerMetadataStoreError.invalidRecord("\(recordID) 的第 \(ordinal + 1) 张图片引用无效")
        }
        return filename
    }

    private func imageByteCount(
        item: HomeItem,
        ordinal: Int,
        reference: String,
        existing: ExistingAsset?
    ) -> Int64 {
        if let data = item.memoryImageData(at: ordinal) {
            return Int64(data.count)
        }
        let fileURL = storeRootURL.appendingPathComponent(reference)
        if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
           let size = attributes[.size] as? NSNumber {
            return size.int64Value
        }
        if existing?.relativePath == reference {
            return existing?.byteCount ?? 0
        }
        return 0
    }

    private func readExistingAssets(recordID: String, from database: OpaquePointer) throws -> [Int: ExistingAsset] {
        let statement = try prepare(
            database,
            sql: "SELECT ordinal, relative_path, byte_count, media_type FROM image_assets WHERE record_id = ?",
            operation: "读取原图片引用"
        )
        defer { sqlite3_finalize(statement) }
        var index: Int32 = 1
        try bind(recordID, statement: statement, index: &index)
        var result: [Int: ExistingAsset] = [:]
        try forEachRow(statement, database: database, operation: "读取原图片引用") {
            let ordinal = Int(sqlite3_column_int64(statement, 0))
            result[ordinal] = ExistingAsset(
                relativePath: requiredText(statement, column: 1),
                byteCount: sqlite3_column_int64(statement, 2),
                mediaType: requiredText(statement, column: 3)
            )
        }
        return result
    }

    private func deleteRecord(id: String, from database: OpaquePointer) throws {
        let statement = try prepare(database, sql: "DELETE FROM records WHERE id = ?", operation: "删除账单")
        defer { sqlite3_finalize(statement) }
        var index: Int32 = 1
        try bind(id, statement: statement, index: &index)
        try stepDone(statement, database: database, operation: "删除账单")
    }

    private func readItems(from database: OpaquePointer) throws -> [HomeItem] {
        let imageAssets = try readImageAssets(from: database)
        let sql = """
        SELECT id, title, amount_minor_units, amount_value, category, source, created_at, updated_at, emotion_tag,
               merchant_brand_id, draft_batch_id, draft_imported_at, draft_status,
               user_edited_title, user_edited_category, category_correction_from,
               memory_weather_kind, memory_temperature_celsius, memory_city_name, memory_semantic_place,
               scene_pack_id, cover_image_ordinal, memory_anchor_role, memory_anchor_scene_hint,
               memory_anchor_caption, memory_anchor_created_at
        FROM records
        ORDER BY created_at DESC, updated_at DESC, id ASC
        """
        let statement = try prepare(database, sql: sql, operation: "读取账本")
        defer { sqlite3_finalize(statement) }
        var items: [HomeItem] = []

        try forEachRow(statement, database: database, operation: "读取账本") {
            let idText = requiredText(statement, column: 0)
            guard let id = UUID(uuidString: idText),
                  let category = HomeItem.Category(rawValue: requiredText(statement, column: 4)),
                  let source = HomeItem.Source(rawValue: requiredText(statement, column: 5)) else {
                throw LedgerMetadataStoreError.invalidRecord(idText)
            }

            let draftMeta = try decodedDraftMeta(statement, id: idText)
            let memoryContext = decodedMemoryContext(statement)
            let categoryCorrectionText = optionalText(statement, column: 15)
            let categoryCorrection = categoryCorrectionText.flatMap { HomeItem.Category(rawValue: $0) }
            let anchorRoleText = optionalText(statement, column: 22)
            let anchorRole = anchorRoleText.flatMap { PhotoMemoryAssetRole(rawValue: $0) }
            let anchorSceneText = optionalText(statement, column: 23)
            let anchorScene = anchorSceneText.flatMap { PhotoMemorySceneHint(rawValue: $0) }
            if categoryCorrectionText != nil, categoryCorrection == nil {
                throw LedgerMetadataStoreError.invalidRecord("\(idText) 的分类修正字段无效")
            }
            if anchorRoleText != nil, anchorRole == nil {
                throw LedgerMetadataStoreError.invalidRecord("\(idText) 的图片角色字段无效")
            }
            if anchorSceneText != nil, anchorScene == nil {
                throw LedgerMetadataStoreError.invalidRecord("\(idText) 的图片场景字段无效")
            }
            let assets = imageAssets[idText] ?? []
            let references = assets.map(\.relativePath)
            let byteCounts = assets.map { Int(clamping: $0.byteCount) }
            let coverIndex = optionalInt(statement, column: 21).map(Int.init)

            items.append(
                HomeItem(
                    id: id,
                    title: requiredText(statement, column: 1),
                    amount: sqlite3_column_double(statement, 3),
                    category: category,
                    source: source,
                    createdAt: Date(timeIntervalSinceReferenceDate: sqlite3_column_double(statement, 6)),
                    updatedAt: Date(timeIntervalSinceReferenceDate: sqlite3_column_double(statement, 7)),
                    emotionTag: requiredText(statement, column: 8),
                    merchantBrandId: optionalText(statement, column: 9),
                    draftMeta: draftMeta,
                    userEditedTitle: optionalBool(statement, column: 13),
                    userEditedCategory: optionalBool(statement, column: 14),
                    categoryCorrectionFrom: categoryCorrection,
                    memoryContext: memoryContext,
                    scenePackId: optionalText(statement, column: 20),
                    memoryImageReferences: references,
                    memoryImageByteCounts: byteCounts,
                    coverMemoryImageIndex: coverIndex,
                    memoryAnchorRole: anchorRole,
                    memoryAnchorSceneHint: anchorScene,
                    memoryAnchorCaption: optionalText(statement, column: 24),
                    memoryAnchorCreatedAt: optionalDate(statement, column: 25)
                )
            )
        }
        return items
    }

    private func decodedDraftMeta(_ statement: OpaquePointer, id: String) throws -> HomeItem.DraftMeta? {
        let batchID = optionalText(statement, column: 10)
        let importedAt = optionalDate(statement, column: 11)
        let statusText = optionalText(statement, column: 12)
        if batchID == nil, importedAt == nil, statusText == nil { return nil }
        guard let batchID, let importedAt, let statusText,
              let status = HomeItem.DraftMeta.Status(rawValue: statusText) else {
            throw LedgerMetadataStoreError.invalidRecord("\(id) 的草稿字段不完整")
        }
        return HomeItem.DraftMeta(batchId: batchID, importedAt: importedAt, status: status)
    }

    private func decodedMemoryContext(_ statement: OpaquePointer) -> HomeItem.MemoryContext? {
        let weather = optionalText(statement, column: 16)
        let temperature = optionalDouble(statement, column: 17)
        let city = optionalText(statement, column: 18)
        let place = optionalText(statement, column: 19)
        guard weather != nil || temperature != nil || city != nil || place != nil else { return nil }
        return HomeItem.MemoryContext(
            weatherKind: weather,
            temperatureCelsius: temperature,
            cityName: city,
            semanticPlace: place
        )
    }

    private func readImageAssets(from database: OpaquePointer) throws -> [String: [ExistingAsset]] {
        let statement = try prepare(
            database,
            sql: "SELECT record_id, ordinal, relative_path, byte_count, media_type FROM image_assets ORDER BY record_id, ordinal",
            operation: "读取图片引用"
        )
        defer { sqlite3_finalize(statement) }
        var assets: [String: [ExistingAsset]] = [:]
        try forEachRow(statement, database: database, operation: "读取图片引用") {
            let recordID = requiredText(statement, column: 0)
            let ordinal = Int(sqlite3_column_int64(statement, 1))
            let expectedOrdinal = assets[recordID]?.count ?? 0
            guard ordinal == expectedOrdinal else {
                throw LedgerMetadataStoreError.invalidRecord("\(recordID) 的图片顺序不连续")
            }
            assets[recordID, default: []].append(
                ExistingAsset(
                    relativePath: requiredText(statement, column: 2),
                    byteCount: sqlite3_column_int64(statement, 3),
                    mediaType: requiredText(statement, column: 4)
                )
            )
        }
        return assets
    }

    private func audit(items: [HomeItem], in database: OpaquePointer) throws {
        var sourceFingerprints: [String: String] = [:]
        for item in items {
            let id = item.id.uuidString.lowercased()
            guard sourceFingerprints[id] == nil else {
                throw LedgerMetadataStoreError.auditMismatch("迁移源包含重复 ID：\(id)")
            }
            sourceFingerprints[id] = try recordFingerprint(item)
        }
        let storedFingerprints = try readFingerprints(from: database)
        guard sourceFingerprints == storedFingerprints else {
            throw LedgerMetadataStoreError.auditMismatch("记录字段或图片引用不一致")
        }
        let stats = try databaseStats(in: database)
        let expectedImages = items.reduce(0) { $0 + $1.memoryImageReferences.count }
        let expectedTotal = items.reduce(Int64(0)) { $0 + Self.minorUnits($1.amount) }
        guard stats.recordCount == items.count,
              stats.imageCount == expectedImages,
              stats.amountMinorUnitTotal == expectedTotal else {
            throw LedgerMetadataStoreError.auditMismatch("数量、金额或图片统计不一致")
        }
    }

    private func recordFingerprint(_ item: HomeItem) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return Self.sha256Hex(try encoder.encode(item))
    }

    private func itemsByID(_ items: [HomeItem]) throws -> [String: HomeItem] {
        var result: [String: HomeItem] = [:]
        for item in items {
            let id = item.id.uuidString.lowercased()
            guard result[id] == nil else {
                throw LedgerMetadataStoreError.auditMismatch("待保存账本包含重复 ID：\(id)")
            }
            result[id] = item
        }
        return result
    }

    private func validateExternalizedItems(_ items: [HomeItem]) throws {
        for item in items where item.hasMemoryImages {
            guard item.memoryImageReferences.count == item.memoryImageCount,
                  item.memoryImageReferences.allSatisfy({ !$0.isEmpty }) else {
                throw LedgerMetadataStoreError.invalidRecord(
                    "\(item.id.uuidString.lowercased()) 仍包含未文件化的图片"
                )
            }
        }
    }

    private func readFingerprints(from database: OpaquePointer) throws -> [String: String] {
        let statement = try prepare(
            database,
            sql: "SELECT id, record_fingerprint FROM records",
            operation: "读取账单摘要"
        )
        defer { sqlite3_finalize(statement) }
        var result: [String: String] = [:]
        try forEachRow(statement, database: database, operation: "读取账单摘要") {
            result[requiredText(statement, column: 0)] = requiredText(statement, column: 1)
        }
        return result
    }

    private func readRecordStats(id: String, from database: OpaquePointer) throws -> ExistingRecordStats? {
        let statement = try prepare(
            database,
            sql: """
            SELECT records.amount_minor_units, COUNT(image_assets.id)
            FROM records
            LEFT JOIN image_assets ON image_assets.record_id = records.id
            WHERE records.id = ?
            GROUP BY records.id, records.amount_minor_units
            """,
            operation: "读取变化账单摘要"
        )
        defer { sqlite3_finalize(statement) }
        var index: Int32 = 1
        try bind(id, statement: statement, index: &index)
        let result = sqlite3_step(statement)
        if result == SQLITE_DONE { return nil }
        guard result == SQLITE_ROW else {
            throw sqliteError(database, operation: "读取变化账单摘要")
        }
        return ExistingRecordStats(
            amountMinorUnits: sqlite3_column_int64(statement, 0),
            imageCount: Int(sqlite3_column_int64(statement, 1))
        )
    }

    private func readRecordVersions(from database: OpaquePointer) throws -> [String: ExistingRecordVersion] {
        let statement = try prepare(
            database,
            sql: "SELECT id, updated_at FROM records",
            operation: "读取账单版本"
        )
        defer { sqlite3_finalize(statement) }
        var result: [String: ExistingRecordVersion] = [:]
        try forEachRow(statement, database: database, operation: "读取账单版本") {
            result[requiredText(statement, column: 0)] = ExistingRecordVersion(
                updatedAt: sqlite3_column_double(statement, 1)
            )
        }
        return result
    }

    private func databaseStats(at url: URL) throws -> DatabaseStats {
        try withDatabase(at: url, createIfNeeded: false) { database in
            try validateDatabase(database)
            return try databaseStats(in: database)
        }
    }

    private func databaseStats(in database: OpaquePointer) throws -> DatabaseStats {
        let statement = try prepare(
            database,
            sql: """
            SELECT COUNT(*), COALESCE(SUM(amount_minor_units), 0),
                   (SELECT COUNT(*) FROM image_assets)
            FROM records
            """,
            operation: "统计账本"
        )
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw sqliteError(database, operation: "统计账本")
        }
        return DatabaseStats(
            recordCount: Int(sqlite3_column_int64(statement, 0)),
            imageCount: Int(sqlite3_column_int64(statement, 2)),
            amountMinorUnitTotal: sqlite3_column_int64(statement, 1)
        )
    }

    private func writeManifest(_ manifest: LedgerStoreManifest) throws {
        try fileManager.createDirectory(at: storeRootURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(manifest)
        try data.write(to: manifestURL, options: .atomic)
    }

    private func removeSQLiteFiles(at url: URL) throws {
        try removeSQLiteSidecars(at: url)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private func removeSQLiteSidecars(at url: URL) throws {
        for candidate in [URL(fileURLWithPath: url.path + "-wal"), URL(fileURLWithPath: url.path + "-shm")] {
            if fileManager.fileExists(atPath: candidate.path) {
                try fileManager.removeItem(at: candidate)
            }
        }
    }

    private func inTransaction(_ database: OpaquePointer, _ body: () throws -> Void) throws {
        try execute(database, sql: "BEGIN IMMEDIATE", operation: "开始账本事务")
        do {
            try body()
            try execute(database, sql: "COMMIT", operation: "提交账本事务")
        } catch {
            try? execute(database, sql: "ROLLBACK", operation: "回滚账本事务")
            throw error
        }
    }

    private func execute(_ database: OpaquePointer, sql: String, operation: String) throws {
        var errorPointer: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(database, sql, nil, nil, &errorPointer)
        guard result == SQLITE_OK else {
            let message = errorPointer.map { String(cString: $0) } ?? String(cString: sqlite3_errmsg(database))
            if let errorPointer { sqlite3_free(errorPointer) }
            throw LedgerMetadataStoreError.sqliteFailure(operation: operation, message: message)
        }
    }

    private func prepare(_ database: OpaquePointer, sql: String, operation: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw sqliteError(database, operation: operation)
        }
        return statement
    }

    private func stepDone(_ statement: OpaquePointer, database: OpaquePointer, operation: String) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw sqliteError(database, operation: operation)
        }
    }

    private func forEachRow(
        _ statement: OpaquePointer,
        database: OpaquePointer,
        operation: String,
        body: () throws -> Void
    ) throws {
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW:
                try body()
            case SQLITE_DONE:
                return
            default:
                throw sqliteError(database, operation: operation)
            }
        }
    }

    private func singleInt(_ database: OpaquePointer, sql: String, operation: String) throws -> Int64 {
        let statement = try prepare(database, sql: sql, operation: operation)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { throw sqliteError(database, operation: operation) }
        return sqlite3_column_int64(statement, 0)
    }

    private func singleText(_ database: OpaquePointer, sql: String, operation: String) throws -> String {
        let statement = try prepare(database, sql: sql, operation: operation)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { throw sqliteError(database, operation: operation) }
        return requiredText(statement, column: 0)
    }

    private func sqliteError(_ database: OpaquePointer, operation: String) -> LedgerMetadataStoreError {
        LedgerMetadataStoreError.sqliteFailure(
            operation: operation,
            message: String(cString: sqlite3_errmsg(database))
        )
    }

    private func bind(_ value: String?, statement: OpaquePointer, index: inout Int32) throws {
        let result: Int32
        if let value {
            let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            result = value.withCString { sqlite3_bind_text(statement, index, $0, -1, transient) }
        } else {
            result = sqlite3_bind_null(statement, index)
        }
        guard result == SQLITE_OK else {
            throw LedgerMetadataStoreError.sqliteFailure(operation: "绑定文本字段", message: "SQLite code \(result)")
        }
        index += 1
    }

    private func bind(_ value: Int64?, statement: OpaquePointer, index: inout Int32) throws {
        let result = value.map { sqlite3_bind_int64(statement, index, $0) }
            ?? sqlite3_bind_null(statement, index)
        guard result == SQLITE_OK else {
            throw LedgerMetadataStoreError.sqliteFailure(operation: "绑定整数字段", message: "SQLite code \(result)")
        }
        index += 1
    }

    private func bind(_ value: Double?, statement: OpaquePointer, index: inout Int32) throws {
        let result = value.map { sqlite3_bind_double(statement, index, $0) }
            ?? sqlite3_bind_null(statement, index)
        guard result == SQLITE_OK else {
            throw LedgerMetadataStoreError.sqliteFailure(operation: "绑定数值字段", message: "SQLite code \(result)")
        }
        index += 1
    }

    private func bind(_ value: Bool?, statement: OpaquePointer, index: inout Int32) throws {
        try bind(value.map { $0 ? Int64(1) : Int64(0) }, statement: statement, index: &index)
    }

    private func requiredText(_ statement: OpaquePointer, column: Int32) -> String {
        optionalText(statement, column: column) ?? ""
    }

    private func optionalText(_ statement: OpaquePointer, column: Int32) -> String? {
        guard sqlite3_column_type(statement, column) != SQLITE_NULL,
              let bytes = sqlite3_column_text(statement, column) else { return nil }
        let chars = UnsafeRawPointer(bytes).assumingMemoryBound(to: CChar.self)
        return String(cString: chars)
    }

    private func optionalInt(_ statement: OpaquePointer, column: Int32) -> Int64? {
        guard sqlite3_column_type(statement, column) != SQLITE_NULL else { return nil }
        return sqlite3_column_int64(statement, column)
    }

    private func optionalDouble(_ statement: OpaquePointer, column: Int32) -> Double? {
        guard sqlite3_column_type(statement, column) != SQLITE_NULL else { return nil }
        return sqlite3_column_double(statement, column)
    }

    private func optionalBool(_ statement: OpaquePointer, column: Int32) -> Bool? {
        optionalInt(statement, column: column).map { $0 != 0 }
    }

    private func optionalDate(_ statement: OpaquePointer, column: Int32) -> Date? {
        optionalDouble(statement, column: column).map { Date(timeIntervalSinceReferenceDate: $0) }
    }
}
