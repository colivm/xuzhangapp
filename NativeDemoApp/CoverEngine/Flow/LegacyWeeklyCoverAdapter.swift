import Foundation
import UIKit

struct LegacyWeeklyCoverMedia: @unchecked Sendable {
    let id: UUID
    let evidenceItemIDs: [UUID]
    let image: UIImage
    let privacyRisk: CoverMediaPrivacyRisk
    let allowsHero: Bool
    let requiresAnalysisForHero: Bool
    let analysis: CoverMediaAnalysis?

    init(
        id: UUID,
        evidenceItemIDs: [UUID],
        image: UIImage,
        privacyRisk: CoverMediaPrivacyRisk,
        allowsHero: Bool,
        requiresAnalysisForHero: Bool = false,
        analysis: CoverMediaAnalysis? = nil
    ) {
        self.id = id
        self.evidenceItemIDs = evidenceItemIDs
        self.image = image
        self.privacyRisk = privacyRisk
        self.allowsHero = allowsHero
        self.requiresAnalysisForHero = requiresAnalysisForHero
        self.analysis = analysis
    }
}

struct LegacyWeeklyCoverSource: @unchecked Sendable {
    let sourceRevision: Int
    let payload: WeeklyShareCardPayload
    let fallbackEvidenceItemIDs: [UUID]
    let media: [LegacyWeeklyCoverMedia]
    let unavailableMediaCount: Int
    let variantID: String
    let paletteID: CoverPaletteID
    let backgroundFamily: BackgroundFamily
    let backgroundImage: UIImage?
    let backgroundIdentity: String
}

struct LegacyWeeklyCoverDirectorInput: Equatable, Sendable {
    let request: CoverAIDirectorRequest
    let mediaIDByAlias: [String: UUID]
}

enum LegacyWeeklyCoverAdapterErrorCode: String, Codable, Sendable {
    case missingCertifiedLead
    case duplicateMedia
    case invalidPreparedImage
}

struct LegacyWeeklyCoverAdapterError: Error, Equatable, Sendable {
    let code: LegacyWeeklyCoverAdapterErrorCode
    let relatedIDs: [String]
}

enum LegacyWeeklyCoverAdapter {
    static func makeDirectorInput(
        from source: LegacyWeeklyCoverSource
    ) throws -> LegacyWeeklyCoverDirectorInput {
        try directorInput(from: assembledContext(from: source), source: source)
    }

    static func prepareSession(
        from source: LegacyWeeklyCoverSource,
        directorDecision: CoverAIDirectorDecision? = nil
    ) throws -> CoverShareSession {
        let context = try assembledContext(from: source)
        let story = context.story
        let support = context.support
        let safeMedia = context.safeMedia
        let descriptors = context.descriptors
        let recordedDayCount = context.recordedDayCount
        let factPack = context.factPack
        let hasEvidenceBoundHero = context.hasEvidenceBoundHero
        let fingerprint = factPack.contentFingerprint
        let leadText = story.text
        let privacyFilteredCount = context.privacyFilteredCount
        let preferredTemplateID = LaunchCoverTemplateCatalog.templateID(
            forLegacyVariantID: source.variantID
        )
        let localTemplateID = LaunchCoverTemplateCatalog.selectTemplateID(
            for: LaunchCoverTemplateSelectionInput(
                preferredTemplateID: preferredTemplateID,
                availablePhotoCount: descriptors.count,
                hasEvidenceBoundHero: hasEvidenceBoundHero,
                evidenceBoundHeroOrientations: evidenceBoundHeroOrientations(
                    descriptors,
                    leadEvidenceItemIDs: story.evidenceItemIDs
                ),
                recordedDayCount: recordedDayCount,
                leadCharacterCount: leadText.count,
                sceneKeys: Set(factPack.context.sceneKeys)
            )
        )
        let currentDirectorInput = try? directorInput(from: context, source: source)
        let acceptedDirectorDecision = directorDecision.flatMap { decision in
            guard source.backgroundImage == nil,
                  let currentDirectorInput,
                  CoverAIDirectorValidator.isStillValid(
                    decision,
                    request: currentDirectorInput.request,
                    mediaIDByAlias: currentDirectorInput.mediaIDByAlias
                  ) else {
                return nil
            }
            return decision
        }
        let templateID = acceptedDirectorDecision?.templateID ?? localTemplateID
        let allocation = try ContentAllocationEngine.allocate(
            atoms: factPack.contentAtoms(),
            request: LaunchCoverTemplateCatalog.allocationRequest(
                for: templateID,
                factPack: factPack
            ),
            privacyPolicy: factPack.privacy
        )
        let mediaRecipes = acceptedDirectorDecision.map {
            mediaRecipes(for: templateID, selections: $0.mediaSelections)
        } ?? LaunchCoverTemplateCatalog.mediaRecipes(
            for: templateID,
            descriptors: descriptors,
            leadEvidenceItemIDs: story.evidenceItemIDs
        )
        let selectedMediaIDs = Set(mediaRecipes.map(\.mediaID))
        let selectedImages = safeMedia.reduce(into: [UUID: UIImage]()) { result, media in
            guard selectedMediaIDs.contains(media.id) else { return }
            result[media.id] = media.image
        }
        let selectedAnalyses = safeMedia.reduce(into: [UUID: CoverMediaAnalysis]()) { result, media in
            guard selectedMediaIDs.contains(media.id), let analysis = media.analysis else { return }
            result[media.id] = analysis
        }
        let heroMediaID = mediaRecipes.first(where: { $0.role == .hero })?.mediaID
        let dynamicPalette = source.backgroundImage == nil
            ? heroMediaID
                .flatMap { selectedAnalyses[$0]?.palette }
                .flatMap { $0.isValid ? $0 : nil }
            : nil
        let localSeed = UInt64(fingerprint.prefix(16), radix: 16) ?? 0
        let seed = acceptedDirectorDecision?.seed ?? localSeed
        let variantID = acceptedDirectorDecision?.variantID ?? LaunchCoverTemplateCatalog.variantID(
            for: templateID,
            leadCharacterCount: leadText.count,
            mediaCount: mediaRecipes.count
        )
        let paletteID = acceptedDirectorDecision?.paletteID ?? source.paletteID
        let backgroundFamily = acceptedDirectorDecision?.backgroundFamily ?? source.backgroundFamily
        let animationProfile = acceptedDirectorDecision?.animationProfile
            ?? LaunchCoverTemplateCatalog.descriptor(for: templateID)?.animationProfile
            ?? .quietFade
        let reasonCodes = acceptedDirectorDecision?.reasonCodes
            ?? LaunchCoverTemplateCatalog.reasonCodes(
                for: templateID,
                hasEvidenceBoundHero: hasEvidenceBoundHero,
                availablePhotoCount: descriptors.count
            )
        let recipeFingerprint = CoverStableIdentity.fingerprint([
            fingerprint,
            acceptedDirectorDecision == nil ? "local" : "ai",
            templateID.rawValue,
            variantID,
            paletteID.rawValue,
            backgroundFamily.rawValue,
            source.backgroundIdentity,
            animationProfile.rawValue,
            String(seed),
            mediaRecipes.map { "\($0.mediaID.uuidString):\($0.role.rawValue)" }
                .joined(separator: "|"),
        ])
        let recipeID = "cover.launch.\(recipeFingerprint)"
        let templateDescriptor = LaunchCoverTemplateCatalog.descriptor(for: templateID)
        let recipe = CoverRecipe(
            schemaVersion: CoverContractSchema.currentVersion,
            recipeID: recipeID,
            source: acceptedDirectorDecision == nil ? .local : .ai,
            sourceRevision: factPack.sourceRevision,
            periodKey: factPack.periodKey,
            contentFingerprint: factPack.contentFingerprint,
            template: TemplateSelection(
                templateID: templateID,
                variantID: variantID
            ),
            palette: CoverPaletteRecipe(paletteID: paletteID),
            background: BackgroundRecipe(
                family: backgroundFamily,
                seed: seed
            ),
            typography: TypographyRecipe(
                family: templateDescriptor?.typographyFamily ?? .journal
            ),
            content: ContentRecipe(
                leadAtomID: allocation.storyLead.id,
                supportAtomID: allocation.storySupport?.id,
                markAtomIDs: allocation.marks.map(\.id),
                timelineAtomIDs: allocation.timeline.map(\.id)
            ),
            media: mediaRecipes,
            footer: FooterRecipe(
                style: .quiet,
                atomIDs: allocation.footer.map(\.id),
                showsVerifiedQRCode: false
            ),
            animation: CoverAnimationRecipe(
                profile: animationProfile
            ),
            seed: seed,
            confidence: acceptedDirectorDecision?.confidence ?? 1,
            reasonCodes: reasonCodes
        )
        let layout = LaunchCoverTemplateLayoutResolver.resolve(
            recipe: recipe,
            allocation: allocation
        )
        return try CoverShareFlow.prepare(
            CoverRenderPreparationRequest(
                expectedSourceRevision: source.sourceRevision,
                factPack: factPack,
                allocation: allocation,
                recipe: recipe,
                layout: layout,
                preparedImagesByID: selectedImages,
                mediaAnalysesByID: selectedAnalyses,
                dynamicPalette: dynamicPalette,
                backgroundImage: source.backgroundImage,
                unavailableMediaCount: source.unavailableMediaCount + privacyFilteredCount
            )
        )
    }

    private struct AssembledContext {
        let story: CertifiedStory
        let support: CertifiedStory?
        let safeMedia: [LegacyWeeklyCoverMedia]
        let descriptors: [MediaDescriptor]
        let recordedDayCount: Int
        let factPack: CoverFactPack
        let hasEvidenceBoundHero: Bool
        let privacyFilteredCount: Int
    }

    private static func assembledContext(
        from source: LegacyWeeklyCoverSource
    ) throws -> AssembledContext {
        let leadSignal = source.payload.narrativePlan?.signalsByRole[.lead]?.first(
            where: isCertifiedSignal
        )
        let fallbackEvidence = unique(source.fallbackEvidenceItemIDs)
        let leadEvidence = unique(leadSignal?.evidenceItemIDs ?? fallbackEvidence)
        guard !leadEvidence.isEmpty else {
            throw LegacyWeeklyCoverAdapterError(
                code: .missingCertifiedLead,
                relatedIDs: []
            )
        }

        let leadText = firstNonempty([
            source.payload.narrativeRewrite?.headline,
            source.payload.narrativePlan?.headline,
            source.payload.headline,
            source.payload.insight.fact,
        ])
        guard let leadText else {
            throw LegacyWeeklyCoverAdapterError(
                code: .missingCertifiedLead,
                relatedIDs: leadEvidence.map(\.uuidString)
            )
        }
        let leadSeed = leadSignal?.id ?? CoverStableIdentity.fingerprint([
            leadText,
            leadEvidence.map(\.uuidString).sorted().joined(separator: ","),
        ])
        let story = CertifiedStory(
            id: "cover.story.lead.\(stableSuffix(leadSeed))",
            text: leadText,
            semanticKey: "story:lead:\(leadSeed)",
            evidenceItemIDs: leadEvidence
        )
        let support = makeSupport(source: source, leadText: leadText)
        let marks = makeMarks(
            source.payload,
            excluding: [leadText, support?.text].compactMap { $0 }
        )
        let sceneKeys = makeSceneKeys(source.payload)
        let safeMedia = try preparedSafeMedia(source.media)
        let privacyFilteredCount = max(0, source.media.count - safeMedia.count)
        let descriptors = safeMedia.map { media in
            MediaDescriptor(
                id: media.id,
                evidenceItemIDs: unique(media.evidenceItemIDs),
                orientation: orientation(for: media.image),
                eligibility: media.allowsHero
                    && (media.analysis?.isHeroEligible ?? !media.requiresAnalysisForHero)
                    ? .heroEligible
                    : .secondaryOnly,
                privacyRisk: .safe,
                caption: nil,
                analysis: media.analysis
            )
        }
        let recordedDayCount = source.payload.dailyCountTrend.filter { $0.1 > 0 }.count
        let timelineLabels = makeTimelineLabels(
            source.payload,
            evidenceItemIDs: unique(fallbackEvidence + leadEvidence)
        )
        let periodKey = source.payload.narrativeRewrite?.key.periodKey
            ?? "week:\(source.payload.periodText)"
        let fingerprint = CoverStableIdentity.fingerprint([
            String(source.sourceRevision),
            periodKey,
            story.id,
            story.text,
            support?.id ?? "none",
            support?.text ?? "none",
            marks.map { "\($0.id):\($0.text)" }.joined(separator: "|"),
            timelineLabels.map { "\($0.id):\($0.text)" }.joined(separator: "|"),
            sceneKeys.joined(separator: "|"),
            String(source.payload.recordCount),
            String(recordedDayCount),
            safeMedia.map { $0.id.uuidString }.joined(separator: "|"),
            safeMedia.map { $0.analysis?.stableSignature ?? "analysis-unavailable" }
                .joined(separator: "|"),
            "cover-media-analysis-v\(CoverMediaAnalysisRules.currentVersion)",
        ])
        let factPack = CoverFactPack(
            schemaVersion: CoverContractSchema.currentVersion,
            sourceRevision: source.sourceRevision,
            periodKey: periodKey,
            periodLabel: source.payload.periodText,
            story: story,
            support: support,
            marks: marks,
            footerFacts: FooterFacts(
                brandText: "叙账",
                dateText: source.payload.periodText,
                recordCount: source.payload.recordCount,
                recordedDayCount: max(source.payload.recordCount > 0 ? 1 : 0, recordedDayCount),
                photoCount: safeMedia.count,
                verifiedQRCodeURL: nil
            ),
            media: descriptors,
            context: SafeCoverContext(
                locationLabels: [],
                timelineLabels: timelineLabels,
                sceneKeys: sceneKeys
            ),
            privacy: CoverPrivacyPolicy(
                blockedMediaIDs: [],
                allowsLocationText: false,
                allowsVerifiedQRCode: false
            ),
            contentFingerprint: fingerprint
        )
        let hasEvidenceBoundHero = descriptors.contains { descriptor in
            descriptor.eligibility == .heroEligible
                && !Set(descriptor.evidenceItemIDs).isDisjoint(with: Set(story.evidenceItemIDs))
        }
        return AssembledContext(
            story: story,
            support: support,
            safeMedia: safeMedia,
            descriptors: descriptors,
            recordedDayCount: recordedDayCount,
            factPack: factPack,
            hasEvidenceBoundHero: hasEvidenceBoundHero,
            privacyFilteredCount: privacyFilteredCount
        )
    }

    private static func directorInput(
        from context: AssembledContext,
        source: LegacyWeeklyCoverSource
    ) throws -> LegacyWeeklyCoverDirectorInput {
        let selectionInput = LaunchCoverTemplateSelectionInput(
            preferredTemplateID: nil,
            availablePhotoCount: context.descriptors.count,
            hasEvidenceBoundHero: context.hasEvidenceBoundHero,
            evidenceBoundHeroOrientations: evidenceBoundHeroOrientations(
                context.descriptors,
                leadEvidenceItemIDs: context.story.evidenceItemIDs
            ),
            recordedDayCount: context.recordedDayCount,
            leadCharacterCount: context.story.text.count,
            sceneKeys: Set(context.factPack.context.sceneKeys)
        )
        let localTemplateID = LaunchCoverTemplateCatalog.selectTemplateID(for: selectionInput)
        let request = try CoverAIDirectorRequestFactory.make(
            factPack: context.factPack,
            eligibleTemplateIDs: LaunchCoverTemplateCatalog.availableTemplateIDs(for: selectionInput),
            localTemplateID: localTemplateID,
            localPaletteID: source.paletteID,
            localBackgroundFamily: source.backgroundFamily
        )
        return LegacyWeeklyCoverDirectorInput(
            request: request,
            mediaIDByAlias: CoverAIDirectorRequestFactory.mediaIDMap(
                factPack: context.factPack,
                request: request
            )
        )
    }

    private static func mediaRecipes(
        for templateID: CoverTemplateID,
        selections: [CoverAIDirectorMediaSelection]
    ) -> [MediaPlacementRecipe] {
        selections.enumerated().map { index, selection in
            return MediaPlacementRecipe(
                mediaID: selection.mediaID,
                role: selection.role,
                slotID: "launch.\(templateID.rawValue).\(selection.role.rawValue).\(index)",
                cropMode: LaunchCoverTemplateCatalog.cropMode(
                    for: templateID,
                    role: selection.role
                ),
                treatment: LaunchCoverTemplateCatalog.treatment(
                    for: templateID,
                    role: selection.role
                )
            )
        }
    }

    private static func makeSupport(
        source: LegacyWeeklyCoverSource,
        leadText: String
    ) -> CertifiedStory? {
        guard let signal = source.payload.narrativePlan?.signalsByRole[.support]?.first(where: isCertifiedSignal),
              let text = firstNonempty([
                source.payload.narrativeRewrite?.supportingLine,
                source.payload.narrativePlan?.supportingLine,
              ]),
              CoverContractValidator.normalizedVisibleText(text)
                != CoverContractValidator.normalizedVisibleText(leadText) else {
            return nil
        }
        return CertifiedStory(
            id: "cover.story.support.\(stableSuffix(signal.id))",
            text: text,
            semanticKey: "story:support:\(signal.id)",
            evidenceItemIDs: unique(signal.evidenceItemIDs)
        )
    }

    private static func makeMarks(
        _ payload: WeeklyShareCardPayload,
        excluding textValues: [String]
    ) -> [CertifiedLabel] {
        var normalized = Set(textValues.map(CoverContractValidator.normalizedVisibleText))
        var seenSignalIDs: Set<String> = []
        return (payload.narrativePlan?.signalsByRole[.mark] ?? [])
            .filter(isCertifiedSignal)
            .compactMap { signal -> CertifiedLabel? in
                let candidates: [String?] = [signal.label, signal.fact]
                let text = firstNonempty(candidates) ?? ""
                let normalizedText = CoverContractValidator.normalizedVisibleText(text)
                guard !normalizedText.isEmpty,
                      normalized.insert(normalizedText).inserted,
                      seenSignalIDs.insert(signal.id).inserted else {
                    return nil
                }
                return CertifiedLabel(
                    id: "cover.mark.\(stableSuffix(signal.id))",
                    kind: .lifeMark,
                    text: text,
                    semanticKey: "mark:\(signal.id)",
                    evidenceItemIDs: unique(signal.evidenceItemIDs)
                )
            }
            .prefix(2)
            .map { $0 }
    }

    private static func makeTimelineLabels(
        _ payload: WeeklyShareCardPayload,
        evidenceItemIDs: [UUID]
    ) -> [CertifiedLabel] {
        guard !evidenceItemIDs.isEmpty else { return [] }
        return payload.dailyCountTrend.enumerated().compactMap { index, entry in
            guard entry.1 > 0 else { return nil }
            let rawLabel = entry.0.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawLabel.isEmpty else { return nil }
            let text = rawLabel.hasPrefix("周") ? rawLabel : "周\(rawLabel)"
            let seed = "\(payload.periodText)|\(index)|\(text)"
            return CertifiedLabel(
                id: "cover.timeline.\(stableSuffix(seed))",
                kind: .timeline,
                text: text,
                semanticKey: "timeline:\(stableSuffix(seed))",
                evidenceItemIDs: evidenceItemIDs
            )
        }
        .prefix(4)
        .map { $0 }
    }

    private static func makeSceneKeys(
        _ payload: WeeklyShareCardPayload
    ) -> [String] {
        let signals = payload.narrativePlan?.signalsByRole.values.flatMap { $0 } ?? []
        return Array(Set(signals.compactMap { signal -> String? in
            guard signal.kind == .structuredScene,
                  isCertifiedSignal(signal),
                  signal.id.hasPrefix("scene:") else {
                return nil
            }
            return signal.id
        }))
        .sorted()
        .prefix(6)
        .map { $0 }
    }

    private static func evidenceBoundHeroOrientations(
        _ descriptors: [MediaDescriptor],
        leadEvidenceItemIDs: [UUID]
    ) -> Set<MediaOrientation> {
        let leadEvidence = Set(leadEvidenceItemIDs)
        return Set(descriptors.compactMap { descriptor in
            guard descriptor.eligibility == .heroEligible,
                  !Set(descriptor.evidenceItemIDs).isDisjoint(with: leadEvidence) else {
                return nil
            }
            return descriptor.orientation
        })
    }

    private static func preparedSafeMedia(
        _ media: [LegacyWeeklyCoverMedia]
    ) throws -> [LegacyWeeklyCoverMedia] {
        var seen: Set<UUID> = []
        var safe: [LegacyWeeklyCoverMedia] = []
        for item in media {
            guard seen.insert(item.id).inserted else {
                throw LegacyWeeklyCoverAdapterError(
                    code: .duplicateMedia,
                    relatedIDs: [item.id.uuidString]
                )
            }
            guard item.image.size.width > 0, item.image.size.height > 0 else {
                throw LegacyWeeklyCoverAdapterError(
                    code: .invalidPreparedImage,
                    relatedIDs: [item.id.uuidString]
                )
            }
            guard item.privacyRisk == .safe, !item.evidenceItemIDs.isEmpty else { continue }
            safe.append(item)
        }
        return safe
    }

    private static func orientation(for image: UIImage) -> MediaOrientation {
        let width = image.size.width
        let height = image.size.height
        if abs(width - height) <= max(width, height) * 0.08 { return .square }
        return height > width ? .portrait : .landscape
    }

    private static func isCertifiedSignal(_ signal: LifeNarrativeSignal) -> Bool {
        !signal.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !signal.isSensitive
            && !signal.isAdministrative
            && !signal.evidenceItemIDs.isEmpty
    }

    private static func firstNonempty(_ values: [String?]) -> String? {
        values.compactMap { value in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }.first
    }

    private static func stableSuffix(_ value: String) -> String {
        CoverStableIdentity.fingerprint([value])
    }

    private static func unique(_ values: [UUID]) -> [UUID] {
        var seen: Set<UUID> = []
        return values.filter { seen.insert($0).inserted }
    }
}
