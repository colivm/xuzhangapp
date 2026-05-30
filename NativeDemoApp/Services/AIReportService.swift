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

enum AIReportServiceError: Error {
    case invalidEndpoint
    case invalidResponse
}

final class AIReportService {
    private let zhipuDefaultEndpoint = "https://open.bigmodel.cn/api/paas/v4/chat/completions"

    func generateInsight(
        snapshot: AISnapshot,
        endpoint: String,
        apiKey: String,
        tone: AppSettings.AITone,
        model: String
    ) async throws -> AIInsightPayload {
        let finalEndpoint = endpoint.isEmpty ? zhipuDefaultEndpoint : endpoint
        guard let url = URL(string: finalEndpoint) else {
            throw AIReportServiceError.invalidEndpoint
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

        let prompt = HomeViewModel.promptTemplate(
            todayTotal: snapshot.todayTotal,
            weeklyAverage: snapshot.weekAverage,
            monthlyTotal: snapshot.monthTotal,
            topCategories: snapshot.topCategories.joined(separator: "、")
        )

        let systemContent = """
        你是“轻账日记”的温和消费复盘助手。
        根据用户消费快照输出 JSON，字段必须是 summary/action/encourage。
        不要输出投资建议，不要说教。
        """

        let userContent = """
        语气：\(tone.rawValue)
        日期：\(snapshot.date)
        今日总支出：\(snapshot.todayTotal)
        近7日平均日支出：\(snapshot.weekAverage)
        本月累计支出：\(snapshot.monthTotal)
        TOP分类：\(snapshot.topCategories.joined(separator: "、"))

        按以下 Prompt 执行并仅输出 JSON：
        \(prompt)
        """

        let body: [String: Any] = [
            "model": model.isEmpty ? "doubao-seed-1-6-flash-250828" : model,
            "messages": [
                ["role": "system", "content": systemContent],
                ["role": "user", "content": userContent]
            ],
            "temperature": 0.6
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw AIReportServiceError.invalidResponse
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
}
