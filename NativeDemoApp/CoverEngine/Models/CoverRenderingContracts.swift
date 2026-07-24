import Foundation
import UIKit

enum CoverRenderSchema {
    static let currentVersion = 1
}

struct CoverRenderSize: Codable, Equatable, Sendable {
    let width: Double
    let height: Double

    var isValid: Bool {
        width.isFinite && height.isFinite && width > 0 && height > 0
    }
}

struct CoverRenderRect: Codable, Equatable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    var maxX: Double { x + width }
    var maxY: Double { y + height }

    var isValid: Bool {
        [x, y, width, height].allSatisfy(\.isFinite)
            && width > 0
            && height > 0
    }

    func isInside(_ size: CoverRenderSize) -> Bool {
        isValid
            && x >= 0
            && y >= 0
            && maxX <= size.width
            && maxY <= size.height
    }

    func intersects(_ other: CoverRenderRect) -> Bool {
        x < other.maxX
            && maxX > other.x
            && y < other.maxY
            && maxY > other.y
    }
}

enum CoverTextRole: String, Codable, Sendable {
    case masthead
    case lead
    case support
    case caption
    case mark
    case timeline
}

enum CoverTextAlignmentToken: String, Codable, Sendable {
    case leading
    case center
    case trailing
}

struct ResolvedCoverAtomPlacement: Codable, Equatable, Sendable, Identifiable {
    let atomID: String
    let frame: CoverRenderRect
    let textRole: CoverTextRole
    let alignment: CoverTextAlignmentToken
    let lineLimit: Int

    var id: String { atomID }
}

struct ResolvedCoverMediaPlacement: Codable, Equatable, Sendable, Identifiable {
    let mediaID: UUID
    let frame: CoverRenderRect
    let cropMode: CropMode
    let treatment: MediaTreatment
    let zIndex: Int

    var id: UUID { mediaID }
}

struct ResolvedCoverLayout: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let layoutID: String
    let recipeID: String
    let sourceRevision: Int
    let periodKey: String
    let contentFingerprint: String
    let canvasSize: CoverRenderSize
    let footerFrame: CoverRenderRect
    let bodyAtomPlacements: [ResolvedCoverAtomPlacement]
    let mediaPlacements: [ResolvedCoverMediaPlacement]
}

struct CoverRenderIdentity: Codable, Equatable, Hashable, Sendable {
    let sourceRevision: Int
    let periodKey: String
    let contentFingerprint: String
    let recipeID: String
    let layoutID: String
    let sourceKey: String
}

struct CoverFooterPresentation: Equatable, Sendable {
    let textAtomIDs: [String]
    let text: String
    let qrCodeAtomID: String?
    let qrCodeURL: String?
}

final class PreparedCoverRenderInput: @unchecked Sendable {
    let identity: CoverRenderIdentity
    let recipe: CoverRecipe
    let allocation: ContentAllocationPlan
    let layout: ResolvedCoverLayout
    let preparedImagesByID: [UUID: UIImage]
    let mediaAnalysesByID: [UUID: CoverMediaAnalysis]
    let dynamicPalette: CoverDynamicPalette?
    let backgroundImage: UIImage?
    let verifiedQRCodeImage: UIImage?
    let footerPresentation: CoverFooterPresentation
    let unavailableMediaCount: Int

    init(
        identity: CoverRenderIdentity,
        recipe: CoverRecipe,
        allocation: ContentAllocationPlan,
        layout: ResolvedCoverLayout,
        preparedImagesByID: [UUID: UIImage],
        mediaAnalysesByID: [UUID: CoverMediaAnalysis],
        dynamicPalette: CoverDynamicPalette?,
        backgroundImage: UIImage?,
        verifiedQRCodeImage: UIImage?,
        footerPresentation: CoverFooterPresentation,
        unavailableMediaCount: Int
    ) {
        self.identity = identity
        self.recipe = recipe
        self.allocation = allocation
        self.layout = layout
        self.preparedImagesByID = preparedImagesByID
        self.mediaAnalysesByID = mediaAnalysesByID
        self.dynamicPalette = dynamicPalette
        self.backgroundImage = backgroundImage
        self.verifiedQRCodeImage = verifiedQRCodeImage
        self.footerPresentation = footerPresentation
        self.unavailableMediaCount = unavailableMediaCount
    }
}

struct CoverShareSession: @unchecked Sendable {
    private let lockedRenderInput: PreparedCoverRenderInput

    init(renderInput: PreparedCoverRenderInput) {
        lockedRenderInput = renderInput
    }

    var previewRenderInput: PreparedCoverRenderInput { lockedRenderInput }
    var exportRenderInput: PreparedCoverRenderInput { lockedRenderInput }
    var identity: CoverRenderIdentity { lockedRenderInput.identity }
}

struct CoverRenderPreparationRequest: @unchecked Sendable {
    let expectedSourceRevision: Int
    let factPack: CoverFactPack
    let allocation: ContentAllocationPlan
    let recipe: CoverRecipe
    let layout: ResolvedCoverLayout
    let preparedImagesByID: [UUID: UIImage]
    let mediaAnalysesByID: [UUID: CoverMediaAnalysis]
    let dynamicPalette: CoverDynamicPalette?
    let backgroundImage: UIImage?
    let unavailableMediaCount: Int

    init(
        expectedSourceRevision: Int,
        factPack: CoverFactPack,
        allocation: ContentAllocationPlan,
        recipe: CoverRecipe,
        layout: ResolvedCoverLayout,
        preparedImagesByID: [UUID: UIImage],
        mediaAnalysesByID: [UUID: CoverMediaAnalysis] = [:],
        dynamicPalette: CoverDynamicPalette? = nil,
        backgroundImage: UIImage?,
        unavailableMediaCount: Int
    ) {
        self.expectedSourceRevision = expectedSourceRevision
        self.factPack = factPack
        self.allocation = allocation
        self.recipe = recipe
        self.layout = layout
        self.preparedImagesByID = preparedImagesByID
        self.mediaAnalysesByID = mediaAnalysesByID
        self.dynamicPalette = dynamicPalette
        self.backgroundImage = backgroundImage
        self.unavailableMediaCount = unavailableMediaCount
    }
}

enum CoverStableIdentity {
    static func fingerprint(_ components: [String]) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in components.joined(separator: "\u{1F}").utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(format: "%016llx", hash)
    }
}
