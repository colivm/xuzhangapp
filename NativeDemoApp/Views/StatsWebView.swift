import SwiftUI

// MARK: - Stats View (matching web statsPage)

struct StatsWebView: View {

    @EnvironmentObject private var homeViewModel: HomeViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    var onShowMemberPricing: (() -> Void)? = nil
    var onOpenInsight: (() -> Void)? = nil

    @State private var selectedPeriod: StatsPeriod = .week
    @State private var selectedCategory: HomeItem.Category? = nil
    @State private var editingItem: HomeItem?
    @State private var summaryPlayback: SummaryPlayback?
    @State private var summaryQuotaMessage: String?
    @State private var quotaRefreshID = UUID()
    @State private var isFiltersExpanded = false
    @State private var showTraceDetailSheet = false
    @State private var isTrendExpandedInSheet = false
    @State private var pendingEditingItemAfterTraceClose: HomeItem?
    private let playbackService = PlaybackService()
    private let quotaStore = SummaryPlaybackQuotaStore()

    enum StatsPeriod: String, CaseIterable, Identifiable {
        case week = "本周"
        case month = "本月"
        case year = "本年"
        var id: String { rawValue }
    }

    private var filteredItems: [HomeItem] {
        var items: [HomeItem]
        if useCustomRange {
            let cal = Calendar.current
            let start = cal.startOfDay(for: customStartDate)
            let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: customEndDate)) ?? customEndDate
            items = homeViewModel.items.filter { $0.createdAt >= start && $0.createdAt < end }
        } else {
            switch selectedPeriod {
            case .week:
                if let interval = PlaybackService.isoCalendar.dateInterval(of: .weekOfYear, for: .now) {
                    items = homeViewModel.items.filter { $0.createdAt >= interval.start && $0.createdAt < interval.end }
                } else {
                    items = []
                }
            case .month: items = homeViewModel.items.filter { Calendar.current.isDate($0.createdAt, equalTo: .now, toGranularity: .month) }
            case .year: items = homeViewModel.items.filter { Calendar.current.isDate($0.createdAt, equalTo: .now, toGranularity: .year) }
            }
        }
        if let cat = selectedCategory {
            items = items.filter { $0.category == cat }
        }
        return items.sorted { $0.createdAt > $1.createdAt }
    }

    private var totalExpense: Double {
        filteredItems.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
    }

    private var emptyRecordListText: String {
        if homeViewModel.items.isEmpty {
            return "这一段还没有痕迹，先去记下一笔。"
        }
        return "这一段没有匹配的痕迹，可以换个时间或分类看看。"
    }

    private var hasMemberAccess: Bool {
        settingsViewModel.settings.hasMemberAccess
    }

    private var currentFilterSummary: String {
        let periodText = useCustomRange ? "自定义时间" : selectedPeriod.rawValue
        let categoryText = selectedCategory?.rawValue ?? "全部分类"
        return "\(periodText) · \(categoryText)"
    }

    private var overviewNarrativeText: String {
        let count = filteredItems.count
        guard count > 0 else {
            return "这一段还没有记录。先留下几笔，之后会整理成一段场记。"
        }
        let trendData = computeTrendData()
        let trendText = trendData.isEmpty ? "多记几天，节奏会更清楚。" : trendInsightText(data: trendData)
        return "这一段留下 \(count) 笔，合计 \(totalExpense.formatted(.cny))。\(trendText)"
    }

    @State private var showPeriodSheet = false
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    @State private var useCustomRange = false

    var body: some View {
        statsScrollView
            .sheet(isPresented: $showPeriodSheet) {
                periodPickerSheet
            }
            .sheet(isPresented: $showTraceDetailSheet) {
                traceDetailSheet
            }
            .sheet(item: $editingItem) { item in
                editSheet(for: item)
            }
            .sheet(item: $summaryPlayback) { playback in
                summaryPlaybackSheet(playback)
            }
            .onChange(of: showTraceDetailSheet) { _, isPresented in
                if !isPresented {
                    presentPendingEditorIfNeeded()
                }
            }
            .alert("播放次数已用完", isPresented: summaryQuotaAlertBinding) {
                summaryQuotaAlertActions
            } message: {
                Text(summaryQuotaMessage ?? "")
            }
    }

    private var statsScrollView: some View {
        ScrollView {
            statsContent
        }
        .scrollIndicators(.hidden)
    }

    private var statsContent: some View {
        VStack(spacing: 12) {
            traceChapterCard
            traceAppendixStrip
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 120)
        .frame(maxWidth: 430)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var heroScopedItems: [HomeItem] {
        if useCustomRange || selectedPeriod == .year {
            return filteredItems
        }
        let calendar = Calendar.current
        let items: [HomeItem]
        switch selectedPeriod {
        case .week:
            if let interval = PlaybackService.isoCalendar.dateInterval(of: .weekOfYear, for: .now) {
                items = homeViewModel.items.filter { $0.createdAt >= interval.start && $0.createdAt < interval.end }
            } else {
                items = []
            }
        case .month:
            items = homeViewModel.items.filter { calendar.isDate($0.createdAt, equalTo: .now, toGranularity: .month) }
        case .year:
            items = []
        }
        return items
            .filter { $0.amount > 0 && $0.draftMeta == nil }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var traceRepresentativeItems: [HomeItem] {
        representativeTraceItems(from: heroScopedItems)
    }

    private func representativeTraceItems(from items: [HomeItem]) -> [HomeItem] {
        guard items.count > 3 else { return items }
        let ranked = Array(items.enumerated()).sorted { lhs, rhs in
            let leftScore = traceRepresentativeScore(item: lhs.element, index: lhs.offset)
            let rightScore = traceRepresentativeScore(item: rhs.element, index: rhs.offset)
            if leftScore == rightScore {
                return lhs.element.createdAt > rhs.element.createdAt
            }
            return leftScore > rightScore
        }

        var selected: [HomeItem] = []
        var selectedCategories = Set<String>()
        for candidate in ranked where selected.count < 3 {
            let categoryKey = candidate.element.category.rawValue
            guard !selectedCategories.contains(categoryKey) else { continue }
            selected.append(candidate.element)
            selectedCategories.insert(categoryKey)
        }
        for candidate in ranked where selected.count < 3 {
            guard !selected.contains(where: { $0.id == candidate.element.id }) else { continue }
            selected.append(candidate.element)
        }
        return selected.sorted { $0.createdAt > $1.createdAt }
    }

    private func traceRepresentativeScore(item: HomeItem, index: Int) -> Int {
        let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultTitle = item.category.defaultRecordTitle
        let defaultEmotion = HomeItem.inferEmotionTag(category: item.category, amount: item.amount)
        let emotion = item.displayEmotionTag
        var score = 0
        if !emotion.isEmpty && emotion != defaultEmotion { score += 40 }
        if item.userEditedTitle == true { score += 30 }
        if title != defaultTitle && (4...18).contains(title.count) { score += 20 }
        if case .manual = item.source { score += 6 }
        score += min(index, 6) * 2
        if title == defaultTitle { score -= 12 }
        return score
    }

    private var heroTotalExpense: Double {
        heroScopedItems.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
    }

    private var heroNarrativeText: String {
        let items = heroScopedItems
        guard !items.isEmpty else {
            return selectedPeriod == .week
                ? "这一周还没有记录。先留下几笔，之后会整理成一段场记。"
                : "这个月还没有记录。先留下几笔，之后会整理成一段场记。"
        }
        let grouped = Dictionary(grouping: items, by: \.category)
        let topCategory = grouped
            .map { (category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }
            .first?.category.rawValue ?? "日常"
        return "这一段留下 \(items.count) 笔，合计 \(heroTotalExpense.formatted(.cny))。「\(topCategory)」出现得多一点，像这段日子的一个小主题。"
    }

    private var heroRange: SummaryPlaybackRange {
        selectedPeriod == .week ? .week : .month
    }

    private var traceChapterCard: some View {
        let _ = quotaRefreshID
        let range = heroRange
        let preview = buildSummaryPreview(for: range)
        let hasData = !heroScopedItems.isEmpty
        let isMonthLocked = range == .month && !hasMemberAccess && quotaStore.monthRemaining(isMember: false) <= 0
        let canPlay = hasData && quotaStore.canPlay(range, isMember: hasMemberAccess)

        return VStack(alignment: .leading, spacing: 14) {
            traceRangeKicker

            Text(heroNarrativeText)
                .font(.system(size: 16, weight: .medium))
                .lineSpacing(5)
                .foregroundStyle(AppColors.text)
                .fixedSize(horizontal: false, vertical: true)

            Text(summaryCardSubtitle(preview: preview, range: range, hasData: hasData, isMonthLocked: isMonthLocked))
                .font(.system(size: 13))
                .foregroundStyle(AppColors.subtext)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                handleSummaryPlaybackTap(range: range, preview: preview)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isMonthLocked ? "lock.fill" : "play.fill")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(AppColors.accent.opacity(canPlay ? 0.16 : 0.08)))
                    Text(isMonthLocked ? "了解会员" : "听听这一段")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(canPlay || isMonthLocked ? AppColors.accent.opacity(0.9) : AppColors.subtext.opacity(0.82))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule(style: .continuous)
                        .fill(AppColors.tracePlaybackButtonBg)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(AppColors.accent.opacity(canPlay || isMonthLocked ? 0.24 : 0.10), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(!hasData && !isMonthLocked)

            if hasData {
                VStack(spacing: 8) {
                    ForEach(Array(traceRepresentativeItems.enumerated()), id: \.element.id) { _, item in
                        Button {
                            openEditor(for: item)
                        } label: {
                            traceSlipRow(item)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.26))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppColors.accent.opacity(0.10), lineWidth: 1)
                )
            } else {
                traceEmptyState
            }
        }
        .paperChapterPanel(radius: 24, padding: 20)
    }

    private var traceRangeKicker: some View {
        HStack(spacing: 6) {
            traceRangeText("本周", period: .week)
            Text("·")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(AppColors.subtext.opacity(0.55))
            traceRangeText("本月", period: .month)
        }
    }

    private func traceRangeText(_ title: String, period: StatsPeriod) -> some View {
        let isSelected = !useCustomRange && selectedPeriod == period
        return Button {
            useCustomRange = false
            selectedPeriod = period
        } label: {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .bold : .semibold))
                .foregroundStyle(isSelected ? AppColors.text.opacity(0.92) : AppColors.subtext.opacity(0.78))
                .overlay(alignment: .bottom) {
                    if isSelected {
                        Rectangle()
                            .fill(AppColors.accent.opacity(0.35))
                            .frame(height: 1)
                            .offset(y: 3)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func traceSlipRow(_ item: HomeItem) -> some View {
        HStack(alignment: .center, spacing: 10) {
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(traceAccentColor(for: item.category))
                .frame(width: 3)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.text)
                        .lineLimit(1)
                    Spacer()
                    Text(item.amount.formatted(.cny))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.subtext.opacity(0.92))
                }
                if shouldShowTraceSlipEmotion(for: item) {
                    Text(item.displayEmotionTag)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.subtext.opacity(0.78))
                        .lineLimit(1)
                }
                HStack(spacing: 4) {
                    Text(item.category.rawValue)
                    Text("·")
                    Text(item.createdAt.zhBillDateTime)
                }
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(minHeight: 58)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.40))
        )
    }

    private func shouldShowTraceSlipEmotion(for item: HomeItem) -> Bool {
        let tag = item.displayEmotionTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return false }
        return tag != HomeItem.inferEmotionTag(category: item.category, amount: item.amount)
    }

    private func traceAccentColor(for category: HomeItem.Category) -> Color {
        switch category {
        case .dining:
            return Color(red: 0.78, green: 0.58, blue: 0.34).opacity(0.78)
        case .transport:
            return Color(red: 0.40, green: 0.62, blue: 0.70).opacity(0.78)
        default:
            return AppColors.accent.opacity(0.56)
        }
    }

    private var traceEmptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("✦")
                .font(.system(size: 22))
                .foregroundStyle(AppColors.accent.opacity(0.7))
            Text(emptyRecordListText)
                .font(.system(size: 13))
                .foregroundStyle(AppColors.subtext)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.32))
        )
    }

    private var traceAppendixStrip: some View {
        Button {
            showTraceDetailSheet = true
        } label: {
            HStack(spacing: 7) {
                Text("细查这一段")
                    .font(.system(size: 13, weight: .semibold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(AppColors.text.opacity(0.78))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.36))
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.thinMaterial)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppColors.accent.opacity(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var traceDetailSheet: some View {
        NavigationStack {
            ZStack {
                AppColors.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("细查这一段")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppColors.text)

                        Text(traceDetailMetaText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.subtext)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(alignment: .top, spacing: 8) {
                            periodFilter
                            categoryFilter
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    isTrendExpandedInSheet.toggle()
                                }
                            } label: {
                                HStack {
                                    Text(trendInsightText(data: computeTrendData()))
                                        .font(.system(size: 13))
                                        .foregroundStyle(AppColors.text.opacity(0.78))
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                    Text(isTrendExpandedInSheet ? "收起走势" : "展开走势")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(AppColors.accent.opacity(0.82))
                                }
                            }
                            .buttonStyle(.plain)

                            if isTrendExpandedInSheet {
                                trendChart
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.36))
                        )

                        VStack(alignment: .leading, spacing: 12) {
                            recordListContent(fromTraceDetail: true)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(traceDetailListBackground)
                        .overlay(traceDetailListBorder)
                    }
                    .padding(18)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { showTraceDetailSheet = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var traceDetailMetaText: String {
        "\(currentFilterSummary) · \(filteredItems.count) 笔 · 合计 \(totalExpense.formatted(.cny))"
    }

    private var filtersPanel: some View {
        VStack(alignment: .leading, spacing: isFiltersExpanded ? 14 : 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isFiltersExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("细查时间与分类")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColors.text.opacity(0.82))
                        Text(currentFilterSummary)
                            .font(.system(size: 11))
                            .foregroundStyle(AppColors.subtext)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppColors.subtext.opacity(0.7))
                        .rotationEffect(.degrees(isFiltersExpanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)

            if isFiltersExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Text("时间与分类")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.subtext)

                    HStack(alignment: .top, spacing: 8) {
                        periodFilter
                        categoryFilter
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .glassPanel(radius: 18, padding: isFiltersExpanded ? 16 : 14)
    }

    private var periodFilter: some View {
        VStack(alignment: .leading, spacing: 4) {
            filterLabel("时间")
            Button {
                showPeriodSheet = true
            } label: {
                filterButtonLabel(useCustomRange ? "自定义" : selectedPeriod.rawValue)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private var categoryFilter: some View {
        VStack(alignment: .leading, spacing: 4) {
            filterLabel("分类")
            Menu {
                Button("全部分类") { selectedCategory = nil }
                ForEach(HomeItem.Category.allCases) { cat in
                    Button(cat.rawValue) { selectedCategory = cat }
                }
            } label: {
                filterButtonLabel(selectedCategory?.rawValue ?? "全部分类")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func filterLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11))
            .foregroundStyle(AppColors.subtext)
    }

    private func filterButtonLabel(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColors.text.opacity(0.88))
            Spacer()
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(AppColors.subtext.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(filterControlBackground)
        .overlay(filterControlBorder)
    }

    private var filterControlBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.ultraThinMaterial)
    }

    private var filterControlBorder: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(Color.white.opacity(0.45), lineWidth: 0.8)
    }

    private var traceDetailListBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.58),
                        AppColors.paperWarm.opacity(0.20),
                        Color.white.opacity(0.48)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.thinMaterial)
            )
    }

    private var traceDetailListBorder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(Color.white.opacity(0.55), lineWidth: 1)
            .allowsHitTesting(false)
    }

    private var overviewPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("这一段")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppColors.text)
            Text(overviewNarrativeText)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.text.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
            totalExpenseCard
            trendChart
        }
        .glassPanel(radius: 24, padding: 20)
    }

    private var totalExpenseCard: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("合计")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.subtext)
            Spacer()
            Text(totalExpense.formatted(.cny))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.accent.opacity(0.86))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.54))
        )
    }

    private var recordListPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("这一段里的笔笔")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppColors.text)
            recordListContent()
        }
        .glassPanel(radius: 24, padding: 20)
    }

    @ViewBuilder
    private func recordListContent(fromTraceDetail: Bool = false) -> some View {
        if filteredItems.isEmpty {
            Text(emptyRecordListText)
                .font(.system(size: 13))
                .foregroundStyle(AppColors.subtext)
        } else {
            ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                if fromTraceDetail {
                    traceDetailBillRecordRow(item, isFirst: index == 0)
                } else {
                    Button {
                        openEditor(for: item)
                    } label: {
                        billRecordRow(item, isFirst: index == 0)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func openEditor(for item: HomeItem, fromTraceDetail: Bool = false) {
        if fromTraceDetail {
            pendingEditingItemAfterTraceClose = item
            showTraceDetailSheet = false
        } else {
            editingItem = item
        }
    }

    private func presentPendingEditorIfNeeded() {
        guard let item = pendingEditingItemAfterTraceClose else { return }
        pendingEditingItemAfterTraceClose = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            editingItem = item
        }
    }

    private func editSheet(for item: HomeItem) -> some View {
        RecordEditSheet(item: item) { updated in
            let didSave = homeViewModel.updateItem(updated)
            if didSave {
                editingItem = nil
            }
            return didSave
        } onDelete: {
            if let idx = homeViewModel.items.firstIndex(where: { $0.id == item.id }) {
                homeViewModel.delete(at: IndexSet(integer: idx))
            }
            editingItem = nil
        }
    }

    private func summaryPlaybackSheet(_ playback: SummaryPlayback) -> some View {
        SummaryPlaybackSheet(
            playback: playback,
            petEnabled: settingsViewModel.petCompanionEnabled,
            isMember: hasMemberAccess,
            weeklySharePayload: weeklySharePayload(for: playback),
            shareNickname: settingsViewModel.displayName,
            onCompleted: { progress in
                quotaStore.markCompleted(playback.range, isMember: hasMemberAccess, progress: progress)
                if progress >= 0.8 {
                    homeViewModel.markSummaryPlaybackCompleted(playback.range)
                }
                quotaRefreshID = UUID()
            },
            onShowMemberPricing: onShowMemberPricing,
            onOpenWeekly: {
                useCustomRange = false
                selectedPeriod = .week
            },
            onOpenInsight: onOpenInsight
        )
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    private func weeklySharePayload(for playback: SummaryPlayback) -> WeeklyShareCardPayload? {
        guard playback.range == .week else { return nil }
        return playbackService.buildWeeklyShareCardPayload(from: homeViewModel.items, summary: playback)
    }

    private var summaryQuotaAlertBinding: Binding<Bool> {
        Binding(
            get: { summaryQuotaMessage != nil },
            set: { if !$0 { summaryQuotaMessage = nil } }
        )
    }

    @ViewBuilder
    private var summaryQuotaAlertActions: some View {
            Button("了解会员") {
                let shouldOpenMember = summaryQuotaMessage?.contains("会员") ?? false
                summaryQuotaMessage = nil
                if shouldOpenMember { onShowMemberPricing?() }
            }
            Button("知道了", role: .cancel) {
                summaryQuotaMessage = nil
            }
    }

    // MARK: - Summary Playback Card

    @ViewBuilder
    private var summarySliceCard: some View {
        let _ = quotaRefreshID
        if useCustomRange || selectedPeriod == .year {
            EmptyView()
        } else {
            let range = selectedPeriod == .week ? SummaryPlaybackRange.week : .month
            let preview = buildSummaryPreview(for: range)
            let hasData = preview.count > 0
            let canPlay = hasData && quotaStore.canPlay(range, isMember: hasMemberAccess)
            let isMonthLocked = range == .month && !hasMemberAccess && quotaStore.monthRemaining(isMember: false) <= 0

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Text(isMonthLocked ? "🔒" : "🎬")
                        .font(.system(size: 24))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(range == .week ? "本周回放" : "本月回放")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppColors.text)
                        Text(summaryCardSubtitle(preview: preview, range: range, hasData: hasData, isMonthLocked: isMonthLocked))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.subtext)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }

                let playbackButtonTitle = isMonthLocked ? "了解会员" : "听听这一段"
                let playbackForeground = canPlay ? Color.white : AppColors.text.opacity(0.72)
                let playbackFill = canPlay ? AppColors.accent : Color.white.opacity(0.64)
                let playbackStroke = canPlay ? AppColors.accent.opacity(0.28) : Color.white.opacity(0.58)

                HStack(spacing: 12) {
                    Button {
                        handleSummaryPlaybackTap(range: range, preview: preview)
                    } label: {
                        Text(playbackButtonTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(playbackForeground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(playbackFill)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(playbackStroke, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasData && !isMonthLocked)
                }

                Text(summaryQuotaFootnote(range: range, hasData: hasData))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(range == .month && isMonthLocked ? AppColors.lockGold : AppColors.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .glassPanel(radius: 24, padding: 20)
        }
    }

    private func buildSummaryPreview(for range: SummaryPlaybackRange) -> SummaryPlayback {
        switch range {
        case .week:
            return playbackService.buildWeekSummary(from: homeViewModel.items)
        case .month:
            return playbackService.buildMonthSummary(from: homeViewModel.items)
        }
    }

    private func summaryCardSubtitle(preview: SummaryPlayback, range: SummaryPlaybackRange, hasData: Bool, isMonthLocked: Bool) -> String {
        guard hasData else { return "先留下几笔，这里就能讲出这一段。" }
        if isMonthLocked {
            return "会员专属 · 你的 3 次新用户体验已用完"
        }
        if !preview.teaserLine.isEmpty {
            return preview.teaserLine
        }
        switch range {
        case .week:
            if homeViewModel.items.count >= 5 && !quotaStore.hasCompletedWeekPlaybackEver() {
                return "已记 \(homeViewModel.items.count) 笔，可以讲这周的故事了"
            }
            let category = preview.topCategory.map { "\($0)为主" } ?? "日常为主"
            return "\(preview.count) 笔 · \(preview.total.formatted(.cny)) · \(category)"
        case .month:
            return "\(preview.count) 笔 · \(preview.total.formatted(.cny)) · 分段看完整月节奏"
        }
    }

    private func summaryQuotaFootnote(range: SummaryPlaybackRange, hasData: Bool) -> String {
        guard hasData else { return "回放使用本地模板生成，不依赖 AI 服务。" }
        guard !hasMemberAccess else { return "会员可无限回看周/月回放。" }
        switch range {
        case .week:
            let remaining = quotaStore.weekRemaining(isMember: false)
            return remaining > 0 ? "本周剩余 1 次 · 会员可无限" : "本周剩余 0 次 · 下个自然周刷新"
        case .month:
            let remaining = quotaStore.monthRemaining(isMember: false)
            return remaining > 0
                ? "新用户专享剩余 \(remaining)/3 次 · 用完后需会员"
                : "本月回放体验已用完 · 会员可无限回看"
        }
    }

    private func handleSummaryPlaybackTap(range: SummaryPlaybackRange, preview: SummaryPlayback) {
        guard preview.count > 0 else { return }
        guard quotaStore.canPlay(range, isMember: hasMemberAccess) else {
            switch range {
            case .week:
                summaryQuotaMessage = "本周回放已经看完啦。下个自然周会再刷新 1 次免费次数。开通会员可无限回看周/月回放。"
            case .month:
                summaryQuotaMessage = "你的 3 次新用户「本月回放」已用完。开通会员可无限播放周/月回放，并享无限 OCR 与更高 AI 复盘额度。本周回放仍会在每个自然周刷新 1 次免费次数。"
            }
            return
        }
        let copySeed = nextSummaryCopySeed(for: range)
        summaryPlayback = buildSummaryPlayback(for: range, copySeed: copySeed)
    }

    private func buildSummaryPlayback(for range: SummaryPlaybackRange, copySeed: String) -> SummaryPlayback {
        switch range {
        case .week:
            return playbackService.buildWeekSummary(from: homeViewModel.items, copySeed: copySeed)
        case .month:
            return playbackService.buildMonthSummary(from: homeViewModel.items, copySeed: copySeed)
        }
    }

    private func nextSummaryCopySeed(for range: SummaryPlaybackRange) -> String {
        let period = summaryCopyPeriodKey(for: range)
        let key = "summary_copy_variant_\(range.rawValue)_\(period)"
        let defaults = UserDefaults.standard
        let next = defaults.integer(forKey: key) + 1
        defaults.set(next, forKey: key)
        return "open-\(next)"
    }

    private func summaryCopyPeriodKey(for range: SummaryPlaybackRange) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        switch range {
        case .week:
            formatter.dateFormat = "yyyy-'W'ww"
        case .month:
            formatter.dateFormat = "yyyy-MM"
        }
        return formatter.string(from: .now)
    }

    // MARK: - Period Picker Sheet

    private var periodPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Text("选择时间范围")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppColors.text)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(StatsPeriod.allCases) { period in
                    periodOptionButton(period)
                }

                // Custom date range
                customDateRangePicker
            }
            .padding(24)
            .background(AppColors.bg.ignoresSafeArea())
            .navigationTitle("时间范围")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showPeriodSheet = false }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func periodOptionButton(_ period: StatsPeriod) -> some View {
        let isSelected = !useCustomRange && selectedPeriod == period
        return Button {
            useCustomRange = false
            selectedPeriod = period
            showPeriodSheet = false
        } label: {
            periodOptionLabel(period, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func periodOptionLabel(_ period: StatsPeriod, isSelected: Bool) -> some View {
        HStack {
            Text(period.rawValue)
                .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.accent)
            }
        }
        .foregroundStyle(AppColors.text)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(periodOptionBackground(isSelected: isSelected))
    }

    private func periodOptionBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(isSelected ? AppColors.accent.opacity(0.1) : Color.white.opacity(0.62))
    }

    private var customDateRangePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("自定义日期")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppColors.text.opacity(0.8))
            DatePicker("开始", selection: $customStartDate, displayedComponents: [.date])
                .datePickerStyle(.compact)
            DatePicker("结束", selection: $customEndDate, displayedComponents: [.date])
                .datePickerStyle(.compact)
            applyCustomDateButton
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.62))
        )
    }

    private var applyCustomDateButton: some View {
        Button {
            useCustomRange = true
            showPeriodSheet = false
        } label: {
            Text("应用自定义日期")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Simplified Category Filter Chips (no longer used, replaced by Menu)

    private func billRecordRow(_ item: HomeItem, isFirst: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                Spacer()
                Text(item.amount.formatted(.cny))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.text)
            }

            let emotionTag = item.displayEmotionTag
            if !emotionTag.isEmpty {
                Text(emotionTag)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.accent.opacity(0.74))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule(style: .continuous).fill(AppColors.accent.opacity(0.08)))
                    .overlay(Capsule(style: .continuous).stroke(AppColors.accent.opacity(0.18), lineWidth: 0.7))
                    .padding(.bottom, 4)
            }

            HStack(spacing: 6) {
                Text(item.category.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.subtext.opacity(0.82))
                Text("·").foregroundStyle(AppColors.subtext)
                Text(item.createdAt.zhBillDateTime)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .overlay(alignment: .top) {
            if !isFirst {
                PaperCreaseDivider()
                    .padding(.top, -10)
            }
        }
    }

    private func traceDetailBillRecordRow(_ item: HomeItem, isFirst: Bool) -> some View {
        HStack(alignment: .center, spacing: 10) {
            billRecordRow(item, isFirst: isFirst)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                openEditor(for: item, fromTraceDetail: true)
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.accent.opacity(0.88))
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.60))
                    )
                    .overlay(
                        Circle()
                            .stroke(AppColors.accent.opacity(0.18), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("编辑账单")
        }
    }

    // MARK: - Category Filter Chip

    private func categoryFilterChip(label: String, category: HomeItem.Category?) -> some View {
        let isSelected = selectedCategory == category
        return Button(label) {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedCategory = category
            }
        }
        .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .rounded))
        .foregroundStyle(isSelected ? .white : AppColors.text.opacity(0.82))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            isSelected
                ? AppColors.accent
                : Color.white.opacity(0.72),
            in: Capsule(style: .continuous)
        )
        .shadow(color: isSelected ? AppColors.accent.opacity(0.2) : .clear, radius: 4, y: 2)
    }

    // MARK: - Record List Item

    private func recordListItem(_ item: HomeItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                Spacer()
                Text(item.amount.formatted(.cny))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.text)
            }

            HStack(spacing: 6) {
                Text(item.category.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.subtext.opacity(0.82))

                Text("·")
                    .foregroundStyle(AppColors.subtext)

                Text(item.createdAt.zhBillDateTime)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .overlay(alignment: .top) {
            PaperCreaseDivider()
                .padding(.top, -4)
        }
    }

    // MARK: - Trend Chart

    @ViewBuilder
    private var trendChart: some View {
        let trendData = computeTrendData()
        VStack(alignment: .leading, spacing: 6) {
            Text("一点走势")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.subtext)

            if trendData.isEmpty {
                Text("近 30 天还没有足够的痕迹。")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext)
                    .padding(.vertical, 12)
            } else {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h: CGFloat = 48
                    let maxVal = trendData.map(\.value).max() ?? 1
                    let padding: CGFloat = 8
                    let chartW = w - padding * 2
                    let chartH = h - padding * 2

                    ZStack(alignment: .topLeading) {
                        // Y axis
                        Path { p in
                            p.move(to: CGPoint(x: padding, y: padding))
                            p.addLine(to: CGPoint(x: padding, y: h - padding))
                        }
                        .stroke(AppColors.subtext.opacity(0.3), lineWidth: 1)

                        // X axis
                        Path { p in
                            p.move(to: CGPoint(x: padding, y: h - padding))
                            p.addLine(to: CGPoint(x: w - padding, y: h - padding))
                        }
                        .stroke(AppColors.subtext.opacity(0.3), lineWidth: 1)

                        // Max label
                        Text("\(Int(maxVal))")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.subtext.opacity(0.82))
                            .offset(x: padding + 2, y: 0)

                        // Trend line
                        if trendData.count >= 2 {
                            Path { p in
                                for (i, point) in trendData.enumerated() {
                                    let x = padding + (chartW / CGFloat(max(trendData.count - 1, 1))) * CGFloat(i)
                                    let y = padding + chartH - (CGFloat(point.value) / CGFloat(maxVal)) * chartH
                                    if i == 0 {
                                        p.move(to: CGPoint(x: x, y: y))
                                    } else {
                                        p.addLine(to: CGPoint(x: x, y: y))
                                    }
                                }
                            }
                            .stroke(AppColors.accent.opacity(0.86), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        }

                        // Peak dot
                        if let peak = trendData.max(by: { $0.value < $1.value }),
                           let idx = trendData.firstIndex(where: { $0.id == peak.id }) {
                            let x = padding + (chartW / CGFloat(max(trendData.count - 1, 1))) * CGFloat(idx)
                            let y = padding + chartH - (CGFloat(peak.value) / CGFloat(maxVal)) * chartH
                            Circle()
                                .fill(AppColors.accent.opacity(0.86))
                                .frame(width: 6, height: 6)
                                .position(x: x, y: y)
                            Text(peak.value.formatted(.cny))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AppColors.text.opacity(0.88))
                                .position(x: min(x + 24, w - 30), y: y - 14)
                        }
                    }
                }
                .frame(height: 52)
            }
        }
    }

    private struct TrendPoint: Identifiable {
        let id = UUID()
        let day: String
        let value: Double
    }

    private func computeTrendData() -> [TrendPoint] {
        let cal = Calendar.current
        let trendItems = filteredItems.filter { $0.amount > 0 && $0.draftMeta == nil }
        guard !trendItems.isEmpty else { return [] }

        if !useCustomRange, selectedPeriod == .year {
            let currentYear = cal.component(.year, from: Date())
            let points = (1...12).map { month -> TrendPoint in
                let total = trendItems
                    .filter {
                        cal.component(.year, from: $0.createdAt) == currentYear &&
                        cal.component(.month, from: $0.createdAt) == month
                    }
                    .reduce(0) { $0 + $1.amount }
                return TrendPoint(day: "\(month)月", value: total)
            }
            return points.contains { $0.value > 0 } ? points : []
        }

        guard let interval = trendDateInterval(calendar: cal) else { return [] }
        let startDay = cal.startOfDay(for: interval.start)
        let inclusiveEnd = cal.date(byAdding: .second, value: -1, to: interval.end) ?? interval.end
        let endDay = cal.startOfDay(for: inclusiveEnd)
        let dayCount = max(cal.dateComponents([.day], from: startDay, to: endDay).day ?? 0, 0)
        let points = (0...dayCount).compactMap { offset -> TrendPoint? in
            guard let date = cal.date(byAdding: .day, value: offset, to: startDay) else { return nil }
            let total = trendItems
                .filter { cal.isDate($0.createdAt, inSameDayAs: date) }
                .reduce(0) { $0 + $1.amount }
            return TrendPoint(day: "\(cal.component(.day, from: date))", value: total)
        }
        return points.contains { $0.value > 0 } ? points : []
    }

    private func trendDateInterval(calendar cal: Calendar) -> DateInterval? {
        if useCustomRange {
            let start = cal.startOfDay(for: min(customStartDate, customEndDate))
            let endBase = cal.startOfDay(for: max(customStartDate, customEndDate))
            let end = cal.date(byAdding: .day, value: 1, to: endBase) ?? endBase
            return DateInterval(start: start, end: end)
        }

        switch selectedPeriod {
        case .week:
            return PlaybackService.isoCalendar.dateInterval(of: .weekOfYear, for: Date())
        case .month:
            guard let month = cal.dateInterval(of: .month, for: Date()) else { return nil }
            return DateInterval(start: month.start, end: min(month.end, Date()))
        case .year:
            return cal.dateInterval(of: .year, for: Date())
        }
    }

    private func trendInsightText(data: [TrendPoint]) -> String {
        let active = data.filter { $0.value > 0 }
        guard let peak = active.max(by: { $0.value < $1.value }) else {
            return "这一段还没有足够走势。"
        }
        if active.count == 1 {
            return "这一段主要落在 \(peak.day)。"
        }
        let firstHalf = data.prefix(max(data.count / 2, 1)).reduce(0) { $0 + $1.value }
        let secondHalf = data.suffix(max(data.count - data.count / 2, 1)).reduce(0) { $0 + $1.value }
        if secondHalf > firstHalf * 1.18 {
            return "这一段后半更密一些。"
        } else if firstHalf > secondHalf * 1.18 {
            return "这一段前半更密一些。"
        }
        return "\(peak.day) 最明显，其余日子比较分散。"
    }
}
