import Foundation
import XCTest
@testable import NativeDemoApp

final class CoverContractEngineTests: XCTestCase {
    private let leadEvidenceID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    private let supportEvidenceID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
    private let heroMediaID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
    private let secondaryMediaID = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!

    func testValidFactAllocationAndRecipeShareOneImmutableIdentity() throws {
        let factPack = makeFactPack()
        let atoms = factPack.contentAtoms()
        let allocation = try ContentAllocationEngine.allocate(
            atoms: atoms,
            request: makeAllocationRequest(),
            privacyPolicy: factPack.privacy
        )
        let recipe = makeRecipe(factPack: factPack, allocation: allocation)

        XCTAssertEqual(allocation.visibleAtoms.count, allocation.consumedAtomIDs.count)
        XCTAssertEqual(allocation.footer.filter { $0.role == .brand }.count, 1)
        XCTAssertTrue(allocation.footer.filter { $0.role == .footerMetric }.count == 3)
        XCTAssertTrue(CoverContractValidator.validateFactPack(factPack).isValid)
        XCTAssertTrue(
            CoverContractValidator.validateRecipe(
                recipe,
                factPack: factPack,
                allocation: allocation
            ).isValid
        )
    }

    func testSameAtomCannotBeConsumedByTwoVisibleRegions() {
        let factPack = makeFactPack()
        var request = makeAllocationRequest()
        request = CoverContentAllocationRequest(
            mastheadAtomIDs: request.mastheadAtomIDs,
            storyLeadAtomID: request.storyLeadAtomID,
            storySupportAtomID: request.storySupportAtomID,
            mediaCaptionAtomIDs: request.mediaCaptionAtomIDs,
            markAtomIDs: request.markAtomIDs,
            timelineAtomIDs: request.timelineAtomIDs,
            footerAtomIDs: request.footerAtomIDs + [CoverFactAtomID.period]
        )

        assertAllocationFails(
            factPack: factPack,
            atoms: factPack.contentAtoms(),
            request: request,
            code: .duplicateAtomConsumption
        )
    }

    func testDifferentAtomsWithTheSameSemanticKeyCannotBothBeVisible() {
        let factPack = makeFactPack()
        let duplicateSemanticAtom = CoverContentAtom(
            id: "mark.semantic-duplicate",
            role: .lifeMark,
            text: "另一个版面表达",
            evidenceItemIDs: [leadEvidenceID],
            semanticKey: factPack.story.semanticKey,
            priority: 10
        )
        var request = makeAllocationRequest()
        request = CoverContentAllocationRequest(
            mastheadAtomIDs: request.mastheadAtomIDs,
            storyLeadAtomID: request.storyLeadAtomID,
            storySupportAtomID: request.storySupportAtomID,
            mediaCaptionAtomIDs: request.mediaCaptionAtomIDs,
            markAtomIDs: request.markAtomIDs + [duplicateSemanticAtom.id],
            timelineAtomIDs: request.timelineAtomIDs,
            footerAtomIDs: request.footerAtomIDs
        )

        assertAllocationFails(
            factPack: factPack,
            atoms: factPack.contentAtoms() + [duplicateSemanticAtom],
            request: request,
            code: .duplicateSemanticKey
        )
    }

    func testNormalizedDuplicateCopyCannotHideBehindDifferentIDs() {
        let factPack = makeFactPack()
        let duplicateCopyAtom = CoverContentAtom(
            id: "mark.copy-duplicate",
            role: .lifeMark,
            text: "  下班路上，也把这一刻留了下来。 ",
            evidenceItemIDs: [leadEvidenceID],
            semanticKey: "mark:copy-duplicate",
            priority: 10
        )
        var request = makeAllocationRequest()
        request = CoverContentAllocationRequest(
            mastheadAtomIDs: request.mastheadAtomIDs,
            storyLeadAtomID: request.storyLeadAtomID,
            storySupportAtomID: request.storySupportAtomID,
            mediaCaptionAtomIDs: request.mediaCaptionAtomIDs,
            markAtomIDs: request.markAtomIDs + [duplicateCopyAtom.id],
            timelineAtomIDs: request.timelineAtomIDs,
            footerAtomIDs: request.footerAtomIDs
        )

        assertAllocationFails(
            factPack: factPack,
            atoms: factPack.contentAtoms() + [duplicateCopyAtom],
            request: request,
            code: .duplicateVisibleText
        )
    }

    func testFooterMetricOutsideFooterAndConsumedSetDriftAreRejected() throws {
        let factPack = makeFactPack()
        let valid = try makeAllocation(factPack: factPack)
        let metric = valid.footer.first { $0.id == CoverFactAtomID.recordCount }!
        let invalid = ContentAllocationPlan(
            masthead: valid.masthead + [metric],
            storyLead: valid.storyLead,
            storySupport: valid.storySupport,
            mediaCaptions: valid.mediaCaptions,
            marks: valid.marks,
            timeline: valid.timeline,
            footer: valid.footer.filter { $0.id != metric.id },
            consumedAtomIDs: []
        )

        let codes = Set(
            CoverContractValidator.validateAllocation(
                invalid,
                privacyPolicy: factPack.privacy
            ).violations.map(\.code)
        )
        XCTAssertTrue(codes.contains(.footerMetricOutsideFooter))
        XCTAssertTrue(codes.contains(.roleNotAllowedInRegion))
        XCTAssertTrue(codes.contains(.consumedSetMismatch))
    }

    func testAPlanWithoutExactlyOneFooterBrandIsRejected() {
        let factPack = makeFactPack()
        let request = makeAllocationRequest(includeBrand: false)

        assertAllocationFails(
            factPack: factPack,
            atoms: factPack.contentAtoms(),
            request: request,
            code: .brandCountMismatch
        )
    }

    func testFooterCannotDropOneOfTheCertifiedMetricAtoms() {
        let factPack = makeFactPack()
        let base = makeAllocationRequest()
        let request = CoverContentAllocationRequest(
            mastheadAtomIDs: base.mastheadAtomIDs,
            storyLeadAtomID: base.storyLeadAtomID,
            storySupportAtomID: base.storySupportAtomID,
            mediaCaptionAtomIDs: base.mediaCaptionAtomIDs,
            markAtomIDs: base.markAtomIDs,
            timelineAtomIDs: base.timelineAtomIDs,
            footerAtomIDs: base.footerAtomIDs.filter { $0 != CoverFactAtomID.photoCount }
        )

        assertAllocationFails(
            factPack: factPack,
            atoms: factPack.contentAtoms(),
            request: request,
            code: .footerMetricSetMismatch
        )
    }

    func testQRCodeRequiresAnAllowedVerifiedHTTPSDestination() {
        let invalidURL = makeFactPack(
            qrCodeURL: "http://example.com/share",
            allowsVerifiedQRCode: true
        )
        let invalidURLCodes = Set(
            CoverContractValidator.validateFactPack(invalidURL).violations.map(\.code)
        )
        XCTAssertTrue(invalidURLCodes.contains(.qrCodeNotVerified))

        let disallowed = makeFactPack(
            qrCodeURL: "https://example.com/share",
            allowsVerifiedQRCode: false
        )
        let disallowedCodes = Set(
            CoverContractValidator.validateFactPack(disallowed).violations.map(\.code)
        )
        XCTAssertTrue(disallowedCodes.contains(.qrCodeNotAllowed))
    }

    func testBlockedMediaAndSecondaryOnlyHeroAreRejectedLocally() throws {
        let blockedPack = makeFactPack(blockedMediaIDs: [heroMediaID])
        let blockedCodes = Set(
            CoverContractValidator.validateFactPack(blockedPack).violations.map(\.code)
        )
        XCTAssertTrue(blockedCodes.contains(.blockedMedia))

        let secondaryOnlyPack = makeFactPack(heroEligibility: .secondaryOnly)
        let allocation = try makeAllocation(factPack: secondaryOnlyPack)
        let recipe = makeRecipe(factPack: secondaryOnlyPack, allocation: allocation)
        let recipeCodes = Set(
            CoverContractValidator.validateRecipe(
                recipe,
                factPack: secondaryOnlyPack,
                allocation: allocation
            ).violations.map(\.code)
        )
        XCTAssertTrue(recipeCodes.contains(.mediaRoleNotAllowed))
    }

    func testHeroAndCaptionMustRemainBoundToTheirCertifiedEvidence() throws {
        let mismatchedPack = makeFactPack(heroMatchesLeadEvidence: false)
        let allocation = try makeAllocation(factPack: mismatchedPack)
        let recipe = makeRecipe(factPack: mismatchedPack, allocation: allocation)
        let codes = Set(
            CoverContractValidator.validateRecipe(
                recipe,
                factPack: mismatchedPack,
                allocation: allocation
            ).violations.map(\.code)
        )

        XCTAssertTrue(codes.contains(.mediaEvidenceMismatch))
    }

    func testRecipeCannotCrossFactRevisionPeriodOrFingerprint() throws {
        let factPack = makeFactPack()
        let allocation = try makeAllocation(factPack: factPack)
        let valid = makeRecipe(factPack: factPack, allocation: allocation)
        let mismatched = CoverRecipe(
            schemaVersion: valid.schemaVersion,
            recipeID: valid.recipeID,
            source: valid.source,
            sourceRevision: valid.sourceRevision + 1,
            periodKey: "month:2026-07",
            contentFingerprint: "different-fingerprint",
            template: valid.template,
            palette: valid.palette,
            background: valid.background,
            typography: valid.typography,
            content: valid.content,
            media: valid.media,
            footer: valid.footer,
            animation: valid.animation,
            seed: valid.seed,
            confidence: valid.confidence,
            reasonCodes: valid.reasonCodes
        )

        let codes = Set(
            CoverContractValidator.validateRecipe(
                mismatched,
                factPack: factPack,
                allocation: allocation
            ).violations.map(\.code)
        )
        XCTAssertTrue(codes.contains(.recipeIdentityMismatch))
    }

    func testFactPackAndRecipeRemainCodableValueContracts() throws {
        let factPack = makeFactPack()
        let allocation = try makeAllocation(factPack: factPack)
        let recipe = makeRecipe(factPack: factPack, allocation: allocation)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let decodedFactPack = try JSONDecoder().decode(
            CoverFactPack.self,
            from: encoder.encode(factPack)
        )
        let decodedRecipe = try JSONDecoder().decode(
            CoverRecipe.self,
            from: encoder.encode(recipe)
        )

        XCTAssertEqual(decodedFactPack, factPack)
        XCTAssertEqual(decodedRecipe, recipe)
    }

    private func makeFactPack(
        qrCodeURL: String? = nil,
        allowsVerifiedQRCode: Bool = false,
        blockedMediaIDs: Set<UUID> = [],
        heroEligibility: CoverMediaEligibility = .heroEligible,
        heroMatchesLeadEvidence: Bool = true
    ) -> CoverFactPack {
        let caption = CertifiedLabel(
            id: "caption.rain-window",
            kind: .photoCaption,
            text: "雨停以后，窗边慢了下来",
            semanticKey: "caption:rain-window",
            evidenceItemIDs: [supportEvidenceID]
        )
        return CoverFactPack(
            schemaVersion: CoverContractSchema.currentVersion,
            sourceRevision: 42,
            periodKey: "week:2026-07-20",
            periodLabel: "2026.07.20—07.26",
            story: CertifiedStory(
                id: "story.lead",
                text: "下班路上，也把这一刻留了下来",
                semanticKey: "story:lead:rainy-commute",
                evidenceItemIDs: [leadEvidenceID]
            ),
            support: CertifiedStory(
                id: "story.support",
                text: "雨停以后，回家的路慢了一点",
                semanticKey: "story:support:slow-way-home",
                evidenceItemIDs: [supportEvidenceID]
            ),
            marks: [
                CertifiedLabel(
                    id: "mark.dinner",
                    kind: .lifeMark,
                    text: "晚饭",
                    semanticKey: "mark:dinner",
                    evidenceItemIDs: [supportEvidenceID]
                ),
            ],
            footerFacts: FooterFacts(
                brandText: "叙账",
                dateText: nil,
                recordCount: 12,
                recordedDayCount: 3,
                photoCount: 2,
                verifiedQRCodeURL: qrCodeURL
            ),
            media: [
                MediaDescriptor(
                    id: heroMediaID,
                    evidenceItemIDs: [heroMatchesLeadEvidence ? leadEvidenceID : supportEvidenceID],
                    orientation: .portrait,
                    eligibility: heroEligibility,
                    privacyRisk: .safe,
                    caption: nil
                ),
                MediaDescriptor(
                    id: secondaryMediaID,
                    evidenceItemIDs: [supportEvidenceID],
                    orientation: .landscape,
                    eligibility: .secondaryOnly,
                    privacyRisk: .safe,
                    caption: caption
                ),
            ],
            context: SafeCoverContext(
                locationLabels: [],
                timelineLabels: [
                    CertifiedLabel(
                        id: "timeline.tuesday",
                        kind: .timeline,
                        text: "周二晚饭",
                        semanticKey: "timeline:tuesday-dinner",
                        evidenceItemIDs: [supportEvidenceID]
                    ),
                ],
                sceneKeys: ["rainy-commute", "dinner"]
            ),
            privacy: CoverPrivacyPolicy(
                blockedMediaIDs: blockedMediaIDs,
                allowsLocationText: false,
                allowsVerifiedQRCode: allowsVerifiedQRCode
            ),
            contentFingerprint: "fixture-fingerprint-42"
        )
    }

    private func makeAllocationRequest(includeBrand: Bool = true) -> CoverContentAllocationRequest {
        var footerIDs = [
            CoverFactAtomID.recordCount,
            CoverFactAtomID.recordedDayCount,
            CoverFactAtomID.photoCount,
        ]
        if includeBrand {
            footerIDs.insert(CoverFactAtomID.brand, at: 0)
        }
        return CoverContentAllocationRequest(
            mastheadAtomIDs: [CoverFactAtomID.period],
            storyLeadAtomID: "story.lead",
            storySupportAtomID: "story.support",
            mediaCaptionAtomIDs: [secondaryMediaID: "caption.rain-window"],
            markAtomIDs: ["mark.dinner"],
            timelineAtomIDs: ["timeline.tuesday"],
            footerAtomIDs: footerIDs
        )
    }

    private func makeAllocation(factPack: CoverFactPack) throws -> ContentAllocationPlan {
        try ContentAllocationEngine.allocate(
            atoms: factPack.contentAtoms(),
            request: makeAllocationRequest(),
            privacyPolicy: factPack.privacy
        )
    }

    private func makeRecipe(
        factPack: CoverFactPack,
        allocation: ContentAllocationPlan
    ) -> CoverRecipe {
        CoverRecipe(
            schemaVersion: CoverContractSchema.currentVersion,
            recipeID: "fixture-recipe",
            source: .local,
            sourceRevision: factPack.sourceRevision,
            periodKey: factPack.periodKey,
            contentFingerprint: factPack.contentFingerprint,
            template: TemplateSelection(
                templateID: .heroStory,
                variantID: "portraitHeroBottom"
            ),
            palette: CoverPaletteRecipe(paletteID: .creamMorning),
            background: BackgroundRecipe(
                family: .morningLight,
                seed: 89_121
            ),
            typography: TypographyRecipe(family: .songEditorial),
            content: ContentRecipe(
                leadAtomID: allocation.storyLead.id,
                supportAtomID: allocation.storySupport?.id,
                markAtomIDs: allocation.marks.map(\.id),
                timelineAtomIDs: allocation.timeline.map(\.id)
            ),
            media: [
                MediaPlacementRecipe(
                    mediaID: heroMediaID,
                    role: .hero,
                    slotID: "hero",
                    cropMode: .cropSafeFill,
                    treatment: .clean
                ),
                MediaPlacementRecipe(
                    mediaID: secondaryMediaID,
                    role: .secondary,
                    slotID: "secondary-1",
                    cropMode: .fill,
                    treatment: .paper
                ),
            ],
            footer: FooterRecipe(
                style: .quiet,
                atomIDs: allocation.footer.map(\.id),
                showsVerifiedQRCode: false
            ),
            animation: CoverAnimationRecipe(profile: .gentleEditorial),
            seed: 89_121,
            confidence: 0.9,
            reasonCodes: [.strongPhotoLead, .shortStory]
        )
    }

    private func assertAllocationFails(
        factPack: CoverFactPack,
        atoms: [CoverContentAtom],
        request: CoverContentAllocationRequest,
        code: CoverContractViolationCode,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try ContentAllocationEngine.allocate(
                atoms: atoms,
                request: request,
                privacyPolicy: factPack.privacy
            ),
            file: file,
            line: line
        ) { error in
            guard let contractError = error as? CoverContractValidationError else {
                return XCTFail("Unexpected error: \(error)", file: file, line: line)
            }
            XCTAssertTrue(
                contractError.violations.contains { $0.code == code },
                "Expected \(code), got \(contractError.violations)",
                file: file,
                line: line
            )
        }
    }
}
