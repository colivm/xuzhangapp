import XCTest
import UIKit
@testable import NativeDemoApp

final class CoverMediaAnalysisTests: XCTestCase {
    func testEvidenceBoundHeroUsesHighestEligibleQualityScore() {
        let evidenceID = UUID()
        let lowID = UUID()
        let highID = UUID()
        let secondaryOnlyID = UUID()
        let descriptors = [
            descriptor(
                id: lowID,
                evidenceID: evidenceID,
                eligibility: .heroEligible,
                score: 0.54
            ),
            descriptor(
                id: secondaryOnlyID,
                evidenceID: evidenceID,
                eligibility: .secondaryOnly,
                score: 0.98
            ),
            descriptor(
                id: highID,
                evidenceID: evidenceID,
                eligibility: .heroEligible,
                score: 0.88
            ),
        ]

        XCTAssertEqual(
            CoverMediaRoleScoring.orderedHeroCandidates(
                descriptors,
                leadEvidenceItemIDs: [evidenceID]
            ).map(\.id),
            [highID, lowID]
        )
    }

    func testHeroOrderingKeepsInputOrderWhenLegacyAnalysisIsUnavailable() {
        let evidenceID = UUID()
        let firstID = UUID()
        let secondID = UUID()
        let descriptors = [firstID, secondID].map { id in
            MediaDescriptor(
                id: id,
                evidenceItemIDs: [evidenceID],
                orientation: .portrait,
                eligibility: .heroEligible,
                privacyRisk: .safe,
                caption: nil
            )
        }

        XCTAssertEqual(
            CoverMediaRoleScoring.orderedHeroCandidates(
                descriptors,
                leadEvidenceItemIDs: [evidenceID]
            ).map(\.id),
            [firstID, secondID]
        )
    }

    func testCropOffsetClampsProtectedFocusInsideFillOverflow() {
        let offset = CoverCropOffsetResolver.offset(
            imageSize: CGSize(width: 200, height: 100),
            frameSize: CGSize(width: 100, height: 100),
            focusPoint: CoverNormalizedPoint(x: 0.8, y: 0.5)
        )

        XCTAssertEqual(offset.width, -50, accuracy: 0.001)
        XCTAssertEqual(offset.height, 0, accuracy: 0.001)
    }

    func testDynamicPaletteRequiresHeroTextContrast() {
        let background = CoverRGBA(red: 0.96, green: 0.94, blue: 0.90, alpha: 1)
        let valid = CoverDynamicPalette(
            sourceMediaID: UUID(),
            backgroundStart: background,
            backgroundEnd: CoverRGBA(red: 0.88, green: 0.86, blue: 0.82, alpha: 1),
            paper: CoverRGBA(red: 1, green: 1, blue: 1, alpha: 1),
            ink: CoverRGBA(red: 0.08, green: 0.08, blue: 0.08, alpha: 1),
            mutedInk: CoverRGBA(red: 0.25, green: 0.24, blue: 0.22, alpha: 1),
            accent: CoverRGBA(red: 0.32, green: 0.42, blue: 0.36, alpha: 1),
            minimumTextContrastRatio: 8
        )
        let invalid = CoverDynamicPalette(
            sourceMediaID: UUID(),
            backgroundStart: background,
            backgroundEnd: background,
            paper: background,
            ink: background,
            mutedInk: background,
            accent: background,
            minimumTextContrastRatio: 1
        )

        XCTAssertTrue(valid.isValid)
        XCTAssertFalse(invalid.isValid)
    }

    func testLowResolutionFlatImageCannotBecomeHero() async throws {
        let mediaID = UUID()
        let image = solidImage(size: CGSize(width: 240, height: 240), gray: 0.5)
        let analyzer = LocalCoverMediaAnalyzer(maximumCacheCount: 4)

        let values = await analyzer.analyze([
            CoverMediaAnalysisRequest(
                mediaID: mediaID,
                stableImageIdentity: "low-resolution-flat",
                image: image
            ),
        ])
        let analysis = try XCTUnwrap(values[mediaID])

        XCTAssertTrue(analysis.isBelowHeroResolution)
        XCTAssertTrue(analysis.hasSevereBlur)
        XCTAssertFalse(analysis.isHeroEligible)
    }

    func testSeverelyUnderexposedImageCannotBecomeHeroAtValidResolution() async throws {
        let mediaID = UUID()
        let image = solidImage(size: CGSize(width: 1_200, height: 1_600), gray: 0.01)
        let analyzer = LocalCoverMediaAnalyzer(maximumCacheCount: 4)

        let values = await analyzer.analyze([
            CoverMediaAnalysisRequest(
                mediaID: mediaID,
                stableImageIdentity: "underexposed-full-resolution",
                image: image
            ),
        ])
        let analysis = try XCTUnwrap(values[mediaID])

        XCTAssertFalse(analysis.isBelowHeroResolution)
        XCTAssertTrue(analysis.hasSevereExposureFailure)
        XCTAssertFalse(analysis.isHeroEligible)
    }

    func testProtectedRegionConstrainsCropOffsetBeforeClipping() {
        let offset = CoverCropOffsetResolver.offset(
            imageSize: CGSize(width: 200, height: 100),
            frameSize: CGSize(width: 100, height: 100),
            focusPoint: CoverNormalizedPoint(x: 0.35, y: 0.5),
            protectedRegions: [
                CoverNormalizedRect(x: 0.02, y: 0.2, width: 0.20, height: 0.50),
            ]
        )

        XCTAssertGreaterThanOrEqual(offset.width, 46)
        XCTAssertLessThanOrEqual(offset.width, 50)
    }

    func testStableImageIdentityCachesOnceAndRetargetsPaletteSource() async throws {
        let firstID = UUID()
        let secondID = UUID()
        let image = solidImage(size: CGSize(width: 1_200, height: 1_200), gray: 0.46)
        let analyzer = LocalCoverMediaAnalyzer(maximumCacheCount: 4)

        let first = await analyzer.analyze([
            CoverMediaAnalysisRequest(
                mediaID: firstID,
                stableImageIdentity: "same-local-photo",
                image: image
            ),
        ])
        let second = await analyzer.analyze([
            CoverMediaAnalysisRequest(
                mediaID: secondID,
                stableImageIdentity: "same-local-photo",
                image: image
            ),
        ])

        let cachedResultCount = await analyzer.cachedResultCount()
        let analysisExecutionCount = await analyzer.analysisExecutionCount()
        XCTAssertEqual(cachedResultCount, 1)
        XCTAssertEqual(analysisExecutionCount, 1)
        XCTAssertEqual(first[firstID]?.cacheKey, second[secondID]?.cacheKey)
        XCTAssertEqual(second[secondID]?.palette?.sourceMediaID, secondID)
    }

    func testAnalysisCacheKeyIncludesRuleAndPixelIdentity() {
        let mediaID = UUID()
        let small = CoverMediaAnalysisRequest(
            mediaID: mediaID,
            stableImageIdentity: "stable-photo",
            image: solidImage(size: CGSize(width: 300, height: 300), gray: 0.4)
        )
        let large = CoverMediaAnalysisRequest(
            mediaID: mediaID,
            stableImageIdentity: "stable-photo",
            image: solidImage(size: CGSize(width: 600, height: 600), gray: 0.4)
        )

        XCTAssertNotEqual(small.cacheKey, large.cacheKey)
        XCTAssertFalse(small.cacheKey.isEmpty)
    }

    private func descriptor(
        id: UUID,
        evidenceID: UUID,
        eligibility: CoverMediaEligibility,
        score: Double
    ) -> MediaDescriptor {
        MediaDescriptor(
            id: id,
            evidenceItemIDs: [evidenceID],
            orientation: .portrait,
            eligibility: eligibility,
            privacyRisk: .safe,
            caption: nil,
            analysis: analysis(id: id, score: score)
        )
    }

    private func analysis(id: UUID, score: Double) -> CoverMediaAnalysis {
        CoverMediaAnalysis(
            ruleVersion: CoverMediaAnalysisRules.currentVersion,
            cacheKey: "analysis-\(id.uuidString)",
            pixelWidth: 1_600,
            pixelHeight: 2_000,
            sharpness: score,
            exposure: 0.8,
            dynamicRange: 0.7,
            resolutionFitness: 1,
            composition: 0.8,
            subjectSalience: 0.8,
            qualityScore: score,
            hasSevereBlur: false,
            hasSevereExposureFailure: false,
            isBelowHeroResolution: false,
            cropSafety: CoverCropSafety(
                focusPoint: CoverNormalizedPoint(x: 0.5, y: 0.45),
                protectedRegions: [],
                safetyScore: 0.8
            ),
            palette: nil
        )
    }

    private func solidImage(size: CGSize, gray: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(white: gray, alpha: 1).setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: size))
        }
    }
}
