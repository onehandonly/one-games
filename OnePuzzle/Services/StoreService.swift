import Foundation
import StoreKit

// MARK: - StoreService
// StoreKit 2 scaffold — subscription + consumable hints.
// No transactions are processed until the monetization sprint.
// This provides the store surface that SwiftUI views can reference.

@MainActor
@Observable
final class StoreService {
    static let plusSubscriptionID = "com.onepuzzle.plus.monthly"
    static let plusYearlySubscriptionID = "com.onepuzzle.plus.yearly"
    static let hintConsumableID = "com.onepuzzle.hint.five"

    var isPlusSubscriber = false
    var products: [Product] = []
    var isLoading = false

    // Stub — populate when StoreKit wiring is active
    func loadProducts() async {
        isLoading = true
        // TODO: ONE-21 — Implement StoreKit 2 product loading
        // let ids = [Self.plusSubscriptionID, Self.hintConsumableID]
        // products = try? await Product.products(for: Set(ids))
        isLoading = false
    }

    func purchase(_ product: Product) async {
        // TODO: ONE-21 — Implement StoreKit 2 purchase flow
    }

    func restorePurchases() async {
        // TODO: ONE-21 — Implement restore
    }
}
