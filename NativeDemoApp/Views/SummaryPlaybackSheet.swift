import SwiftUI

struct SummaryPlaybackSheet: View {
    let playback: SummaryPlayback
    let petEnabled: Bool
    let isMember: Bool
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
            backgroundGradient.ignoresSafeArea()

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
    }

    private var backgroundGradient: LinearGradient {
        if petEnabled {
            LinearGradient(
                colors: [
                    AppColors.heroGradientPink.opacity(0.34),
                    AppColors.heroGradientTeal.opacity(0.38),
                    AppColors.bg
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.86, green: 0.90, blue: 0.95),
                    Color(red: 0.94, green: 0.96, blue: 0.98),
                    AppColors.bg
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(playback.title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.text)
                Text("\(playback.rangeLabel) · \(playback.count) 笔 · \(playback.total.formatted(.cny))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.subtext)
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
        VStack(spacing: 18) {
            if let chapter = currentChapter {
                Text(chapter.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColors.subtext)
                    .frame(maxWidth: .infinity, alignment: .leading)

                metricView(for: chapter)
                    .id(chapter.id)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))

                Text(petEnabled ? chapter.narration.warm : chapter.narration.plain)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.text)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
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
    private func metricView(for chapter: SummaryChapter) -> some View {
        if let ratioText = chapter.metrics["ratio"], let ratio = Double(ratioText) {
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
        } else if let total = chapter.metrics["total"] {
            VStack(alignment: .leading, spacing: 4) {
                Text(total)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.accentDark)
                    .contentTransition(.numericText())
                metricCaption(chapter)
            }
        } else if let amount = chapter.metrics["amount"] {
            VStack(alignment: .leading, spacing: 4) {
                Text(amount)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.accentDark)
                    .contentTransition(.numericText())
                metricCaption(chapter)
            }
        } else {
            metricCaption(chapter)
        }
    }

    private func metricCaption(_ chapter: SummaryChapter) -> some View {
        let parts = [
            chapter.metrics["count"].map { "\($0) 笔" },
            chapter.metrics["day"],
            chapter.metrics["busiestDay"],
            chapter.metrics["title"],
            chapter.metrics["change"]
        ].compactMap { $0 }
        return Text(parts.first ?? playback.rangeLabel)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(AppColors.subtext)
            .lineLimit(2)
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
