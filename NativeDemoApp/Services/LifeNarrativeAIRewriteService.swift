import Foundation

extension Notification.Name {
    static let narrativeAIConfigurationDidChange = Notification.Name(
        "narrativeAIConfigurationDidChange"
    )
    static let narrativeAIRewriteDidChange = Notification.Name(
        "narrativeAIRewriteDidChange"
    )
}

struct LifeNarrativeAIRewriteKey: Hashable {
    let scope: String
    let sourceRevision: Int
    let periodKey: String
    let ruleVersion: Int
}

struct LifeNarrativeAIFact: Codable, Equatable {
    let id: String
    let role: String
    let kind: String
    let label: String
    let statement: String
    let evidenceCount: Int
}

struct LifeNarrativeAIFactPackRequest: Codable, Equatable {
    let scope: String
    let periodKey: String
    let mode: String
    let facts: [LifeNarrativeAIFact]
}

struct LifeNarrativeAIRewriteCandidate: Codable, Equatable {
    let scope: String
    let periodKey: String
    let headline: String
    let summary: String
    let supportingLine: String?
    let evidenceIDs: [String]
}

struct LifeNarrativeAIRewriteBatchResponse: Codable, Equatable {
    let rewrites: [LifeNarrativeAIRewriteCandidate]
}

struct LifeNarrativeAIRewrite: Equatable {
    let key: LifeNarrativeAIRewriteKey
    let headline: String
    let summary: String
    let supportingLine: String?
    let evidenceIDs: [String]
    let evidenceItemIDs: [UUID]
}

struct PreparedLifeNarrativeAIFactPack {
    let key: LifeNarrativeAIRewriteKey
    let request: LifeNarrativeAIFactPackRequest
    let localPlan: LifeNarrativePlan
    let echo: LifeNarrativeEcho?
    let itemIDsByFactID: [String: [UUID]]
}

enum LifeNarrativeAIPreparationPolicy {
    static let ruleVersion = 5

    static func prepareFactPacks(
        items: [HomeItem],
        sourceRevision: Int,
        now: Date,
        calendar baseCalendar: Calendar = .current
    ) -> [PreparedLifeNarrativeAIFactPack] {
        [LifeNarrativeScope.day, .week, .month].compactMap { scope in
            prepareFactPack(
                scope: scope,
                items: items,
                sourceRevision: sourceRevision,
                now: now,
                calendar: baseCalendar
            )
        }
    }

    static func key(
        scope: LifeNarrativeScope,
        sourceRevision: Int,
        now: Date,
        calendar baseCalendar: Calendar = .current
    ) -> LifeNarrativeAIRewriteKey {
        let calendar = periodCalendar(scope: scope, base: baseCalendar)
        return LifeNarrativeAIRewriteKey(
            scope: scope.rawValue,
            sourceRevision: sourceRevision,
            periodKey: periodKey(scope: scope, now: now, calendar: calendar),
            ruleVersion: ruleVersion
        )
    }

    private static func prepareFactPack(
        scope: LifeNarrativeScope,
        items: [HomeItem],
        sourceRevision: Int,
        now: Date,
        calendar baseCalendar: Calendar
    ) -> PreparedLifeNarrativeAIFactPack? {
        let calendar = periodCalendar(scope: scope, base: baseCalendar)
        guard let current = periodInterval(scope: scope, date: now, calendar: calendar),
              let previousStart = previousPeriodStart(scope: scope, currentStart: current.start, calendar: calendar) else {
            return nil
        }
        let currentItems = items.filter {
            $0.createdAt >= current.start && $0.createdAt < current.end && $0.createdAt <= now
        }
        guard !currentItems.isEmpty else { return nil }
        let previousItems = items.filter { $0.createdAt >= previousStart && $0.createdAt < current.start }
        let journeyFact = LifeJourneyFactService.primaryFact(
            in: currentItems,
            calendar: calendar
        )
        let echo = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: scope,
                sourceRevision: sourceRevision,
                items: items,
                now: now,
                recentEchoIDs: []
            ),
            calendar: calendar
        )
        let plan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: scope,
                sourceRevision: sourceRevision,
                items: currentItems,
                previousItems: previousItems,
                now: now,
                recentLeadSignalIDs: LifeNarrativeSignalPolicy.recentStableSignalIDs(from: previousItems),
                relationshipEcho: echo,
                journeyFact: journeyFact
            )
        )
        // Cross-city routes and their evidence stay entirely local. The certified local
        // journey wording is already complete and must not be replaced by a remote rewrite.
        if plan.leadSignalID == journeyFact?.id {
            return nil
        }
        let roleOrder: [LifeNarrativeSignalRole] = [.lead, .support, .mark, .evidence]
        let relationshipMode = echo.map { plan.leadSignalID == $0.id } ?? false
        var seenSignalIDs = Set<String>()
        var facts: [LifeNarrativeAIFact] = []
        var itemIDsByFactID: [String: [UUID]] = [:]

        for role in roleOrder {
            for signal in plan.signalsByRole[role, default: []] {
                guard signal.kind != .userText,
                      !signal.id.hasPrefix("journey:"),
                      (!relationshipMode || signal.id == echo?.id),
                      seenSignalIDs.insert(signal.id).inserted else {
                    continue
                }
                let factID = "F\(facts.count + 1)"
                let isRelationshipFact = signal.id == echo?.id
                facts.append(
                    LifeNarrativeAIFact(
                        id: factID,
                        role: role.rawValue,
                        kind: isRelationshipFact ? (echo?.kind.rawValue ?? signal.kind.rawValue) : signal.kind.rawValue,
                        label: redactedLabel(for: signal),
                        statement: isRelationshipFact ? (echo?.line ?? signal.fact) : redactedStatement(for: signal, scope: scope),
                        evidenceCount: signal.evidenceItemIDs.count
                    )
                )
                itemIDsByFactID[factID] = signal.evidenceItemIDs
                if facts.count >= 6 { break }
            }
            if facts.count >= 6 { break }
        }

        if let echo,
           !seenSignalIDs.contains(echo.id),
           facts.count < 6 {
            let factID = "F\(facts.count + 1)"
            facts.append(
                LifeNarrativeAIFact(
                    id: factID,
                    role: "echo",
                    kind: echo.kind.rawValue,
                    label: echo.label,
                    statement: echo.line,
                    evidenceCount: echo.currentEvidenceItemIDs.count + echo.historicalEvidenceItemIDs.count
                )
            )
            itemIDsByFactID[factID] = echo.currentEvidenceItemIDs + echo.historicalEvidenceItemIDs
        }
        guard let first = facts.first, first.role == LifeNarrativeSignalRole.lead.rawValue else { return nil }
        let rewriteKey = Self.key(
            scope: scope,
            sourceRevision: sourceRevision,
            now: now,
            calendar: calendar
        )
        return PreparedLifeNarrativeAIFactPack(
            key: rewriteKey,
            request: LifeNarrativeAIFactPackRequest(
                scope: scope.rawValue,
                periodKey: rewriteKey.periodKey,
                mode: relationshipMode ? "relationship" : "factual",
                facts: facts
            ),
            localPlan: plan,
            echo: echo,
            itemIDsByFactID: itemIDsByFactID
        )
    }

    private static func redactedLabel(for signal: LifeNarrativeSignal) -> String {
        switch signal.kind {
        case .userText: return "本机原文"
        case .photo: return "有真实照片的记录"
        default: return signal.label
        }
    }

    private static func redactedStatement(
        for signal: LifeNarrativeSignal,
        scope: LifeNarrativeScope
    ) -> String {
        switch signal.kind {
        case .userText:
            return "\(scope.periodLead)的具体原文只在本机展示。"
        case .photo:
            return "\(scope.periodLead)有 1 条记录带真实照片。"
        default:
            return signal.fact
        }
    }

    private static func periodCalendar(scope: LifeNarrativeScope, base: Calendar) -> Calendar {
        guard scope == .week else { return base }
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = base.timeZone
        calendar.firstWeekday = 2
        return calendar
    }

    private static func periodInterval(
        scope: LifeNarrativeScope,
        date: Date,
        calendar: Calendar
    ) -> DateInterval? {
        switch scope {
        case .day:
            let start = calendar.startOfDay(for: date)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
            return DateInterval(start: start, end: end)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)
        case .month:
            return calendar.dateInterval(of: .month, for: date)
        }
    }

    private static func previousPeriodStart(
        scope: LifeNarrativeScope,
        currentStart: Date,
        calendar: Calendar
    ) -> Date? {
        switch scope {
        case .day: return calendar.date(byAdding: .day, value: -1, to: currentStart)
        case .week: return calendar.date(byAdding: .weekOfYear, value: -1, to: currentStart)
        case .month: return calendar.date(byAdding: .month, value: -1, to: currentStart)
        }
    }

    private static func periodKey(
        scope: LifeNarrativeScope,
        now: Date,
        calendar: Calendar
    ) -> String {
        switch scope {
        case .day:
            let components = calendar.dateComponents([.year, .month, .day], from: now)
            return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
        case .week:
            return SummaryPlaybackQuotaStore().currentWeekKey(now: now)
        case .month:
            let components = calendar.dateComponents([.year, .month], from: now)
            return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
        }
    }
}

enum LifeNarrativeAIRewriteValidationPolicy {
    private static let forbiddenTerms = [
        "治" + "愈", "焦虑", "压力", "辛" + "苦", "努力", "终于", "一定", "因为", "说明你",
        "建议", "应该", "需要减少", "预算", "省钱", "控制消费", "健康诊断", "财务风险",
        "投资", "收益", "联系方式", "手机号", "身份证", "银行卡", "密码", "验证码",
        "主要日常", "构成了你的生活", "生活重心", "最能代表你"
    ]
    private static let relationshipKinds: Set<String> = [
        LifeNarrativeEchoKind.repeatRhythm.rawValue,
        LifeNarrativeEchoKind.returnAfterGap.rawValue,
        LifeNarrativeEchoKind.comparableChange.rawValue,
        LifeNarrativeEchoKind.contextReturn.rawValue,
        LifeNarrativeEchoKind.newContextPair.rawValue,
    ]

    static func validate(
        _ candidate: LifeNarrativeAIRewriteCandidate,
        against pack: PreparedLifeNarrativeAIFactPack
    ) -> LifeNarrativeAIRewrite? {
        guard candidate.scope == pack.key.scope,
              candidate.periodKey == pack.key.periodKey else { return nil }
        let headline = clean(candidate.headline)
        let summary = clean(candidate.summary)
        let supporting = candidate.supportingLine.flatMap(cleanOptional)
        guard (4...32).contains(headline.count),
              (6...64).contains(summary.count),
              supporting.map({ $0.count <= 48 }) ?? true,
              normalized(headline) != normalized(summary) else { return nil }
        let combined = [headline, summary, supporting].compactMap { $0 }.joined(separator: " ")
        guard !forbiddenTerms.contains(where: { combined.localizedCaseInsensitiveContains($0) }),
              !combined.localizedCaseInsensitiveContains("http"),
              !combined.contains("@") else { return nil }

        let allowedFactIDs = Set(pack.request.facts.map(\.id))
        let citedFactIDs = Set(candidate.evidenceIDs)
        guard !citedFactIDs.isEmpty,
              citedFactIDs.isSubset(of: allowedFactIDs),
              let leadFactID = pack.request.facts.first(where: { $0.role == "lead" })?.id,
              citedFactIDs.contains(leadFactID) else { return nil }
        let leadFactKind = pack.request.facts.first(where: { $0.role == "lead" })?.kind
        let leadIsRelationship = leadFactKind.map { relationshipKinds.contains($0) } ?? false
        guard (pack.request.mode == "relationship" && leadIsRelationship)
                || (pack.request.mode == "factual" && !leadIsRelationship) else {
            return nil
        }

        let allowedNumbers = Set(pack.request.facts.flatMap { numbers(in: $0.statement) + [$0.evidenceCount] })
        guard Set(numbers(in: combined)).isSubset(of: allowedNumbers) else { return nil }
        let citedStatements = pack.request.facts
            .filter { citedFactIDs.contains($0.id) }
            .map(\.statement)
            .joined(separator: " ")
        guard relationshipClaimsAreSupported(output: combined, sources: citedStatements) else { return nil }
        let evidenceItemIDs = candidate.evidenceIDs.flatMap { pack.itemIDsByFactID[$0, default: []] }
        guard !evidenceItemIDs.isEmpty else { return nil }

        return LifeNarrativeAIRewrite(
            key: pack.key,
            headline: headline,
            summary: summary,
            supportingLine: supporting,
            evidenceIDs: candidate.evidenceIDs,
            evidenceItemIDs: Array(Set(evidenceItemIDs)).sorted { $0.uuidString < $1.uuidString }
        )
    }

    private static func clean(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanOptional(_ text: String) -> String? {
        let cleaned = clean(text)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func normalized(_ text: String) -> String {
        text.lowercased().filter { !$0.isWhitespace && !"，。！？；：,.!?;:".contains($0) }
    }

    private static func numbers(in text: String) -> [Int] {
        guard let expression = try? NSRegularExpression(pattern: #"\d+"#) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.matches(in: text, range: range).compactMap { match in
            guard let swiftRange = Range(match.range, in: text) else { return nil }
            return Int(text[swiftRange])
        }
    }

    private static func relationshipClaimsAreSupported(
        output: String,
        sources: String
    ) -> Bool {
        let claimGroups = [
            ["第一次", "首次"],
            ["重新出现", "再次出现"],
            ["连续"],
            ["上一次"],
            ["周前", "个月前", "天前"],
            ["之后"],
            ["一起出现", "同时出现"],
        ]
        for aliases in claimGroups where aliases.contains(where: { output.contains($0) }) {
            guard aliases.contains(where: { sources.contains($0) }) else { return false }
        }
        let outputClaimsFirst = output.contains("第一次") || output.contains("首次")
        let sourceHasBoundedFirst = (sources.contains("第一次") || sources.contains("首次"))
            && sources.contains("近")
        if outputClaimsFirst,
           sourceHasBoundedFirst,
           !output.contains("近"),
           !output.contains("有记录的周里") {
            return false
        }
        return true
    }
}

final class LifeNarrativeAIRewriteStore: @unchecked Sendable {
    static let shared = LifeNarrativeAIRewriteStore()

    private let lock = NSLock()
    private var rewrites: [LifeNarrativeAIRewriteKey: LifeNarrativeAIRewrite] = [:]

    private init() {}

    func rewrite(for key: LifeNarrativeAIRewriteKey) -> LifeNarrativeAIRewrite? {
        lock.lock()
        defer { lock.unlock() }
        return rewrites[key]
    }

    func publish(_ accepted: [LifeNarrativeAIRewrite], expectedSourceRevision: Int) {
        lock.lock()
        var didChangeTraceRewrite = false
        for rewrite in accepted where rewrite.key.sourceRevision == expectedSourceRevision {
            let affectsTrace = rewrite.key.scope == LifeNarrativeScope.week.rawValue
                || rewrite.key.scope == LifeNarrativeScope.month.rawValue
            if rewrites[rewrite.key] != rewrite,
               affectsTrace {
                didChangeTraceRewrite = true
            }
            rewrites[rewrite.key] = rewrite
        }
        if rewrites.count > 24 {
            let keep = rewrites.keys.sorted { lhs, rhs in
                if lhs.sourceRevision == rhs.sourceRevision { return lhs.periodKey > rhs.periodKey }
                return lhs.sourceRevision > rhs.sourceRevision
            }.prefix(24)
            rewrites = Dictionary(uniqueKeysWithValues: keep.compactMap { key in rewrites[key].map { (key, $0) } })
        }
        lock.unlock()
        if didChangeTraceRewrite {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .narrativeAIRewriteDidChange, object: nil)
            }
        }
    }

    func removeAll() {
        lock.lock()
        rewrites.removeAll()
        lock.unlock()
    }

    func removeAllForTesting() {
        removeAll()
    }
}

actor LifeNarrativeAIPrecomputeCoordinator {
    static let shared = LifeNarrativeAIPrecomputeCoordinator()

    private let reportService = AIReportService()
    private var latestRequestID = UUID()

    func invalidatePendingRewrites() {
        latestRequestID = UUID()
        LifeNarrativeAIRewriteStore.shared.removeAll()
    }

    func prepare(
        items: [HomeItem],
        sourceRevision: Int,
        now: Date,
        settings: AppSettings
    ) async {
        guard settings.useRemoteAI, !items.isEmpty, !LocalStore.isReleaseFixtureMode else { return }
        let requestID = UUID()
        latestRequestID = requestID
        let packs = LifeNarrativeAIPreparationPolicy.prepareFactPacks(
            items: items,
            sourceRevision: sourceRevision,
            now: now
        ).filter { LifeNarrativeAIRewriteStore.shared.rewrite(for: $0.key) == nil }
        guard !packs.isEmpty, !Task.isCancelled else { return }

        guard !KeychainService.loadAccessToken().isEmpty,
              AIUsageLimiter.canUseRemoteAI(limitPerMonth: settings.remoteAIMonthlyLimit) else { return }

        do {
            let response = try await reportService.generateNarrativeRewrites(
                factPacks: packs.map(\.request),
                tone: settings.aiTone
            )
            guard !Task.isCancelled, latestRequestID == requestID else { return }
            let packsByScope = Dictionary(uniqueKeysWithValues: packs.map { ($0.key.scope, $0) })
            var acceptedScopes = Set<String>()
            let accepted: [LifeNarrativeAIRewrite] = response.rewrites.compactMap { candidate -> LifeNarrativeAIRewrite? in
                guard acceptedScopes.insert(candidate.scope).inserted,
                      let pack = packsByScope[candidate.scope] else { return nil }
                return LifeNarrativeAIRewriteValidationPolicy.validate(candidate, against: pack)
            }
            guard !accepted.isEmpty else { return }
            LifeNarrativeAIRewriteStore.shared.publish(
                accepted,
                expectedSourceRevision: sourceRevision
            )
            _ = AIUsageLimiter.consumeOnce(limitPerMonth: settings.remoteAIMonthlyLimit)
        } catch {
            // The local plan is already complete. Remote failure is intentionally silent here.
        }
    }
}
