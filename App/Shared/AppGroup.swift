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

/// What the "Next person up" widget shows.
struct WidgetSnapshot: Codable {
    struct Entry: Codable {
        var momentID: UUID
        var name: String
        var occasion: String
        var dueDate: Date
        var detail: String?
    }
    var next: [Entry]
    var writtenAt: Date
}
