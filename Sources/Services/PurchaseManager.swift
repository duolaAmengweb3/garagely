import StoreKit
import SwiftUI

@MainActor
final class PurchaseManager: ObservableObject {
    @Published private(set) var isPro: Bool = false
    @Published private(set) var product: Product?
    @Published private(set) var purchasing = false
    @Published var lastError: String?

    private var updates: Task<Void, Never>?

    init() {
        // Screenshot/testing override only.
        if ProcessInfo.processInfo.environment["PRO"] == "1" { isPro = true }
        updates = listenForTransactions()
        Task {
            await loadProduct()
            await refreshEntitlement()
        }
    }

    deinit { updates?.cancel() }

    var priceText: String { product?.displayPrice ?? "$5.99" }

    func loadProduct() async {
        do {
            let products = try await Product.products(for: [ProductIDs.pro])
            product = products.first
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshEntitlement() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == ProductIDs.pro {
                owned = true
            }
        }
        isPro = owned || ProcessInfo.processInfo.environment["PRO"] == "1"
        // Cache for the container factory + widget to read without StoreKit.
        AppGroup.defaults?.set(isPro, forKey: AppSettingsKeys.proCached)
    }

    func purchase() async {
        guard let product else { await loadProduct(); return }
        purchasing = true
        defer { purchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlement()
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlement()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.refreshEntitlement()
                }
            }
        }
    }
}

// Free tier allows a single vehicle; Pro unlocks everything.
enum ProLimits {
    static let freeVehicleLimit = 1
}
