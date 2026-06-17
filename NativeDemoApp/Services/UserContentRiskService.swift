import Foundation

struct UserContentValidationResult: Equatable {
    let isAllowed: Bool
    let value: String
    let message: String?
}

final class UserContentRiskService {
    static let shared = UserContentRiskService()

    private let sensitiveWords = [
        "傻逼", "操你", "约炮", "裸聊", "色情", "赌博", "毒品", "自杀", "杀人", "恐怖袭击"
    ]

    private let privacyKeywords = [
        "密码", "口令", "验证码", "身份证", "银行卡", "卡号", "手机号", "电话", "token", "api key", "apikey"
    ]

    private let privacyPatterns = [
        #"https?://|www\.|[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
        #"(?<!\d)1[3-9]\d{9}(?!\d)"#,
        #"(?<!\d)\d{6}(18|19|20)\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])\d{3}[0-9Xx](?!\d)"#,
        #"(?<!\d)(?:\d[ -]?){12,19}(?!\d)"#
    ]

    private init() {}

    func normalizeUserText(_ value: String, maxLength: Int) -> String {
        let collapsed = value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(collapsed.prefix(maxLength))
    }

    func normalizedManualNote(_ value: String) -> String {
        normalizeUserText(value, maxLength: 32)
    }

    func validateDisplayName(_ value: String, fallback: String = "叙账用户") -> UserContentValidationResult {
        let normalized = normalizeUserText(value, maxLength: 12)
        let next = normalized.isEmpty ? fallback : normalized
        if let reason = riskReason(for: next) {
            return .init(isAllowed: false, value: fallback, message: "昵称里有\(reason)，换个简单称呼就好。")
        }
        return .init(isAllowed: true, value: next, message: nil)
    }

    func validatePetNickname(_ value: String) -> UserContentValidationResult {
        let normalized = normalizeUserText(value, maxLength: 6)
        guard !normalized.isEmpty else {
            return .init(isAllowed: true, value: "", message: nil)
        }
        if let reason = riskReason(for: normalized) {
            return .init(isAllowed: false, value: "", message: "宠物昵称里有\(reason)，换个短一点的称呼吧。")
        }
        return .init(isAllowed: true, value: normalized, message: nil)
    }

    func validateManualNote(_ value: String, allowEmpty: Bool = true) -> UserContentValidationResult {
        let normalized = normalizedManualNote(value)
        if normalized.isEmpty {
            return .init(
                isAllowed: allowEmpty,
                value: "",
                message: allowEmpty ? nil : "备注还没填，补一句再保存。"
            )
        }
        if let reason = riskReason(for: normalized) {
            return .init(isAllowed: false, value: normalized, message: "这句备注可能包含敏感信息，请删掉隐私内容后再保存。")
        }
        return .init(isAllowed: true, value: normalized, message: nil)
    }

    func isAllowedManualNote(_ value: String, allowEmpty: Bool = true) -> Bool {
        validateManualNote(value, allowEmpty: allowEmpty).isAllowed
    }

    private func riskReason(for text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if privacyPatterns.contains(where: { matches($0, in: trimmed) }) {
            return "手机号、证件号、卡号或链接"
        }
        let compact = trimmed.filter { !$0.isWhitespace }.lowercased()
        if sensitiveWords.contains(where: { compact.contains($0.lowercased()) }) {
            return "不适合展示的词"
        }
        if trimmed.rangeOfCharacter(from: .decimalDigits) != nil,
           privacyKeywords.contains(where: { compact.contains($0.replacingOccurrences(of: " ", with: "").lowercased()) }) {
            return "隐私信息"
        }
        return nil
    }

    private func matches(_ pattern: String, in text: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
