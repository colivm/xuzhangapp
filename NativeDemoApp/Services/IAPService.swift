import Foundation
import StoreKit

enum IAPTier: String, CaseIterable {
    case monthly
    case yearly
    case lifetime
}

struct IAPPurchaseVerification: Equatable {
    let productId: String
    let transactionId: String
    let signedTransactionInfo: String
    let tier: IAPTier
}

enum IAPServiceError: LocalizedError {
    case productNotConfigured
    case productNotFound
    case purchaseCancelled
    case purchasePending
    case unverifiedTransaction

    var errorDescription: String? {
        switch self {
        case .productNotConfigured:
            return "内购商品 ID 尚未配置。"
        case .productNotFound:
            return "没有从 App Store 加载到对应会员商品。"
        case .purchaseCancelled:
            return "已取消购买。"
        case .purchasePending:
            return "购买正在处理中，请稍后在会员页恢复购买。"
        case .unverifiedTransaction:
            return "交易校验失败，请稍后重试。"
        }
    }
}

@MainActor
final class IAPService: ObservableObject {
    static let shared = IAPService()

    @Published private(set) var productsByTier: [IAPTier: Product] = [:]

    private let productIDsByTier: [IAPTier: String]
    private var updatesTask: Task<Void, Never>?
    private var pendingTransactions: [String: Transaction] = [:]

    private init(productIDsByTier: [IAPTier: String] = IAPProductConfig.loadProductIDs()) {
        self.productIDsByTier = productIDsByTier
        updatesTask = listenForTransactionUpdates()
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async throws {
        let ids = productIDsByTier.values.filter { !$0.isEmpty }
        guard ids.count == IAPTier.allCases.count else {
            throw IAPServiceError.productNotConfigured
        }
        let products = try await Product.products(for: ids)
        productsByTier = Dictionary(uniqueKeysWithValues: products.compactMap { product in
            guard let tier = tier(for: product.id) else { return nil }
            return (tier, product)
        })
    }

    func displayPrice(for tier: IAPTier, fallback: String) -> String {
        productsByTier[tier]?.displayPrice ?? fallback
    }

    func purchase(tier: IAPTier) async throws -> IAPPurchaseVerification {
        if productsByTier[tier] == nil {
            try await loadProducts()
        }
        guard let product = productsByTier[tier] else {
            throw IAPServiceError.productNotFound
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verifiedTransaction(from: verification)
            pendingTransactions[String(transaction.id)] = transaction
            return verificationPayload(for: transaction, signedTransactionInfo: verification.jwsRepresentation, tier: tier)
        case .userCancelled:
            throw IAPServiceError.purchaseCancelled
        case .pending:
            throw IAPServiceError.purchasePending
        @unknown default:
            throw IAPServiceError.purchasePending
        }
    }

    func restorePurchases() async throws -> [IAPPurchaseVerification] {
        try await AppStore.sync()
        var payloads: [IAPPurchaseVerification] = []
        for await result in Transaction.currentEntitlements {
            let transaction = try verifiedTransaction(from: result)
            guard let tier = tier(for: transaction.productID) else { continue }
            pendingTransactions[String(transaction.id)] = transaction
            payloads.append(verificationPayload(for: transaction, signedTransactionInfo: result.jwsRepresentation, tier: tier))
        }
        return payloads
    }

    func finish(transactionId: String) async {
        guard let transaction = pendingTransactions.removeValue(forKey: transactionId) else { return }
        await transaction.finish()
    }

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await MainActor.run {
                        self.pendingTransactions[String(transaction.id)] = transaction
                    }
                }
            }
        }
    }

    private func verifiedTransaction(from result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified:
            throw IAPServiceError.unverifiedTransaction
        }
    }

    private func verificationPayload(
        for transaction: Transaction,
        signedTransactionInfo: String,
        tier: IAPTier
    ) -> IAPPurchaseVerification {
        IAPPurchaseVerification(
            productId: transaction.productID,
            transactionId: String(transaction.id),
            signedTransactionInfo: signedTransactionInfo,
            tier: tier
        )
    }

    private func tier(for productId: String) -> IAPTier? {
        productIDsByTier.first(where: { $0.value == productId })?.key
    }
}

private enum IAPProductConfig {
    static func loadProductIDs() -> [IAPTier: String] {
        let secrets = loadSecretsPlist()
        let info = Bundle.main.infoDictionary ?? [:]
        return [
            .monthly: secrets["IAPMonthlyProductID"] ?? infoString("IAPMonthlyProductID", in: info) ?? "com.xuzhang.app.member.monthly",
            .yearly: secrets["IAPYearlyProductID"] ?? infoString("IAPYearlyProductID", in: info) ?? "com.xuzhang.app.member.yearly",
            .lifetime: secrets["IAPLifetimeProductID"] ?? infoString("IAPLifetimeProductID", in: info) ?? "com.xuzhang.app.member.lifetime",
        ]
    }

    private static func infoString(_ key: String, in info: [String: Any]) -> String? {
        guard let value = info[key] as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func loadSecretsPlist() -> [String: String] {
        guard let url = Bundle.main.url(forResource: "AppSecrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let object = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = object as? [String: Any] else {
            return [:]
        }
        return dict.reduce(into: [String: String]()) { result, pair in
            if let value = pair.value as? String {
                result[pair.key] = value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }
}
