import Foundation

enum LedgerStorageSchema {
    static let legacyVersion = 1
    static let targetVersion = 2
    static let storeDirectoryName = "LedgerStore"
    static let metadataDatabaseName = "ledger-v2.sqlite"
    static let imageDirectoryName = "images"
    static let migrationDirectoryName = "migration"
}

struct LedgerStoreManifest: Codable, Equatable {
    enum ActiveStore: String, Codable {
        case legacyJSON
        case metadataV2
    }

    var schemaVersion: Int
    var activeStore: ActiveStore
    var sourceDigest: String
    var recordCount: Int
    var imageCount: Int
    var amountMinorUnitTotal: Int64
    var completedAt: Date?
}

struct LedgerRecordMetadataV2: Codable, Equatable, Identifiable {
    var id: UUID
    var title: String
    var amountMinorUnits: Int64
    var amountValue: Double
    var category: String
    var source: String
    var createdAt: Date
    var updatedAt: Date
    var emotionTag: String
    var merchantBrandId: String?
    var draftBatchId: String?
    var draftImportedAt: Date?
    var draftStatus: String?
    var userEditedTitle: Bool?
    var userEditedCategory: Bool?
    var categoryCorrectionFrom: String?
    var memoryWeatherKind: String?
    var memoryTemperatureCelsius: Double?
    var memoryCityName: String?
    var memorySemanticPlace: String?
    var scenePackId: String?
    var coverImageOrdinal: Int?
    var memoryAnchorRole: String?
    var memoryAnchorSceneHint: String?
    var memoryAnchorCaption: String?
    var memoryAnchorCreatedAt: Date?
}

struct LedgerImageAssetV2: Codable, Equatable, Identifiable {
    var id: String
    var recordId: UUID
    var ordinal: Int
    var relativePath: String
    var sha256: String
    var byteCount: Int
    var mediaType: String
}

struct LedgerMigrationCheckpoint: Codable, Equatable {
    enum Phase: String, Codable {
        case notStarted
        case inventoryComplete
        case imagesStaged
        case metadataStaged
        case validationComplete
        case activated
    }

    var schemaVersion: Int
    var sourceDigest: String
    var phase: Phase
    var nextRecordIndex: Int
    var stagedRecordCount: Int
    var stagedImageCount: Int
    var updatedAt: Date
    var lastError: String?
}

struct LedgerMigrationAudit: Codable, Equatable {
    var sourceRecordCount: Int
    var targetRecordCount: Int
    var sourceImageCount: Int
    var targetImageCount: Int
    var sourceAmountMinorUnitTotal: Int64
    var targetAmountMinorUnitTotal: Int64
    var sourceCategoryCounts: [String: Int]
    var targetCategoryCounts: [String: Int]
    var missingRecordIDs: [UUID]
    var mismatchedImageHashes: [String]

    var isValid: Bool {
        sourceRecordCount == targetRecordCount
            && sourceImageCount == targetImageCount
            && sourceAmountMinorUnitTotal == targetAmountMinorUnitTotal
            && sourceCategoryCounts == targetCategoryCounts
            && missingRecordIDs.isEmpty
            && mismatchedImageHashes.isEmpty
    }
}
