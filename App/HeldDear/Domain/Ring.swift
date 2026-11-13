import Foundation

/// How close a person is. A per-person default; an occasion can override it (stage 4).
enum Ring: String, Codable, CaseIterable, Identifiable {
    case inner, middle, outer

    var id: String { rawValue }

    /// Days before the occasion that the heads-up arrives. Outer ring starts on the day.
    var leadDays: Int {
        switch self {
        case .inner: 21
        case .middle: 7
        case .outer: 0
        }
    }

    var label: String {
        switch self {
        case .inner: "Inner ring"
        case .middle: "Middle ring"
        case .outer: "Outer ring"
        }
    }

    var promise: String {
        switch self {
        case .inner: "3-week heads-up and a plan"
        case .middle: "1-week heads-up"
        case .outer: "A message ready on the day"
        }
    }
}

enum MomentStatus: String, Codable {
    case upcoming, planning, done, missed, lateSent, letGo, closed

    /// Finished one way or another; nothing more is asked of the user.
    var isSettled: Bool {
        switch self {
        case .done, .lateSent, .letGo, .closed: true
        case .upcoming, .planning, .missed: false
        }
    }
}

enum ActRole: String, Codable { case plan, greeting }

enum ActKind: String, Codable {
    case gift, card, call, message, dinner, other

    /// Plans that need doing before the day, with an order-by or mail-by date.
    var hasCutoff: Bool { self == .gift || self == .card }
}

enum ConfirmedBy: String, Codable { case user, messageSent, callConnected, callConfirmed, calendar, mailed }

enum WishStatus: String, Codable { case open, used, dismissed }
