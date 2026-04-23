import Foundation
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var settings: AppSettings

    init() {
        settings = LocalStore.loadSettings()
    }

    var displayName: String {
        get { settings.displayName }
        set {
            settings.displayName = newValue
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
            settings.aiEndpoint = newValue
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

    var colorScheme: ColorScheme? {
        settings.colorScheme
    }

    private func persist() {
        LocalStore.saveSettings(settings)
    }
}
