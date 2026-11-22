import Foundation

/// Files shared with the share extension and the widget through the App Group container.
/// The app writes a small people snapshot and a widget snapshot; the share extension writes wishes to an inbox
/// that the app imports the next time it is active. Nothing here leaves the phone.
enum AppGroup {
    static let identifier = "group.com.grahamdeno.helddear"

    static var container: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) {
            return url
        }
        // Simulator builds without signing have no App Group; fall back to Application Support.
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    static var peopleURL: URL { container.appendingPathComponent("people.json") }
    static var widgetURL: URL { container.appendingPathComponent("widget.json") }
    static var inboxDir: URL {
        let url = container.appendingPathComponent("Inbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func write<T: Encodable>(_ value: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(value) { try? data.write(to: url, options: .atomic) }
    }

    static func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }
}

/// One person, as the share extension needs to show them under "Who is this for?".
struct SharedPerson: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var isInner: Bool
}

/// A wish captured in the share extension, waiting for the app to file it on the person.
struct InboxWish: Codable {
    var id: UUID
    var personID: UUID
    var text: String
    var url: String?
    /// File name of a downscaled photo in the inbox folder, if one was shared.
    var imageFile: String?
    var capturedAt: Date
}

/// Photos shared from the Photos app for one person (Nov 22, 2026): the files sit in the inbox folder until Held
/// Dear opens and keeps the ones from their days, plus 30 more.
struct InboxPhotos: Codable {
    var id: UUID
    var personID: UUID
    var files: [String]
}

/// What the "Next person up" widget shows.
struct WidgetSnapshot: Codable {
    struct Entry: Codable {
        var momentID: UUID
        var name: String
        var occasion: String
        var dueDate: Date
        var detail: String?
        /// Inside 3 days, the act instead of the date: "Order today", "Message ready Tuesday".
        var soonLine: String?
        // Home Screen widgets (Nov 21, 2026). Optional so an older snapshot still reads.
        var personID: UUID? = nil
        /// A shared holiday shows once: its raw name ("christmas", "custom:Hanukkah") and year.
        var holidayRaw: String? = nil
        var year: Int? = nil
        var ready: Int? = nil
        var total: Int? = nil
        var people: Int? = nil
        /// The plan's next step, like "Order the flowers".
        var nextStep: String? = nil

        var isHoliday: Bool { holidayRaw != nil }

        /// Where a tap goes: the holiday's page, or the day.
        var link: URL {
            if let raw = holidayRaw, let year {
                var c = URLComponents()
                c.scheme = "helddear"; c.host = "holiday"
                c.queryItems = [URLQueryItem(name: "raw", value: raw), URLQueryItem(name: "year", value: "\(year)")]
                if let url = c.url { return url }
            }
            return URL(string: "helddear://moment?id=\(momentID.uuidString)")!
        }
    }
    var next: [Entry]
    var writtenAt: Date
    /// Each coming shared holiday once, for the holiday widget's choice.
    var holidays: [Entry]? = nil
}

extension AppGroup {
    /// Small faces for the Home Screen widgets, one per person, kept in the App Group.
    static var facesDir: URL {
        let url = container.appendingPathComponent("WidgetFaces", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    static func faceURL(_ personID: UUID) -> URL { facesDir.appendingPathComponent("\(personID.uuidString).jpg") }
    /// Faces show on the Home Screen widgets only when the user turns them on (off by default).
    static let widgetFacesKey = "homeWidgetFaces"
}
