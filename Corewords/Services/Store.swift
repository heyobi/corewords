import StoreKit
import SwiftUI

/// One-time Pro unlock (StoreKit 2): the Extended list, phrasal verbs and the pronunciation trainer.
@MainActor
final class Store: ObservableObject {
    static let productID = "com.heyobi.corewords.pro"

    @Published private(set) var isPro = UserDefaults.standard.bool(forKey: "pro")
    @Published private(set) var product: Product?
    @Published var busy = false
    @Published var message: LocalizedStringKey?

    private var updates: Task<Void, Never>?

    init() {
        if ShotsTour.active { isPro = true }
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let t) = result { await t.finish(); await self?.refresh() }
            }
        }
        Task { await load(); await refresh() }
    }

    /// The localized price, hidden if the store reports a currency that doesn't match the storefront.
    var priceText: String? {
        guard let p = product else { return nil }
        return p.displayPrice
    }

    func load() async {
        product = try? await Product.products(for: [Self.productID]).first
    }

    func refresh() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.productID, t.revocationDate == nil { owned = true }
        }
        if ShotsTour.active { owned = true }
        set(owned)
    }

    private func set(_ owned: Bool) {
        isPro = owned
        UserDefaults.standard.set(owned, forKey: "pro")
    }

    func buy() async {
        if product == nil { await load() }
        guard let product else { message = "The App Store isn't available right now. Please try again later."; return }
        busy = true
        defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(let v):
                if case .verified(let t) = v { await t.finish(); set(true) }
            case .pending: message = "The purchase is waiting for approval."
            default: break
            }
        } catch {
            message = "The purchase didn't go through. Nothing was charged."
        }
    }

    func restore() async {
        busy = true
        defer { busy = false }
        try? await AppStore.sync()
        await refresh()
        message = isPro ? "Pro is unlocked. Thank you!" : "No earlier purchase was found for this Apple Account."
    }
}
