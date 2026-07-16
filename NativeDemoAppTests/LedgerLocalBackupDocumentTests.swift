import Foundation
import XCTest
@testable import NativeDemoApp

final class LedgerLocalBackupDocumentTests: XCTestCase {
    func testBackupPackageContainsRefsOnlyLedgerAndAvailablePhotoFiles() throws {
        let image = Data([1, 2, 3, 4])
        let item = HomeItem(
            id: UUID(uuidString: "AAAAAAAA-1111-1111-1111-AAAAAAAAAAAA")!,
            title: "两张相同照片",
            amount: 12.5,
            category: .shopping,
            memoryImageDatas: [image, image],
            coverMemoryImageIndex: 1
        )

        let document = try LedgerLocalBackupDocument(items: [item])
        let root = document.exportedFileWrapperForTesting()
        let rootFiles = try XCTUnwrap(root.fileWrappers)
        let ledgerData = try XCTUnwrap(rootFiles["ledger.json"]?.regularFileContents)
        let ledgerJSON = try XCTUnwrap(String(data: ledgerData, encoding: .utf8))
        let decoded = try JSONDecoder().decode([HomeItem].self, from: ledgerData)

        XCTAssertTrue(ledgerJSON.contains("memoryImageReferences"))
        XCTAssertFalse(ledgerJSON.contains("memoryImageDatas"))
        XCTAssertEqual(decoded.first?.memoryImageReferences.count, 2)
        XCTAssertEqual(decoded.first?.memoryImageReferences[0], decoded.first?.memoryImageReferences[1])
        XCTAssertEqual(decoded.first?.coverMemoryImageIndex, 1)
        XCTAssertEqual(document.summary.recordCount, 1)
        XCTAssertEqual(document.summary.photoReferenceCount, 2)
        XCTAssertEqual(document.summary.exportedPhotoFileCount, 1)
        XCTAssertEqual(document.summary.unavailablePhotoCount, 0)

        let images = try XCTUnwrap(rootFiles["images"]?.fileWrappers)
        let recordFolder = try XCTUnwrap(images[item.id.uuidString.lowercased()]?.fileWrappers)
        XCTAssertEqual(recordFolder.count, 1)
        XCTAssertEqual(recordFolder.values.first?.regularFileContents, image)

        let manifestData = try XCTUnwrap(rootFiles["manifest.json"]?.regularFileContents)
        let manifest = try XCTUnwrap(JSONSerialization.jsonObject(with: manifestData) as? [String: Any])
        XCTAssertEqual(manifest["cloudPhotoBackupSupported"] as? Bool, false)
        XCTAssertEqual(manifest["photoReferenceCount"] as? Int, 2)
    }

    func testUnavailablePhotoIsReportedWithoutBreakingLedgerExport() throws {
        let reference = "images/bbbbbbbb-2222-2222-2222-bbbbbbbbbbbb/\(String(repeating: "a", count: 64)).jpg"
        let item = HomeItem(
            id: UUID(uuidString: "BBBBBBBB-2222-2222-2222-BBBBBBBBBBBB")!,
            title: "缺图记录",
            amount: 8,
            category: .daily,
            memoryImageReferences: [reference]
        )

        let document = try LedgerLocalBackupDocument(items: [item])
        let rootFiles = try XCTUnwrap(document.exportedFileWrapperForTesting().fileWrappers)

        XCTAssertEqual(document.summary.photoReferenceCount, 1)
        XCTAssertEqual(document.summary.exportedPhotoFileCount, 0)
        XCTAssertEqual(document.summary.unavailablePhotoCount, 1)
        XCTAssertNil(rootFiles["images"])
        let ledgerData = try XCTUnwrap(rootFiles["ledger.json"]?.regularFileContents)
        XCTAssertEqual(try JSONDecoder().decode([HomeItem].self, from: ledgerData).first?.memoryImageReferences, [reference])
    }

    func testImageWithoutDataOrStableReferenceCannotClaimCompleteExport() {
        let item = HomeItem(
            title: "无引用缺图",
            amount: 3,
            category: .other,
            memoryImageDatas: [Data()]
        )

        XCTAssertThrowsError(try LedgerLocalBackupDocument(items: [item]))
    }

    func testExportImportRoundTripPreservesRecordOrderPhotosAndCover() throws {
        let exportedAt = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let first = HomeItem(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "先导出的记录",
            amount: 18,
            category: .dining,
            createdAt: exportedAt.addingTimeInterval(-60),
            updatedAt: exportedAt.addingTimeInterval(-30),
            memoryImageDatas: [Data([1, 2, 3]), Data([4, 5, 6])],
            coverMemoryImageIndex: 1
        )
        let second = HomeItem(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            title: "后导出的记录",
            amount: 28,
            category: .transport,
            createdAt: exportedAt.addingTimeInterval(-120),
            updatedAt: exportedAt.addingTimeInterval(-20)
        )

        let document = try LedgerLocalBackupDocument(
            items: [first, second],
            exportedAt: exportedAt
        )
        let prepared = try LedgerLocalBackupImporter.prepare(
            from: document.exportedFileWrapperForTesting()
        )

        XCTAssertEqual(prepared.items.map(\.id), [first.id, second.id])
        XCTAssertEqual(prepared.items[0].memoryImages, first.memoryImages)
        XCTAssertEqual(prepared.items[0].coverMemoryImageIndex, 1)
        XCTAssertEqual(prepared.summary.recordCount, 2)
        XCTAssertEqual(prepared.summary.availablePhotoCount, 2)
        XCTAssertEqual(prepared.summary.unavailablePhotoCount, 0)
        XCTAssertEqual(prepared.summary.exportedAt, exportedAt)
    }

    func testTamperedPhotoDigestRejectsImport() throws {
        let item = HomeItem(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            title: "校验照片",
            amount: 6,
            category: .daily,
            memoryImageDatas: [Data([1, 3, 5, 7])]
        )
        let document = try LedgerLocalBackupDocument(items: [item])
        let tamperedRoot = try replacingFirstPhoto(
            in: document.exportedFileWrapperForTesting(),
            with: Data([9, 9, 9, 9])
        )

        XCTAssertThrowsError(try LedgerLocalBackupImporter.prepare(from: tamperedRoot)) { error in
            XCTAssertTrue(error.localizedDescription.contains("照片校验失败"))
        }
    }

    func testOfficialExportWithUnavailablePhotoImportsAsMissingSlot() throws {
        let digest = String(repeating: "b", count: 64)
        let reference = "images/44444444-4444-4444-4444-444444444444/\(digest).jpg"
        let item = HomeItem(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            title: "导出时缺图",
            amount: 9,
            category: .other,
            memoryImageReferences: [reference],
            coverMemoryImageIndex: 0
        )
        let document = try LedgerLocalBackupDocument(
            items: [item],
            imageDataResolver: { _ in nil }
        )

        let prepared = try LedgerLocalBackupImporter.prepare(
            from: document.exportedFileWrapperForTesting()
        )

        XCTAssertEqual(prepared.summary.availablePhotoCount, 0)
        XCTAssertEqual(prepared.summary.unavailablePhotoCount, 1)
        XCTAssertEqual(prepared.items[0].memoryImageCount, 1)
        XCTAssertEqual(prepared.items[0].memoryImageReferences, [reference])
        XCTAssertEqual(prepared.items[0].unavailableMemoryImageIndices, Set([0]))
        XCTAssertEqual(prepared.items[0].coverMemoryImageIndex, 0)
    }

    func testDuplicateRecordIDRejectsImportEvenWhenManifestCountMatches() throws {
        let item = HomeItem(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            title: "重复记录",
            amount: 11,
            category: .shopping
        )
        let document = try LedgerLocalBackupDocument(items: [item])
        let root = document.exportedFileWrapperForTesting()
        let rootFiles = try XCTUnwrap(root.fileWrappers)
        let ledgerData = try XCTUnwrap(rootFiles["ledger.json"]?.regularFileContents)
        let decoded = try JSONDecoder().decode([HomeItem].self, from: ledgerData)
        var manifest = try JSONDecoder().decode(
            LedgerLocalBackupDocument.BackupManifest.self,
            from: try XCTUnwrap(rootFiles["manifest.json"]?.regularFileContents)
        )
        manifest.recordCount = 2
        let encoder = JSONEncoder()
        var replacements = rootFiles
        replacements["ledger.json"] = FileWrapper(
            regularFileWithContents: try encoder.encode([decoded[0], decoded[0]])
        )
        replacements["manifest.json"] = FileWrapper(
            regularFileWithContents: try encoder.encode(manifest)
        )
        let duplicateRoot = FileWrapper(directoryWithFileWrappers: replacements)

        XCTAssertThrowsError(try LedgerLocalBackupImporter.prepare(from: duplicateRoot)) { error in
            XCTAssertTrue(error.localizedDescription.contains("重复记录 ID"))
        }
    }

    func testManifestCountMismatchRejectsImport() throws {
        let document = try LedgerLocalBackupDocument(items: [
            HomeItem(title: "数量不符", amount: 5, category: .other)
        ])
        let root = document.exportedFileWrapperForTesting()
        let rootFiles = try XCTUnwrap(root.fileWrappers)
        var manifest = try JSONDecoder().decode(
            LedgerLocalBackupDocument.BackupManifest.self,
            from: try XCTUnwrap(rootFiles["manifest.json"]?.regularFileContents)
        )
        manifest.recordCount += 1
        var replacements = rootFiles
        replacements["manifest.json"] = FileWrapper(
            regularFileWithContents: try JSONEncoder().encode(manifest)
        )

        XCTAssertThrowsError(
            try LedgerLocalBackupImporter.prepare(
                from: FileWrapper(directoryWithFileWrappers: replacements)
            )
        ) { error in
            XCTAssertTrue(error.localizedDescription.contains("记录数量与清单不一致"))
        }
    }

    func testRestorePlanKeepsNewerLocalUpdatesOlderLocalAndInsertsMissing() throws {
        let base = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let keepID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
        let updateID = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
        let insertID = UUID(uuidString: "88888888-8888-8888-8888-888888888888")!
        let local = [
            HomeItem(id: keepID, title: "本机较新", amount: 1, category: .daily, createdAt: base, updatedAt: base.addingTimeInterval(30)),
            HomeItem(id: updateID, title: "本机较旧", amount: 2, category: .daily, createdAt: base.addingTimeInterval(-10), updatedAt: base.addingTimeInterval(10)),
        ]
        let backup = [
            HomeItem(id: keepID, title: "备份较旧", amount: 3, category: .daily, createdAt: base, updatedAt: base.addingTimeInterval(20)),
            HomeItem(id: updateID, title: "备份较新", amount: 4, category: .daily, createdAt: base.addingTimeInterval(-10), updatedAt: base.addingTimeInterval(40)),
            HomeItem(id: insertID, title: "备份新增", amount: 5, category: .daily, createdAt: base.addingTimeInterval(10), updatedAt: base.addingTimeInterval(50)),
        ]

        let plan = try LedgerLocalBackupRestorePlanner.makePlan(
            localItems: local,
            backupItems: backup
        )

        XCTAssertEqual(plan.summary.insertedRecordCount, 1)
        XCTAssertEqual(plan.summary.updatedRecordCount, 1)
        XCTAssertEqual(plan.summary.keptLocalRecordCount, 1)
        XCTAssertEqual(Set(plan.changes.upserts.map(\.id)), Set([updateID, insertID]))
        XCTAssertEqual(plan.mergedItems.first?.id, insertID)
        XCTAssertEqual(plan.mergedItems.first(where: { $0.id == keepID })?.title, "本机较新")
        XCTAssertEqual(plan.mergedItems.first(where: { $0.id == updateID })?.title, "备份较新")
    }

    func testRestorePersistenceFailureDoesNotMutateLocalLedger() throws {
        let local = [HomeItem(title: "原账本", amount: 7, category: .daily)]
        let backup = [HomeItem(title: "备份新增", amount: 8, category: .shopping)]
        var current = local

        let result = try LedgerLocalBackupRestorer.restore(
            localItems: &current,
            backupItems: backup,
            persist: { _, _ in false }
        )

        XCTAssertNil(result)
        XCTAssertEqual(current, local)
    }

    private func replacingFirstPhoto(in root: FileWrapper, with data: Data) throws -> FileWrapper {
        var rootFiles = try XCTUnwrap(root.fileWrappers)
        let images = try XCTUnwrap(rootFiles["images"]?.fileWrappers)
        let recordKey = try XCTUnwrap(images.keys.sorted().first)
        var recordFiles = try XCTUnwrap(images[recordKey]?.fileWrappers)
        let photoKey = try XCTUnwrap(recordFiles.keys.sorted().first)
        recordFiles[photoKey] = FileWrapper(regularFileWithContents: data)
        var imageDirectories = images
        imageDirectories[recordKey] = FileWrapper(directoryWithFileWrappers: recordFiles)
        rootFiles["images"] = FileWrapper(directoryWithFileWrappers: imageDirectories)
        return FileWrapper(directoryWithFileWrappers: rootFiles)
    }
}
