import CryptoKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum LedgerLocalBackupError: LocalizedError {
    case missingImageReference(recordID: UUID, index: Int)
    case invalidPackage(String)

    var errorDescription: String? {
        switch self {
        case .missingImageReference(let recordID, let index):
            return "记录 \(recordID.uuidString) 的第 \(index + 1) 张照片暂时不可用，无法建立完整备份索引。"
        case .invalidPackage(let message):
            return "这份备份无法恢复：\(message)"
        }
    }
}

struct LedgerLocalBackupDocument: FileDocument, @unchecked Sendable {
    struct Summary: Equatable {
        var recordCount: Int
        var photoReferenceCount: Int
        var exportedPhotoFileCount: Int
        var unavailablePhotoCount: Int
    }

    struct BackupManifest: Codable, Equatable {
        var schemaVersion: Int
        var exportedAt: Date
        var recordCount: Int
        var photoReferenceCount: Int
        var exportedPhotoFileCount: Int
        var unavailablePhotoCount: Int
        var cloudPhotoBackupSupported: Bool
        var note: String
    }

    static let contentType = UTType(
        exportedAs: "com.xuzhangapp.ledger-backup",
        conformingTo: .package
    )
    static var readableContentTypes: [UTType] { [contentType] }

    let summary: Summary
    private let rootWrapper: FileWrapper

    init(
        items: [HomeItem],
        exportedAt: Date = Date(),
        imageDataResolver: (String) -> Data? = {
            LocalStore.loadMemoryImageData(reference: $0, variant: .original)
        }
    ) throws {
        var exportedItems: [HomeItem] = []
        var recordImageDirectories: [String: FileWrapper] = [:]
        var photoReferenceCount = 0
        var exportedPhotoFileCount = 0
        var unavailablePhotoCount = 0

        for source in items {
            let recordID = source.id.uuidString.lowercased()
            var references: [String] = []
            var exportedData: [Data] = []
            var unavailableIndices = Set<Int>()
            var imageFiles: [String: FileWrapper] = [:]
            references.reserveCapacity(source.memoryImageCount)
            exportedData.reserveCapacity(source.memoryImageCount)

            for index in 0..<source.memoryImageCount {
                photoReferenceCount += 1
                let sourceReference = source.memoryImageReference(at: index)
                let data = source.memoryImageData(at: index)
                    ?? sourceReference.flatMap(imageDataResolver)
                if let data, !data.isEmpty {
                    let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                    let filename = "\(digest).jpg"
                    references.append("images/\(recordID)/\(filename)")
                    exportedData.append(Data())
                    if imageFiles[filename] == nil {
                        imageFiles[filename] = FileWrapper(regularFileWithContents: data)
                        exportedPhotoFileCount += 1
                    }
                    continue
                }

                guard let sourceReference else {
                    throw LedgerLocalBackupError.missingImageReference(recordID: source.id, index: index)
                }
                references.append(sourceReference)
                exportedData.append(Data())
                unavailableIndices.insert(index)
                unavailablePhotoCount += 1
            }

            var exportedItem = source
            exportedItem.setExternalMemoryImages(
                references: references,
                data: exportedData,
                unavailableIndices: unavailableIndices
            )
            exportedItems.append(exportedItem)
            if !imageFiles.isEmpty {
                recordImageDirectories[recordID] = FileWrapper(directoryWithFileWrappers: imageFiles)
            }
        }

        let summary = Summary(
            recordCount: exportedItems.count,
            photoReferenceCount: photoReferenceCount,
            exportedPhotoFileCount: exportedPhotoFileCount,
            unavailablePhotoCount: unavailablePhotoCount
        )
        self.summary = summary

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let ledgerData = try encoder.encode(exportedItems)
        let manifestData = try encoder.encode(
            BackupManifest(
                schemaVersion: LedgerStorageSchema.targetVersion,
                exportedAt: exportedAt,
                recordCount: summary.recordCount,
                photoReferenceCount: summary.photoReferenceCount,
                exportedPhotoFileCount: summary.exportedPhotoFileCount,
                unavailablePhotoCount: summary.unavailablePhotoCount,
                cloudPhotoBackupSupported: false,
                note: "云端只备份金额、分类、备注和日期；记忆照片仅保存在本机和这份手动导出的备份包中。"
            )
        )
        let readme = """
        叙账本地备份

        - ledger.json：账单信息与照片顺序/封面引用
        - images/：本次可读取的记忆照片
        - manifest.json：导出数量与缺图说明

        当前云端只备份金额、分类、备注和日期，不上传记忆照片。
        请把整个 .xuzhangbackup 备份包保存到“文件”、电脑或你信任的网盘，不要只取出其中一个文件。
        """

        var rootFiles: [String: FileWrapper] = [
            "ledger.json": FileWrapper(regularFileWithContents: ledgerData),
            "manifest.json": FileWrapper(regularFileWithContents: manifestData),
            "README.txt": FileWrapper(regularFileWithContents: Data(readme.utf8)),
        ]
        if !recordImageDirectories.isEmpty {
            rootFiles["images"] = FileWrapper(directoryWithFileWrappers: recordImageDirectories)
        }
        self.rootWrapper = FileWrapper(directoryWithFileWrappers: rootFiles)
    }

    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.fileReadUnsupportedScheme)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        rootWrapper
    }

    func exportedFileWrapperForTesting() -> FileWrapper {
        rootWrapper
    }
}

struct LedgerLocalBackupPreparedImport: Identifiable, @unchecked Sendable {
    struct Summary: Equatable, Sendable {
        var recordCount: Int
        var availablePhotoCount: Int
        var unavailablePhotoCount: Int
        var exportedPhotoFileCount: Int
        var exportedAt: Date
    }

    let id = UUID()
    let items: [HomeItem]
    let summary: Summary
}

enum LedgerLocalBackupImporter {
    static func prepare(from url: URL) throws -> LedgerLocalBackupPreparedImport {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
        let root = try FileWrapper(url: url, options: [.immediate])
        return try prepare(from: root)
    }

    static func prepare(from root: FileWrapper) throws -> LedgerLocalBackupPreparedImport {
        guard root.isDirectory, let rootFiles = root.fileWrappers else {
            throw LedgerLocalBackupError.invalidPackage("请选择完整的 .xuzhangbackup 备份包。")
        }
        guard let ledgerData = rootFiles["ledger.json"]?.regularFileContents,
              let manifestData = rootFiles["manifest.json"]?.regularFileContents else {
            throw LedgerLocalBackupError.invalidPackage("缺少 ledger.json 或 manifest.json。")
        }
        try validateLedgerShape(ledgerData)
        let manifest = try JSONDecoder().decode(LedgerLocalBackupDocument.BackupManifest.self, from: manifestData)
        guard manifest.schemaVersion == LedgerStorageSchema.targetVersion else {
            throw LedgerLocalBackupError.invalidPackage("备份版本不受支持。")
        }
        guard manifest.cloudPhotoBackupSupported == false else {
            throw LedgerLocalBackupError.invalidPackage("备份边界标记异常。")
        }
        guard manifest.recordCount >= 0,
              manifest.photoReferenceCount >= 0,
              manifest.exportedPhotoFileCount >= 0,
              manifest.unavailablePhotoCount >= 0,
              manifest.exportedPhotoFileCount <= manifest.photoReferenceCount,
              manifest.unavailablePhotoCount <= manifest.photoReferenceCount else {
            throw LedgerLocalBackupError.invalidPackage("清单数量无效。")
        }
        let decodedItems = try JSONDecoder().decode([HomeItem].self, from: ledgerData)
        guard decodedItems.count == manifest.recordCount else {
            throw LedgerLocalBackupError.invalidPackage("记录数量与清单不一致。")
        }
        guard Set(decodedItems.map(\.id)).count == decodedItems.count else {
            throw LedgerLocalBackupError.invalidPackage("存在重复记录 ID。")
        }

        var restoredItems: [HomeItem] = []
        var photoReferenceCount = 0
        var availablePhotoCount = 0
        var unavailablePhotoCount = 0
        var availableFiles = Set<String>()
        restoredItems.reserveCapacity(decodedItems.count)

        for source in decodedItems {
            guard source.memoryImageReferences.count == source.memoryImageCount else {
                throw LedgerLocalBackupError.invalidPackage("记录 \(source.id.uuidString) 的照片索引不完整。")
            }
            var restoredReferences: [String] = []
            var restoredData: [Data] = []
            var restoredByteCounts: [Int] = []
            var unavailableIndices = Set<Int>()
            restoredReferences.reserveCapacity(source.memoryImageReferences.count)
            restoredData.reserveCapacity(source.memoryImageReferences.count)
            restoredByteCounts.reserveCapacity(source.memoryImageReferences.count)
            for (index, reference) in source.memoryImageReferences.enumerated() {
                photoReferenceCount += 1
                let components = try validatedImageComponents(reference, recordID: source.id)
                guard let wrapper = fileWrapper(at: components, root: root),
                      let data = wrapper.regularFileContents,
                      !data.isEmpty else {
                    restoredReferences.append(reference)
                    restoredData.append(Data())
                    restoredByteCounts.append(source.memoryImageByteCount(at: index))
                    unavailableIndices.insert(index)
                    unavailablePhotoCount += 1
                    continue
                }
                let expectedDigest = URL(fileURLWithPath: reference)
                    .deletingPathExtension()
                    .lastPathComponent
                    .lowercased()
                let actualDigest = SHA256.hash(data: data)
                    .map { String(format: "%02x", $0) }
                    .joined()
                guard expectedDigest == actualDigest else {
                    throw LedgerLocalBackupError.invalidPackage("照片校验失败：\(reference)。")
                }
                restoredReferences.append("")
                restoredData.append(data)
                restoredByteCounts.append(data.count)
                availablePhotoCount += 1
                availableFiles.insert(reference)
            }

            var restored = source
            restored.setExternalMemoryImages(
                references: restoredReferences,
                data: restoredData,
                byteCounts: restoredByteCounts,
                unavailableIndices: unavailableIndices
            )
            restoredItems.append(restored)
        }

        guard photoReferenceCount == manifest.photoReferenceCount,
              unavailablePhotoCount == manifest.unavailablePhotoCount,
              availableFiles.count == manifest.exportedPhotoFileCount else {
            throw LedgerLocalBackupError.invalidPackage("照片数量与清单不一致。")
        }

        return LedgerLocalBackupPreparedImport(
            items: restoredItems,
            summary: .init(
                recordCount: restoredItems.count,
                availablePhotoCount: availablePhotoCount,
                unavailablePhotoCount: unavailablePhotoCount,
                exportedPhotoFileCount: availableFiles.count,
                exportedAt: manifest.exportedAt
            )
        )
    }

    private static func validateLedgerShape(_ data: Data) throws {
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw LedgerLocalBackupError.invalidPackage("ledger.json 格式无效。")
        }
        let requiredKeys = ["id", "title", "amount", "category", "source", "createdAt", "updatedAt", "emotionTag"]
        for (index, row) in rows.enumerated() {
            guard requiredKeys.allSatisfy({ row[$0] != nil }) else {
                throw LedgerLocalBackupError.invalidPackage("第 \(index + 1) 条记录字段不完整。")
            }
            guard let id = row["id"] as? String, UUID(uuidString: id) != nil,
                  row["title"] is String,
                  row["amount"] is NSNumber,
                  let category = row["category"] as? String,
                  HomeItem.Category(rawValue: category) != nil,
                  let source = row["source"] as? String,
                  HomeItem.Source(rawValue: source) != nil else {
                throw LedgerLocalBackupError.invalidPackage("第 \(index + 1) 条记录内容无效。")
            }
        }
    }

    private static func validatedImageComponents(_ reference: String, recordID: UUID) throws -> [String] {
        let components = reference.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        let expectedRecordID = recordID.uuidString.lowercased()
        let filename = components.last ?? ""
        let digest = String(filename.dropLast(4)).lowercased()
        guard components.count == 3,
              components[0] == "images",
              components[1].lowercased() == expectedRecordID,
              filename.lowercased().hasSuffix(".jpg"),
              digest.count == 64,
              digest.allSatisfy({ $0.isHexDigit }),
              !components.contains("..") else {
            throw LedgerLocalBackupError.invalidPackage("照片路径越界：\(reference)。")
        }
        return components
    }

    private static func fileWrapper(at components: [String], root: FileWrapper) -> FileWrapper? {
        var current = root
        for component in components {
            guard current.isDirectory,
                  let next = current.fileWrappers?[component] else { return nil }
            current = next
        }
        return current
    }
}

struct LedgerLocalBackupRestoreSummary: Equatable, Sendable {
    var insertedRecordCount: Int
    var updatedRecordCount: Int
    var keptLocalRecordCount: Int

    var restoredRecordCount: Int {
        insertedRecordCount + updatedRecordCount
    }
}

struct LedgerLocalBackupRestorePlan: @unchecked Sendable {
    let mergedItems: [HomeItem]
    let changes: LedgerHomeItemsChangeSet
    let summary: LedgerLocalBackupRestoreSummary
}

enum LedgerLocalBackupRestorePlanner {
    static func makePlan(
        localItems: [HomeItem],
        backupItems: [HomeItem]
    ) throws -> LedgerLocalBackupRestorePlan {
        guard Set(backupItems.map(\.id)).count == backupItems.count else {
            throw LedgerLocalBackupError.invalidPackage("存在重复记录 ID。")
        }

        var mergedByID = Dictionary(uniqueKeysWithValues: localItems.map { ($0.id, $0) })
        var upserts: [HomeItem] = []
        var inserted = 0
        var updated = 0
        var keptLocal = 0

        for backupItem in backupItems {
            guard let localItem = mergedByID[backupItem.id] else {
                mergedByID[backupItem.id] = backupItem
                upserts.append(backupItem)
                inserted += 1
                continue
            }
            guard backupItem.updatedAt > localItem.updatedAt else {
                keptLocal += 1
                continue
            }
            mergedByID[backupItem.id] = backupItem
            upserts.append(backupItem)
            updated += 1
        }

        let mergedItems = mergedByID.values.sorted(by: stableLedgerOrder)
        return LedgerLocalBackupRestorePlan(
            mergedItems: mergedItems,
            changes: LedgerHomeItemsChangeSet(upserts: upserts, deletedIDs: []),
            summary: LedgerLocalBackupRestoreSummary(
                insertedRecordCount: inserted,
                updatedRecordCount: updated,
                keptLocalRecordCount: keptLocal
            )
        )
    }

    private static func stableLedgerOrder(_ lhs: HomeItem, _ rhs: HomeItem) -> Bool {
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

enum LedgerLocalBackupRestorer {
    static func restore(
        localItems: inout [HomeItem],
        backupItems: [HomeItem],
        persist: (LedgerHomeItemsChangeSet, [HomeItem]) -> Bool
    ) throws -> LedgerLocalBackupRestoreSummary? {
        let plan = try LedgerLocalBackupRestorePlanner.makePlan(
            localItems: localItems,
            backupItems: backupItems
        )
        if !plan.changes.isEmpty,
           !persist(plan.changes, plan.mergedItems) {
            return nil
        }
        localItems = plan.mergedItems
        return plan.summary
    }
}
