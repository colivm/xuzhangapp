import Foundation
import SwiftUI

struct WarmRecordDatePanel: View {
    @Binding var selection: Date
    var onSelectionChanged: () -> Void = {}
    @State private var calendarMonth: Date

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.locale = Locale(identifier: "zh_CN")
        value.firstWeekday = 2
        return value
    }

    init(selection: Binding<Date>, onSelectionChanged: @escaping () -> Void = {}) {
        self._selection = selection
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

            HStack(spacing: 10) {
                timeStepper(title: "时", value: calendar.component(.hour, from: selection), range: 0...23) { setHour($0) }
                timeStepper(title: "分", value: calendar.component(.minute, from: selection), range: 0...59) { setMinute($0) }
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

    private func timeStepper(title: String, value: Int, range: ClosedRange<Int>, onSet: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.subtext)
            Button {
                onSet(value == range.lowerBound ? range.upperBound : value - 1)
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColors.accent)

            Text(String(format: "%02d", value))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.text)
                .frame(width: 30)

            Button {
                onSet(value == range.upperBound ? range.lowerBound : value + 1)
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColors.accent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.56))
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

    private func setHour(_ hour: Int) {
        var components = calendar.dateComponents([.year, .month, .day, .minute], from: selection)
        components.hour = hour
        selection = calendar.date(from: components) ?? selection
        onSelectionChanged()
    }

    private func setMinute(_ minute: Int) {
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: selection)
        components.minute = minute
        selection = calendar.date(from: components) ?? selection
        onSelectionChanged()
    }
}
