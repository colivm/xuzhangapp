import Foundation

struct AuthUserDTO: Codable, Equatable {
    let userId: String
    let displayName: String
    let memberTier: String?
    let memberExpiresAt: String?
}

struct UserSession: Codable, Equatable {
    let userId: String
    let displayName: String
    let accessToken: String
    let refreshToken: String?
    let loginType: LoginType
    var memberTier: String
    var memberExpiresAt: String?
}

enum LoginType: String, Codable {
    case wechat
    case phone
}

enum AuthServiceError: LocalizedError {
    case invalidURL
    case badStatus(Int, String)
    case decodeFailed
    case unsupported

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "后端服务地址配置异常。"
        case .badStatus(let code, let body):
            return "请求失败 (\(code))：\(body)"
        case .decodeFailed:
            return "服务器返回格式异常。"
        case .unsupported:
            return "该登录方式尚未接入。"
        }
    }
}

private struct SendSMSBody: Encodable {
    let phone: String
}

private struct VerifySMSBody: Encodable {
    let phone: String
    let code: String
}

private struct SMSVerifyResponse: Decodable {
    let ok: Bool
    let user: AuthUserDTO?
    let accessToken: String?
    let error: String?
}

private struct MemberMeResponse: Decodable {
    let ok: Bool
    let memberTier: String?
    let memberExpiresAt: String?
}

private struct AccountMeResponse: Decodable {
    let ok: Bool
    let user: AuthUserDTO?
}

private struct UpdateAccountBody: Encodable {
    let displayName: String
}

private struct IAPVerifyBody: Encodable {
    let productId: String
    let transactionId: String
    let signedTransactionInfo: String
}

private struct IAPVerifyResponse: Decodable {
    let ok: Bool
    let memberTier: String?
    let memberExpiresAt: String?
}

protocol AuthServiceProtocol {
    func loginWithWeChat(authCode: String) async throws -> UserSession
    func sendSMSCode(phone: String) async throws
    func loginWithSMS(phone: String, code: String) async throws -> UserSession
}

/// 对接 `backend` 服务（见仓库 `backend/README.md`）。
final class AuthService: AuthServiceProtocol {
    private let baseURL: String
    private let urlSession: URLSession

    init(baseURL: String, urlSession: URLSession = .shared) {
        self.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.urlSession = urlSession
    }

    func loginWithWeChat(authCode: String) async throws -> UserSession {
        _ = authCode
        throw AuthServiceError.unsupported
    }

    func sendSMSCode(phone: String) async throws {
        let url = try makeURL(path: "/v1/auth/sms/send")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(SendSMSBody(phone: phone))
        let (_, response, bodyText) = try await data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AuthServiceError.badStatus(-1, "") }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw AuthServiceError.badStatus(http.statusCode, bodyText)
        }
    }

    func loginWithSMS(phone: String, code: String) async throws -> UserSession {
        let url = try makeURL(path: "/v1/auth/sms/verify")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(VerifySMSBody(phone: phone, code: code))
        let (data, response, bodyText) = try await data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AuthServiceError.badStatus(-1, "") }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw AuthServiceError.badStatus(http.statusCode, bodyText)
        }
        let decoded = try JSONDecoder().decode(SMSVerifyResponse.self, from: data)
        guard decoded.ok, let user = decoded.user, let token = decoded.accessToken, !token.isEmpty else {
            throw AuthServiceError.decodeFailed
        }
        return UserSession(
            userId: user.userId,
            displayName: user.displayName,
            accessToken: token,
            refreshToken: nil,
            loginType: .phone,
            memberTier: user.memberTier ?? "free",
            memberExpiresAt: user.memberExpiresAt
        )
    }

    /// 拉取当前会员状态（需已登录，请求头带 Bearer）。
    func fetchMemberMe(accessToken: String) async throws -> (tier: String, expiresAt: String?) {
        let url = try makeURL(path: "/v1/member/me")
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response, bodyText) = try await data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AuthServiceError.badStatus(-1, "") }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw AuthServiceError.badStatus(http.statusCode, bodyText)
        }
        let decoded = try JSONDecoder().decode(MemberMeResponse.self, from: data)
        guard decoded.ok else { throw AuthServiceError.decodeFailed }
        return (decoded.memberTier ?? "free", decoded.memberExpiresAt)
    }

    func fetchAccountMe(accessToken: String) async throws -> AuthUserDTO {
        let url = try makeURL(path: "/v1/account/me")
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response, bodyText) = try await data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AuthServiceError.badStatus(-1, "") }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw AuthServiceError.badStatus(http.statusCode, bodyText)
        }
        let decoded = try JSONDecoder().decode(AccountMeResponse.self, from: data)
        guard decoded.ok, let user = decoded.user else { throw AuthServiceError.decodeFailed }
        return user
    }

    func updateDisplayName(accessToken: String, displayName: String) async throws -> AuthUserDTO {
        let url = try makeURL(path: "/v1/account/me")
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(UpdateAccountBody(displayName: displayName))
        let (data, response, bodyText) = try await data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AuthServiceError.badStatus(-1, "") }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw AuthServiceError.badStatus(http.statusCode, bodyText)
        }
        let decoded = try JSONDecoder().decode(AccountMeResponse.self, from: data)
        guard decoded.ok, let user = decoded.user else { throw AuthServiceError.decodeFailed }
        return user
    }

    func verifyIAPPurchase(
        accessToken: String,
        productId: String,
        transactionId: String,
        signedTransactionInfo: String
    ) async throws -> (tier: String, expiresAt: String?) {
        let url = try makeURL(path: "/v1/iap/verify")
        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(IAPVerifyBody(
            productId: productId,
            transactionId: transactionId,
            signedTransactionInfo: signedTransactionInfo
        ))
        let (data, response, bodyText) = try await data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AuthServiceError.badStatus(-1, "") }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw AuthServiceError.badStatus(http.statusCode, bodyText)
        }
        let decoded = try JSONDecoder().decode(IAPVerifyResponse.self, from: data)
        guard decoded.ok else { throw AuthServiceError.decodeFailed }
        return (decoded.memberTier ?? "free", decoded.memberExpiresAt)
    }

    func deleteCloudLedger(accessToken: String) async throws {
        try await deleteAuthorized(path: "/v1/ledger", accessToken: accessToken)
    }

    func deleteAccount(accessToken: String) async throws {
        try await deleteAuthorized(path: "/v1/account", accessToken: accessToken)
    }

    private func makeURL(path: String) throws -> URL {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed + path) else { throw AuthServiceError.invalidURL }
        return url
    }

    private func deleteAuthorized(path: String, accessToken: String) async throws {
        let url = try makeURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (_, response, bodyText) = try await data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AuthServiceError.badStatus(-1, "") }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw AuthServiceError.badStatus(http.statusCode, bodyText)
        }
    }

    private func data(for request: URLRequest) async throws -> (Data, URLResponse, String) {
        let (data, response) = try await urlSession.data(for: request)
        let text = String(data: data, encoding: .utf8) ?? ""
        return (data, response, text)
    }
}
