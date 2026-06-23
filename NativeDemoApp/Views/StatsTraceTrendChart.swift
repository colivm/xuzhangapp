import SwiftUI

extension StatsWebView {

    // MARK: - Trend Chart

    @ViewBuilder
    var trendChart: some View {
        let trendData = computeTrendData()
        let activeData = trendData.filter { $0.value > 0 }
        VStack(alignment: .leading, spacing: 6) {
            Text(activeData.count >= 2 ? "一点走势" : "暂时不画走势")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.subtext)

            if trendData.isEmpty {
                Text("这一段还没有能连起来看的记录。")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext)
                    .padding(.vertical, 12)
            } else if activeData.count < 2 {
                traceTrendQuietSummary(activeData.first)
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

    private func traceTrendQuietSummary(_ point: TrendPoint?) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(AppColors.accent.opacity(0.68))
                .frame(width: 8, height: 8)
            Text(point.map { "这一段只有 \($0.day) 有记录，先等多几天再看走势。" } ?? "多留下几天，走势会自然出来。")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.text.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.38))
        )
    }

    func computeTrendData() -> [TrendPoint] {
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
        let totalsByDay = trendItems.reduce(into: [Date: Double]()) { result, item in
            let day = cal.startOfDay(for: item.createdAt)
            result[day, default: 0] += item.amount
        }
        let points = (0...dayCount).compactMap { offset -> TrendPoint? in
            guard let date = cal.date(byAdding: .day, value: offset, to: startDay) else { return nil }
            let total = totalsByDay[cal.startOfDay(for: date), default: 0]
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

    func trendInsightText(data: [TrendPoint]) -> String {
        let active = data.filter { $0.value > 0 }
        guard let peak = active.max(by: { $0.value < $1.value }) else {
            return "这一段还没有能连起来看的记录。"
        }
        if active.count == 1 {
            return "这一段只有 \(peak.day) 有记录，先不用急着看走势。"
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
