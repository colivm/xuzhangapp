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
    case invalidEndpoint(String)
    case badStatus(Int, String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint(let endpoint):
            return "AI 服务地址配置异常：\(endpoint)"
        case .badStatus(let code, let body):
            if body.contains("AI_INPUT_REJECTED") || body.contains("BANK_CARD") {
                return "远程 AI 触发内容保护，已回退本地建议。"
            }
            return "AI 请求失败（\(code)），已回退本地建议。"
        case .invalidResponse:
            return "AI 返回格式异常。"
        }
    }
}

final class AIReportService {
    private let zhipuDefaultEndpoint = "https://open.bigmodel.cn/api/paas/v4/chat/completions"

    func generateInsight(
        snapshot: AISnapshot,
        endpoint: String,
        apiKey: String,
        tone: AppSettings.AITone,
        model: String,
        feature: String = "daily"
    ) async throws -> AIInsightPayload {
        let finalEndpoint = normalizedEndpoint(endpoint)
        guard let url = URL(string: finalEndpoint) else {
            throw AIReportServiceError.invalidEndpoint(finalEndpoint)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let isDirectZhipu = finalEndpoint.contains("open.bigmodel.cn")
        if isDirectZhipu && !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        } else if !isDirectZhipu && !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-proxy-token")
        }
        if finalEndpoint.contains("/v1/ai/") {
            let accessToken = KeychainService.loadAccessToken()
            if !accessToken.isEmpty {
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            }
        }

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
            "model": model.isEmpty ? "doubao-seed-1-6-flash-250828" : model,
            "feature": feature,
            "messages": [
                ["role": "system", "content": systemContent],
                ["role": "user", "content": userContent]
            ],
            "temperature": 0.6
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 45

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIReportServiceError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw AIReportServiceError.badStatus(http.statusCode, String(bodyText.prefix(300)))
        }

        if let payload = try? JSONDecoder().decode(AIInsightPayload.self, from: data) {
            return payload
        }

        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if
                let summary = object["summary"] as? String,
                let action = object["action"] as? String,
                let encourage = object["encourage"] as? String {
                return AIInsightPayload(summary: summary, action: action, encourage: encourage)
            }

            if
                let choices = object["choices"] as? [[String: Any]],
                let first = choices.first,
                let message = first["message"] as? [String: Any],
                let content = message["content"] as? String,
                let payload = decodePayloadFromText(content) {
                return payload
            }
        }

        throw AIReportServiceError.invalidResponse
    }

    private func decodePayloadFromText(_ content: String) -> AIInsightPayload? {
        let trimmed = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if
            let data = trimmed.data(using: .utf8),
            let payload = try? JSONDecoder().decode(AIInsightPayload.self, from: data) {
            return payload
        }

        if
            let data = trimmed.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let summary = object["summary"] as? String,
            let action = object["action"] as? String,
            let encourage = object["encourage"] as? String {
            return AIInsightPayload(summary: summary, action: action, encourage: encourage)
        }

        return nil
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

    private func normalizedEndpoint(_ endpoint: String) -> String {
        let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return zhipuDefaultEndpoint }

        let withoutTrailingSlash = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard
            let components = URLComponents(string: withoutTrailingSlash),
            components.scheme != nil,
            components.host != nil
        else {
            return trimmed
        }

        let path = components.path
        if path.isEmpty || path == "/" {
            return withoutTrailingSlash + "/v1/insight/daily"
        }
        return trimmed
    }
}
