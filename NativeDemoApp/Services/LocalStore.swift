import Foundation

enum LocalStore {
    private static let settingsKey = "app_settings_v1"
    private static let cloudSyncPreferencesKey = "cloud_sync_preferences_v1"
    private static let cloudSyncServerMigrationKey = "cloud_sync_server_migrations_v1"
    private static let homeItemsBackupKey = "home_items_v1_backup"
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

    static func loadCloudSyncPreference(for userId: String) -> Bool {
        cloudSyncPreferences()[userId] ?? false
    }

    static func hasCloudSyncPreference(for userId: String) -> Bool {
        cloudSyncPreferences()[userId] != nil
    }

    static func saveCloudSyncPreference(_ enabled: Bool, for userId: String) {
        guard !userId.isEmpty else { return }
        var preferences = cloudSyncPreferences()
        preferences[userId] = enabled
        UserDefaults.standard.set(preferences, forKey: cloudSyncPreferencesKey)
    }

    static func removeCloudSyncPreference(for userId: String) {
        guard !userId.isEmpty else { return }
        var preferences = cloudSyncPreferences()
        preferences.removeValue(forKey: userId)
        UserDefaults.standard.set(preferences, forKey: cloudSyncPreferencesKey)
    }

    static func hasMigratedCloudSyncPreferenceToAccount(for userId: String) -> Bool {
        migratedCloudSyncPreferenceUserIds().contains(userId)
    }

    static func markCloudSyncPreferenceMigratedToAccount(for userId: String) {
        guard !userId.isEmpty else { return }
        var ids = migratedCloudSyncPreferenceUserIds()
        ids.insert(userId)
        UserDefaults.standard.set(Array(ids), forKey: cloudSyncServerMigrationKey)
    }

    static func removeCloudSyncPreferenceMigration(for userId: String) {
        guard !userId.isEmpty else { return }
        var ids = migratedCloudSyncPreferenceUserIds()
        ids.remove(userId)
        UserDefaults.standard.set(Array(ids), forKey: cloudSyncServerMigrationKey)
    }

    static func loadHomeItems() -> [HomeItem] {
        guard let fileURL = fileURL(for: homeItemsFile) else {
            return loadHomeItemsBackup()
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([HomeItem].self, from: data)
        } catch {
            return loadHomeItemsBackup()
        }
    }

    static func saveHomeItems(_ items: [HomeItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: homeItemsBackupKey)
        guard let fileURL = fileURL(for: homeItemsFile) else {
            return
        }

        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save home items: \(error)")
        }
    }

    private static func loadHomeItemsBackup() -> [HomeItem] {
        guard let data = UserDefaults.standard.data(forKey: homeItemsBackupKey) else {
            return []
        }
        return (try? JSONDecoder().decode([HomeItem].self, from: data)) ?? []
    }

    private static func cloudSyncPreferences() -> [String: Bool] {
        let raw = UserDefaults.standard.dictionary(forKey: cloudSyncPreferencesKey) ?? [:]
        return raw.compactMapValues { value in
            if let bool = value as? Bool {
                return bool
            }
            return (value as? NSNumber)?.boolValue
        }
    }

    private static func migratedCloudSyncPreferenceUserIds() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: cloudSyncServerMigrationKey) ?? [])
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
