import Foundation
import SwiftUI
import Combine

enum SettingsViewModelError: LocalizedError {
    case loginRequired
    case memberEntitlementUnavailable
    case themeLocked(String)

    var errorDescription: String? {
        switch self {
        case .loginRequired:
            return "请先登录账号，再开通或恢复会员，这样换机后也能找回权益。"
        case .memberEntitlementUnavailable:
            return "当前账号暂时没有可用会员权益。请确认购买是否完成，或使用购买时的账号恢复。"
        case .themeLocked(let message):
            return message
        }
    }
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published var loginPhone: String = ""
    @Published var loginCode: String = ""
    @Published private(set) var authMessage: String?
    @Published private(set) var contentSafetyMessage: String?
    @Published private(set) var themeMessage: String?
    @Published private(set) var isAuthBusy: Bool = false
    @Published private(set) var smsCooldownRemaining: Int = 0
    @Published private(set) var hasPendingLoginCloudSyncDecision: Bool = false
    /// 是否已保存访问令牌（与 Keychain 同步，用于界面展示）。
    @Published private(set) var hasCloudSession: Bool = false
    private var smsCooldownTask: Task<Void, Never>?
    private var cloudSessionInvalidationCancellable: AnyCancellable?
    private enum ThemeTrialKeys {
        static let usedAt = "lifetimeThemeTrialUsedAt"
        static let themeId = "lifetimeThemeTrialThemeId"
        static let duration: TimeInterval = 24 * 60 * 60
    }

    init() {
        settings = LocalStore.loadSettings()
        hasCloudSession = !KeychainService.loadAccessToken().isEmpty
        if !hasCloudSession {
            settings.syncEnabled = false
            settings.cloudUserId = ""
        } else if !settings.cloudUserId.isEmpty,
                  !LocalStore.hasCloudSyncPreference(for: settings.cloudUserId) {
            LocalStore.saveCloudSyncPreference(settings.syncEnabled, for: settings.cloudUserId)
        }
        if !hasCloudSession && Self.isBackendDefaultDisplayName(settings.displayName) {
            settings.displayName = Self.localDefaultDisplayName
        }
        settings.displayName = sanitizedDisplayName(settings.displayName)
        settings.petNickname = sanitizedPetNickname(settings.petNickname)
        settings.colorThemeId = validThemeId(settings.colorThemeId)
        enforceCurrentThemeAccess(showsMessage: false)
        persist()
        cloudSessionInvalidationCancellable = NotificationCenter.default
            .publisher(for: .cloudSessionDidExpire)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.applyExpiredCloudSessionState()
                }
            }
    }

    var displayName: String {
        get { settings.displayName }
        set {
            settings.displayName = sanitizedDisplayName(newValue)
            persist()
        }
    }

    var notificationsEnabled: Bool {
        get { settings.notificationsEnabled }
        set {
            settings.notificationsEnabled = newValue
            persist()
        }
    }

    var appearance: AppSettings.Appearance {
        get { settings.appearance }
        set {
            settings.appearance = newValue
            applyThemeResolver()
            persist()
        }
    }

    var colorThemeId: String {
        settings.colorThemeId
    }

    var shareCardUsesAppTheme: Bool {
        get { settings.shareCardUsesAppTheme }
        set {
            if newValue && !settings.hasMemberAccess {
                settings.shareCardUsesAppTheme = false
                themeMessage = ExperienceRuleCopy.shareThemeMemberToast
                persist()
                return
            }
            settings.shareCardUsesAppTheme = newValue
            themeMessage = nil
            persist()
        }
    }

    var biometricLockEnabled: Bool {
        get { settings.biometricLockEnabled }
        set {
            settings.biometricLockEnabled = newValue
            persist()
        }
    }

    var syncEnabled: Bool {
        get { settings.syncEnabled }
        set {
            setCloudSyncEnabled(newValue, rememberForAccount: true)
        }
    }

    var petCompanionEnabled: Bool {
        get { settings.petCompanionEnabled }
        set {
            settings.petCompanionEnabled = newValue
            persist()
            if newValue {
                if settings.weatherCompanionEnabled {
                    WeatherCompanionService.shared.startBackgroundRefresh()
                }
            } else {
                WeatherCompanionService.shared.stopBackgroundRefresh()
            }
        }
    }

    var petNickname: String {
        get { settings.petNickname }
        set {
            settings.petNickname = sanitizedPetNickname(newValue)
            persist()
        }
    }

    @discardableResult
    func updateDisplayName(_ value: String) -> Bool {
        let result = UserContentRiskService.shared.validateDisplayName(value, fallback: Self.localDefaultDisplayName)
        guard result.isAllowed else {
            contentSafetyMessage = result.message
            return false
        }
        settings.displayName = result.value
        contentSafetyMessage = nil
        persist()
        Task { await syncDisplayNameToCloud(result.value) }
        return true
    }

    @discardableResult
    func updatePetNickname(_ value: String) -> Bool {
        let result = UserContentRiskService.shared.validatePetNickname(value)
        guard result.isAllowed else {
            contentSafetyMessage = result.message
            return false
        }
        settings.petNickname = result.value
        contentSafetyMessage = nil
        persist()
        return true
    }

    var weatherCompanionEnabled: Bool {
        get { settings.weatherCompanionEnabled }
        set {
            settings.weatherCompanionEnabled = newValue
            persist()
            if newValue, settings.petCompanionEnabled {
                WeatherCompanionService.shared.startBackgroundRefresh()
            } else {
                WeatherCompanionService.shared.stopBackgroundRefresh()
            }
        }
    }

    var aiTone: AppSettings.AITone {
        get { settings.aiTone }
        set {
            guard settings.aiTone != newValue else { return }
            settings.aiTone = newValue
            persist()
            notifyNarrativeAIConfigurationChanged()
        }
    }

    var useRemoteAI: Bool {
        get { settings.useRemoteAI }
        set {
            guard settings.useRemoteAI != newValue else { return }
            settings.useRemoteAI = newValue
            persist()
            notifyNarrativeAIConfigurationChanged()
        }
    }

    var aiEndpoint: String {
        get { settings.aiEndpoint }
        set {
            settings.aiEndpoint = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            persist()
        }
    }

    var aiAPIKey: String {
        get { KeychainService.loadAIAPIKey() }
        set {
            KeychainService.saveAIAPIKey(newValue)
        }
    }

    var aiModel: String {
        get { settings.aiModel }
        set {
            settings.aiModel = newValue
            persist()
        }
    }

    var remoteAIMonthlyLimit: Int {
        get { settings.remoteAIMonthlyLimit }
        set {
            settings.remoteAIMonthlyLimit = max(0, newValue)
            persist()
        }
    }

    var backendBaseURL: String {
        get { settings.backendBaseURL }
        set {
            settings.backendBaseURL = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            persist()
        }
    }

    var cloudUserId: String {
        settings.cloudUserId
    }

    var memberTier: String {
        get { settings.memberTier }
        set {
            settings.memberTier = newValue
            if newValue.lowercased() == "free" {
                settings.memberExpiresAt = nil
            }
            enforceCurrentThemeAccess(showsMessage: true)
            persist()
        }
    }

    var colorScheme: ColorScheme? {
        settings.colorScheme
    }

    var currentThemeName: String {
        ThemeResolver.shared.definition(for: settings.colorThemeId)?.displayName ?? "叙账默认"
    }

    var activeLifetimeThemeTrialThemeId: String? {
        guard let themeId = UserDefaults.standard.string(forKey: ThemeTrialKeys.themeId),
              let definition = ThemeResolver.shared.definition(for: themeId),
              definition.tier == .lifetime else { return nil }
        let usedAt = UserDefaults.standard.double(forKey: ThemeTrialKeys.usedAt)
        guard usedAt > 0, Date().timeIntervalSince1970 < usedAt + ThemeTrialKeys.duration else { return nil }
        return themeId
    }

    var isLifetimeThemeTrialActive: Bool {
        activeLifetimeThemeTrialThemeId != nil
    }

    @discardableResult
    func setTheme(_ themeId: String, showsLockedMessage: Bool = true) -> Bool {
        let resolvedId = validThemeId(themeId)
        guard isThemeUnlocked(resolvedId) else {
            if showsLockedMessage {
                themeMessage = lockedThemeMessage(for: resolvedId)
            }
            return false
        }
        settings.colorThemeId = resolvedId
        themeMessage = nil
        applyThemeResolver()
        persist()
        return true
    }

    func restoreDefaultAppearanceAndTheme() {
        settings.appearance = .system
        settings.colorThemeId = ThemeResolver.defaultThemeId
        settings.shareCardUsesAppTheme = false
        themeMessage = nil
        applyThemeResolver()
        persist()
    }

    func refreshThemeAccess(showsMessage: Bool = false) {
        enforceCurrentThemeAccess(showsMessage: showsMessage)
        persist()
    }

    func isThemeUnlocked(_ themeId: String) -> Bool {
        guard let definition = ThemeResolver.shared.definition(for: themeId) else {
            return themeId == ThemeResolver.defaultThemeId
        }
        let requiredTier = definition.unlockTier ?? definition.tier
        switch requiredTier {
        case .free:
            return true
        case .standard:
            return settings.hasMemberAccess
        case .lifetime:
            if definition.tier == .lifetime, activeLifetimeThemeTrialThemeId == themeId {
                return true
            }
            return settings.memberTier.lowercased() == "lifetime"
        }
    }

    func canStartLifetimeThemeTrial(for themeId: String) -> Bool {
        guard settings.memberTier.lowercased() != "lifetime",
              UserDefaults.standard.object(forKey: ThemeTrialKeys.usedAt) == nil,
              let definition = ThemeResolver.shared.definition(for: themeId),
              definition.tier == .lifetime else { return false }
        return true
    }

    @discardableResult
    func startLifetimeThemeTrial(themeId: String) -> Bool {
        guard canStartLifetimeThemeTrial(for: themeId) else { return false }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: ThemeTrialKeys.usedAt)
        UserDefaults.standard.set(themeId, forKey: ThemeTrialKeys.themeId)
        settings.colorThemeId = themeId
        themeMessage = "典藏主题试用中，24 小时后会自动回到默认主题。"
        applyThemeResolver()
        persist()
        return true
    }

    func lockedThemeMessage(for themeId: String) -> String {
        guard let definition = ThemeResolver.shared.definition(for: themeId) else {
            return "这个主题暂时不可用。"
        }
        let requiredTier = definition.unlockTier ?? definition.tier
        switch requiredTier {
        case .free:
            return "这个主题暂时不可用。"
        case .standard:
            return "开通会员解锁主题。"
        case .lifetime:
            return "永久会员专属。"
        }
    }

    func sendSMSLoginCode() async {
        authMessage = nil
        guard !isAuthBusy else { return }
        if smsCooldownRemaining > 0 {
            authMessage = "验证码发送太频繁，请 \(smsCooldownRemaining) 秒后再试。"
            return
        }
        let phone = loginPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard phone.count == 11, phone.hasPrefix("1") else {
            authMessage = "请输入 11 位手机号。"
            return
        }
        isAuthBusy = true
        defer { isAuthBusy = false }
        let client = AuthService(baseURL: backendBaseURL)
        do {
            try await client.sendSMSCode(phone: phone)
            authMessage = "验证码已发送，请查看短信。"
            startSMSCooldown(60)
        } catch {
            authMessage = sendSMSMessage(for: error)
        }
    }

    func clearAuthMessage() {
        authMessage = nil
    }

    func verifySMSLogin() async {
        authMessage = nil
        guard !isAuthBusy else { return }
        let phone = loginPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = loginCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard phone.count == 11 else {
            authMessage = "请先填写手机号。"
            return
        }
        guard !code.isEmpty else {
            authMessage = "请输入验证码。"
            return
        }
        isAuthBusy = true
        defer { isAuthBusy = false }
        let client = AuthService(baseURL: backendBaseURL)
        do {
            let session = try await client.loginWithSMS(phone: phone, code: code)
            KeychainService.saveAccessToken(session.accessToken)
            settings.displayName = sanitizedDisplayName(session.displayName)
            settings.cloudUserId = session.userId
            settings.memberTier = session.memberTier
            settings.memberExpiresAt = session.memberExpiresAt
            enforceCurrentThemeAccess(showsMessage: true)
            settings.syncEnabled = false
            hasPendingLoginCloudSyncDecision = session.cloudSyncEnabled ?? LocalStore.loadCloudSyncPreference(for: session.userId)
            SummaryPlaybackQuotaStore().syncLocalUsageAfterLogin(userId: session.userId)
            persist()
            if let account = try? await client.fetchAccountMe(accessToken: session.accessToken) {
                applyCloudAccount(account, allowsPendingCloudSyncDecision: true)
            }
            let tier = try await client.fetchMemberMe(accessToken: session.accessToken)
            settings.memberTier = tier.tier
            settings.memberExpiresAt = tier.expiresAt
            enforceCurrentThemeAccess(showsMessage: true)
            persist()
            hasCloudSession = true
            notifyNarrativeAIConfigurationChanged()
            authMessage = "登录成功。"
            loginCode = ""
        } catch {
            authMessage = verifySMSMessage(for: error)
        }
    }

    func logoutCloud() {
        stopSMSCooldown()
        KeychainService.clearAccessToken()
        settings.cloudUserId = ""
        settings.memberTier = "free"
        settings.memberExpiresAt = nil
        settings.syncEnabled = false
        enforceCurrentThemeAccess(showsMessage: true)
        hasPendingLoginCloudSyncDecision = false
        if Self.isBackendDefaultDisplayName(settings.displayName) {
            settings.displayName = Self.localDefaultDisplayName
        }
        hasCloudSession = false
        authMessage = "已退出登录。"
        persist()
        notifyNarrativeAIConfigurationChanged()
    }

    func enableCloudSyncForCurrentAccount() {
        hasPendingLoginCloudSyncDecision = false
        setCloudSyncEnabled(true, rememberForAccount: true)
    }

    func keepCloudSyncOffForCurrentLogin() {
        hasPendingLoginCloudSyncDecision = false
        settings.syncEnabled = false
        persist()
        authMessage = "已先保留本机账本，不会自动同步账单字段到当前账号；照片仍只在本机。"
    }

    @discardableResult
    func deleteCloudLedger() async -> Bool {
        authMessage = nil
        let token = KeychainService.loadAccessToken()
        guard !token.isEmpty else {
            authMessage = "请先登录账号。"
            return false
        }
        isAuthBusy = true
        defer { isAuthBusy = false }
        let client = AuthService(baseURL: backendBaseURL)
        do {
            try await client.deleteCloudLedger(accessToken: token)
            setCloudSyncEnabled(false, rememberForAccount: true)
            authMessage = "云端账单字段已删除，本机记录和照片仍保留。"
            return true
        } catch {
            if invalidateCloudSessionIfUnauthorized(error) { return false }
            authMessage = "云端账单字段暂时没删除成功，请稍后再试。"
            return false
        }
    }

    @discardableResult
    func deleteCloudAccount() async -> Bool {
        authMessage = nil
        let token = KeychainService.loadAccessToken()
        guard !token.isEmpty else {
            authMessage = "请先登录账号。"
            return false
        }
        isAuthBusy = true
        defer { isAuthBusy = false }
        let client = AuthService(baseURL: backendBaseURL)
        let deletedUserId = settings.cloudUserId
        do {
            try await client.deleteAccount(accessToken: token)
            KeychainService.clearAccessToken()
            settings.cloudUserId = ""
            settings.memberTier = "free"
            settings.memberExpiresAt = nil
            settings.syncEnabled = false
            enforceCurrentThemeAccess(showsMessage: true)
            hasPendingLoginCloudSyncDecision = false
            LocalStore.removeCloudSyncPreference(for: deletedUserId)
            LocalStore.removeCloudSyncPreferenceMigration(for: deletedUserId)
            if Self.isBackendDefaultDisplayName(settings.displayName) {
                settings.displayName = Self.localDefaultDisplayName
            }
            hasCloudSession = false
            authMessage = "账号已注销，云端数据和会员关联已删除。"
            persist()
            notifyNarrativeAIConfigurationChanged()
            return true
        } catch {
            if invalidateCloudSessionIfUnauthorized(error) { return false }
            authMessage = "账号暂时没注销成功，请稍后再试。"
            return false
        }
    }

    func verifyIAPPurchase(_ payload: IAPPurchaseVerification, showsMessage: Bool = true) async throws {
        let token = KeychainService.loadAccessToken()
        guard !token.isEmpty else {
            if showsMessage {
                authMessage = "请先登录账号，再开通会员，这样换机后也能找回权益。"
            }
            throw SettingsViewModelError.loginRequired
        }
        isAuthBusy = true
        defer { isAuthBusy = false }
        let client = AuthService(baseURL: backendBaseURL)
        let verified = try await client.verifyIAPPurchase(
            accessToken: token,
            productId: payload.productId,
            transactionId: payload.transactionId,
            signedTransactionInfo: payload.signedTransactionInfo
        )
        var resolvedTier = verified.tier
        var resolvedExpiresAt = verified.expiresAt
        do {
            let tier = try await client.fetchMemberMe(accessToken: token)
            let verifiedHasAccess = AppSettings.hasMemberAccess(tier: verified.tier, expiresAt: verified.expiresAt)
            let fetchedHasAccess = AppSettings.hasMemberAccess(tier: tier.tier, expiresAt: tier.expiresAt)
            if fetchedHasAccess || !verifiedHasAccess {
                resolvedTier = tier.tier
                resolvedExpiresAt = tier.expiresAt
            }
        } catch {
            // The verify endpoint is still authoritative for this operation.
        }
        settings.memberTier = resolvedTier
        settings.memberExpiresAt = resolvedExpiresAt
        enforceCurrentThemeAccess(showsMessage: true)
        persist()
        guard AppSettings.hasMemberAccess(tier: resolvedTier, expiresAt: resolvedExpiresAt) else {
            if showsMessage {
                authMessage = "当前账号暂时没有可用会员权益。请确认购买是否完成，或使用购买时的账号恢复。"
            }
            throw SettingsViewModelError.memberEntitlementUnavailable
        }
        if showsMessage {
            authMessage = "会员状态已更新。"
        }
    }

    func refreshMemberFromLocalEntitlements(
        synchronize: Bool = false,
        syncToCloud: Bool = true,
        showsMessage: Bool = false
    ) async {
        do {
            let payloads = try await IAPService.shared.currentEntitlements(synchronize: synchronize)
            guard let payload = bestLocalEntitlement(from: payloads),
                  hasActiveLocalEntitlement(payload) else { return }
            let currentHasAccess = settings.hasMemberAccess
            guard hasCloudSession else { return }
            if syncToCloud {
                do {
                    try await verifyIAPPurchase(payload, showsMessage: false)
                } catch {
                    if synchronize, showsMessage {
                        authMessage = "当前账号暂时没有可恢复的会员权益。请确认使用的是购买时的账号。"
                    }
                    return
                }
            }
            if !currentHasAccess, settings.hasMemberAccess, showsMessage {
                authMessage = "已检测到 App Store 会员权益，状态已恢复。"
            }
        } catch {
            if synchronize, showsMessage {
                authMessage = "暂时没恢复到本机会员状态，请稍后再试。"
            }
        }
    }

    func refreshCloudAccountProfile() async {
        let token = KeychainService.loadAccessToken()
        guard !token.isEmpty else { return }
        let client = AuthService(baseURL: backendBaseURL)
        do {
            let account = try await client.fetchAccountMe(accessToken: token)
            applyCloudAccount(account, allowsPendingCloudSyncDecision: false)
        } catch {
            if invalidateCloudSessionIfUnauthorized(error) { return }
            authMessage = "账号信息暂时没刷新成功，请稍后再试。"
        }
    }

    private func persist() {
        LocalStore.saveSettings(settings)
    }

    private func validThemeId(_ themeId: String) -> String {
        ThemeResolver.shared.definition(for: themeId) == nil ? ThemeResolver.defaultThemeId : themeId
    }

    private func enforceCurrentThemeAccess(showsMessage: Bool) {
        let resolvedId = validThemeId(settings.colorThemeId)
        let wasExpiredTrial = isExpiredLifetimeThemeTrial(themeId: resolvedId)
        let shouldFallback = resolvedId != settings.colorThemeId || !isThemeUnlocked(resolvedId)
        settings.colorThemeId = shouldFallback ? ThemeResolver.defaultThemeId : resolvedId
        if shouldFallback {
            settings.shareCardUsesAppTheme = false
            if showsMessage {
                themeMessage = wasExpiredTrial ? "典藏主题试用已结束，已回到默认主题。" : "会员主题已回到默认，开通后可以再切回来。"
            }
        }
        applyThemeResolver()
    }

    private func isExpiredLifetimeThemeTrial(themeId: String) -> Bool {
        guard let storedId = UserDefaults.standard.string(forKey: ThemeTrialKeys.themeId),
              storedId == themeId,
              let definition = ThemeResolver.shared.definition(for: themeId),
              definition.tier == .lifetime else { return false }
        let usedAt = UserDefaults.standard.double(forKey: ThemeTrialKeys.usedAt)
        return usedAt > 0 && Date().timeIntervalSince1970 >= usedAt + ThemeTrialKeys.duration
    }

    private func applyThemeResolver() {
        ThemeResolver.shared.apply(themeId: settings.colorThemeId, appearance: settings.appearance)
    }

    private func setCloudSyncEnabled(_ enabled: Bool, rememberForAccount: Bool) {
        settings.syncEnabled = enabled
        if rememberForAccount, !settings.cloudUserId.isEmpty {
            LocalStore.saveCloudSyncPreference(enabled, for: settings.cloudUserId)
            LocalStore.markCloudSyncPreferenceMigratedToAccount(for: settings.cloudUserId)
            syncCloudSyncPreferenceToAccount(enabled)
        }
        persist()
    }

    private func applyCloudAccount(
        _ account: AuthUserDTO,
        shouldApplyCloudSyncPreference: Bool = true,
        allowsPendingCloudSyncDecision: Bool = true
    ) {
        settings.displayName = sanitizedDisplayName(account.displayName)
        settings.cloudUserId = account.userId
        SummaryPlaybackQuotaStore().syncLocalUsageAfterLogin(userId: account.userId)
        if let memberTier = account.memberTier {
            settings.memberTier = memberTier
        }
        settings.memberExpiresAt = account.memberExpiresAt
        enforceCurrentThemeAccess(showsMessage: true)
        if shouldApplyCloudSyncPreference {
            applyAccountCloudSyncPreference(
                account.cloudSyncEnabled,
                allowsPendingCloudSyncDecision: allowsPendingCloudSyncDecision
            )
        }
        persist()
    }

    private func applyAccountCloudSyncPreference(
        _ remoteEnabled: Bool?,
        allowsPendingCloudSyncDecision: Bool
    ) {
        if let remoteEnabled, !settings.cloudUserId.isEmpty {
            if !remoteEnabled,
               settings.syncEnabled,
               !LocalStore.hasMigratedCloudSyncPreferenceToAccount(for: settings.cloudUserId) {
                LocalStore.saveCloudSyncPreference(true, for: settings.cloudUserId)
                LocalStore.markCloudSyncPreferenceMigratedToAccount(for: settings.cloudUserId)
                syncCloudSyncPreferenceToAccount(true)
                return
            }
            LocalStore.markCloudSyncPreferenceMigratedToAccount(for: settings.cloudUserId)
        }
        let enabled = remoteEnabled ?? LocalStore.loadCloudSyncPreference(for: settings.cloudUserId)
        if enabled {
            if !settings.cloudUserId.isEmpty {
                LocalStore.saveCloudSyncPreference(true, for: settings.cloudUserId)
            }
            if !settings.syncEnabled, allowsPendingCloudSyncDecision {
                hasPendingLoginCloudSyncDecision = true
            }
            return
        }
        settings.syncEnabled = false
        hasPendingLoginCloudSyncDecision = false
        if !settings.cloudUserId.isEmpty {
            LocalStore.saveCloudSyncPreference(false, for: settings.cloudUserId)
        }
    }

    private func syncCloudSyncPreferenceToAccount(_ enabled: Bool) {
        let token = KeychainService.loadAccessToken()
        guard !token.isEmpty else { return }
        let client = AuthService(baseURL: backendBaseURL)
        Task {
            do {
                let account = try await client.updateCloudSyncEnabled(accessToken: token, enabled: enabled)
                applyCloudAccount(
                    account,
                    shouldApplyCloudSyncPreference: false,
                    allowsPendingCloudSyncDecision: false
                )
            } catch {
                if invalidateCloudSessionIfUnauthorized(error) { return }
                authMessage = enabled
                    ? "账单字段云端备份已在本机开启，账号开关稍后会再同步；照片不会上传。"
                    : "账单字段云端备份已在本机关闭，账号开关稍后会再同步。"
            }
        }
    }

    private func syncDisplayNameToCloud(_ displayName: String) async {
        let token = KeychainService.loadAccessToken()
        guard !token.isEmpty else { return }
        let client = AuthService(baseURL: backendBaseURL)
        do {
            let account = try await client.updateDisplayName(accessToken: token, displayName: displayName)
            applyCloudAccount(account, shouldApplyCloudSyncPreference: false)
            authMessage = "昵称已同步。"
        } catch {
            if invalidateCloudSessionIfUnauthorized(error) { return }
            authMessage = "昵称已保存在本机。云端暂时没同步成功，稍后会再试。"
        }
    }

    @discardableResult
    private func invalidateCloudSessionIfUnauthorized(_ error: Error) -> Bool {
        guard CloudSessionFailurePolicy.shouldInvalidateSession(for: error) else {
            return false
        }
        CloudSessionInvalidationService.invalidate()
        applyExpiredCloudSessionState()
        return true
    }

    private func applyExpiredCloudSessionState() {
        settings = LocalStore.loadSettings()
        hasCloudSession = false
        hasPendingLoginCloudSyncDecision = false
        if Self.isBackendDefaultDisplayName(settings.displayName) {
            settings.displayName = Self.localDefaultDisplayName
        }
        settings.displayName = sanitizedDisplayName(settings.displayName)
        settings.petNickname = sanitizedPetNickname(settings.petNickname)
        enforceCurrentThemeAccess(showsMessage: true)
        authMessage = CloudSessionInvalidationService.userMessage
        persist()
        notifyNarrativeAIConfigurationChanged()
    }

    private func notifyNarrativeAIConfigurationChanged() {
        LifeNarrativeAIRewriteStore.shared.removeAll()
        NotificationCenter.default.post(name: .narrativeAIConfigurationDidChange, object: nil)
    }

    private func hasActiveLocalEntitlement(_ payload: IAPPurchaseVerification, now: Date = Date()) -> Bool {
        switch payload.tier {
        case .lifetime:
            return true
        case .monthly, .yearly:
            guard let expirationDate = payload.expirationDate else { return true }
            return expirationDate > now
        }
    }

    private func bestLocalEntitlement(from payloads: [IAPPurchaseVerification]) -> IAPPurchaseVerification? {
        payloads.sorted { lhs, rhs in
            entitlementRank(lhs) > entitlementRank(rhs)
        }
        .first
    }

    private func entitlementRank(_ payload: IAPPurchaseVerification) -> Int {
        let tierWeight: Int
        switch payload.tier {
        case .lifetime: tierWeight = 3_000_000_000
        case .yearly: tierWeight = 2_000_000_000
        case .monthly: tierWeight = 1_000_000_000
        }
        let expiry = Int(payload.expirationDate?.timeIntervalSince1970 ?? 0)
        return tierWeight + expiry
    }

    private func startSMSCooldown(_ seconds: Int) {
        smsCooldownTask?.cancel()
        smsCooldownRemaining = max(0, seconds)
        guard smsCooldownRemaining > 0 else { return }
        smsCooldownTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    guard let self, self.smsCooldownRemaining > 0 else { return }
                    self.smsCooldownRemaining -= 1
                    if self.smsCooldownRemaining == 0 {
                        self.smsCooldownTask?.cancel()
                        self.smsCooldownTask = nil
                    }
                }
            }
        }
    }

    private func stopSMSCooldown() {
        smsCooldownTask?.cancel()
        smsCooldownTask = nil
        smsCooldownRemaining = 0
    }

    private struct SMSAPIErrorBody: Decodable {
        let error: String?
        let retryAfterSec: Int?
    }

    private func parsedSMSAPIError(_ body: String) -> SMSAPIErrorBody? {
        guard let data = body.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(SMSAPIErrorBody.self, from: data)
    }

    private func sendSMSMessage(for error: Error) -> String {
        guard let serviceError = error as? AuthServiceError,
              case AuthServiceError.badStatus(let code, let body) = serviceError else {
            return "验证码暂时没发出去，请检查手机号或稍后再试。"
        }
        guard code == 429 else {
            return "验证码暂时没发出去，请检查手机号或稍后再试。"
        }
        let payload = parsedSMSAPIError(body)
        let retryAfter = max(1, payload?.retryAfterSec ?? 60)
        startSMSCooldown(retryAfter)
        switch payload?.error {
        case "SMS_RATE_LIMIT":
            return "发送次数已达上限，请 \(retryAfter) 秒后再试。"
        case "SMS_COOLDOWN":
            return "发送太频繁，请 \(retryAfter) 秒后再试。"
        default:
            return "验证码发送太频繁，请 \(retryAfter) 秒后再试。"
        }
    }

    private func verifySMSMessage(for error: Error) -> String {
        guard let serviceError = error as? AuthServiceError,
              case AuthServiceError.badStatus(let code, let body) = serviceError else {
            return "登录没有成功，请检查手机号和验证码后再试。"
        }
        if code == 429 {
            let retryAfter = max(1, parsedSMSAPIError(body)?.retryAfterSec ?? 60)
            return "验证太频繁，请 \(retryAfter) 秒后再试。"
        }
        return "登录没有成功，请检查手机号和验证码后再试。"
    }

    private func sanitizedDisplayName(_ value: String) -> String {
        let result = UserContentRiskService.shared.validateDisplayName(value, fallback: Self.localDefaultDisplayName)
        return result.isAllowed ? result.value : Self.localDefaultDisplayName
    }

    private func sanitizedPetNickname(_ value: String) -> String {
        let result = UserContentRiskService.shared.validatePetNickname(value)
        return result.isAllowed ? result.value : ""
    }

    private static let localDefaultDisplayName = "叙账用户"

    private static func isBackendDefaultDisplayName(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let compact = trimmed.replacingOccurrences(of: " ", with: "")
        guard compact.hasPrefix("用户") else { return false }
        let suffix = compact.dropFirst(2)
        return !suffix.isEmpty && suffix.allSatisfy(\.isNumber)
    }
}
