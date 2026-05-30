import Foundation
import SwiftUI

struct AppSettings: Codable, Equatable {
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
    var aiTone: AITone
    var useRemoteAI: Bool
    var aiEndpoint: String
    var aiModel: String
    var remoteAIMonthlyLimit: Int
    /// 序帐后端根地址，例如 `http://127.0.0.1:8790`（模拟器连本机）或局域网 IP。
    var backendBaseURL: String
    /// 云端用户 ID，登录成功后由后端返回；未登录为空。
    var cloudUserId: String
    /// 会员档位：free / monthly / yearly / lifetime（与后端一致）。
    var memberTier: String

    static let `default` = AppSettings(
        displayName: "序帐用户",
        notificationsEnabled: true,
        appearance: .system,
        biometricLockEnabled: false,
        syncEnabled: false,
        aiTone: .gentle,
        useRemoteAI: false,
        aiEndpoint: "",
        aiModel: "doubao-seed-1-6-flash-250828",
        remoteAIMonthlyLimit: 120,
        backendBaseURL: "http://127.0.0.1:8790",
        cloudUserId: "",
        memberTier: "free"
    )
}

extension AppSettings {
    enum CodingKeys: String, CodingKey {
        case displayName
        case notificationsEnabled
        case appearance
        case biometricLockEnabled
        case syncEnabled
        case aiTone
        case useRemoteAI
        case aiEndpoint
        case aiModel
        case remoteAIMonthlyLimit
        case backendBaseURL
        case cloudUserId
        case memberTier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? "序帐用户"
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        appearance = try container.decodeIfPresent(Appearance.self, forKey: .appearance) ?? .system
        biometricLockEnabled = try container.decodeIfPresent(Bool.self, forKey: .biometricLockEnabled) ?? false
        syncEnabled = try container.decodeIfPresent(Bool.self, forKey: .syncEnabled) ?? false
        aiTone = try container.decodeIfPresent(AITone.self, forKey: .aiTone) ?? .gentle
        useRemoteAI = try container.decodeIfPresent(Bool.self, forKey: .useRemoteAI) ?? false
        aiEndpoint = try container.decodeIfPresent(String.self, forKey: .aiEndpoint) ?? ""
        aiModel = try container.decodeIfPresent(String.self, forKey: .aiModel) ?? "doubao-seed-1-6-flash-250828"
        remoteAIMonthlyLimit = try container.decodeIfPresent(Int.self, forKey: .remoteAIMonthlyLimit) ?? 120
        backendBaseURL = try container.decodeIfPresent(String.self, forKey: .backendBaseURL) ?? "http://127.0.0.1:8790"
        cloudUserId = try container.decodeIfPresent(String.self, forKey: .cloudUserId) ?? ""
        memberTier = try container.decodeIfPresent(String.self, forKey: .memberTier) ?? "free"
    }
}

extension AppSettings {
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
