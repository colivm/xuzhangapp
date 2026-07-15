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
}
