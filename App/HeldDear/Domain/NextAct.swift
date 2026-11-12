import Foundation

/// What the Home hero offers for a Moment: one button that follows the Moment's state.
enum NextAct: Equatable {
    case lateNote                 // missed, within grace
    case dayOfCall                // today, a call is the plan
    case dayOfMessage             // today
    case pick                     // nothing chosen yet
    case saveWish                 // more than 99 days out, nothing to do yet
    case orderBy(Date)            // gift not done
    case mailBy(Date)             // card not done
    case addDinner                // dinner not on the calendar yet
    case readyOnTheDay(Date)      // call or message, set up for the morning of
    case finishOther(String)      // "something else" not done
    case allSet                   // plan done before the day

    /// Far enough away that the hero shows months and a gentle secondary button.
    static let farDays = 99

    static func make(_ m: MomentState, now: Date, calendar: Calendar = .current) -> NextAct {
        let days = OccasionDates.daysBetween(now, m.dueDate, calendar: calendar)
        if m.status == .missed { return .lateNote }
        if days == 0 {
            if m.planKind == .call && !m.planDone && m.hasPhone { return .dayOfCall }
            return .dayOfMessage
        }
        if m.planDone || m.status == .done { return .allSet }
        let cutoff = OccasionDates.adding(days: -OccasionDates.cutoffDays, to: m.dueDate, calendar: calendar)
        if m.status == .planning, let kind = m.planKind {
            switch kind {
            case .gift: return .orderBy(cutoff)
            case .card: return .mailBy(cutoff)
            case .dinner: return .addDinner
            case .call, .message: return .readyOnTheDay(m.dueDate)
            case .other: return .finishOther(m.planTitle ?? "Something special")
            }
        }
        return days > farDays ? .saveWish : .pick
    }

    func title(name: String) -> String {
        switch self {
        case .lateNote: return "Send a late note"
        case .dayOfCall: return "Call \(name)"
        case .dayOfMessage: return "Send \(name) a message"
        case .pick: return "Pick what to do"
        case .saveWish: return "Save a wish for \(name)"
        case .orderBy(let d): return "Order by \(d.formatted(.dateTime.month(.abbreviated).day()))"
        case .mailBy(let d): return "Mail by \(d.formatted(.dateTime.month(.abbreviated).day()))"
        case .addDinner: return "Add dinner to calendar"
        case .readyOnTheDay(let d): return "Ready on \(d.formatted(.dateTime.month(.abbreviated).day()))"
        case .finishOther(let t): return t
        case .allSet: return "All set"
        }
    }

    /// The gentle states use a secondary button; everything else is the one primary.
    var isGentle: Bool {
        switch self {
        case .saveWish, .allSet, .readyOnTheDay: return true
        default: return false
        }
    }
}

/// The hero: a just-missed birthday still in grace, otherwise the soonest one.
enum HeroPicker {
    static func pick(_ moments: [MomentState], now: Date, calendar: Calendar = .current) -> MomentState? {
        let today = calendar.startOfDay(for: now)
        if let missed = moments.filter({ $0.status == .missed }).max(by: { $0.dueDate < $1.dueDate }) { return missed }
        return moments.filter { $0.dueDate >= today && !$0.status.isSettled || ($0.status == .done && $0.dueDate >= today) }
            .min { $0.dueDate == $1.dueDate ? $0.personName < $1.personName : $0.dueDate < $1.dueDate }
    }
}
