import Foundation

struct LaunchCoverTemplateDescriptor: Equatable, Sendable {
    let id: CoverTemplateID
    let displayName: String
    let subtitle: String
    let systemImageName: String
    let supportedPhotoCounts: ClosedRange<Int>
    let maximumRenderedPhotoCount: Int
    let requiresEvidenceBoundHero: Bool
    let allowsHero: Bool
    let allowsDecoration: Bool
    let requiredHeroOrientation: MediaOrientation?
    let automaticSceneKeys: Set<String>?
    let minimumRecordedDayCount: Int
    let maximumLeadCharacterCount: Int
    let showsMasthead: Bool
    let showsSupport: Bool
    let maximumMarkCount: Int
    let usesTimeline: Bool
    let typographyFamily: TypographyFamily
    let animationProfile: CoverAnimationProfile
    let defaultPaletteID: CoverPaletteID
    let defaultBackgroundFamily: BackgroundFamily
}

struct LaunchCoverTemplateSelectionInput: Equatable, Sendable {
    let preferredTemplateID: CoverTemplateID?
    let availablePhotoCount: Int
    let hasEvidenceBoundHero: Bool
    let evidenceBoundHeroOrientations: Set<MediaOrientation>
    let recordedDayCount: Int
    let leadCharacterCount: Int
    let sceneKeys: Set<String>
}

enum LaunchCoverTemplateCatalog {
    static let orderedTemplateIDs: [CoverTemplateID] = [
        .heroStory,
        .magazine,
        .memoryFocus,
        .journal,
        .film,
        .minimal,
        .quote,
        .timeline,
        .postcard,
        .scrapbook,
        .editorial,
        .memoryWall,
        .travelNote,
        .bookCover,
        .natureDiary,
        .coffeeStory,
        .warmHome,
        .nightStory,
        .ocean,
        .quietEditorial,
    ]

    private static let descriptorsByID: [CoverTemplateID: LaunchCoverTemplateDescriptor] = [
        .heroStory: LaunchCoverTemplateDescriptor(
            id: .heroStory,
            displayName: "主角故事",
            subtitle: "一张主图带出故事",
            systemImageName: "photo.fill",
            supportedPhotoCounts: 1...3,
            maximumRenderedPhotoCount: 3,
            requiresEvidenceBoundHero: true,
            allowsHero: true,
            allowsDecoration: false,
            requiredHeroOrientation: nil,
            automaticSceneKeys: nil,
            minimumRecordedDayCount: 0,
            maximumLeadCharacterCount: 48,
            showsMasthead: true,
            showsSupport: true,
            maximumMarkCount: 0,
            usesTimeline: false,
            typographyFamily: .songEditorial,
            animationProfile: .gentleEditorial,
            defaultPaletteID: .creamMorning,
            defaultBackgroundFamily: .morningLight
        ),
        .magazine: LaunchCoverTemplateDescriptor(
            id: .magazine,
            displayName: "杂志版面",
            subtitle: "一大两小的编辑排版",
            systemImageName: "rectangle.split.2x2",
            supportedPhotoCounts: 2...5,
            maximumRenderedPhotoCount: 3,
            requiresEvidenceBoundHero: true,
            allowsHero: true,
            allowsDecoration: false,
            requiredHeroOrientation: nil,
            automaticSceneKeys: nil,
            minimumRecordedDayCount: 0,
            maximumLeadCharacterCount: 42,
            showsMasthead: true,
            showsSupport: true,
            maximumMarkCount: 1,
            usesTimeline: false,
            typographyFamily: .sansEditorial,
            animationProfile: .gentleEditorial,
            defaultPaletteID: .paperGray,
            defaultBackgroundFamily: .editorial
        ),
        .memoryFocus: LaunchCoverTemplateDescriptor(
            id: .memoryFocus,
            displayName: "回忆聚焦",
            subtitle: "单张焦点与大留白",
            systemImageName: "viewfinder",
            supportedPhotoCounts: 1...3,
            maximumRenderedPhotoCount: 1,
            requiresEvidenceBoundHero: true,
            allowsHero: true,
            allowsDecoration: false,
            requiredHeroOrientation: nil,
            automaticSceneKeys: nil,
            minimumRecordedDayCount: 0,
            maximumLeadCharacterCount: 48,
            showsMasthead: false,
            showsSupport: true,
            maximumMarkCount: 0,
            usesTimeline: false,
            typographyFamily: .songEditorial,
            animationProfile: .gentleEditorial,
            defaultPaletteID: .quietCream,
            defaultBackgroundFamily: .quietEditorial
        ),
        .journal: LaunchCoverTemplateDescriptor(
            id: .journal,
            displayName: "生活手札",
            subtitle: "纸张、短文和生活小记",
            systemImageName: "book.closed",
            supportedPhotoCounts: 0...3,
            maximumRenderedPhotoCount: 2,
            requiresEvidenceBoundHero: false,
            allowsHero: false,
            allowsDecoration: false,
            requiredHeroOrientation: nil,
            automaticSceneKeys: nil,
            minimumRecordedDayCount: 0,
            maximumLeadCharacterCount: .max,
            showsMasthead: true,
            showsSupport: true,
            maximumMarkCount: 2,
            usesTimeline: false,
            typographyFamily: .journal,
            animationProfile: .paperReveal,
            defaultPaletteID: .warmBeige,
            defaultBackgroundFamily: .journal
        ),
        .film: LaunchCoverTemplateDescriptor(
            id: .film,
            displayName: "胶片故事",
            subtitle: "不等大的连续影格",
            systemImageName: "film",
            supportedPhotoCounts: 2...7,
            maximumRenderedPhotoCount: 4,
            requiresEvidenceBoundHero: true,
            allowsHero: true,
            allowsDecoration: false,
            requiredHeroOrientation: nil,
            automaticSceneKeys: nil,
            minimumRecordedDayCount: 2,
            maximumLeadCharacterCount: 56,
            showsMasthead: true,
            showsSupport: false,
            maximumMarkCount: 0,
            usesTimeline: true,
            typographyFamily: .film,
            animationProfile: .sequentialDevelop,
            defaultPaletteID: .nightBlue,
            defaultBackgroundFamily: .film
        ),
        .minimal: LaunchCoverTemplateDescriptor(
            id: .minimal,
            displayName: "留白",
            subtitle: "没有照片也保留呼吸感",
            systemImageName: "rectangle.split.3x1",
            supportedPhotoCounts: 0...1,
            maximumRenderedPhotoCount: 1,
            requiresEvidenceBoundHero: false,
            allowsHero: false,
            allowsDecoration: true,
            requiredHeroOrientation: nil,
            automaticSceneKeys: nil,
            minimumRecordedDayCount: 0,
            maximumLeadCharacterCount: 30,
            showsMasthead: true,
            showsSupport: false,
            maximumMarkCount: 0,
            usesTimeline: false,
            typographyFamily: .songEditorial,
            animationProfile: .quietFade,
            defaultPaletteID: .quietCream,
            defaultBackgroundFamily: .minimal
        ),
        .quote: LaunchCoverTemplateDescriptor(
            id: .quote,
            displayName: "一句话",
            subtitle: "让一句真实记录成为主角",
            systemImageName: "quote.opening",
            supportedPhotoCounts: 0...1,
            maximumRenderedPhotoCount: 1,
            requiresEvidenceBoundHero: false,
            allowsHero: false,
            allowsDecoration: false,
            requiredHeroOrientation: nil,
            automaticSceneKeys: nil,
            minimumRecordedDayCount: 0,
            maximumLeadCharacterCount: 30,
            showsMasthead: false,
            showsSupport: false,
            maximumMarkCount: 0,
            usesTimeline: false,
            typographyFamily: .songEditorial,
            animationProfile: .quietFade,
            defaultPaletteID: .fogGreen,
            defaultBackgroundFamily: .morningLight
        ),
        .timeline: LaunchCoverTemplateDescriptor(
            id: .timeline,
            displayName: "时间线",
            subtitle: "按真实记录日展开节奏",
            systemImageName: "point.topleft.down.to.point.bottomright.curvepath",
            supportedPhotoCounts: 0...7,
            maximumRenderedPhotoCount: 3,
            requiresEvidenceBoundHero: false,
            allowsHero: true,
            allowsDecoration: false,
            requiredHeroOrientation: nil,
            automaticSceneKeys: nil,
            minimumRecordedDayCount: 3,
            maximumLeadCharacterCount: 56,
            showsMasthead: true,
            showsSupport: true,
            maximumMarkCount: 0,
            usesTimeline: true,
            typographyFamily: .sansEditorial,
            animationProfile: .sequentialDevelop,
            defaultPaletteID: .paperGray,
            defaultBackgroundFamily: .film
        ),
        .postcard: LaunchCoverTemplateDescriptor(
            id: .postcard,
            displayName: "明信片",
            subtitle: "街景主图与轻邮寄感",
            systemImageName: "envelope",
            supportedPhotoCounts: 1...2,
            maximumRenderedPhotoCount: 2,
            requiresEvidenceBoundHero: true,
            allowsHero: true,
            allowsDecoration: false,
            requiredHeroOrientation: nil,
            automaticSceneKeys: ["scene:cityRoute", "scene:lodging"],
            minimumRecordedDayCount: 0,
            maximumLeadCharacterCount: 42,
            showsMasthead: true,
            showsSupport: true,
            maximumMarkCount: 0,
            usesTimeline: false,
            typographyFamily: .songEditorial,
            animationProfile: .gentleEditorial,
            defaultPaletteID: .creamMorning,
            defaultBackgroundFamily: .postcard
        ),
        .scrapbook: LaunchCoverTemplateDescriptor(
            id: .scrapbook,
            displayName: "拼贴手账",
            subtitle: "多张照片错落叠放",
            systemImageName: "square.on.square",
            supportedPhotoCounts: 3...7,
            maximumRenderedPhotoCount: 5,
            requiresEvidenceBoundHero: true,
            allowsHero: true,
            allowsDecoration: false,
            requiredHeroOrientation: nil,
            automaticSceneKeys: nil,
            minimumRecordedDayCount: 0,
            maximumLeadCharacterCount: 48,
            showsMasthead: false,
            showsSupport: false,
            maximumMarkCount: 1,
            usesTimeline: false,
            typographyFamily: .journal,
            animationProfile: .paperReveal,
            defaultPaletteID: .warmBeige,
            defaultBackgroundFamily: .journal
        ),
        .editorial: LaunchCoverTemplateDescriptor(
            id: .editorial,
            displayName: "编辑精选",
            subtitle: "主图、侧栏与编辑短注",
            systemImageName: "newspaper",
            supportedPhotoCounts: 2...4,
            maximumRenderedPhotoCount: 3,
            requiresEvidenceBoundHero: true,
            allowsHero: true,
            allowsDecoration: false,
            requiredHeroOrientation: nil,
            automaticSceneKeys: nil,
            minimumRecordedDayCount: 0,
            maximumLeadCharacterCount: 48,
            showsMasthead: true,
            showsSupport: true,
            maximumMarkCount: 1,
            usesTimeline: false,
            typographyFamily: .sansEditorial,
            animationProfile: .gentleEditorial,
            defaultPaletteID: .paperGray,
            defaultBackgroundFamily: .editorial
        ),
        .memoryWall: LaunchCoverTemplateDescriptor(
            id: .memoryWall,
            displayName: "记忆墙",
            subtitle: "多图不对称拼成一页",
            systemImageName: "rectangle.3.group",
            supportedPhotoCounts: 4...7,
            maximumRenderedPhotoCount: 6,
            requiresEvidenceBoundHero: true,
            allowsHero: true,
            allowsDecoration: false,
            requiredHeroOrientation: nil,
            automaticSceneKeys: nil,
            minimumRecordedDayCount: 0,
            maximumLeadCharacterCount: 42,
            showsMasthead: false,
            showsSupport: false,
            maximumMarkCount: 0,
            usesTimeline: false,
            typographyFamily: .sansEditorial,
            animationProfile: .gentleEditorial,
            defaultPaletteID: .quietCream,
            defaultBackgroundFamily: .quietEditorial
        ),
        .travelNote: LaunchCoverTemplateDescriptor(
            id: .travelNote,
            displayName: "旅行札记",
            subtitle: "路线节奏与三张旅途照片",
            systemImageName: "map",
            supportedPhotoCounts: 2...6,
            maximumRenderedPhotoCount: 3,
            requiresEvidenceBoundHero: true,
            allowsHero: true,
            allowsDecoration: false,
            requiredHeroOrientation: nil,
            automaticSceneKeys: ["scene:cityRoute", "scene:lodging"],
            minimumRecordedDayCount: 2,
            maximumLeadCharacterCount: 48,
            showsMasthead: true,
            showsSupport: true,
            maximumMarkCount: 0,
            usesTimeline: true,
            typographyFamily: .journal,
            animationProfile: .sequentialDevelop,
            defaultPaletteID: .warmBeige,
            defaultBackgroundFamily: .travelNote
        ),
        .bookCover: LaunchCoverTemplateDescriptor(
            id: .bookCover,
            displayName: "书封",
            subtitle: "纵向主图与书名式标题",
            systemImageName: "book",
            supportedPhotoCounts: 1...1,
            maximumRenderedPhotoCount: 1,
            requiresEvidenceBoundHero: true,
            allowsHero: true,
            allowsDecoration: false,
            requiredHeroOrientation: .portrait,
            automaticSceneKeys: nil,
            minimumRecordedDayCount: 0,
            maximumLeadCharacterCount: 30,
            showsMasthead: true,
            showsSupport: true,
            maximumMarkCount: 0,
            usesTimeline: false,
            typographyFamily: .songEditorial,
            animationProfile: .gentleEditorial,
            defaultPaletteID: .quietCream,
            defaultBackgroundFamily: .bookCover
        ),
        .natureDiary: LaunchCoverTemplateDescriptor(
            id: .natureDiary,
            displayName: "自然日记",
            subtitle: "柔和绿意与观察片段",
            systemImageName: "leaf",
            supportedPhotoCounts: 1...4,
            maximumRenderedPhotoCount: 3,
            requiresEvidenceBoundHero: true,
            allowsHero: true,
            allowsDecoration: false,
            requiredHeroOrientation: nil,
            automaticSceneKeys: [],
            minimumRecordedDayCount: 0,
            maximumLeadCharacterCount: 48,
            showsMasthead: true,
            showsSupport: true,
            maximumMarkCount: 1,
            usesTimeline: false,
            typographyFamily: .journal,
            animationProfile: .gentleEditorial,
            defaultPaletteID: .fogGreen,
            defaultBackgroundFamily: .nature
        ),
        .coffeeStory: LaunchCoverTemplateDescriptor(
            id: .coffeeStory,
            displayName: "咖啡片段",
            subtitle: "暖棕主图与一段变化",
            systemImageName: "cup.and.saucer",
            supportedPhotoCounts: 1...3,
            maximumRenderedPhotoCount: 2,
            requiresEvidenceBoundHero: true,
            allowsHero: true,
            allowsDecoration: false,
            requiredHeroOrientation: nil,
            automaticSceneKeys: ["scene:coffee"],
            minimumRecordedDayCount: 0,
            maximumLeadCharacterCount: 48,
            showsMasthead: false,
            showsSupport: true,
            maximumMarkCount: 1,
            usesTimeline: false,
            typographyFamily: .songEditorial,
            animationProfile: .gentleEditorial,
            defaultPaletteID: .coffeeBrown,
            defaultBackgroundFamily: .coffeeTime
        ),
        .warmHome: LaunchCoverTemplateDescriptor(
            id: .warmHome,
            displayName: "家中片刻",
            subtitle: "暖纸色与柔和窗光",
            systemImageName: "house",
            supportedPhotoCounts: 1...4,
            maximumRenderedPhotoCount: 3,
            requiresEvidenceBoundHero: true,
            allowsHero: true,
            allowsDecoration: false,
            requiredHeroOrientation: nil,
            automaticSceneKeys: ["scene:homeSupply", "scene:groceries"],
            minimumRecordedDayCount: 0,
            maximumLeadCharacterCount: 48,
            showsMasthead: true,
            showsSupport: true,
            maximumMarkCount: 1,
            usesTimeline: false,
            typographyFamily: .journal,
            animationProfile: .paperReveal,
            defaultPaletteID: .warmBeige,
            defaultBackgroundFamily: .warmHome
        ),
        .nightStory: LaunchCoverTemplateDescriptor(
            id: .nightStory,
            displayName: "夜行故事",
            subtitle: "深蓝反光与夜间节奏",
            systemImageName: "moon.stars",
            supportedPhotoCounts: 1...4,
            maximumRenderedPhotoCount: 3,
            requiresEvidenceBoundHero: true,
            allowsHero: true,
            allowsDecoration: false,
            requiredHeroOrientation: nil,
            automaticSceneKeys: [],
            minimumRecordedDayCount: 0,
            maximumLeadCharacterCount: 48,
            showsMasthead: true,
            showsSupport: true,
            maximumMarkCount: 0,
            usesTimeline: false,
            typographyFamily: .film,
            animationProfile: .sequentialDevelop,
            defaultPaletteID: .nightBlue,
            defaultBackgroundFamily: .nightWalk
        ),
        .ocean: LaunchCoverTemplateDescriptor(
            id: .ocean,
            displayName: "海边记忆",
            subtitle: "水平主图与低饱和蓝",
            systemImageName: "water.waves",
            supportedPhotoCounts: 1...4,
            maximumRenderedPhotoCount: 3,
            requiresEvidenceBoundHero: true,
            allowsHero: true,
            allowsDecoration: false,
            requiredHeroOrientation: nil,
            automaticSceneKeys: [],
            minimumRecordedDayCount: 0,
            maximumLeadCharacterCount: 42,
            showsMasthead: false,
            showsSupport: true,
            maximumMarkCount: 0,
            usesTimeline: false,
            typographyFamily: .songEditorial,
            animationProfile: .gentleEditorial,
            defaultPaletteID: .oceanBlue,
            defaultBackgroundFamily: .ocean
        ),
        .quietEditorial: LaunchCoverTemplateDescriptor(
            id: .quietEditorial,
            displayName: "静默编辑",
            subtitle: "小图、细字与大量留白",
            systemImageName: "text.alignleft",
            supportedPhotoCounts: 0...2,
            maximumRenderedPhotoCount: 2,
            requiresEvidenceBoundHero: false,
            allowsHero: false,
            allowsDecoration: true,
            requiredHeroOrientation: nil,
            automaticSceneKeys: nil,
            minimumRecordedDayCount: 0,
            maximumLeadCharacterCount: 36,
            showsMasthead: true,
            showsSupport: true,
            maximumMarkCount: 1,
            usesTimeline: false,
            typographyFamily: .songEditorial,
            animationProfile: .quietFade,
            defaultPaletteID: .quietCream,
            defaultBackgroundFamily: .quietEditorial
        ),
    ]

    static func descriptor(
        for templateID: CoverTemplateID
    ) -> LaunchCoverTemplateDescriptor? {
        descriptorsByID[templateID]
    }

    static func templateID(
        forLegacyVariantID variantID: String
    ) -> CoverTemplateID? {
        if let explicitID = CoverTemplateID(rawValue: variantID),
           orderedTemplateIDs.contains(explicitID) {
            return explicitID
        }
        switch variantID {
        case "warmLight", "fullPhoto", "customBackground":
            return .heroStory
        case "magazine", "collageStory":
            return .magazine
        case "journal", "review-weekly":
            return .journal
        case "appleMemories":
            return .quote
        case "filmStory":
            return .timeline
        case "cleanTexture":
            return .minimal
        default:
            return nil
        }
    }

    static func availableTemplateIDs(
        for input: LaunchCoverTemplateSelectionInput
    ) -> [CoverTemplateID] {
        orderedTemplateIDs.filter { isAutomaticallyEligible($0, for: input) }
    }

    static func manuallyAvailableTemplateIDs(
        for input: LaunchCoverTemplateSelectionInput
    ) -> [CoverTemplateID] {
        orderedTemplateIDs.filter { isStructurallyEligible($0, for: input) }
    }

    static func selectTemplateID(
        for input: LaunchCoverTemplateSelectionInput
    ) -> CoverTemplateID {
        if let preferredTemplateID = input.preferredTemplateID,
           isStructurallyEligible(preferredTemplateID, for: input) {
            return preferredTemplateID
        }

        let fallbackOrder: [CoverTemplateID]
        if input.leadCharacterCount > 48 {
            fallbackOrder = [.journal, .timeline, .minimal]
        } else if input.hasEvidenceBoundHero && input.availablePhotoCount >= 4 {
            fallbackOrder = [
                .memoryWall, .scrapbook, .editorial, .magazine,
                .heroStory, .film, .timeline, .journal,
            ]
        } else if input.hasEvidenceBoundHero && input.availablePhotoCount >= 2 {
            fallbackOrder = [
                .editorial, .magazine, .memoryFocus, .heroStory,
                .film, .timeline, .journal, .minimal,
            ]
        } else if input.hasEvidenceBoundHero {
            fallbackOrder = [
                .memoryFocus, .heroStory, .bookCover, .timeline,
                .quote, .journal, .minimal,
            ]
        } else if input.recordedDayCount >= 3 {
            fallbackOrder = [.timeline, .quietEditorial, .quote, .journal, .minimal]
        } else {
            fallbackOrder = [.quietEditorial, .quote, .journal, .minimal]
        }
        return fallbackOrder.first(where: { isAutomaticallyEligible($0, for: input) }) ?? .journal
    }

    static func allocationRequest(
        for templateID: CoverTemplateID,
        factPack: CoverFactPack
    ) -> CoverContentAllocationRequest {
        let descriptor = descriptorsByID[templateID] ?? descriptorsByID[.journal]!
        return CoverContentAllocationRequest(
            mastheadAtomIDs: descriptor.showsMasthead ? [CoverFactAtomID.period] : [],
            storyLeadAtomID: factPack.story.id,
            storySupportAtomID: descriptor.showsSupport ? factPack.support?.id : nil,
            mediaCaptionAtomIDs: [:],
            markAtomIDs: Array(factPack.marks.prefix(descriptor.maximumMarkCount)).map(\.id),
            timelineAtomIDs: descriptor.usesTimeline
                ? Array(factPack.context.timelineLabels.prefix(4)).map(\.id)
                : [],
            footerAtomIDs: [
                CoverFactAtomID.brand,
                CoverFactAtomID.recordCount,
                CoverFactAtomID.recordedDayCount,
                CoverFactAtomID.photoCount,
            ]
        )
    }

    static func mediaRecipes(
        for templateID: CoverTemplateID,
        descriptors: [MediaDescriptor],
        leadEvidenceItemIDs: [UUID]
    ) -> [MediaPlacementRecipe] {
        guard let template = descriptorsByID[templateID] else { return [] }
        let usesHeroRole = template.allowsHero
        let heroCandidates = usesHeroRole
            ? CoverMediaRoleScoring.orderedHeroCandidates(
                descriptors,
                leadEvidenceItemIDs: leadEvidenceItemIDs
            )
            : []
        let heroID = heroCandidates.first(where: { descriptor in
            guard let requiredOrientation = template.requiredHeroOrientation else { return true }
            return descriptor.orientation == requiredOrientation
        })?.id

        var ordered = CoverMediaRoleScoring.orderedSecondaryCandidates(
            descriptors,
            excluding: heroID
        )
        if let heroID,
           let hero = descriptors.first(where: { $0.id == heroID }) {
            ordered.insert(hero, at: 0)
        }
        let selected = Array(ordered.prefix(template.maximumRenderedPhotoCount))
        return selected.enumerated().map { index, descriptor in
            let role: MediaRole
            if template.allowsHero, descriptor.id == heroID {
                role = .hero
            } else if template.allowsDecoration {
                role = .decoration
            } else {
                role = .secondary
            }
            return MediaPlacementRecipe(
                mediaID: descriptor.id,
                role: role,
                slotID: "launch.\(templateID.rawValue).\(role.rawValue).\(index)",
                cropMode: cropMode(for: templateID, role: role),
                treatment: treatment(for: templateID, role: role)
            )
        }
    }

    static func variantID(
        for templateID: CoverTemplateID,
        leadCharacterCount: Int,
        mediaCount: Int
    ) -> String {
        let density = leadCharacterCount > 48 ? "long-copy" : "standard-copy"
        return "launch.\(templateID.rawValue).\(density).media-\(min(max(0, mediaCount), 6))"
    }

    static func reasonCodes(
        for templateID: CoverTemplateID,
        hasEvidenceBoundHero: Bool,
        availablePhotoCount: Int
    ) -> [CoverDirectorReason] {
        var reasons: [CoverDirectorReason] = [.deterministicFallback]
        if hasEvidenceBoundHero, descriptorsByID[templateID]?.allowsHero == true {
            reasons.insert(.strongPhotoLead, at: 0)
        }
        if descriptorsByID[templateID].map({ $0.maximumRenderedPhotoCount >= 2 }) == true,
           availablePhotoCount >= 2 {
            reasons.append(.balancedPhotoSet)
        }
        if descriptorsByID[templateID]?.usesTimeline == true {
            reasons.append(.timelineEvidence)
        }
        if availablePhotoCount == 0 {
            reasons.append(.noEligiblePhoto)
        }
        return reasons
    }

    private static func isAutomaticallyEligible(
        _ templateID: CoverTemplateID,
        for input: LaunchCoverTemplateSelectionInput
    ) -> Bool {
        guard isStructurallyEligible(templateID, for: input),
              let sceneKeys = descriptorsByID[templateID]?.automaticSceneKeys else {
            return isStructurallyEligible(templateID, for: input)
        }
        guard !sceneKeys.isEmpty else { return false }
        return !sceneKeys.isDisjoint(with: input.sceneKeys)
    }

    private static func isStructurallyEligible(
        _ templateID: CoverTemplateID,
        for input: LaunchCoverTemplateSelectionInput
    ) -> Bool {
        guard let descriptor = descriptorsByID[templateID] else { return false }
        let availablePhotoCount = max(0, input.availablePhotoCount)
        let renderedPhotoCount = min(
            availablePhotoCount,
            descriptor.maximumRenderedPhotoCount
        )
        guard descriptor.supportedPhotoCounts.contains(renderedPhotoCount),
              input.recordedDayCount >= descriptor.minimumRecordedDayCount,
              input.leadCharacterCount <= descriptor.maximumLeadCharacterCount else {
            return false
        }
        if descriptor.requiresEvidenceBoundHero && !input.hasEvidenceBoundHero {
            return false
        }
        if let requiredOrientation = descriptor.requiredHeroOrientation,
           !input.evidenceBoundHeroOrientations.contains(requiredOrientation) {
            return false
        }
        return true
    }

    static func cropMode(
        for templateID: CoverTemplateID,
        role: MediaRole
    ) -> CropMode {
        if role == .hero { return .cropSafeFill }
        return descriptorsByID[templateID]?.allowsDecoration == true ? .fit : .fill
    }

    static func treatment(
        for templateID: CoverTemplateID,
        role: MediaRole
    ) -> MediaTreatment {
        if role == .hero { return .clean }
        switch templateID {
        case .journal, .quote, .minimal, .memoryFocus, .scrapbook,
             .travelNote, .natureDiary, .coffeeStory, .warmHome,
             .quietEditorial:
            return .paper
        case .timeline, .postcard:
            return .polaroid
        case .film, .nightStory:
            return .film
        default:
            return .clean
        }
    }
}

enum LaunchCoverTemplateLayoutResolver {
    private static let canvasSize = CoverRenderSize(width: 540, height: 960)
    private static let footerFrame = CoverRenderRect(x: 32, y: 872, width: 476, height: 56)

    static func resolve(
        recipe: CoverRecipe,
        allocation: ContentAllocationPlan
    ) -> ResolvedCoverLayout {
        let bodyPlacements: [ResolvedCoverAtomPlacement]
        let mediaPlacements: [ResolvedCoverMediaPlacement]
        switch recipe.template.templateID {
        case .heroStory:
            bodyPlacements = heroStoryAtoms(allocation)
            mediaPlacements = heroStoryMedia(recipe.media)
        case .magazine:
            bodyPlacements = magazineAtoms(allocation)
            mediaPlacements = magazineMedia(recipe.media)
        case .memoryFocus:
            bodyPlacements = memoryFocusAtoms(allocation)
            mediaPlacements = arrangedMedia(
                recipe.media,
                heroFrame: rect(92, 316, 356, 476),
                secondaryFrames: []
            )
        case .journal:
            bodyPlacements = journalAtoms(
                allocation,
                usesLongCopy: allocation.storyLead.text.count > 48
            )
            mediaPlacements = journalMedia(recipe.media)
        case .film:
            bodyPlacements = filmAtoms(allocation)
            mediaPlacements = arrangedMedia(
                recipe.media,
                heroFrame: rect(32, 246, 300, 272),
                secondaryFrames: [
                    rect(350, 246, 158, 176),
                    rect(58, 492, 210, 294),
                    rect(288, 448, 220, 338),
                ]
            )
        case .minimal:
            bodyPlacements = minimalAtoms(allocation)
            mediaPlacements = minimalMedia(recipe.media)
        case .quote:
            bodyPlacements = quoteAtoms(allocation)
            mediaPlacements = quoteMedia(recipe.media)
        case .timeline:
            bodyPlacements = timelineAtoms(allocation)
            mediaPlacements = timelineMedia(recipe.media)
        case .postcard:
            bodyPlacements = postcardAtoms(allocation)
            mediaPlacements = arrangedMedia(
                recipe.media,
                heroFrame: rect(32, 286, 476, 350),
                secondaryFrames: [rect(326, 658, 182, 156)]
            )
        case .scrapbook:
            bodyPlacements = scrapbookAtoms(allocation)
            mediaPlacements = arrangedMedia(
                recipe.media,
                heroFrame: rect(56, 258, 292, 336),
                secondaryFrames: [
                    rect(334, 228, 158, 194),
                    rect(36, 610, 190, 188),
                    rect(244, 628, 176, 176),
                    rect(382, 548, 126, 252),
                ]
            )
        case .editorial:
            bodyPlacements = editorialAtoms(allocation)
            mediaPlacements = arrangedMedia(
                recipe.media,
                heroFrame: rect(32, 294, 318, 508),
                secondaryFrames: [
                    rect(366, 294, 142, 224),
                    rect(366, 570, 142, 232),
                ]
            )
        case .memoryWall:
            bodyPlacements = memoryWallAtoms(allocation)
            mediaPlacements = arrangedMedia(
                recipe.media,
                heroFrame: rect(32, 232, 270, 328),
                secondaryFrames: [
                    rect(316, 232, 192, 192),
                    rect(316, 438, 192, 250),
                    rect(32, 576, 150, 226),
                    rect(196, 576, 146, 226),
                    rect(356, 704, 152, 98),
                ]
            )
        case .travelNote:
            bodyPlacements = travelNoteAtoms(allocation)
            mediaPlacements = arrangedMedia(
                recipe.media,
                heroFrame: rect(178, 306, 330, 286),
                secondaryFrames: [
                    rect(32, 616, 216, 186),
                    rect(266, 616, 242, 186),
                ]
            )
        case .bookCover:
            bodyPlacements = bookCoverAtoms(allocation)
            mediaPlacements = arrangedMedia(
                recipe.media,
                heroFrame: rect(84, 274, 372, 548),
                secondaryFrames: []
            )
        case .natureDiary:
            bodyPlacements = natureDiaryAtoms(allocation)
            mediaPlacements = arrangedMedia(
                recipe.media,
                heroFrame: rect(32, 286, 310, 372),
                secondaryFrames: [
                    rect(360, 286, 148, 214),
                    rect(360, 518, 148, 204),
                ]
            )
        case .coffeeStory:
            bodyPlacements = coffeeStoryAtoms(allocation)
            mediaPlacements = arrangedMedia(
                recipe.media,
                heroFrame: rect(56, 302, 324, 430),
                secondaryFrames: [rect(348, 646, 160, 156)]
            )
        case .warmHome:
            bodyPlacements = warmHomeAtoms(allocation)
            mediaPlacements = arrangedMedia(
                recipe.media,
                heroFrame: rect(32, 300, 476, 330),
                secondaryFrames: [
                    rect(32, 650, 226, 154),
                    rect(278, 650, 230, 154),
                ]
            )
        case .nightStory:
            bodyPlacements = nightStoryAtoms(allocation)
            mediaPlacements = arrangedMedia(
                recipe.media,
                heroFrame: rect(32, 284, 326, 514),
                secondaryFrames: [
                    rect(374, 284, 134, 240),
                    rect(374, 544, 134, 254),
                ]
            )
        case .ocean:
            bodyPlacements = oceanAtoms(allocation)
            mediaPlacements = arrangedMedia(
                recipe.media,
                heroFrame: rect(32, 300, 476, 322),
                secondaryFrames: [
                    rect(92, 650, 190, 154),
                    rect(304, 650, 148, 122),
                ]
            )
        case .quietEditorial:
            bodyPlacements = quietEditorialAtoms(allocation)
            mediaPlacements = arrangedMedia(
                recipe.media,
                heroFrame: nil,
                secondaryFrames: [
                    rect(326, 566, 154, 142),
                    rect(64, 680, 126, 104),
                ]
            )
        }
        return ResolvedCoverLayout(
            schemaVersion: CoverRenderSchema.currentVersion,
            layoutID: "layout.launch.\(CoverStableIdentity.fingerprint([
                recipe.recipeID,
                recipe.template.templateID.rawValue,
                recipe.template.variantID,
            ]))",
            recipeID: recipe.recipeID,
            sourceRevision: recipe.sourceRevision,
            periodKey: recipe.periodKey,
            contentFingerprint: recipe.contentFingerprint,
            canvasSize: canvasSize,
            footerFrame: footerFrame,
            bodyAtomPlacements: bodyPlacements,
            mediaPlacements: mediaPlacements
        )
    }

    private static func heroStoryAtoms(
        _ allocation: ContentAllocationPlan
    ) -> [ResolvedCoverAtomPlacement] {
        var placements = masthead(allocation, frame: rect(32, 34, 476, 22))
        placements.append(atom(allocation.storyLead, rect(32, 76, 456, 120), .lead, 3))
        if let support = allocation.storySupport {
            placements.append(atom(support, rect(32, 204, 420, 66), .support, 3))
        }
        return placements
    }

    private static func heroStoryMedia(
        _ media: [MediaPlacementRecipe]
    ) -> [ResolvedCoverMediaPlacement] {
        media.enumerated().map { index, item in
            let frame: CoverRenderRect
            if item.role == .hero {
                frame = rect(32, 302, 476, 514)
            } else if index.isMultiple(of: 2) {
                frame = rect(348, 680, 160, 126)
            } else {
                frame = rect(32, 690, 154, 116)
            }
            return mediaAtom(item, frame, item.role == .hero ? 0 : index + 2)
        }
    }

    private static func magazineAtoms(
        _ allocation: ContentAllocationPlan
    ) -> [ResolvedCoverAtomPlacement] {
        var placements = masthead(allocation, frame: rect(32, 32, 476, 22))
        placements.append(atom(allocation.storyLead, rect(32, 66, 476, 108), .lead, 3))
        if let support = allocation.storySupport {
            placements.append(atom(support, rect(32, 182, 316, 72), .support, 3))
        }
        for (index, mark) in allocation.marks.enumerated() {
            placements.append(atom(mark, rect(370, 190 + Double(index) * 30, 138, 24), .mark, 1))
        }
        return placements
    }

    private static func magazineMedia(
        _ media: [MediaPlacementRecipe]
    ) -> [ResolvedCoverMediaPlacement] {
        media.enumerated().map { index, item in
            let frame: CoverRenderRect
            if item.role == .hero {
                frame = rect(32, 282, 310, 520)
            } else if index.isMultiple(of: 2) {
                frame = rect(354, 282, 154, 238)
            } else {
                frame = rect(354, 536, 154, 266)
            }
            return mediaAtom(item, frame, item.role == .hero ? 0 : index + 1)
        }
    }

    private static func journalAtoms(
        _ allocation: ContentAllocationPlan,
        usesLongCopy: Bool
    ) -> [ResolvedCoverAtomPlacement] {
        var placements = masthead(allocation, frame: rect(48, 46, 424, 22))
        placements.append(
            atom(
                allocation.storyLead,
                rect(48, 96, 424, usesLongCopy ? 220 : 154),
                .lead,
                usesLongCopy ? 5 : 3
            )
        )
        let supportY = usesLongCopy ? 334.0 : 278.0
        if let support = allocation.storySupport {
            placements.append(atom(support, rect(72, supportY, 384, 100), .support, 4))
        }
        let marksY = supportY + (allocation.storySupport == nil ? 28 : 124)
        for (index, mark) in allocation.marks.enumerated() {
            placements.append(atom(mark, rect(72, marksY + Double(index) * 38, 280, 28), .mark, 1))
        }
        return placements
    }

    private static func journalMedia(
        _ media: [MediaPlacementRecipe]
    ) -> [ResolvedCoverMediaPlacement] {
        media.enumerated().map { index, item in
            let frame = index == 0
                ? rect(276, 574, 196, 232)
                : rect(64, 642, 176, 164)
            return mediaAtom(item, frame, index + 1)
        }
    }

    private static func quoteAtoms(
        _ allocation: ContentAllocationPlan
    ) -> [ResolvedCoverAtomPlacement] {
        [atom(allocation.storyLead, rect(52, 138, 436, 382), .lead, 4, .leading)]
    }

    private static func quoteMedia(
        _ media: [MediaPlacementRecipe]
    ) -> [ResolvedCoverMediaPlacement] {
        media.prefix(1).enumerated().map { index, item in
            mediaAtom(item, rect(356, 648, 152, 146), index + 1)
        }
    }

    private static func timelineAtoms(
        _ allocation: ContentAllocationPlan
    ) -> [ResolvedCoverAtomPlacement] {
        var placements = masthead(allocation, frame: rect(32, 32, 476, 22))
        placements.append(atom(allocation.storyLead, rect(72, 68, 436, 112), .lead, 3))
        if let support = allocation.storySupport {
            placements.append(atom(support, rect(72, 190, 416, 64), .support, 3))
        }
        for (index, timeline) in allocation.timeline.enumerated() {
            placements.append(
                atom(
                    timeline,
                    rect(72, 310 + Double(index) * 104, 156, 30),
                    .timeline,
                    1
                )
            )
        }
        return placements
    }

    private static func timelineMedia(
        _ media: [MediaPlacementRecipe]
    ) -> [ResolvedCoverMediaPlacement] {
        let hasHero = media.contains { $0.role == .hero }
        return media.enumerated().map { index, item in
            let frame: CoverRenderRect
            if item.role == .hero {
                frame = rect(260, 294, 248, 224)
            } else if hasHero && index == 1 {
                frame = rect(292, 548, 216, 174)
            } else if hasHero {
                frame = rect(260, 736, 180, 92)
            } else if index == 0 {
                frame = rect(286, 318, 190, 156)
            } else if index == 1 {
                frame = rect(252, 520, 224, 142)
            } else {
                frame = rect(290, 704, 186, 124)
            }
            return mediaAtom(item, frame, item.role == .hero ? 0 : index + 1)
        }
    }

    private static func minimalAtoms(
        _ allocation: ContentAllocationPlan
    ) -> [ResolvedCoverAtomPlacement] {
        var placements = masthead(allocation, frame: rect(32, 36, 476, 22))
        placements.append(atom(allocation.storyLead, rect(72, 246, 396, 210), .lead, 3))
        return placements
    }

    private static func minimalMedia(
        _ media: [MediaPlacementRecipe]
    ) -> [ResolvedCoverMediaPlacement] {
        media.prefix(1).enumerated().map { index, item in
            mediaAtom(item, rect(360, 650, 132, 118), index + 1)
        }
    }

    private static func memoryFocusAtoms(
        _ allocation: ContentAllocationPlan
    ) -> [ResolvedCoverAtomPlacement] {
        var placements = [atom(allocation.storyLead, rect(56, 72, 428, 134), .lead, 3)]
        if let support = allocation.storySupport {
            placements.append(atom(support, rect(92, 218, 356, 64), .support, 3))
        }
        return placements
    }

    private static func filmAtoms(
        _ allocation: ContentAllocationPlan
    ) -> [ResolvedCoverAtomPlacement] {
        var placements = masthead(allocation, frame: rect(32, 32, 476, 22))
        placements.append(atom(allocation.storyLead, rect(32, 70, 456, 112), .lead, 3))
        for (index, timeline) in allocation.timeline.enumerated() {
            placements.append(atom(
                timeline,
                rect(32 + Double(index) * 119, 816, 108, 24),
                .timeline,
                1
            ))
        }
        return placements
    }

    private static func postcardAtoms(
        _ allocation: ContentAllocationPlan
    ) -> [ResolvedCoverAtomPlacement] {
        var placements = masthead(allocation, frame: rect(32, 34, 476, 22))
        placements.append(atom(allocation.storyLead, rect(32, 72, 442, 108), .lead, 3))
        if let support = allocation.storySupport {
            placements.append(atom(support, rect(32, 190, 376, 62), .support, 3))
        }
        return placements
    }

    private static func scrapbookAtoms(
        _ allocation: ContentAllocationPlan
    ) -> [ResolvedCoverAtomPlacement] {
        var placements = [atom(allocation.storyLead, rect(44, 52, 452, 116), .lead, 3)]
        for (index, mark) in allocation.marks.enumerated() {
            placements.append(atom(mark, rect(48, 182 + Double(index) * 28, 180, 22), .mark, 1))
        }
        return placements
    }

    private static func editorialAtoms(
        _ allocation: ContentAllocationPlan
    ) -> [ResolvedCoverAtomPlacement] {
        var placements = masthead(allocation, frame: rect(32, 32, 476, 22))
        placements.append(atom(allocation.storyLead, rect(32, 70, 456, 104), .lead, 3))
        if let support = allocation.storySupport {
            placements.append(atom(support, rect(32, 186, 300, 70), .support, 3))
        }
        for (index, mark) in allocation.marks.enumerated() {
            placements.append(atom(mark, rect(366, 190 + Double(index) * 30, 142, 24), .mark, 1))
        }
        return placements
    }

    private static func memoryWallAtoms(
        _ allocation: ContentAllocationPlan
    ) -> [ResolvedCoverAtomPlacement] {
        [atom(allocation.storyLead, rect(44, 58, 452, 124), .lead, 3)]
    }

    private static func travelNoteAtoms(
        _ allocation: ContentAllocationPlan
    ) -> [ResolvedCoverAtomPlacement] {
        var placements = masthead(allocation, frame: rect(32, 30, 476, 22))
        placements.append(atom(allocation.storyLead, rect(32, 68, 456, 108), .lead, 3))
        if let support = allocation.storySupport {
            placements.append(atom(support, rect(32, 184, 430, 64), .support, 3))
        }
        for (index, timeline) in allocation.timeline.enumerated() {
            placements.append(atom(
                timeline,
                rect(32, 316 + Double(index) * 66, 126, 24),
                .timeline,
                1
            ))
        }
        return placements
    }

    private static func bookCoverAtoms(
        _ allocation: ContentAllocationPlan
    ) -> [ResolvedCoverAtomPlacement] {
        var placements = [atom(allocation.storyLead, rect(84, 40, 372, 112), .lead, 3, .center)]
        placements += masthead(allocation, frame: rect(84, 164, 372, 22))
        if let support = allocation.storySupport {
            placements.append(atom(support, rect(112, 202, 316, 48), .support, 2, .center))
        }
        return placements
    }

    private static func natureDiaryAtoms(
        _ allocation: ContentAllocationPlan
    ) -> [ResolvedCoverAtomPlacement] {
        var placements = masthead(allocation, frame: rect(32, 32, 476, 22))
        placements.append(atom(allocation.storyLead, rect(32, 72, 440, 104), .lead, 3))
        if let support = allocation.storySupport {
            placements.append(atom(support, rect(32, 186, 378, 62), .support, 3))
        }
        for (index, mark) in allocation.marks.enumerated() {
            placements.append(atom(mark, rect(360, 742 + Double(index) * 28, 148, 22), .mark, 1))
        }
        return placements
    }

    private static func coffeeStoryAtoms(
        _ allocation: ContentAllocationPlan
    ) -> [ResolvedCoverAtomPlacement] {
        var placements = [atom(allocation.storyLead, rect(56, 68, 428, 116), .lead, 3)]
        if let support = allocation.storySupport {
            placements.append(atom(support, rect(56, 196, 372, 64), .support, 3))
        }
        for (index, mark) in allocation.marks.enumerated() {
            placements.append(atom(mark, rect(56, 270 + Double(index) * 28, 180, 22), .mark, 1))
        }
        return placements
    }

    private static func warmHomeAtoms(
        _ allocation: ContentAllocationPlan
    ) -> [ResolvedCoverAtomPlacement] {
        var placements = masthead(allocation, frame: rect(32, 32, 476, 22))
        placements.append(atom(allocation.storyLead, rect(32, 72, 452, 108), .lead, 3))
        if let support = allocation.storySupport {
            placements.append(atom(support, rect(32, 192, 392, 62), .support, 3))
        }
        for (index, mark) in allocation.marks.enumerated() {
            placements.append(atom(mark, rect(388, 198 + Double(index) * 28, 120, 22), .mark, 1))
        }
        return placements
    }

    private static func nightStoryAtoms(
        _ allocation: ContentAllocationPlan
    ) -> [ResolvedCoverAtomPlacement] {
        var placements = masthead(allocation, frame: rect(32, 32, 476, 22))
        placements.append(atom(allocation.storyLead, rect(32, 70, 456, 108), .lead, 3))
        if let support = allocation.storySupport {
            placements.append(atom(support, rect(32, 188, 418, 62), .support, 3))
        }
        return placements
    }

    private static func oceanAtoms(
        _ allocation: ContentAllocationPlan
    ) -> [ResolvedCoverAtomPlacement] {
        var placements = [atom(allocation.storyLead, rect(52, 72, 436, 112), .lead, 3, .center)]
        if let support = allocation.storySupport {
            placements.append(atom(support, rect(86, 198, 368, 58), .support, 3, .center))
        }
        return placements
    }

    private static func quietEditorialAtoms(
        _ allocation: ContentAllocationPlan
    ) -> [ResolvedCoverAtomPlacement] {
        var placements = masthead(allocation, frame: rect(48, 44, 444, 22))
        placements.append(atom(allocation.storyLead, rect(64, 166, 396, 190), .lead, 3))
        if let support = allocation.storySupport {
            placements.append(atom(support, rect(64, 380, 312, 76), .support, 3))
        }
        for (index, mark) in allocation.marks.enumerated() {
            placements.append(atom(mark, rect(64, 480 + Double(index) * 30, 180, 22), .mark, 1))
        }
        return placements
    }

    private static func arrangedMedia(
        _ media: [MediaPlacementRecipe],
        heroFrame: CoverRenderRect?,
        secondaryFrames: [CoverRenderRect]
    ) -> [ResolvedCoverMediaPlacement] {
        var secondaryIndex = 0
        return media.compactMap { item -> ResolvedCoverMediaPlacement? in
            let frame: CoverRenderRect
            if item.role == .hero {
                guard let heroFrame else { return nil }
                frame = heroFrame
            } else {
                guard secondaryIndex < secondaryFrames.count else { return nil }
                frame = secondaryFrames[secondaryIndex]
                secondaryIndex += 1
            }
            return mediaAtom(item, frame, item.role == .hero ? 0 : secondaryIndex + 1)
        }
    }

    private static func masthead(
        _ allocation: ContentAllocationPlan,
        frame: CoverRenderRect
    ) -> [ResolvedCoverAtomPlacement] {
        allocation.masthead.prefix(1).map { atom($0, frame, .masthead, 1) }
    }

    private static func atom(
        _ atom: CoverContentAtom,
        _ frame: CoverRenderRect,
        _ role: CoverTextRole,
        _ lineLimit: Int,
        _ alignment: CoverTextAlignmentToken = .leading
    ) -> ResolvedCoverAtomPlacement {
        ResolvedCoverAtomPlacement(
            atomID: atom.id,
            frame: frame,
            textRole: role,
            alignment: alignment,
            lineLimit: lineLimit
        )
    }

    private static func mediaAtom(
        _ media: MediaPlacementRecipe,
        _ frame: CoverRenderRect,
        _ zIndex: Int
    ) -> ResolvedCoverMediaPlacement {
        ResolvedCoverMediaPlacement(
            mediaID: media.mediaID,
            frame: frame,
            cropMode: media.cropMode,
            treatment: media.treatment,
            zIndex: zIndex
        )
    }

    private static func rect(
        _ x: Double,
        _ y: Double,
        _ width: Double,
        _ height: Double
    ) -> CoverRenderRect {
        CoverRenderRect(x: x, y: y, width: width, height: height)
    }
}
