import CryptoKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum LedgerLocalBackupError: LocalizedError {
    case missingImageReference(recordID: UUID, index: Int)

    var errorDescription: String? {
        switch self {
        case .missingImageReference(let recordID, let index):
            return "记录 \(recordID.uuidString) 的第 \(index + 1) 张照片暂时不可用，无法建立完整备份索引。"
        }
    }
}

struct LedgerLocalBackupDocument: FileDocument {
    struct Summary: Equatable {
        var recordCount: Int
        var photoReferenceCount: Int
        var exportedPhotoFileCount: Int
        var unavailablePhotoCount: Int
    }

    private struct BackupManifest: Codable {
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

    init(items: [HomeItem], exportedAt: Date = Date()) throws {
        var exportedItems: [HomeItem] = []
        var recordImageDirectories: [String: FileWrapper] = [:]
        var photoReferenceCount = 0
        var exportedPhotoFileCount = 0
        var unavailablePhotoCount = 0

        for source in items {
            let recordID = source.id.uuidString.lowercased()
            let images = source.memoryImages
            var references: [String] = []
            var exportedData: [Data] = []
            var unavailableIndices = Set<Int>()
            var imageFiles: [String: FileWrapper] = [:]
            references.reserveCapacity(images.count)
            exportedData.reserveCapacity(images.count)

            for (index, data) in images.enumerated() {
                photoReferenceCount += 1
                if !data.isEmpty {
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

                guard source.memoryImageReferences.indices.contains(index),
                      !source.memoryImageReferences[index].isEmpty else {
                    throw LedgerLocalBackupError.missingImageReference(recordID: source.id, index: index)
                }
                references.append(source.memoryImageReferences[index])
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
                note: "云端只同步账单字段；记忆照片仅保存在本机和这份手动导出的备份包中。"
            )
        )
        let readme = """
        叙账本地备份

        - ledger.json：账单字段与照片顺序/封面引用
        - images/：本次可读取的记忆照片
        - manifest.json：导出数量与缺图说明

        当前云端备份只同步金额、分类、备注、日期等账单字段，不上传记忆照片。
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
