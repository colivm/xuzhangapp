import Foundation

enum LocalStore {
    private static let settingsKey = "app_settings_v1"
    private static let cloudSyncPreferencesKey = "cloud_sync_preferences_v1"
    private static let cloudSyncServerMigrationKey = "cloud_sync_server_migrations_v1"
    private static let homeItemsBackupKey = "home_items_v1_backup"
    private static let homeItemsFile = "home_items_v1.json"
    private static let preImageMigrationBackupFile = "home_items_v1.pre_image_migration.json"
    private static let dailyInsightsFile = "daily_insights_v1.json"

    static var isReleaseFixtureMode: Bool {
        #if DEBUG
        ReleaseFixtureLaunchConfiguration.resolve() != nil
        #else
        false
        #endif
    }

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
        loadHomeItemsResult().items
    }

    static func loadHomeItemsResult() -> LedgerHomeItemsLoadResult {
        #if DEBUG
        if let context = releaseFixtureStoreContext() {
            do {
                try prepareReleaseFixtureStore(context)
            } catch {
                return LedgerHomeItemsLoadResult(
                    items: [],
                    issueMessage: "QA 发布夹具无法准备：\(error.localizedDescription)",
                    writesBlocked: true
                )
            }
        }
        #endif
        guard let repository = homeItemsRepository() else {
            return LedgerHomeItemsLoadResult(
                items: [],
                issueMessage: "本机账本目录暂时不可用，原数据没有被覆盖。",
                writesBlocked: true
            )
        }
        var result = repository.load()
        #if DEBUG
        if let configuration = ReleaseFixtureLaunchConfiguration.resolve() {
            let fixtureMessage = "QA 发布夹具：\(configuration.count) 条，本机账本使用隔离目录，云端自动同步已停用。"
            result.issueMessage = [fixtureMessage, result.issueMessage]
                .compactMap { $0 }
                .joined(separator: " ")
        }
        #endif
        return result
    }

    @discardableResult
    static func saveHomeItems(_ items: [HomeItem]) -> Bool {
        guard let repository = homeItemsRepository() else { return false }
        return repository.save(items)
    }

    private static func homeItemsRepository() -> LedgerHomeItemsRepository? {
        #if DEBUG
        if let context = releaseFixtureStoreContext() {
            return LedgerHomeItemsRepository(
                documentsURL: context.documentsURL,
                defaults: context.defaults,
                homeItemsBackupKey: homeItemsBackupKey,
                homeItemsFile: homeItemsFile,
                preImageMigrationBackupFile: preImageMigrationBackupFile
            )
        }
        #endif
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return LedgerHomeItemsRepository(
            documentsURL: documentsURL,
            defaults: .standard,
            homeItemsBackupKey: homeItemsBackupKey,
            homeItemsFile: homeItemsFile,
            preImageMigrationBackupFile: preImageMigrationBackupFile
        )
    }

    #if DEBUG
    private struct ReleaseFixtureStoreContext {
        let configuration: ReleaseFixtureLaunchConfiguration
        let documentsURL: URL
        let defaults: UserDefaults
        let suiteName: String
    }

    private static let releaseFixtureSeededKey = "release_fixture_seeded_v1"
    private static let releaseFixtureResetProcessKey = "release_fixture_reset_process_v1"

    private static func releaseFixtureStoreContext() -> ReleaseFixtureStoreContext? {
        guard let configuration = ReleaseFixtureLaunchConfiguration.resolve(),
              let baseDocumentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let suiteName = "\(Bundle.main.bundleIdentifier ?? "NativeDemoApp").qa.releaseFixture.\(configuration.count)"
        guard let defaults = UserDefaults(suiteName: suiteName) else { return nil }
        let documentsURL = baseDocumentsURL
            .appendingPathComponent("QAReleaseFixtures", isDirectory: true)
            .appendingPathComponent("ledger_\(configuration.count)", isDirectory: true)
        return ReleaseFixtureStoreContext(
            configuration: configuration,
            documentsURL: documentsURL,
            defaults: defaults,
            suiteName: suiteName
        )
    }

    private static func prepareReleaseFixtureStore(_ context: ReleaseFixtureStoreContext) throws {
        let processID = Int(ProcessInfo.processInfo.processIdentifier)
        if context.configuration.reset,
           context.defaults.integer(forKey: releaseFixtureResetProcessKey) != processID {
            if FileManager.default.fileExists(atPath: context.documentsURL.path) {
                try FileManager.default.removeItem(at: context.documentsURL)
            }
            context.defaults.removePersistentDomain(forName: context.suiteName)
            context.defaults.set(processID, forKey: releaseFixtureResetProcessKey)
        }

        guard !context.defaults.bool(forKey: releaseFixtureSeededKey) else { return }
        try FileManager.default.createDirectory(at: context.documentsURL, withIntermediateDirectories: true)
        let legacyURL = context.documentsURL.appendingPathComponent(homeItemsFile)
        let metadataRoot = context.documentsURL.appendingPathComponent(LedgerStorageSchema.storeDirectoryName, isDirectory: true)
        if FileManager.default.fileExists(atPath: legacyURL.path)
            || FileManager.default.fileExists(atPath: metadataRoot.path) {
            context.defaults.set(true, forKey: releaseFixtureSeededKey)
            return
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(ReleaseFixtureFactory.makeItems(count: context.configuration.count))
        try data.write(to: legacyURL, options: .atomic)
        context.defaults.set(data, forKey: homeItemsBackupKey)
        context.defaults.set(true, forKey: releaseFixtureSeededKey)
    }
    #endif

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
