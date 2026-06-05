import SwiftUI
import UIKit

struct SummaryPlaybackSheet: View {
    let playback: SummaryPlayback
    let petEnabled: Bool
    let isMember: Bool
    var weeklySharePayload: WeeklyShareCardPayload?
    var shareNickname: String = "叙帐用户"
    var onCompleted: (Double) -> Void
    var onShowMemberPricing: (() -> Void)? = nil
    var onOpenWeekly: (() -> Void)? = nil
    var onOpenInsight: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var activeIndex = 0
    @State private var isPlaying = true
    @State private var playbackDone = false
    @State private var completionReported = false
    @State private var playbackTask: Task<Void, Never>?
    @State private var shareImage: ShareImage?

    private var currentChapter: SummaryChapter? {
        guard !playback.chapters.isEmpty else { return nil }
        return playback.chapters[min(activeIndex, playback.chapters.count - 1)]
    }

    private var progressFraction: Double {
        guard !playback.chapters.isEmpty else { return 0 }
        if playbackDone { return 1 }
        return Double(activeIndex + 1) / Double(playback.chapters.count)
    }

    var body: some View {
        ZStack {
            backgroundGradient
                .id(currentChapter?.id ?? "empty")
                .transition(.opacity)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Capsule()
                    .fill(Color.white.opacity(0.58))
                    .frame(width: 42, height: 5)
                    .padding(.top, 10)

                header

                Spacer(minLength: 8)

                chapterStage

                Spacer(minLength: 8)

                controls

                if playbackDone {
                    doneActions
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
        .animation(.easeInOut(duration: 0.28), value: currentChapter?.id)
        .onAppear {
            startPlayback()
        }
        .onChange(of: isPlaying) { _, newValue in
            newValue ? startPlayback() : playbackTask?.cancel()
        }
        .onDisappear {
            reportCompletionIfNeeded(progress: progressFraction)
            playbackTask?.cancel()
        }
        .sheet(item: $shareImage) { item in
            ActivityShareSheet(activityItems: [item.image])
        }
    }

    private var backgroundGradient: LinearGradient {
        let palette = chapterPalette(for: currentChapter)
        return LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(playback.title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.text)
                Text(playback.teaserLine)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.subtext)
                    .lineLimit(2)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColors.subtext)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.64), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭")
        }
        .padding(.top, 4)
    }

    private var chapterStage: some View {
        ZStack(alignment: .topTrailing) {
            if let chapter = currentChapter {
                Image(systemName: chapterSymbol(for: chapter))
                    .font(.system(size: 112, weight: .bold))
                    .foregroundStyle(chapterAccent(for: chapter).opacity(0.08))
                    .offset(x: 18, y: -20)
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 16) {
                    Text(chapter.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(chapterAccent(for: chapter))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if shouldShowRangeLabel(for: chapter), let range = chapter.metrics["range"] {
                        Text(range)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.subtext)
                    }

                    Text(petEnabled ? chapter.narration.warm : chapter.narration.plain)
                        .font(.system(size: 23, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.text)
                        .lineSpacing(7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.opacity)

                    chapterSupportView(for: chapter)
                }
                    .id(chapter.id)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 330, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.62))
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.62), lineWidth: 1)
        )
        .shadow(color: AppColors.subtext.opacity(0.16), radius: 22, x: 0, y: 12)
        .animation(.easeInOut(duration: 0.22), value: activeIndex)
    }

    @ViewBuilder
    private func chapterSupportView(for chapter: SummaryChapter) -> some View {
        if hasNoSupportLine(chapter) {
            EmptyView()
        } else if isCategoryChapter(chapter), let ratioText = chapter.metrics["ratio"], let ratio = Double(ratioText) {
            HStack(spacing: 18) {
                RatioRing(progress: max(0, min(ratio / 100, 1)))
                    .frame(width: 96, height: 96)
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(Int(ratio))%")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.accentDark)
                        .contentTransition(.numericText())
                    Text(chapter.metrics["category"] ?? "生活")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.text)
                    Text(chapter.metrics["amount"] ?? "")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColors.subtext)
                }
                Spacer()
            }
        } else if isHighlightChapter(chapter), let title = chapter.metrics["title"] {
            VStack(alignment: .leading, spacing: 10) {
                Text("“\(title)”")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.text)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.68), lineWidth: 1)
                    )
                metricCaption(chapter)
            }
        } else {
            metricCaption(chapter)
        }
    }

    private func metricCaption(_ chapter: SummaryChapter) -> some View {
        let parts = [
            compactIntroMetric(for: chapter),
            rhythmMetric(for: chapter),
            highlightMetric(for: chapter),
            monthSegmentMetric(for: chapter)
        ].compactMap { $0 }
        return Text(parts.first ?? playback.rangeLabel)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(AppColors.subtext)
            .lineLimit(3)
    }

    private func compactIntroMetric(for chapter: SummaryChapter) -> String? {
        guard isIntroChapter(chapter),
              let count = chapter.metrics["count"],
              let total = chapter.metrics["total"] else { return nil }
        if let activeDays = chapter.metrics["activeDays"] {
            let mom = chapter.metrics["momPercent"].flatMap { $0.isEmpty ? nil : " · 较上月 \($0)" } ?? ""
            return "\(activeDays) 天 · \(count) 笔 · \(total)\(mom)"
        }
        return "\(count) 笔 · \(total)"
    }

    private func rhythmMetric(for chapter: SummaryChapter) -> String? {
        guard isRhythmChapter(chapter) else { return nil }
        if let busiest = chapter.metrics["busiestDay"], let count = chapter.metrics["count"] {
            return "\(busiest) · \(count) 笔"
        }
        if let middle = chapter.metrics["middle"], let late = chapter.metrics["late"], let leading = chapter.metrics["leading"] {
            return "\(leading)更热闹 · 中旬 \(middle) · 下旬 \(late)"
        }
        return nil
    }

    private func highlightMetric(for chapter: SummaryChapter) -> String? {
        guard isHighlightChapter(chapter) else { return nil }
        let parts = [chapter.metrics["day"], chapter.metrics["amount"]].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func monthSegmentMetric(for chapter: SummaryChapter) -> String? {
        guard chapter.id == "month-early" else { return nil }
        let parts = [
            chapter.metrics["label"],
            chapter.metrics["count"].map { "\($0) 笔" },
            chapter.metrics["amount"]
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func shouldShowRangeLabel(for chapter: SummaryChapter) -> Bool {
        chapter.id == "week-intro"
    }

    private func isIntroChapter(_ chapter: SummaryChapter) -> Bool {
        chapter.id.contains("intro")
    }

    private func isRhythmChapter(_ chapter: SummaryChapter) -> Bool {
        chapter.id.contains("rhythm") || chapter.id == "month-middle-late"
    }

    private func isCategoryChapter(_ chapter: SummaryChapter) -> Bool {
        chapter.id.contains("category") || chapter.id == "month-composition"
    }

    private func isHighlightChapter(_ chapter: SummaryChapter) -> Bool {
        chapter.id.contains("highlight")
    }

    private func isOutroChapter(_ chapter: SummaryChapter) -> Bool {
        chapter.id.contains("outro") || chapter.id == "month-action"
    }

    private func hasNoSupportLine(_ chapter: SummaryChapter) -> Bool {
        isOutroChapter(chapter) || chapter.id == "month-change"
    }

    private func chapterAccent(for chapter: SummaryChapter?) -> Color {
        guard let chapter else { return AppColors.accent }
        if isCategoryChapter(chapter) { return AppColors.accentDark }
        if isRhythmChapter(chapter) { return Color(red: 0.22, green: 0.50, blue: 0.58) }
        if isHighlightChapter(chapter) { return Color(red: 0.70, green: 0.36, blue: 0.28) }
        if isOutroChapter(chapter) { return Color(red: 0.42, green: 0.46, blue: 0.64) }
        return AppColors.accent
    }

    private func chapterSymbol(for chapter: SummaryChapter) -> String {
        if isCategoryChapter(chapter) { return "chart.pie.fill" }
        if isRhythmChapter(chapter) { return "waveform.path.ecg" }
        if isHighlightChapter(chapter) { return "quote.bubble.fill" }
        if isOutroChapter(chapter) { return "sparkles" }
        return "calendar"
    }

    private func chapterPalette(for chapter: SummaryChapter?) -> [Color] {
        let warmBase: [Color]
        let coolBase: [Color]
        if let chapter, isRhythmChapter(chapter) {
            warmBase = [Color(red: 0.88, green: 0.97, blue: 0.96), Color(red: 1.00, green: 0.93, blue: 0.86), AppColors.bg]
            coolBase = [Color(red: 0.86, green: 0.93, blue: 0.96), Color(red: 0.94, green: 0.97, blue: 0.98), AppColors.bg]
        } else if let chapter, isCategoryChapter(chapter) {
            warmBase = [Color(red: 1.00, green: 0.94, blue: 0.84), Color(red: 0.92, green: 0.97, blue: 0.90), AppColors.bg]
            coolBase = [Color(red: 0.91, green: 0.94, blue: 0.89), Color(red: 0.95, green: 0.97, blue: 0.94), AppColors.bg]
        } else if let chapter, isHighlightChapter(chapter) {
            warmBase = [Color(red: 1.00, green: 0.90, blue: 0.86), Color(red: 1.00, green: 0.95, blue: 0.88), AppColors.bg]
            coolBase = [Color(red: 0.93, green: 0.90, blue: 0.88), Color(red: 0.97, green: 0.95, blue: 0.93), AppColors.bg]
        } else if let chapter, isOutroChapter(chapter) {
            warmBase = [Color(red: 0.97, green: 0.90, blue: 0.98), Color(red: 0.91, green: 0.96, blue: 0.98), AppColors.bg]
            coolBase = [Color(red: 0.89, green: 0.91, blue: 0.96), Color(red: 0.95, green: 0.96, blue: 0.98), AppColors.bg]
        } else {
            warmBase = [AppColors.heroGradientPink.opacity(0.34), AppColors.heroGradientTeal.opacity(0.38), AppColors.bg]
            coolBase = [Color(red: 0.86, green: 0.90, blue: 0.95), Color(red: 0.94, green: 0.96, blue: 0.98), AppColors.bg]
        }
        return petEnabled ? warmBase : coolBase
    }

    private var controls: some View {
        VStack(spacing: 12) {
            ProgressView(value: progressFraction)
                .tint(AppColors.accent)

            HStack(spacing: 12) {
                ForEach(playback.chapters.indices, id: \.self) { index in
                    Circle()
                        .fill(index <= activeIndex ? AppColors.accent : Color.white.opacity(0.54))
                        .frame(width: index == activeIndex ? 9 : 7, height: index == activeIndex ? 9 : 7)
                }
                Spacer()
                Button {
                    restartPlayback()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.64), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("重新播放")

                Button {
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(AppColors.accent, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPlaying ? "暂停" : "播放")
            }
            .foregroundStyle(AppColors.text)
        }
    }

    private var doneActions: some View {
        VStack(spacing: 10) {
            Text(playback.range == .week ? "像不像你的这周？" : "像不像你的这个月？")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.text.opacity(0.82))
                .frame(maxWidth: .infinity, alignment: .leading)

            if playback.range == .week {
                Button {
                    handlePrimaryDoneAction()
                } label: {
                    Text(isMember ? "下周再来" : "了解会员")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    shareWeeklyStoryCard()
                } label: {
                    Text("保存本周故事图")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(weeklySharePayload == nil)

                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        onOpenInsight?()
                    }
                } label: {
                    Text("想多聊一句？")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    handlePrimaryDoneAction()
                } label: {
                    Text(isMember ? "继续回看" : "了解会员")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if playback.range == .month {
                Button {
                    onOpenWeekly?()
                    dismiss()
                } label: {
                    Text("先看本周")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func handlePrimaryDoneAction() {
        if isMember {
            playback.range == .month ? restartPlayback() : dismiss()
        } else {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                onShowMemberPricing?()
            }
        }
    }

    private func shareWeeklyStoryCard() {
        guard let payload = weeklySharePayload else { return }
        let card = WeeklyShareCardView(
            payload: payload,
            isPetMode: petEnabled,
            nickname: shareNickname.isEmpty ? "叙帐用户" : shareNickname
        )
        guard let image = card.snapshot() else { return }
        shareImage = ShareImage(image: image)
    }

    private func startPlayback() {
        guard !playback.chapters.isEmpty, isPlaying else { return }
        playbackTask?.cancel()
        playbackTask = Task {
            while !Task.isCancelled && isPlaying && activeIndex < playback.chapters.count {
                let duration = playback.chapters[activeIndex].durationSec
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    if activeIndex < playback.chapters.count - 1 {
                        activeIndex += 1
                    } else {
                        playbackDone = true
                        isPlaying = false
                        reportCompletionIfNeeded(progress: 1)
                    }
                }
            }
        }
    }

    private func restartPlayback() {
        playbackTask?.cancel()
        activeIndex = 0
        playbackDone = false
        isPlaying = true
        startPlayback()
    }

    private func reportCompletionIfNeeded(progress: Double) {
        guard !completionReported, progress >= 0.8 else { return }
        completionReported = true
        onCompleted(progress)
    }
}

private struct ShareImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct RatioRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.62), lineWidth: 14)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(AppColors.accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle()
                .fill(Color.white.opacity(0.72))
                .frame(width: 48, height: 48)
        }
        .shadow(color: AppColors.accent.opacity(0.16), radius: 12, y: 6)
    }
}
