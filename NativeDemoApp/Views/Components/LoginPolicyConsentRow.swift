import SwiftUI

struct LoginPolicyConsentRow: View {
    @Binding var isAccepted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                isAccepted.toggle()
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: isAccepted ? "checkmark.square.fill" : "square")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isAccepted ? AppColors.accent : AppColors.subtext.opacity(0.72))
                        .frame(width: 28, height: 28)

                    Text("我已阅读并同意以下条款")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.text.opacity(0.88))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("同意用户协议和隐私政策")
            .accessibilityValue(isAccepted ? "已勾选" : "未勾选")
            .accessibilityAddTraits(isAccepted ? .isSelected : [])

            HStack(spacing: 5) {
                Link("《用户协议》", destination: LoginLegalPolicy.termsURL)
                Text("和")
                    .foregroundStyle(AppColors.subtext.opacity(0.78))
                Link("《隐私政策》", destination: LoginLegalPolicy.privacyURL)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(AppColors.accentDark)
            .padding(.leading, 38)

            if !isAccepted {
                Text("勾选后才能发送验证码。")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.subtext.opacity(0.78))
                    .padding(.leading, 38)
            }
        }
    }
}
