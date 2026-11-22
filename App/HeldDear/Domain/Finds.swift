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
    /// The price as shown ("$55 to $75", "From $35").
    var price: String = ""
    /// The lowest price in whole dollars, for the price filter. Nil when unknown.
    var fromDollars: Int? = nil
    /// Who it suits, for the Finds filter.
    var fits: Set<FindFit> = []
    /// How long it takes to arrive, in the shop's words.
    var arrives: String = ""
    /// A dependable pick from a national brand (a cake or flowers to order without searching), not a discovery.
    var dependable: Bool = false
    /// When it was added to the catalog, newest first in Finds.
    var added: String = "2026-11-20"
    /// The shop's product photo, bundled in the app's assets under this name, only once the shop has agreed
    /// (Nov 21, 2026). Nil shows no photo; nothing is ever fetched.
    var photo: String? = nil
}

/// Who a find suits, in the words the Finds filter shows.
enum FindFit: String, CaseIterable {
    case partner, parent, kidsGiving, child, grandparent, friend

    var label: String {
        switch self {
        case .partner: "Partner"
        case .parent: "Parent"
        case .kidsGiving: "Kids giving"
        case .child: "Child"
        case .grandparent: "Grandparent"
        case .friend: "Friend"
        }
    }
}

/// The Finds price filter.
enum FindPrice: String, CaseIterable {
    case under50, from50to100, over100

    var label: String {
        switch self {
        case .under50: "Under $50"
        case .from50to100: "$50 to $100"
        case .over100: "Over $100"
        }
    }

    func contains(_ dollars: Int?) -> Bool {
        guard let d = dollars else { return false }
        switch self {
        case .under50: return d < 50
        case .from50to100: return d >= 50 && d <= 100
        case .over100: return d > 100
        }
    }
}

enum Finds {
    /// The catalog. Graham approves every find (decided Nov 21, 2026); monthly Claude and Perplexity searches propose them.
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
        // Approved Nov 21, 2026, from the first Perplexity list. Pages checked Nov 21.
        Find(id: "nostalgic-signature-seal", name: "Signature wax seal", maker: "Nostalgic Impressions",
             url: "https://nostalgicimpressions.com/products/my-signature-custom-wax-seal-stamp", kinds: [.gift], fromKids: nil,
             tags: ["letters", "writing", "stationery", "keepsake", "handwriting"], leadDays: 14,
             why: "A brass seal engraved from someone's own handwritten signature.",
             price: "$55 to $75", fromDollars: 55, fits: [.partner, .grandparent, .kidsGiving],
             arrives: "About 1 to 2 weeks after you approve the proof", added: "2026-11-21"),
        Find(id: "nostalgic-art-seal", name: "Wax seal from a child's drawing", maker: "Nostalgic Impressions",
             url: "https://nostalgicimpressions.com/products/create-your-own-wax-seal-stamp", kinds: [.kidsMade, .gift], fromKids: true,
             tags: ["letters", "drawing", "art", "keepsake", "stationery"], leadDays: 14,
             why: "A child's own drawing turned into a working wax seal.",
             price: "From $35", fromDollars: 35, fits: [.kidsGiving, .grandparent],
             arrives: "About 1 to 2 weeks after you approve the proof", added: "2026-11-21"),
        Find(id: "nervous-system-puzzle", name: "Custom wooden jigsaw puzzle", maker: "Nervous System",
             url: "https://n-e-r-v-o-u-s.com/customPuzzle/", kinds: [.gift], fromKids: nil,
             tags: ["puzzles", "photos", "games", "family"], leadDays: 21,
             why: "Grown piece shapes, custom letter pieces and a message engraved on the back.",
             price: "From $65", fromDollars: 65, fits: [.partner, .friend, .grandparent],
             arrives: "Ships in 2 weeks, then 2 to 3 days", added: "2026-11-21"),
        Find(id: "olfactory-custom-scent", name: "At-home custom scent", maker: "Olfactory NYC",
             url: "https://www.olfactorynyc.com/products/at-home-online-custom-scent-experience", kinds: [.gift], fromKids: false,
             tags: ["fragrance", "perfume", "beauty", "self-care"], leadDays: 14,
             why: "They test blends at home and end with a bottle they name themselves.",
             price: "$85 to $145", fromDollars: 85, fits: [.partner, .parent, .friend],
             arrives: "Ships in 3 to 5 business days; the bottle comes about day 10", added: "2026-11-21"),
        Find(id: "kiriki-embroidery-starter", name: "Embroidery starter kit", maker: "Kiriki Press",
             url: "https://kirikipress.com/products/embroidery-starter-kit-beginner-embroidery", kinds: [.gift, .stocking, .kidsMade], fromKids: nil,
             tags: ["sewing", "embroidery", "crafts", "animals", "making"], leadDays: 14,
             why: "Hand screen-printed by a small studio; easy to make together.",
             price: "$49", fromDollars: 49, fits: [.child, .grandparent, .kidsGiving],
             arrives: "Ships weekly, arrives within a week of shipping", added: "2026-11-21"),
        Find(id: "urban-cheesecraft-deluxe", name: "Deluxe cheesemaking kit", maker: "Urban Cheesecraft",
             url: "https://www.urbancheesecraft.com/products/deluxe-cheese-kit-mozzarella-burrata-string-cheese-goat-cheese-ricotta-paneer-queso-blanco-farmers-cow-goat-milk",
             kinds: [.gift, .theDay], fromKids: false, tags: ["cooking", "food", "cheese", "kitchen"], leadDays: 10,
             why: "A screen-free kitchen project for two from a small Portland shop.",
             price: "$59", fromDollars: 59, fits: [.partner, .friend, .parent],
             arrives: "3 to 4 days to pack, then 1 to 5 days", added: "2026-11-21"),
        Find(id: "field-forest-shiitake", name: "Shiitake tabletop farm", maker: "Field & Forest Products",
             url: "https://fieldforest.net/shiitake-table-top-farm/", kinds: [.gift, .stocking], fromKids: nil,
             tags: ["gardening", "cooking", "plants", "mushrooms"], leadDays: 10,
             why: "A family grower's block that sprouts mushrooms on the counter.",
             price: "$28", fromDollars: 28, fits: [.parent, .grandparent, .friend],
             arrives: "Ships within 5 business days", added: "2026-11-21"),
        Find(id: "pysanky-super-color-kit", name: "Pysanky egg decorating kit", maker: "Ukrainian Gift Shop",
             url: "https://ukrainiangiftshop.com/products/super-color-kit-w-delrin", kinds: [.gift, .kidsMade], fromKids: nil,
             tags: ["crafts", "heritage", "easter", "art", "making"], leadDays: 7,
             why: "A family shop's kit for traditional Ukrainian decorated eggs.",
             price: "$35", fromDollars: 35, fits: [.grandparent, .child],
             arrives: "Usually ships the next business day", added: "2026-11-21"),
        Find(id: "murrays-fly-tying", name: "Fly tying starter kit", maker: "Murray's Fly Shop",
             url: "https://www.murraysflyshop.com/products/murrays-basic-fly-tying-kit", kinds: [.gift], fromKids: nil,
             tags: ["fishing", "fly fishing", "outdoors", "making"], leadDays: 10,
             why: "The setup a family-run Virginia shop uses in its own workshops.",
             price: "$109", fromDollars: 109, fits: [.parent, .grandparent, .kidsGiving],
             arrives: "3 to 7 business days", added: "2026-11-21"),
        Find(id: "bari-zaki-bookbinding", name: "Bookbinding kit", maker: "Bari Zaki Studio",
             url: "https://www.barizaki.com/shop/5tmq02lvyvh1e27xaoc2680g8zivge", kinds: [.gift], fromKids: nil,
             tags: ["journaling", "paper", "books", "writing", "making"], leadDays: 10,
             why: "A paper studio's tools for sewing a book by hand, gift-wrapped by the studio.",
             price: "$68", fromDollars: 68, fits: [.friend, .partner, .child],
             arrives: "Usually ships within 2 business days", added: "2026-11-21"),
        Find(id: "corter-wallet-kit", name: "Leather wallet kit", maker: "Corter Leather (via Buckleguy)",
             url: "https://www.buckleguy.com/diy-corter-front-pocket-wallet-leather-kit/", kinds: [.gift], fromKids: nil,
             tags: ["leather", "making", "wallets", "crafts"], leadDays: 10,
             why: "They stitch their own wallet from the leather and thread you pick.",
             price: "$35", fromDollars: 35, fits: [.partner, .parent, .kidsGiving],
             arrives: "1 to 2 days to prepare, then 2 to 5 days", added: "2026-11-21"),
        Find(id: "snuggly-monkey-folk-fox", name: "Folk fox mini embroidery kit", maker: "Snuggly Monkey",
             url: "https://www.snugglymonkey.com/products/folk-fox-mini-embroidery-kit", kinds: [.gift, .stocking], fromKids: nil,
             tags: ["embroidery", "folk art", "crafts", "foxes"], leadDays: 7,
             why: "A small folk-art hoop kit from a family needlework shop.",
             price: "$25", fromDollars: 25, fits: [.friend, .child],
             arrives: "Usually ships within 3 days", added: "2026-11-21"),
        // Dependable picks: national brands for the cake and the flowers, to order without searching.
        Find(id: "urbanstems-margot", name: "The Margot bouquet", maker: "UrbanStems",
             url: "https://urbanstems.com/products/the-margot", kinds: [.flowers], fromKids: nil,
             tags: ["flowers", "roses"], leadDays: 2,
             why: "Anemone, garden roses and ranunculus, delivered on the day you choose.",
             price: "$90", fromDollars: 90, fits: [.partner, .parent, .grandparent, .friend],
             arrives: "Pick the delivery date at checkout", dependable: true, added: "2026-11-21"),
        Find(id: "baked-by-melissa-cupcakes", name: "Bite-size cupcakes", maker: "Baked by Melissa",
             url: "https://www.bakedbymelissa.com/collections/cupcakes", kinds: [.cake], fromKids: nil,
             tags: ["sweets", "dessert", "cupcakes", "party"], leadDays: 4,
             why: "A box of tiny cupcakes shipped to the door when baking isn't happening.",
             price: "See the shop", fits: [.partner, .parent, .child, .grandparent, .friend],
             arrives: "Shipped; see the shop for dates", dependable: true, added: "2026-11-21"),
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

extension Finds {
    /// Every find for the Finds page, newest first, narrowed by who it's for and price. Filters stack.
    static func browse(fits: Set<FindFit> = [], prices: Set<FindPrice> = [], catalog: [Find] = Finds.catalog) -> [Find] {
        catalog.enumerated()
            .filter { _, f in fits.isEmpty || !f.fits.isDisjoint(with: fits) }
            .filter { _, f in prices.isEmpty || prices.contains { $0.contains(f.fromDollars) } }
            .sorted { a, b in a.element.added == b.element.added ? a.offset > b.offset : a.element.added > b.element.added }
            .map(\.element)
    }
}
