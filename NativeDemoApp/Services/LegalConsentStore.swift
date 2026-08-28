import Foundation

enum LoginLegalPolicy {
    static let termsVersion = "1.0"
    static let privacyVersion = "1.0"
    static let termsURL = URL(string: "https://xuzhangapp.com/legal/terms.html")!
    static let privacyURL = URL(string: "https://xuzhangapp.com/legal/privacy.html")!
}

struct LoginPolicyConsentRecord: Codable, Equatable {
    let termsVersion: String
    let privacyVersion: String
    let acceptedAt: Date
}

final class LegalConsentStore {
    private enum Keys {
        static let loginPolicyConsent = "login_policy_consent_v1"
    }

    private let defaults: UserDefaults
    private let termsVersion: String
    private let privacyVersion: String

    init(
        defaults: UserDefaults = .standard,
        termsVersion: String = LoginLegalPolicy.termsVersion,
        privacyVersion: String = LoginLegalPolicy.privacyVersion
    ) {
        self.defaults = defaults
        self.termsVersion = termsVersion
        self.privacyVersion = privacyVersion
    }

    var currentRecord: LoginPolicyConsentRecord? {
        guard let data = defaults.data(forKey: Keys.loginPolicyConsent) else { return nil }
        return try? JSONDecoder().decode(LoginPolicyConsentRecord.self, from: data)
    }

    var hasAcceptedCurrentPolicies: Bool {
        guard let record = currentRecord else { return false }
        return record.termsVersion == termsVersion
            && record.privacyVersion == privacyVersion
    }

    @discardableResult
    func acceptCurrentPolicies(now: Date = Date()) -> LoginPolicyConsentRecord? {
        let record = LoginPolicyConsentRecord(
            termsVersion: termsVersion,
            privacyVersion: privacyVersion,
            acceptedAt: now
        )
        guard let data = try? JSONEncoder().encode(record) else { return nil }
        defaults.set(data, forKey: Keys.loginPolicyConsent)
        return hasAcceptedCurrentPolicies ? record : nil
    }

    func revokeCurrentPolicies() {
        defaults.removeObject(forKey: Keys.loginPolicyConsent)
    }
}
