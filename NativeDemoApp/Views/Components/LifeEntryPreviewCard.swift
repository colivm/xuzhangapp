import SwiftUI

struct LifeEntryPreviewCard: View {
    enum QuickActionProminence {
        case link
        case balanced
        case primary
    }

    let headline: String
    let emotion: String
    let meta: String
    let amountText: String
    let quickActionTitle: String
    let quickActionProminence: QuickActionProminence
    var onTap: () -> Void
    var onChangeCategory: () -> Void
    var onQuickAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 9) {
                    Text(headline)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.text)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(emotion)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.accent.opacity(0.78))
                        .lineLimit(1)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(AppColors.accent.opacity(0.08))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(AppColors.accent.opacity(0.18), lineWidth: 0.7)
                        )
                }

                Spacer(minLength: 8)

                Text(amountText)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.text.opacity(0.66))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            HStack(spacing: 8) {
                Text(meta)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext.opacity(0.86))
                    .lineLimit(1)

                Spacer(minLength: 8)

                Button("改分类", action: onChangeCategory)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.accent.opacity(0.86))
                    .buttonStyle(.plain)
            }

            quickActionButton
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.34), AppColors.accent.opacity(0.07)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .allowsHitTesting(false)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.58), lineWidth: 1)
                .allowsHitTesting(false)
        )
        .shadow(color: AppColors.subtext.opacity(0.10), radius: 14, x: 0, y: 7)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture(perform: onTap)
    }

    @ViewBuilder
    private var quickActionButton: some View {
        switch quickActionProminence {
        case .link:
            Button(quickActionTitle, action: onQuickAction)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.accent.opacity(0.82))
                .buttonStyle(.plain)
        case .balanced:
            Button(action: onQuickAction) {
                Text(quickActionTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.accent.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(AppColors.accent.opacity(0.10))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(AppColors.accent.opacity(0.22), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        case .primary:
            Button(action: onQuickAction) {
                Text(quickActionTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        Capsule(style: .continuous)
                            .fill(AppColors.accent.opacity(0.9))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.38), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}
