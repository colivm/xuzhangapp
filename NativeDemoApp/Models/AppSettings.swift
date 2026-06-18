import Foundation
import SwiftUI

struct AppSettings: Codable, Equatable {
    static let productionBackendBaseURL = "https://api.xuzhangapp.com"
    static let productionAIEndpoint = "https://api.xuzhangapp.com/v1/ai/insight/daily"
    static let defaultColorThemeId = "xuzhang_default"

    enum Appearance: String, Codable, CaseIterable, Identifiable {
        case system
        case light
        case dark

        var id: String { rawValue }

        var title: String {
            switch self {
            case .system:
                return "跟随系统"
            case .light:
                return "浅色"
            case .dark:
                return "深色"
            }
        }
    }

    enum AITone: String, Codable, CaseIterable, Identifiable {
        case gentle
        case neutral

        var id: String { rawValue }

        var title: String {
            switch self {
            case .gentle:
                return "温和"
            case .neutral:
                return "中性"
            }
        }
    }

    var displayName: String
    var notificationsEnabled: Bool
    var appearance: Appearance
    var biometricLockEnabled: Bool
    var syncEnabled: Bool
    var petCompanionEnabled: Bool
    var petNickname: String
    var weatherCompanionEnabled: Bool
    var aiTone: AITone
    var useRemoteAI: Bool
    var aiEndpoint: String
    var aiModel: String
    var remoteAIMonthlyLimit: Int
    /// 叙账后端根地址。生产环境固定走 `productionBackendBaseURL`。
    var backendBaseURL: String
    /// 云端用户 ID，登录成功后由后端返回；未登录为空。
    var cloudUserId: String
    /// 会员档位：free / monthly / yearly / lifetime（与后端一致）。
    var memberTier: String
    /// 会员有效期，后端返回的 ISO8601 字符串；永久会员为空。
    var memberExpiresAt: String?
    /// 当前界面色彩主题 ID。
    var colorThemeId: String
    /// 分享图是否跟随 App 当前主题。
    var shareCardUsesAppTheme: Bool

    mutating func applyProductionEndpoints() {
        backendBaseURL = Self.productionBackendBaseURL
        aiEndpoint = Self.productionAIEndpoint
    }

    static let `default` = AppSettings(
        displayName: "叙账用户",
        notificationsEnabled: true,
        appearance: .system,
        biometricLockEnabled: false,
        syncEnabled: false,
        petCompanionEnabled: true,
        petNickname: "",
        weatherCompanionEnabled: true,
        aiTone: .gentle,
        useRemoteAI: false,
        aiEndpoint: productionAIEndpoint,
        aiModel: "doubao-seed-1-6-flash-250828",
        remoteAIMonthlyLimit: 120,
        backendBaseURL: productionBackendBaseURL,
        cloudUserId: "",
        memberTier: "free",
        memberExpiresAt: nil,
        colorThemeId: defaultColorThemeId,
        shareCardUsesAppTheme: false
    )
}

extension AppSettings {
    enum CodingKeys: String, CodingKey {
        case displayName
        case notificationsEnabled
        case appearance
        case biometricLockEnabled
        case syncEnabled
        case petCompanionEnabled
        case petNickname
        case weatherCompanionEnabled
        case aiTone
        case useRemoteAI
        case aiEndpoint
        case aiModel
        case remoteAIMonthlyLimit
        case backendBaseURL
        case cloudUserId
        case memberTier
        case memberExpiresAt
        case colorThemeId
        case shareCardUsesAppTheme
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? "叙账用户"
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        appearance = try container.decodeIfPresent(Appearance.self, forKey: .appearance) ?? .system
        biometricLockEnabled = try container.decodeIfPresent(Bool.self, forKey: .biometricLockEnabled) ?? false
        syncEnabled = try container.decodeIfPresent(Bool.self, forKey: .syncEnabled) ?? false
        petCompanionEnabled = try container.decodeIfPresent(Bool.self, forKey: .petCompanionEnabled) ?? true
        petNickname = try container.decodeIfPresent(String.self, forKey: .petNickname) ?? ""
        weatherCompanionEnabled = try container.decodeIfPresent(Bool.self, forKey: .weatherCompanionEnabled) ?? true
        aiTone = try container.decodeIfPresent(AITone.self, forKey: .aiTone) ?? .gentle
        useRemoteAI = try container.decodeIfPresent(Bool.self, forKey: .useRemoteAI) ?? false
        aiEndpoint = try container.decodeIfPresent(String.self, forKey: .aiEndpoint) ?? Self.productionAIEndpoint
        aiModel = try container.decodeIfPresent(String.self, forKey: .aiModel) ?? "doubao-seed-1-6-flash-250828"
        remoteAIMonthlyLimit = try container.decodeIfPresent(Int.self, forKey: .remoteAIMonthlyLimit) ?? 120
        backendBaseURL = try container.decodeIfPresent(String.self, forKey: .backendBaseURL) ?? Self.productionBackendBaseURL
        cloudUserId = try container.decodeIfPresent(String.self, forKey: .cloudUserId) ?? ""
        memberTier = try container.decodeIfPresent(String.self, forKey: .memberTier) ?? "free"
        memberExpiresAt = try container.decodeIfPresent(String.self, forKey: .memberExpiresAt)
        colorThemeId = try container.decodeIfPresent(String.self, forKey: .colorThemeId) ?? Self.defaultColorThemeId
        shareCardUsesAppTheme = try container.decodeIfPresent(Bool.self, forKey: .shareCardUsesAppTheme) ?? false
        applyProductionEndpoints()
    }
}

extension AppSettings {
    static func hasMemberAccess(tier: String, expiresAt: String? = nil, now: Date = Date()) -> Bool {
        switch tier.lowercased() {
        case "lifetime":
            return true
        case "monthly", "yearly":
            guard let expiresAt, let expiry = parseISODate(expiresAt) else {
                return true
            }
            return expiry > now
        default:
            return false
        }
    }

    var hasMemberAccess: Bool {
        Self.hasMemberAccess(tier: memberTier, expiresAt: memberExpiresAt)
    }

    static func memberTierDisplayName(_ tier: String) -> String {
        switch tier.lowercased() {
        case "monthly": return "月度会员"
        case "yearly": return "年度会员"
        case "lifetime": return "永久会员"
        default: return "免费版"
        }
    }

    var memberValidityText: String? {
        switch memberTier.lowercased() {
        case "lifetime":
            return "永久有效"
        case "monthly", "yearly":
            guard let memberExpiresAt, let date = Self.parseISODate(memberExpiresAt) else {
                return nil
            }
            return "有效期至 \(Self.displayDateFormatter.string(from: date))"
        default:
            return nil
        }
    }

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()

    private static let isoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let fractionalISODateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func parseISODate(_ value: String) -> Date? {
        fractionalISODateFormatter.date(from: value) ?? isoDateFormatter.date(from: value)
    }

    static func isoString(from date: Date) -> String {
        fractionalISODateFormatter.string(from: date)
    }

    var colorScheme: ColorScheme? {
        switch appearance {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
