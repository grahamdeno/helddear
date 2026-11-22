import Foundation

/// Remembered places (story 2.12, approved Nov 21, 2026): the bakery, florist or restaurant used before, offered
/// again on the same kind of item for anyone. Kept on the phone in a small list, no change to the stored model.
/// Story 2.14: a place with a ZIP code is offered only within 50 miles of the person, when both ZIP codes are known.
struct Place: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    /// The item kind it was used on (ActKind raw value). A baker shows on cakes, never on flowers or gifts.
    var kindRaw: String
    var name: String
    var link: String?
    var phone: String?
    /// Five-digit ZIP code, when known.
    var zip: String?
    var lastUsed: Date = Date()
}

enum Places {
    /// The kinds of item that have a "Where from" card instead of "Who it's from".
    static let kinds: Set<ActKind> = [.cake, .flowers, .dinner, .theDay]
    static let nearMiles: Double = 50

    static func hasWhereFrom(_ kind: ActKind) -> Bool { kinds.contains(kind) }

    /// The places to offer on an item of this kind for a person with this ZIP code, most recently used first.
    /// A place with a ZIP code farther than 50 miles from the person's is left out; a missing ZIP keeps the place.
    static func offered(_ all: [Place], kindRaw: String, personZip: String?,
                        centers: ZipCenters = .shared) -> [Place] {
        all.filter { $0.kindRaw == kindRaw }
            .filter { place in
                guard let miles = centers.miles(from: place.zip, to: personZip) else { return true }
                return miles <= nearMiles
            }
            .sorted { $0.lastUsed > $1.lastUsed }
    }

    /// Adds a place, or refreshes one with the same name on the same kind (case and spaces ignored).
    static func remembering(_ place: Place, in all: [Place]) -> [Place] {
        var list = all
        let key = normalized(place.name)
        if let i = list.firstIndex(where: { $0.kindRaw == place.kindRaw && normalized($0.name) == key }) {
            var kept = list[i]
            kept.name = place.name
            kept.link = place.link ?? kept.link
            kept.phone = place.phone ?? kept.phone
            kept.zip = place.zip ?? kept.zip
            kept.lastUsed = place.lastUsed
            list[i] = kept
        } else {
            list.append(place)
        }
        return list
    }

    /// The first five digits found at the end of an address or a typed ZIP code.
    static func zip(in text: String?) -> String? {
        guard let text else { return nil }
        let digits = text.split(whereSeparator: { !$0.isNumber && $0 != "-" }).map(String.init)
        for token in digits.reversed() {
            let five = token.split(separator: "-").first.map(String.init) ?? token
            if five.count == 5, five.allSatisfy(\.isNumber) { return five }
        }
        return nil
    }

    private static func normalized(_ s: String) -> String {
        s.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

/// Where the list lives: the app's own settings on this phone.
final class PlaceStore {
    static let shared = PlaceStore()
    private let defaults: UserDefaults
    private let key = "rememberedPlaces"
    private let chosenKey = "chosenPlaces"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var all: [Place] {
        get { (defaults.data(forKey: key)).flatMap { try? JSONDecoder().decode([Place].self, from: $0) } ?? [] }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: key) }
    }

    /// The place chosen for one item, by the item's id.
    func chosen(for actID: UUID) -> Place? {
        guard let map = defaults.dictionary(forKey: chosenKey) as? [String: String],
              let id = map[actID.uuidString].flatMap(UUID.init(uuidString:)) else { return nil }
        return all.first { $0.id == id }
    }

    func choose(_ place: Place?, for actID: UUID) {
        var map = (defaults.dictionary(forKey: chosenKey) as? [String: String]) ?? [:]
        if let place {
            var touched = place
            touched.lastUsed = Date()
            all = Places.remembering(touched, in: all)
            let saved = all.first { $0.kindRaw == place.kindRaw && $0.name.lowercased() == place.name.lowercased() }
            map[actID.uuidString] = (saved ?? place).id.uuidString
        } else {
            map[actID.uuidString] = nil
        }
        defaults.set(map, forKey: chosenKey)
    }

    func forget(_ place: Place) {
        all.removeAll { $0.id == place.id }
        var map = (defaults.dictionary(forKey: chosenKey) as? [String: String]) ?? [:]
        map = map.filter { $0.value != place.id.uuidString }
        defaults.set(map, forKey: chosenKey)
    }
}

/// Addresses kept in settings by builds before store version 3 (story 2.13, by person id). Read once, when the copy
/// to version 3 moves each onto its person (Person.mailingAddress); nothing writes here any more.
final class SavedAddresses {
    static let shared = SavedAddresses()
    private let defaults: UserDefaults
    private let key = "savedAddresses"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func address(for personID: UUID) -> MailAddress? {
        guard let data = defaults.data(forKey: key),
              let map = try? JSONDecoder().decode([String: MailAddress].self, from: data) else { return nil }
        return map[personID.uuidString]
    }

    func set(_ address: MailAddress?, for personID: UUID) {
        var map = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([String: MailAddress].self, from: $0) } ?? [:]
        map[personID.uuidString] = address
        defaults.set(try? JSONEncoder().encode(map), forKey: key)
    }

    /// Everything kept, for the data export.
    var all: [String: MailAddress] {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([String: MailAddress].self, from: $0) } ?? [:]
    }
}

/// US ZIP code centers from Census public data, built into the app (story 2.14). Nothing is looked up online.
struct ZipCenters {
    static let shared = ZipCenters(bundleFile: "zip-centers")
    /// ZIP code to (latitude, longitude) in degrees.
    private let centers: [String: (Double, Double)]

    init(centers: [String: (Double, Double)]) { self.centers = centers }

    init(bundleFile: String) {
        guard let url = Bundle.main.url(forResource: bundleFile, withExtension: "csv"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { self.init(centers: [:]); return }
        self.init(csv: text)
    }

    /// Lines of "zip,lat,lon", latitude and longitude in hundredths of a degree.
    init(csv: String) {
        var map: [String: (Double, Double)] = [:]
        map.reserveCapacity(34_000)
        for line in csv.split(separator: "\n") {
            let f = line.split(separator: ",")
            guard f.count == 3, let la = Double(f[1]), let lo = Double(f[2]) else { continue }
            map[String(f[0])] = (la / 100, lo / 100)
        }
        centers = map
    }

    var isEmpty: Bool { centers.isEmpty }

    /// Miles between two ZIP code centers, or nil when either is missing or unknown.
    func miles(from a: String?, to b: String?) -> Double? {
        guard let a, let b, let p = centers[a], let q = centers[b] else { return nil }
        return Self.miles(p, q)
    }

    /// Great-circle distance in miles.
    static func miles(_ p: (Double, Double), _ q: (Double, Double)) -> Double {
        let r = 3958.8
        let toRad = Double.pi / 180
        let dLat = (q.0 - p.0) * toRad, dLon = (q.1 - p.1) * toRad
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(p.0 * toRad) * cos(q.0 * toRad) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * asin(min(1, sqrt(h)))
    }
}
