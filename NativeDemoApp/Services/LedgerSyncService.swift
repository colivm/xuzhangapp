import Foundation

enum LedgerSyncError: LocalizedError {
    case invalidBaseURL
    case badStatus(Int, String)
    case invalidAcknowledgement

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "同步设置暂时不可用，请稍后再试。"
        case .badStatus, .invalidAcknowledgement:
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
    let memoryContext: LedgerMemoryContextDTO?
    let scenePackId: String?
}

enum CloudNetworkFailureGuidance {
    static func message(for error: Error) -> String? {
        let error = error as NSError
        guard error.domain == NSURLErrorDomain else { return nil }
        switch URLError.Code(rawValue: error.code) {
        case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff,
             .networkConnectionLost, .timedOut, .cannotConnectToHost,
             .cannotFindHost, .dnsLookupFailed:
            return "暂时无法连接网络。请检查网络；若已禁止叙账联网，请在系统设置中允许访问无线局域网与蜂窝网络。"
        default:
            return nil
        }
    }
}

/// A batch is complete only when every required mutation was acknowledged.
/// Keep processing other records after a recoverable failure without hiding it.
struct LedgerSyncAttemptOutcome {
    private(set) var failedUploads = 0
    private(set) var failedDeletions = 0
    private(set) var needsNetworkHelp = false

    var isComplete: Bool { failedUploads == 0 && failedDeletions == 0 }

    mutating func recordUploadFailure(_ error: Error) {
        failedUploads += 1
        needsNetworkHelp = needsNetworkHelp || CloudNetworkFailureGuidance.message(for: error) != nil
    }

    mutating func recordDeletionFailure(_ error: Error) {
        failedDeletions += 1
        needsNetworkHelp = needsNetworkHelp || CloudNetworkFailureGuidance.message(for: error) != nil
    }

    var message: String {
        if isComplete {
            return "自动备份已完成；照片仍保存在本机。重复记录已保留最新版本。"
        }
        let retry = needsNetworkHelp
            ? "请检查网络和系统设置中的联网权限后重试。"
            : "请稍后重试。"
        return "备份尚未完成，有记录或删除操作未同步。\(retry)本机记录已保留。"
    }
}

private struct LedgerAcknowledgement: Decodable {
    let ok: Bool
}

private struct LedgerDraftMetaDTO: Codable {
    let batchId: String
    let importedAt: String
    let status: String
}

private struct LedgerMemoryContextDTO: Codable {
    let weatherKind: String?
    let temperatureCelsius: Double?
    let cityName: String?
    let semanticPlace: String?
}

private struct LedgerTombstoneDTO: Codable {
    let id: String
    let deletedAt: String
}

private struct LedgerListResponse: Codable {
    let ok: Bool
    let items: [LedgerDTO]
    let tombstones: [LedgerTombstoneDTO]?
}

struct LedgerCloudSnapshot: Equatable {
    var items: [HomeItem]
    var tombstones: [CloudLedgerMergePolicy.Tombstone]
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
            categoryCorrectionFrom: item.categoryCorrectionFrom?.rawValue,
            memoryContext: item.memoryContext.map {
                LedgerMemoryContextDTO(
                    weatherKind: $0.weatherKind,
                    temperatureCelsius: $0.temperatureCelsius,
                    cityName: $0.cityName,
                    semanticPlace: $0.semanticPlace
                )
            },
            scenePackId: item.scenePackId
        )
        var request = try makeRequest(path: "/v1/ledger", method: "POST")
        request.httpBody = try JSONEncoder().encode(dto)
        _ = try await data(for: request)
    }

    func delete(id: UUID, deletedAt: Date? = nil) async throws {
        var request = try makeRequest(path: "/v1/ledger/\(id.uuidString)", method: "DELETE")
        if let deletedAt {
            var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "deletedAt", value: iso8601.string(from: deletedAt))]
            if let url = components?.url { request.url = url }
        }
        _ = try await data(for: request)
    }

    func fetchAll() async throws -> [HomeItem] {
        try await fetchSnapshot().items
    }

    func fetchSnapshot() async throws -> LedgerCloudSnapshot {
        let request = try makeRequest(path: "/v1/ledger", method: "GET")
        let (data, _) = try await data(for: request)
        let payload = try JSONDecoder().decode(LedgerListResponse.self, from: data)
        let tombstones = (payload.tombstones ?? []).compactMap { dto -> CloudLedgerMergePolicy.Tombstone? in
            guard let id = UUID(uuidString: dto.id),
                  let deletedAt = iso8601.date(from: dto.deletedAt) else { return nil }
            return CloudLedgerMergePolicy.Tombstone(id: id, deletedAt: deletedAt)
        }
        let items = payload.items.map { dto in
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
                categoryCorrectionFrom: dto.categoryCorrectionFrom.flatMap { HomeItem.Category(rawValue: $0) },
                memoryContext: dto.memoryContext.map {
                    HomeItem.MemoryContext(
                        weatherKind: $0.weatherKind,
                        temperatureCelsius: $0.temperatureCelsius,
                        cityName: $0.cityName,
                        semanticPlace: $0.semanticPlace
                    )
                },
                scenePackId: dto.scenePackId
            )
        }
        return LedgerCloudSnapshot(items: items, tombstones: tombstones)
    }

    private func makeRequest(path: String, method: String) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw LedgerSyncError.invalidBaseURL
        }
        // A previous GET response cannot prove that this attempt reached the server.
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
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
        guard let acknowledgement = try? JSONDecoder().decode(LedgerAcknowledgement.self, from: data),
              acknowledgement.ok else {
            throw LedgerSyncError.invalidAcknowledgement
        }
        return (data, body)
    }
}

