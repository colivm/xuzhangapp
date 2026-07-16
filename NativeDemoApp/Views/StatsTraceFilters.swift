import SwiftUI

extension StatsWebView {

    private var customStartDateBinding: Binding<Date> {
        Binding(
            get: { customStartDate },
            set: { customStartDate = $0 }
        )
    }

    private var customEndDateBinding: Binding<Date> {
        Binding(
            get: { customEndDate },
            set: { customEndDate = $0 }
        )
    }

    var tracePeriodFilter: some View {
        VStack(alignment: .leading, spacing: 4) {
            filterLabel("时间")
            Menu {
                Button("本周") {
                    applyTracePeriod(.week)
                }
                Button("本月") {
                    applyTracePeriod(.month)
                }
                Button("本年") {
                    applyTracePeriod(.year)
                }
                Button("具体时间段") {
                    withAnimation(traceEditSpring) {
                        showTraceCustomDatePanel.toggle()
                        traceInlineEditingItemID = nil
                        traceSwipedItemID = nil
                    }
                }
            } label: {
                filterButtonLabel(useCustomRange ? "具体时间段" : selectedPeriod.rawValue)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    var traceCategoryFilter: some View {
        VStack(alignment: .leading, spacing: 4) {
            filterLabel("分类")
            Menu {
                Button("全部分类") {
                    applyTraceCategory(nil)
                }
                ForEach(HomeItem.Category.allCases) { category in
                    Button(category.displayName) {
                        applyTraceCategory(category)
                    }
                }
            } label: {
                filterButtonLabel(selectedCategory?.rawValue ?? "全部分类")
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    var traceCustomDatePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            traceQuickRangeGrid

            HStack(spacing: 8) {
                traceInlineDatePicker(title: "开始", selection: customStartDateBinding)
                traceInlineDatePicker(title: "结束", selection: customEndDateBinding)
            }

            HStack(spacing: 8) {
                Button("取消") {
                    withAnimation(traceEditSpring) {
                        showTraceCustomDatePanel = false
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.subtext.opacity(0.86))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.45))
                )

                Button("应用") {
                    withAnimation(traceEditSpring) {
                        if customStartDate > customEndDate {
                            let start = customStartDate
                            customStartDate = customEndDate
                            customEndDate = start
                        }
                        useCustomRange = true
                        showTraceCustomDatePanel = false
                        traceInlineEditingItemID = nil
                        traceSwipedItemID = nil
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.accent.opacity(0.86))
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.42))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.46), lineWidth: 1)
        )
    }

    private var traceQuickRangeGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 7)], spacing: 7) {
            traceQuickRangeButton("今天") {
                setTraceCustomRange(.today)
            }
            traceQuickRangeButton("昨天") {
                setTraceCustomRange(.yesterday)
            }
            traceQuickRangeButton("本周") {
                setTraceCustomRange(.thisWeek)
            }
            traceQuickRangeButton("本月") {
                setTraceCustomRange(.thisMonth)
            }
            traceQuickRangeButton("近7天") {
                setTraceCustomRange(.last7Days)
            }
            traceQuickRangeButton("近30天") {
                setTraceCustomRange(.last30Days)
            }
        }
    }

    private func traceQuickRangeButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.text.opacity(0.78))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.52))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(AppColors.accent.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func setTraceCustomRange(_ preset: TraceCustomRangePreset) {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let range: (Date, Date)

        switch preset {
        case .today:
            range = (today, today)
        case .yesterday:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            range = (yesterday, yesterday)
        case .thisWeek:
            let interval = PlaybackService.isoCalendar.dateInterval(of: .weekOfYear, for: now)
            range = (interval?.start ?? today, today)
        case .thisMonth:
            let interval = calendar.dateInterval(of: .month, for: now)
            range = (interval?.start ?? today, today)
        case .last7Days:
            range = (calendar.date(byAdding: .day, value: -6, to: today) ?? today, today)
        case .last30Days:
            range = (calendar.date(byAdding: .day, value: -29, to: today) ?? today, today)
        }

        withAnimation(.easeInOut(duration: 0.16)) {
            customStartDate = range.0
            customEndDate = range.1
        }
    }

    private func traceInlineDatePicker(title: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.subtext)

            HStack(spacing: 6) {
                traceDateStepButton(systemName: "chevron.left") {
                    shiftTraceDate(selection, by: -1)
                }

                Text(traceCompactDateText(selection.wrappedValue))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.text.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                    .frame(maxWidth: .infinity)

                traceDateStepButton(systemName: "chevron.right") {
                    shiftTraceDate(selection, by: 1)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.white.opacity(0.58))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(Color.white.opacity(0.46), lineWidth: 1)
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.34))
        )
    }

    private func traceDateStepButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppColors.accent.opacity(0.86))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(AppColors.accent.opacity(0.09))
                )
        }
        .buttonStyle(.plain)
    }

    private func shiftTraceDate(_ selection: Binding<Date>, by days: Int) {
        let next = Calendar.current.date(byAdding: .day, value: days, to: selection.wrappedValue) ?? selection.wrappedValue
        withAnimation(.easeInOut(duration: 0.16)) {
            selection.wrappedValue = next
        }
    }

    private func traceCompactDateText(_ date: Date) -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return "\(month)月\(day)日 \(weekdayText(for: date))"
    }

    func applyTracePeriod(_ period: StatsPeriod) {
        guard useCustomRange || selectedPeriod != period || showTraceCustomDatePanel else {
            return
        }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            useCustomRange = false
            selectedPeriod = period
            showTraceCustomDatePanel = false
            traceInlineEditingItemID = nil
            traceSwipedItemID = nil
        }
    }

    private func applyTraceCategory(_ category: HomeItem.Category?) {
        withAnimation(traceEditSpring) {
            selectedCategory = category
            traceInlineEditingItemID = nil
            traceSwipedItemID = nil
        }
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

    // MARK: - Period Picker Sheet

    var periodPickerSheet: some View {
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
        VStack(alignment: .leading, spacing: 10) {
            Text("自定义日期")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppColors.text.opacity(0.8))

            HStack(spacing: 8) {
                customDateEndpointButton("开始", date: customStartDate, endpoint: .start)
                customDateEndpointButton("结束", date: customEndDate, endpoint: .end)
            }

            if customDateFocus == .start {
                WarmRecordDatePanel(selection: customStartDateBinding)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                WarmRecordDatePanel(selection: customEndDateBinding)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            applyCustomDateButton
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.62))
        )
    }

    private func customDateEndpointButton(_ title: String, date: Date, endpoint: CustomDateEndpoint) -> some View {
        let isSelected = customDateFocus == endpoint
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                customDateFocus = endpoint
            }
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.subtext)
                Spacer(minLength: 4)
                Text(date.zhBillDateOnly)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(customDateEndpointBackground(isSelected: isSelected))
        }
        .buttonStyle(.plain)
    }

    private func customDateEndpointBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(isSelected ? AppColors.accent.opacity(0.14) : Color.white.opacity(0.62))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? AppColors.accent.opacity(0.28) : Color.white.opacity(0.4), lineWidth: 1)
            )
    }

    var categoryFilterSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("选择分类")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppColors.text)

                    Button {
                        selectedCategory = nil
                        showCategoryFilterSheet = false
                    } label: {
                        categorySheetOptionLabel(
                            title: "全部分类",
                            subtitle: "看这一段完整的生活记录",
                            emoji: "✨",
                            isSelected: selectedCategory == nil
                        )
                    }
                    .buttonStyle(.plain)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 10)], spacing: 10) {
                        ForEach(HomeItem.Category.allCases) { category in
                            Button {
                                selectedCategory = category
                                showCategoryFilterSheet = false
                            } label: {
                                categorySheetOptionLabel(
                                    title: category.label,
                                    subtitle: category.rawValue,
                                    emoji: category.emoji,
                                    isSelected: selectedCategory == category
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(22)
            }
            .scrollIndicators(.hidden)
            .background(AppColors.bg.ignoresSafeArea())
            .navigationTitle("分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { showCategoryFilterSheet = false }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func categorySheetOptionLabel(title: String, subtitle: String, emoji: String, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Text(emoji)
                .font(.system(size: 22))
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(isSelected ? AppColors.accent.opacity(0.18) : Color.white.opacity(0.56))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.subtext)
            }

            Spacer(minLength: 4)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColors.accent)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(categorySheetOptionBackground(isSelected: isSelected))
    }

    private func categorySheetOptionBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(isSelected ? AppColors.accent.opacity(0.12) : Color.white.opacity(0.66))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? AppColors.accent.opacity(0.28) : Color.white.opacity(0.46), lineWidth: 1)
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
}
