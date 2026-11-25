import Foundation

/// Mailed cards the user has ordered, kept on this iPhone so the order number is easy to find later (Graham,
/// Nov 25, 2026). Only what the user needs for help: who, which card, when, the order number. No addresses.
struct MailedOrder: Codable, Equatable, Identifiable {
    var id: String          // the order's reference, the same one the server knows
    var orderNumber: String
    var firstName: String
    var cardName: String
    var orderedOn: Date
    var mailing: String
    var test: Bool
}

enum MailedOrders {
    static let key = "mailedOrders"

    /// Newest first.
    static func all(_ defaults: UserDefaults = .standard) -> [MailedOrder] {
        guard let data = defaults.data(forKey: key),
              let list = try? JSONDecoder().decode([MailedOrder].self, from: data) else { return [] }
        return list.sorted { $0.orderedOn > $1.orderedOn }
    }

    /// Adds an order; the same reference twice keeps one row (a retried order is still one card).
    static func add(_ order: MailedOrder, _ defaults: UserDefaults = .standard) {
        var list = all(defaults).filter { $0.id != order.id }
        list.insert(order, at: 0)
        defaults.set(try? JSONEncoder().encode(list), forKey: key)
    }

    static func removeTests(_ defaults: UserDefaults = .standard) {
        defaults.set(try? JSONEncoder().encode(all(defaults).filter { !$0.test }), forKey: key)
    }
}
