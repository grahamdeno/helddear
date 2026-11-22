import Foundation

/// A picture for one occasion, like a couple's photo for an anniversary (Graham, Nov 21, 2026). The occasion is
/// stored once, so the photo set from the You page or from the partner's page is the same photo on both. The
/// photo file lives with the app's photos (and in iCloud with them); this keeps which file belongs to which day,
/// in the settings that sync through iCloud.
enum OccasionPhotos {
    static let key = "occasionPhotos"

    static func file(for occasionID: UUID?, _ d: UserDefaults = .standard) -> String? {
        guard let id = occasionID else { return nil }
        return (d.dictionary(forKey: key) as? [String: String])?[id.uuidString]
    }

    static func set(_ file: String?, for occasionID: UUID, _ d: UserDefaults = .standard) {
        var all = (d.dictionary(forKey: key) as? [String: String]) ?? [:]
        all[occasionID.uuidString] = file
        d.set(all, forKey: key)
    }
}
