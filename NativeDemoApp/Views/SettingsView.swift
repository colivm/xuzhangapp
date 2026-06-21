import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @Binding var showMemberPricing: Bool
    @Binding var pricingHighlightPlanId: String?
    var openAppearanceRequestID: UUID?
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
    @State private var expandedThemeFamily: String?
    @State private var vaultHelperIndex = 0
    @State private var lifetimePreviewTheme: ThemeDefinition?
    @State private var lifetimePreviewDismissTask: Task<Void, Never>?
    @State private var lifetimeTrialOfferTheme: ThemeDefinition?
    @State private var handledAppearanceRequestID: UUID?
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

    private struct AccountMemoryStats {
        let recordStreakDays: Int
        let traceCount: Int
        let weeklyStoryCount: Int
        let monthlyStoryCount: Int
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

    private var isLifetimeMember: Bool {
        settingsViewModel.memberTier.lowercased() == "lifetime" && hasMemberAccess
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

    private let vaultHelperLines = [
        "多数永久会员从「档案馆」开始建立自己的生活档案。",
        "爱看构成和节奏，试试「观察者」。",
        "晚上复盘，「夜读」更适合慢慢翻。"
    ]

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
            settingsViewModel.refreshThemeAccess(showsMessage: true)
            openAppearanceSheetIfNeeded(openAppearanceRequestID)
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
        .onChange(of: openAppearanceRequestID) { _, requestID in
            openAppearanceSheetIfNeeded(requestID)
        }
        .overlay {
            ZStack {
                settingsConfirmationOverlay(host: .main)
                lifetimeThemePreviewOverlay
            }
        }
        .alert(item: $lifetimeTrialOfferTheme) { theme in
            Alert(
                title: Text("试一天典藏皮"),
                message: Text("这次不会改变会员状态，只临时试用 24 小时。试用结束后会回到默认主题。"),
                primaryButton: .default(Text("开始试用")) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    _ = settingsViewModel.startLifetimeThemeTrial(themeId: theme.id)
                },
                secondaryButton: .cancel(Text("以后再说")) {
                    openMemberPricingFromSettingsSheet(highlightPlanId: "lifetime")
                }
            )
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
                        HStack(spacing: 6) {
                            Text(identityCardMeta)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(settingsInkAccent.opacity(0.92))
                                .lineLimit(1)
                            if isLifetimeMember {
                                Text("永久典藏")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color(hex: "A68445"))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(AppColors.lockGold.opacity(0.12))
                                    )
                            }
                        }
                        Text(identityCardSubtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.text.opacity(0.82))
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 28)
                .padding(.top, 28)
                .padding(.bottom, 42)

                if isLifetimeMember {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            lifetimeIdentitySeal
                        }
                    }
                    .padding(.trailing, 18)
                    .padding(.bottom, 14)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(height: 150)
    }

    private var identityCardSubtitle: String {
        if isLifetimeMember {
            return "典藏主题、完整回放和长期故事已经为你保留。"
        }
        return settingsViewModel.hasCloudSession ? "云端备份已准备好，照常记就好。" : "不用登录也能记；换机备份时再放进云端。"
    }

    private var lifetimeIdentitySeal: some View {
        Text("永久有效")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color(hex: "8B6F38"))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(AppColors.lockGold.opacity(0.14))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(AppColors.lockGold.opacity(0.42), lineWidth: 1)
            )
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
        "\(settingsViewModel.appearance.title) · \(settingsViewModel.currentThemeName)"
    }

    private var settingsDisplayName: String {
        settingsViewModel.displayName.isEmpty ? "叙账用户" : settingsViewModel.displayName
    }

    private var memberTierName: String {
        AppSettings.memberTierDisplayName(settingsViewModel.memberTier)
    }

    private var identityCardMeta: String {
        if isLifetimeMember {
            return "永久档案馆 · 随账号保留"
        }
        let sync = settingsViewModel.syncEnabled ? "已同步云端" : "本地保存"
        let expiry = hasExpiredPaidMemberTier ? " · 会员待续期" : ""
        return "\(sync) · \(memberTierName)\(expiry)"
    }

    private var accountRowSummary: String {
        guard settingsViewModel.hasCloudSession else { return "未登录 · 可选" }
        let stats = accountMemoryStats
        if isLifetimeMember {
            return stats.traceCount > 0 ? "永久典藏 · \(stats.traceCount) 条痕迹" : "永久典藏 · 已解锁"
        }
        if stats.traceCount > 0 {
            return "连续 \(stats.recordStreakDays) 天 · \(stats.traceCount) 条痕迹"
        }
        if hasMemberAccess { return "已登录 · \(memberTierName)" }
        if hasPaidMemberTier { return "已登录 · 待续期" }
        return "已登录 · 免费版"
    }

    private var accountMemoryStats: AccountMemoryStats {
        let items = homeViewModel.items.filter { $0.amount > 0 }
        let dayStarts = Set(items.map { Calendar.current.startOfDay(for: $0.createdAt) })
        let monthKeys = Set(items.map { accountMonthKey(for: $0.createdAt) })
        let weekKeys = Set(items.map { accountWeekKey(for: $0.createdAt) })
        return AccountMemoryStats(
            recordStreakDays: accountLongestRecordStreak(from: dayStarts),
            traceCount: items.count,
            weeklyStoryCount: weekKeys.count,
            monthlyStoryCount: monthKeys.count
        )
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

    private func openMemberPricing(highlightPlanId: String? = nil) {
        pricingHighlightPlanId = highlightPlanId
        showMemberPricing = true
    }

    private func openMemberPricingFromSettingsSheet(highlightPlanId: String? = nil) {
        activeSettingsSheet = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            openMemberPricing(highlightPlanId: highlightPlanId)
        }
    }

    private func openAppearanceSheetIfNeeded(_ requestID: UUID?) {
        guard let requestID, handledAppearanceRequestID != requestID else { return }
        handledAppearanceRequestID = requestID
        activeSettingsSheet = .appearance
    }

    private func handleLockedThemeTap(_ theme: ThemeDefinition, style: ThemeSwatchStyle) {
        guard style == .lifetime else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                openMemberPricingFromSettingsSheet()
            }
            return
        }
        if settingsViewModel.canStartLifetimeThemeTrial(for: theme.id) {
            lifetimeTrialOfferTheme = theme
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                openMemberPricingFromSettingsSheet(highlightPlanId: "lifetime")
            }
        }
    }

    private func showLifetimeThemePreview(_ theme: ThemeDefinition) {
        lifetimePreviewDismissTask?.cancel()
        lifetimePreviewTheme = theme
        lifetimePreviewDismissTask = Task {
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                lifetimePreviewTheme = nil
            }
        }
    }

    private func dismissLifetimeThemePreview() {
        lifetimePreviewDismissTask?.cancel()
        lifetimePreviewDismissTask = nil
        lifetimePreviewTheme = nil
    }

    private var settingsInkAccent: Color {
        AppColors.accentDark
    }

    private var settingsInkText: Color {
        AppColors.text
    }

    private var settingsMutedText: Color {
        AppColors.subtext
    }

    private var settingsSage: Color {
        AppColors.accent.opacity(0.62)
    }

    private var settingsDeepSage: Color {
        AppColors.accentDark.opacity(0.64)
    }

    private var settingsMint: Color {
        AppColors.surfaceMuted
    }

    private var settingsCream: Color {
        AppColors.paperWarm
    }

    private var settingsEnvelopeIvory: Color {
        AppColors.settingsEnvelopeIvory
    }

    private var settingsEnvelopeWarm: Color {
        AppColors.settingsEnvelopeWarm
    }

    private var settingsEnvelopeMint: Color {
        AppColors.settingsEnvelopeMint
    }

    private var settingsEnvelopeSage: Color {
        AppColors.settingsEnvelopeSage
    }

    private var settingsEnvelopeDeepSage: Color {
        AppColors.settingsEnvelopeDeepSage
    }

    @ViewBuilder
    private func settingsTileBackground(_ style: SettingsTileStyle) -> some View {
        switch style {
        case .solid:
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppColors.accentDark.opacity(0.98),
                            AppColors.accent.opacity(0.92)
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
                        colors: [settingsCream.opacity(0.98), AppColors.surfaceMuted.opacity(0.82)],
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
            return AppColors.accent.opacity(0.82)
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
            return AppColors.categoryColor(.transport)
        case "伴":
            return AppColors.accent.opacity(0.88)
        case "色":
            return AppColors.lockGold
        case "安":
            return AppColors.categoryColor(.shopping)
        default:
            return settingsInkAccent
        }
    }

    private func settingsSheet(_ sheet: SettingsSheet) -> some View {
        ZStack {
            AppColors.bg.ignoresSafeArea()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(sheet.title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppColors.text)
                        settingsSheetContent(sheet, proxy: proxy)
                    }
                    .webCardPadding()
                    .webCardBackground()
                    .padding(16)
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    guard sheet == .appearance else { return }
                    expandFamilyForCurrentTheme()
                }
            }
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
                Color(hex: "1C242A")
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
        .shadow(color: Color(hex: "2F433A").opacity(0.18), radius: 24, x: 0, y: 12)
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
                Color(hex: "C7473D"),
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
                Color(hex: "C7473D"),
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
                Color(hex: "C7473D"),
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
                            Color(hex: "D6574D"),
                            Color(hex: "AD3833")
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
    private func settingsSheetContent(_ sheet: SettingsSheet, proxy: ScrollViewProxy? = nil) -> some View {
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
            appearanceSheetContent(proxy: proxy)
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

    private func appearanceSheetContent(proxy: ScrollViewProxy? = nil) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            appearanceModeSection

            Divider().overlay(AppColors.line.opacity(0.7))

            VStack(alignment: .leading, spacing: 20) {
                themeSectionHeader(proxy: proxy)
                dailyThemeSection
                memberThemeSection
                lifetimeThemeVault

                if let msg = settingsViewModel.themeMessage {
                    Text(msg)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.lockGold)
                        .padding(.top, 2)
                }

                settingToggle("分享图使用当前主题", isOn: Binding(
                    get: { settingsViewModel.shareCardUsesAppTheme },
                    set: { settingsViewModel.shareCardUsesAppTheme = $0 }
                ))

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    settingsViewModel.restoreDefaultAppearanceAndTheme()
                } label: {
                    Text("恢复默认主题")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.tertiary)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
            }
        }
    }

    private enum ThemeSwatchStyle {
        case daily
        case standard
        case lifetime
    }

    private var appearanceModeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("明暗")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.text)

            HStack(spacing: 6) {
                appearanceModePill("跟随", symbol: "circle.lefthalf.filled", isActive: settingsViewModel.appearance == .system) {
                    settingsViewModel.appearance = .system
                }
                appearanceModePill("浅色", symbol: "sun.max", isActive: settingsViewModel.appearance == .light) {
                    settingsViewModel.appearance = .light
                }
                appearanceModePill("深色", symbol: "moon", isActive: settingsViewModel.appearance == .dark) {
                    settingsViewModel.appearance = .dark
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppColors.surfaceMuted.opacity(0.74))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppColors.line.opacity(0.52), lineWidth: 1)
            )

            settingHelper("跟随系统时，明暗会随 iOS 设置切换。")
        }
    }

    private func appearanceModePill(
        _ title: String,
        symbol: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: isActive ? .semibold : .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isActive ? AppColors.text : AppColors.subtext)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isActive ? AppColors.panelStrong.opacity(0.88) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isActive ? AppColors.accent.opacity(0.22) : Color.clear, lineWidth: 1)
            )
            .shadow(color: isActive ? AppColors.accent.opacity(0.12) : .clear, radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    private func themeSectionHeader(proxy: ScrollViewProxy?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("生活风格")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.text)
            Text("不是换颜色，而是给你的生活记录选择一种气质。")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext)
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                focusCurrentTheme(proxy)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "scope")
                        .font(.system(size: 10, weight: .semibold))
                    Text("当前：\(settingsViewModel.currentThemeName)")
                        .font(.system(size: 11, weight: .semibold))
                    Image(systemName: "arrow.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(AppColors.accentDark.opacity(0.78))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Capsule(style: .continuous).fill(AppColors.accent.opacity(0.08)))
            }
            .buttonStyle(.plain)
            if settingsViewModel.isLifetimeThemeTrialActive {
                Text("试用中 · 24 小时后自动回到默认主题")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "8B6F38"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule(style: .continuous).fill(AppColors.lockGold.opacity(0.12)))
            }
        }
    }

    private var dailyThemeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("基础风格")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                Spacer()
                Text("免费")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.tertiary)
            }
            themeSwatchGrid(themes: freeThemes, columns: 3, style: .daily)
        }
        .id(themeSectionScrollID(for: .daily))
        .padding(10)
        .background(themeSectionHighlight(for: .daily))
    }

    private var memberThemeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("生活风格系统")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                if !hasMemberAccess {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppColors.lockGold)
                }
            }
            Text("每一种风格对应一种记录气质：纸面、档案、夜读、观察、旅行和展览。")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext)

            VStack(spacing: 6) {
                ForEach(themeFamilySections, id: \.key) { section in
                    themeFamilyDisclosure(section)
                }
            }
        }
        .id(themeSectionScrollID(for: .standard))
    }

    private var lifetimeThemeVault: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("永久典藏风格")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                Spacer()
                Text(settingsViewModel.memberTier.lowercased() == "lifetime" ? "已解锁 ✓" : "✦ 永久会员")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "8B6F38"))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule(style: .continuous).fill(AppColors.lockGold.opacity(0.12)))
            }

            Text("三套长期使用的生活档案风格，随永久会员账号保留。")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext)

            Text(vaultHelperLines[vaultHelperIndex % vaultHelperLines.count])
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext.opacity(0.86))
                .transition(.opacity)

            themeSwatchGrid(themes: lifetimeThemes, columns: 3, style: .lifetime)

            if settingsViewModel.memberTier.lowercased() != "lifetime" {
                Button {
                    openMemberPricingFromSettingsSheet(highlightPlanId: "lifetime")
                } label: {
                    Text("了解永久会员 →")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "8B6F38"))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .buttonStyle(.plain)
                .padding(.top, -2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "F5F0E8"),
                            Color(hex: "EEECF2")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(currentThemeSectionStyle == .lifetime ? AppColors.lockGold.opacity(0.62) : AppColors.lockGold.opacity(0.25), lineWidth: currentThemeSectionStyle == .lifetime ? 1.8 : 1)
        )
        .shadow(color: currentThemeSectionStyle == .lifetime ? AppColors.lockGold.opacity(0.16) : .clear, radius: 12, y: 5)
        .padding(.vertical, 4)
        .id(themeSectionScrollID(for: .lifetime))
        .onReceive(Timer.publish(every: 6.5, on: .main, in: .common).autoconnect()) { _ in
            withAnimation(.easeInOut(duration: 0.24)) {
                vaultHelperIndex = (vaultHelperIndex + 1) % vaultHelperLines.count
            }
        }
    }

    @ViewBuilder
    private var lifetimeThemePreviewOverlay: some View {
        if let theme = lifetimePreviewTheme {
            let background = lifetimePreviewBackground(for: theme) ?? AppColors.bg
            let accent = lifetimePreviewAccent(for: theme) ?? AppColors.lockGold
            ZStack {
                Color.black.opacity(0.16)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissLifetimeThemePreview()
                    }

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("典藏预览")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColors.subtext)
                        Spacer()
                        Button {
                            dismissLifetimeThemePreview()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppColors.subtext)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(AppColors.panelStrong.opacity(0.82)))
                        }
                        .buttonStyle(.plain)
                    }

                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [background, AppColors.paperWarm.opacity(0.88)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 180)
                        .overlay(alignment: .topLeading) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(themeDisplayName(theme))
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(AppColors.text)
                                Text(lifetimeThemeCaption(theme))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(accent)
                            }
                            .padding(18)
                        }
                        .overlay(alignment: .bottomTrailing) {
                            HStack(spacing: 6) {
                                Circle().fill(accent).frame(width: 20, height: 20)
                                RoundedRectangle(cornerRadius: 999, style: .continuous)
                                    .fill(AppColors.panelStrong.opacity(0.78))
                                    .frame(width: 74, height: 10)
                            }
                            .padding(18)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [AppColors.lockGold.opacity(0.55), Color(hex: "A68445").opacity(0.55)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.2
                                )
                        )

                    Text("长按只是预览，不会写入当前主题。")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.subtext)
                }
                .padding(18)
                .frame(maxWidth: 360)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(AppColors.panel.opacity(0.96))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(AppColors.line.opacity(0.62), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.16), radius: 26, y: 12)
                .padding(.horizontal, 24)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
            .zIndex(80)
        }
    }

    private var freeThemes: [ThemeDefinition] {
        ThemeResolver.shared.themes.filter { $0.tier == .free }
    }

    private var lifetimeThemes: [ThemeDefinition] {
        ThemeResolver.shared.themes.filter { $0.tier == .lifetime }
    }

    private var themeFamilySections: [(key: String, title: String, themes: [ThemeDefinition])] {
        let standardThemes = ThemeResolver.shared.themes.filter { $0.tier == .standard }
        let preferredOrder = ["paperverse", "mood_weather", "cyber", "orbital", "bio", "brutal"]
        return preferredOrder.compactMap { family in
            let themes = standardThemes.filter { $0.family == family }
            guard !themes.isEmpty else { return nil }
            return (family, themeFamilyTitle(family), themes)
        }
    }

    private func prepareCurrentThemeLocation(_ proxy: ScrollViewProxy) {
        expandFamilyForCurrentTheme()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            focusCurrentTheme(proxy)
        }
    }

    private func focusCurrentTheme(_ proxy: ScrollViewProxy?) {
        expandFamilyForCurrentTheme()
        guard let proxy else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeInOut(duration: 0.24)) {
                proxy.scrollTo(currentThemeScrollTarget, anchor: .center)
            }
        }
    }

    private func expandFamilyForCurrentTheme() {
        guard let definition = ThemeResolver.shared.definition(for: settingsViewModel.colorThemeId),
              definition.tier == .standard else {
            return
        }
        expandedThemeFamily = definition.family
    }

    private var currentThemeScrollTarget: String {
        guard let definition = ThemeResolver.shared.definition(for: settingsViewModel.colorThemeId) else {
            return themeSectionScrollID(for: .daily)
        }
        return themeScrollID(definition.id)
    }

    private func themeSectionScrollID(for style: ThemeSwatchStyle) -> String {
        "theme-section-\(style)"
    }

    private func themeFamilyScrollID(_ family: String) -> String {
        "theme-family-\(family)"
    }

    private func themeScrollID(_ themeId: String) -> String {
        "theme-\(themeId)"
    }

    private func themeSectionHighlight(for style: ThemeSwatchStyle) -> some View {
        let isActive = currentThemeSectionStyle == style
        return RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(isActive ? AppColors.accent.opacity(0.08) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isActive ? AppColors.accent.opacity(0.28) : Color.clear, lineWidth: 1)
            )
    }

    private var currentThemeSectionStyle: ThemeSwatchStyle? {
        guard let definition = ThemeResolver.shared.definition(for: settingsViewModel.colorThemeId) else { return nil }
        switch definition.tier {
        case .free: return .daily
        case .standard: return .standard
        case .lifetime: return .lifetime
        }
    }

    private func themeFamilyTitle(_ family: String) -> String {
        switch family {
        case "paperverse": return "纸境"
        case "mood_weather": return "夜读"
        case "cyber": return "观察者"
        case "orbital": return "旅行手账"
        case "bio": return "博物馆"
        case "brutal": return "档案馆"
        default: return family
        }
    }

    private func themeFamilySubtitle(_ themes: [ThemeDefinition]) -> String {
        guard let family = themes.first?.family else {
            return themes.prefix(3).map { themeDisplayName($0) }.joined(separator: "、")
        }
        switch family {
        case "paperverse": return "安静纸面，适合长期记录"
        case "mood_weather": return "适合夜间复盘和情绪回看"
        case "cyber": return "更像观察仪表，适合看结构"
        case "orbital": return "适合路上、出差和旅行账本"
        case "bio": return "像展柜一样收藏生活细节"
        case "brutal": return "秩序感更强，适合归档整理"
        default:
            return themes.prefix(3).map { themeDisplayName($0) }.joined(separator: "、")
        }
    }

    private func themeFamilyDisclosure(
        _ section: (key: String, title: String, themes: [ThemeDefinition])
    ) -> some View {
        let isExpanded = expandedThemeFamily == section.key
        let containsSelected = section.themes.contains { $0.id == settingsViewModel.colorThemeId }
        return VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    expandedThemeFamily = isExpanded ? nil : section.key
                }
            } label: {
                HStack(spacing: 12) {
                    themeFamilyStripe(section.key)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(section.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColors.text)
                        Text(themeFamilySubtitle(section.themes))
                            .font(.system(size: 11))
                            .foregroundStyle(AppColors.tertiary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Text("\(section.themes.count) 款")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.tertiary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.accent)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .frame(height: 56)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .overlay(AppColors.line.opacity(0.7))
                    .padding(.leading, 12)
                themeSwatchGrid(themes: section.themes, columns: 2, style: .standard)
                    .padding(.leading, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 6)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(containsSelected ? AppColors.accent.opacity(0.10) : AppColors.surfaceMuted.opacity(0.62))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(containsSelected ? AppColors.accent.opacity(0.42) : AppColors.line.opacity(0.38), lineWidth: containsSelected ? 1.5 : 1)
        )
        .shadow(color: containsSelected ? AppColors.accent.opacity(0.10) : .clear, radius: 10, y: 4)
        .id(themeFamilyScrollID(section.key))
    }

    private func themeSwatchGrid(themes: [ThemeDefinition], columns: Int, style: ThemeSwatchStyle) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columns), spacing: 14) {
            ForEach(themes) { theme in
                themeSwatch(theme, style: style)
            }
        }
    }

    private func themeSwatch(_ theme: ThemeDefinition, style: ThemeSwatchStyle) -> some View {
        let isSelected = settingsViewModel.colorThemeId == theme.id
        let isUnlocked = settingsViewModel.isThemeUnlocked(theme.id)
        let tokens = theme.modes.light ?? theme.modes.dark
        let background = lifetimePreviewBackground(for: theme) ?? tokens?.background.color ?? AppColors.bg
        let warm = tokens?.surfaceWarm.color ?? AppColors.paperWarm
        let accent = lifetimePreviewAccent(for: theme) ?? tokens?.accent.color ?? AppColors.accent
        let surface = tokens?.surface.color ?? AppColors.panel
        let size: CGFloat = style == .lifetime ? 64 : 56
        let radius: CGFloat = style == .lifetime ? 16 : 14
        let nameWeight: Font.Weight = style == .lifetime ? .semibold : .medium
        return Button {
            if settingsViewModel.setTheme(theme.id) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } else {
                handleLockedThemeTap(theme, style: style)
            }
        } label: {
            VStack(spacing: style == .lifetime ? 8 : 7) {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [background, warm],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: size, height: size)
                        .overlay(alignment: .topTrailing) {
                            Circle()
                                .fill(accent)
                                .frame(width: style == .lifetime ? 18 : 16, height: style == .lifetime ? 18 : 16)
                                .padding(7)
                        }
                        .overlay(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 999, style: .continuous)
                                .fill(surface.opacity(0.86))
                                .frame(width: style == .lifetime ? 40 : 34, height: style == .lifetime ? 7 : 6)
                                .padding(.bottom, style == .lifetime ? 10 : 9)
                        }
                        .opacity(isUnlocked ? 1 : 0.92)
                        .overlay(alignment: style == .lifetime ? .topTrailing : .bottomLeading) {
                            if !isUnlocked {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(style == .lifetime ? Color(hex: "8B6F38") : AppColors.lockGold)
                                    .frame(width: 18, height: 18)
                                    .background(
                                        Circle()
                                            .fill(style == .lifetime ? AppColors.lockGold.opacity(0.20) : AppColors.panelStrong.opacity(0.86))
                                    )
                                    .padding(6)
                            }
                        }
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: style == .lifetime ? 17 : 16, weight: .semibold))
                            .foregroundStyle(style == .lifetime ? Color(hex: "A68445") : accent)
                            .background(Circle().fill(AppColors.panelStrong))
                            .offset(x: size / 2 - 6, y: -size / 2 + 8)
                    }
                    if isSelected, style == .daily {
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .fill(accent)
                            .frame(width: size - 14, height: 2)
                            .padding(.bottom, -5)
                    }
                }
                .overlay(
                    swatchBorder(style: style, isSelected: isSelected, accent: accent, radius: radius)
                )
                .shadow(color: isSelected ? accent.opacity(0.14) : Color.black.opacity(0.025), radius: isSelected ? 9 : 5, y: 4)

                swatchNameText(theme, style: style, accent: accent)
                    .font(.system(size: 11, weight: nameWeight))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                if style == .lifetime {
                    Text(lifetimeThemeCaption(theme))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(AppColors.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0.5) {
            guard style == .lifetime else { return }
            showLifetimeThemePreview(theme)
        }
        .accessibilityLabel(themeDisplayName(theme))
        .id(themeScrollID(theme.id))
    }

    @ViewBuilder
    private func swatchBorder(
        style: ThemeSwatchStyle,
        isSelected: Bool,
        accent: Color,
        radius: CGFloat
    ) -> some View {
        if style == .lifetime {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            isSelected ? Color(hex: "A68445") : Color(hex: "C9A961"),
                            Color(hex: "A68445")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isSelected ? 2 : 1.5
                )
        } else {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(isSelected ? accent.opacity(0.88) : AppColors.line.opacity(0.48), lineWidth: isSelected ? 2 : 1)
        }
    }

    private func swatchNameText(_ theme: ThemeDefinition, style: ThemeSwatchStyle, accent: Color) -> Text {
        let displayName = themeDisplayName(theme)
        guard style == .lifetime, displayName.hasPrefix("永享·") else {
            return Text(displayName).foregroundColor(AppColors.text)
        }
        let suffix = String(displayName.dropFirst("永享·".count))
        return Text("永享·").foregroundColor(accent) + Text(suffix).foregroundColor(AppColors.text)
    }

    private func themeDisplayName(_ theme: ThemeDefinition) -> String {
        switch theme.id {
        case "xuzhang_default": return "默认手账"
        case "paperverse_blank": return "纸境"
        case "mood_weather_clear": return "晨间留白"
        case "paperverse_seal": return "朱砂印"
        case "paperverse_ink_wash": return "湿墨"
        case "paperverse_typecase": return "活字格"
        case "paperverse_faint_spectrum": return "淡彩谱"
        case "mood_weather_dusk": return "夜读晚霞"
        case "mood_weather_mist": return "薄雾晨读"
        case "mood_weather_storm": return "雨夜复盘"
        case "mood_weather_aurora": return "极光夜读"
        case "mood_weather_tide": return "潮汐日志"
        case "cyber_neon_abyss": return "观察者"
        case "cyber_vector_camouflage": return "结构网格"
        case "cyber_holographic_dusk": return "全息观察"
        case "cyber_crystal_overload": return "晶体仪表"
        case "cyber_silicon_vesper": return "夜间观测"
        case "orbital_window_dawn": return "旅行手账"
        case "orbital_zero_g": return "轻装清单"
        case "orbital_deep_stamp": return "远行邮戳"
        case "orbital_sleep_mode": return "途中夜航"
        case "bio_moss_terminal": return "博物馆"
        case "bio_coral_data": return "珊瑚展柜"
        case "bio_mycelium": return "菌丝标本"
        case "bio_photosynth": return "光合展厅"
        case "brutal_concrete": return "档案馆"
        case "brutal_safety_orange": return "编号标签"
        case "brutal_grid_paper": return "索引卡"
        case "lifetime_archive_gold": return "永享·档案馆"
        case "lifetime_gilded_circuit": return "永享·观察者"
        case "lifetime_neon_cathedral": return "永享·夜读"
        default: return theme.displayName
        }
    }

    private func lifetimeThemeCaption(_ theme: ThemeDefinition) -> String {
        switch theme.id {
        case "lifetime_gilded_circuit": return "看结构"
        case "lifetime_archive_gold": return "长期归档"
        case "lifetime_neon_cathedral": return "夜间回看"
        default: return "典藏款"
        }
    }

    private func lifetimePreviewBackground(for theme: ThemeDefinition) -> Color? {
        switch theme.id {
        case "lifetime_gilded_circuit": return Color(hex: "EEF1F2")
        case "lifetime_archive_gold": return Color(hex: "F4EFE5")
        case "lifetime_neon_cathedral": return Color(hex: "10141C")
        default: return nil
        }
    }

    private func lifetimePreviewAccent(for theme: ThemeDefinition) -> Color? {
        switch theme.id {
        case "lifetime_gilded_circuit": return Color(hex: "1F6F78")
        case "lifetime_archive_gold": return Color(hex: "9A7032")
        case "lifetime_neon_cathedral": return Color(hex: "CBA66D")
        default: return nil
        }
    }

    private func themeFamilyStripe(_ family: String) -> some View {
        HStack(spacing: 3) {
            ForEach(Array(themeFamilyStripeColors(family).enumerated()), id: \.offset) { _, color in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(color)
                    .frame(width: 3, height: 20)
            }
        }
        .frame(width: 17, alignment: .leading)
    }

    private func themeFamilyStripeColors(_ family: String) -> [Color] {
        switch family {
        case "cyber":
            return [
                Color(hex: "B84888"),
                Color(hex: "5A9858"),
                Color(hex: "48A8B8")
            ]
        case "mood_weather":
            return [
                Color(hex: "C87848"),
                Color(hex: "88A8B8"),
                Color(hex: "58A888")
            ]
        case "paperverse":
            return [
                Color(hex: "B84848"),
                Color(hex: "486878"),
                Color(hex: "9090A8")
            ]
        case "bio":
            return [
                Color(hex: "6A9870"),
                Color(hex: "C88878"),
                Color(hex: "78B068")
            ]
        case "orbital":
            return [
                Color(hex: "D88858"),
                Color(hex: "586878"),
                Color(hex: "688898")
            ]
        case "brutal":
            return [
                Color(hex: "606060"),
                Color(hex: "D85018"),
                Color(hex: "6888B0")
            ]
        default:
            return [AppColors.accent.opacity(0.65), AppColors.accent, AppColors.accentDark]
        }
    }

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
        Text(isLifetimeMember ? "永久典藏" : "已解锁")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(isLifetimeMember ? Color(hex: "8B6F38") : settingsInkAccent.opacity(0.86))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(isLifetimeMember ? AppColors.lockGold.opacity(0.14) : settingsInkAccent.opacity(0.11))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isLifetimeMember ? AppColors.lockGold.opacity(0.42) : settingsInkAccent.opacity(0.18), lineWidth: 1)
            )
    }

    private var accountHeaderMemberMeta: String {
        if isLifetimeMember {
            return "永久会员 · 已登录"
        }
        let expiry = hasExpiredPaidMemberTier ? " · 待续期" : ""
        return "\(memberTierName) · 已登录\(expiry)"
    }

    private var accountMemberSection: some View {
        accountPanel(isLifetimeMember ? "永久典藏档案" : "我的生活档案") {
            accountMemoryCard

            if let validity = settingsViewModel.settings.memberValidityText {
                accountInfoRow(title: "有效期", value: validity)
            } else if isLifetimeMember {
                accountInfoRow(title: "会员身份", value: "永久有效")
            }

            if hasMemberAccess || hasPaidMemberTier {
                if hasExpiredPaidMemberTier {
                    settingHelper("会员待续期，续费后可恢复权益。")
                    Button {
                        showAccountSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            openMemberPricing()
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
                settingHelper("免费版适合轻度记录。会员会持续整理这些痕迹，让周记、月章和生活回放不断档。")
                Button {
                    showAccountSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        openMemberPricing()
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

    private var accountMemoryCard: some View {
        let stats = accountMemoryStats
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(accountMemoryTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.text)
                    Text(accountMemorySubtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.subtext.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: isLifetimeMember ? "crown.fill" : (hasMemberAccess ? "checkmark.seal.fill" : "sparkles"))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isLifetimeMember ? AppColors.lockGold.opacity(0.95) : settingsInkAccent.opacity(0.86))
            }

            LazyVGrid(columns: accountMemoryMetricColumns, spacing: 10) {
                accountMemoryMetric(value: "\(stats.recordStreakDays)", label: "连续记录天")
                accountMemoryMetric(value: "\(stats.traceCount)", label: "AI整理生活痕迹")
                accountMemoryMetric(value: "\(stats.weeklyStoryCount)", label: "可整理周记")
                accountMemoryMetric(value: "\(stats.monthlyStoryCount)", label: "保存月份故事")
            }

            Text(isLifetimeMember ? "这是随账号保留的完整生活档案，不只是一个设置开关。" : "这些不是设置项，是你已经留下来的生活沉淀。")
                .font(.system(size: 11))
                .foregroundStyle(AppColors.subtext.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            (isLifetimeMember ? AppColors.lockGold : settingsInkAccent).opacity(isLifetimeMember ? 0.14 : 0.10),
                            Color.white.opacity(0.58)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isLifetimeMember ? AppColors.lockGold.opacity(0.42) : settingsInkAccent.opacity(0.16), lineWidth: isLifetimeMember ? 1.2 : 1)
        )
    }

    private var accountMemoryTitle: String {
        if isLifetimeMember {
            return "永久档案馆已启封"
        }
        return hasMemberAccess ? "已解锁完整生活档案" : "你的生活档案正在形成"
    }

    private var accountMemorySubtitle: String {
        if isLifetimeMember {
            return "AI 会长期整理这些日子，典藏主题和完整回放随账号保留。"
        }
        return hasMemberAccess ? "AI 正在持续整理和连接每一天。" : "开通会员后，这些痕迹会继续整理成周记、月章和回放。"
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

    private var accountMemoryMetricColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
        ]
    }

    private func accountMemoryMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppColors.text)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.subtext.opacity(0.84))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.white.opacity(0.56))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.44), lineWidth: 1)
        )
    }

    private func accountLongestRecordStreak(from dayStarts: Set<Date>) -> Int {
        guard !dayStarts.isEmpty else { return 0 }
        let sortedDays = dayStarts.sorted()
        var longest = 1
        var current = 1
        for index in sortedDays.indices.dropFirst() {
            let previous = sortedDays[sortedDays.index(before: index)]
            let day = sortedDays[index]
            let gap = Calendar.current.dateComponents([.day], from: previous, to: day).day ?? 0
            if gap == 1 {
                current += 1
            } else if gap > 1 {
                current = 1
            }
            longest = max(longest, current)
        }
        return longest
    }

    private func accountMonthKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)"
    }

    private func accountWeekKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(components.yearForWeekOfYear ?? 0)-\(components.weekOfYear ?? 0)"
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
            .shadow(color: Color(hex: "75839C").opacity(0.11), radius: 22, x: 0, y: 8)
    }

    func webCardPadding() -> some View {
        self.padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(showMemberPricing: .constant(false), pricingHighlightPlanId: .constant(nil), openAppearanceRequestID: nil)
            .environmentObject(SettingsViewModel())
            .environmentObject(HomeViewModel())
    }
}
