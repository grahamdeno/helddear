import ActivityKit
import Foundation

/// Starts and ends the Lock Screen cards (Graham, Nov 22, 2026). Runs when the app comes forward, since iOS lets
/// an app start one only then. The person can turn them off for Held Dear in iOS Settings.
@MainActor
enum LiveDayService {
    static func sync(days: [LiveDays.Day], arrivals: [LiveDays.Arrival], lines: [UUID: (line: String, ready: Int, total: Int)],
                     initialsOnly: Bool, initials: [UUID: String], now: Date = Date()) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        var wanted: [String: (DayActivityAttributes, DayActivityAttributes.ContentState, Date)] = [:]
        for d in LiveDays.days(days, now: now) {
            let title = initialsOnly ? (initials[d.id] ?? "A day") : d.title
            let a = DayActivityAttributes(kind: .day, id: d.id.uuidString, title: title, date: d.dueDate)
            let l = lines[d.id] ?? ("Today", 0, 0)
            wanted[a.key] = (a, .init(line: l.line, ready: l.ready, total: l.total), LiveDays.endOfDay(d.dueDate))
        }
        for x in LiveDays.arrivals(arrivals, now: now) {
            let title = initialsOnly ? (initials[x.id] ?? "Something") : x.title
            let a = DayActivityAttributes(kind: .arrival, id: x.id.uuidString, title: title, date: x.arrives)
            wanted[a.key] = (a, .init(line: LiveDays.arrivalLine(x.arrives, now: now), ready: 0, total: 0), LiveDays.endOfDay(x.arrives))
        }
        let running = Activity<DayActivityAttributes>.activities
        for activity in running {
            if let w = wanted[activity.attributes.key] {
                Task { await activity.update(ActivityContent(state: w.1, staleDate: w.2)) }
            } else {
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
            }
        }
        let have = Set(running.map(\.attributes.key))
        for (key, w) in wanted where !have.contains(key) {
            _ = try? Activity.request(attributes: w.0, content: ActivityContent(state: w.1, staleDate: w.2), pushType: nil)
        }
    }
}
