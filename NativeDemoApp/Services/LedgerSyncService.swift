import Foundation

enum LedgerSyncError: LocalizedError {
    case invalidBaseURL
    case badStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "同步设置暂时不可用，请稍后再试。"
        case .badStatus(let code, let body):
            return "同步没有完成，请稍后再试。你的本机记录已保留。"
        }
    }
}

private struct LedgerDTO: Codable {
    let id: String
    let title: String
    let amount: Double
    let category: String
    let source: String
    let createdAt: String
    let updatedAt: String
    let emotionTag: String?
    let merchantBrandId: String?
    let draftMeta: LedgerDraftMetaDTO?
    let userEditedTitle: Bool?
    let userEditedCategory: Bool?
    let categoryCorrectionFrom: String?
}

private struct LedgerDraftMetaDTO: Codable {
    let batchId: String
    let importedAt: String
    let status: String
}

private struct LedgerListResponse: Codable {
    let ok: Bool
    let items: [LedgerDTO]
}

final class LedgerSyncService {
    private let baseURL: String
    private let accessToken: String
    private let urlSession: URLSession
    private let iso8601 = ISO8601DateFormatter()

    init(baseURL: String, accessToken: String, urlSession: URLSession = .shared) {
        self.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.accessToken = accessToken
        self.urlSession = urlSession
    }

    func upload(_ item: HomeItem) async throws {
        let dto = LedgerDTO(
            id: item.id.uuidString,
            title: item.title,
            amount: item.amount,
            category: item.category.rawValue,
            source: item.source.rawValue,
            createdAt: iso8601.string(from: item.createdAt),
            updatedAt: iso8601.string(from: item.updatedAt),
            emotionTag: item.emotionTag,
            merchantBrandId: item.merchantBrandId,
            draftMeta: item.draftMeta.map {
                LedgerDraftMetaDTO(
                    batchId: $0.batchId,
                    importedAt: iso8601.string(from: $0.importedAt),
                    status: $0.status.rawValue
                )
            },
            userEditedTitle: item.userEditedTitle,
            userEditedCategory: item.userEditedCategory,
            categoryCorrectionFrom: item.categoryCorrectionFrom?.rawValue
        )
        var request = try makeRequest(path: "/v1/ledger", method: "POST")
        request.httpBody = try JSONEncoder().encode(dto)
        _ = try await data(for: request)
    }

    func delete(id: UUID) async throws {
        let request = try makeRequest(path: "/v1/ledger/\(id.uuidString)", method: "DELETE")
        _ = try await data(for: request)
    }

    func fetchAll() async throws -> [HomeItem] {
        let request = try makeRequest(path: "/v1/ledger", method: "GET")
        let (data, _) = try await data(for: request)
        let payload = try JSONDecoder().decode(LedgerListResponse.self, from: data)
        return payload.items.map { dto in
            let id = UUID(uuidString: dto.id) ?? UUID()
            let createdAt = iso8601.date(from: dto.createdAt) ?? .now
            let updatedAt = iso8601.date(from: dto.updatedAt) ?? createdAt
            let category = HomeItem.Category(rawValue: dto.category) ?? .other
            let source = HomeItem.Source(rawValue: dto.source) ?? .manual
            let draftMeta = dto.draftMeta.flatMap { meta -> HomeItem.DraftMeta? in
                guard let importedAt = iso8601.date(from: meta.importedAt),
                      let status = HomeItem.DraftMeta.Status(rawValue: meta.status) else {
                    return nil
                }
                return HomeItem.DraftMeta(
                    batchId: meta.batchId,
                    importedAt: importedAt,
                    status: status
                )
            }
            return HomeItem(
                id: id,
                title: dto.title,
                amount: dto.amount,
                category: category,
                source: source,
                createdAt: createdAt,
                updatedAt: updatedAt,
                emotionTag: dto.emotionTag,
                merchantBrandId: dto.merchantBrandId,
                draftMeta: draftMeta,
                userEditedTitle: dto.userEditedTitle,
                userEditedCategory: dto.userEditedCategory,
                categoryCorrectionFrom: dto.categoryCorrectionFrom.flatMap { HomeItem.Category(rawValue: $0) }
            )
        }
    }

    private func makeRequest(path: String, method: String) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw LedgerSyncError.invalidBaseURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func data(for request: URLRequest) async throws -> (Data, String) {
        let (data, response) = try await urlSession.data(for: request)
        let body = String(data: data, encoding: .utf8) ?? ""
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(statusCode) else {
            throw LedgerSyncError.badStatus(statusCode, body)
        }
        return (data, body)
    }
}

