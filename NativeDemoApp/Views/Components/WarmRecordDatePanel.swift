import Foundation
import SwiftUI

enum RecordTimeSelectionPolicy {
    static func applyingTime(
        hour: Int,
        minute: Int,
        to source: Date,
        calendar: Calendar = .current
    ) -> Date {
        let normalizedHour = min(max(hour, 0), 23)
        let normalizedMinute = min(max(minute, 0), 59)
        let startOfDay = calendar.startOfDay(for: source)
        if let matched = calendar.date(
            bySettingHour: normalizedHour,
            minute: normalizedMinute,
            second: 0,
            of: startOfDay,
            matchingPolicy: .nextTimePreservingSmallerComponents,
            repeatedTimePolicy: .first,
            direction: .forward
        ), calendar.isDate(matched, inSameDayAs: source) {
            return matched
        }

        var components = calendar.dateComponents([.era, .year, .month, .day], from: source)
        components.hour = normalizedHour
        components.minute = normalizedMinute
        components.second = 0
        return calendar.date(from: components) ?? source
    }
}

private struct RecordTimePickerPresentation: Identifiable, Equatable {
    let id = UUID()
    let sourceSelection: Date
}

private struct WarmRecordTimePickerSheet: View {
    let sourceSelection: Date
    let calendar: Calendar
    let onCancel: () -> Void
    let onCommit: (Date) -> Void
    @State private var draftHour: Int
    @State private var draftMinute: Int

    init(
        sourceSelection: Date,
        calendar: Calendar,
        onCancel: @escaping () -> Void,
        onCommit: @escaping (Date) -> Void
    ) {
        self.sourceSelection = sourceSelection
        self.calendar = calendar
        self.onCancel = onCancel
        self.onCommit = onCommit
        self._draftHour = State(initialValue: calendar.component(.hour, from: sourceSelection))
        self._draftMinute = State(initialValue: calendar.component(.minute, from: sourceSelection))
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("取消", action: onCancel)
                    .frame(minWidth: 44, minHeight: 44)

                Spacer()

                Text("选择时间")
                    .font(.headline)
                    .foregroundStyle(AppColors.text)

                Spacer()

                Button("完成") {
                    onCommit(RecordTimeSelectionPolicy.applyingTime(
                        hour: draftHour,
                        minute: draftMinute,
                        to: sourceSelection,
                        calendar: calendar
                    ))
                }
                .fontWeight(.semibold)
                .frame(minWidth: 44, minHeight: 44)
            }
            .foregroundStyle(AppColors.accent)

            HStack(spacing: 6) {
                Picker("小时", selection: $draftHour) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(String(format: "%02d", hour)).tag(hour)
                    }
                }
                .pickerStyle(.wheel)
                .accessibilityLabel("小时")

                Text(":")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppColors.subtext)

                Picker("分钟", selection: $draftMinute) {
                    ForEach(0..<60, id: \.self) { minute in
                        Text(String(format: "%02d", minute)).tag(minute)
                    }
                }
                .pickerStyle(.wheel)
                .accessibilityLabel("分钟")
            }
            .frame(height: 176)

            if calendar.isDateInToday(sourceSelection) {
                Button {
                    let now = Date()
                    draftHour = calendar.component(.hour, from: now)
                    draftMinute = calendar.component(.minute, from: now)
                } label: {
                    Label("现在", systemImage: "clock.arrow.circlepath")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColors.accent)
                .background(
                    Capsule(style: .continuous)
                        .fill(AppColors.accent.opacity(0.09))
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 18)
        .background(AppColors.panel.ignoresSafeArea())
    }
}

struct WarmRecordDatePanel: View {
    @Binding var selection: Date
    var onSelectionChanged: () -> Void = {}
    let showsTimeSelection: Bool
    @State private var calendarMonth: Date
    @State private var timePickerPresentation: RecordTimePickerPresentation?

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.locale = Locale(identifier: "zh_CN")
        value.firstWeekday = 2
        return value
    }

    init(
        selection: Binding<Date>,
        showsTimeSelection: Bool = true,
        onSelectionChanged: @escaping () -> Void = {}
    ) {
        self._selection = selection
        self.showsTimeSelection = showsTimeSelection
        self.onSelectionChanged = onSelectionChanged
        self._calendarMonth = State(initialValue: Self.monthStart(for: selection.wrappedValue))
    }

    static func monthStart(for date: Date) -> Date {
        var value = Calendar(identifier: .gregorian)
        value.locale = Locale(identifier: "zh_CN")
        value.firstWeekday = 2
        return value.date(from: value.dateComponents([.year, .month], from: date)) ?? date
    }

    private var monthTitle: String {
        Self.monthTitleFormatter.string(from: calendarMonth)
    }

    private static let monthTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }()

    private var calendarDays: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: calendarMonth),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let lastWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end.addingTimeInterval(-1))
        else { return [] }

        var days: [Date?] = []
        var cursor = firstWeek.start
        while cursor < lastWeek.end {
            days.append(calendar.isDate(cursor, equalTo: calendarMonth, toGranularity: .month) ? cursor : nil)
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? lastWeek.end
        }
        return days
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    shiftMonth(-1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColors.accent)

                Spacer()

                Text(monthTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.text)

                Spacer()

                Button {
                    shiftMonth(1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColors.accent)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 6) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.subtext.opacity(0.72))
                        .frame(height: 20)
                }
                ForEach(Array(calendarDays.enumerated()), id: \.offset) { pair in
                    if let date = pair.element {
                        dayButton(date)
                    } else {
                        Color.clear.frame(height: 34)
                    }
                }
            }

            if showsTimeSelection {
                timeSelectionButton
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColors.accent.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppColors.accent.opacity(0.14), lineWidth: 1)
        )
        .sheet(item: $timePickerPresentation) { presentation in
            WarmRecordTimePickerSheet(
                sourceSelection: presentation.sourceSelection,
                calendar: calendar,
                onCancel: {
                    timePickerPresentation = nil
                },
                onCommit: { committedSelection in
                    timePickerPresentation = nil
                    commitTime(committedSelection)
                }
            )
            .presentationDetents([.height(340)])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: selection) { _, newSelection in
            if let presentation = timePickerPresentation,
               presentation.sourceSelection != newSelection {
                timePickerPresentation = nil
            }
            if !calendar.isDate(newSelection, equalTo: calendarMonth, toGranularity: .month) {
                calendarMonth = Self.monthStart(for: newSelection)
            }
        }
    }

    private func dayButton(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selection)
        let dayText = String(calendar.component(.day, from: date))
        return Button {
            setDay(date)
        } label: {
            dayButtonLabel(dayText, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func dayButtonLabel(_ title: String, isSelected: Bool) -> some View {
        let weight: Font.Weight = isSelected ? .semibold : .regular
        let foreground: Color = isSelected ? AppColors.text : AppColors.subtext
        return Text(title)
            .font(.system(size: 13, weight: weight))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(dayButtonBackground(isSelected: isSelected))
            .overlay(dayButtonBorder(isSelected: isSelected))
    }

    private func dayButtonBackground(isSelected: Bool) -> some View {
        let fill = isSelected ? AppColors.accent.opacity(0.20) : Color.white.opacity(0.38)
        return Circle().fill(fill)
    }

    private func dayButtonBorder(isSelected: Bool) -> some View {
        let stroke = isSelected ? AppColors.accent.opacity(0.36) : Color.white.opacity(0.18)
        return Circle().stroke(stroke, lineWidth: 1)
    }

    private var timeSelectionButton: some View {
        Button {
            timePickerPresentation = RecordTimePickerPresentation(sourceSelection: selection)
        } label: {
            HStack(spacing: 10) {
                Label("时间", systemImage: "clock")
                    .font(.system(size: 13, weight: .medium))

                Spacer(minLength: 8)

                Text(String(format: "%02d:%02d", calendar.component(.hour, from: selection), calendar.component(.minute, from: selection)))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(AppColors.text)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.56))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "修改时间，当前 \(calendar.component(.hour, from: selection)) 点 \(calendar.component(.minute, from: selection)) 分"
        )
    }

    private func shiftMonth(_ value: Int) {
        calendarMonth = calendar.date(byAdding: .month, value: value, to: calendarMonth) ?? calendarMonth
    }

    private func setDay(_ date: Date) {
        var selectedComponents = calendar.dateComponents([.hour, .minute], from: selection)
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: date)
        selectedComponents.year = dayComponents.year
        selectedComponents.month = dayComponents.month
        selectedComponents.day = dayComponents.day
        selection = calendar.date(from: selectedComponents) ?? selection
        onSelectionChanged()
    }

    private func commitTime(_ committedSelection: Date) {
        guard committedSelection != selection else { return }
        selection = committedSelection
        onSelectionChanged()
    }
}
