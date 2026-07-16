import XCTest
import UIKit
@testable import NativeDemoApp

final class LedgerImageStoreTests: XCTestCase {
    private var rootURL: URL!
    private var store: LedgerImageStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerImageStoreTests-\(UUID().uuidString)", isDirectory: true)
        store = LedgerImageStore(storeRootURL: rootURL)
    }

    override func tearDownWithError() throws {
        if let rootURL, FileManager.default.fileExists(atPath: rootURL.path) {
            try FileManager.default.removeItem(at: rootURL)
        }
        store = nil
        rootURL = nil
        try super.tearDownWithError()
    }

    func testImagesMoveOutOfJSONAndHydrateInOriginalOrder() throws {
        let first = Data([1, 2, 3])
        let second = Data([4, 5, 6])
        let item = HomeItem(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            title: "两张图",
            amount: 20,
            category: .shopping,
            memoryImageDatas: [first, second],
            coverMemoryImageIndex: 1
        )

        let externalized = try XCTUnwrap(store.prepareForPersistence([item]).first)
        XCTAssertEqual(externalized.memoryImageReferences.count, 2)
        XCTAssertEqual(externalized.coverMemoryImageIndex, 1)

        let encoded = try JSONEncoder().encode([externalized])
        let json = try XCTUnwrap(String(data: encoded, encoding: .utf8))
        XCTAssertTrue(json.contains("memoryImageReferences"))
        XCTAssertFalse(json.contains("memoryImageDatas"))
        XCTAssertFalse(json.contains("AQID"))

        let decoded = try JSONDecoder().decode([HomeItem].self, from: encoded)
        let hydrated = try XCTUnwrap(store.hydrate(decoded).first)
        XCTAssertEqual(hydrated.memoryImages, [first, second])
        XCTAssertEqual(hydrated.coverMemoryImageIndex, 1)
    }

    func testRemovingOneImageCleansOnlyItsOrphan() throws {
        var item = try XCTUnwrap(store.prepareForPersistence([
            HomeItem(
                id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
                title: "删一张",
                amount: 30,
                category: .shopping,
                memoryImageDatas: [Data([1]), Data([2])]
            )
        ]).first)
        let removedReference = item.memoryImageReferences[0]
        let keptReference = item.memoryImageReferences[1]

        item.removeMemoryImage(at: 0)
        let persisted = try XCTUnwrap(store.prepareForPersistence([item]).first)
        try store.cleanupOrphans(keeping: store.referencedPaths(in: [persisted]))

        XCTAssertFalse(FileManager.default.fileExists(atPath: rootURL.appendingPathComponent(removedReference).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: rootURL.appendingPathComponent(keptReference).path))
        XCTAssertEqual(persisted.memoryImages, [Data([2])])
    }

    func testMissingImageBecomesPlaceholderWithoutBreakingLedgerDecode() throws {
        let externalized = try XCTUnwrap(store.prepareForPersistence([
            HomeItem(
                id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
                title: "缺图恢复",
                amount: 40,
                category: .daily,
                memoryImageDatas: [Data([9, 9, 9])]
            )
        ]).first)
        let reference = try XCTUnwrap(externalized.memoryImageReferences.first)
        try FileManager.default.removeItem(at: rootURL.appendingPathComponent(reference))

        let encoded = try JSONEncoder().encode([externalized])
        let decoded = try JSONDecoder().decode([HomeItem].self, from: encoded)
        let hydrated = try XCTUnwrap(store.hydrate(decoded).first)

        XCTAssertEqual(hydrated.memoryImages.count, 1)
        XCTAssertTrue(hydrated.memoryImages[0].isEmpty)
        XCTAssertEqual(hydrated.unavailableMemoryImageIndices, [0])
        XCTAssertTrue(hydrated.hasMemoryImages)
    }

    func testMetadataOnlyStartupDefersOriginalAndCreatesThumbnailOnDemand() throws {
        let image = try XCTUnwrap(
            Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR42mN4l+MLAAPzAajtSvbZAAAAAElFTkSuQmCC")
        )
        let externalized = try XCTUnwrap(store.prepareForPersistence([
            HomeItem(
                id: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
                title: "按需加载",
                amount: 50,
                category: .shopping,
                memoryImageDatas: [image]
            )
        ]).first)
        let metadataOnly = try XCTUnwrap(store.metadataOnly([externalized]).first)
        let reference = try XCTUnwrap(metadataOnly.coverMemoryImageReference)

        XCTAssertTrue(metadataOnly.hasMemoryImages)
        XCTAssertNil(metadataOnly.coverMemoryImageData)
        XCTAssertEqual(metadataOnly.memoryImageByteCount(at: 0), image.count)
        XCTAssertEqual(store.loadData(reference: reference, variant: .original), image)

        let thumbnail = try XCTUnwrap(store.loadData(reference: reference, variant: .thumbnail))
        XCTAssertNotNil(UIImage(data: thumbnail))
        XCTAssertTrue(FileManager.default.fileExists(atPath: rootURL.appendingPathComponent("thumbnails").path))
    }
}
