import Foundation

/// Everything the alert planner needs to know about one Moment, as plain values.
struct MomentState: Equatable {
    var id: UUID
    var personName: String
    var ring: Ring
    /// Start of the occasion's day.
    var dueDate: Date
    var status: MomentStatus
    var planKind: ActKind?
    var planTitle: String? = nil
    var planDone: Bool
    var greetingDone: Bool
    var anyActDone: Bool
    var openWishCount: Int
    var hasPhone: Bool
    var turning: Int?
    /// When the heads-up was (or will be) delivered. Set once, so a late heads-up is not repeated.
    var headsUpAt: Date?
}

enum AlertKind: String {
    case wishPrompt, headsUp, nudge, cutoff, dayOf, missed, season, grouped
}

struct PlannedAlert: Equatable {
    var id: String
    var kind: AlertKind
    var fireDate: Date
    var body: String
    var momentID: UUID?
    var category: String?
    /// For season alerts: the first day of the busy month.
    var monthStart: Date?
}

/// A month with several birthdays that need planning (overlap insight S1).
struct Season: Equatable {
    var monthStart: Date
    var momentIDs: [UUID]
}

enum NotificationCategory {
    static let dayOfCall = "dayof.call"
    static let dayOfMessage = "dayof.message"
    static let dayOfOpen = "dayof.open"
    static let actionCall = "CALL"
    static let actionMessage = "MESSAGE"
    static let actionOpen = "OPEN"
}

/// Turns Moments into the notifications the journey calls for (C1, B3, C2 nudges, C3 cutoff, D1, F1, S1).
/// Pure: the caller schedules the result and stores `headsUpUpdates`.
enum AlertPlanner {
    /// iOS keeps 64 pending notifications per app; leave room for one-off alerts.
    static let maxAlerts = 60
    static let maxNudges = 2
    static let nudgeGapDays = 3
    /// A month with at least this many inner- or middle-ring birthdays gets one early heads-up.
    static let seasonThreshold = 3

    static func plan(moments: [MomentState], seasons: [Season], now: Date,
                     calendar: Calendar = .current) -> (alerts: [PlannedAlert], headsUpUpdates: [UUID: Date]) {
        var alerts: [PlannedAlert] = []
        var updates: [UUID: Date] = [:]
        typealias D = OccasionDates

        for m in moments {
            if m.status.isSettled { continue }
            let due9 = D.alertTime(on: m.dueDate, calendar: calendar)
            let name = m.personName

            // B3: inner ring, 60 days out, only when nothing is saved yet. Not repeated if missed.
            if m.ring == .inner, m.status == .upcoming, m.openWishCount == 0 {
                let fire = D.alertTime(on: D.adding(days: -D.wishPromptDays, to: m.dueDate, calendar: calendar), calendar: calendar)
                if fire > now {
                    alerts.append(PlannedAlert(id: "wish-\(m.id)", kind: .wishPrompt, fireDate: fire,
                                               body: "Has \(name) mentioned wanting anything lately?", momentID: m.id))
                }
            }

            // C1: heads-up by ring. Added closer than the lead time: the next morning instead.
            if m.ring != .outer, m.status == .upcoming {
                let lead = D.alertTime(on: D.adding(days: -m.ring.leadDays, to: m.dueDate, calendar: calendar), calendar: calendar)
                let fire = m.headsUpAt ?? (lead > now ? lead : D.nextMorning(after: now, calendar: calendar))
                if fire < due9 {
                    if m.headsUpAt == nil { updates[m.id] = fire }
                    if fire > now {
                        alerts.append(PlannedAlert(id: "headsup-\(m.id)", kind: .headsUp, fireDate: fire,
                                                   body: headsUpText(m, from: fire, calendar: calendar), momentID: m.id))
                    }
                    // C2 closed without choosing: nudged again in 3 days, at most twice (inner ring).
                    if m.ring == .inner {
                        for n in 1...maxNudges {
                            let nudge = D.adding(days: n * nudgeGapDays, to: fire, calendar: calendar)
                            if nudge > now && nudge < D.adding(days: -1, to: due9, calendar: calendar) {
                                let days = D.daysBetween(nudge, m.dueDate, calendar: calendar)
                                let tail = m.openWishCount > 0 ? "Your saved ideas are ready." : "Pick one thing and Held Dear sets it up."
                                alerts.append(PlannedAlert(id: "nudge\(n)-\(m.id)", kind: .nudge, fireDate: nudge,
                                                           body: "\(name)'s birthday is in \(days) days. \(tail)", momentID: m.id))
                            }
                        }
                    }
                }
            }

            // C3: one reminder on the order-by or mail-by morning if the plan is not done.
            if m.status == .planning, let kind = m.planKind, kind.hasCutoff, !m.planDone {
                let fire = D.alertTime(on: D.adding(days: -D.cutoffDays, to: m.dueDate, calendar: calendar), calendar: calendar)
                if fire > now {
                    let body = kind == .gift
                        ? "Today is the order-by day for \(name)'s gift."
                        : "Today is the mail-by day for \(name)'s card."
                    alerts.append(PlannedAlert(id: "cutoff-\(m.id)", kind: .cutoff, fireDate: fire, body: body, momentID: m.id))
                }
            }

            // D1: the morning of, with the act already chosen.
            if !m.greetingDone, m.status != .missed, due9 > now {
                alerts.append(PlannedAlert(id: "dayof-\(m.id)", kind: .dayOf, fireDate: due9,
                                           body: dayOfText(m), momentID: m.id, category: dayOfCategory(m)))
            }

            // F1: the next morning, only if nothing was done.
            if !m.anyActDone, m.status == .upcoming || m.status == .planning {
                let fire = D.alertTime(on: D.adding(days: 1, to: m.dueDate, calendar: calendar), calendar: calendar)
                if fire > now {
                    alerts.append(PlannedAlert(id: "missed-\(m.id)", kind: .missed, fireDate: fire,
                                               body: "\(name)'s birthday was yesterday. A late note still counts.", momentID: m.id))
                }
            }
        }

        // S1: one early heads-up for a busy month, 3 weeks before it starts.
        for s in seasons {
            let fire = D.alertTime(on: D.adding(days: -21, to: s.monthStart, calendar: calendar), calendar: calendar)
            guard fire > now else { continue }
            let month = s.monthStart.formatted(.dateTime.month(.wide))
            alerts.append(PlannedAlert(id: "season-\(month)-\(calendar.component(.year, from: s.monthStart))", kind: .season,
                                       fireDate: fire,
                                       body: "\(month) is a big month. \(s.momentIDs.count) of your people have birthdays in it.",
                                       monthStart: s.monthStart))
        }

        alerts = groupHeadsUps(alerts, names: Dictionary(uniqueKeysWithValues: moments.map { ($0.id, $0.personName) }), calendar: calendar)
        alerts.sort { $0.fireDate == $1.fireDate ? $0.id < $1.id : $0.fireDate < $1.fireDate }
        return (Array(alerts.prefix(maxAlerts)), updates)
    }

    /// Two or more heads-ups on the same morning become one alert that opens Home.
    static func groupHeadsUps(_ alerts: [PlannedAlert], names: [UUID: String], calendar: Calendar = .current) -> [PlannedAlert] {
        let heads = alerts.filter { $0.kind == .headsUp }
        let byDay = Dictionary(grouping: heads) { calendar.startOfDay(for: $0.fireDate) }
        var result = alerts.filter { $0.kind != .headsUp }
        for (day, group) in byDay {
            if group.count == 1 { result.append(group[0]); continue }
            let who = group.compactMap { $0.momentID.flatMap { names[$0] } }.sorted()
            let list = who.count == 2 ? "\(who[0]) and \(who[1])" : who.dropLast().joined(separator: ", ") + ", and " + (who.last ?? "")
            result.append(PlannedAlert(id: "grouped-\(Int(day.timeIntervalSince1970))", kind: .grouped,
                                       fireDate: group[0].fireDate,
                                       body: "\(group.count) birthdays coming up: \(list).", momentID: nil))
        }
        return result
    }

    static func headsUpText(_ m: MomentState, from fire: Date, calendar: Calendar = .current) -> String {
        let days = OccasionDates.daysBetween(fire, m.dueDate, calendar: calendar)
        let when: String
        switch days {
        case 1: when = "tomorrow"
        case 7: when = "next week"
        case 14: when = "in 2 weeks"
        case 21: when = "in 3 weeks"
        default: when = "in \(days) days"
        }
        var text = "\(m.personName)'s birthday is \(when)."
        if m.openWishCount == 1 { text += " You saved 1 idea." }
        if m.openWishCount > 1 { text += " You saved \(m.openWishCount) ideas." }
        return text
    }

    static func dayOfText(_ m: MomentState) -> String {
        var text = "It's \(m.personName)'s birthday."
        if let t = m.turning { text += " Turning \(t) today." }
        if m.planDone, let kind = m.planKind {
            switch kind {
            case .gift: text += " Your gift is on its way."
            case .card: text += " Your card is in the mail."
            case .dinner: text += " Dinner is on the calendar."
            default: break
            }
        }
        return text
    }

    static func dayOfCategory(_ m: MomentState) -> String {
        if !m.hasPhone { return NotificationCategory.dayOfOpen }
        if m.planKind == .call && !m.planDone { return NotificationCategory.dayOfCall }
        return NotificationCategory.dayOfMessage
    }

    /// Months in the next year with several inner- or middle-ring birthdays.
    static func seasons(from moments: [MomentState], now: Date, calendar: Calendar = .current) -> [Season] {
        let candidates = moments.filter { $0.ring != .outer && !$0.status.isSettled && $0.dueDate >= calendar.startOfDay(for: now) }
        let byMonth = Dictionary(grouping: candidates) { m -> Date in
            calendar.date(from: calendar.dateComponents([.year, .month], from: m.dueDate))!
        }
        return byMonth.compactMap { month, ms in
            ms.count >= seasonThreshold ? Season(monthStart: month, momentIDs: ms.sorted { $0.dueDate < $1.dueDate }.map(\.id)) : nil
        }.sorted { $0.monthStart < $1.monthStart }
    }
}

/// One stop on a person's "What Held Dear will do" timeline.
struct ScheduleStop: Equatable {
    var date: Date
    var label: String
    var showsTime: Bool
}

extension AlertPlanner {
    /// The coming stops for one Moment, from the same rules that schedule the alerts.
    static func schedule(for m: MomentState, calendar: Calendar = .current) -> [ScheduleStop] {
        let farPast = OccasionDates.adding(days: -400, to: m.dueDate, calendar: calendar)
        let alerts = plan(moments: [m], seasons: [], now: farPast, calendar: calendar).alerts
        return alerts.compactMap { a -> ScheduleStop? in
            switch a.kind {
            case .wishPrompt: return ScheduleStop(date: a.fireDate, label: "A question about wishes", showsTime: false)
            case .headsUp, .grouped:
                return ScheduleStop(date: a.fireDate, label: m.ring == .inner ? "A heads-up and a plan" : "A heads-up", showsTime: false)
            case .cutoff:
                return ScheduleStop(date: a.fireDate, label: m.planKind == .card ? "Mail by, for the card" : "Order by, for the gift", showsTime: false)
            case .dayOf:
                return ScheduleStop(date: a.fireDate, label: m.planKind == .call && !m.planDone ? "A call, one tap away" : "A message ready", showsTime: true)
            default: return nil
            }
        }
    }
}
