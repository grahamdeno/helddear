import Foundation

/// Finds: unusual things from small makers, shown inside the item they fit (mockup approved Nov 20, 2026).
/// The catalog ships inside the app and is matched on the phone, so nothing leaves it. At most two per item,
/// each with a reason it fits and an order-by date. The giver shapes the finds: a gift from the kids gets things
/// they can make or give.
struct Find: Equatable, Identifiable {
    let id: String
    let name: String
    let maker: String
    let url: String
    /// The items it can fill.
    let kinds: Set<ActKind>
    /// True: suits a gift from the kids. False: suits a gift from you. Nil: either.
    let fromKids: Bool?
    /// Interests it fits, matched against what the person loves.
    let tags: Set<String>
    /// Days before the day to order it.
    let leadDays: Int
    /// One line on why it fits.
    let why: String
}

enum Finds {
    /// The starter catalog. An agent refreshes it from small makers before each app update; Graham doesn't curate it.
    static let catalog: [Find] = [
        Find(id: "tamara-silk-scarf-kit", name: "Silk scarf painting kit", maker: "Tamara Silk Scarves",
             url: "https://www.tamarasilkscarves.com/paintingkits", kinds: [.kidsMade, .gift, .fromSanta], fromKids: true,
             tags: ["painting", "art", "crafts", "scarves", "fashion", "making"], leadDays: 21,
             why: "The kids paint it, and she wears it. Made for beginners."),
        Find(id: "boarderie-dessert-board", name: "Classic birthday dessert board", maker: "Boarderie",
             url: "https://boarderie.com/products/classic-birthday-dessert-board", kinds: [.cake], fromKids: nil,
             tags: ["sweets", "dessert", "food", "chocolate", "party", "hosting"], leadDays: 7,
             why: "Instead of one cake, a board of sweets for everyone to share."),
        Find(id: "star-child-special-edition", name: "Star Child, special edition picture book", maker: "Claire A. Nivola",
             url: "https://coolhunting.com/buy/star-child-special-edition-by-claire-a-nivola/", kinds: [.kidsMade, .gift, .stocking],
             fromKids: true, tags: ["books", "reading", "art", "illustration", "stars", "keepsake"], leadDays: 10,
             why: "A keepsake the kids can sign inside the cover."),
        Find(id: "cns-watch-bands", name: "A handmade watch band", maker: "CNS Watch Bands",
             url: "https://cnswatchbands.com", kinds: [.gift], fromKids: false,
             tags: ["watches", "style", "leather", "fashion", "handmade"], leadDays: 14,
             why: "Something worn every day, made for the watch they already love."),
    ]

    /// Up to `limit` finds for an item, best fit first: the item's kind, the giver, then how many of the person's
    /// loves it matches. Dismissed finds never come back.
    static func matches(kind: ActKind, fromKids: Bool, loves: [String], dismissed: Set<String>,
                        catalog: [Find] = Finds.catalog, limit: Int = 2) -> [Find] {
        let words = Set(loves.flatMap { $0.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init) })
        let candidates = catalog.enumerated().filter { _, f in
            f.kinds.contains(kind) && (f.fromKids == nil || f.fromKids == fromKids) && !dismissed.contains(f.id)
        }
        return candidates.sorted { a, b in
            let sa = score(a.element, words), sb = score(b.element, words)
            return sa == sb ? a.offset < b.offset : sa > sb
        }.prefix(limit).map(\.element)
    }

    static func score(_ f: Find, _ words: Set<String>) -> Int {
        f.tags.filter { tag in words.contains(tag) || words.contains { $0.hasPrefix(tag) || tag.hasPrefix($0) && $0.count > 3 } }.count
    }

    /// The day to order by for an occasion on `due`.
    static func orderBy(_ f: Find, due: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -f.leadDays, to: due) ?? due
    }

    /// "Tamara Silk Scarves · order by Jan 2".
    static func meta(_ f: Find, due: Date, calendar: Calendar = .current) -> String {
        "\(f.maker) · order by \(orderBy(f, due: due, calendar: calendar).formatted(.dateTime.month(.abbreviated).day()))"
    }

    /// Dismissed finds, per person, in a setting (not stored data).
    static func dismissed(for personID: UUID, _ defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: "dismissedFinds-\(personID.uuidString)") ?? [])
    }

    static func dismiss(_ id: String, for personID: UUID, _ defaults: UserDefaults = .standard) {
        var now = dismissed(for: personID, defaults)
        now.insert(id)
        defaults.set(Array(now).sorted(), forKey: "dismissedFinds-\(personID.uuidString)")
    }
}
