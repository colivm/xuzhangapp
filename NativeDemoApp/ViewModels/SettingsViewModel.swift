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
    /// 是否已保存访问令牌（与 Keychain 同步，用于界面展示）。
    @Published private(set) var hasCloudSession: Bool = false

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
            persist()
        }
    }

    var colorScheme: ColorScheme? {
        settings.colorScheme
    }

    func sendSMSLoginCode() async {
        authMessage = nil
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
        } catch {
            authMessage = error.localizedDescription
        }
    }

    func verifySMSLogin() async {
        authMessage = nil
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
            persist()
            let tier = try await client.fetchMemberMe(accessToken: session.accessToken)
            settings.memberTier = tier.tier
            persist()
            hasCloudSession = true
            authMessage = "登录成功。"
            loginCode = ""
        } catch {
            authMessage = error.localizedDescription
        }
    }

    func logoutCloud() {
        KeychainService.clearAccessToken()
        settings.cloudUserId = ""
        settings.memberTier = "free"
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

    func deleteCloudAccount() async {
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
            try await client.deleteAccount(accessToken: token)
            KeychainService.clearAccessToken()
            settings.cloudUserId = ""
            settings.memberTier = "free"
            settings.syncEnabled = false
            if Self.isBackendDefaultDisplayName(settings.displayName) {
                settings.displayName = Self.localDefaultDisplayName
            }
            hasCloudSession = false
            authMessage = "账号已注销，云端数据已删除。"
            persist()
        } catch {
            authMessage = error.localizedDescription
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
        _ = try await client.verifyIAPPurchase(
            accessToken: token,
            productId: payload.productId,
            transactionId: payload.transactionId,
            signedTransactionInfo: payload.signedTransactionInfo
        )
        let tier = try await client.fetchMemberMe(accessToken: token)
        settings.memberTier = tier.tier
        persist()
        authMessage = "会员状态已更新。"
    }

    private func persist() {
        LocalStore.saveSettings(settings)
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
        guard trimmed.hasPrefix("用户 ") else { return false }
        return trimmed.dropFirst(3).allSatisfy(\.isNumber)
    }
}
