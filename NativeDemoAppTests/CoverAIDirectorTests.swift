import UIKit
import XCTest
@testable import NativeDemoApp

final class CoverAIDirectorTests: XCTestCase {
    override func tearDown() {
        CoverAIDirectorDecisionStore.shared.removeAll()
        super.tearDown()
    }

    func testDirectorRequestContainsOnlyRedactedStructuralFactsAndAliases() throws {
        let source = makeSource(mediaCount: 2)
        let input = try LegacyWeeklyCoverAdapter.makeDirectorInput(from: source)
        let data = try JSONEncoder().encode(input.request)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertFalse(json.contains(source.payload.headline))
        XCTAssertFalse(json.contains(source.payload.subtitle))
        XCTAssertFalse(json.contains(source.fallbackEvidenceItemIDs[0].uuidString))
        XCTAssertFalse(json.contains(source.media[0].id.uuidString))
        for forbiddenKey in [
            "storyText",
            "headline",
            "photoData",
            "imageData",
            "imageReference",
            "evidenceItemIDs",
            "messages",
            "face",
            "paletteSample",
        ] {
            XCTAssertFalse(json.contains("\"\(forbiddenKey)\""))
        }
        XCTAssertLessThanOrEqual(
            input.request.templateCandidates.count,
            CoverAIDirectorRules.maximumTemplateCandidateCount
        )
        XCTAssertEqual(input.request.mediaCandidates.map(\.alias), ["M1", "M2"])
        XCTAssertEqual(Set(input.mediaIDByAlias.keys), Set(["M1", "M2"]))
        XCTAssertTrue(input.request.templateCandidates.allSatisfy {
            LaunchCoverTemplateCatalog.orderedTemplateIDs.contains($0.templateID)
        })
    }

    func testStrictResponseDecoderRejectsAdditionalFields() throws {
        let response = try validResponse(for: makeSource(mediaCount: 2))
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(response)) as? [String: Any]
        )
        object["storyText"] = "不允许输出正文"
        let data = try JSONSerialization.data(withJSONObject: object)

        XCTAssertThrowsError(try CoverAIDirectorResponse.decodeStrict(from: data)) { error in
            XCTAssertEqual(error as? CoverAIDirectorError, .invalidResponse)
        }
    }

    func testValidatorRejectsStaleUnknownAndUnboundChoices() throws {
        let source = makeSource(mediaCount: 2)
        let input = try LegacyWeeklyCoverAdapter.makeDirectorInput(from: source)
        let valid = try validResponse(for: source)
        XCTAssertNotNil(CoverAIDirectorValidator.validate(
            valid,
            request: input.request,
            mediaIDByAlias: input.mediaIDByAlias
        ))

        let stale = response(
            basedOn: valid,
            sourceRevision: valid.sourceRevision - 1
        )
        XCTAssertNil(CoverAIDirectorValidator.validate(
            stale,
            request: input.request,
            mediaIDByAlias: input.mediaIDByAlias
        ))

        let unknownTemplate = response(basedOn: valid, templateID: .scrapbook)
        XCTAssertNil(CoverAIDirectorValidator.validate(
            unknownTemplate,
            request: input.request,
            mediaIDByAlias: input.mediaIDByAlias
        ))

        let unknownPalette = response(basedOn: valid, paletteID: .oceanBlue)
        XCTAssertNil(CoverAIDirectorValidator.validate(
            unknownPalette,
            request: input.request,
            mediaIDByAlias: input.mediaIDByAlias
        ))

        let unknownMedia = response(
            basedOn: valid,
            mediaRoles: [
                CoverAIDirectorMediaRoleResponse(mediaAlias: "M99", role: .hero),
            ]
        )
        XCTAssertNil(CoverAIDirectorValidator.validate(
            unknownMedia,
            request: input.request,
            mediaIDByAlias: input.mediaIDByAlias
        ))
    }

    func testValidatorRejectsMagazineWithFewerThanTwoMediaSelections() throws {
        let source = makeSource(mediaCount: 2)
        let input = try LegacyWeeklyCoverAdapter.makeDirectorInput(from: source)
        let candidate = try XCTUnwrap(
            input.request.templateCandidates.first { $0.templateID == .magazine }
        )
        XCTAssertEqual(candidate.minimumMediaCount, 2)

        let response = CoverAIDirectorResponse(
            schemaVersion: CoverAIDirectorRules.currentVersion,
            sourceRevision: input.request.sourceRevision,
            periodKeyHash: input.request.periodKeyHash,
            contentFingerprint: input.request.contentFingerprint,
            templateID: candidate.templateID,
            variantID: candidate.variantID,
            paletteID: candidate.allowedPaletteIDs[0],
            backgroundFamily: candidate.allowedBackgroundFamilies[0],
            mediaRoles: [
                CoverAIDirectorMediaRoleResponse(mediaAlias: "M1", role: .hero),
            ],
            animationProfile: candidate.allowedAnimationProfiles[0],
            seed: 89_121,
            confidence: 0.88,
            reasonCodes: [.strongPhotoLead]
        )

        XCTAssertNil(CoverAIDirectorValidator.validate(
            response,
            request: input.request,
            mediaIDByAlias: input.mediaIDByAlias
        ))
    }

    func testValidAIDecisionStillPassesTheFullLocalRenderContract() throws {
        let source = makeSource(mediaCount: 2)
        let input = try LegacyWeeklyCoverAdapter.makeDirectorInput(from: source)
        let response = try validResponse(for: source)
        let decision = try XCTUnwrap(CoverAIDirectorValidator.validate(
            response,
            request: input.request,
            mediaIDByAlias: input.mediaIDByAlias
        ))

        let session = try LegacyWeeklyCoverAdapter.prepareSession(
            from: source,
            directorDecision: decision
        )
        let renderInput = session.previewRenderInput
        XCTAssertTrue(renderInput === session.exportRenderInput)
        XCTAssertEqual(renderInput.recipe.source, .ai)
        XCTAssertEqual(renderInput.recipe.template.templateID, response.templateID)
        XCTAssertEqual(renderInput.recipe.palette.paletteID, response.paletteID)
        XCTAssertEqual(renderInput.recipe.background.family, response.backgroundFamily)
        XCTAssertEqual(renderInput.recipe.media.first?.role, .hero)
        XCTAssertEqual(renderInput.preparedImagesByID.count, response.mediaRoles.count)
        XCTAssertTrue(Set(renderInput.allocation.footer.map(\.id)).isDisjoint(
            with: Set(renderInput.layout.bodyAtomPlacements.map(\.atomID))
        ))
    }

    func testStaleDecisionFallsBackToTheCompleteLocalRecipe() throws {
        let source = makeSource(mediaCount: 2)
        let input = try LegacyWeeklyCoverAdapter.makeDirectorInput(from: source)
        let response = try validResponse(for: source)
        let decision = try XCTUnwrap(CoverAIDirectorValidator.validate(
            response,
            request: input.request,
            mediaIDByAlias: input.mediaIDByAlias
        ))
        let stale = CoverAIDirectorDecision(
            requestCacheKey: decision.requestCacheKey,
            sourceRevision: decision.sourceRevision - 1,
            periodKeyHash: decision.periodKeyHash,
            contentFingerprint: decision.contentFingerprint,
            templateID: decision.templateID,
            variantID: decision.variantID,
            paletteID: decision.paletteID,
            backgroundFamily: decision.backgroundFamily,
            mediaSelections: decision.mediaSelections,
            animationProfile: decision.animationProfile,
            seed: decision.seed,
            confidence: decision.confidence,
            reasonCodes: decision.reasonCodes
        )

        let local = try LegacyWeeklyCoverAdapter.prepareSession(
            from: source,
            directorDecision: stale
        ).previewRenderInput
        XCTAssertEqual(local.recipe.source, .local)
        XCTAssertFalse(local.recipe.reasonCodes.isEmpty)
    }

    func testDecisionCacheIsBoundedAndUsesTheExactRequestKey() throws {
        let source = makeSource(mediaCount: 2)
        let input = try LegacyWeeklyCoverAdapter.makeDirectorInput(from: source)
        let response = try validResponse(for: source)
        let base = try XCTUnwrap(CoverAIDirectorValidator.validate(
            response,
            request: input.request,
            mediaIDByAlias: input.mediaIDByAlias
        ))
        CoverAIDirectorDecisionStore.shared.publish(base)
        XCTAssertEqual(
            CoverAIDirectorDecisionStore.shared.decision(for: input.request),
            base
        )

        for index in 0..<(CoverAIDirectorRules.maximumCachedDecisionCount + 6) {
            CoverAIDirectorDecisionStore.shared.publish(
                CoverAIDirectorDecision(
                    requestCacheKey: "cache-key-\(index)",
                    sourceRevision: index,
                    periodKeyHash: base.periodKeyHash,
                    contentFingerprint: base.contentFingerprint,
                    templateID: base.templateID,
                    variantID: base.variantID,
                    paletteID: base.paletteID,
                    backgroundFamily: base.backgroundFamily,
                    mediaSelections: base.mediaSelections,
                    animationProfile: base.animationProfile,
                    seed: base.seed,
                    confidence: base.confidence,
                    reasonCodes: base.reasonCodes
                )
            )
        }
        XCTAssertEqual(
            CoverAIDirectorDecisionStore.shared.cachedDecisionCount,
            CoverAIDirectorRules.maximumCachedDecisionCount
        )
    }

    private func validResponse(
        for source: LegacyWeeklyCoverSource
    ) throws -> CoverAIDirectorResponse {
        let input = try LegacyWeeklyCoverAdapter.makeDirectorInput(from: source)
        let candidate = try XCTUnwrap(
            input.request.templateCandidates.first { $0.templateID == .heroStory }
        )
        return CoverAIDirectorResponse(
            schemaVersion: CoverAIDirectorRules.currentVersion,
            sourceRevision: input.request.sourceRevision,
            periodKeyHash: input.request.periodKeyHash,
            contentFingerprint: input.request.contentFingerprint,
            templateID: candidate.templateID,
            variantID: candidate.variantID,
            paletteID: candidate.allowedPaletteIDs[0],
            backgroundFamily: candidate.allowedBackgroundFamilies[0],
            mediaRoles: [
                CoverAIDirectorMediaRoleResponse(mediaAlias: "M1", role: .hero),
                CoverAIDirectorMediaRoleResponse(mediaAlias: "M2", role: .secondary),
            ],
            animationProfile: candidate.allowedAnimationProfiles[0],
            seed: 89_121,
            confidence: 0.88,
            reasonCodes: [.strongPhotoLead, .balancedPhotoSet]
        )
    }

    private func response(
        basedOn base: CoverAIDirectorResponse,
        sourceRevision: Int? = nil,
        templateID: CoverTemplateID? = nil,
        paletteID: CoverPaletteID? = nil,
        mediaRoles: [CoverAIDirectorMediaRoleResponse]? = nil
    ) -> CoverAIDirectorResponse {
        CoverAIDirectorResponse(
            schemaVersion: base.schemaVersion,
            sourceRevision: sourceRevision ?? base.sourceRevision,
            periodKeyHash: base.periodKeyHash,
            contentFingerprint: base.contentFingerprint,
            templateID: templateID ?? base.templateID,
            variantID: base.variantID,
            paletteID: paletteID ?? base.paletteID,
            backgroundFamily: base.backgroundFamily,
            mediaRoles: mediaRoles ?? base.mediaRoles,
            animationProfile: base.animationProfile,
            seed: base.seed,
            confidence: base.confidence,
            reasonCodes: base.reasonCodes
        )
    }

    private func makeSource(mediaCount: Int) -> LegacyWeeklyCoverSource {
        let leadText = "下班路上，也把这一刻留了下来"
        let supportText = "雨停以后，回家的路慢了一点"
        let evidenceIDs = (0..<max(1, mediaCount)).map { index in
            UUID(uuidString: String(format: "51000000-0000-0000-0000-%012d", index + 1))!
        }
        let leadSignal = LifeNarrativeSignal(
            id: "director.lead",
            kind: .userText,
            label: "这一周",
            fact: leadText,
            evidenceItemIDs: evidenceIDs,
            confidence: 96,
            informationGain: 92,
            narrativeValue: 94,
            representativeness: 90,
            isAdministrative: false,
            isSensitive: false,
            isStable: false
        )
        let supportSignal = LifeNarrativeSignal(
            id: "director.support",
            kind: .userText,
            label: "回家的路",
            fact: supportText,
            evidenceItemIDs: evidenceIDs,
            confidence: 92,
            informationGain: 84,
            narrativeValue: 86,
            representativeness: 82,
            isAdministrative: false,
            isSensitive: false,
            isStable: false
        )
        let plan = LifeNarrativePlan(
            scope: .week,
            sourceRevision: 98,
            maturity: .contextual,
            headline: leadText,
            summary: supportText,
            supportingLine: supportText,
            leadSignalID: leadSignal.id,
            signalsByRole: [
                .lead: [leadSignal],
                .support: [supportSignal],
            ]
        )
        let dailyCounts = ["一", "二", "三", "四", "五", "六", "日"].enumerated().map {
            ($0.element, $0.offset < 4 ? 1 : 0)
        }
        let payload = WeeklyShareCardPayload(
            weekTotal: 188,
            topCategory: "日常",
            recordCount: 4,
            primaryMetricCount: 4,
            primaryMetricEmoji: "",
            dailyTrend: dailyCounts.map { ($0.0, Double($0.1) * 20) },
            dailyCountTrend: dailyCounts,
            categorySlices: [],
            topCategoryRatio: 0.4,
            headline: leadText,
            subtitle: supportText,
            anchorLine: nil,
            lifeMarkLine: nil,
            contextLine: nil,
            emotionLine: nil,
            periodText: "2026.07.20—07.26",
            insight: ShareInsight(
                fact: leadText,
                care: supportText,
                footnote: "本周",
                tags: []
            ),
            narrativePlan: plan,
            narrativeEcho: nil,
            narrativeRewrite: nil
        )
        let media = (0..<mediaCount).map { index in
            LegacyWeeklyCoverMedia(
                id: UUID(uuidString: String(format: "52000000-0000-0000-0000-%012d", index + 1))!,
                evidenceItemIDs: [evidenceIDs[index]],
                image: makeImage(index: index),
                privacyRisk: .safe,
                allowsHero: true
            )
        }
        return LegacyWeeklyCoverSource(
            sourceRevision: 98,
            payload: payload,
            fallbackEvidenceItemIDs: evidenceIDs,
            media: media,
            unavailableMediaCount: 0,
            variantID: "magazine",
            paletteID: .creamMorning,
            backgroundFamily: .morningLight,
            backgroundImage: nil,
            backgroundIdentity: "director-test"
        )
    }

    private func makeImage(index: Int) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 160, height: 220))
        return renderer.image { context in
            UIColor(
                hue: CGFloat(index % 6) / 6,
                saturation: 0.45,
                brightness: 0.82,
                alpha: 1
            ).setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 160, height: 220))
        }
    }
}
