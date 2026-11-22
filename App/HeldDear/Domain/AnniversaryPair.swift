import Foundation

/// Two photos for an anniversary (approved Nov 21, 2026): the person's, and the other half of the couple's when
/// it's known. Plain rules, unit tested; views only draw the result.
enum PairSide: Equatable {
    /// Another person in the app.
    case person(UUID)
    /// The user: the anniversary is theirs.
    case you
    /// Only a typed name: shown as initials.
    case initials(String)
}

enum AnniversaryPair {
    struct Someone { let id: UUID; let name: String; let fullName: String }

    /// The other half of an anniversary, or nil when there's nothing to pair (not an anniversary, or no partner).
    /// The user's own anniversary is one whose partner is the user's name, or "you".
    static func partner(type: OccasionType, partnerName: String?, extraRecipientIDs: [UUID], ownerID: UUID,
                        people: [Someone], yourName: String) -> PairSide? {
        guard type == .anniversary else { return nil }
        let typed = partnerName.map { DisplayName.plain($0).trimmingCharacters(in: .whitespaces) } ?? ""
        let you = DisplayName.plain(yourName).trimmingCharacters(in: .whitespaces)
        if !typed.isEmpty {
            if typed.lowercased() == "you" || (!you.isEmpty && typed.lowercased() == you.lowercased()) { return .you }
            if let match = people.first(where: { $0.id != ownerID && NameCleanup.isSamePerson(typed, name: $0.name, fullName: $0.fullName) }) {
                return .person(match.id)
            }
        }
        if let id = extraRecipientIDs.first(where: { id in id != ownerID && people.contains { $0.id == id } }) { return .person(id) }
        if !typed.isEmpty { return .initials(typed) }
        return nil
    }

    /// One or two letters for a typed name.
    static func initials(_ name: String) -> String {
        let letters = DisplayName.plain(name).split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}

/// The user's own photo and dates, kept in settings on this iPhone (and in iCloud with sync on).
enum YouProfile {
    static let photoKey = "yourPhotoFile"
    static let birthdayKey = "yourBirthday"

    static var photoFile: String? {
        get { UserDefaults.standard.string(forKey: photoKey) }
        set { UserDefaults.standard.set(newValue, forKey: photoKey) }
    }

    /// Month, day and an optional year.
    struct Day: Codable, Equatable { var month: Int; var day: Int; var year: Int? }

    static func birthday(_ d: UserDefaults = .standard) -> Day? {
        d.data(forKey: birthdayKey).flatMap { try? JSONDecoder().decode(Day.self, from: $0) }
    }

    static func setBirthday(_ day: Day?, _ d: UserDefaults = .standard) {
        d.set(day.flatMap { try? JSONEncoder().encode($0) }, forKey: birthdayKey)
    }
}
