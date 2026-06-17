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
    @State private var showClearAllRecordsConfirm = false
    @State private var showDeleteAccountConfirm = false
    @State private var showEnableCloudSyncConfirm = false
    @State private var showLoginCloudSyncMergeConfirm = false
    @State private var confirmationHost: SettingsConfirmationHost = .main
    @State private var isAccountDangerExpanded = false
    @State private var showNicknameEditor = false
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

    private enum SettingsConfirmationHost {
        case main
        case settingsSheet
        case accountSheet
    }

    private enum SettingsConfirmationKind: Hashable {
        case deleteCloudLedger
        case enableCloudSync
        case loginCloudSyncMerge
        case clearAllRecords
        case deleteAccount
    }

    private enum SettingsConfirmationActionStyle {
        case primary
        case secondary
        case destructive
    }

    private struct SettingsConfirmationAction: Identifiable {
        let id: String
        let title: String
        let style: SettingsConfirmationActionStyle
        let handler: () -> Void
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

    private var hasExpiredPaidMemberTier: Bool {
        hasPaidMemberTier && !hasMemberAccess
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                settingsIdentityCard
                settingsFeatureGrid
                settingsFooterLinks
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 120)
            .frame(maxWidth: 430)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            draftDisplayName = settingsViewModel.displayName
            draftPetNickname = settingsViewModel.petNickname
            Task {
                await settingsViewModel.refreshCloudAccountProfile()
                await settingsViewModel.refreshMemberFromLocalEntitlements()
                handleCloudSessionBecameActive()
                if settingsViewModel.syncEnabled {
                    await homeViewModel.syncCloudLedgerNow()
                }
            }
        }
        .onChange(of: settingsViewModel.hasCloudSession) { _, hasSession in
            guard hasSession else { return }
            Task {
                await settingsViewModel.refreshCloudAccountProfile()
                handleCloudSessionBecameActive()
                if settingsViewModel.syncEnabled {
                    await homeViewModel.syncCloudLedgerNow()
                }
            }
        }
        .onChange(of: settingsViewModel.displayName) { _, name in
            if focusedField != .displayName {
                draftDisplayName = name
            }
        }
        .onChange(of: focusedField) { oldValue, newValue in
            if oldValue == .displayName, newValue != .displayName {
                commitDisplayName()
                if settingsViewModel.hasCloudSession {
                    showNicknameEditor = false
                }
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
            settingsConfirmations(accountSheet, host: .accountSheet)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $activeSettingsSheet) { sheet in
            settingsConfirmations(settingsSheet(sheet), host: .settingsSheet)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .overlay {
            settingsConfirmationOverlay(host: .main)
        }
    }

    // MARK: - Account Entry

    private var settingsIdentityCard: some View {
        Button {
            showAccountSheet = true
        } label: {
            ZStack {
                settingsEnvelopeBackground

                HStack(spacing: 14) {
                    narrativeSealAvatar

                    VStack(alignment: .leading, spacing: 5) {
                        Text(settingsDisplayName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppColors.text)
                            .lineLimit(1)
                        Text(identityCardMeta)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(settingsInkAccent.opacity(0.92))
                            .lineLimit(1)
                        Text(settingsViewModel.hasCloudSession ? "云端备份已准备好，照常记就好。" : "不用登录也能记；换机备份时再放进云端。")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.text.opacity(0.82))
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 28)
                .padding(.top, 28)
                .padding(.bottom, 42)
            }
        }
        .buttonStyle(.plain)
        .frame(height: 150)
    }

    private var narrativeSealAvatar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(settingsEnvelopeIvory.opacity(0.92))
                .frame(width: 48, height: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(settingsInkAccent.opacity(0.28), lineWidth: 1)
                )
            Text("叙")
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundStyle(settingsInkAccent.opacity(0.82))
        }
    }

    private var settingsEnvelopeBackground: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let width = size.width
            let height = size.height
            let centerX = width * 0.5
            let flapDrop = height * 0.68
            let flapSideY = height * 0.39

            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(settingsEnvelopeIvory)

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.46),
                        settingsEnvelopeWarm.opacity(0.52),
                        settingsEnvelopeMint.opacity(0.42)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(settingsEnvelopeDeepSage.opacity(0.34))
                    .frame(width: width * 0.58, height: width * 0.58)
                    .blur(radius: 24)
                    .offset(x: width * 0.36, y: height * 0.28)
                    .allowsHitTesting(false)

                Path { path in
                    path.move(to: CGPoint(x: 0, y: flapSideY))
                    path.addLine(to: CGPoint(x: centerX, y: flapDrop))
                    path.addLine(to: CGPoint(x: width, y: flapSideY))
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.addLine(to: CGPoint(x: 0, y: height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [
                            settingsEnvelopeWarm.opacity(0.72),
                            Color.white.opacity(0.50),
                            settingsEnvelopeSage.opacity(0.42)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

                Path { path in
                    path.move(to: CGPoint(x: 0, y: height))
                    path.addLine(to: CGPoint(x: centerX, y: flapDrop))
                    path.addLine(to: CGPoint(x: width, y: height))
                }
                .stroke(Color.white.opacity(0.44), lineWidth: 1)

                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: width, y: 0))
                    path.addQuadCurve(
                        to: CGPoint(x: centerX, y: flapDrop * 0.86),
                        control: CGPoint(x: width * 0.94, y: height * 0.74)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 0, y: 0),
                        control: CGPoint(x: width * 0.06, y: height * 0.74)
                    )
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.68),
                            settingsEnvelopeIvory.opacity(0.80),
                            settingsEnvelopeMint.opacity(0.44)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.10), radius: 15, x: 0, y: 8)

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.white.opacity(0.66), lineWidth: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .shadow(color: settingsEnvelopeDeepSage.opacity(0.28), radius: 18, x: 0, y: 10)
        .shadow(color: Color.black.opacity(0.06), radius: 5, x: 0, y: 2)
    }

    private var settingsFeatureGrid: some View {
        LazyVGrid(columns: settingsFeatureColumns, spacing: 14) {
            settingsFeatureTile(
                title: "账号会员",
                subtitle: accountRowSummary,
                systemImage: "person.crop.circle.badge.checkmark",
                style: .light
            ) {
                showAccountSheet = true
            }

            settingsFeatureTile(
                title: "云端备份",
                subtitle: backupRowSummary,
                systemImage: settingsViewModel.syncEnabled ? "checkmark.shield" : "icloud",
                style: settingsViewModel.syncEnabled ? .solid : .mint
            ) {
                activeSettingsSheet = .backup
            }

            settingsFeatureTile(
                title: "陪伴语气",
                subtitle: companionRowSummary,
                systemImage: "gearshape",
                style: .mint
            ) {
                activeSettingsSheet = .companion
            }

            settingsFeatureTile(
                title: "外观设置",
                subtitle: appearanceSummary,
                systemImage: "sparkles",
                style: .cream
            ) {
                activeSettingsSheet = .appearance
            }
        }
    }

    private var settingsFeatureColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14)
        ]
    }

    private enum SettingsTileStyle {
        case solid
        case light
        case cream
        case mint
    }

    private func settingsFeatureTile(
        title: String,
        subtitle: String,
        systemImage: String,
        style: SettingsTileStyle,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 38, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(settingsTileIconColor(style))
                    .frame(height: 46)

                VStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(settingsTileTextColor(style))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(settingsTileSubtextColor(style))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.84)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .padding(18)
            .background(settingsTileBackground(style))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(style == .solid ? 0.22 : 0.58), lineWidth: 1)
            )
            .shadow(color: settingsTileShadowColor(style), radius: 18, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }

    private var settingsFooterLinks: some View {
        HStack(spacing: 7) {
            Button("新手引导") { onShowMinimalOnboarding() }
            Text("·")
            Button("数据隐私") { activeSettingsSheet = .privacy }
            Text("·")
            Link("用户协议", destination: termsURL)
            Text("·")
            Link("隐私政策", destination: privacyURL)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(AppColors.subtext.opacity(0.72))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.horizontal, 10)
        .padding(.top, 72)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var appearanceSummary: String {
        switch settingsViewModel.appearance {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    private var settingsDisplayName: String {
        settingsViewModel.displayName.isEmpty ? "叙账用户" : settingsViewModel.displayName
    }

    private var memberTierName: String {
        AppSettings.memberTierDisplayName(settingsViewModel.memberTier)
    }

    private var identityCardMeta: String {
        let sync = settingsViewModel.syncEnabled ? "已同步云端" : "本地保存"
        let expiry = hasExpiredPaidMemberTier ? " · 会员待续期" : ""
        return "\(sync) · \(memberTierName)\(expiry)"
    }

    private var accountRowSummary: String {
        guard settingsViewModel.hasCloudSession else { return "未登录 · 可选" }
        if hasMemberAccess { return "已登录 · \(memberTierName)" }
        if hasPaidMemberTier { return "已登录 · 待续期" }
        return "已登录 · 免费版"
    }

    private var backupRowSummary: String {
        switch (settingsViewModel.syncEnabled, settingsViewModel.useRemoteAI) {
        case (true, true): return "云端开 · AI 开"
        case (true, false): return "云端备份已开"
        case (false, true): return "联网梳理已开"
        case (false, false): return "仅本地保存"
        }
    }

    private var cloudSyncHelperText: String {
        if homeViewModel.isSyncingCloudLedger {
            return "正在合并云端账本。"
        }
        if let message = homeViewModel.syncStatusMessage, !message.isEmpty {
            return message
        }
        if settingsViewModel.syncEnabled {
            return "已开启；新增、编辑、删除会自动同步。"
        }
        return "首次开启会先合并云端与本机；冲突保留更新时间较新的记录。"
    }

    private var companionRowSummary: String {
        guard settingsViewModel.petCompanionEnabled else { return "宠物已关" }
        if settingsViewModel.weatherCompanionEnabled { return "宠物开 · 天气互动" }
        return "宠物开 · \(aiToneSummary)"
    }

    private var aiToneSummary: String {
        switch settingsViewModel.aiTone {
        case .gentle: return "温和"
        case .neutral: return "中性"
        }
    }

    private func requestCloudSyncChange(_ enabled: Bool) {
        if !enabled {
            settingsViewModel.syncEnabled = false
            return
        }
        guard settingsViewModel.hasCloudSession else {
            showAccountSheet = true
            return
        }
        if settingsViewModel.syncEnabled {
            return
        }
        if showAccountSheet {
            confirmationHost = .accountSheet
        } else if activeSettingsSheet != nil {
            confirmationHost = .settingsSheet
        } else {
            confirmationHost = .main
        }
        showEnableCloudSyncConfirm = true
    }

    private func enableCloudSyncAndMerge() {
        settingsViewModel.enableCloudSyncForCurrentAccount()
        Task {
            await homeViewModel.syncCloudLedgerNow()
        }
    }

    private func handleCloudSessionBecameActive() {
        guard settingsViewModel.hasPendingLoginCloudSyncDecision else { return }
        if homeViewModel.items.isEmpty {
            settingsViewModel.enableCloudSyncForCurrentAccount()
            return
        }
        confirmationHost = showAccountSheet ? .accountSheet : .main
        showLoginCloudSyncMergeConfirm = true
    }

    private func mergeLocalLedgerIntoCurrentAccount() {
        showLoginCloudSyncMergeConfirm = false
        settingsViewModel.enableCloudSyncForCurrentAccount()
        Task {
            await homeViewModel.syncCloudLedgerNow()
        }
    }

    private func keepLocalLedgerOnlyForCurrentLogin() {
        showLoginCloudSyncMergeConfirm = false
        settingsViewModel.keepCloudSyncOffForCurrentLogin()
    }

    private func replaceLocalLedgerWithCurrentAccountCloud() {
        showLoginCloudSyncMergeConfirm = false
        homeViewModel.clearLocalLedgerData()
        settingsViewModel.enableCloudSyncForCurrentAccount()
        Task {
            await homeViewModel.syncCloudLedgerNow()
        }
    }

    private var clearAllRecordsHelperText: String {
        let count = homeViewModel.items.count
        if settingsViewModel.syncEnabled && settingsViewModel.hasCloudSession {
            return count > 0 ? "当前 \(count) 笔；会同时清空本机和云端账本。" : "当前没有本机记录；云端账本也会一并清空。"
        }
        return count > 0 ? "当前 \(count) 笔；只清空这台设备上的本机账本。" : "当前没有本机记录。"
    }

    private var clearAllRecordsConfirmMessage: String {
        if settingsViewModel.syncEnabled && settingsViewModel.hasCloudSession {
            return "这会删除本机记录，并清空服务器上的同步账本；云端备份会同时关闭。这个操作不能撤销。"
        }
        return "这会删除这台设备上的全部本机记录、今日回放和本地复盘缓存。这个操作不能撤销。"
    }

    private func clearAllRecords() {
        if settingsViewModel.syncEnabled && settingsViewModel.hasCloudSession {
            Task {
                let didClearCloud = await settingsViewModel.deleteCloudLedger()
                if didClearCloud {
                    homeViewModel.clearLocalLedgerData()
                }
            }
        } else {
            homeViewModel.clearLocalLedgerData()
        }
    }

    private var settingsInkAccent: Color {
        Color(red: 0.62, green: 0.50, blue: 0.30)
    }

    private var settingsInkText: Color {
        Color(red: 28/255, green: 30/255, blue: 32/255)
    }

    private var settingsMutedText: Color {
        Color(red: 108/255, green: 114/255, blue: 110/255)
    }

    private var settingsSage: Color {
        Color(red: 184/255, green: 199/255, blue: 187/255)
    }

    private var settingsDeepSage: Color {
        Color(red: 168/255, green: 184/255, blue: 170/255)
    }

    private var settingsMint: Color {
        Color(red: 241/255, green: 246/255, blue: 242/255)
    }

    private var settingsCream: Color {
        Color(red: 249/255, green: 247/255, blue: 241/255)
    }

    private var settingsEnvelopeIvory: Color {
        Color(red: 248/255, green: 244/255, blue: 232/255)
    }

    private var settingsEnvelopeWarm: Color {
        Color(red: 248/255, green: 238/255, blue: 216/255)
    }

    private var settingsEnvelopeMint: Color {
        Color(red: 232/255, green: 243/255, blue: 233/255)
    }

    private var settingsEnvelopeSage: Color {
        Color(red: 169/255, green: 190/255, blue: 171/255)
    }

    private var settingsEnvelopeDeepSage: Color {
        Color(red: 92/255, green: 124/255, blue: 108/255)
    }

    @ViewBuilder
    private func settingsTileBackground(_ style: SettingsTileStyle) -> some View {
        switch style {
        case .solid:
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 146/255, green: 172/255, blue: 154/255).opacity(0.98),
                            Color(red: 125/255, green: 158/255, blue: 139/255).opacity(0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        case .light:
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [settingsCream.opacity(0.96), Color.white.opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        case .cream:
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [settingsCream.opacity(0.98), Color(red: 247/255, green: 245/255, blue: 240/255)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        case .mint:
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [settingsMint.opacity(0.98), Color.white.opacity(0.80)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private func settingsTileTextColor(_ style: SettingsTileStyle) -> Color {
        style == .solid ? .white : settingsInkText
    }

    private func settingsTileSubtextColor(_ style: SettingsTileStyle) -> Color {
        style == .solid ? Color.white.opacity(0.88) : settingsInkText.opacity(0.82)
    }

    private func settingsTileIconColor(_ style: SettingsTileStyle) -> Color {
        switch style {
        case .solid:
            return Color.white.opacity(0.80)
        case .cream:
            return settingsInkAccent.opacity(0.70)
        case .mint:
            return Color(red: 132/255, green: 160/255, blue: 141/255).opacity(0.82)
        case .light:
            return settingsInkAccent.opacity(0.72)
        }
    }

    private func settingsTileShadowColor(_ style: SettingsTileStyle) -> Color {
        switch style {
        case .solid:
            return settingsSage.opacity(0.24)
        case .mint:
            return settingsSage.opacity(0.15)
        default:
            return Color.black.opacity(0.035)
        }
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

    private func settingsConfirmations<Content: View>(
        _ content: Content,
        host: SettingsConfirmationHost
    ) -> some View {
        ZStack {
            content
            settingsConfirmationOverlay(host: host)
        }
    }

    private func activeSettingsConfirmation(for host: SettingsConfirmationHost) -> SettingsConfirmationKind? {
        guard confirmationHost == host else { return nil }
        if showDeleteCloudLedgerConfirm { return .deleteCloudLedger }
        if showEnableCloudSyncConfirm { return .enableCloudSync }
        if showLoginCloudSyncMergeConfirm { return .loginCloudSyncMerge }
        if showClearAllRecordsConfirm { return .clearAllRecords }
        if showDeleteAccountConfirm { return .deleteAccount }
        return nil
    }

    @ViewBuilder
    private func settingsConfirmationOverlay(host: SettingsConfirmationHost) -> some View {
        if let kind = activeSettingsConfirmation(for: host) {
            ZStack {
                Color(red: 28/255, green: 36/255, blue: 42/255)
                    .opacity(0.24)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissSettingsConfirmation(kind)
                    }

                settingsConfirmationCard(kind)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.88), value: kind)
            .zIndex(40)
        }
    }

    private func settingsConfirmationCard(_ kind: SettingsConfirmationKind) -> some View {
        let details = settingsConfirmationDetails(for: kind)
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: details.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(details.accent.opacity(0.94))
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(details.accent.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 7) {
                    Text(details.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppColors.text)

                    Text(details.message)
                        .font(.system(size: 14))
                        .lineSpacing(4)
                        .foregroundStyle(AppColors.subtext.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 10) {
                ForEach(details.actions) { action in
                    settingsConfirmationButton(action)
                }
            }
        }
        .padding(22)
        .frame(maxWidth: 370)
        .background(settingsConfirmationCardBackground)
        .overlay(settingsConfirmationCardBorder)
        .shadow(color: Color(red: 47/255, green: 67/255, blue: 58/255).opacity(0.18), radius: 24, x: 0, y: 12)
        .padding(.horizontal, 24)
    }

    private func settingsConfirmationDetails(
        for kind: SettingsConfirmationKind
    ) -> (symbol: String, title: String, message: String, accent: Color, actions: [SettingsConfirmationAction]) {
        switch kind {
        case .deleteCloudLedger:
            return (
                "icloud.slash",
                "删除云端账本",
                "只删除服务器上的同步账本，本机记录仍保留。为避免重新上传，云端同步会同时关闭。",
                Color(red: 0.78, green: 0.28, blue: 0.24),
                [
                    SettingsConfirmationAction(id: "cancel", title: "取消", style: .secondary) {
                        dismissSettingsConfirmation(.deleteCloudLedger)
                    },
                    SettingsConfirmationAction(id: "deleteCloudLedger", title: "删除云端账本", style: .destructive) {
                        dismissSettingsConfirmation(.deleteCloudLedger)
                        Task { await settingsViewModel.deleteCloudLedger() }
                    }
                ]
            )
        case .enableCloudSync:
            return (
                "icloud.and.arrow.up",
                "开启云端备份",
                "会先把云端账本和本机记录合并，再把最新结果同步上去。重复或冲突记录会保留更新时间较新的版本。",
                AppColors.accent,
                [
                    SettingsConfirmationAction(id: "cancel", title: "先不开启", style: .secondary) {
                        dismissSettingsConfirmation(.enableCloudSync)
                    },
                    SettingsConfirmationAction(id: "enableCloudSync", title: "开启并同步", style: .primary) {
                        dismissSettingsConfirmation(.enableCloudSync)
                        enableCloudSyncAndMerge()
                    }
                ]
            )
        case .loginCloudSyncMerge:
            return (
                "arrow.triangle.2.circlepath",
                "这台设备已有本地账本",
                "当前账号的云端备份偏好是开启的。要把这台设备上的本地记录和当前账号的云端账本合并吗？",
                AppColors.accent,
                [
                    SettingsConfirmationAction(id: "mergeLocal", title: "合并到当前账号", style: .primary) {
                        mergeLocalLedgerIntoCurrentAccount()
                    },
                    SettingsConfirmationAction(id: "keepLocal", title: "先不同步，只看本机", style: .secondary) {
                        keepLocalLedgerOnlyForCurrentLogin()
                    },
                    SettingsConfirmationAction(id: "replaceLocal", title: "清空本机后同步云端", style: .destructive) {
                        replaceLocalLedgerWithCurrentAccountCloud()
                    }
                ]
            )
        case .clearAllRecords:
            return (
                "trash",
                "清空所有记录",
                clearAllRecordsConfirmMessage,
                Color(red: 0.78, green: 0.28, blue: 0.24),
                [
                    SettingsConfirmationAction(id: "cancel", title: "取消", style: .secondary) {
                        dismissSettingsConfirmation(.clearAllRecords)
                    },
                    SettingsConfirmationAction(id: "clearAllRecords", title: "清空所有记录", style: .destructive) {
                        dismissSettingsConfirmation(.clearAllRecords)
                        clearAllRecords()
                    }
                ]
            )
        case .deleteAccount:
            return (
                "person.crop.circle.badge.xmark",
                "注销账号",
                "这会退出登录，并清空服务器上的账号、云端账本和会员绑定状态。Apple 订阅不会自动取消，之后可用同一 Apple ID 登录后恢复购买。",
                Color(red: 0.78, green: 0.28, blue: 0.24),
                [
                    SettingsConfirmationAction(id: "keepLocal", title: "保留本机账本并注销", style: .destructive) {
                        dismissSettingsConfirmation(.deleteAccount)
                        Task {
                            let didDelete = await settingsViewModel.deleteCloudAccount()
                            if didDelete {
                                showAccountSheet = false
                            }
                        }
                    },
                    SettingsConfirmationAction(id: "clearLocal", title: "清空本机账本并注销", style: .destructive) {
                        dismissSettingsConfirmation(.deleteAccount)
                        Task {
                            let didDelete = await settingsViewModel.deleteCloudAccount()
                            if didDelete {
                                homeViewModel.clearLocalLedgerData()
                                showAccountSheet = false
                            }
                        }
                    },
                    SettingsConfirmationAction(id: "cancel", title: "取消", style: .secondary) {
                        dismissSettingsConfirmation(.deleteAccount)
                    }
                ]
            )
        }
    }

    private func settingsConfirmationButton(_ action: SettingsConfirmationAction) -> some View {
        Button {
            action.handler()
        } label: {
            Text(action.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(settingsConfirmationButtonForeground(for: action.style))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background {
                    settingsConfirmationButtonBackground(for: action.style)
                }
        }
        .buttonStyle(.plain)
    }

    private func settingsConfirmationButtonForeground(for style: SettingsConfirmationActionStyle) -> Color {
        switch style {
        case .primary, .destructive:
            return .white
        case .secondary:
            return AppColors.text.opacity(0.82)
        }
    }

    @ViewBuilder
    private func settingsConfirmationButtonBackground(for style: SettingsConfirmationActionStyle) -> some View {
        switch style {
        case .primary:
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppColors.accent.opacity(0.92), AppColors.accentDark.opacity(0.90)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        case .secondary:
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.66))
        case .destructive:
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.84, green: 0.34, blue: 0.30),
                            Color(red: 0.68, green: 0.22, blue: 0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private var settingsConfirmationCardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.84),
                        AppColors.paperWarm.opacity(0.34),
                        AppColors.paperMist.opacity(0.38)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
    }

    private var settingsConfirmationCardBorder: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.82),
                        AppColors.accent.opacity(0.16),
                        AppColors.paperBorder.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    private func dismissSettingsConfirmation(_ kind: SettingsConfirmationKind) {
        switch kind {
        case .deleteCloudLedger:
            showDeleteCloudLedgerConfirm = false
        case .enableCloudSync:
            showEnableCloudSyncConfirm = false
        case .loginCloudSyncMerge:
            keepLocalLedgerOnlyForCurrentLogin()
        case .clearAllRecords:
            showClearAllRecordsConfirm = false
        case .deleteAccount:
            showDeleteAccountConfirm = false
        }
    }

    @ViewBuilder
    private func settingsSheetContent(_ sheet: SettingsSheet) -> some View {
        switch sheet {
        case .backup:
            settingToggle("云端备份（可选）", isOn: Binding(
                get: { settingsViewModel.syncEnabled },
                set: { requestCloudSyncChange($0) }
            ))
            cloudSyncHelper()
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
            destructiveSettingsButton("清空所有记录") {
                confirmationHost = .settingsSheet
                showClearAllRecordsConfirm = true
            }
            settingHelper(clearAllRecordsHelperText)
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
                set: { requestCloudSyncChange($0) }
            ))
            cloudSyncHelper()

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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                narrativeSealAvatar
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(settingsDisplayName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppColors.text)
                            .lineLimit(1)

                        Button {
                            if showNicknameEditor {
                                commitDisplayName()
                                showNicknameEditor = false
                                focusedField = nil
                            } else {
                                draftDisplayName = settingsViewModel.displayName
                                showNicknameEditor = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                    focusedField = .displayName
                                }
                            }
                        } label: {
                            Image(systemName: showNicknameEditor ? "checkmark" : "pencil")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppColors.subtext.opacity(0.78))
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.50))
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 6) {
                        Text(accountHeaderMemberMeta)
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

            if showNicknameEditor {
                VStack(alignment: .leading, spacing: 6) {
                    settingField(label: "昵称") {
                        TextField("叙账用户", text: $draftDisplayName)
                            .focused($focusedField, equals: .displayName)
                            .submitLabel(.done)
                            .onSubmit {
                                commitDisplayName()
                                showNicknameEditor = false
                            }
                    }
                    settingHelper("不要写手机号、证件号或链接。")
                    if let msg = settingsViewModel.contentSafetyMessage {
                        settingHelper(msg)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
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

    private var accountHeaderMemberMeta: String {
        let expiry = hasExpiredPaidMemberTier ? " · 待续期" : ""
        return "\(memberTierName) · 已登录\(expiry)"
    }

    private var accountMemberSection: some View {
        accountPanel("让账本更懂你") {
            if let validity = settingsViewModel.settings.memberValidityText {
                accountInfoRow(title: "有效期", value: validity)
            }

            if hasMemberAccess || hasPaidMemberTier {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(settingsInkAccent.opacity(0.22))
                    .frame(height: 3)
                LazyVGrid(columns: accountMemberBenefitColumns, alignment: .leading, spacing: 8) {
                    ForEach(accountMemberBenefits, id: \.self) { benefit in
                        memberBenefitRow(benefit)
                    }
                }

                if hasExpiredPaidMemberTier {
                    settingHelper("会员待续期，续费后可恢复权益。")
                    Button {
                        showAccountSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            showMemberPricing = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text("续费会员")
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
            } else {
                accountInfoRow(title: "当前档位", value: memberTierName)
                settingHelper("免费版可以完整记账。会员会让回放、OCR 和生活场景持续跟上你的记录节奏。")
                Button {
                    showAccountSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        showMemberPricing = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("让账本更懂我的生活")
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
                        confirmationHost = .accountSheet
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
                        confirmationHost = .accountSheet
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
            "周/月生活回放无限",
            "每月生活章持续整理",
            "今日回放不限",
            "OCR 导入不限",
            "AI 回顾额度提升",
            "生活场景换角度",
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

    private func cloudSyncHelper() -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: homeViewModel.isSyncingCloudLedger ? "arrow.triangle.2.circlepath" : "icloud")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(settingsInkAccent.opacity(0.82))
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(settingsInkAccent.opacity(0.10))
                )

            Text(cloudSyncHelperText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.text.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.52))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(settingsInkAccent.opacity(0.12), lineWidth: 1)
        )
        .padding(.top, -4)
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

    private func destructiveSettingsButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(Color.red.opacity(0.82))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.red.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.red.opacity(0.18), lineWidth: 1)
            )
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
