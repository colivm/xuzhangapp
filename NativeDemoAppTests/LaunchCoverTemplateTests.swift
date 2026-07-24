import UIKit
import XCTest
@testable import NativeDemoApp

final class LaunchCoverTemplateTests: XCTestCase {
    func testCatalogContainsExactlyTwentyCompleteUniqueTemplates() throws {
        let expectedIDs: [CoverTemplateID] = [
            .heroStory, .magazine, .memoryFocus, .journal, .film,
            .minimal, .quote, .timeline, .postcard, .scrapbook,
            .editorial, .memoryWall, .travelNote, .bookCover,
            .natureDiary, .coffeeStory, .warmHome, .nightStory,
            .ocean, .quietEditorial,
        ]
        let expectedNames = [
            "主角故事", "杂志版面", "回忆聚焦", "生活手札", "胶片故事",
            "留白", "一句话", "时间线", "明信片", "拼贴手账",
            "编辑精选", "记忆墙", "旅行札记", "书封", "自然日记",
            "咖啡片段", "家中片刻", "夜行故事", "海边记忆", "静默编辑",
        ]

        XCTAssertEqual(LaunchCoverTemplateCatalog.orderedTemplateIDs, expectedIDs)
        XCTAssertEqual(CoverTemplateID.allCases, expectedIDs)
        XCTAssertEqual(Set(expectedIDs).count, 20)
        XCTAssertEqual(
            expectedIDs.compactMap {
                LaunchCoverTemplateCatalog.descriptor(for: $0)?.displayName
            },
            expectedNames
        )

        for templateID in expectedIDs {
            let descriptor = try XCTUnwrap(
                LaunchCoverTemplateCatalog.descriptor(for: templateID)
            )
            XCTAssertEqual(descriptor.id, templateID)
            XCTAssertFalse(descriptor.displayName.isEmpty)
            XCTAssertFalse(descriptor.subtitle.isEmpty)
            XCTAssertFalse(descriptor.systemImageName.isEmpty)
            XCTAssertGreaterThanOrEqual(descriptor.supportedPhotoCounts.lowerBound, 0)
            XCTAssertGreaterThanOrEqual(
                descriptor.maximumRenderedPhotoCount,
                descriptor.supportedPhotoCounts.lowerBound
            )
            XCTAssertLessThanOrEqual(
                descriptor.maximumRenderedPhotoCount,
                descriptor.supportedPhotoCounts.upperBound
            )
            XCTAssertFalse(descriptor.requiresEvidenceBoundHero && !descriptor.allowsHero)
        }
    }

    func testLegacyAndExplicitStyleIDsMapToTheTwentyTemplateCatalog() {
        for templateID in LaunchCoverTemplateCatalog.orderedTemplateIDs {
            XCTAssertEqual(
                LaunchCoverTemplateCatalog.templateID(
                    forLegacyVariantID: templateID.rawValue
                ),
                templateID
            )
        }

        let mappings: [(String, CoverTemplateID)] = [
            ("warmLight", .heroStory),
            ("fullPhoto", .heroStory),
            ("customBackground", .heroStory),
            ("magazine", .magazine),
            ("collageStory", .magazine),
            ("journal", .journal),
            ("review-weekly", .journal),
            ("appleMemories", .quote),
            ("filmStory", .timeline),
            ("cleanTexture", .minimal),
        ]

        for (legacyID, expected) in mappings {
            XCTAssertEqual(
                LaunchCoverTemplateCatalog.templateID(forLegacyVariantID: legacyID),
                expected
            )
        }
        XCTAssertEqual(
            LaunchCoverTemplateCatalog.templateID(forLegacyVariantID: "film"),
            .film
        )
        XCTAssertNil(
            LaunchCoverTemplateCatalog.templateID(forLegacyVariantID: "unknown-template")
        )
    }

    func testManualEligibilityAndMediaRecipesCoverZeroThroughSevenPhotos() throws {
        let allOrientations: Set<MediaOrientation> = [.portrait, .landscape, .square]

        for templateID in LaunchCoverTemplateCatalog.orderedTemplateIDs {
            let descriptor = try XCTUnwrap(
                LaunchCoverTemplateCatalog.descriptor(for: templateID)
            )
            for photoCount in 0...7 {
                let input = selectionInput(
                    preferredTemplateID: templateID,
                    photoCount: photoCount,
                    orientations: allOrientations
                )
                let renderedPhotoCount = min(
                    photoCount,
                    descriptor.maximumRenderedPhotoCount
                )
                let expectedEligibility = descriptor.supportedPhotoCounts.contains(
                    renderedPhotoCount
                )
                XCTAssertEqual(
                    LaunchCoverTemplateCatalog.manuallyAvailableTemplateIDs(for: input)
                        .contains(templateID),
                    expectedEligibility,
                    "\(templateID.rawValue) eligibility drifted for \(photoCount) photos"
                )
            }

            let fixture = makeMediaDescriptors(
                count: 7,
                orientations: [.portrait, .landscape, .square]
            )
            let recipes = LaunchCoverTemplateCatalog.mediaRecipes(
                for: templateID,
                descriptors: fixture.descriptors,
                leadEvidenceItemIDs: fixture.evidenceItemIDs
            )
            XCTAssertEqual(recipes.count, descriptor.maximumRenderedPhotoCount)
            XCTAssertEqual(Set(recipes.map(\.mediaID)).count, recipes.count)
            XCTAssertEqual(
                recipes.filter { $0.role == .hero }.count,
                descriptor.allowsHero ? 1 : 0
            )
            if descriptor.allowsDecoration {
                XCTAssertTrue(recipes.allSatisfy { $0.role == .decoration })
            } else if !descriptor.allowsHero {
                XCTAssertTrue(recipes.allSatisfy { $0.role == .secondary })
            }
        }
    }

    func testAutomaticSceneCandidatesRemainSeparateFromManualCatalog() {
        let noScene = selectionInput(
            preferredTemplateID: nil,
            photoCount: 2,
            sceneKeys: []
        )
        let manual = LaunchCoverTemplateCatalog.manuallyAvailableTemplateIDs(for: noScene)
        let automatic = LaunchCoverTemplateCatalog.availableTemplateIDs(for: noScene)

        for templateID in [
            CoverTemplateID.postcard, .travelNote, .natureDiary, .coffeeStory,
            .warmHome, .nightStory, .ocean,
        ] {
            XCTAssertTrue(manual.contains(templateID))
            XCTAssertFalse(automatic.contains(templateID))
        }

        let matched = selectionInput(
            preferredTemplateID: nil,
            photoCount: 2,
            sceneKeys: [
                "scene:cityRoute", "scene:lodging", "scene:coffee",
                "scene:homeSupply", "scene:groceries",
            ]
        )
        let matchedAutomatic = LaunchCoverTemplateCatalog.availableTemplateIDs(for: matched)
        for templateID in [
            CoverTemplateID.postcard, .travelNote, .coffeeStory, .warmHome,
        ] {
            XCTAssertTrue(matchedAutomatic.contains(templateID))
        }
        for templateID in [
            CoverTemplateID.natureDiary, .nightStory, .ocean,
        ] {
            XCTAssertFalse(matchedAutomatic.contains(templateID))
        }
    }

    func testZeroPhotoLaunchTemplatesRenderWithoutMediaOrPlaceholders() throws {
        let variants: [(String, CoverTemplateID)] = [
            ("journal", .journal),
            ("appleMemories", .quote),
            ("filmStory", .timeline),
            ("cleanTexture", .minimal),
        ]

        for (variantID, expectedTemplateID) in variants {
            let session = try LegacyWeeklyCoverAdapter.prepareSession(
                from: makeSource(
                    variantID: variantID,
                    mediaCount: 0,
                    recordedDayCount: 4
                )
            )
            let input = session.previewRenderInput
            XCTAssertEqual(input.recipe.template.templateID, expectedTemplateID)
            XCTAssertTrue(input.recipe.media.isEmpty)
            XCTAssertTrue(input.layout.mediaPlacements.isEmpty)
            XCTAssertTrue(input.preparedImagesByID.isEmpty)
        }
    }

    func testSecondaryOnlyAndReceiptMediaNeverBecomeHero() throws {
        let secondaryOnly = try LegacyWeeklyCoverAdapter.prepareSession(
            from: makeSource(
                variantID: "warmLight",
                mediaCount: 1,
                allowsHero: false,
                recordedDayCount: 4
            )
        ).previewRenderInput
        XCTAssertNotEqual(secondaryOnly.recipe.template.templateID, .heroStory)
        XCTAssertFalse(secondaryOnly.recipe.media.contains { $0.role == .hero })

        let receipt = try LegacyWeeklyCoverAdapter.prepareSession(
            from: makeSource(
                variantID: "warmLight",
                mediaCount: 1,
                privacyRisk: .receiptOrScreenshot,
                recordedDayCount: 4
            )
        ).previewRenderInput
        XCTAssertTrue(receipt.recipe.media.isEmpty)
        XCTAssertTrue(receipt.preparedImagesByID.isEmpty)
        XCTAssertEqual(receipt.unavailableMediaCount, 1)
        XCTAssertNotEqual(receipt.recipe.template.templateID, .heroStory)
    }

    func testLongQuoteAndMinimalCopyFallBackToExpandedJournalLayout() throws {
        let longLead = String(repeating: "这一段真实生活仍然需要完整保留", count: 5)
        for variantID in ["appleMemories", "cleanTexture"] {
            let input = try LegacyWeeklyCoverAdapter.prepareSession(
                from: makeSource(
                    variantID: variantID,
                    mediaCount: 0,
                    leadText: longLead,
                    recordedDayCount: 2
                )
            ).previewRenderInput
            XCTAssertEqual(input.recipe.template.templateID, .journal)
            let leadPlacement = try XCTUnwrap(
                input.layout.bodyAtomPlacements.first { $0.textRole == .lead }
            )
            XCTAssertEqual(leadPlacement.lineLimit, 5)
            XCTAssertGreaterThanOrEqual(leadPlacement.frame.height, 220)
        }
    }

    func testTimelineRequiresAtLeastThreeCertifiedRecordDays() throws {
        let twoDays = try LegacyWeeklyCoverAdapter.prepareSession(
            from: makeSource(
                variantID: "filmStory",
                mediaCount: 0,
                recordedDayCount: 2
            )
        ).previewRenderInput
        XCTAssertNotEqual(twoDays.recipe.template.templateID, .timeline)

        let threeDays = try LegacyWeeklyCoverAdapter.prepareSession(
            from: makeSource(
                variantID: "filmStory",
                mediaCount: 0,
                recordedDayCount: 3
            )
        ).previewRenderInput
        XCTAssertEqual(threeDays.recipe.template.templateID, .timeline)
        XCTAssertEqual(threeDays.allocation.timeline.count, 3)
        XCTAssertEqual(threeDays.layout.bodyAtomPlacements.filter { $0.textRole == .timeline }.count, 3)
    }

    func testTwentyLayoutsKeepAtomMediaFooterAndCanvasContractsAligned() throws {
        var signatures: Set<String> = []

        for templateID in LaunchCoverTemplateCatalog.orderedTemplateIDs {
            let descriptor = try XCTUnwrap(
                LaunchCoverTemplateCatalog.descriptor(for: templateID)
            )
            let session = try LegacyWeeklyCoverAdapter.prepareSession(
                from: makeSource(
                    variantID: templateID.rawValue,
                    mediaCount: descriptor.maximumRenderedPhotoCount,
                    recordedDayCount: 7
                )
            )
            let input = session.previewRenderInput
            XCTAssertTrue(input === session.exportRenderInput)
            XCTAssertEqual(input.recipe.template.templateID, templateID)
            XCTAssertEqual(input.recipe.media.count, descriptor.maximumRenderedPhotoCount)
            XCTAssertEqual(input.layout.canvasSize, CoverRenderSize(width: 540, height: 960))
            XCTAssertEqual(
                input.layout.footerFrame,
                CoverRenderRect(x: 32, y: 872, width: 476, height: 56)
            )

            let footerIDs = Set(input.allocation.footer.map(\.id))
            let bodyIDs = Set(input.layout.bodyAtomPlacements.map(\.atomID))
            let expectedBodyIDs = Set(
                input.allocation.visiblePlacements.compactMap { placement in
                    placement.region == .footer ? nil : placement.atom.id
                }
            )
            XCTAssertTrue(footerIDs.isDisjoint(with: bodyIDs))
            XCTAssertEqual(bodyIDs, expectedBodyIDs)
            XCTAssertEqual(input.recipe.footer.atomIDs, input.allocation.footer.map(\.id))
            XCTAssertEqual(input.footerPresentation.textAtomIDs, input.allocation.footer.map(\.id))
            XCTAssertEqual(
                input.footerPresentation.text.components(separatedBy: " · ").count,
                4
            )
            for placement in input.allocation.visiblePlacements where
                placement.atom.role == .brand || placement.atom.role == .footerMetric {
                XCTAssertEqual(placement.region, .footer)
            }

            let recipeMediaIDs = input.recipe.media.map(\.mediaID)
            let layoutMediaIDs = input.layout.mediaPlacements.map(\.mediaID)
            XCTAssertEqual(Set(recipeMediaIDs), Set(layoutMediaIDs))
            XCTAssertEqual(Set(recipeMediaIDs), Set(input.preparedImagesByID.keys))
            XCTAssertEqual(Set(layoutMediaIDs).count, layoutMediaIDs.count)

            for placement in input.layout.bodyAtomPlacements {
                XCTAssertTrue(placement.frame.isInside(input.layout.canvasSize))
                XCTAssertLessThanOrEqual(placement.frame.maxY, input.layout.footerFrame.y)
                XCTAssertFalse(placement.frame.intersects(input.layout.footerFrame))
            }
            for placement in input.layout.mediaPlacements {
                XCTAssertTrue(placement.frame.isInside(input.layout.canvasSize))
                XCTAssertLessThanOrEqual(placement.frame.maxY, input.layout.footerFrame.y)
                XCTAssertFalse(placement.frame.intersects(input.layout.footerFrame))
            }

            let mediaFrameSignatures = input.layout.mediaPlacements.map {
                "\($0.frame.x):\($0.frame.y):\($0.frame.width):\($0.frame.height)"
            }
            XCTAssertEqual(Set(mediaFrameSignatures).count, mediaFrameSignatures.count)
            if input.recipe.media.count >= 4 {
                let mediaSizes = Set(input.layout.mediaPlacements.map {
                    "\($0.frame.width):\($0.frame.height)"
                })
                XCTAssertGreaterThan(mediaSizes.count, 1)
            }

            if let heroRecipe = input.recipe.media.first(where: { $0.role == .hero }) {
                let heroPlacement = try XCTUnwrap(
                    input.layout.mediaPlacements.first { $0.mediaID == heroRecipe.mediaID }
                )
                let heroArea = heroPlacement.frame.width * heroPlacement.frame.height
                for secondaryRecipe in input.recipe.media where secondaryRecipe.role != .hero {
                    let secondaryPlacement = try XCTUnwrap(
                        input.layout.mediaPlacements.first {
                            $0.mediaID == secondaryRecipe.mediaID
                        }
                    )
                    XCTAssertGreaterThan(
                        heroArea,
                        secondaryPlacement.frame.width * secondaryPlacement.frame.height,
                        "\(templateID.rawValue) must keep Hero larger than every auxiliary image"
                    )
                }
            }

            let signature = input.layout.bodyAtomPlacements.map {
                "\($0.textRole.rawValue):\($0.frame.x):\($0.frame.y):\($0.frame.width):\($0.frame.height)"
            }.joined(separator: "|") + input.layout.mediaPlacements.map {
                "media:\($0.frame.x):\($0.frame.y):\($0.frame.width):\($0.frame.height)"
            }.joined(separator: "|")
            signatures.insert(signature)
        }
        XCTAssertEqual(signatures.count, 20)
    }

    func testBookCoverRequiresPortraitHeroAcrossSelectionAndRecipe() throws {
        let landscapeOnly = selectionInput(
            preferredTemplateID: .bookCover,
            photoCount: 1,
            orientations: [.landscape]
        )
        XCTAssertFalse(
            LaunchCoverTemplateCatalog.manuallyAvailableTemplateIDs(for: landscapeOnly)
                .contains(.bookCover)
        )
        XCTAssertNotEqual(
            LaunchCoverTemplateCatalog.selectTemplateID(for: landscapeOnly),
            .bookCover
        )

        let portrait = selectionInput(
            preferredTemplateID: .bookCover,
            photoCount: 1,
            orientations: [.portrait]
        )
        XCTAssertTrue(
            LaunchCoverTemplateCatalog.manuallyAvailableTemplateIDs(for: portrait)
                .contains(.bookCover)
        )
        XCTAssertEqual(
            LaunchCoverTemplateCatalog.selectTemplateID(for: portrait),
            .bookCover
        )

        let fixture = makeMediaDescriptors(
            count: 2,
            orientations: [.landscape, .portrait]
        )
        let recipes = LaunchCoverTemplateCatalog.mediaRecipes(
            for: .bookCover,
            descriptors: fixture.descriptors,
            leadEvidenceItemIDs: fixture.evidenceItemIDs
        )
        XCTAssertEqual(recipes.count, 1)
        XCTAssertEqual(recipes.first?.role, .hero)
        XCTAssertEqual(recipes.first?.mediaID, fixture.descriptors[1].id)
    }

    private func selectionInput(
        preferredTemplateID: CoverTemplateID?,
        photoCount: Int,
        orientations: Set<MediaOrientation> = [.portrait, .landscape, .square],
        sceneKeys: Set<String> = []
    ) -> LaunchCoverTemplateSelectionInput {
        LaunchCoverTemplateSelectionInput(
            preferredTemplateID: preferredTemplateID,
            availablePhotoCount: photoCount,
            hasEvidenceBoundHero: photoCount > 0,
            evidenceBoundHeroOrientations: photoCount > 0 ? orientations : [],
            recordedDayCount: 7,
            leadCharacterCount: 18,
            sceneKeys: sceneKeys
        )
    }

    private func makeMediaDescriptors(
        count: Int,
        orientations: [MediaOrientation]
    ) -> (descriptors: [MediaDescriptor], evidenceItemIDs: [UUID]) {
        precondition(!orientations.isEmpty)
        let evidenceItemIDs = (0..<count).map { index in
            UUID(uuidString: String(format: "43000000-0000-0000-0000-%012d", index + 1))!
        }
        let descriptors = (0..<count).map { index in
            MediaDescriptor(
                id: UUID(uuidString: String(format: "44000000-0000-0000-0000-%012d", index + 1))!,
                evidenceItemIDs: [evidenceItemIDs[index]],
                orientation: orientations[index % orientations.count],
                eligibility: .heroEligible,
                privacyRisk: .safe,
                caption: nil
            )
        }
        return (descriptors, evidenceItemIDs)
    }

    private func session(
        variantID: String,
        mediaCount: Int
    ) throws -> CoverShareSession {
        try LegacyWeeklyCoverAdapter.prepareSession(
            from: makeSource(
                variantID: variantID,
                mediaCount: mediaCount,
                recordedDayCount: 4
            )
        )
    }

    private func makeSource(
        variantID: String,
        mediaCount: Int,
        allowsHero: Bool = true,
        privacyRisk: CoverMediaPrivacyRisk = .safe,
        leadText: String = "下班路上，也把这一刻留了下来",
        recordedDayCount: Int
    ) -> LegacyWeeklyCoverSource {
        let evidenceIDs = (0..<max(1, mediaCount)).map { index in
            UUID(uuidString: String(format: "41000000-0000-0000-0000-%012d", index + 1))!
        }
        let leadSignal = LifeNarrativeSignal(
            id: "launch.lead",
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
            id: "launch.support",
            kind: .userText,
            label: "回家的路",
            fact: "雨停以后，回家的路慢了一点",
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
            sourceRevision: 88,
            maturity: .contextual,
            headline: leadText,
            summary: supportSignal.fact,
            supportingLine: supportSignal.fact,
            leadSignalID: leadSignal.id,
            signalsByRole: [
                .lead: [leadSignal],
                .support: [supportSignal],
            ]
        )
        let dayLabels = ["一", "二", "三", "四", "五", "六", "日"]
        let dailyCounts = dayLabels.enumerated().map { index, label in
            (label, index < recordedDayCount ? 1 : 0)
        }
        let payload = WeeklyShareCardPayload(
            weekTotal: 188,
            topCategory: "日常",
            recordCount: max(recordedDayCount, 1),
            primaryMetricCount: max(recordedDayCount, 1),
            primaryMetricEmoji: "",
            dailyTrend: dailyCounts.map { ($0.0, Double($0.1) * 20) },
            dailyCountTrend: dailyCounts,
            categorySlices: [],
            topCategoryRatio: 0.4,
            headline: leadText,
            subtitle: supportSignal.fact,
            anchorLine: nil,
            lifeMarkLine: nil,
            contextLine: nil,
            emotionLine: nil,
            periodText: "2026.07.20—07.26",
            insight: ShareInsight(
                fact: leadText,
                care: supportSignal.fact,
                footnote: "本周",
                tags: []
            ),
            narrativePlan: plan,
            narrativeEcho: nil,
            narrativeRewrite: nil
        )
        let media = (0..<mediaCount).map { index in
            LegacyWeeklyCoverMedia(
                id: UUID(uuidString: String(format: "42000000-0000-0000-0000-%012d", index + 1))!,
                evidenceItemIDs: [evidenceIDs[index]],
                image: makeImage(index: index),
                privacyRisk: privacyRisk,
                allowsHero: allowsHero
            )
        }
        return LegacyWeeklyCoverSource(
            sourceRevision: 88,
            payload: payload,
            fallbackEvidenceItemIDs: evidenceIDs,
            media: media,
            unavailableMediaCount: 0,
            variantID: variantID,
            paletteID: .quietCream,
            backgroundFamily: .minimal,
            backgroundImage: nil,
            backgroundIdentity: "launch-test:\(variantID):\(mediaCount)"
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
