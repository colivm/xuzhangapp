import SwiftUI

enum ComputationLoadingPresentation {
    case page
    case card
    case inline
}

struct ComputationLoadingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let message: String
    var detail: String? = nil
    var presentation: ComputationLoadingPresentation = .card
    var progress: Double? = nil

    @State private var isBreathing = false

    var body: some View {
        Group {
            switch presentation {
            case .page:
                pageBody
            case .card:
                loadingCard
            case .inline:
                inlineBody
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
        .accessibilityValue(accessibilityStatusValue)
        .accessibilityAddTraits(.updatesFrequently)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
        .onChange(of: reduceMotion) { _, shouldReduce in
            if shouldReduce {
                isBreathing = false
            } else {
                withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true)) {
                    isBreathing = true
                }
            }
        }
    }

    private var pageBody: some View {
        VStack {
            Spacer(minLength: 44)
            loadingCard
                .frame(maxWidth: 310)
            Spacer(minLength: 120)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    private var loadingCard: some View {
        VStack(spacing: 16) {
            paperGlyph

            VStack(spacing: 6) {
                Text(message)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.text.opacity(0.90))
                    .multilineTextAlignment(.center)

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.subtext.opacity(0.78))
                        .multilineTextAlignment(.center)
                }
            }

            if let progress {
                ProgressView(value: min(max(progress, 0), 1))
                    .tint(AppColors.accent)
                    .frame(maxWidth: 210)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppColors.panelStrong.opacity(0.90))
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.68), lineWidth: 1)
        )
        .shadow(color: AppColors.subtext.opacity(0.07), radius: 18, x: 0, y: 8)
    }

    private var inlineBody: some View {
        HStack(spacing: 10) {
            paperGlyph
                .scaleEffect(0.61)
                .frame(width: 54, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(message)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.text.opacity(0.86))
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.subtext.opacity(0.72))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            Capsule(style: .continuous)
                .fill(AppColors.panelStrong.opacity(0.82))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.62), lineWidth: 1)
        )
    }

    private var paperGlyph: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.92),
                            AppColors.paperWarm.opacity(0.72),
                            AppColors.paperMist.opacity(0.64)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppColors.paperBorder.opacity(0.46), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 6) {
                loadingLine(width: 46, delay: 0)
                loadingLine(width: 64, delay: 0.12)
                loadingLine(width: 36, delay: 0.24)
            }
            .padding(.leading, 14)

            Circle()
                .fill(AppColors.accent.opacity(0.82))
                .frame(width: 7, height: 7)
                .shadow(color: AppColors.accent.opacity(0.28), radius: 5)
                .offset(x: reduceMotion ? 62 : (isBreathing ? 65 : 9), y: -23)
        }
        .frame(width: 86, height: 62)
        .scaleEffect(reduceMotion ? 1 : (isBreathing ? 1 : 0.985))
    }

    private func loadingLine(width: CGFloat, delay: Double) -> some View {
        Capsule(style: .continuous)
            .fill(AppColors.accent.opacity(reduceMotion ? 0.28 : (isBreathing ? 0.42 - delay * 0.22 : 0.20 + delay * 0.16)))
            .frame(width: width, height: 4)
            .offset(x: reduceMotion ? 0 : (isBreathing ? 3 : 0))
    }

    private var accessibilityStatusValue: String {
        var values: [String] = []
        if let detail, !detail.isEmpty {
            values.append(detail)
        }
        if let progress {
            let percent = Int((min(max(progress, 0), 1) * 100).rounded())
            values.append("完成百分之\(percent)")
        }
        return values.joined(separator: "，")
    }
}

struct ComputationUpdatePill: View {
    let message: String

    var body: some View {
        ComputationLoadingView(
            message: message,
            presentation: .inline
        )
        .fixedSize(horizontal: false, vertical: true)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
