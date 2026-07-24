import Foundation

enum CoverContractViolationCode: String, Codable, Hashable, Sendable {
    case unsupportedSchemaVersion
    case emptyRequiredValue
    case negativeCount
    case evidenceMissing
    case tooManyMarks
    case duplicateAtomID
    case duplicateSemanticKey
    case duplicateVisibleText
    case unknownAtomID
    case duplicateAtomConsumption
    case roleNotAllowedInRegion
    case missingStoryLead
    case consumedSetMismatch
    case brandCountMismatch
    case brandOutsideFooter
    case footerMetricOutsideFooter
    case footerMetricSetMismatch
    case qrCodeOutsideFooter
    case qrCodeNotAllowed
    case qrCodeNotVerified
    case locationTextNotAllowed
    case duplicateMediaID
    case blockedMedia
    case ineligibleMedia
    case unknownMedia
    case duplicateMediaPlacement
    case duplicateMediaSlot
    case multipleHeroMedia
    case mediaRoleNotAllowed
    case mediaEvidenceMismatch
    case recipeIdentityMismatch
    case recipeContentMismatch
    case footerRecipeMismatch
    case invalidConfidence
    case photoCountMismatch
}

struct CoverContractViolation: Codable, Equatable, Sendable {
    let code: CoverContractViolationCode
    let path: String
    let relatedIDs: [String]
}

struct CoverContractValidationError: Error, Equatable, Sendable {
    let violations: [CoverContractViolation]
}

struct CoverContractValidationResult: Equatable, Sendable {
    let violations: [CoverContractViolation]

    var isValid: Bool { violations.isEmpty }
}

enum ContentAllocationEngine {
    private struct RequestedPlacement {
        let region: CoverContentRegion
        let atomID: String
    }

    static func allocate(
        atoms: [CoverContentAtom],
        request: CoverContentAllocationRequest,
        privacyPolicy: CoverPrivacyPolicy
    ) throws -> ContentAllocationPlan {
        var violations = CoverContractValidator.validateAtomCatalog(atoms)
        var atomsByID: [String: CoverContentAtom] = [:]
        for atom in atoms where atomsByID[atom.id] == nil {
            atomsByID[atom.id] = atom
        }

        var requested = request.mastheadAtomIDs.map { RequestedPlacement(region: .masthead, atomID: $0) }
        requested.append(RequestedPlacement(region: .storyLead, atomID: request.storyLeadAtomID))
        if let supportID = request.storySupportAtomID {
            requested.append(RequestedPlacement(region: .storySupport, atomID: supportID))
        }
        requested.append(contentsOf: request.mediaCaptionAtomIDs.values.map {
            RequestedPlacement(region: .mediaCaption, atomID: $0)
        })
        requested.append(contentsOf: request.markAtomIDs.map {
            RequestedPlacement(region: .marks, atomID: $0)
        })
        requested.append(contentsOf: request.timelineAtomIDs.map {
            RequestedPlacement(region: .timeline, atomID: $0)
        })
        requested.append(contentsOf: request.footerAtomIDs.map {
            RequestedPlacement(region: .footer, atomID: $0)
        })

        var firstRegionByAtomID: [String: CoverContentRegion] = [:]
        var firstAtomIDBySemanticKey: [String: String] = [:]
        var firstAtomIDByNormalizedText: [String: String] = [:]

        for placement in requested {
            guard let atom = atomsByID[placement.atomID] else {
                violations.append(
                    CoverContractViolation(
                        code: .unknownAtomID,
                        path: placement.region.rawValue,
                        relatedIDs: [placement.atomID]
                    )
                )
                continue
            }

            if let firstRegion = firstRegionByAtomID[atom.id] {
                violations.append(
                    CoverContractViolation(
                        code: .duplicateAtomConsumption,
                        path: placement.region.rawValue,
                        relatedIDs: [atom.id, firstRegion.rawValue]
                    )
                )
            } else {
                firstRegionByAtomID[atom.id] = placement.region
            }

            if let firstAtomID = firstAtomIDBySemanticKey[atom.semanticKey], firstAtomID != atom.id {
                violations.append(
                    CoverContractViolation(
                        code: .duplicateSemanticKey,
                        path: placement.region.rawValue,
                        relatedIDs: [firstAtomID, atom.id, atom.semanticKey]
                    )
                )
            } else {
                firstAtomIDBySemanticKey[atom.semanticKey] = atom.id
            }

            let normalizedText = CoverContractValidator.normalizedVisibleText(atom.text)
            if !normalizedText.isEmpty,
               let firstAtomID = firstAtomIDByNormalizedText[normalizedText],
               firstAtomID != atom.id {
                violations.append(
                    CoverContractViolation(
                        code: .duplicateVisibleText,
                        path: placement.region.rawValue,
                        relatedIDs: [firstAtomID, atom.id]
                    )
                )
            } else if !normalizedText.isEmpty {
                firstAtomIDByNormalizedText[normalizedText] = atom.id
            }

            if !CoverContractValidator.isAllowed(atom.role, in: placement.region) {
                violations.append(
                    CoverContractViolation(
                        code: .roleNotAllowedInRegion,
                        path: placement.region.rawValue,
                        relatedIDs: [atom.id, atom.role.rawValue]
                    )
                )
            }

            if atom.role == .qrCode {
                violations.append(contentsOf: CoverContractValidator.qrCodeViolations(
                    atom: atom,
                    region: placement.region,
                    privacyPolicy: privacyPolicy
                ))
            }
        }

        if !violations.isEmpty {
            throw CoverContractValidationError(violations: violations)
        }

        guard let storyLead = atomsByID[request.storyLeadAtomID] else {
            throw CoverContractValidationError(violations: [
                CoverContractViolation(
                    code: .missingStoryLead,
                    path: CoverContentRegion.storyLead.rawValue,
                    relatedIDs: [request.storyLeadAtomID]
                ),
            ])
        }
        var mediaCaptions: [UUID: CoverContentAtom] = [:]
        for (mediaID, atomID) in request.mediaCaptionAtomIDs {
            if let atom = atomsByID[atomID] {
                mediaCaptions[mediaID] = atom
            }
        }

        let plan = ContentAllocationPlan(
            masthead: request.mastheadAtomIDs.compactMap { atomsByID[$0] },
            storyLead: storyLead,
            storySupport: request.storySupportAtomID.flatMap { atomsByID[$0] },
            mediaCaptions: mediaCaptions,
            marks: request.markAtomIDs.compactMap { atomsByID[$0] },
            timeline: request.timelineAtomIDs.compactMap { atomsByID[$0] },
            footer: request.footerAtomIDs.compactMap { atomsByID[$0] },
            consumedAtomIDs: Set(requested.map(\.atomID))
        )

        let planResult = CoverContractValidator.validateAllocation(
            plan,
            privacyPolicy: privacyPolicy
        )
        if !planResult.isValid {
            throw CoverContractValidationError(violations: planResult.violations)
        }
        return plan
    }
}

enum CoverContractValidator {
    static func validateFactPack(_ factPack: CoverFactPack) -> CoverContractValidationResult {
        var violations: [CoverContractViolation] = []

        if factPack.schemaVersion != CoverContractSchema.currentVersion {
            violations.append(violation(.unsupportedSchemaVersion, "factPack.schemaVersion"))
        }
        if factPack.sourceRevision < 0 {
            violations.append(violation(.negativeCount, "factPack.sourceRevision"))
        }
        for (path, value) in [
            ("factPack.periodKey", factPack.periodKey),
            ("factPack.periodLabel", factPack.periodLabel),
            ("factPack.contentFingerprint", factPack.contentFingerprint),
            ("factPack.story.id", factPack.story.id),
            ("factPack.story.text", factPack.story.text),
            ("factPack.story.semanticKey", factPack.story.semanticKey),
            ("factPack.footerFacts.brandText", factPack.footerFacts.brandText),
        ] where trimmed(value).isEmpty {
            violations.append(violation(.emptyRequiredValue, path))
        }
        if factPack.story.evidenceItemIDs.isEmpty {
            violations.append(violation(.evidenceMissing, "factPack.story.evidenceItemIDs"))
        }
        if let support = factPack.support {
            if trimmed(support.id).isEmpty || trimmed(support.text).isEmpty || trimmed(support.semanticKey).isEmpty {
                violations.append(violation(.emptyRequiredValue, "factPack.support"))
            }
            if support.evidenceItemIDs.isEmpty {
                violations.append(violation(.evidenceMissing, "factPack.support.evidenceItemIDs"))
            }
        }
        if factPack.marks.count > 2 {
            violations.append(violation(.tooManyMarks, "factPack.marks"))
        }
        let certifiedLabels = factPack.marks
            + factPack.context.locationLabels
            + factPack.context.timelineLabels
            + factPack.media.compactMap(\.caption)
        for label in certifiedLabels {
            if trimmed(label.id).isEmpty || trimmed(label.text).isEmpty || trimmed(label.semanticKey).isEmpty {
                violations.append(violation(.emptyRequiredValue, "factPack.labels", [label.id]))
            }
            if label.evidenceItemIDs.isEmpty {
                violations.append(violation(.evidenceMissing, "factPack.labels", [label.id]))
            }
        }

        let counts = [
            factPack.footerFacts.recordCount,
            factPack.footerFacts.recordedDayCount,
            factPack.footerFacts.photoCount,
        ]
        if counts.contains(where: { $0 < 0 }) {
            violations.append(violation(.negativeCount, "factPack.footerFacts"))
        }
        if factPack.media.count > factPack.footerFacts.photoCount {
            violations.append(violation(.photoCountMismatch, "factPack.footerFacts.photoCount"))
        }

        var seenMediaIDs: Set<UUID> = []
        for descriptor in factPack.media {
            if !seenMediaIDs.insert(descriptor.id).inserted {
                violations.append(violation(.duplicateMediaID, "factPack.media", [descriptor.id.uuidString]))
            }
            if factPack.privacy.blockedMediaIDs.contains(descriptor.id) {
                violations.append(violation(.blockedMedia, "factPack.media", [descriptor.id.uuidString]))
            }
            if descriptor.eligibility == .excluded || descriptor.privacyRisk != .safe {
                violations.append(violation(.ineligibleMedia, "factPack.media", [descriptor.id.uuidString]))
            }
            if descriptor.evidenceItemIDs.isEmpty {
                violations.append(violation(.evidenceMissing, "factPack.media", [descriptor.id.uuidString]))
            }
        }

        if !factPack.privacy.allowsLocationText, !factPack.context.locationLabels.isEmpty {
            violations.append(violation(.locationTextNotAllowed, "factPack.context.locationLabels"))
        }
        if let qrCodeURL = factPack.footerFacts.verifiedQRCodeURL {
            let qrAtom = CoverContentAtom(
                id: CoverFactAtomID.qrCode,
                role: .qrCode,
                text: qrCodeURL,
                evidenceItemIDs: [],
                semanticKey: "qr-code:verified-destination",
                priority: 20
            )
            violations.append(contentsOf: qrCodeViolations(
                atom: qrAtom,
                region: .footer,
                privacyPolicy: factPack.privacy
            ))
        }

        violations.append(contentsOf: validateAtomCatalog(factPack.contentAtoms()))
        return CoverContractValidationResult(violations: violations.deduplicated)
    }

    static func validateAllocation(
        _ plan: ContentAllocationPlan,
        privacyPolicy: CoverPrivacyPolicy
    ) -> CoverContractValidationResult {
        var violations: [CoverContractViolation] = []
        let placements = plan.visiblePlacements
        let visibleIDs = placements.map { $0.atom.id }

        if Set(visibleIDs) != plan.consumedAtomIDs || visibleIDs.count != plan.consumedAtomIDs.count {
            violations.append(violation(.consumedSetMismatch, "allocation.consumedAtomIDs", visibleIDs))
        }

        var seenIDs: Set<String> = []
        var semanticKeyToAtomID: [String: String] = [:]
        var textToAtomID: [String: String] = [:]
        for placement in placements {
            let atom = placement.atom
            if !seenIDs.insert(atom.id).inserted {
                violations.append(violation(.duplicateAtomConsumption, placement.region.rawValue, [atom.id]))
            }
            if let firstID = semanticKeyToAtomID[atom.semanticKey], firstID != atom.id {
                violations.append(violation(.duplicateSemanticKey, placement.region.rawValue, [firstID, atom.id]))
            } else {
                semanticKeyToAtomID[atom.semanticKey] = atom.id
            }
            let normalized = normalizedVisibleText(atom.text)
            if !normalized.isEmpty, let firstID = textToAtomID[normalized], firstID != atom.id {
                violations.append(violation(.duplicateVisibleText, placement.region.rawValue, [firstID, atom.id]))
            } else if !normalized.isEmpty {
                textToAtomID[normalized] = atom.id
            }
            if !isAllowed(atom.role, in: placement.region) {
                violations.append(violation(.roleNotAllowedInRegion, placement.region.rawValue, [atom.id]))
            }
            if atom.role == .brand, placement.region != .footer {
                violations.append(violation(.brandOutsideFooter, placement.region.rawValue, [atom.id]))
            }
            if atom.role == .footerMetric, placement.region != .footer {
                violations.append(violation(.footerMetricOutsideFooter, placement.region.rawValue, [atom.id]))
            }
            if atom.role == .qrCode {
                violations.append(contentsOf: qrCodeViolations(
                    atom: atom,
                    region: placement.region,
                    privacyPolicy: privacyPolicy
                ))
            }
        }

        let brandAtoms = placements.filter { $0.atom.role == .brand }
        if brandAtoms.count != 1 || brandAtoms.first?.region != .footer {
            violations.append(violation(
                .brandCountMismatch,
                "allocation.footer",
                brandAtoms.map { $0.atom.id }
            ))
        }
        let expectedMetricIDs: Set<String> = [
            CoverFactAtomID.recordCount,
            CoverFactAtomID.recordedDayCount,
            CoverFactAtomID.photoCount,
        ]
        let footerMetricIDs = Set(
            plan.footer.filter { $0.role == .footerMetric }.map(\.id)
        )
        if footerMetricIDs != expectedMetricIDs {
            violations.append(violation(
                .footerMetricSetMismatch,
                "allocation.footer",
                Array(footerMetricIDs).sorted()
            ))
        }
        if plan.storyLead.role != .storyLead {
            violations.append(violation(.missingStoryLead, "allocation.storyLead", [plan.storyLead.id]))
        }

        return CoverContractValidationResult(violations: violations.deduplicated)
    }

    static func validateRecipe(
        _ recipe: CoverRecipe,
        factPack: CoverFactPack,
        allocation: ContentAllocationPlan
    ) -> CoverContractValidationResult {
        var violations = validateFactPack(factPack).violations
        violations.append(contentsOf: validateAllocation(
            allocation,
            privacyPolicy: factPack.privacy
        ).violations)

        if recipe.schemaVersion != CoverContractSchema.currentVersion {
            violations.append(violation(.unsupportedSchemaVersion, "recipe.schemaVersion"))
        }
        if trimmed(recipe.recipeID).isEmpty || trimmed(recipe.template.variantID).isEmpty {
            violations.append(violation(.emptyRequiredValue, "recipe.identity"))
        }
        if recipe.sourceRevision != factPack.sourceRevision
            || recipe.periodKey != factPack.periodKey
            || recipe.contentFingerprint != factPack.contentFingerprint {
            violations.append(violation(.recipeIdentityMismatch, "recipe.sourceIdentity"))
        }
        if !(0...1).contains(recipe.confidence) || !recipe.confidence.isFinite {
            violations.append(violation(.invalidConfidence, "recipe.confidence"))
        }

        if recipe.content.leadAtomID != allocation.storyLead.id
            || recipe.content.supportAtomID != allocation.storySupport?.id
            || recipe.content.markAtomIDs != allocation.marks.map(\.id)
            || recipe.content.timelineAtomIDs != allocation.timeline.map(\.id) {
            violations.append(violation(.recipeContentMismatch, "recipe.content"))
        }

        let allocationFooterIDs = allocation.footer.map(\.id)
        let hasQRCode = allocation.footer.contains { $0.role == .qrCode }
        if recipe.footer.atomIDs != allocationFooterIDs
            || recipe.footer.showsVerifiedQRCode != hasQRCode {
            violations.append(violation(.footerRecipeMismatch, "recipe.footer", recipe.footer.atomIDs))
        }

        var mediaByID: [UUID: MediaDescriptor] = [:]
        for descriptor in factPack.media where mediaByID[descriptor.id] == nil {
            mediaByID[descriptor.id] = descriptor
        }
        for (mediaID, captionAtom) in allocation.mediaCaptions {
            guard let descriptor = mediaByID[mediaID] else {
                violations.append(violation(.unknownMedia, "allocation.mediaCaptions", [mediaID.uuidString]))
                continue
            }
            let descriptorEvidence = Set(descriptor.evidenceItemIDs)
            let captionEvidence = Set(captionAtom.evidenceItemIDs)
            if descriptor.caption?.id != captionAtom.id
                || descriptorEvidence.isDisjoint(with: captionEvidence) {
                violations.append(violation(
                    .mediaEvidenceMismatch,
                    "allocation.mediaCaptions",
                    [mediaID.uuidString, captionAtom.id]
                ))
            }
        }
        var seenMediaIDs: Set<UUID> = []
        var seenSlotIDs: Set<String> = []
        var heroCount = 0
        for placement in recipe.media {
            if !seenMediaIDs.insert(placement.mediaID).inserted {
                violations.append(violation(.duplicateMediaPlacement, "recipe.media", [placement.mediaID.uuidString]))
            }
            if trimmed(placement.slotID).isEmpty {
                violations.append(violation(.emptyRequiredValue, "recipe.media.slotID", [placement.mediaID.uuidString]))
            } else if !seenSlotIDs.insert(placement.slotID).inserted {
                violations.append(violation(.duplicateMediaSlot, "recipe.media.slotID", [placement.slotID]))
            }
            guard let descriptor = mediaByID[placement.mediaID] else {
                violations.append(violation(.unknownMedia, "recipe.media", [placement.mediaID.uuidString]))
                continue
            }
            if factPack.privacy.blockedMediaIDs.contains(placement.mediaID)
                || descriptor.privacyRisk != .safe
                || descriptor.eligibility == .excluded {
                violations.append(violation(.blockedMedia, "recipe.media", [placement.mediaID.uuidString]))
            }
            if placement.role == .hero {
                heroCount += 1
                if descriptor.eligibility != .heroEligible {
                    violations.append(violation(.mediaRoleNotAllowed, "recipe.media.hero", [placement.mediaID.uuidString]))
                }
                let mediaEvidence = Set(descriptor.evidenceItemIDs)
                let leadEvidence = Set(allocation.storyLead.evidenceItemIDs)
                if mediaEvidence.isDisjoint(with: leadEvidence) {
                    violations.append(violation(
                        .mediaEvidenceMismatch,
                        "recipe.media.hero",
                        [placement.mediaID.uuidString, allocation.storyLead.id]
                    ))
                }
            }
        }
        if heroCount > 1 {
            violations.append(violation(.multipleHeroMedia, "recipe.media"))
        }

        return CoverContractValidationResult(violations: violations.deduplicated)
    }

    static func validateAtomCatalog(_ atoms: [CoverContentAtom]) -> [CoverContractViolation] {
        var violations: [CoverContractViolation] = []
        var seenIDs: Set<String> = []
        for atom in atoms {
            if trimmed(atom.id).isEmpty || trimmed(atom.semanticKey).isEmpty || trimmed(atom.text).isEmpty {
                violations.append(violation(.emptyRequiredValue, "atoms", [atom.id]))
            }
            if !seenIDs.insert(atom.id).inserted {
                violations.append(violation(.duplicateAtomID, "atoms", [atom.id]))
            }
        }
        return violations
    }

    static func normalizedVisibleText(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping
            .lowercased()
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }

    static func isAllowed(
        _ role: CoverContentAtom.Role,
        in region: CoverContentRegion
    ) -> Bool {
        switch role {
        case .period:
            return region == .masthead || region == .footer
        case .masthead:
            return region == .masthead
        case .storyLead:
            return region == .storyLead
        case .storySupport:
            return region == .storySupport
        case .photoCaption:
            return region == .mediaCaption
        case .lifeMark:
            return region == .marks
        case .timeline:
            return region == .timeline
        case .footerMetric, .brand, .qrCode:
            return region == .footer
        }
    }

    static func qrCodeViolations(
        atom: CoverContentAtom,
        region: CoverContentRegion,
        privacyPolicy: CoverPrivacyPolicy
    ) -> [CoverContractViolation] {
        var violations: [CoverContractViolation] = []
        if region != .footer {
            violations.append(violation(.qrCodeOutsideFooter, region.rawValue, [atom.id]))
        }
        if !privacyPolicy.allowsVerifiedQRCode {
            violations.append(violation(.qrCodeNotAllowed, region.rawValue, [atom.id]))
        }
        guard let components = URLComponents(string: trimmed(atom.text)),
              components.scheme?.lowercased() == "https",
              let host = components.host,
              !host.isEmpty else {
            violations.append(violation(.qrCodeNotVerified, region.rawValue, [atom.id]))
            return violations
        }
        return violations
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func violation(
        _ code: CoverContractViolationCode,
        _ path: String,
        _ relatedIDs: [String] = []
    ) -> CoverContractViolation {
        CoverContractViolation(code: code, path: path, relatedIDs: relatedIDs)
    }
}

private extension Array where Element == CoverContractViolation {
    var deduplicated: [CoverContractViolation] {
        var seen: Set<String> = []
        return filter { violation in
            let key = "\(violation.code.rawValue)|\(violation.path)|\(violation.relatedIDs.joined(separator: ","))"
            return seen.insert(key).inserted
        }
    }
}
