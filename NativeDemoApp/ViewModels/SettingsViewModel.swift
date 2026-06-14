import Foundation
import SwiftUI
import Combine

enum SettingsViewModelError: LocalizedError {
    case loginRequired

    var errorDescription: String? {
        switch self {
        case .loginRequired:
            return "请先登录账号，再开通或恢复会员。"
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
    @Published private(set) var isAuthBusy: Bool = false
    @Published private(set) var smsCooldownRemaining: Int = 0
    /// 是否已保存访问令牌（与 Keychain 同步，用于界面展示）。
    @Published private(set) var hasCloudSession: Bool = false
    private var smsCooldownTask: Task<Void, Never>?

    init() {
        settings = LocalStore.loadSettings()
        hasCloudSession = !KeychainService.loadAccessToken().isEmpty
        if !hasCloudSession && Self.isBackendDefaultDisplayName(settings.displayName) {
            settings.displayName = Self.localDefaultDisplayName
        }
        settings.displayName = sanitizedDisplayName(settings.displayName)
        settings.petNickname = sanitizedPetNickname(settings.petNickname)
        persist()
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
            settings.syncEnabled = newValue
            persist()
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
            settings.aiTone = newValue
            persist()
        }
    }

    var useRemoteAI: Bool {
        get { settings.useRemoteAI }
        set {
            settings.useRemoteAI = newValue
            persist()
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
            persist()
        }
    }

    var colorScheme: ColorScheme? {
        settings.colorScheme
    }

    func sendSMSLoginCode() async {
        authMessage = nil
        guard !isAuthBusy else { return }
        if smsCooldownRemaining > 0 {
            authMessage = "请 \(smsCooldownRemaining) 秒后再试。"
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
            persist()
            if let account = try? await client.fetchAccountMe(accessToken: session.accessToken) {
                applyCloudAccount(account)
            }
            let tier = try await client.fetchMemberMe(accessToken: session.accessToken)
            settings.memberTier = tier.tier
            settings.memberExpiresAt = tier.expiresAt
            persist()
            hasCloudSession = true
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
        if Self.isBackendDefaultDisplayName(settings.displayName) {
            settings.displayName = Self.localDefaultDisplayName
        }
        hasCloudSession = false
        authMessage = "已退出登录。"
        persist()
    }

    func deleteCloudLedger() async {
        authMessage = nil
        let token = KeychainService.loadAccessToken()
        guard !token.isEmpty else {
            authMessage = "请先登录账号。"
            return
        }
        isAuthBusy = true
        defer { isAuthBusy = false }
        let client = AuthService(baseURL: backendBaseURL)
        do {
            try await client.deleteCloudLedger(accessToken: token)
            settings.syncEnabled = false
            persist()
            authMessage = "云端账本已删除，本机记录仍保留。"
        } catch {
            authMessage = error.localizedDescription
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
        do {
            try await client.deleteAccount(accessToken: token)
            KeychainService.clearAccessToken()
            settings.cloudUserId = ""
            settings.memberTier = "free"
            settings.memberExpiresAt = nil
            settings.syncEnabled = false
            if Self.isBackendDefaultDisplayName(settings.displayName) {
                settings.displayName = Self.localDefaultDisplayName
            }
            hasCloudSession = false
            authMessage = "账号已注销，服务器数据和会员绑定状态已清空。"
            persist()
            return true
        } catch {
            authMessage = error.localizedDescription
            return false
        }
    }

    func verifyIAPPurchase(_ payload: IAPPurchaseVerification) async throws {
        let token = KeychainService.loadAccessToken()
        guard !token.isEmpty else {
            authMessage = "请先登录账号，再开通会员。"
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
        applyVerifiedMemberState(tier: verified.tier, expiresAt: verified.expiresAt, fallbackPayload: payload)
        do {
            let tier = try await client.fetchMemberMe(accessToken: token)
            let verifiedHasAccess = AppSettings.hasMemberAccess(tier: verified.tier, expiresAt: verified.expiresAt)
            let fetchedHasAccess = AppSettings.hasMemberAccess(tier: tier.tier, expiresAt: tier.expiresAt)
            let localHasAccess = hasActiveLocalEntitlement(payload)
            if (verifiedHasAccess || localHasAccess) && !fetchedHasAccess {
                authMessage = "会员已恢复，状态刷新稍后会再同步。"
            } else {
                settings.memberTier = tier.tier
                settings.memberExpiresAt = tier.expiresAt
                persist()
                authMessage = "会员状态已更新。"
            }
        } catch {
            authMessage = "会员已恢复，状态刷新稍后会再同步。"
        }
    }

    func refreshMemberFromLocalEntitlements(synchronize: Bool = false) async {
        do {
            let payloads = try await IAPService.shared.currentEntitlements(synchronize: synchronize)
            guard let payload = bestLocalEntitlement(from: payloads),
                  hasActiveLocalEntitlement(payload) else { return }
            let currentHasAccess = settings.hasMemberAccess
            applyLocalEntitlement(payload)
            if !currentHasAccess {
                authMessage = "已检测到 App Store 会员权益，状态已恢复。"
            }
        } catch {
            if synchronize {
                authMessage = error.localizedDescription
            }
        }
    }

    func refreshCloudAccountProfile() async {
        let token = KeychainService.loadAccessToken()
        guard !token.isEmpty else { return }
        let client = AuthService(baseURL: backendBaseURL)
        do {
            let account = try await client.fetchAccountMe(accessToken: token)
            applyCloudAccount(account)
        } catch {
            authMessage = error.localizedDescription
        }
    }

    private func persist() {
        LocalStore.saveSettings(settings)
    }

    private func applyCloudAccount(_ account: AuthUserDTO) {
        settings.displayName = sanitizedDisplayName(account.displayName)
        settings.cloudUserId = account.userId
        if let memberTier = account.memberTier {
            settings.memberTier = memberTier
        }
        settings.memberExpiresAt = account.memberExpiresAt
        persist()
    }

    private func syncDisplayNameToCloud(_ displayName: String) async {
        let token = KeychainService.loadAccessToken()
        guard !token.isEmpty else { return }
        let client = AuthService(baseURL: backendBaseURL)
        do {
            let account = try await client.updateDisplayName(accessToken: token, displayName: displayName)
            applyCloudAccount(account)
            authMessage = "昵称已同步。"
        } catch {
            authMessage = "昵称已保存在本机，云端同步失败：\(error.localizedDescription)"
        }
    }

    private func applyVerifiedMemberState(
        tier: String,
        expiresAt: String?,
        fallbackPayload: IAPPurchaseVerification
    ) {
        let verifiedHasAccess = AppSettings.hasMemberAccess(tier: tier, expiresAt: expiresAt)
        if verifiedHasAccess || !hasActiveLocalEntitlement(fallbackPayload) {
            settings.memberTier = tier
            settings.memberExpiresAt = expiresAt
        } else {
            applyLocalEntitlement(fallbackPayload, shouldPersist: false)
        }
        persist()
    }

    private func applyLocalEntitlement(_ payload: IAPPurchaseVerification, shouldPersist: Bool = true) {
        settings.memberTier = payload.tier.rawValue
        switch payload.tier {
        case .lifetime:
            settings.memberExpiresAt = nil
        case .monthly, .yearly:
            settings.memberExpiresAt = payload.expirationDate.map { AppSettings.isoString(from: $0) }
        }
        if shouldPersist {
            persist()
        }
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
            return "验证码发送失败，请稍后再试。"
        }
        guard code == 429 else {
            return "验证码发送失败，请稍后再试。"
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
            return "请 \(retryAfter) 秒后再试。"
        }
    }

    private func verifySMSMessage(for error: Error) -> String {
        guard let serviceError = error as? AuthServiceError,
              case AuthServiceError.badStatus(let code, let body) = serviceError else {
            return "登录失败，请检查验证码后再试。"
        }
        if code == 429 {
            let retryAfter = max(1, parsedSMSAPIError(body)?.retryAfterSec ?? 60)
            return "验证太频繁，请 \(retryAfter) 秒后再试。"
        }
        return "登录失败，请检查手机号和验证码。"
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
