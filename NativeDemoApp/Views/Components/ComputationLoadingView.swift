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
            withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
        .onChange(of: reduceMotion) { _, shouldReduce in
            if shouldReduce {
                isBreathing = false
            } else {
                withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
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
            quietIndicator

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
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.68), lineWidth: 1)
        )
        .shadow(color: AppColors.subtext.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private var inlineBody: some View {
        HStack(spacing: 10) {
            quietIndicator
                .scaleEffect(0.78)
                .frame(width: 28, height: 28)

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

    private var quietIndicator: some View {
        ZStack {
            Circle()
                .stroke(AppColors.accent.opacity(0.16), lineWidth: 3)
            Circle()
                .fill(AppColors.accent.opacity(reduceMotion ? 0.58 : (isBreathing ? 0.72 : 0.38)))
                .frame(width: 9, height: 9)
                .scaleEffect(reduceMotion ? 1 : (isBreathing ? 1.08 : 0.82))
        }
        .frame(width: 34, height: 34)
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
