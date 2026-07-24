import Foundation

enum CoverContractSchema {
    static let currentVersion = 1
}

struct CertifiedStory: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let text: String
    let semanticKey: String
    let evidenceItemIDs: [UUID]
}

struct CertifiedLabel: Codable, Equatable, Sendable, Identifiable {
    enum Kind: String, Codable, Sendable {
        case lifeMark
        case location
        case timeline
        case photoCaption
    }

    let id: String
    let kind: Kind
    let text: String
    let semanticKey: String
    let evidenceItemIDs: [UUID]
}

struct FooterFacts: Codable, Equatable, Sendable {
    let brandText: String
    let dateText: String?
    let recordCount: Int
    let recordedDayCount: Int
    let photoCount: Int
    let verifiedQRCodeURL: String?
}

enum MediaOrientation: String, Codable, Sendable {
    case portrait
    case landscape
    case square
}

enum CoverMediaEligibility: String, Codable, Sendable {
    case heroEligible
    case secondaryOnly
    case excluded
}

enum CoverMediaPrivacyRisk: String, Codable, Sendable {
    case safe
    case sensitiveText
    case receiptOrScreenshot
    case identityRisk
    case restricted
}

struct MediaDescriptor: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let evidenceItemIDs: [UUID]
    let orientation: MediaOrientation
    let eligibility: CoverMediaEligibility
    let privacyRisk: CoverMediaPrivacyRisk
    let caption: CertifiedLabel?
    let analysis: CoverMediaAnalysis?

    init(
        id: UUID,
        evidenceItemIDs: [UUID],
        orientation: MediaOrientation,
        eligibility: CoverMediaEligibility,
        privacyRisk: CoverMediaPrivacyRisk,
        caption: CertifiedLabel?,
        analysis: CoverMediaAnalysis? = nil
    ) {
        self.id = id
        self.evidenceItemIDs = evidenceItemIDs
        self.orientation = orientation
        self.eligibility = eligibility
        self.privacyRisk = privacyRisk
        self.caption = caption
        self.analysis = analysis
    }
}

struct SafeCoverContext: Codable, Equatable, Sendable {
    let locationLabels: [CertifiedLabel]
    let timelineLabels: [CertifiedLabel]
    let sceneKeys: [String]
}

struct CoverPrivacyPolicy: Codable, Equatable, Sendable {
    let blockedMediaIDs: Set<UUID>
    let allowsLocationText: Bool
    let allowsVerifiedQRCode: Bool
}

struct CoverFactPack: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let sourceRevision: Int
    let periodKey: String
    let periodLabel: String
    let story: CertifiedStory
    let support: CertifiedStory?
    let marks: [CertifiedLabel]
    let footerFacts: FooterFacts
    let media: [MediaDescriptor]
    let context: SafeCoverContext
    let privacy: CoverPrivacyPolicy
    let contentFingerprint: String

    func contentAtoms() -> [CoverContentAtom] {
        var atoms: [CoverContentAtom] = [
            CoverContentAtom(
                id: CoverFactAtomID.period,
                role: .period,
                text: footerFacts.dateText ?? periodLabel,
                evidenceItemIDs: [],
                semanticKey: "period:\(periodKey)",
                priority: 90
            ),
            CoverContentAtom(
                id: story.id,
                role: .storyLead,
                text: story.text,
                evidenceItemIDs: story.evidenceItemIDs,
                semanticKey: story.semanticKey,
                priority: 100
            ),
        ]

        if let support {
            atoms.append(
                CoverContentAtom(
                    id: support.id,
                    role: .storySupport,
                    text: support.text,
                    evidenceItemIDs: support.evidenceItemIDs,
                    semanticKey: support.semanticKey,
                    priority: 80
                )
            )
        }

        atoms.append(contentsOf: marks.map { label in
            CoverContentAtom(
                id: label.id,
                role: .lifeMark,
                text: label.text,
                evidenceItemIDs: label.evidenceItemIDs,
                semanticKey: label.semanticKey,
                priority: 40
            )
        })

        atoms.append(contentsOf: context.locationLabels.map { label in
            CoverContentAtom(
                id: label.id,
                role: .lifeMark,
                text: label.text,
                evidenceItemIDs: label.evidenceItemIDs,
                semanticKey: label.semanticKey,
                priority: 45
            )
        })

        atoms.append(contentsOf: context.timelineLabels.map { label in
            CoverContentAtom(
                id: label.id,
                role: .timeline,
                text: label.text,
                evidenceItemIDs: label.evidenceItemIDs,
                semanticKey: label.semanticKey,
                priority: 50
            )
        })

        atoms.append(contentsOf: media.compactMap(\.caption).map { label in
            CoverContentAtom(
                id: label.id,
                role: .photoCaption,
                text: label.text,
                evidenceItemIDs: label.evidenceItemIDs,
                semanticKey: label.semanticKey,
                priority: 35
            )
        })

        atoms.append(
            CoverContentAtom(
                id: CoverFactAtomID.brand,
                role: .brand,
                text: footerFacts.brandText,
                evidenceItemIDs: [],
                semanticKey: "brand",
                priority: 100
            )
        )
        atoms.append(
            CoverContentAtom(
                id: CoverFactAtomID.recordCount,
                role: .footerMetric,
                text: "\(footerFacts.recordCount) 笔记录",
                evidenceItemIDs: [],
                semanticKey: "count:record",
                priority: 90
            )
        )
        atoms.append(
            CoverContentAtom(
                id: CoverFactAtomID.recordedDayCount,
                role: .footerMetric,
                text: "\(footerFacts.recordedDayCount) 个记录日",
                evidenceItemIDs: [],
                semanticKey: "count:record-day",
                priority: 90
            )
        )
        atoms.append(
            CoverContentAtom(
                id: CoverFactAtomID.photoCount,
                role: .footerMetric,
                text: "\(footerFacts.photoCount) 张照片",
                evidenceItemIDs: [],
                semanticKey: "count:photo",
                priority: 90
            )
        )

        if let verifiedQRCodeURL = footerFacts.verifiedQRCodeURL {
            atoms.append(
                CoverContentAtom(
                    id: CoverFactAtomID.qrCode,
                    role: .qrCode,
                    text: verifiedQRCodeURL,
                    evidenceItemIDs: [],
                    semanticKey: "qr-code:verified-destination",
                    priority: 20
                )
            )
        }

        return atoms
    }
}

enum CoverFactAtomID {
    static let period = "cover.period"
    static let brand = "cover.footer.brand"
    static let recordCount = "cover.footer.record-count"
    static let recordedDayCount = "cover.footer.recorded-day-count"
    static let photoCount = "cover.footer.photo-count"
    static let qrCode = "cover.footer.qr-code"
}

enum CoverContentRegion: String, Codable, Sendable {
    case masthead
    case storyLead
    case storySupport
    case mediaCaption
    case marks
    case timeline
    case footer
}

struct CoverContentAtom: Codable, Equatable, Sendable, Identifiable {
    enum Role: String, Codable, Sendable {
        case period
        case masthead
        case storyLead
        case storySupport
        case photoCaption
        case lifeMark
        case timeline
        case footerMetric
        case brand
        case qrCode
    }

    let id: String
    let role: Role
    let text: String
    let evidenceItemIDs: [UUID]
    let semanticKey: String
    let priority: Int
}

struct ContentAllocationPlan: Equatable, Sendable {
    let masthead: [CoverContentAtom]
    let storyLead: CoverContentAtom
    let storySupport: CoverContentAtom?
    let mediaCaptions: [UUID: CoverContentAtom]
    let marks: [CoverContentAtom]
    let timeline: [CoverContentAtom]
    let footer: [CoverContentAtom]
    let consumedAtomIDs: Set<String>

    var visibleAtoms: [CoverContentAtom] {
        var atoms = masthead
        atoms.append(storyLead)
        if let storySupport {
            atoms.append(storySupport)
        }
        for mediaID in mediaCaptions.keys.sorted(by: { $0.uuidString < $1.uuidString }) {
            if let caption = mediaCaptions[mediaID] {
                atoms.append(caption)
            }
        }
        atoms.append(contentsOf: marks)
        atoms.append(contentsOf: timeline)
        atoms.append(contentsOf: footer)
        return atoms
    }

    var visiblePlacements: [(region: CoverContentRegion, atom: CoverContentAtom)] {
        var placements = masthead.map { (CoverContentRegion.masthead, $0) }
        placements.append((.storyLead, storyLead))
        if let storySupport {
            placements.append((.storySupport, storySupport))
        }
        for mediaID in mediaCaptions.keys.sorted(by: { $0.uuidString < $1.uuidString }) {
            if let caption = mediaCaptions[mediaID] {
                placements.append((.mediaCaption, caption))
            }
        }
        placements.append(contentsOf: marks.map { (.marks, $0) })
        placements.append(contentsOf: timeline.map { (.timeline, $0) })
        placements.append(contentsOf: footer.map { (.footer, $0) })
        return placements
    }
}

struct CoverContentAllocationRequest: Equatable, Sendable {
    let mastheadAtomIDs: [String]
    let storyLeadAtomID: String
    let storySupportAtomID: String?
    let mediaCaptionAtomIDs: [UUID: String]
    let markAtomIDs: [String]
    let timelineAtomIDs: [String]
    let footerAtomIDs: [String]
}

enum CoverRecipeSource: String, Codable, Sendable {
    case local
    case ai
    case correctedAI
    case fallback
}

enum CoverTemplateID: String, Codable, CaseIterable, Sendable {
    case heroStory
    case magazine
    case memoryFocus
    case journal
    case film
    case minimal
    case quote
    case timeline
    case postcard
    case scrapbook
    case editorial
    case memoryWall
    case travelNote
    case bookCover
    case natureDiary
    case coffeeStory
    case warmHome
    case nightStory
    case ocean
    case quietEditorial
}

struct TemplateSelection: Codable, Equatable, Sendable {
    let templateID: CoverTemplateID
    let variantID: String
}

enum CoverPaletteID: String, Codable, CaseIterable, Sendable {
    case creamMorning
    case warmBeige
    case fogGreen
    case coffeeBrown
    case nightBlue
    case paperGray
    case oceanBlue
    case quietCream
}

struct CoverPaletteRecipe: Codable, Equatable, Sendable {
    let paletteID: CoverPaletteID
}

enum BackgroundFamily: String, Codable, CaseIterable, Sendable {
    case morningLight
    case warmHome
    case creamPaper
    case coffeeTime
    case forestDiary
    case travelNote
    case nightWalk
    case film
    case journal
    case editorial
    case nature
    case bookCover
    case ocean
    case autumn
    case minimal
    case postcard
    case quietEditorial
    case softUtility
    case sunset
    case paperGray
}

struct BackgroundRecipe: Codable, Equatable, Sendable {
    let family: BackgroundFamily
    let seed: UInt64
}

enum TypographyFamily: String, Codable, CaseIterable, Sendable {
    case songEditorial
    case sansEditorial
    case journal
    case film
}

struct TypographyRecipe: Codable, Equatable, Sendable {
    let family: TypographyFamily
}

struct ContentRecipe: Codable, Equatable, Sendable {
    let leadAtomID: String
    let supportAtomID: String?
    let markAtomIDs: [String]
    let timelineAtomIDs: [String]
}

enum MediaRole: String, Codable, Sendable {
    case hero
    case secondary
    case decoration
}

enum CropMode: String, Codable, Sendable {
    case fill
    case fit
    case cropSafeFill
}

enum MediaTreatment: String, Codable, Sendable {
    case clean
    case paper
    case film
    case polaroid
}

struct MediaPlacementRecipe: Codable, Equatable, Sendable {
    let mediaID: UUID
    let role: MediaRole
    let slotID: String
    let cropMode: CropMode
    let treatment: MediaTreatment
}

enum FooterStyle: String, Codable, Sendable {
    case quiet
    case lightOnDark
}

struct FooterRecipe: Codable, Equatable, Sendable {
    let style: FooterStyle
    let atomIDs: [String]
    let showsVerifiedQRCode: Bool
}

enum CoverAnimationProfile: String, Codable, CaseIterable, Sendable {
    case gentleEditorial
    case paperReveal
    case sequentialDevelop
    case quietFade
}

struct CoverAnimationRecipe: Codable, Equatable, Sendable {
    let profile: CoverAnimationProfile
}

enum CoverDirectorReason: String, Codable, CaseIterable, Sendable {
    case strongPhotoLead
    case balancedPhotoSet
    case shortStory
    case strongSupport
    case timelineEvidence
    case locationEvidence
    case noEligiblePhoto
    case privacyFallback
    case deterministicFallback
    case diversityPreference
}

struct CoverRecipe: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let recipeID: String
    let source: CoverRecipeSource
    let sourceRevision: Int
    let periodKey: String
    let contentFingerprint: String
    let template: TemplateSelection
    let palette: CoverPaletteRecipe
    let background: BackgroundRecipe
    let typography: TypographyRecipe
    let content: ContentRecipe
    let media: [MediaPlacementRecipe]
    let footer: FooterRecipe
    let animation: CoverAnimationRecipe
    let seed: UInt64
    let confidence: Double
    let reasonCodes: [CoverDirectorReason]
}
