import Foundation
import StoreKit
import WidgetKit

/// Held Dear Lifetime: one non-consumable in-app purchase, $9.99, no subscription.
/// It adds delight (card designs, your own words, Lock Screen widget, look-back, future circles),
/// never anything needed to avoid missing someone. StoreKit verifies with Apple; the app itself sends nothing.
@MainActor
final class Purchases: ObservableObject {
    static let shared = Purchases()
    static let lifetimeID = "com.grahamdeno.helddear.lifetime"

    @Published private(set) var hasLifetime: Bool
    @Published private(set) var product: Product?
    @Published private(set) var isWorking = false
    @Published var message: String?

    private var updates: Task<Void, Never>?

    private init() {
        hasLifetime = UserDefaults.standard.bool(forKey: "hasLifetime")
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task { await refresh() }
    }

    /// "$9.99" in the user's currency, once the App Store answers.
    var priceText: String { product?.displayPrice ?? "$9.99" }

    func refresh() async {
        if product == nil {
            product = try? await Product.products(for: [Self.lifetimeID]).first
        }
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.lifetimeID, t.revocationDate == nil { owned = true }
        }
        setLifetime(owned)
    }

    func buy() async {
        guard let product else {
            message = "The App Store isn't answering right now. Try again in a moment."
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            switch try await product.purchase() {
            case .success(let result): await handle(result)
            case .pending: message = "Waiting for approval. Lifetime turns on as soon as it's approved."
            case .userCancelled: break
            @unknown default: break
            }
        } catch {
            message = "That didn't go through. You weren't charged."
        }
    }

    func restore() async {
        isWorking = true
        defer { isWorking = false }
        try? await AppStore.sync()
        await refresh()
        message = hasLifetime ? "Lifetime is on. Thank you." : "No earlier purchase found for this Apple Account."
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let t) = result else { return }
        if t.productID == Self.lifetimeID { setLifetime(t.revocationDate == nil) }
        await t.finish()
    }

    private func setLifetime(_ on: Bool) {
        hasLifetime = on
        UserDefaults.standard.set(on, forKey: "hasLifetime")
        // The widget reads this to show the Lock Screen version.
        UserDefaults(suiteName: AppGroup.identifier)?.set(on, forKey: "hasLifetime")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
