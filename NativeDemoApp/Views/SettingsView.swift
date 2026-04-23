import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("用户") {
                    TextField("显示名称", text: Binding(
                        get: { settingsViewModel.displayName },
                        set: { settingsViewModel.displayName = $0 }
                    ))
                }

                Section("偏好") {
                    Toggle("启用通知（演示）", isOn: Binding(
                        get: { settingsViewModel.notificationsEnabled },
                        set: { settingsViewModel.notificationsEnabled = $0 }
                    ))

                    Toggle("Face ID / 指纹锁定（占位）", isOn: Binding(
                        get: { settingsViewModel.biometricLockEnabled },
                        set: { settingsViewModel.biometricLockEnabled = $0 }
                    ))

                    Toggle("开启可选同步（占位）", isOn: Binding(
                        get: { settingsViewModel.syncEnabled },
                        set: { settingsViewModel.syncEnabled = $0 }
                    ))
                }

                Section("外观") {
                    Picker("主题模式", selection: Binding(
                        get: { settingsViewModel.appearance },
                        set: { settingsViewModel.appearance = $0 }
                    )) {
                        ForEach(AppSettings.Appearance.allCases) { appearance in
                            Text(appearance.title)
                                .tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("已适配深色模式，支持跟随系统/浅色/深色。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("AI") {
                    Picker("建议语气", selection: Binding(
                        get: { settingsViewModel.aiTone },
                        set: { settingsViewModel.aiTone = $0 }
                    )) {
                        ForEach(AppSettings.AITone.allCases) { tone in
                            Text(tone.title).tag(tone)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("启用远程 AI（可选）", isOn: Binding(
                        get: { settingsViewModel.useRemoteAI },
                        set: { settingsViewModel.useRemoteAI = $0 }
                    ))

                    TextField("AI 接口地址（POST）", text: Binding(
                        get: { settingsViewModel.aiEndpoint },
                        set: { settingsViewModel.aiEndpoint = $0 }
                    ))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                    Text("留空默认使用智谱官方地址。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    SecureField("AI API Key（可选）", text: Binding(
                        get: { settingsViewModel.aiAPIKey },
                        set: { settingsViewModel.aiAPIKey = $0 }
                    ))
                    Text("直连智谱时填 API Key；走代理时可填代理口令。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    TextField("模型（默认 glm-4-flash）", text: Binding(
                        get: { settingsViewModel.aiModel },
                        set: { settingsViewModel.aiModel = $0 }
                    ))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                    Stepper(
                        "月度远程 AI 调用上限：\(settingsViewModel.remoteAIMonthlyLimit)",
                        value: Binding(
                            get: { settingsViewModel.remoteAIMonthlyLimit },
                            set: { settingsViewModel.remoteAIMonthlyLimit = $0 }
                        ),
                        in: 0...1000
                    )

                    Text("本月已用：\(AIUsageLimiter.usageText(limitPerMonth: settingsViewModel.remoteAIMonthlyLimit))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("数据与隐私") {
                    Text("默认本地存储，无需登录即可完整使用。")
                    Text("如果开启同步，后续版本会使用加密远程同步。")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            }
            .navigationTitle("设置")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsViewModel())
}
