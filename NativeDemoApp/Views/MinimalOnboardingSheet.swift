import SwiftUI

enum MinimalOnboardingStore {
    private static let key = "minimal_onboarding_completed_v1"

    static var hasCompleted: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: key)
    }
}

struct MinimalOnboardingSheet: View {
    var onStartFirstRecord: () -> Void
    var onSkip: () -> Void

    var body: some View {
        ZStack {
            AppColors.bg.ignoresSafeArea()
            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("记一笔，今天就开始有轮廓")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AppColors.text)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("只输金额也可以。记好后，晚上用十几秒叙完这一天。")
                        .font(.system(size: 15))
                        .foregroundStyle(AppColors.text.opacity(0.78))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 10) {
                    Button {
                        MinimalOnboardingStore.markCompleted()
                        onStartFirstRecord()
                    } label: {
                        Text("记第一笔")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [AppColors.accent.opacity(0.92), AppColors.accent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.38), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        MinimalOnboardingStore.markCompleted()
                        onSkip()
                    } label: {
                        Text("跳过")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColors.subtext)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .glassPanel(radius: 26, padding: 24)
            .padding(.horizontal, 18)
        }
    }
}
