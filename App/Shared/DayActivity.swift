import ActivityKit
import Foundation

/// The Lock Screen card for a person's day, or for something arriving soon (Graham, Nov 22, 2026). Shared by the app,
/// which starts and ends it, and the widget extension, which draws it. Nothing leaves the phone.
struct DayActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// "Turning 40 today", "2 of 3 ready", "Arrives today".
        var line: String
        var ready: Int
        var total: Int
    }

    enum Kind: String, Codable { case day, arrival }

    var kind: Kind
    /// The Moment's id for a day, the item's id for an arrival.
    var id: String
    /// "Ada's birthday", "Ada's cake". Initials only when the Lock Screen setting asks for it.
    var title: String
    var date: Date

    var key: String { "\(kind.rawValue)-\(id)" }
    var link: URL? {
        URL(string: kind == .day ? "helddear://moment?id=\(id)" : "helddear://item?id=\(id)")
    }
}
