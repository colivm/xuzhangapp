import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @Binding var showMemberPricing: Bool
    @State private var showPetCompanion = true
    @State private var showWeatherCompanion = true

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(spacing: 14) {
                // ── Account Entry Panel ──
                accountEntryPanel(proxy: proxy)

                // ── Main Settings Panel ──
                mainSettingsPanel

                // ── Appearance Panel ──
                appearancePanel

                // ── Cloud Account Panel (iOS native auth) ──
                cloudAccountPanel.id("cloudAccount")

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
        }
    }

    // MARK: - Account Entry

    private func accountEntryPanel(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation { proxy.scrollTo("cloudAccount", anchor: UnitPoint.top) }
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
                         ? "你好，\(settingsViewModel.cloudUserId.prefix(8))"
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

            sectionBody("数据仅保存在你的手机，不上传云端。")

            // Display name
            settingField(label: "显示名称") {
                TextField("输入昵称", text: Binding(
                    get: { settingsViewModel.displayName },
                    set: { settingsViewModel.displayName = $0 }
                ))
            }

            // iCloud sync
            settingToggle("iCloud 备份（可选）", isOn: Binding(
                get: { settingsViewModel.syncEnabled },
                set: { settingsViewModel.syncEnabled = $0 }
            ))
            settingHelper("开启后数据会同步到 iCloud，换机更方便。")

            // AI toggle
            settingToggle("开启 AI 智能建议（需联网）", isOn: Binding(
                get: { settingsViewModel.useRemoteAI },
                set: { settingsViewModel.useRemoteAI = $0 }
            ))
            settingHelper("默认本地存储，不强制登录。")

            // Pet companion
            settingToggle("开启宠物陪伴", isOn: $showPetCompanion)
            settingHelper("关闭后首页不显示宠物助手。")

            // Weather companion
            settingToggle("允许天气场景暖心互动 🌤️", isOn: $showWeatherCompanion)
            settingHelper("开启这个，我就能知道今天是晴是雨，陪你说更懂你的悄悄话啦！")

            // Reset guide
            webButton("重新查看新手引导") { /* trigger guide overlay */ }
        }
        .webCardPadding()
        .webCardBackground()
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

    // MARK: - Cloud Account (from original iOS)

    private var cloudAccountPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("云端账号（手机号）")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppColors.text)

            settingField(label: "后端根地址") {
                TextField("http://127.0.0.1:8790", text: Binding(
                    get: { settingsViewModel.backendBaseURL },
                    set: { settingsViewModel.backendBaseURL = $0 }
                ))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }
            settingHelper("模拟器连本机：http://127.0.0.1:8790。真机请填电脑局域网 IP。")

            if settingsViewModel.hasCloudSession {
                HStack {
                    Text("用户 ID")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.subtext)
                    Spacer()
                    Text(settingsViewModel.cloudUserId.isEmpty ? "—" : settingsViewModel.cloudUserId)
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.text)
                }
                .padding(.vertical, 4)

                HStack {
                    Text("会员档位")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.subtext)
                    Spacer()
                    Text(settingsViewModel.memberTier)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColors.text)
                }

                Button {
                    showMemberPricing = true
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

                webButton("刷新会员状态") {
                    Task { await settingsViewModel.refreshMemberFromServer() }
                }

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
            }

            if let msg = settingsViewModel.authMessage {
                Text(msg)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext)
            }
        }
        .webCardPadding()
        .webCardBackground()
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

            // AI Endpoint
            settingField(label: "AI 接口地址（POST）") {
                TextField("留空默认智谱", text: Binding(
                    get: { settingsViewModel.aiEndpoint },
                    set: { settingsViewModel.aiEndpoint = $0 }
                ))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }
            settingHelper("留空默认使用智谱官方地址。")

            // API Key
            settingField(label: "AI API Key（可选）") {
                SecureField("API Key 或代理口令", text: Binding(
                    get: { settingsViewModel.aiAPIKey },
                    set: { settingsViewModel.aiAPIKey = $0 }
                ))
            }
            settingHelper("直连智谱时填 API Key；走代理时可填代理口令。")

            // Model
            settingField(label: "模型") {
                TextField("doubao-seed-1-6-flash-250828", text: Binding(
                    get: { settingsViewModel.aiModel },
                    set: { settingsViewModel.aiModel = $0 }
                ))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
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
            Text("默认本地存储，无需登录即可完整使用。如果开启同步，后续版本会使用加密远程同步。")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext)
        }
        .webCardPadding()
        .webCardBackground()
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
        Button(action: action) {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.text.opacity(0.82))
                .frame(maxWidth: .infinity)
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
        .buttonStyle(.plain)
    }

    private func webAppearanceButton(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: isActive ? .semibold : .regular))
                Spacer()
                if isActive {
                    Text("✓")
                        .font(.system(size: 11))
                }
            }
            .foregroundStyle(
                isActive ? AppColors.accent.opacity(0.84) : AppColors.text.opacity(0.82)
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                isActive ? AppColors.accent.opacity(0.18) : Color.white.opacity(0.72),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isActive ? AppColors.accent.opacity(0.45) : Color.white.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: isActive ? AppColors.accent.opacity(0.18) : .clear, radius: 6, y: 3)
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
}

// MARK: - Web Card Styling Helpers

private extension View {
    func webCardBackground() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.thinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.22), Color.white.opacity(0.04)],
                            startPoint: UnitPoint(x: 0.3, y: 0),
                            endPoint: UnitPoint(x: 0.7, y: 1)
                        )
                    )
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppColors.line.opacity(0.73), lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 4)
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
