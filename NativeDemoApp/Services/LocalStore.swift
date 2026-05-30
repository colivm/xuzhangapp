import Foundation

enum LocalStore {
    private static let settingsKey = "app_settings_v1"
    private static let homeItemsFile = "home_items_v1.json"
    private static let dailyInsightsFile = "daily_insights_v1.json"

    static func loadSettings() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey) else {
            return .default
        }

        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            return .default
        }
    }

    static func saveSettings(_ settings: AppSettings) {
        do {
            let data = try JSONEncoder().encode(settings)
            UserDefaults.standard.set(data, forKey: settingsKey)
        } catch {
            print("Failed to save settings: \(error)")
        }
    }

    static func loadHomeItems() -> [HomeItem] {
        guard let fileURL = fileURL(for: homeItemsFile) else {
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([HomeItem].self, from: data)
        } catch {
            return []
        }
    }

    static func saveHomeItems(_ items: [HomeItem]) {
        guard let fileURL = fileURL(for: homeItemsFile) else {
            return
        }

        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save home items: \(error)")
        }
    }

    static func loadDailyInsights() -> [DailyInsight] {
        guard let fileURL = fileURL(for: dailyInsightsFile) else {
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([DailyInsight].self, from: data)
        } catch {
            return []
        }
    }

    static func saveDailyInsights(_ insights: [DailyInsight]) {
        guard let fileURL = fileURL(for: dailyInsightsFile) else {
            return
        }

        do {
            let data = try JSONEncoder().encode(insights)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save daily insights: \(error)")
        }
    }

    private static func fileURL(for fileName: String) -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(fileName)
    }
}
