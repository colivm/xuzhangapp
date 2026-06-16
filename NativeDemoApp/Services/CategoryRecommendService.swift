import Foundation

struct RecordContextSignal: Equatable {
    enum WeatherKind: Equatable {
        case rain
        case snow
        case hot
        case cold
        case normal
    }

    enum DayType: Equatable {
        case workday
        case weekend
    }

    enum TimeBand: Equatable {
        case morning
        case lunch
        case afternoon
        case evening
        case lateNight
        case other
    }

    enum CityContext: Equatable {
        case homeCity
        case awayCity
        case unknown
    }

    enum RoutineContext: Equatable {
        case nearRoutine
        case awayFromRoutine
        case unknown
    }

    let weather: WeatherKind?
    let cityContext: CityContext
    let routineContext: RoutineContext
    let dayType: DayType
    let timeBand: TimeBand

    init(
        referenceDate: Date,
        weather: WeatherSnapshot?,
        cityContext: CityContext = .unknown,
        routineContext: RoutineContext = .unknown
    ) {
        self.weather = Self.weatherKind(from: weather)
        self.cityContext = cityContext
        self.routineContext = routineContext
        self.dayType = Self.dayType(for: referenceDate)
        self.timeBand = Self.timeBand(for: referenceDate)
    }

    private static func weatherKind(from snapshot: WeatherSnapshot?) -> WeatherKind? {
        guard let snapshot else { return nil }
        if let code = snapshot.weatherCode {
            if (51...67).contains(code) || (80...82).contains(code) || code == 95 {
                return .rain
            }
            if (71...77).contains(code) || (85...86).contains(code) {
                return .snow
            }
        }
        if let temp = snapshot.temp {
            if temp >= 30 { return .hot }
            if temp <= 5 { return .cold }
        }
        return .normal
    }

    private static func dayType(for date: Date) -> DayType {
        let weekday = Calendar.current.component(.weekday, from: date)
        return (weekday == 1 || weekday == 7) ? .weekend : .workday
    }

    private static func timeBand(for date: Date) -> TimeBand {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 7..<10: return .morning
        case 11..<14: return .lunch
        case 14..<17: return .afternoon
        case 17..<21: return .evening
        case 22...23, 0..<6: return .lateNight
        default: return .other
        }
    }
}

struct CategoryRecommendInput {
    let amount: Double
    let referenceDate: Date
    let items: [HomeItem]
    let noteDraft: String
    let locked: Bool
    let context: RecordContextSignal?

    init(
        amount: Double,
        referenceDate: Date,
        items: [HomeItem],
        noteDraft: String,
        locked: Bool,
        context: RecordContextSignal? = nil
    ) {
        self.amount = amount
        self.referenceDate = referenceDate
        self.items = items
        self.noteDraft = noteDraft
        self.locked = locked
        self.context = context
    }
}

struct CategoryRecommendResult: Equatable {
    let recommended: HomeItem.Category
    let reasonTag: String?
}

struct CategoryRecommendService {
    private struct ScoreBreakdown {
        var history: Double = 0
        var time: Double = 0
        var amount: Double = 0
        var note: Double = 0
        var context: Double = 0

        var total: Double {
            history * 0.30 + note * 0.25 + time * 0.20 + context * 0.15 + amount * 0.10
        }
    }

    func recommend(input: CategoryRecommendInput) -> CategoryRecommendResult? {
        guard !input.locked, input.amount > 0 else { return nil }

        var scores = Dictionary(
            uniqueKeysWithValues: HomeItem.Category.allCases.map { ($0, ScoreBreakdown()) }
        )
        applyHistoryScores(input: input, scores: &scores)
        applyTimeScores(input: input, scores: &scores)
        applyAmountScores(amount: input.amount, scores: &scores)
        applyNoteScores(note: input.noteDraft, scores: &scores)
        applyContextScores(input: input, scores: &scores)

        let ranked = HomeItem.Category.allCases
            .map { category -> (category: HomeItem.Category, breakdown: ScoreBreakdown, total: Double) in
                let breakdown = scores[category] ?? ScoreBreakdown()
                return (category, breakdown, breakdown.total)
            }
            .sorted { lhs, rhs in
                if lhs.total == rhs.total {
                    return categoryPriority(lhs.category) < categoryPriority(rhs.category)
                }
                return lhs.total > rhs.total
            }

        guard let best = ranked.first else { return nil }
        return CategoryRecommendResult(
            recommended: best.category,
            reasonTag: dominantReason(for: best.breakdown)
        )
    }

    private func applyHistoryScores(
        input: CategoryRecommendInput,
        scores: inout [HomeItem.Category: ScoreBreakdown]
    ) {
        let historyItems = input.items.filter { $0.amount > 0 }
        guard !historyItems.isEmpty else { return }

        let weightedItems = historyItems.map { item in
            (item: item, weight: recencyWeight(for: item.createdAt, referenceDate: input.referenceDate))
        }
        let totalWeight = weightedItems.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return }

        let confidence = min(totalWeight / 18, 1)
        for category in HomeItem.Category.allCases {
            let categoryWeight = weightedItems
                .filter { $0.item.category == category }
                .reduce(0) { $0 + $1.weight }
            addHistory((categoryWeight / totalWeight) * confidence * 0.65, to: category, scores: &scores)
        }

        let low = input.amount * 0.7
        let high = input.amount * 1.3
        let sameBand = historyItems.filter { $0.amount >= low && $0.amount <= high }
        if sameBand.count >= 3,
           let scene = LifeSceneSemanticService.dominantScene(in: sameBand),
           scene.signal.confidenceTier >= .medium,
           scene.count >= 3 {
            addHistory(sceneHistoryBoost(for: scene, in: sameBand), to: scene.signal.category, scores: &scores)
        }
        if sameBand.count >= 3, let top = mostFrequentCategory(in: sameBand) {
            addHistory(0.9, to: top, scores: &scores)
        }
        applyCorrectionPenalties(
            input: input,
            sameBand: sameBand,
            scores: &scores
        )

        let note = input.noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if note.count >= 2,
           let top = mostFrequentCategory(in: historyItems.filter({ hasSimilarTitle(note, $0.title) })) {
            addHistory(1.2, to: top, scores: &scores)
        }
    }

    private func recencyWeight(for date: Date, referenceDate: Date) -> Double {
        let days = max(0, Calendar.current.dateComponents([.day], from: date, to: referenceDate).day ?? 0)
        switch days {
        case 0...14: return 1.0
        case 15...30: return 0.7
        case 31...90: return 0.35
        default: return 0.15
        }
    }

    private func sceneHistoryBoost(
        for scene: (signal: LifeSceneSignal, count: Int, latest: Date),
        in items: [HomeItem]
    ) -> Double {
        let activeWeight = items.reduce(0.0) { partial, item in
            partial
                + (item.userEditedCategory == true ? 0.35 : 0)
                + (item.userEditedTitle == true ? 0.18 : 0)
        }
        let base = scene.signal.confidenceTier == .strong ? 1.25 : 0.95
        return min(base + activeWeight, 1.65)
    }

    private func applyCorrectionPenalties(
        input: CategoryRecommendInput,
        sameBand: [HomeItem],
        scores: inout [HomeItem.Category: ScoreBreakdown]
    ) {
        let relevantCorrections = sameBand.filter { item in
            guard let correctedFrom = item.categoryCorrectionFrom,
                  correctedFrom != item.category else {
                return false
            }
            return sameCorrectionContext(item.createdAt, input.referenceDate)
        }
        guard !relevantCorrections.isEmpty else { return }

        var penalties: [HomeItem.Category: Double] = [:]
        for item in relevantCorrections {
            guard let correctedFrom = item.categoryCorrectionFrom else { continue }
            let weight = item.userEditedCategory == true ? 0.82 : 0.55
            penalties[correctedFrom, default: 0] += weight
        }
        for (category, penalty) in penalties {
            addHistory(-min(penalty, 1.6), to: category, scores: &scores)
        }
    }

    private func sameCorrectionContext(_ lhs: Date, _ rhs: Date) -> Bool {
        let calendar = Calendar.current
        let lhsWeekday = calendar.component(.weekday, from: lhs)
        let rhsWeekday = calendar.component(.weekday, from: rhs)
        let lhsWeekend = lhsWeekday == 1 || lhsWeekday == 7
        let rhsWeekend = rhsWeekday == 1 || rhsWeekday == 7
        guard lhsWeekend == rhsWeekend else { return false }
        return calendar.component(.hour, from: lhs) / 3 == calendar.component(.hour, from: rhs) / 3
    }

    private func hasSimilarTitle(_ lhs: String, _ rhs: String) -> Bool {
        let left = lhs.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let right = rhs.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard left.count >= 2, right.count >= 2 else { return false }
        return left.contains(right) || right.contains(left)
    }

    private func applyTimeScores(
        input: CategoryRecommendInput,
        scores: inout [HomeItem.Category: ScoreBreakdown]
    ) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: input.referenceDate)
        let weekday = calendar.component(.weekday, from: input.referenceDate)
        let isWeekend = weekday == 1 || weekday == 7

        if !isWeekend, (7..<10).contains(hour) {
            addTime(input.amount <= 30 ? 3.4 : 3, to: .transport, scores: &scores)
            addTime(input.amount <= 35 ? 0.8 : 0.2, to: .dining, scores: &scores)
        }
        if (11..<14).contains(hour) {
            addTime(input.amount <= 80 ? 3 : 0.6, to: .dining, scores: &scores)
        }
        if (17..<20).contains(hour) {
            addTime(input.amount <= 120 ? 2 : 0.5, to: .dining, scores: &scores)
            addTime(1, to: .transport, scores: &scores)
        }
        if hour >= 22 || hour < 6 {
            addTime(input.amount <= 100 ? 2 : 0.5, to: .dining, scores: &scores)
            addTime(1, to: .entertainment, scores: &scores)
        }
        if isWeekend, (14..<22).contains(hour) {
            addTime(2, to: .entertainment, scores: &scores)
            addTime(1, to: .shopping, scores: &scores)
            addTime(0.8, to: .social, scores: &scores)
            addTime(0.6, to: .home, scores: &scores)
        }
    }

    private func applyAmountScores(
        amount: Double,
        scores: inout [HomeItem.Category: ScoreBreakdown]
    ) {
        switch amount {
        case ...20.0:
            addAmount(1.5, to: .transport, scores: &scores)
            addAmount(1.9, to: .dining, scores: &scores)
            addAmount(1.4, to: .daily, scores: &scores)
        case 21.0...50.0:
            addAmount(2.0, to: .shopping, scores: &scores)
            addAmount(1.9, to: .daily, scores: &scores)
            addAmount(1.8, to: .dining, scores: &scores)
            addAmount(1.5, to: .transport, scores: &scores)
        case 51.0...200.0:
            addAmount(3.0, to: .shopping, scores: &scores)
            addAmount(2.6, to: .daily, scores: &scores)
            addAmount(2.2, to: .health, scores: &scores)
            addAmount(1.8, to: .social, scores: &scores)
            addAmount(1.2, to: .home, scores: &scores)
        case 201.0...800.0:
            addAmount(3.0, to: .shopping, scores: &scores)
            addAmount(2.6, to: .home, scores: &scores)
            addAmount(2.2, to: .health, scores: &scores)
            addAmount(2.0, to: .social, scores: &scores)
            addAmount(1.0, to: .lodging, scores: &scores)
        default:
            addAmount(3.0, to: .home, scores: &scores)
            addAmount(2.5, to: .lodging, scores: &scores)
            addAmount(2.2, to: .shopping, scores: &scores)
            addAmount(2.0, to: .other, scores: &scores)
            addAmount(1.8, to: .social, scores: &scores)
        }
    }

    private func applyNoteScores(
        note: String,
        scores: inout [HomeItem.Category: ScoreBreakdown]
    ) {
        let normalized = note.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return }

        for rule in RecordSemanticLexicon.keywordRules {
            if rule.keywords.contains(where: { normalized.contains($0.lowercased()) }) {
                addNote(rule.score, to: rule.category, scores: &scores)
            }
        }
        for rule in RecordSemanticLexicon.comboRules {
            guard rule.keywords.contains(where: { normalized.contains($0.lowercased()) }) else { continue }
            for (category, score) in rule.scores {
                addNote(score, to: category, scores: &scores)
            }
        }
    }

    private func applyContextScores(
        input: CategoryRecommendInput,
        scores: inout [HomeItem.Category: ScoreBreakdown]
    ) {
        guard let context = input.context else { return }

        if let weather = context.weather,
           [.rain, .snow].contains(weather),
           [.morning, .evening].contains(context.timeBand),
           (20...120).contains(input.amount) {
            addContext(2.0, to: .transport, scores: &scores)
        }

        if context.weather == .cold,
           [.evening, .lateNight].contains(context.timeBand),
           input.amount <= 80 {
            addContext(1.4, to: .dining, scores: &scores)
            addContext(0.4, to: .home, scores: &scores)
        }

        if context.weather == .hot,
           [.afternoon, .evening].contains(context.timeBand),
           input.amount <= 50 {
            addContext(1.4, to: .dining, scores: &scores)
        }

        if context.timeBand == .lateNight, input.amount <= 80 {
            addContext(1.6, to: .dining, scores: &scores)
        }

        if context.dayType == .weekend,
           [.afternoon, .evening].contains(context.timeBand) {
            addContext(0.7, to: .entertainment, scores: &scores)
            addContext(0.5, to: .shopping, scores: &scores)
        }

        if context.cityContext == .awayCity {
            addContext(0.8, to: .lodging, scores: &scores)
            addContext(0.6, to: .transport, scores: &scores)
            addContext(0.5, to: .entertainment, scores: &scores)
        }
    }

    private func addHistory(
        _ value: Double,
        to category: HomeItem.Category,
        scores: inout [HomeItem.Category: ScoreBreakdown]
    ) {
        var score = scores[category] ?? ScoreBreakdown()
        score.history += value
        scores[category] = score
    }

    private func addTime(
        _ value: Double,
        to category: HomeItem.Category,
        scores: inout [HomeItem.Category: ScoreBreakdown]
    ) {
        var score = scores[category] ?? ScoreBreakdown()
        score.time += value
        scores[category] = score
    }

    private func addAmount(
        _ value: Double,
        to category: HomeItem.Category,
        scores: inout [HomeItem.Category: ScoreBreakdown]
    ) {
        var score = scores[category] ?? ScoreBreakdown()
        score.amount += value
        scores[category] = score
    }

    private func addNote(
        _ value: Double,
        to category: HomeItem.Category,
        scores: inout [HomeItem.Category: ScoreBreakdown]
    ) {
        var score = scores[category] ?? ScoreBreakdown()
        score.note += value
        scores[category] = score
    }

    private func addContext(
        _ value: Double,
        to category: HomeItem.Category,
        scores: inout [HomeItem.Category: ScoreBreakdown]
    ) {
        var score = scores[category] ?? ScoreBreakdown()
        score.context += value
        scores[category] = score
    }

    private func mostFrequentCategory(in items: [HomeItem]) -> HomeItem.Category? {
        let grouped = Dictionary(grouping: items, by: \.category)
        let counts = HomeItem.Category.allCases
            .map { category -> (category: HomeItem.Category, count: Int, priority: Int) in
                (
                    category: category,
                    count: grouped[category]?.count ?? 0,
                    priority: categoryPriority(category)
                )
            }
            .filter { entry in entry.count > 0 }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.priority < rhs.priority
                }
                return lhs.count > rhs.count
            }

        return counts.first?.category
    }

    private func dominantReason(for breakdown: ScoreBreakdown) -> String? {
        let parts = [
            ("history", breakdown.history * 0.30),
            ("note", breakdown.note * 0.25),
            ("time", breakdown.time * 0.20),
            ("context", breakdown.context * 0.15),
            ("amount", breakdown.amount * 0.10),
        ]
        return parts.max(by: { $0.1 < $1.1 })?.0
    }

    private func categoryPriority(_ category: HomeItem.Category) -> Int {
        switch category {
        case .dining: return 0
        case .transport: return 1
        case .shopping: return 2
        case .daily: return 3
        case .entertainment: return 4
        case .lodging: return 5
        case .health: return 6
        case .home: return 7
        case .social: return 8
        case .other: return 9
        }
    }
}
