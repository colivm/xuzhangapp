import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @Binding var showMemberPricing: Bool
    var onShowMinimalOnboarding: () -> Void = {}
    @State private var showAccountSheet = false
    @State private var draftDisplayName = ""
    @State private var draftPetNickname = ""
    @FocusState private var focusedField: SettingsField?
    private let termsURL = URL(string: "https://xuzhangapp.com/legal/terms.html")!
    private let privacyURL = URL(string: "https://xuzhangapp.com/legal/privacy.html")!

    private enum SettingsField {
        case displayName
        case petNickname
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // ── Account Entry Panel ──
                accountEntryPanel

                // ── Main Settings Panel ──
                mainSettingsPanel

                // ── Appearance Panel ──
                appearancePanel

                // ── AI Settings Panel ──
                aiSettingsPanel

                // ── Data & Privacy ──
                privacyNote
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 120)
            .frame(maxWidth: 430)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            draftDisplayName = settingsViewModel.displayName
            draftPetNickname = settingsViewModel.petNickname
        }
        .onChange(of: focusedField) { oldValue, newValue in
            if oldValue == .displayName, newValue != .displayName {
                commitDisplayName()
            }
            if oldValue == .petNickname, newValue != .petNickname {
                commitPetNickname()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    focusedField = nil
                }
            }
        }
        .sheet(isPresented: $showAccountSheet) {
            accountSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Account Entry

    private var accountEntryPanel: some View {
        VStack(spacing: 0) {
            Button {
                showAccountSheet = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppColors.accent.opacity(0.2))
                            .frame(width: 46, height: 46)
                        Text("👤")
                            .font(.system(size: 22))
                    }
                    Text(settingsViewModel.hasCloudSession
                         ? "\(settingsViewModel.displayName) > 管理账号与会员。"
                         : "点击登录，解锁云备份与会员权益 >")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.text.opacity(0.9))
                    Spacer()
                    if settingsViewModel.hasCloudSession {
                        Text(settingsViewModel.memberTier.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(AppColors.accent)
                            )
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .webCardBackground()
    }

    // MARK: - Main Settings

    private var mainSettingsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("设置")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppColors.text)

            sectionBody("默认仅保存在你的手机；登录并开启同步后，才会上传云端备份。")

            // Display name
            settingField(label: "显示名称") {
                TextField("输入昵称", text: $draftDisplayName)
                    .focused($focusedField, equals: .displayName)
                    .submitLabel(.done)
                    .onSubmit { commitDisplayName() }
            }

            // Cloud sync
            settingToggle("云端备份（可选）", isOn: Binding(
                get: { settingsViewModel.syncEnabled },
                set: { settingsViewModel.syncEnabled = $0 }
            ))
            settingHelper("开启后账单会同步到云端，换机时可恢复。")

            // AI toggle
            settingToggle("开启 AI 智能建议（需联网）", isOn: Binding(
                get: { settingsViewModel.useRemoteAI },
                set: { settingsViewModel.useRemoteAI = $0 }
            ))
            settingHelper("默认本地存储，不强制登录。")

            // Pet companion
            settingToggle("开启宠物陪伴", isOn: Binding(
                get: { settingsViewModel.petCompanionEnabled },
                set: { settingsViewModel.petCompanionEnabled = $0 }
            ))
            settingHelper("关闭后首页不显示宠物助手。")
            settingField(label: "宠物昵称") {
                TextField("小窝", text: $draftPetNickname)
                    .focused($focusedField, equals: .petNickname)
                    .submitLabel(.done)
                    .onSubmit { commitPetNickname() }
            }

            // Weather companion
            settingToggle("允许天气场景暖心互动 🌤️", isOn: Binding(
                get: { settingsViewModel.weatherCompanionEnabled },
                set: { settingsViewModel.weatherCompanionEnabled = $0 }
            ))
            settingHelper("开启这个，我就能知道今天是晴是雨，陪你说更懂你的悄悄话啦！")

            // Reset guide
            webButton("重新查看新手引导") {
                onShowMinimalOnboarding()
            }
        }
        .webCardPadding()
        .webCardBackground()
    }

    private func commitDisplayName() {
        let trimmed = draftDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let next = trimmed.isEmpty ? "叙账用户" : trimmed
        draftDisplayName = next
        if settingsViewModel.displayName != next {
            settingsViewModel.displayName = next
        }
    }

    private func commitPetNickname() {
        let trimmed = draftPetNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        draftPetNickname = trimmed
        if settingsViewModel.petNickname != trimmed {
            settingsViewModel.petNickname = trimmed
        }
    }

    // MARK: - Appearance

    private var appearancePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("外观")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppColors.text)

            // System follow
            webAppearanceButton("跟随系统", isActive: settingsViewModel.appearance == .system) {
                settingsViewModel.appearance = .system
            }
            .padding(.bottom, 4)

            // Light / Dark
            HStack(spacing: 4) {
                webAppearanceButton("浅色", isActive: settingsViewModel.appearance == .light) {
                    settingsViewModel.appearance = .light
                }
                webAppearanceButton("深色", isActive: settingsViewModel.appearance == .dark) {
                    settingsViewModel.appearance = .dark
                }
            }
        }
        .webCardPadding()
        .webCardBackground()
    }

    // MARK: - Account Sheet

    private var accountSheet: some View {
        ZStack {
            AppColors.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("账号与会员")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AppColors.text)

                    sectionBody(settingsViewModel.hasCloudSession
                                ? "管理你的云端登录状态和会员权益。"
                                : "登录后可同步会员状态，默认本地功能仍可直接使用。")

                    accountSheetContent

                    if let msg = settingsViewModel.authMessage {
                        Text(msg)
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.subtext)
                    }
                }
                .webCardPadding()
                .webCardBackground()
                .padding(16)
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private var accountSheetContent: some View {
        if settingsViewModel.hasCloudSession {
            HStack {
                Text("账号状态")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.subtext)
                Spacer()
                Text("已登录")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.text)
            }
            .padding(.vertical, 4)

            HStack {
                Text("显示名称")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.subtext)
                Spacer()
                Text(settingsViewModel.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.text)
            }

            HStack {
                Text("会员档位")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.subtext)
                Spacer()
                Text(memberTierDisplayName(settingsViewModel.memberTier))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.text)
            }

            Button {
                showAccountSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    showMemberPricing = true
                }
            } label: {
                HStack {
                    Text("✨ 查看会员方案与权益")
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppColors.subtext)
                }
                .foregroundStyle(AppColors.text.opacity(0.88))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [AppColors.lockGold.opacity(0.12), Color.white.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColors.lockGold.opacity(0.25), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Button("退出登录", role: .destructive) {
                settingsViewModel.logoutCloud()
            }
            .font(.system(size: 14))
            .foregroundStyle(.red.opacity(0.8))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
            )
        } else {
            settingField(label: "手机号") {
                TextField("手机号", text: $settingsViewModel.loginPhone)
                    .keyboardType(.phonePad)
            }

            settingField(label: "验证码") {
                TextField("验证码", text: $settingsViewModel.loginCode)
                    .keyboardType(.numberPad)
            }

            webButton("发送验证码") {
                Task { await settingsViewModel.sendSMSLoginCode() }
            }

            Button("验证并登录") {
                Task { await settingsViewModel.verifySMSLogin() }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [AppColors.accent.opacity(0.92), AppColors.accent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .shadow(color: AppColors.accent.opacity(0.25), radius: 8, y: 4)

            legalInlineText(prefix: "登录即表示你已阅读并同意")
        }
    }

    // MARK: - AI Settings

    private var aiSettingsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI 设置")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppColors.text)

            // Tone
            VStack(alignment: .leading, spacing: 6) {
                Text("建议语气")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.text.opacity(0.82))
                HStack(spacing: 4) {
                    webToneButton("温和", isActive: settingsViewModel.aiTone == .gentle) {
                        settingsViewModel.aiTone = .gentle
                    }
                    webToneButton("中性", isActive: settingsViewModel.aiTone == .neutral) {
                        settingsViewModel.aiTone = .neutral
                    }
                }
            }

        }
        .webCardPadding()
        .webCardBackground()
    }

    // MARK: - Privacy Note

    private var privacyNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("数据与隐私")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppColors.text)
            Text("默认本地存储，无需登录即可完整使用。开启云端备份后，仅同步必要账单数据与会员状态。")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext)
            legalLinksRow
                .padding(.top, 4)
            Text("ICP备案号：待备案")
                .font(.system(size: 11))
                .foregroundStyle(AppColors.subtext.opacity(0.68))
                .padding(.top, 2)
        }
        .webCardPadding()
        .webCardBackground()
    }

    private var legalLinksRow: some View {
        HStack(spacing: 12) {
            Link("用户协议", destination: termsURL)
            Text("·")
                .foregroundStyle(AppColors.subtext.opacity(0.55))
            Link("隐私政策", destination: privacyURL)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(AppColors.accentDark.opacity(0.9))
    }

    private func legalInlineText(prefix: String) -> some View {
        HStack(spacing: 4) {
            Text(prefix)
                .foregroundStyle(AppColors.subtext.opacity(0.78))
            Link("用户协议", destination: termsURL)
                .foregroundStyle(AppColors.accentDark.opacity(0.9))
            Text("和")
                .foregroundStyle(AppColors.subtext.opacity(0.78))
            Link("隐私政策", destination: privacyURL)
                .foregroundStyle(AppColors.accentDark.opacity(0.9))
        }
        .font(.system(size: 11))
        .frame(maxWidth: .infinity, alignment: .center)
        .lineLimit(1)
        .minimumScaleFactor(0.82)
    }

    // MARK: - Shared Components

    private func sectionBody(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(AppColors.subtext.opacity(0.85))
            .padding(.bottom, 2)
    }

    private func settingField(label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColors.text.opacity(0.82))
            content()
                .font(.system(size: 16))
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.72))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )
        }
    }

    private func settingToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.text.opacity(0.88))
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(AppColors.accent)
        }
    }

    private func settingHelper(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(AppColors.subtext.opacity(0.74))
            .padding(.top, -8)
    }

    private func webButton(_ title: String, action: @escaping () -> Void) -> some View {
        return Button(action: action) {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.text.opacity(0.82))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(webButtonBackground)
                .overlay(webButtonBorder)
        }
        .buttonStyle(.plain)
    }

    private var webButtonBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.72))
    }

    private var webButtonBorder: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(Color.white.opacity(0.5), lineWidth: 1)
    }

    private func webAppearanceButton(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        let titleWeight: Font.Weight = isActive ? .semibold : .regular
        let foreground = isActive ? AppColors.accent.opacity(0.84) : AppColors.text.opacity(0.82)
        let fill = isActive ? AppColors.accent.opacity(0.18) : Color.white.opacity(0.72)
        let stroke = isActive ? AppColors.accent.opacity(0.45) : Color.white.opacity(0.5)
        let shadow = isActive ? AppColors.accent.opacity(0.18) : Color.clear

        return Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: titleWeight))
                Spacer()
                if isActive {
                    Text("✓")
                        .font(.system(size: 11))
                }
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
            .shadow(color: shadow, radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }

    private func webToneButton(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? .white : AppColors.text.opacity(0.82))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    isActive ? AppColors.accent : Color.white.opacity(0.72),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .shadow(color: isActive ? AppColors.accent.opacity(0.2) : .clear, radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func memberTierDisplayName(_ tier: String) -> String {
        switch tier.lowercased() {
        case "monthly": return "月度会员"
        case "yearly": return "年度会员"
        case "lifetime": return "永久会员"
        default: return "免费用户"
        }
    }
}

// MARK: - Web Card Styling Helpers

private extension View {
    func webCardBackground() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppColors.panel)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.16), Color.white.opacity(0.03)],
                            startPoint: UnitPoint(x: 0.3, y: 0),
                            endPoint: UnitPoint(x: 0.7, y: 1)
                        )
                    )
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppColors.line.opacity(0.88), lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .shadow(color: Color(red: 117/255, green: 131/255, blue: 156/255).opacity(0.11), radius: 22, x: 0, y: 8)
    }

    func webCardPadding() -> some View {
        self.padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(showMemberPricing: .constant(false))
            .environmentObject(SettingsViewModel())
    }
}
