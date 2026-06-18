import SwiftUI

struct LifeEntryPreviewCard: View {
    let tier: RecordPreviewTier
    let headline: String
    let hint: String?
    let learningHint: String?
    let emotion: String
    let meta: String
    let amountText: String
    let primaryActionTitle: String
    let showsPrimaryAction: Bool
    let showAngleAction: Bool
    var showsFreePrimaryAction: Bool = false
    var showFreeAngleAction: Bool = false
    var onTap: () -> Void
    var onChangeCategory: () -> Void
    var onPrimaryAction: () -> Void
    var onWriteOwn: () -> Void
    var onAngleAction: () -> Void
    var onFreePrimaryAction: (() -> Void)? = nil
    var onFreeAngleAction: (() -> Void)? = nil

    private var isWhisper: Bool { tier == .whisper }
    private var isConfirm: Bool { tier == .confirm }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            bodyContent

            Divider()
                .background(AppColors.line.opacity(0.38))
                .padding(.top, 12)

            footContent
                .padding(.top, 10)
        }
        .padding(.horizontal, 17)
        .padding(.top, isWhisper ? 15 : 17)
        .padding(.bottom, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(cardBorder)
        .shadow(color: isWhisper ? .clear : AppColors.subtext.opacity(0.08), radius: 14, x: 0, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture(perform: onTap)
    }

    private var bodyContent: some View {
        VStack(alignment: .leading, spacing: isWhisper ? 7 : 8) {
            Text(headline)
                .font(.system(size: isWhisper ? 15.5 : 21, weight: isWhisper ? .regular : .semibold))
                .foregroundStyle(isWhisper ? AppColors.text.opacity(0.76) : AppColors.text)
                .lineSpacing(isWhisper ? 2 : 1)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if let hint, !hint.isEmpty, isConfirm {
                Text(hint)
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.subtext.opacity(0.78))
            }

            if let learningHint, !learningHint.isEmpty {
                learningHintPill(learningHint)
            }

            emotionPill

            metaRow
        }
    }

    private func learningHintPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(AppColors.subtext.opacity(0.76))
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var footContent: some View {
        HStack(alignment: .center, spacing: 10) {
            actionRow

            Spacer(minLength: 10)

            Text(amountText)
                .font(.system(size: isWhisper ? 11 : 12, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.subtext.opacity(isWhisper ? 0.48 : 0.58))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    @ViewBuilder
    private var emotionPill: some View {
        if isConfirm && !emotion.isEmpty {
            Text(emotion)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.accent.opacity(0.62))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(emotionPillBackground)
                .overlay(emotionPillBorder)
        }
    }

    private var emotionPillBackground: some View {
        Capsule(style: .continuous)
            .fill(Color.white.opacity(0.34))
    }

    private var emotionPillBorder: some View {
        Capsule(style: .continuous)
            .stroke(AppColors.accent.opacity(0.16), lineWidth: 0.7)
    }

    private var metaRow: some View {
        HStack(spacing: 7) {
            Text(meta)
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext.opacity(0.82))
                .lineLimit(1)

            Spacer(minLength: 8)

            if isConfirm {
                Button("改分类", action: onChangeCategory)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.accent.opacity(0.72))
                    .buttonStyle(.plain)
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 0) {
            if showsPrimaryAction {
                quietAction(primaryActionTitle, action: onPrimaryAction)
                if showAngleAction && isConfirm {
                    separator
                    quietAction("换个角度", action: onAngleAction)
                }
                separator
            } else if showsFreePrimaryAction {
                quietAction(primaryActionTitle) {
                    onFreePrimaryAction?()
                }
                if showFreeAngleAction && isConfirm {
                    separator
                    quietAction("换个角度") {
                        onFreeAngleAction?()
                    }
                }
                separator
            }
            quietAction("自己写一句", action: onWriteOwn)
        }
    }

    private func quietAction(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(AppColors.accent.opacity(0.68))
            .buttonStyle(.plain)
    }

    private var separator: some View {
        Text("|")
            .font(.system(size: 12))
            .foregroundStyle(AppColors.subtext.opacity(0.42))
            .padding(.horizontal, 8)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.thinMaterial)
            .overlay(
                LinearGradient(
                    colors: isWhisper
                        ? [Color.white.opacity(0.34), Color.white.opacity(0.12)]
                        : [Color.white.opacity(0.42), AppColors.accent.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .leading) {
                if isWhisper {
                    Capsule(style: .continuous)
                        .fill(AppColors.accent.opacity(0.32))
                        .frame(width: 2)
                        .padding(.vertical, 16)
                }
            }
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(
                isWhisper ? AppColors.line.opacity(0.55) : AppColors.accent.opacity(0.18),
                lineWidth: 1
            )
            .allowsHitTesting(false)
    }
}
