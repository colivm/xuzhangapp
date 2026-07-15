import Foundation
import XCTest
@testable import NativeDemoApp

final class LedgerMetadataStoreTests: XCTestCase {
    private var documentsURL: URL!
    private var defaults: UserDefaults!
    private var defaultsSuiteName: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        documentsURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerMetadataStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        defaultsSuiteName = "LedgerMetadataStoreTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
    }

    override func tearDownWithError() throws {
        if let documentsURL, FileManager.default.fileExists(atPath: documentsURL.path) {
            try FileManager.default.removeItem(at: documentsURL)
        }
        if let defaultsSuiteName {
            defaults?.removePersistentDomain(forName: defaultsSuiteName)
        }
        defaults = nil
        defaultsSuiteName = nil
        documentsURL = nil
        try super.tearDownWithError()
    }

    func testMigrationActivatesSQLiteAndPreservesDuplicateImageOrder() throws {
        let root = documentsURL.appendingPathComponent(LedgerStorageSchema.storeDirectoryName, isDirectory: true)
        let imageStore = LedgerImageStore(storeRootURL: root)
        let metadataStore = LedgerMetadataStore(storeRootURL: root)
        let repeatedImage = Data([1, 2, 3, 4])
        let createdAt = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let item = HomeItem(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            title: "完整迁移",
            amount: 88.605,
            category: .shopping,
            source: .ocr,
            createdAt: createdAt,
            updatedAt: createdAt.addingTimeInterval(60),
            emotionTag: "原样保留",
            merchantBrandId: "brand-a",
            draftMeta: HomeItem.DraftMeta(batchId: "batch-a", importedAt: createdAt, status: .pending),
            userEditedTitle: false,
            userEditedCategory: true,
            categoryCorrectionFrom: .daily,
            memoryContext: HomeItem.MemoryContext(
                weatherKind: "sunny",
                temperatureCelsius: 26,
                cityName: "杭州",
                semanticPlace: "商场"
            ),
            scenePackId: "scene-a",
            memoryImageDatas: [repeatedImage, repeatedImage],
            coverMemoryImageIndex: 1,
            memoryAnchorRole: .object,
            memoryAnchorSceneHint: .importantPurchase,
            memoryAnchorCaption: "同一张图也保留两次顺序",
            memoryAnchorCreatedAt: createdAt
        )
        let externalized = try XCTUnwrap(imageStore.prepareForPersistence([item]).first)

        try metadataStore.activate(items: [externalized], sourceDigest: "fixture-digest")

        let manifest = try XCTUnwrap(metadataStore.loadManifest())
        XCTAssertEqual(manifest.activeStore, .metadataV2)
        XCTAssertEqual(manifest.recordCount, 1)
        XCTAssertEqual(manifest.imageCount, 2)
        let loaded = try XCTUnwrap(metadataStore.loadItems().first)
        XCTAssertEqual(loaded.id, item.id)
        XCTAssertEqual(loaded.title, item.title)
        XCTAssertEqual(loaded.amount, item.amount, accuracy: 0.000_001)
        XCTAssertEqual(loaded.draftMeta, item.draftMeta)
        XCTAssertEqual(loaded.memoryContext, item.memoryContext)
        XCTAssertEqual(loaded.memoryImageReferences.count, 2)
        XCTAssertEqual(loaded.memoryImageReferences[0], loaded.memoryImageReferences[1])
        XCTAssertEqual(loaded.coverMemoryImageIndex, 1)
        XCTAssertEqual(imageStore.hydrate([loaded]).first?.memoryImages, [repeatedImage, repeatedImage])
    }

    func testReconcileReportsOnlyInsertedUpdatedAndDeletedRows() throws {
        let root = documentsURL.appendingPathComponent(LedgerStorageSchema.storeDirectoryName, isDirectory: true)
        let metadataStore = LedgerMetadataStore(storeRootURL: root)
        let first = HomeItem(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            title: "第一笔",
            amount: 10,
            category: .dining
        )
        let second = HomeItem(
            id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
            title: "第二笔",
            amount: 20,
            category: .transport
        )
        try metadataStore.activate(items: [first, second], sourceDigest: "fixture-digest")

        XCTAssertEqual(
            try metadataStore.reconcile([first, second]),
            LedgerMetadataWriteSummary(inserted: 0, updated: 0, deleted: 0, unchanged: 2)
        )

        var updatedFirst = first
        updatedFirst.title = "第一笔已修改"
        updatedFirst.updatedAt = first.updatedAt.addingTimeInterval(60)
        let third = HomeItem(
            id: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
            title: "第三笔",
            amount: 30,
            category: .health
        )
        let summary = try metadataStore.reconcile([updatedFirst, third])

        XCTAssertEqual(summary.inserted, 1)
        XCTAssertEqual(summary.updated, 1)
        XCTAssertEqual(summary.deleted, 1)
        XCTAssertEqual(summary.unchanged, 0)
        let loaded = try metadataStore.loadItems()
        XCTAssertEqual(Set(loaded.map(\.id)), Set([updatedFirst.id, third.id]))
        XCTAssertEqual(loaded.first(where: { $0.id == updatedFirst.id })?.title, "第一笔已修改")
    }

    func testCorruptActiveDatabaseFallsBackToRetainedLegacyWithoutEmptyOverwrite() throws {
        let legacyItem = HomeItem(
            id: UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!,
            title: "旧账本仍在",
            amount: 45,
            category: .home
        )
        let legacyData = try JSONEncoder().encode([legacyItem])
        let legacyURL = documentsURL.appendingPathComponent("home_items_v1.json")
        try legacyData.write(to: legacyURL, options: .atomic)
        defaults.set(legacyData, forKey: "home_items_v1_backup")

        let repository = LedgerHomeItemsRepository(documentsURL: documentsURL, defaults: defaults)
        XCTAssertEqual(repository.load().items.map(\.id), [legacyItem.id])

        let databaseURL = documentsURL
            .appendingPathComponent(LedgerStorageSchema.storeDirectoryName, isDirectory: true)
            .appendingPathComponent(LedgerStorageSchema.metadataDatabaseName)
        try Data("not-a-sqlite-database".utf8).write(to: databaseURL, options: .atomic)

        let recovered = LedgerHomeItemsRepository(documentsURL: documentsURL, defaults: defaults).load()

        XCTAssertFalse(recovered.writesBlocked)
        XCTAssertNotNil(recovered.issueMessage)
        XCTAssertEqual(recovered.items.map(\.id), [legacyItem.id])
        XCTAssertEqual(try Data(contentsOf: legacyURL), legacyData)
    }

    func testUnreadableLegacySourcesBlockSaveAndPreserveOriginalBytes() throws {
        let invalidData = Data("not-json".utf8)
        let legacyURL = documentsURL.appendingPathComponent("home_items_v1.json")
        try invalidData.write(to: legacyURL, options: .atomic)
        defaults.set(Data("also-not-json".utf8), forKey: "home_items_v1_backup")
        let repository = LedgerHomeItemsRepository(documentsURL: documentsURL, defaults: defaults)

        let loadResult = repository.load()
        XCTAssertTrue(loadResult.writesBlocked)
        XCTAssertTrue(loadResult.items.isEmpty)

        let newItem = HomeItem(title: "不能覆盖原文件", amount: 1, category: .other)
        XCTAssertFalse(repository.save([newItem]))
        XCTAssertEqual(try Data(contentsOf: legacyURL), invalidData)
    }
}
