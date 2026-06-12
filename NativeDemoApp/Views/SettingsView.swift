import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @Binding var showMemberPricing: Bool
    var onShowMinimalOnboarding: () -> Void = {}
    @State private var showAccountSheet = false
    @State private var activeSettingsSheet: SettingsSheet?
    @State private var draftDisplayName = ""
    @State private var draftPetNickname = ""
    @State private var showDeleteCloudLedgerConfirm = false
    @State private var showDeleteAccountConfirm = false
    @State private var isAccountDangerExpanded = false
    @FocusState private var focusedField: SettingsField?
    private let termsURL = URL(string: "https://xuzhangapp.com/legal/terms.html")!
    private let privacyURL = URL(string: "https://xuzhangapp.com/legal/privacy.html")!

    private enum SettingsField {
        case displayName
        case petNickname
    }

    private enum SettingsSheet: String, Identifiable {
        case backup
        case appearance
        case companion
        case privacy

        var id: String { rawValue }

        var title: String {
            switch self {
            case .backup: return "备份与联网"
            case .appearance: return "外观"
            case .companion: return "陪伴与语气"
            case .privacy: return "数据与隐私"
            }
        }
    }

    private var hasMemberAccess: Bool {
        settingsViewModel.settings.hasMemberAccess
    }

    private var hasPaidMemberTier: Bool {
        switch settingsViewModel.memberTier.lowercased() {
        case "monthly", "yearly", "lifetime":
            return true
        default:
            return false
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                settingsIdentityCard
                settingsChapterPanel
                settingsFooterLinks
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
        .sheet(item: $activeSettingsSheet) { sheet in
            settingsSheet(sheet)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog("删除云端账本？", isPresented: $showDeleteCloudLedgerConfirm, titleVisibility: .visible) {
            Button("删除云端账本", role: .destructive) {
                Task { await settingsViewModel.deleteCloudLedger() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只删除服务器上的同步账本，本机记录仍保留。为避免重新上传，云端同步会同时关闭。")
        }
        .confirmationDialog("注销账号？", isPresented: $showDeleteAccountConfirm, titleVisibility: .visible) {
            Button("保留本机账本并注销", role: .destructive) {
                Task {
                    let didDelete = await settingsViewModel.deleteCloudAccount()
                    if didDelete {
                        showAccountSheet = false
                    }
                }
            }
            Button("清空本机账本并注销", role: .destructive) {
                Task {
                    let didDelete = await settingsViewModel.deleteCloudAccount()
                    if didDelete {
                        homeViewModel.clearLocalLedgerData()
                        showAccountSheet = false
                    }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这会退出登录，并清空服务器上的账号、云端账本和会员绑定状态。Apple 订阅不会自动取消，之后可用同一 Apple ID 登录后恢复购买。")
        }
    }

    // MARK: - Account Entry

    private var settingsIdentityCard: some View {
        Button {
            showAccountSheet = true
        } label: {
            HStack(spacing: 12) {
                narrativeSealAvatar
                VStack(alignment: .leading, spacing: 4) {
                    Text(settingsViewModel.displayName.isEmpty ? "叙账用户" : settingsViewModel.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.text)
                    Text("本地保存 · \(AppSettings.memberTierDisplayName(settingsViewModel.memberTier))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.subtext)
                    Text(settingsViewModel.hasCloudSession ? "云端备份已准备好，照常记就好。" : "想备份或续聊时，再点这里登录。")
                        .font(.system(size: 12))
                        .italic()
                        .foregroundStyle(AppColors.subtext.opacity(0.88))
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppColors.settingsIdentityPanel)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(settingsInkAccent.opacity(0.34))
                .frame(width: 3)
                .padding(.vertical, 18)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppColors.line.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: AppColors.subtext.opacity(0.08), radius: 18, y: 8)
    }

    private var narrativeSealAvatar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 1.0, green: 0.96, blue: 0.88).opacity(0.88))
                .frame(width: 44, height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(settingsInkAccent.opacity(0.32), lineWidth: 1)
                )
            Text("叙")
                .font(.system(size: 20, weight: .bold, design: .serif))
                .foregroundStyle(settingsInkAccent.opacity(0.82))
        }
    }

    private var settingsChapterPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("你的叙账")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppColors.subtext.opacity(0.82))
            VStack(spacing: 0) {
                settingsEntryRow(mark: "你", title: "账号与会员", summary: settingsViewModel.hasCloudSession ? "已登录" : "未登录 · 可选") {
                    showAccountSheet = true
                }
                settingsEntryRow(mark: "云", title: "备份与联网", summary: "云端备份、联网梳理") {
                    activeSettingsSheet = .backup
                }
                settingsEntryRow(mark: "伴", title: "陪伴与语气", summary: "宠物、天气互动") {
                    activeSettingsSheet = .companion
                }
                settingsEntryRow(mark: "色", title: "外观", summary: appearanceSummary) {
                    activeSettingsSheet = .appearance
                }
                settingsEntryRow(mark: "安", title: "数据与隐私", summary: "本地昵称、说明与协议") {
                    activeSettingsSheet = .privacy
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColors.settingsChapterPanel)
        )
    }

    private func settingsEntryRow(mark: String, title: String, summary: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(mark)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(settingsMarkColor(mark).opacity(0.82))
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(settingsMarkColor(mark).opacity(0.10))
                    )
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                Spacer()
                Text(summary)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext.opacity(0.82))
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppColors.subtext.opacity(0.45))
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 11)
        }
        .buttonStyle(.plain)
    }

    private var settingsFooterLinks: some View {
        HStack(spacing: 8) {
            Button("重新查看新手引导") { onShowMinimalOnboarding() }
            Text("·")
            Link("隐私政策", destination: privacyURL)
            Text("·")
            Link("用户协议", destination: termsURL)
        }
        .font(.system(size: 11))
        .foregroundStyle(AppColors.subtext.opacity(0.74))
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var appearanceSummary: String {
        switch settingsViewModel.appearance {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    private var settingsInkAccent: Color {
        Color(red: 0.66, green: 0.47, blue: 0.30)
    }

    private func settingsMarkColor(_ mark: String) -> Color {
        switch mark {
        case "云":
            return Color(red: 0.47, green: 0.56, blue: 0.68)
        case "伴":
            return AppColors.accent.opacity(0.88)
        case "色":
            return Color(red: 0.70, green: 0.55, blue: 0.36)
        case "安":
            return Color(red: 0.56, green: 0.53, blue: 0.62)
        default:
            return settingsInkAccent
        }
    }

    private func settingsSheet(_ sheet: SettingsSheet) -> some View {
        ZStack {
            AppColors.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(sheet.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.text)
                    settingsSheetContent(sheet)
                }
                .webCardPadding()
                .webCardBackground()
                .padding(16)
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private func settingsSheetContent(_ sheet: SettingsSheet) -> some View {
        switch sheet {
        case .backup:
            settingToggle("云端备份（可选）", isOn: Binding(
                get: { settingsViewModel.syncEnabled },
                set: { settingsViewModel.syncEnabled = $0 }
            ))
            settingHelper("开启后账单会同步到云端，换机时可恢复。")
            settingToggle("允许联网梳理复盘（可选）", isOn: Binding(
                get: { settingsViewModel.useRemoteAI },
                set: { settingsViewModel.useRemoteAI = $0 }
            ))
            settingHelper("关闭后仍可使用本地回望，不强制登录。")
        case .appearance:
            webAppearanceButton("跟随系统", isActive: settingsViewModel.appearance == .system) {
                settingsViewModel.appearance = .system
            }
            HStack(spacing: 4) {
                webAppearanceButton("浅色", isActive: settingsViewModel.appearance == .light) {
                    settingsViewModel.appearance = .light
                }
                webAppearanceButton("深色", isActive: settingsViewModel.appearance == .dark) {
                    settingsViewModel.appearance = .dark
                }
            }
        case .companion:
            settingToggle("开启宠物陪伴", isOn: Binding(
                get: { settingsViewModel.petCompanionEnabled },
                set: { settingsViewModel.petCompanionEnabled = $0 }
            ))
            settingField(label: "宠物昵称") {
                TextField("小叙", text: $draftPetNickname)
                    .focused($focusedField, equals: .petNickname)
                    .submitLabel(.done)
                    .onSubmit { commitPetNickname() }
            }
            settingHelper("昵称只保存在本地设置里，不要写手机号、证件号或链接。")
            if let msg = settingsViewModel.contentSafetyMessage {
                settingHelper(msg)
            }
            settingToggle("允许天气场景暖心互动", isOn: Binding(
                get: { settingsViewModel.weatherCompanionEnabled },
                set: { settingsViewModel.weatherCompanionEnabled = $0 }
            ))
            VStack(alignment: .leading, spacing: 6) {
                Text("复盘语气")
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
        case .privacy:
            sectionBody("默认本地存储，无需登录即可完整使用。开启云端备份后，仅同步必要账单数据与会员状态。")
            legalLinksRow
            Text("ICP备案号：待备案")
                .font(.system(size: 11))
                .foregroundStyle(AppColors.subtext.opacity(0.68))
        }
    }

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
                    VStack(alignment: .leading, spacing: 3) {
                        Text("你的叙账在这里")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppColors.text)
                        Text(settingsViewModel.hasCloudSession
                             ? "\(settingsViewModel.displayName)，账号、备份和会员状态都放在这里。"
                             : "不用登录也能完整记录；想换机备份时，再把它放进云端。")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.subtext)
                            .lineLimit(2)
                    }
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
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppColors.subtext.opacity(0.62))
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
            sectionBody("这些偏好只属于你的叙账空间。默认保存在手机里；登录并开启同步后，才会上传云端备份。")

            // Display name
            settingField(label: "显示名称") {
                TextField("输入昵称", text: $draftDisplayName)
                    .focused($focusedField, equals: .displayName)
                    .submitLabel(.done)
                    .onSubmit { commitDisplayName() }
            }
            settingHelper("头像使用内置叙账印章，不上传头像图片；昵称不要写手机号、证件号或链接。")
            if let msg = settingsViewModel.contentSafetyMessage {
                settingHelper(msg)
            }

            // Cloud sync
            settingToggle("云端备份（可选）", isOn: Binding(
                get: { settingsViewModel.syncEnabled },
                set: { settingsViewModel.syncEnabled = $0 }
            ))
            settingHelper("开启后账单会同步到云端，换机时可恢复。")

            // AI toggle
            settingToggle("允许联网梳理复盘（可选）", isOn: Binding(
                get: { settingsViewModel.useRemoteAI },
                set: { settingsViewModel.useRemoteAI = $0 }
            ))
            settingHelper("关闭后仍可使用本地回望，不强制登录。")

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
            settingHelper("不要把手机号、证件号或链接写进昵称。")
            if let msg = settingsViewModel.contentSafetyMessage {
                settingHelper(msg)
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
        if settingsViewModel.updateDisplayName(next) {
            draftDisplayName = settingsViewModel.displayName
        } else {
            draftDisplayName = settingsViewModel.displayName
        }
    }

    private func commitPetNickname() {
        let trimmed = draftPetNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if settingsViewModel.updatePetNickname(trimmed) {
            draftPetNickname = settingsViewModel.petNickname
        } else {
            draftPetNickname = settingsViewModel.petNickname
        }
    }

    // MARK: - Appearance

    private var appearancePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("外观")
                .font(.system(size: 18, weight: .semibold))
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
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.text)

                    if !settingsViewModel.hasCloudSession {
                        sectionBody("登录后可同步会员状态，默认本地功能仍可直接使用。")
                            .lineLimit(1)
                    }

                    accountSheetContent

                    if settingsViewModel.hasCloudSession, let msg = settingsViewModel.authMessage {
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
        .onAppear {
            isAccountDangerExpanded = false
        }
    }

    @ViewBuilder
    private var accountSheetContent: some View {
        if settingsViewModel.hasCloudSession {
            accountIdentityHeader
            accountIdentitySection
            accountMemberSection
            accountSessionSection
            accountDangerZone
        } else {
            accountLoginSection
        }
    }

    private var accountLoginSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            accountLoginHeader

            VStack(alignment: .leading, spacing: 12) {
                settingField(label: "手机号") {
                    TextField("手机号", text: $settingsViewModel.loginPhone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                }

                settingField(label: "验证码") {
                    HStack(spacing: 10) {
                        TextField("验证码", text: $settingsViewModel.loginCode)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)

                        Button(loginSendCodeTitle) {
                            Task { await settingsViewModel.sendSMSLoginCode() }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(loginSendCodeDisabled ? AppColors.subtext.opacity(0.58) : AppColors.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule(style: .continuous)
                                .fill(loginSendCodeDisabled ? Color.white.opacity(0.36) : AppColors.accent.opacity(0.12))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(loginSendCodeDisabled ? AppColors.line.opacity(0.38) : AppColors.accent.opacity(0.22), lineWidth: 1)
                        )
                        .buttonStyle(.plain)
                        .disabled(loginSendCodeDisabled)
                    }
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
                        colors: loginButtonDisabled
                            ? [AppColors.subtext.opacity(0.28), AppColors.subtext.opacity(0.22)]
                            : [AppColors.accent.opacity(0.92), AppColors.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .shadow(color: loginButtonDisabled ? .clear : AppColors.accent.opacity(0.25), radius: 8, y: 4)
                .disabled(loginButtonDisabled)

                if let msg = settingsViewModel.authMessage {
                    Text(msg)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.subtext.opacity(0.92))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                legalInlineText(prefix: "登录即表示你已阅读并同意")

                Button("稍后再说，先不登录") {
                    showAccountSheet = false
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.subtext.opacity(0.86))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.56))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppColors.line.opacity(0.56), lineWidth: 1)
            )
        }
    }

    private var accountLoginHeader: some View {
        HStack(spacing: 12) {
            narrativeSealAvatar
            VStack(alignment: .leading, spacing: 5) {
                Text("欢迎回来，继续把记录留清楚")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
                Text("登录后可同步会员与云端备份")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext.opacity(0.88))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppColors.settingsIdentityPanel)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(settingsInkAccent.opacity(0.34))
                .frame(width: 3)
                .padding(.vertical, 18)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppColors.line.opacity(0.72), lineWidth: 1)
        )
    }

    private var loginSendCodeTitle: String {
        let remaining = settingsViewModel.smsCooldownRemaining
        return remaining > 0 ? "\(remaining)s 后重发" : "发送验证码"
    }

    private var loginPhoneIsValid: Bool {
        let phone = settingsViewModel.loginPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        return phone.count == 11 && phone.hasPrefix("1")
    }

    private var loginSendCodeDisabled: Bool {
        settingsViewModel.isAuthBusy || settingsViewModel.smsCooldownRemaining > 0 || !loginPhoneIsValid
    }

    private var loginButtonDisabled: Bool {
        settingsViewModel.isAuthBusy
    }

    private var accountIdentityHeader: some View {
        HStack(spacing: 12) {
            narrativeSealAvatar
            VStack(alignment: .leading, spacing: 5) {
                Text(settingsViewModel.displayName.isEmpty ? "叙账用户" : settingsViewModel.displayName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("\(AppSettings.memberTierDisplayName(settingsViewModel.memberTier)) · 已登录")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.subtext)
                        .lineLimit(1)
                    if hasMemberAccess {
                        accountMemberBadge
                    }
                }

                Text("云端备份已准备好，照常记就好。")
                    .font(.system(size: 12))
                    .italic()
                    .foregroundStyle(AppColors.subtext.opacity(0.88))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppColors.settingsIdentityPanel)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(settingsInkAccent.opacity(0.34))
                .frame(width: 3)
                .padding(.vertical, 18)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppColors.line.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: AppColors.subtext.opacity(0.07), radius: 14, y: 7)
    }

    private var accountMemberBadge: some View {
        Text("已解锁")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(settingsInkAccent.opacity(0.86))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(settingsInkAccent.opacity(0.11))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(settingsInkAccent.opacity(0.18), lineWidth: 1)
            )
    }

    private var accountIdentitySection: some View {
        accountPanel("身份") {
            settingField(label: "昵称") {
                TextField("叙账用户", text: $draftDisplayName)
                    .focused($focusedField, equals: .displayName)
                    .submitLabel(.done)
                    .onSubmit { commitDisplayName() }
            }
            settingHelper("不要写手机号、证件号或链接。")
            if let msg = settingsViewModel.contentSafetyMessage {
                settingHelper(msg)
            }
        }
    }

    private var accountMemberSection: some View {
        accountPanel("会员") {
            if let validity = settingsViewModel.settings.memberValidityText {
                accountInfoRow(title: "有效期", value: validity)
            }

            if hasMemberAccess {
                LazyVGrid(columns: accountMemberBenefitColumns, alignment: .leading, spacing: 8) {
                    ForEach(accountMemberBenefits, id: \.self) { benefit in
                        memberBenefitRow(benefit)
                    }
                }
            } else {
                accountInfoRow(title: "当前档位", value: AppSettings.memberTierDisplayName(settingsViewModel.memberTier))
                if !hasPaidMemberTier {
                    Button {
                        showAccountSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            showMemberPricing = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text("想多留几段回望？了解会员")
                                .font(.system(size: 14, weight: .medium))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(AppColors.accent.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var accountSessionSection: some View {
        accountPanel("账号") {
            Button {
                settingsViewModel.logoutCloud()
            } label: {
                Text("退出登录")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.text.opacity(0.82))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(webButtonBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppColors.line.opacity(0.6), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var accountDangerZone: some View {
        accountPanel("危险操作") {
            DisclosureGroup(isExpanded: $isAccountDangerExpanded) {
                VStack(spacing: 8) {
                    Button("删除云端账本", role: .destructive) {
                        showDeleteCloudLedgerConfirm = true
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.subtext.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppColors.line.opacity(0.7), lineWidth: 1)
                    )

                    Button("注销账号并删除云端数据", role: .destructive) {
                        showDeleteAccountConfirm = true
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(.red.opacity(0.82))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .padding(.top, 8)
            } label: {
                Text("删除与注销")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.text.opacity(0.82))
            }
            .tint(AppColors.subtext.opacity(0.82))
        }
    }

    private func accountPanel<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppColors.subtext.opacity(0.82))
            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.56))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppColors.line.opacity(0.56), lineWidth: 1)
        )
    }

    private func accountInfoRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(AppColors.subtext)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.text.opacity(0.88))
                .multilineTextAlignment(.trailing)
        }
    }

    private func memberBenefitRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.accent.opacity(0.84))
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.text.opacity(0.86))
            Spacer(minLength: 0)
        }
    }

    private var accountMemberBenefitColumns: [GridItem] {
        [
            GridItem(.flexible(), alignment: .leading),
            GridItem(.flexible(), alignment: .leading),
        ]
    }

    private var accountMemberBenefits: [String] {
        [
            "周/月回放无限",
            "今日回放不限",
            "OCR 识票不限",
            "场景备注包",
            "换一句/换角度",
            "宠物专属昵称",
            "云端备份同步",
            "纯净无广告",
        ]
    }

    // MARK: - AI Settings

    private var aiSettingsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("复盘语气")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppColors.text)

            // Tone
            VStack(alignment: .leading, spacing: 6) {
                Text("语气偏好")
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
            .environmentObject(HomeViewModel())
    }
}
