import CoreImage
import Foundation
import UIKit

enum CoverRenderPreparationViolationCode: String, Codable, Hashable, Sendable {
    case contractRejected
    case staleSourceRevision
    case layoutIdentityMismatch
    case unsupportedLayoutSchema
    case invalidCanvas
    case invalidFooterFrame
    case invalidBodyFrame
    case bodyOverlapsFooter
    case duplicateBodyAtom
    case bodyAtomSetMismatch
    case footerAtomInBody
    case duplicateLayoutMedia
    case mediaLayoutMismatch
    case mediaPresentationMismatch
    case preparedImageSetMismatch
    case mediaAnalysisMismatch
    case invalidDynamicPalette
    case qrCodePreparationFailed
    case invalidUnavailableMediaCount
}

struct CoverRenderPreparationViolation: Codable, Equatable, Sendable {
    let code: CoverRenderPreparationViolationCode
    let path: String
    let relatedIDs: [String]
}

struct CoverRenderPreparationError: Error, Equatable, Sendable {
    let violations: [CoverRenderPreparationViolation]
}

enum CoverShareFlow {
    static func prepare(
        _ request: CoverRenderPreparationRequest
    ) throws -> CoverShareSession {
        var violations: [CoverRenderPreparationViolation] = []
        let contractResult = CoverContractValidator.validateRecipe(
            request.recipe,
            factPack: request.factPack,
            allocation: request.allocation
        )
        if !contractResult.isValid {
            violations.append(
                violation(
                    .contractRejected,
                    "request.contract",
                    contractResult.violations.map { $0.code.rawValue }
                )
            )
        }

        if request.expectedSourceRevision != request.factPack.sourceRevision {
            violations.append(
                violation(
                    .staleSourceRevision,
                    "request.expectedSourceRevision",
                    [
                        String(request.expectedSourceRevision),
                        String(request.factPack.sourceRevision),
                    ]
                )
            )
        }

        let layout = request.layout
        if layout.schemaVersion != CoverRenderSchema.currentVersion {
            violations.append(violation(.unsupportedLayoutSchema, "layout.schemaVersion"))
        }
        if layout.recipeID != request.recipe.recipeID
            || layout.sourceRevision != request.factPack.sourceRevision
            || layout.periodKey != request.factPack.periodKey
            || layout.contentFingerprint != request.factPack.contentFingerprint {
            violations.append(violation(.layoutIdentityMismatch, "layout.identity"))
        }
        if !layout.canvasSize.isValid {
            violations.append(violation(.invalidCanvas, "layout.canvasSize"))
        }
        if !layout.footerFrame.isInside(layout.canvasSize) {
            violations.append(violation(.invalidFooterFrame, "layout.footerFrame"))
        }

        let footerAtomIDs = Set(request.allocation.footer.map(\.id))
        let expectedBodyAtomIDs = Set(
            request.allocation.visiblePlacements.compactMap { placement in
                placement.region == .footer ? nil : placement.atom.id
            }
        )
        let bodyAtomIDs = layout.bodyAtomPlacements.map(\.atomID)
        if Set(bodyAtomIDs).count != bodyAtomIDs.count {
            violations.append(violation(.duplicateBodyAtom, "layout.bodyAtomPlacements", bodyAtomIDs))
        }
        if Set(bodyAtomIDs) != expectedBodyAtomIDs {
            violations.append(
                violation(
                    .bodyAtomSetMismatch,
                    "layout.bodyAtomPlacements",
                    bodyAtomIDs.sorted()
                )
            )
        }
        let misplacedFooterIDs = bodyAtomIDs.filter { footerAtomIDs.contains($0) }
        if !misplacedFooterIDs.isEmpty {
            violations.append(
                violation(.footerAtomInBody, "layout.bodyAtomPlacements", misplacedFooterIDs)
            )
        }
        for placement in layout.bodyAtomPlacements {
            if !placement.frame.isInside(layout.canvasSize) || placement.lineLimit < 1 {
                violations.append(
                    violation(.invalidBodyFrame, "layout.bodyAtomPlacements", [placement.atomID])
                )
            }
            if placement.frame.intersects(layout.footerFrame) {
                violations.append(
                    violation(.bodyOverlapsFooter, "layout.bodyAtomPlacements", [placement.atomID])
                )
            }
        }

        let recipeMediaIDs = request.recipe.media.map(\.mediaID)
        let layoutMediaIDs = layout.mediaPlacements.map(\.mediaID)
        if Set(layoutMediaIDs).count != layoutMediaIDs.count {
            violations.append(
                violation(
                    .duplicateLayoutMedia,
                    "layout.mediaPlacements",
                    layoutMediaIDs.map(\.uuidString)
                )
            )
        }
        if Set(layoutMediaIDs) != Set(recipeMediaIDs) {
            violations.append(
                violation(
                    .mediaLayoutMismatch,
                    "layout.mediaPlacements",
                    layoutMediaIDs.map(\.uuidString).sorted()
                )
            )
        }
        for placement in layout.mediaPlacements {
            if !placement.frame.isInside(layout.canvasSize)
                || placement.frame.intersects(layout.footerFrame) {
                violations.append(
                    violation(.invalidBodyFrame, "layout.mediaPlacements", [placement.mediaID.uuidString])
                )
            }
            if let recipePlacement = request.recipe.media.first(where: {
                $0.mediaID == placement.mediaID
            }), (
                placement.cropMode != recipePlacement.cropMode
                    || placement.treatment != recipePlacement.treatment
            ) {
                violations.append(
                    violation(
                        .mediaPresentationMismatch,
                        "layout.mediaPlacements.presentation",
                        [placement.mediaID.uuidString]
                    )
                )
            }
        }
        if Set(request.preparedImagesByID.keys) != Set(recipeMediaIDs) {
            violations.append(
                violation(
                    .preparedImageSetMismatch,
                    "request.preparedImagesByID",
                    request.preparedImagesByID.keys.map(\.uuidString).sorted()
                )
            )
        }
        let analysisMediaIDs = Set(request.mediaAnalysesByID.keys)
        if !analysisMediaIDs.isSubset(of: Set(recipeMediaIDs))
            || request.mediaAnalysesByID.contains(where: { mediaID, analysis in
                !analysis.isValid
                    || request.factPack.media.first(where: { $0.id == mediaID })?.analysis
                        != analysis
            }) {
            violations.append(
                violation(
                    .mediaAnalysisMismatch,
                    "request.mediaAnalysesByID",
                    analysisMediaIDs.map(\.uuidString).sorted()
                )
            )
        }
        if let dynamicPalette = request.dynamicPalette {
            let heroMediaID = request.recipe.media.first(where: { $0.role == .hero })?.mediaID
            let analyzedPalette = request.mediaAnalysesByID[dynamicPalette.sourceMediaID]?.palette
            if !dynamicPalette.isValid
                || heroMediaID != dynamicPalette.sourceMediaID
                || analyzedPalette != dynamicPalette {
                violations.append(
                    violation(
                        .invalidDynamicPalette,
                        "request.dynamicPalette",
                        [dynamicPalette.sourceMediaID.uuidString]
                    )
                )
            }
        }
        if request.unavailableMediaCount < 0 {
            violations.append(
                violation(.invalidUnavailableMediaCount, "request.unavailableMediaCount")
            )
        }

        let footerPresentation = makeFooterPresentation(request.allocation.footer)
        let verifiedQRCodeImage: UIImage?
        if request.recipe.footer.showsVerifiedQRCode {
            verifiedQRCodeImage = footerPresentation.qrCodeURL.flatMap(makeQRCodeImage)
            if verifiedQRCodeImage == nil {
                violations.append(
                    violation(.qrCodePreparationFailed, "request.footer.qrCode")
                )
            }
        } else {
            verifiedQRCodeImage = nil
        }

        if !violations.isEmpty {
            throw CoverRenderPreparationError(violations: deduplicated(violations))
        }

        let sourceKey = CoverStableIdentity.fingerprint([
            String(request.factPack.sourceRevision),
            request.factPack.periodKey,
            request.factPack.contentFingerprint,
            request.recipe.recipeID,
            request.layout.layoutID,
            request.mediaAnalysesByID.keys.sorted { $0.uuidString < $1.uuidString }
                .compactMap { request.mediaAnalysesByID[$0]?.stableSignature }
                .joined(separator: "|"),
            request.dynamicPalette?.sourceMediaID.uuidString ?? "controlled-palette",
        ])
        let identity = CoverRenderIdentity(
            sourceRevision: request.factPack.sourceRevision,
            periodKey: request.factPack.periodKey,
            contentFingerprint: request.factPack.contentFingerprint,
            recipeID: request.recipe.recipeID,
            layoutID: request.layout.layoutID,
            sourceKey: sourceKey
        )
        let input = PreparedCoverRenderInput(
            identity: identity,
            recipe: request.recipe,
            allocation: request.allocation,
            layout: request.layout,
            preparedImagesByID: request.preparedImagesByID,
            mediaAnalysesByID: request.mediaAnalysesByID,
            dynamicPalette: request.dynamicPalette,
            backgroundImage: request.backgroundImage,
            verifiedQRCodeImage: verifiedQRCodeImage,
            footerPresentation: footerPresentation,
            unavailableMediaCount: request.unavailableMediaCount
        )
        return CoverShareSession(renderInput: input)
    }

    private static func makeFooterPresentation(
        _ footerAtoms: [CoverContentAtom]
    ) -> CoverFooterPresentation {
        let textAtoms = footerAtoms.filter { $0.role != .qrCode }
        let qrCodeAtom = footerAtoms.first { $0.role == .qrCode }
        return CoverFooterPresentation(
            textAtomIDs: textAtoms.map(\.id),
            text: textAtoms.map(\.text).joined(separator: " · "),
            qrCodeAtomID: qrCodeAtom?.id,
            qrCodeURL: qrCodeAtom?.text
        )
    }

    private static func makeQRCodeImage(_ value: String) -> UIImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(value.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let transformed = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private static func violation(
        _ code: CoverRenderPreparationViolationCode,
        _ path: String,
        _ relatedIDs: [String] = []
    ) -> CoverRenderPreparationViolation {
        CoverRenderPreparationViolation(code: code, path: path, relatedIDs: relatedIDs)
    }

    private static func deduplicated(
        _ violations: [CoverRenderPreparationViolation]
    ) -> [CoverRenderPreparationViolation] {
        var seen: Set<String> = []
        return violations.filter { violation in
            let key = "\(violation.code.rawValue)|\(violation.path)|\(violation.relatedIDs.joined(separator: ","))"
            return seen.insert(key).inserted
        }
    }
}
