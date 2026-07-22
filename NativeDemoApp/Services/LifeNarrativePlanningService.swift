import Foundation

enum LifeNarrativeScope: String, Codable, Equatable {
    case day
    case week
    case month

    var periodLead: String {
        switch self {
        case .day: return "今天"
        case .week: return "这周"
        case .month: return "这个月"
        }
    }
}

enum LifeNarrativeMaturity: String, Codable, Equatable {
    case empty
    case factual
    case contextual
    case echoEligible
}

enum LifeNarrativeSignalKind: String, Codable, Equatable {
    case userText
    case photo
    case change
    case structuredScene
    case rhythm
    case stableMark
}

enum LifeNarrativeSignalRole: String, Codable, Equatable, Hashable {
    case lead
    case support
    case mark
    case evidence
}

struct LifeNarrativeSignal: Equatable {
    let id: String
    let kind: LifeNarrativeSignalKind
    let label: String
    let fact: String
    let evidenceItemIDs: [UUID]
    let confidence: Int
    let informationGain: Int
    let narrativeValue: Int
    let representativeness: Int
    let isAdministrative: Bool
    let isSensitive: Bool
    let isStable: Bool
}

struct LifeNarrativePlan: Equatable {
    let scope: LifeNarrativeScope
    let sourceRevision: Int
    let maturity: LifeNarrativeMaturity
    let headline: String
    let summary: String
    let supportingLine: String?
    let leadSignalID: String?
    let signalsByRole: [LifeNarrativeSignalRole: [LifeNarrativeSignal]]

    var markLabels: [String] {
        signalsByRole[.mark, default: []].map(\.label)
    }
}

struct LifeNarrativePlanningInput {
    let scope: LifeNarrativeScope
    let sourceRevision: Int
    let items: [HomeItem]
    let previousItems: [HomeItem]
    let now: Date
    let recentLeadSignalIDs: Set<String>
}

enum LifeNarrativeSignalPolicy {
    private static let sensitiveCategories: Set<HomeItem.Category> = [.health]
    private static let highRiskTerms = [
        "医院", "门诊", "诊所", "体检", "买药", "用药", "贷款", "借款", "还款",
        "成人", "账号", "密码", "验证码", "身份证", "银行卡", "地址"
    ]
    private static let administrativeTerms = [
        "话费", "流量包", "手机充值", "宽带", "水费", "电费", "燃气费", "物业费",
        "房租", "充值", "停车", "过路费", "高速费", "会员续费", "自动续费", "订阅",
        "缴费", "账单还款"
    ]

    static func makePlan(_ input: LifeNarrativePlanningInput) -> LifeNarrativePlan {
        let sourceRows = input.items
            .filter { $0.amount > 0 && $0.draftMeta?.status != .pending }
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt { return lhs.id.uuidString < rhs.id.uuidString }
                return lhs.createdAt < rhs.createdAt
            }
        let rows = sourceRows.filter { !isSensitive($0) }
        let previousRows = input.previousItems.filter {
            $0.amount > 0 && $0.draftMeta?.status != .pending && !isSensitive($0)
        }
        let activeDays = Set(rows.map { Calendar.current.startOfDay(for: $0.createdAt) }).count
        let maturity = maturity(
            recordCount: rows.count,
            activeDays: activeDays,
            hasPhoto: rows.contains { photoNarrativeValue(for: $0) >= 65 }
        )

        guard !rows.isEmpty else {
            let hasPrivateRows = !sourceRows.isEmpty
            return LifeNarrativePlan(
                scope: input.scope,
                sourceRevision: input.sourceRevision,
                maturity: hasPrivateRows ? .factual : .empty,
                headline: hasPrivateRows ? privateHeadline(for: input.scope) : emptyHeadline(for: input.scope),
                summary: hasPrivateRows ? "这段记录先留给你自己，不在故事里展开。" : emptySummary(for: input.scope),
                supportingLine: nil,
                leadSignalID: nil,
                signalsByRole: [:]
            )
        }

        let narrativeRows = rows.filter { !isAdministrativeRecord($0) }
        let previousNarrativeRows = previousRows.filter { !isAdministrativeRecord($0) }
        let administrativeRows = rows.filter { isAdministrativeRecord($0) }
        let previousAdministrativeRows = previousRows.filter { isAdministrativeRecord($0) }
        let sceneGroups = Dictionary(grouping: narrativeRows) { LifeSceneSemanticService.classify($0).kind }
        let previousSceneGroups = Dictionary(grouping: previousNarrativeRows) {
            LifeSceneSemanticService.classify($0).kind
        }
        var candidates: [LifeNarrativeSignal] = []

        if let userSignal = userTextSignal(from: narrativeRows) {
            candidates.append(userSignal)
        }
        if let photoSignal = photoSignal(from: narrativeRows) {
            candidates.append(photoSignal)
        }
        candidates.append(contentsOf: changeSignals(current: sceneGroups, previous: previousSceneGroups, scope: input.scope))
        if let administrativeEvidence = administrativeEvidenceSignal(
            current: administrativeRows,
            previous: previousAdministrativeRows,
            scope: input.scope
        ) {
            candidates.append(administrativeEvidence)
        }
        candidates.append(contentsOf: structuredSceneSignals(from: sceneGroups))
        candidates.append(
            LifeNarrativeSignal(
                id: "rhythm:\(input.scope.rawValue):\(rows.count):\(activeDays)",
                kind: .rhythm,
                label: "记录节奏",
                fact: rhythmFact(scope: input.scope, recordCount: rows.count, activeDays: activeDays),
                evidenceItemIDs: rows.map(\.id),
                confidence: 100,
                informationGain: rows.count == 1 ? 52 : 66,
                narrativeValue: 48,
                representativeness: min(70, 24 + activeDays * 8),
                isAdministrative: false,
                isSensitive: false,
                isStable: false
            )
        )

        let markSignals = stableMarkSignals(
            from: sceneGroups,
            previous: previousSceneGroups
        )
        candidates.append(contentsOf: markSignals)

        let ranked = candidates
            .filter { !$0.isSensitive }
            .sorted { lhs, rhs in
                let leftScore = narrativeScore(lhs, recentLeadSignalIDs: input.recentLeadSignalIDs)
                let rightScore = narrativeScore(rhs, recentLeadSignalIDs: input.recentLeadSignalIDs)
                if leftScore == rightScore {
                    if lhs.confidence == rhs.confidence { return lhs.id < rhs.id }
                    return lhs.confidence > rhs.confidence
                }
                return leftScore > rightScore
            }

        let lead = ranked.first(where: isEligibleLead)
            ?? ranked.first(where: { $0.kind == .rhythm })
        let support = ranked.first { signal in
            guard let lead,
                  signal.id != lead.id,
                  signal.kind != .stableMark,
                  signal.narrativeValue >= 55,
                  !signal.isAdministrative,
                  normalized(signal.fact) != normalized(lead.fact) else {
                return false
            }
            return signalsAreCoherent(lead, signal)
        }
        let marks = Array(markSignals.filter { !$0.isAdministrative }.prefix(2))
        let headline = headline(scope: input.scope, rows: rows, activeDays: activeDays, lead: lead)
        let summary = summary(
            scope: input.scope,
            rows: rows,
            activeDays: activeDays,
            lead: lead,
            marks: marks
        )

        var roles: [LifeNarrativeSignalRole: [LifeNarrativeSignal]] = [:]
        if let lead { roles[.lead] = [lead] }
        if let support { roles[.support] = [support] }
        if !marks.isEmpty { roles[.mark] = marks }
        let rankedEvidence = ranked.filter { $0.kind != .stableMark }
        var evidence = Array(rankedEvidence.prefix(4))
        if let administrativeEvidence = rankedEvidence.first(where: \.isAdministrative),
           !evidence.contains(where: { $0.id == administrativeEvidence.id }) {
            if evidence.isEmpty {
                evidence = [administrativeEvidence]
            } else {
                evidence[evidence.index(before: evidence.endIndex)] = administrativeEvidence
            }
        }
        roles[.evidence] = evidence

        return LifeNarrativePlan(
            scope: input.scope,
            sourceRevision: input.sourceRevision,
            maturity: maturity,
            headline: headline,
            summary: summary,
            supportingLine: support?.fact,
            leadSignalID: lead?.id,
            signalsByRole: roles
        )
    }

    static func narrativeScore(
        _ signal: LifeNarrativeSignal,
        recentLeadSignalIDs: Set<String>
    ) -> Int {
        var score = signal.informationGain
            + signal.narrativeValue
            + signal.confidence / 5
            + min(signal.representativeness / 4, 20)
        if recentLeadSignalIDs.contains(signal.id) {
            score -= signal.isStable ? 70 : 36
        }
        if signal.kind == .stableMark { score -= 30 }
        if signal.isAdministrative { score -= 55 }
        if signal.isSensitive { score -= 1_000 }
        return score
    }

    static func isEligibleLead(_ signal: LifeNarrativeSignal) -> Bool {
        guard !signal.isSensitive,
              !signal.isAdministrative,
              signal.kind != .stableMark else {
            return false
        }
        switch signal.kind {
        case .userText:
            return signal.narrativeValue >= 70
        case .photo:
            return signal.narrativeValue >= 65
        case .change:
            return signal.informationGain >= 70 && signal.narrativeValue >= 55
        case .structuredScene:
            return signal.narrativeValue >= 58
        case .rhythm:
            return true
        case .stableMark:
            return false
        }
    }

    static func maturity(recordCount: Int, activeDays: Int, hasPhoto: Bool) -> LifeNarrativeMaturity {
        guard recordCount > 0 else { return .empty }
        if recordCount <= 2 && !hasPhoto { return .factual }
        if recordCount >= 5 && activeDays >= 3 { return .echoEligible }
        return .contextual
    }

    static func recentStableSignalIDs(from items: [HomeItem]) -> Set<String> {
        let safeRows = publishableItems(from: items).filter { !isAdministrativeRecord($0) }
        return Set(
            Dictionary(grouping: safeRows) { LifeSceneSemanticService.classify($0).kind }
                .compactMap { kind, rows -> String? in
                    guard kind != .general, rows.count >= 2 else { return nil }
                    return "scene:\(kind.rawValue)"
                }
        )
    }

    static func publishableItems(from items: [HomeItem]) -> [HomeItem] {
        items.filter {
            $0.amount > 0 && $0.draftMeta?.status != .pending && !isSensitive($0)
        }
    }

    static func isAdministrativeRecord(_ item: HomeItem) -> Bool {
        isAdministrative(
            item,
            sceneKind: LifeSceneSemanticService.classify(item).kind
        )
    }

    private static func userTextSignal(from rows: [HomeItem]) -> LifeNarrativeSignal? {
        rows.reversed().compactMap { item -> LifeNarrativeSignal? in
            guard item.userEditedTitle == true,
                  !isSensitive(item),
                  !isAdministrative(
                      item,
                      sceneKind: LifeSceneSemanticService.classify(item).kind
                  ),
                  EchoAnchorService.shared.isEligibleLifeTraceTitle(item.title, item: item),
                  UserContentRiskService.shared.isAllowedManualNote(item.title, allowEmpty: false) else {
                return nil
            }
            let title = compact(item.title, limit: 20)
            return LifeNarrativeSignal(
                id: "user:\(item.id.uuidString)",
                kind: .userText,
                label: title,
                fact: "\(item.createdAt.zhBillDateOnly)记下了「\(title)」。",
                evidenceItemIDs: [item.id],
                confidence: 100,
                informationGain: 100,
                narrativeValue: 100,
                representativeness: 24,
                isAdministrative: false,
                isSensitive: false,
                isStable: false
            )
        }.first
    }

    private static func photoSignal(from rows: [HomeItem]) -> LifeNarrativeSignal? {
        rows
            .filter { $0.hasMemoryImages && !isSensitive($0) }
            .map { item in (item, photoNarrativeValue(for: item)) }
            .filter { $0.1 >= 65 }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 { return lhs.0.createdAt > rhs.0.createdAt }
                return lhs.1 > rhs.1
            }
            .first
            .map { pair in
                let item = pair.0
                let narrativeValue = pair.1
                let safeTitle = EchoAnchorService.shared.isEligibleLifeTraceTitle(item.title, item: item)
                    ? compact(item.title, limit: 18)
                    : item.category.label
                return LifeNarrativeSignal(
                    id: "photo:\(item.id.uuidString)",
                    kind: .photo,
                    label: safeTitle,
                    fact: "\(item.createdAt.zhBillDateOnly)那笔「\(safeTitle)」还留着一张照片。",
                    evidenceItemIDs: [item.id],
                    confidence: 100,
                    informationGain: 92,
                    narrativeValue: narrativeValue,
                    representativeness: 28,
                    isAdministrative: false,
                    isSensitive: false,
                    isStable: false
                )
            }
    }

    private static func changeSignals(
        current: [LifeSceneKind: [HomeItem]],
        previous: [LifeSceneKind: [HomeItem]],
        scope: LifeNarrativeScope
    ) -> [LifeNarrativeSignal] {
        current.compactMap { kind, rows -> LifeNarrativeSignal? in
            guard let sample = rows.last, !isSensitive(sample) else { return nil }
            let previousRows = previous[kind, default: []]
            let delta = rows.count - previousRows.count
            guard rows.count >= 2,
                  previousRows.isEmpty || abs(delta) >= 2 else { return nil }
            let signal = LifeSceneSemanticService.classify(sample)
            let fact: String
            if previousRows.isEmpty {
                fact = "\(signal.label)在\(scope.periodLead)新出现了 \(rows.count) 笔。"
            } else if delta > 0 {
                fact = "\(signal.label)比上一段多了 \(delta) 笔。"
            } else {
                fact = "\(signal.label)比上一段少了 \(-delta) 笔。"
            }
            return LifeNarrativeSignal(
                id: "change:\(kind.rawValue):\(delta > 0 ? "up" : "down")",
                kind: .change,
                label: signal.label,
                fact: fact,
                evidenceItemIDs: rows.map(\.id) + previousRows.map(\.id),
                confidence: 94,
                informationGain: 88,
                narrativeValue: sceneNarrativeValue(signal.kind, administrative: false),
                representativeness: min(80, 34 + rows.count * 8),
                isAdministrative: false,
                isSensitive: false,
                isStable: false
            )
        }
    }

    private static func administrativeEvidenceSignal(
        current: [HomeItem],
        previous: [HomeItem],
        scope: LifeNarrativeScope
    ) -> LifeNarrativeSignal? {
        guard !current.isEmpty else { return nil }
        let delta = current.count - previous.count
        let hasComparableChange = !previous.isEmpty && abs(delta) >= 2
        let isNewGroup = previous.isEmpty && current.count >= 2
        let fact: String
        let id: String
        let kind: LifeNarrativeSignalKind
        let informationGain: Int
        if hasComparableChange {
            let direction = delta > 0 ? "多" : "少"
            fact = "固定账单比上一段\(direction)了 \(abs(delta)) 笔。"
            id = "administrative:change:\(delta > 0 ? "up" : "down")"
            kind = .change
            informationGain = 88
        } else if isNewGroup {
            fact = "\(scope.periodLead)新记下了 \(current.count) 笔固定账单。"
            id = "administrative:change:new"
            kind = .change
            informationGain = 76
        } else {
            fact = "\(scope.periodLead)有 \(current.count) 笔固定账单，保留在数字依据里。"
            id = "administrative:evidence"
            kind = .structuredScene
            informationGain = 34
        }
        return LifeNarrativeSignal(
            id: id,
            kind: kind,
            label: "固定账单",
            fact: fact,
            evidenceItemIDs: hasComparableChange
                ? current.map(\.id) + previous.map(\.id)
                : current.map(\.id),
            confidence: 100,
            informationGain: informationGain,
            narrativeValue: 22,
            representativeness: min(56, 24 + current.count * 6),
            isAdministrative: true,
            isSensitive: false,
            isStable: !hasComparableChange && !isNewGroup
        )
    }

    private static func structuredSceneSignals(
        from groups: [LifeSceneKind: [HomeItem]]
    ) -> [LifeNarrativeSignal] {
        groups.compactMap { kind, rows -> LifeNarrativeSignal? in
            guard let sample = rows.last,
                  !isSensitive(sample) else { return nil }
            let scene = LifeSceneSemanticService.classify(sample)
            guard scene.confidenceTier != .weak,
                  kind != .general else { return nil }
            let contextual = rows.contains { item in
                item.memoryContext?.weatherKind != nil
                    || item.scenePackId != nil
                    || (item.hasMemoryImages && photoNarrativeValue(for: item) >= 65)
            }
            guard contextual || rows.count >= 2 else { return nil }
            return LifeNarrativeSignal(
                id: "scene:\(kind.rawValue)",
                kind: .structuredScene,
                label: scene.label,
                fact: "\(scene.label)在这段记录里出现了 \(rows.count) 次。",
                evidenceItemIDs: rows.map(\.id),
                confidence: scene.confidenceTier == .strong ? 92 : 84,
                informationGain: contextual ? 74 : 58,
                narrativeValue: sceneNarrativeValue(scene.kind, administrative: false),
                representativeness: min(92, 38 + rows.count * 9),
                isAdministrative: false,
                isSensitive: false,
                isStable: rows.count >= 2
            )
        }
    }

    private static func stableMarkSignals(
        from groups: [LifeSceneKind: [HomeItem]],
        previous: [LifeSceneKind: [HomeItem]]
    ) -> [LifeNarrativeSignal] {
        groups.compactMap { kind, rows -> LifeNarrativeSignal? in
            guard let sample = rows.last,
                  !isSensitive(sample),
                  kind != .general else { return nil }
            let previousRows = previous[kind, default: []]
            let representativeCount = rows.count + previousRows.count
            guard representativeCount >= 2 else { return nil }
            let signal = LifeSceneSemanticService.classify(sample)
            return LifeNarrativeSignal(
                id: "mark:\(kind.rawValue)",
                kind: .stableMark,
                label: signal.label,
                fact: "生活线索 · \(signal.label)",
                evidenceItemIDs: rows.map(\.id) + previousRows.map(\.id),
                confidence: min(100, 70 + representativeCount * 6),
                informationGain: 24,
                narrativeValue: sceneNarrativeValue(signal.kind, administrative: false),
                representativeness: min(100, 46 + representativeCount * 10),
                isAdministrative: false,
                isSensitive: false,
                isStable: true
            )
        }
        .sorted { lhs, rhs in
            if lhs.evidenceItemIDs.count == rhs.evidenceItemIDs.count { return lhs.id < rhs.id }
            return lhs.evidenceItemIDs.count > rhs.evidenceItemIDs.count
        }
    }

    private static func headline(
        scope: LifeNarrativeScope,
        rows: [HomeItem],
        activeDays: Int,
        lead: LifeNarrativeSignal?
    ) -> String {
        if rows.count == 1 {
            return "\(scope.periodLead)只留下一笔记录"
        }
        switch lead?.kind {
        case .userText:
            return "\(scope.periodLead)有一句具体的话"
        case .photo:
            return "\(scope.periodLead)留下了一张具体的照片"
        case .change:
            return "\(scope.periodLead)有一处明显变化"
        default:
            return "\(scope.periodLead)有 \(max(activeDays, 1)) 个记录日"
        }
    }

    private static func summary(
        scope: LifeNarrativeScope,
        rows: [HomeItem],
        activeDays: Int,
        lead: LifeNarrativeSignal?,
        marks: [LifeNarrativeSignal]
    ) -> String {
        guard let lead else {
            return rhythmFact(scope: scope, recordCount: rows.count, activeDays: activeDays)
        }
        if lead.kind == .rhythm || lead.kind == .stableMark {
            let rhythm = rhythmFact(scope: scope, recordCount: rows.count, activeDays: activeDays)
            let markText = marks.prefix(2).map(\.label).joined(separator: "、")
            guard rows.count > 1, !markText.isEmpty else { return rhythm }
            return "\(rhythm)\(markText)留在生活线索里。"
        }
        return lead.fact
    }

    private static func signalsAreCoherent(
        _ lead: LifeNarrativeSignal,
        _ candidate: LifeNarrativeSignal
    ) -> Bool {
        let leadIDs = Set(lead.evidenceItemIDs)
        let candidateIDs = Set(candidate.evidenceItemIDs)
        if !leadIDs.isDisjoint(with: candidateIDs) { return true }
        if normalized(lead.label) == normalized(candidate.label) { return true }
        return lead.kind == .rhythm && candidate.kind == .change
    }

    private static func photoNarrativeValue(for item: HomeItem) -> Int {
        guard !isAdministrative(
            item,
            sceneKind: LifeSceneSemanticService.classify(item).kind
        ) else {
            return 18
        }
        switch item.memoryAnchorRole {
        case .moment: return 96
        case .place: return 90
        case .object: return item.userEditedTitle == true ? 82 : 70
        case .careRecord: return 68
        case .receipt: return 18
        case nil:
            let scene = LifeSceneSemanticService.classify(item)
            let base = sceneNarrativeValue(scene.kind, administrative: false)
            return item.userEditedTitle == true ? max(base, 82) : 18
        }
    }

    private static func sceneNarrativeValue(
        _ kind: LifeSceneKind,
        administrative: Bool
    ) -> Int {
        if administrative { return 22 }
        switch kind {
        case .social, .leisure, .lodging:
            return 90
        case .fitness, .bodyCare:
            return 82
        case .breakfast, .quickMeal, .coffee, .workMeal:
            return 74
        case .commute, .cityRoute:
            return 70
        case .shopping, .groceries:
            return 62
        case .errand:
            return 58
        case .convenienceSupply, .homeSupply:
            return 46
        case .telecomBill:
            return 18
        case .medicalVisit, .medicineCare:
            return 0
        case .general:
            return 36
        }
    }

    private static func isAdministrative(
        _ item: HomeItem,
        sceneKind: LifeSceneKind
    ) -> Bool {
        if sceneKind == .telecomBill { return true }
        let text = "\(item.title) \(item.category.rawValue)".lowercased()
        return administrativeTerms.contains {
            text.localizedCaseInsensitiveContains($0)
        }
    }

    private static func rhythmFact(scope: LifeNarrativeScope, recordCount: Int, activeDays: Int) -> String {
        if recordCount == 1 { return "\(scope.periodLead)只记下一笔，先放在这里。" }
        return "\(scope.periodLead)有 \(recordCount) 笔记录，分布在 \(max(activeDays, 1)) 个记录日。"
    }

    private static func emptyHeadline(for scope: LifeNarrativeScope) -> String {
        switch scope {
        case .day: return "今天还没有记录"
        case .week: return "这周还没有记录"
        case .month: return "这个月还没有记录"
        }
    }

    private static func privateHeadline(for scope: LifeNarrativeScope) -> String {
        "\(scope.periodLead)有记录，先不展开"
    }

    private static func emptySummary(for scope: LifeNarrativeScope) -> String {
        switch scope {
        case .day: return "今天这一页暂时还是空的。"
        case .week: return "这周暂时还没有可以整理的内容。"
        case .month: return "这个月暂时还没有可以回看的内容。"
        }
    }

    private static func isSensitive(_ item: HomeItem) -> Bool {
        if sensitiveCategories.contains(item.category) { return true }
        let text = "\(item.title) \(item.displayEmotionTag)"
        return highRiskTerms.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private static func normalized(_ text: String) -> String {
        text.lowercased().filter { !$0.isWhitespace && !"，。！？；：,.!?;:".contains($0) }
    }

    private static func compact(_ text: String, limit: Int) -> String {
        let cleaned = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.count > limit ? String(cleaned.prefix(limit)) : cleaned
    }
}
