import Foundation
import StoreKit

@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    @Published var isUnlocked: Bool = false

    private let productID = "com.detriment.app.unlock"

    private init() {
        // Check existing entitlements on launch
        Task { await checkEntitlements() }
        // Listen for transaction updates
        Task { await listenForTransactions() }
    }

    func checkEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == productID {
                isUnlocked = true
                return
            }
        }
    }

    func purchase() async throws -> Bool {
        let products = try await Product.products(for: [productID])
        guard let product = products.first else { return false }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            if case .verified = verification {
                isUnlocked = true
                return true
            }
            return false
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restore() async throws {
        try await AppStore.sync()
        await checkEntitlements()
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result,
               transaction.productID == productID {
                isUnlocked = true
                await transaction.finish()
            }
        }
    }
}
