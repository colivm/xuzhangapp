import UIKit
import XCTest
@testable import NativeDemoApp

final class CoverShareFlowTests: XCTestCase {
    private let evidenceID = UUID(uuidString: "31000000-0000-0000-0000-000000000001")!
    private let mediaID = UUID(uuidString: "32000000-0000-0000-0000-000000000001")!

    func testPreviewAndExportReceiveTheExactSameLockedRenderInput() throws {
        let session = try CoverShareFlow.prepare(makePreparationRequest())

        XCTAssertTrue(session.previewRenderInput === session.exportRenderInput)
        XCTAssertEqual(session.previewRenderInput.identity, session.exportRenderInput.identity)
        XCTAssertEqual(session.identity.sourceRevision, 42)
    }

    func testFoundationRootKeepsAllFooterAtomsOutOfTheTemplateBody() throws {
        let session = try CoverShareFlow.prepare(makePreparationRequest())
        let input = session.previewRenderInput
        let footerIDs = Set(input.allocation.footer.map(\.id))
        let bodyIDs = Set(input.layout.bodyAtomPlacements.map(\.atomID))

        XCTAssertTrue(footerIDs.isDisjoint(with: bodyIDs))
        XCTAssertEqual(input.footerPresentation.textAtomIDs, input.allocation.footer.map(\.id))
        XCTAssertEqual(
            input.footerPresentation.text,
            "叙账 · 4 笔记录 · 3 个记录日 · 0 张照片"
        )
        XCTAssertEqual(
            input.footerPresentation.text.components(separatedBy: " · ").count,
            4
        )
    }

    func testFlowRejectsAStaleExpectedRevisionBeforeRendering() {
        let request = makePreparationRequest(expectedSourceRevision: 43)

        assertPreparationFails(request, code: .staleSourceRevision)
    }

    func testFlowRejectsFooterAtomsPlacedInsideTheBody() {
        let valid = makePreparationRequest()
        let invalidLayout = ResolvedCoverLayout(
            schemaVersion: valid.layout.schemaVersion,
            layoutID: valid.layout.layoutID,
            recipeID: valid.layout.recipeID,
            sourceRevision: valid.layout.sourceRevision,
            periodKey: valid.layout.periodKey,
            contentFingerprint: valid.layout.contentFingerprint,
            canvasSize: valid.layout.canvasSize,
            footerFrame: valid.layout.footerFrame,
            bodyAtomPlacements: valid.layout.bodyAtomPlacements + [
                ResolvedCoverAtomPlacement(
                    atomID: CoverFactAtomID.brand,
                    frame: CoverRenderRect(x: 32, y: 820, width: 120, height: 24),
                    textRole: .mark,
                    alignment: .leading,
                    lineLimit: 1
                ),
            ],
            mediaPlacements: valid.layout.mediaPlacements
        )
        let invalid = CoverRenderPreparationRequest(
            expectedSourceRevision: valid.expectedSourceRevision,
            factPack: valid.factPack,
            allocation: valid.allocation,
            recipe: valid.recipe,
            layout: invalidLayout,
            preparedImagesByID: valid.preparedImagesByID,
            backgroundImage: valid.backgroundImage,
            unavailableMediaCount: valid.unavailableMediaCount
        )

        assertPreparationFails(invalid, code: .footerAtomInBody)
    }

    func testFlowRejectsLayoutMediaPresentationDriftFromRecipe() {
        let valid = makePreparationRequest(includeMedia: true)
        let invalidPlacements = valid.layout.mediaPlacements.map { placement in
            ResolvedCoverMediaPlacement(
                mediaID: placement.mediaID,
                frame: placement.frame,
                cropMode: .fit,
                treatment: placement.treatment,
                zIndex: placement.zIndex
            )
        }
        let invalidLayout = ResolvedCoverLayout(
            schemaVersion: valid.layout.schemaVersion,
            layoutID: valid.layout.layoutID,
            recipeID: valid.layout.recipeID,
            sourceRevision: valid.layout.sourceRevision,
            periodKey: valid.layout.periodKey,
            contentFingerprint: valid.layout.contentFingerprint,
            canvasSize: valid.layout.canvasSize,
            footerFrame: valid.layout.footerFrame,
            bodyAtomPlacements: valid.layout.bodyAtomPlacements,
            mediaPlacements: invalidPlacements
        )
        let invalid = CoverRenderPreparationRequest(
            expectedSourceRevision: valid.expectedSourceRevision,
            factPack: valid.factPack,
            allocation: valid.allocation,
            recipe: valid.recipe,
            layout: invalidLayout,
            preparedImagesByID: valid.preparedImagesByID,
            backgroundImage: valid.backgroundImage,
            unavailableMediaCount: valid.unavailableMediaCount
        )

        assertPreparationFails(invalid, code: .mediaPresentationMismatch)
    }

    func testBothLegacyEntrancesUseTheSameAdapterForNoPhotoAndPreparedPhotoInputs() throws {
        let payload = makeLegacyPayload()
        let noPhoto = try LegacyWeeklyCoverAdapter.prepareSession(
            from: LegacyWeeklyCoverSource(
                sourceRevision: 42,
                payload: payload,
                fallbackEvidenceItemIDs: [evidenceID],
                media: [],
                unavailableMediaCount: 0,
                variantID: "review-weekly",
                paletteID: .quietCream,
                backgroundFamily: .quietEditorial,
                backgroundImage: nil,
                backgroundIdentity: "review-weekly"
            )
        )
        let preparedPhoto = try LegacyWeeklyCoverAdapter.prepareSession(
            from: LegacyWeeklyCoverSource(
                sourceRevision: 42,
                payload: payload,
                fallbackEvidenceItemIDs: [evidenceID],
                media: [
                    LegacyWeeklyCoverMedia(
                        id: mediaID,
                        evidenceItemIDs: [evidenceID],
                        image: makeImage(),
                        privacyRisk: .safe,
                        allowsHero: true
                    ),
                ],
                unavailableMediaCount: 0,
                variantID: "warmLight",
                paletteID: .creamMorning,
                backgroundFamily: .morningLight,
                backgroundImage: nil,
                backgroundIdentity: "playback-weekly"
            )
        )

        XCTAssertEqual(noPhoto.previewRenderInput.preparedImagesByID.count, 0)
        XCTAssertEqual(preparedPhoto.previewRenderInput.preparedImagesByID.count, 1)
        XCTAssertEqual(preparedPhoto.previewRenderInput.recipe.media.first?.role, .hero)
        XCTAssertTrue(noPhoto.previewRenderInput === noPhoto.exportRenderInput)
        XCTAssertTrue(preparedPhoto.previewRenderInput === preparedPhoto.exportRenderInput)
    }

    func testLegacyAdapterFiltersReceiptLikeMediaBeforeFactAndLayoutPreparation() throws {
        let payload = makeLegacyPayload()
        let session = try LegacyWeeklyCoverAdapter.prepareSession(
            from: LegacyWeeklyCoverSource(
                sourceRevision: 42,
                payload: payload,
                fallbackEvidenceItemIDs: [evidenceID],
                media: [
                    LegacyWeeklyCoverMedia(
                        id: mediaID,
                        evidenceItemIDs: [evidenceID],
                        image: makeImage(),
                        privacyRisk: .receiptOrScreenshot,
                        allowsHero: false
                    ),
                ],
                unavailableMediaCount: 0,
                variantID: "warmLight",
                paletteID: .creamMorning,
                backgroundFamily: .morningLight,
                backgroundImage: nil,
                backgroundIdentity: "privacy-filter"
            )
        )

        XCTAssertTrue(session.previewRenderInput.preparedImagesByID.isEmpty)
        XCTAssertTrue(session.previewRenderInput.recipe.media.isEmpty)
        XCTAssertEqual(session.previewRenderInput.unavailableMediaCount, 1)
        XCTAssertTrue(session.previewRenderInput.footerPresentation.text.hasSuffix("0 张照片"))
    }

    func testRequiredAnalysisFailureDemotesPreparedPhotoInsteadOfInventingAHero() throws {
        let session = try LegacyWeeklyCoverAdapter.prepareSession(
            from: LegacyWeeklyCoverSource(
                sourceRevision: 42,
                payload: makeLegacyPayload(),
                fallbackEvidenceItemIDs: [evidenceID],
                media: [
                    LegacyWeeklyCoverMedia(
                        id: mediaID,
                        evidenceItemIDs: [evidenceID],
                        image: makeImage(),
                        privacyRisk: .safe,
                        allowsHero: true,
                        requiresAnalysisForHero: true,
                        analysis: nil
                    ),
                ],
                unavailableMediaCount: 0,
                variantID: "warmLight",
                paletteID: .creamMorning,
                backgroundFamily: .morningLight,
                backgroundImage: nil,
                backgroundIdentity: "analysis-failure"
            )
        )

        XCTAssertFalse(session.previewRenderInput.recipe.media.contains { $0.role == .hero })
        XCTAssertNil(session.previewRenderInput.dynamicPalette)
    }

    func testFlowLocksHeroAnalysisAndDynamicPaletteIntoPreviewAndExport() throws {
        let analysis = makeMediaAnalysis()
        let session = try CoverShareFlow.prepare(
            makePreparationRequest(
                includeMedia: true,
                mediaAnalysis: analysis,
                dynamicPalette: analysis.palette
            )
        )

        XCTAssertEqual(session.previewRenderInput.mediaAnalysesByID[mediaID], analysis)
        XCTAssertEqual(session.previewRenderInput.dynamicPalette, analysis.palette)
        XCTAssertTrue(session.previewRenderInput === session.exportRenderInput)
    }

    func testFlowRejectsDynamicPaletteThatIsNotBoundToTheLockedHero() {
        let analysis = makeMediaAnalysis()
        let mismatched = CoverDynamicPalette(
            sourceMediaID: UUID(),
            backgroundStart: analysis.palette!.backgroundStart,
            backgroundEnd: analysis.palette!.backgroundEnd,
            paper: analysis.palette!.paper,
            ink: analysis.palette!.ink,
            mutedInk: analysis.palette!.mutedInk,
            accent: analysis.palette!.accent,
            minimumTextContrastRatio: analysis.palette!.minimumTextContrastRatio
        )
        let request = makePreparationRequest(
            includeMedia: true,
            mediaAnalysis: analysis,
            dynamicPalette: mismatched
        )

        assertPreparationFails(request, code: .invalidDynamicPalette)
    }

    @MainActor
    func testSynchronousExportUsesTheLockedCanvasWithoutAsyncLoaders() throws {
        let session = try CoverShareFlow.prepare(makePreparationRequest())
        let image = try XCTUnwrap(CoverExportCoordinator.renderImage(from: session))

        XCTAssertEqual(image.cgImage?.width, 1_080)
        XCTAssertEqual(image.cgImage?.height, 1_920)
        XCTAssertTrue(session.previewRenderInput === session.exportRenderInput)
    }

    @MainActor
    func testExportKeepsAnOffsetMediaSlotVisibleInsideItsResolvedFrame() throws {
        let session = try CoverShareFlow.prepare(makePreparationRequest(includeMedia: true))
        let image = try XCTUnwrap(CoverExportCoordinator.renderImage(from: session))
        let pixel = try XCTUnwrap(
            rgbaPixel(
                in: image,
                at: CGPoint(x: 540, y: 960)
            )
        )

        XCTAssertGreaterThan(pixel.green, pixel.red + 0.25)
        XCTAssertGreaterThan(pixel.green, pixel.blue + 0.25)
    }

    private func makePreparationRequest(
        expectedSourceRevision: Int = 42,
        includeMedia: Bool = false,
        mediaAnalysis: CoverMediaAnalysis? = nil,
        dynamicPalette: CoverDynamicPalette? = nil
    ) -> CoverRenderPreparationRequest {
        let media = includeMedia ? [
            MediaDescriptor(
                id: mediaID,
                evidenceItemIDs: [evidenceID],
                orientation: .portrait,
                eligibility: .heroEligible,
                privacyRisk: .safe,
                caption: nil,
                analysis: mediaAnalysis
            ),
        ] : []
        let factPack = CoverFactPack(
            schemaVersion: CoverContractSchema.currentVersion,
            sourceRevision: 42,
            periodKey: "week:2026-07-20",
            periodLabel: "2026.07.20—07.26",
            story: CertifiedStory(
                id: "flow.story.lead",
                text: "下班路上，也把这一刻留了下来",
                semanticKey: "story:lead:flow",
                evidenceItemIDs: [evidenceID]
            ),
            support: nil,
            marks: [],
            footerFacts: FooterFacts(
                brandText: "叙账",
                dateText: "2026.07.20—07.26",
                recordCount: 4,
                recordedDayCount: 3,
                photoCount: media.count,
                verifiedQRCodeURL: nil
            ),
            media: media,
            context: SafeCoverContext(
                locationLabels: [],
                timelineLabels: [],
                sceneKeys: []
            ),
            privacy: CoverPrivacyPolicy(
                blockedMediaIDs: [],
                allowsLocationText: false,
                allowsVerifiedQRCode: false
            ),
            contentFingerprint: "flow-fixture-42"
        )
        let allocation = try! ContentAllocationEngine.allocate(
            atoms: factPack.contentAtoms(),
            request: CoverContentAllocationRequest(
                mastheadAtomIDs: [CoverFactAtomID.period],
                storyLeadAtomID: factPack.story.id,
                storySupportAtomID: nil,
                mediaCaptionAtomIDs: [:],
                markAtomIDs: [],
                timelineAtomIDs: [],
                footerAtomIDs: [
                    CoverFactAtomID.brand,
                    CoverFactAtomID.recordCount,
                    CoverFactAtomID.recordedDayCount,
                    CoverFactAtomID.photoCount,
                ]
            ),
            privacyPolicy: factPack.privacy
        )
        let recipe = CoverRecipe(
            schemaVersion: CoverContractSchema.currentVersion,
            recipeID: "flow-recipe-42",
            source: .fallback,
            sourceRevision: 42,
            periodKey: factPack.periodKey,
            contentFingerprint: factPack.contentFingerprint,
            template: TemplateSelection(templateID: .minimal, variantID: "foundation"),
            palette: CoverPaletteRecipe(paletteID: .quietCream),
            background: BackgroundRecipe(family: .minimal, seed: 42),
            typography: TypographyRecipe(family: .songEditorial),
            content: ContentRecipe(
                leadAtomID: allocation.storyLead.id,
                supportAtomID: nil,
                markAtomIDs: [],
                timelineAtomIDs: []
            ),
            media: includeMedia ? [
                MediaPlacementRecipe(
                    mediaID: mediaID,
                    role: .hero,
                    slotID: "foundation.hero",
                    cropMode: .cropSafeFill,
                    treatment: .clean
                ),
            ] : [],
            footer: FooterRecipe(
                style: .quiet,
                atomIDs: allocation.footer.map(\.id),
                showsVerifiedQRCode: false
            ),
            animation: CoverAnimationRecipe(profile: .quietFade),
            seed: 42,
            confidence: 1,
            reasonCodes: [.deterministicFallback]
        )
        let layout = ResolvedCoverLayout(
            schemaVersion: CoverRenderSchema.currentVersion,
            layoutID: "flow-layout-42",
            recipeID: recipe.recipeID,
            sourceRevision: recipe.sourceRevision,
            periodKey: recipe.periodKey,
            contentFingerprint: recipe.contentFingerprint,
            canvasSize: CoverRenderSize(width: 540, height: 960),
            footerFrame: CoverRenderRect(x: 32, y: 872, width: 476, height: 56),
            bodyAtomPlacements: [
                ResolvedCoverAtomPlacement(
                    atomID: CoverFactAtomID.period,
                    frame: CoverRenderRect(x: 32, y: 36, width: 476, height: 24),
                    textRole: .masthead,
                    alignment: .leading,
                    lineLimit: 1
                ),
                ResolvedCoverAtomPlacement(
                    atomID: factPack.story.id,
                    frame: CoverRenderRect(x: 32, y: 92, width: 476, height: 160),
                    textRole: .lead,
                    alignment: .leading,
                    lineLimit: 3
                ),
            ],
            mediaPlacements: includeMedia ? [
                ResolvedCoverMediaPlacement(
                    mediaID: mediaID,
                    frame: CoverRenderRect(x: 32, y: 378, width: 476, height: 450),
                    cropMode: .cropSafeFill,
                    treatment: .clean,
                    zIndex: 0
                ),
            ] : []
        )
        return CoverRenderPreparationRequest(
            expectedSourceRevision: expectedSourceRevision,
            factPack: factPack,
            allocation: allocation,
            recipe: recipe,
            layout: layout,
            preparedImagesByID: includeMedia ? [mediaID: makeImage()] : [:],
            mediaAnalysesByID: includeMedia ? [mediaID: mediaAnalysis].compactMapValues { $0 } : [:],
            dynamicPalette: dynamicPalette,
            backgroundImage: nil,
            unavailableMediaCount: 0
        )
    }

    private func makeLegacyPayload() -> WeeklyShareCardPayload {
        let signal = LifeNarrativeSignal(
            id: "legacy.lead.signal",
            kind: .userText,
            label: "下班路上",
            fact: "下班路上，也把这一刻留了下来",
            evidenceItemIDs: [evidenceID],
            confidence: 95,
            informationGain: 90,
            narrativeValue: 90,
            representativeness: 88,
            isAdministrative: false,
            isSensitive: false,
            isStable: false
        )
        let plan = LifeNarrativePlan(
            scope: .week,
            sourceRevision: 42,
            maturity: .contextual,
            headline: "下班路上，也把这一刻留了下来",
            summary: "这一周的回家路有了具体的一格",
            supportingLine: nil,
            leadSignalID: signal.id,
            signalsByRole: [.lead: [signal]]
        )
        return WeeklyShareCardPayload(
            weekTotal: 100,
            topCategory: "交通",
            recordCount: 4,
            primaryMetricCount: 4,
            primaryMetricEmoji: "",
            dailyTrend: [("一", 20), ("二", 30), ("三", 50)],
            dailyCountTrend: [("一", 1), ("二", 1), ("三", 2)],
            categorySlices: [],
            topCategoryRatio: 0.5,
            headline: plan.headline,
            subtitle: plan.summary,
            anchorLine: nil,
            lifeMarkLine: nil,
            contextLine: nil,
            emotionLine: nil,
            periodText: "2026.07.20—07.26",
            insight: ShareInsight(
                fact: plan.headline,
                care: plan.summary,
                footnote: "4 笔",
                tags: []
            ),
            narrativePlan: plan,
            narrativeEcho: nil,
            narrativeRewrite: nil
        )
    }

    private func makeImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 180))
        return renderer.image { context in
            UIColor.systemGreen.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 120, height: 180))
        }
    }

    private func rgbaPixel(
        in image: UIImage,
        at point: CGPoint
    ) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)? {
        guard let cgImage = image.cgImage,
              point.x >= 0,
              point.y >= 0,
              point.x < CGFloat(cgImage.width),
              point.y < CGFloat(cgImage.height),
              let cropped = cgImage.cropping(
                to: CGRect(x: point.x, y: point.y, width: 1, height: 1)
              ) else {
            return nil
        }
        var bytes = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &bytes,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return (
            CGFloat(bytes[0]) / 255,
            CGFloat(bytes[1]) / 255,
            CGFloat(bytes[2]) / 255,
            CGFloat(bytes[3]) / 255
        )
    }

    private func makeMediaAnalysis() -> CoverMediaAnalysis {
        let backgroundStart = CoverRGBA(red: 0.94, green: 0.92, blue: 0.86, alpha: 1)
        let backgroundEnd = CoverRGBA(red: 0.86, green: 0.84, blue: 0.78, alpha: 1)
        let ink = CoverRGBA(red: 0.08, green: 0.08, blue: 0.07, alpha: 1)
        let palette = CoverDynamicPalette(
            sourceMediaID: mediaID,
            backgroundStart: backgroundStart,
            backgroundEnd: backgroundEnd,
            paper: CoverRGBA(red: 0.99, green: 0.98, blue: 0.95, alpha: 1),
            ink: ink,
            mutedInk: CoverRGBA(red: 0.24, green: 0.23, blue: 0.20, alpha: 1),
            accent: CoverRGBA(red: 0.30, green: 0.42, blue: 0.35, alpha: 1),
            minimumTextContrastRatio: min(
                ink.contrastRatio(with: backgroundStart),
                ink.contrastRatio(with: backgroundEnd)
            )
        )
        return CoverMediaAnalysis(
            ruleVersion: CoverMediaAnalysisRules.currentVersion,
            cacheKey: "flow-analysis",
            pixelWidth: 1_600,
            pixelHeight: 2_000,
            sharpness: 0.84,
            exposure: 0.82,
            dynamicRange: 0.72,
            resolutionFitness: 1,
            composition: 0.78,
            subjectSalience: 0.80,
            qualityScore: 0.83,
            hasSevereBlur: false,
            hasSevereExposureFailure: false,
            isBelowHeroResolution: false,
            cropSafety: CoverCropSafety(
                focusPoint: CoverNormalizedPoint(x: 0.44, y: 0.40),
                protectedRegions: [],
                safetyScore: 0.80
            ),
            palette: palette
        )
    }

    private func assertPreparationFails(
        _ request: CoverRenderPreparationRequest,
        code: CoverRenderPreparationViolationCode,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try CoverShareFlow.prepare(request),
            file: file,
            line: line
        ) { error in
            guard let preparationError = error as? CoverRenderPreparationError else {
                return XCTFail("Unexpected error: \(error)", file: file, line: line)
            }
            XCTAssertTrue(
                preparationError.violations.contains { $0.code == code },
                "Expected \(code), got \(preparationError.violations)",
                file: file,
                line: line
            )
        }
    }
}
