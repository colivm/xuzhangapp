import Foundation

enum ProductAnalyticsEvent: String, Codable, CaseIterable, Hashable {
    case appOpened = "app_opened"
    case recordSaved = "record_saved"
    case firstRecordSaved = "first_record_saved"
    case recordUpdated = "record_updated"
    case recordDeletedBatch = "record_deleted_batch"
    case recordMemoryImageAttached = "record_memory_image_attached"
    case recordMemoryImageRemoved = "record_memory_image_removed"
    case recordMemoryCoverSelected = "record_memory_cover_selected"
    case ocrRecordsImported = "ocr_records_imported"
    case ocrDraftDeleted = "ocr_draft_deleted"
    case ocrDraftsResolved = "ocr_drafts_resolved"
    case ocrDraftsResolveAll = "ocr_drafts_resolve_all"
    case aiCommandRecordsSaved = "ai_command_records_saved"
    case aiCommandRunCompleted = "ai_command_run_completed"
    case aiDailyGenerated = "ai_daily_generated"
    case aiMonthlyGenerated = "ai_monthly_generated"
    case todayPlaybackPromptShown = "today_playback_prompt_shown"
    case todayPlaybackStarted = "today_playback_started"
    case todayPlaybackCompleted = "today_playback_completed"
    case summaryPlaybackStarted = "summary_playback_started"
    case summaryPlaybackCompleted = "summary_playback_completed"
    case weeklyShareCardGenerated = "weekly_share_card_generated"
    case weeklyRhythmReviewed = "weekly_rhythm_reviewed"
    case weeklyTagMarked = "weekly_tag_marked"
    case monthlyClosingSaved = "monthly_closing_saved"
    case monthlySummarySaved = "monthly_summary_saved"
    case playbackMemoryLineSaved = "playback_memory_line_saved"
    case memberCTAExposed = "member_cta_exposed"
    case memberCTADismissed = "member_cta_dismissed"
    case memberCTAClicked = "member_cta_clicked"
    case memberEntryOpened = "member_entry_opened"
    case memberPurchaseCompleted = "member_purchase_completed"
    case memberRestoreCompleted = "member_restore_completed"
    case routeGuidanceShown = "route_guidance_shown"
    case performanceMeasured = "performance_measured"
}

enum AnalyticsPropertyKey: String, Codable, CaseIterable, Hashable {
    case source
    case countBucket = "count_bucket"
    case ledgerSizeBucket = "ledger_size_bucket"
    case imageCountBucket = "image_count_bucket"
    case mode
    case range
    case scene
    case channel
    case outcome
    case operation
    case durationBucket = "duration_bucket"
    case isFirst = "is_first"
    case destination
    case resultKind = "result_kind"
    case plan
    case prompt
    case route
    case progressBucket = "progress_bucket"
}

enum AnalyticsOutcome: String {
    case success
    case failure
    case blocked
    case empty
    case cancelled
}

enum AnalyticsOperation: String {
    case ledgerColdStart = "ledger_cold_start"
    case traceLifePreparation = "trace_life_preparation"
    case traceCluePreparation = "trace_clue_preparation"
    case insightPreparation = "insight_preparation"
    case aiCommand = "ai_command"
    case monthlyInsight = "monthly_insight"
    case summaryWeek = "summary_week"
    case summaryMonth = "summary_month"
}

struct AnalyticsEvent: Codable, Identifiable, Equatable {
    let id: UUID
    let schemaVersion: Int
    let name: ProductAnalyticsEvent
    let props: [String: String]
    let at: Date

    init(
        name: ProductAnalyticsEvent,
        props: [String: String] = [:],
        at: Date = Date()
    ) {
        id = UUID()
        schemaVersion = 2
        self.name = name
        self.props = props
        self.at = at
    }
}

@MainActor
final class AnalyticsService {
    private static let storageKey = "ios_product_observability_events_v2"
    private static let legacyStorageKey = "ios_analytics_events_v1"
    private static let maxEvents = 1_000
    private static let retentionDays = 30

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.removeObject(forKey: Self.legacyStorageKey)
        pruneExpiredEvents()
    }

    func track(
        _ event: ProductAnalyticsEvent,
        props: [AnalyticsPropertyKey: String] = [:],
        at: Date = Date()
    ) {
        let sanitized = Self.sanitizedProperties(for: event, props: props)
        var events = loadEvents(referenceDate: at)
        events.insert(
            AnalyticsEvent(
                name: event,
                props: Dictionary(uniqueKeysWithValues: sanitized.map { ($0.key.rawValue, $0.value) }),
                at: at
            ),
            at: 0
        )
        save(events: Array(events.prefix(Self.maxEvents)))
    }

    func trackPerformance(
        operation: AnalyticsOperation,
        startedAtUptime: TimeInterval,
        itemCount: Int,
        outcome: AnalyticsOutcome = .success
    ) {
        let elapsed = max(0, ProcessInfo.processInfo.systemUptime - startedAtUptime)
        let durationMs = Int((elapsed * 1_000).rounded())
        track(
            .performanceMeasured,
            props: [
                .operation: operation.rawValue,
                .durationBucket: Self.durationBucket(for: durationMs),
                .ledgerSizeBucket: Self.countBucket(for: itemCount),
                .outcome: outcome.rawValue,
            ]
        )
    }

    func loadEvents(referenceDate: Date = Date()) -> [AnalyticsEvent] {
        guard let data = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([AnalyticsEvent].self, from: data) else {
            return []
        }
        let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -Self.retentionDays,
            to: referenceDate
        ) ?? referenceDate
        return decoded.filter { $0.at >= cutoff }
    }

    func summary(lastDays: Int = 7, referenceDate: Date = Date()) -> [ProductAnalyticsEvent: Int] {
        let days = max(1, min(lastDays, Self.retentionDays))
        let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: referenceDate) ?? referenceDate
        return loadEvents(referenceDate: referenceDate)
            .filter { $0.at >= start }
            .reduce(into: [ProductAnalyticsEvent: Int]()) { partial, event in
                partial[event.name, default: 0] += 1
            }
    }

    static func countBucket(for count: Int) -> String {
        switch max(0, count) {
        case 0: return "0"
        case 1: return "1"
        case 2...4: return "2_4"
        case 5...9: return "5_9"
        case 10...49: return "10_49"
        case 50...99: return "50_99"
        case 100...999: return "100_999"
        case 1_000...4_999: return "1000_4999"
        default: return "5000_plus"
        }
    }

    static func durationBucket(for milliseconds: Int) -> String {
        switch max(0, milliseconds) {
        case 0...49: return "under_50ms"
        case 50...149: return "50_149ms"
        case 150...399: return "150_399ms"
        case 400...999: return "400_999ms"
        case 1_000...2_999: return "1_2s"
        default: return "3s_plus"
        }
    }

    static func sanitizedProperties(
        for event: ProductAnalyticsEvent,
        props: [AnalyticsPropertyKey: String]
    ) -> [AnalyticsPropertyKey: String] {
        let allowedKeys = allowedPropertyKeys(for: event)
        return props.reduce(into: [:]) { partial, pair in
            guard allowedKeys.contains(pair.key), isAllowedValue(pair.value, for: pair.key) else { return }
            partial[pair.key] = pair.value
        }
    }

    private static func allowedPropertyKeys(for event: ProductAnalyticsEvent) -> Set<AnalyticsPropertyKey> {
        switch event {
        case .appOpened:
            return [.ledgerSizeBucket]
        case .recordSaved:
            return [.source, .isFirst, .ledgerSizeBucket]
        case .firstRecordSaved:
            return [.source]
        case .recordUpdated:
            return []
        case .recordDeletedBatch, .ocrDraftsResolved, .ocrDraftsResolveAll:
            return [.countBucket]
        case .recordMemoryImageAttached, .recordMemoryImageRemoved:
            return [.imageCountBucket]
        case .recordMemoryCoverSelected, .ocrDraftDeleted:
            return []
        case .ocrRecordsImported:
            return [.countBucket, .destination]
        case .aiCommandRecordsSaved:
            return [.countBucket]
        case .aiCommandRunCompleted:
            return [.resultKind, .outcome, .ledgerSizeBucket]
        case .aiDailyGenerated, .aiMonthlyGenerated:
            return [.mode, .ledgerSizeBucket, .outcome]
        case .todayPlaybackPromptShown:
            return [.prompt]
        case .todayPlaybackStarted:
            return [.isFirst]
        case .todayPlaybackCompleted:
            return [.progressBucket]
        case .summaryPlaybackStarted, .summaryPlaybackCompleted:
            return [.range, .progressBucket]
        case .weeklyShareCardGenerated, .weeklyRhythmReviewed, .weeklyTagMarked,
             .monthlyClosingSaved, .monthlySummarySaved:
            return []
        case .playbackMemoryLineSaved:
            return [.range]
        case .memberCTAExposed, .memberCTADismissed, .memberCTAClicked:
            return [.scene, .channel]
        case .memberEntryOpened:
            return [.scene]
        case .memberPurchaseCompleted, .memberRestoreCompleted:
            return [.plan, .outcome]
        case .routeGuidanceShown:
            return [.route]
        case .performanceMeasured:
            return [.operation, .durationBucket, .ledgerSizeBucket, .outcome]
        }
    }

    private static func isAllowedValue(_ value: String, for key: AnalyticsPropertyKey) -> Bool {
        switch key {
        case .source:
            return ["manual", "ocr", "ai_command"].contains(value)
        case .countBucket, .ledgerSizeBucket, .imageCountBucket:
            return ["0", "1", "2_4", "5_9", "10_49", "50_99", "100_999", "1000_4999", "5000_plus"].contains(value)
        case .mode:
            return ["live", "local_fallback", "error_fallback"].contains(value)
        case .range:
            return ["week", "month"].contains(value)
        case .scene:
            return [
                "default", "playback_complete", "share_success", "ai_monthly",
                "trace_deep_insight", "playback_quota", "ocr_import", "scene_pack",
                "lifetime", "ai_command", "settings"
            ].contains(value)
        case .channel:
            return ["ios_home"].contains(value)
        case .outcome:
            return AnalyticsOutcome.allRawValues.contains(value)
        case .operation:
            return AnalyticsOperation.allRawValues.contains(value)
        case .durationBucket:
            return ["under_50ms", "50_149ms", "150_399ms", "400_999ms", "1_2s", "3s_plus"].contains(value)
        case .isFirst:
            return ["true", "false"].contains(value)
        case .destination:
            return ["drafts", "ledger"].contains(value)
        case .resultKind:
            return ["query", "compare", "memory_lookup", "duplicate_check", "batch_create", "needs_amount", "unsupported"].contains(value)
        case .plan:
            return ["yearly", "monthly", "lifetime", "unknown"].contains(value)
        case .prompt:
            return ["first_record", "first_use"].contains(value)
        case .route:
            return ["firstRecordTodayPlayback", "weekSliceReady", "fiveRecordsNeverPlayed"].contains(value)
        case .progressBucket:
            return ["under_80", "80_plus"].contains(value)
        }
    }

    private func pruneExpiredEvents() {
        save(events: loadEvents())
    }

    private func save(events: [AnalyticsEvent]) {
        guard let data = try? JSONEncoder().encode(events) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

private extension AnalyticsOutcome {
    static var allRawValues: Set<String> {
        Set([
            AnalyticsOutcome.success,
            AnalyticsOutcome.failure,
            AnalyticsOutcome.blocked,
            AnalyticsOutcome.empty,
            AnalyticsOutcome.cancelled,
        ].map(\.rawValue))
    }
}

private extension AnalyticsOperation {
    static var allRawValues: Set<String> {
        Set(
            [
                AnalyticsOperation.traceLifePreparation,
                AnalyticsOperation.traceCluePreparation,
                AnalyticsOperation.insightPreparation,
                AnalyticsOperation.aiCommand,
                AnalyticsOperation.monthlyInsight,
                AnalyticsOperation.summaryWeek,
                AnalyticsOperation.summaryMonth,
            ]
                .map(\.rawValue)
        )
    }
}
