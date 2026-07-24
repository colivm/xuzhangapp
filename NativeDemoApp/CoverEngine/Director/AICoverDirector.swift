import Foundation

enum CoverAIDirectorRules {
    static let currentVersion = 1
    static let maximumTemplateCandidateCount = 5
    static let maximumMediaCandidateCount = 7
    static let maximumCachedDecisionCount = 24
    static let requestTimeoutNanoseconds: UInt64 = 8_000_000_000
    static let maximumSeed: UInt64 = 2_147_483_647
}

enum CoverAIDirectorQualityBand: String, Codable, Sendable {
    case strong
    case usable
    case limited
}

struct CoverAIDirectorFactSummary: Codable, Equatable, Sendable {
    let leadCharacterCount: Int
    let hasSupport: Bool
    let markCount: Int
    let timelineCount: Int
    let recordedDayCount: Int
    let availablePhotoCount: Int
}

struct CoverAIDirectorMediaCandidate: Codable, Equatable, Sendable {
    let alias: String
    let orientation: MediaOrientation
    let qualityBand: CoverAIDirectorQualityBand
    let isHeroEligible: Bool
    let isEvidenceBoundToLead: Bool
}

struct CoverAIDirectorTemplateCandidate: Codable, Equatable, Sendable {
    let templateID: CoverTemplateID
    let variantID: String
    let allowedPaletteIDs: [CoverPaletteID]
    let allowedBackgroundFamilies: [BackgroundFamily]
    let allowedAnimationProfiles: [CoverAnimationProfile]
    let minimumMediaCount: Int
    let maximumMediaCount: Int
    let requiresHero: Bool
    let allowsHero: Bool
    let allowsDecoration: Bool
}

struct CoverAIDirectorFallback: Codable, Equatable, Sendable {
    let templateID: CoverTemplateID
    let variantID: String
    let paletteID: CoverPaletteID
    let backgroundFamily: BackgroundFamily
    let animationProfile: CoverAnimationProfile
    let seed: UInt64
}

struct CoverAIDirectorRequest: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let sourceRevision: Int
    let periodKeyHash: String
    let contentFingerprint: String
    let facts: CoverAIDirectorFactSummary
    let templateCandidates: [CoverAIDirectorTemplateCandidate]
    let mediaCandidates: [CoverAIDirectorMediaCandidate]
    let fallback: CoverAIDirectorFallback

    var cacheKey: String {
        CoverStableIdentity.fingerprint([
            "cover-ai-director-v\(schemaVersion)",
            String(sourceRevision),
            periodKeyHash,
            contentFingerprint,
            [
                String(facts.leadCharacterCount),
                facts.hasSupport ? "support" : "no-support",
                String(facts.markCount),
                String(facts.timelineCount),
                String(facts.recordedDayCount),
                String(facts.availablePhotoCount),
            ].joined(separator: ":"),
            templateCandidates.map { candidate in
                [
                    candidate.templateID.rawValue,
                    candidate.variantID,
                    candidate.allowedPaletteIDs.map(\.rawValue).joined(separator: ","),
                    candidate.allowedBackgroundFamilies.map(\.rawValue).joined(separator: ","),
                    String(candidate.minimumMediaCount),
                    String(candidate.maximumMediaCount),
                ].joined(separator: ":")
            }.joined(separator: "|"),
            mediaCandidates.map { candidate in
                [
                    candidate.alias,
                    candidate.orientation.rawValue,
                    candidate.qualityBand.rawValue,
                    candidate.isHeroEligible ? "hero" : "secondary",
                    candidate.isEvidenceBoundToLead ? "bound" : "unbound",
                ].joined(separator: ":")
            }.joined(separator: "|"),
            [
                fallback.templateID.rawValue,
                fallback.variantID,
                fallback.paletteID.rawValue,
                fallback.backgroundFamily.rawValue,
                fallback.animationProfile.rawValue,
                String(fallback.seed),
            ].joined(separator: ":"),
        ])
    }
}

struct CoverAIDirectorMediaRoleResponse: Codable, Equatable, Sendable {
    let mediaAlias: String
    let role: MediaRole
}

struct CoverAIDirectorResponse: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let sourceRevision: Int
    let periodKeyHash: String
    let contentFingerprint: String
    let templateID: CoverTemplateID
    let variantID: String
    let paletteID: CoverPaletteID
    let backgroundFamily: BackgroundFamily
    let mediaRoles: [CoverAIDirectorMediaRoleResponse]
    let animationProfile: CoverAnimationProfile
    let seed: UInt64
    let confidence: Double
    let reasonCodes: [CoverDirectorReason]

    static func decodeStrict(from data: Data) throws -> CoverAIDirectorResponse {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(root.keys) == expectedKeys,
              let mediaRoles = root["mediaRoles"] as? [[String: Any]],
              mediaRoles.allSatisfy({ Set($0.keys) == mediaRoleKeys }) else {
            throw CoverAIDirectorError.invalidResponse
        }
        do {
            return try JSONDecoder().decode(CoverAIDirectorResponse.self, from: data)
        } catch {
            throw CoverAIDirectorError.invalidResponse
        }
    }

    private static let expectedKeys: Set<String> = [
        "schemaVersion",
        "sourceRevision",
        "periodKeyHash",
        "contentFingerprint",
        "templateID",
        "variantID",
        "paletteID",
        "backgroundFamily",
        "mediaRoles",
        "animationProfile",
        "seed",
        "confidence",
        "reasonCodes",
    ]
    private static let mediaRoleKeys: Set<String> = ["mediaAlias", "role"]
}

struct CoverAIDirectorMediaSelection: Equatable, Sendable {
    let mediaID: UUID
    let role: MediaRole
}

struct CoverAIDirectorDecision: Equatable, Sendable {
    let requestCacheKey: String
    let sourceRevision: Int
    let periodKeyHash: String
    let contentFingerprint: String
    let templateID: CoverTemplateID
    let variantID: String
    let paletteID: CoverPaletteID
    let backgroundFamily: BackgroundFamily
    let mediaSelections: [CoverAIDirectorMediaSelection]
    let animationProfile: CoverAnimationProfile
    let seed: UInt64
    let confidence: Double
    let reasonCodes: [CoverDirectorReason]
}

enum CoverAIDirectorError: Error, Equatable, Sendable {
    case invalidRequest
    case invalidResponse
    case timedOut
}

enum CoverAIDirectorRequestFactory {
    static func make(
        factPack: CoverFactPack,
        eligibleTemplateIDs: [CoverTemplateID],
        localTemplateID: CoverTemplateID,
        localPaletteID: CoverPaletteID,
        localBackgroundFamily: BackgroundFamily
    ) throws -> CoverAIDirectorRequest {
        guard CoverContractValidator.validateFactPack(factPack).isValid,
              (1...500).contains(factPack.story.text.count),
              factPack.media.count <= CoverAIDirectorRules.maximumMediaCandidateCount,
              factPack.context.timelineLabels.count <= 4,
              factPack.footerFacts.recordedDayCount <= 366 else {
            throw CoverAIDirectorError.invalidRequest
        }

        let leadEvidence = Set(factPack.story.evidenceItemIDs)
        let mediaPairs = factPack.media.enumerated().map { index, descriptor in
            (
                id: descriptor.id,
                candidate: CoverAIDirectorMediaCandidate(
                    alias: "M\(index + 1)",
                    orientation: descriptor.orientation,
                    qualityBand: qualityBand(for: descriptor.analysis),
                    isHeroEligible: descriptor.eligibility == .heroEligible,
                    isEvidenceBoundToLead: !Set(descriptor.evidenceItemIDs).isDisjoint(with: leadEvidence)
                )
            )
        }
        let candidateIDs = rankedCandidates(
            eligibleTemplateIDs,
            localTemplateID: localTemplateID
        )
        let templateCandidates = candidateIDs.compactMap { templateID -> CoverAIDirectorTemplateCandidate? in
            guard let descriptor = LaunchCoverTemplateCatalog.descriptor(for: templateID) else {
                return nil
            }
            let tokens = allowedTokens(for: templateID)
            return CoverAIDirectorTemplateCandidate(
                templateID: templateID,
                variantID: LaunchCoverTemplateCatalog.variantID(
                    for: templateID,
                    leadCharacterCount: factPack.story.text.count,
                    mediaCount: min(factPack.media.count, descriptor.maximumRenderedPhotoCount)
                ),
                allowedPaletteIDs: tokens.palettes,
                allowedBackgroundFamilies: tokens.backgrounds,
                allowedAnimationProfiles: [descriptor.animationProfile],
                minimumMediaCount: descriptor.supportedPhotoCounts.lowerBound,
                maximumMediaCount: descriptor.maximumRenderedPhotoCount,
                requiresHero: descriptor.requiresEvidenceBoundHero,
                allowsHero: descriptor.allowsHero,
                allowsDecoration: descriptor.allowsDecoration
            )
        }
        guard !templateCandidates.isEmpty,
              templateCandidates.count <= CoverAIDirectorRules.maximumTemplateCandidateCount,
              let fallbackCandidate = templateCandidates.first(where: {
                  $0.templateID == localTemplateID
              }) ?? templateCandidates.first,
              fallbackCandidate.allowedAnimationProfiles.count == 1 else {
            throw CoverAIDirectorError.invalidRequest
        }

        let fallbackPalette = fallbackCandidate.allowedPaletteIDs.contains(localPaletteID)
            ? localPaletteID
            : fallbackCandidate.allowedPaletteIDs[0]
        let fallbackBackground = fallbackCandidate.allowedBackgroundFamilies.contains(localBackgroundFamily)
            ? localBackgroundFamily
            : fallbackCandidate.allowedBackgroundFamilies[0]
        let periodKeyHash = redactedHash(
            CoverStableIdentity.fingerprint([factPack.periodKey])
        )
        let contentFingerprint = redactedHash(factPack.contentFingerprint)
        let seed = UInt64(factPack.contentFingerprint.prefix(8), radix: 16) ?? 0
        return CoverAIDirectorRequest(
            schemaVersion: CoverAIDirectorRules.currentVersion,
            sourceRevision: factPack.sourceRevision,
            periodKeyHash: periodKeyHash,
            contentFingerprint: contentFingerprint,
            facts: CoverAIDirectorFactSummary(
                leadCharacterCount: factPack.story.text.count,
                hasSupport: factPack.support != nil,
                markCount: factPack.marks.count,
                timelineCount: factPack.context.timelineLabels.count,
                recordedDayCount: factPack.footerFacts.recordedDayCount,
                availablePhotoCount: factPack.media.count
            ),
            templateCandidates: templateCandidates,
            mediaCandidates: mediaPairs.map(\.candidate),
            fallback: CoverAIDirectorFallback(
                templateID: fallbackCandidate.templateID,
                variantID: fallbackCandidate.variantID,
                paletteID: fallbackPalette,
                backgroundFamily: fallbackBackground,
                animationProfile: fallbackCandidate.allowedAnimationProfiles[0],
                seed: min(seed, CoverAIDirectorRules.maximumSeed)
            )
        )
    }

    static func mediaIDMap(
        factPack: CoverFactPack,
        request: CoverAIDirectorRequest
    ) -> [String: UUID] {
        guard factPack.media.count == request.mediaCandidates.count else { return [:] }
        return Dictionary(uniqueKeysWithValues: zip(
            request.mediaCandidates.map(\.alias),
            factPack.media.map(\.id)
        ))
    }

    private static func rankedCandidates(
        _ eligible: [CoverTemplateID],
        localTemplateID: CoverTemplateID
    ) -> [CoverTemplateID] {
        var seen: Set<CoverTemplateID> = []
        return ([localTemplateID] + eligible)
            .filter { LaunchCoverTemplateCatalog.orderedTemplateIDs.contains($0) }
            .filter { seen.insert($0).inserted }
            .prefix(CoverAIDirectorRules.maximumTemplateCandidateCount)
            .map { $0 }
    }

    private static func qualityBand(
        for analysis: CoverMediaAnalysis?
    ) -> CoverAIDirectorQualityBand {
        guard let analysis, analysis.isValid else { return .limited }
        switch analysis.qualityScore {
        case 0.72...:
            return .strong
        case 0.48...:
            return .usable
        default:
            return .limited
        }
    }

    private static func redactedHash(_ value: String) -> String {
        let normalized = value.lowercased()
        let prefix = String(normalized.prefix(8)).padding(toLength: 8, withPad: "0", startingAt: 0)
        let suffix = String(normalized.suffix(8)).padding(toLength: 8, withPad: "0", startingAt: 0)
        return "h\(prefix)x\(suffix)"
    }

    private static func allowedTokens(
        for templateID: CoverTemplateID
    ) -> (palettes: [CoverPaletteID], backgrounds: [BackgroundFamily]) {
        switch templateID {
        case .heroStory:
            return (
                [.creamMorning, .warmBeige, .fogGreen, .nightBlue],
                [.morningLight, .warmHome, .sunset, .nightWalk]
            )
        case .magazine:
            return (
                [.creamMorning, .paperGray, .nightBlue],
                [.editorial, .paperGray, .nightWalk]
            )
        case .memoryFocus:
            return (
                [.quietCream, .creamMorning, .fogGreen],
                [.quietEditorial, .morningLight, .minimal]
            )
        case .journal:
            return (
                [.warmBeige, .creamMorning, .paperGray],
                [.journal, .creamPaper, .coffeeTime]
            )
        case .film:
            return (
                [.nightBlue, .paperGray, .warmBeige],
                [.film, .nightWalk, .journal]
            )
        case .quote:
            return (
                [.quietCream, .fogGreen, .nightBlue],
                [.minimal, .quietEditorial, .morningLight]
            )
        case .timeline:
            return (
                [.paperGray, .warmBeige, .nightBlue],
                [.film, .journal, .nightWalk]
            )
        case .minimal:
            return (
                [.quietCream, .paperGray, .fogGreen],
                [.minimal, .quietEditorial, .creamPaper]
            )
        case .postcard:
            return (
                [.creamMorning, .warmBeige, .oceanBlue],
                [.postcard, .travelNote, .morningLight]
            )
        case .scrapbook:
            return (
                [.warmBeige, .creamMorning, .paperGray],
                [.journal, .creamPaper, .autumn]
            )
        case .editorial:
            return (
                [.paperGray, .creamMorning, .nightBlue],
                [.editorial, .paperGray, .quietEditorial]
            )
        case .memoryWall:
            return (
                [.quietCream, .warmBeige, .paperGray],
                [.quietEditorial, .creamPaper, .journal]
            )
        case .travelNote:
            return (
                [.warmBeige, .creamMorning, .oceanBlue],
                [.travelNote, .postcard, .journal]
            )
        case .bookCover:
            return (
                [.quietCream, .paperGray, .nightBlue],
                [.bookCover, .quietEditorial, .editorial]
            )
        case .natureDiary:
            return (
                [.fogGreen, .creamMorning, .warmBeige],
                [.nature, .forestDiary, .morningLight]
            )
        case .coffeeStory:
            return (
                [.coffeeBrown, .warmBeige, .creamMorning],
                [.coffeeTime, .warmHome, .creamPaper]
            )
        case .warmHome:
            return (
                [.warmBeige, .creamMorning, .coffeeBrown],
                [.warmHome, .sunset, .creamPaper]
            )
        case .nightStory:
            return (
                [.nightBlue, .paperGray, .oceanBlue],
                [.nightWalk, .film, .editorial]
            )
        case .ocean:
            return (
                [.oceanBlue, .fogGreen, .creamMorning],
                [.ocean, .morningLight, .quietEditorial]
            )
        case .quietEditorial:
            return (
                [.quietCream, .paperGray, .fogGreen],
                [.quietEditorial, .minimal, .creamPaper]
            )
        }
    }
}

enum CoverAIDirectorValidator {
    static func validate(
        _ response: CoverAIDirectorResponse,
        request: CoverAIDirectorRequest,
        mediaIDByAlias: [String: UUID]
    ) -> CoverAIDirectorDecision? {
        guard response.schemaVersion == CoverAIDirectorRules.currentVersion,
              response.sourceRevision == request.sourceRevision,
              response.periodKeyHash == request.periodKeyHash,
              response.contentFingerprint == request.contentFingerprint,
              response.seed <= CoverAIDirectorRules.maximumSeed,
              response.confidence.isFinite,
              (0...1).contains(response.confidence),
              let template = request.templateCandidates.first(where: {
                  $0.templateID == response.templateID
              }),
              response.variantID == template.variantID,
              template.allowedPaletteIDs.contains(response.paletteID),
              template.allowedBackgroundFamilies.contains(response.backgroundFamily),
              template.allowedAnimationProfiles.contains(response.animationProfile),
              !response.reasonCodes.isEmpty,
              Set(response.reasonCodes).count == response.reasonCodes.count,
              response.reasonCodes.allSatisfy(allowedReasonCodes.contains),
              response.mediaRoles.count >= template.minimumMediaCount,
              response.mediaRoles.count <= template.maximumMediaCount else {
            return nil
        }

        let candidatesByAlias = Dictionary(uniqueKeysWithValues: request.mediaCandidates.map {
            ($0.alias, $0)
        })
        var seenAliases: Set<String> = []
        var heroCount = 0
        var selections: [CoverAIDirectorMediaSelection] = []
        for selection in response.mediaRoles {
            guard seenAliases.insert(selection.mediaAlias).inserted,
                  let mediaCandidate = candidatesByAlias[selection.mediaAlias],
                  let mediaID = mediaIDByAlias[selection.mediaAlias] else {
                return nil
            }
            switch selection.role {
            case .hero:
                heroCount += 1
                guard template.allowsHero,
                      mediaCandidate.isHeroEligible,
                      mediaCandidate.isEvidenceBoundToLead,
                      template.templateID != .bookCover || mediaCandidate.orientation == .portrait else {
                    return nil
                }
            case .secondary:
                guard !template.allowsDecoration else { return nil }
            case .decoration:
                guard template.allowsDecoration else { return nil }
            }
            selections.append(CoverAIDirectorMediaSelection(mediaID: mediaID, role: selection.role))
        }
        guard heroCount <= 1,
              !template.requiresHero || heroCount == 1,
              template.allowsHero || heroCount == 0,
              reasonsMatchFacts(
                response.reasonCodes,
                request: request,
                heroCount: heroCount,
                selectedMediaCount: selections.count
              ) else {
            return nil
        }

        return CoverAIDirectorDecision(
            requestCacheKey: request.cacheKey,
            sourceRevision: response.sourceRevision,
            periodKeyHash: response.periodKeyHash,
            contentFingerprint: response.contentFingerprint,
            templateID: response.templateID,
            variantID: response.variantID,
            paletteID: response.paletteID,
            backgroundFamily: response.backgroundFamily,
            mediaSelections: selections,
            animationProfile: response.animationProfile,
            seed: response.seed,
            confidence: response.confidence,
            reasonCodes: response.reasonCodes
        )
    }

    static func isStillValid(
        _ decision: CoverAIDirectorDecision,
        request: CoverAIDirectorRequest,
        mediaIDByAlias: [String: UUID]
    ) -> Bool {
        let aliasByMediaID = Dictionary(uniqueKeysWithValues: mediaIDByAlias.map {
            ($0.value, $0.key)
        })
        guard aliasByMediaID.count == mediaIDByAlias.count else { return false }
        let responseRoles = decision.mediaSelections.compactMap { selection -> CoverAIDirectorMediaRoleResponse? in
            guard let alias = aliasByMediaID[selection.mediaID] else { return nil }
            return CoverAIDirectorMediaRoleResponse(mediaAlias: alias, role: selection.role)
        }
        guard responseRoles.count == decision.mediaSelections.count else { return false }
        let response = CoverAIDirectorResponse(
            schemaVersion: CoverAIDirectorRules.currentVersion,
            sourceRevision: decision.sourceRevision,
            periodKeyHash: decision.periodKeyHash,
            contentFingerprint: decision.contentFingerprint,
            templateID: decision.templateID,
            variantID: decision.variantID,
            paletteID: decision.paletteID,
            backgroundFamily: decision.backgroundFamily,
            mediaRoles: responseRoles,
            animationProfile: decision.animationProfile,
            seed: decision.seed,
            confidence: decision.confidence,
            reasonCodes: decision.reasonCodes
        )
        return decision.requestCacheKey == request.cacheKey
            && validate(response, request: request, mediaIDByAlias: mediaIDByAlias) == decision
    }

    private static let allowedReasonCodes: Set<CoverDirectorReason> = [
        .strongPhotoLead,
        .balancedPhotoSet,
        .shortStory,
        .strongSupport,
        .timelineEvidence,
        .noEligiblePhoto,
    ]

    private static func reasonsMatchFacts(
        _ reasons: [CoverDirectorReason],
        request: CoverAIDirectorRequest,
        heroCount: Int,
        selectedMediaCount: Int
    ) -> Bool {
        for reason in reasons {
            switch reason {
            case .strongPhotoLead where heroCount != 1:
                return false
            case .balancedPhotoSet where selectedMediaCount < 2:
                return false
            case .shortStory where request.facts.leadCharacterCount > 30:
                return false
            case .strongSupport where !request.facts.hasSupport:
                return false
            case .timelineEvidence where request.facts.timelineCount < 3:
                return false
            case .noEligiblePhoto where request.facts.availablePhotoCount != 0:
                return false
            default:
                break
            }
        }
        return true
    }
}

final class CoverAIDirectorDecisionStore: @unchecked Sendable {
    static let shared = CoverAIDirectorDecisionStore()

    private let lock = NSLock()
    private var decisions: [String: CoverAIDirectorDecision] = [:]
    private var recency: [String] = []

    private init() {}

    func decision(for request: CoverAIDirectorRequest) -> CoverAIDirectorDecision? {
        lock.lock()
        defer { lock.unlock() }
        return decisions[request.cacheKey]
    }

    func publish(_ decision: CoverAIDirectorDecision) {
        lock.lock()
        decisions[decision.requestCacheKey] = decision
        recency.removeAll { $0 == decision.requestCacheKey }
        recency.append(decision.requestCacheKey)
        while recency.count > CoverAIDirectorRules.maximumCachedDecisionCount {
            decisions.removeValue(forKey: recency.removeFirst())
        }
        lock.unlock()
    }

    func removeAll() {
        lock.lock()
        decisions.removeAll()
        recency.removeAll()
        lock.unlock()
    }

    var cachedDecisionCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return decisions.count
    }
}

actor CoverAIDirectorCoordinator {
    static let shared = CoverAIDirectorCoordinator()

    private let reportService = AIReportService()
    private var latestRequestID = UUID()
    private var activeRequestKey: String?
    private var inFlight: [String: (id: UUID, task: Task<CoverAIDirectorResponse, Error>)] = [:]

    func prepare(
        request: CoverAIDirectorRequest,
        mediaIDByAlias: [String: UUID],
        isEnabled: Bool,
        monthlyLimit: Int
    ) async -> CoverAIDirectorDecision? {
        guard isEnabled,
              !LocalStore.isReleaseFixtureMode,
              !KeychainService.loadAccessToken().isEmpty,
              AIUsageLimiter.canUseRemoteAI(limitPerMonth: monthlyLimit),
              !Task.isCancelled else {
            return nil
        }
        if let cached = CoverAIDirectorDecisionStore.shared.decision(for: request),
           CoverAIDirectorValidator.isStillValid(
                cached,
                request: request,
                mediaIDByAlias: mediaIDByAlias
           ) {
            return cached
        }

        let requestID: UUID
        if activeRequestKey == request.cacheKey {
            requestID = latestRequestID
        } else {
            inFlight.values.forEach { $0.task.cancel() }
            inFlight.removeAll()
            requestID = UUID()
            latestRequestID = requestID
            activeRequestKey = request.cacheKey
        }
        let entry: (id: UUID, task: Task<CoverAIDirectorResponse, Error>)
        if let existing = inFlight[request.cacheKey] {
            entry = existing
        } else {
            let entryID = UUID()
            let service = reportService
            let task = Task {
                try await Self.responseBeforeTimeout(service: service, request: request)
            }
            entry = (entryID, task)
            inFlight[request.cacheKey] = entry
        }
        do {
            let response = try await entry.task.value
            if inFlight[request.cacheKey]?.id == entry.id {
                inFlight.removeValue(forKey: request.cacheKey)
            }
            guard !Task.isCancelled, latestRequestID == requestID,
                  activeRequestKey == request.cacheKey,
                  let decision = CoverAIDirectorValidator.validate(
                    response,
                    request: request,
                    mediaIDByAlias: mediaIDByAlias
                  ) else {
                return nil
            }
            if let cached = CoverAIDirectorDecisionStore.shared.decision(for: request),
               CoverAIDirectorValidator.isStillValid(
                    cached,
                    request: request,
                    mediaIDByAlias: mediaIDByAlias
               ) {
                return cached
            }
            guard AIUsageLimiter.consumeOnce(limitPerMonth: monthlyLimit) else {
                return nil
            }
            CoverAIDirectorDecisionStore.shared.publish(decision)
            return decision
        } catch {
            if inFlight[request.cacheKey]?.id == entry.id {
                inFlight.removeValue(forKey: request.cacheKey)
            }
            return nil
        }
    }

    func cancelAndRejectPendingResult() {
        latestRequestID = UUID()
        activeRequestKey = nil
        inFlight.values.forEach { $0.task.cancel() }
        inFlight.removeAll()
    }

    private static func responseBeforeTimeout(
        service: AIReportService,
        request: CoverAIDirectorRequest
    ) async throws -> CoverAIDirectorResponse {
        return try await withThrowingTaskGroup(of: CoverAIDirectorResponse.self) { group in
            group.addTask {
                try await service.generateCoverDirectorDecision(request: request)
            }
            group.addTask {
                try await Task.sleep(
                    nanoseconds: CoverAIDirectorRules.requestTimeoutNanoseconds
                )
                throw CoverAIDirectorError.timedOut
            }
            guard let first = try await group.next() else {
                throw CoverAIDirectorError.invalidResponse
            }
            group.cancelAll()
            return first
        }
    }
}
