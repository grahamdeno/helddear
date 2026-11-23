import Foundation

/// Coming alerts the user turned off, one at a time, from a person's "Coming up from Held Dear" (Graham, Nov 22,
/// 2026). Kept on this phone by the alert's id; each id belongs to one day of one person, so next year's alerts
/// come as usual.
enum CancelledAlerts {
    private static let key = "cancelledAlertIDs"

    static func all(_ d: UserDefaults = .standard) -> Set<String> { Set(d.stringArray(forKey: key) ?? []) }
    static func isOff(_ id: String, _ d: UserDefaults = .standard) -> Bool { all(d).contains(id) }

    static func set(_ id: String, off: Bool, _ d: UserDefaults = .standard) {
        var s = all(d)
        if off { s.insert(id) } else { s.remove(id) }
        d.set(Array(s), forKey: key)
    }

    static func filter(_ ids: [String], _ d: UserDefaults = .standard) -> [String] {
        let off = all(d)
        return ids.filter { !off.contains($0) }
    }
}
