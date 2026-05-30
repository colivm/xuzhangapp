import Foundation

struct AnalyticsEvent: Codable, Identifiable {
    let id: UUID
    let name: String
    let props: [String: String]
    let at: Date

    init(name: String, props: [String: String] = [:], at: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.props = props
        self.at = at
    }
}

final class AnalyticsService {
    private let key = "ios_analytics_events_v1"
    private let maxEvents = 2000

    func track(_ name: String, props: [String: String] = [:]) {
        var events = loadEvents()
        events.insert(AnalyticsEvent(name: name, props: props), at: 0)
        save(events: Array(events.prefix(maxEvents)))
    }

    func loadEvents() -> [AnalyticsEvent] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([AnalyticsEvent].self, from: data)) ?? []
    }

    func summary(lastDays: Int = 7) -> [String: Int] {
        let days = max(1, min(lastDays, 90))
        let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: Date()) ?? Date()
        let filtered = loadEvents().filter { $0.at >= start }
        return filtered.reduce(into: [String: Int]()) { partial, event in
            partial[event.name, default: 0] += 1
        }
    }

    private func save(events: [AnalyticsEvent]) {
        guard let data = try? JSONEncoder().encode(events) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

