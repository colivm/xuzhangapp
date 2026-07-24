import Foundation

struct AISnapshot: Codable {
    let date: String
    let todayTotal: Double
    let weekAverage: Double
    let monthTotal: Double
    let topCategories: [String]
}

struct AIInsightPayload: Codable {
    let summary: String
    let action: String
    let encourage: String
}

enum AIReportServiceError: LocalizedError {
    case invalidEndpoint
    case authenticationRequired
    case badStatus(Int, String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "远程服务地址异常，将使用本地规则。"
        case .authenticationRequired:
            return "登录后才能使用联网整理，已使用本地规则。"
        case .badStatus(let code, let body):
            if body.contains("AI_INPUT_REJECTED") || body.contains("BANK_CARD") {
                return "远程模型触发内容保护，将使用本地规则。"
            }
            return "远程模型请求失败（\(code)），将使用本地规则。"
        case .invalidResponse:
            return "远程模型返回格式异常，将使用本地规则。"
        }
    }
}

final class AIReportService: @unchecked Sendable {
    func generateCoverDirectorDecision(
        request directorRequest: CoverAIDirectorRequest
    ) async throws -> CoverAIDirectorResponse {
        let encodedRequest = try JSONEncoder().encode(directorRequest)
        let directorPayload = try JSONSerialization.jsonObject(with: encodedRequest)

        var request = try authenticatedRequest(timeoutInterval: 10)
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "feature": "cover_director",
            "directorRequest": directorPayload,
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIReportServiceError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw AIReportServiceError.badStatus(http.statusCode, String(bodyText.prefix(300)))
        }
        return try CoverAIDirectorResponse.decodeStrict(from: data)
    }

    func generateNarrativeRewrites(
        factPacks: [LifeNarrativeAIFactPackRequest],
        tone: AppSettings.AITone
    ) async throws -> LifeNarrativeAIRewriteBatchResponse {
        guard !factPacks.isEmpty else { return LifeNarrativeAIRewriteBatchResponse(rewrites: []) }
        let encodedPacks = try JSONEncoder().encode(factPacks)
        let factPackPayload = try JSONSerialization.jsonObject(with: encodedPacks)

        var request = try authenticatedRequest(timeoutInterval: 30)
        let body: [String: Any] = [
            "feature": "narrative_rewrite_batch",
            "factPacks": factPackPayload,
            "tone": tone.rawValue
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIReportServiceError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw AIReportServiceError.badStatus(http.statusCode, String(bodyText.prefix(300)))
        }
        if let decoded = try? JSONDecoder().decode(LifeNarrativeAIRewriteBatchResponse.self, from: data) {
            return decoded
        }
        throw AIReportServiceError.invalidResponse
    }

    func generateInsight(
        snapshot: AISnapshot,
        tone: AppSettings.AITone,
        feature: String = "daily"
    ) async throws -> AIInsightPayload {
        var request = try authenticatedRequest(timeoutInterval: 45)

        let systemContent = """
        你是“叙账”的生活记录整理助手。
        根据用户消费快照输出 JSON，字段必须是 summary/action/encourage。
        只谈已经发生的生活记录：可复述时间范围、分类和大致金额区间，不替用户解释情绪。
        可以有一点理解和鼓励，但必须贴着真实记录说；像“这一周已经留下几笔可以回看的记录”，不要写成泛泛安慰、心理分析或夸奖。
        禁止：下月/下周金额目标、预算上限、减少支出比例、达成率、任何管控式省钱建议。
        action 字段应像账本页脚的一句自然收束或轻鼓励，不是理财计划，也不是空泛安慰话术。
        不要输出投资建议，不要说教。
        不要输出任何具体联系方式、隐私编号、账号信息或链接。
        """

        let userContent = """
        语气：\(tone.rawValue)
        时间范围：\(safeDateText(for: feature))
        今日支出区间：\(amountBand(snapshot.todayTotal))
        近七日平均区间：\(amountBand(snapshot.weekAverage))
        本月累计区间：\(amountBand(snapshot.monthTotal))
        常出现分类：\(safeCategoryText(snapshot.topCategories))

        请仅输出 JSON：
        {"summary":"不超过80字","action":"不超过50字","encourage":"不超过30字"}
        """

        let body: [String: Any] = [
            "feature": feature,
            "messages": [
                ["role": "system", "content": systemContent],
                ["role": "user", "content": userContent]
            ],
            "temperature": 0.6
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIReportServiceError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw AIReportServiceError.badStatus(http.statusCode, String(bodyText.prefix(300)))
        }

        guard let payload = try? JSONDecoder().decode(AIInsightPayload.self, from: data) else {
            throw AIReportServiceError.invalidResponse
        }
        return payload
    }

    private func safeDateText(for feature: String) -> String {
        switch feature {
        case "monthly":
            return "本月"
        case "weekly":
            return "近七日"
        default:
            return "今天"
        }
    }

    private func safeCategoryText(_ categories: [String]) -> String {
        let allowList = Set(HomeItem.Category.allCases.map(\.rawValue))
        let safe = categories
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { allowList.contains($0) }
            .prefix(3)
        return safe.isEmpty ? "暂无明显分类" : safe.joined(separator: "、")
    }

    private func amountBand(_ amount: Double) -> String {
        switch amount {
        case ..<0.01:
            return "暂无支出"
        case ..<30:
            return "较少"
        case ..<100:
            return "日常小额"
        case ..<300:
            return "中等"
        case ..<800:
            return "偏高"
        default:
            return "较高"
        }
    }

    private func authenticatedRequest(timeoutInterval: TimeInterval) throws -> URLRequest {
        guard let url = URL(string: AppSettings.productionAIEndpoint) else {
            throw AIReportServiceError.invalidEndpoint
        }
        let accessToken = KeychainService.loadAccessToken()
        guard !accessToken.isEmpty else {
            throw AIReportServiceError.authenticationRequired
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeoutInterval
        return request
    }
}
