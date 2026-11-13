import Foundation
import SwiftData

/// Keeps Moments on a rolling 12-month window and moves them through their statuses.
/// No status counts against the user: a missed Moment closes quietly after 3 days.
enum MomentEngine {
    static let missedCloseDays = 3

    @MainActor
    static func refresh(_ context: ModelContext, now: Date = Date(), calendar: Calendar = .current) {
        let occasions = (try? context.fetch(FetchDescriptor<Occasion>())) ?? []
        for occasion in occasions where occasion.person != nil {
            for (year, date) in OccasionRules.occurrences(type: occasion.type, month: occasion.month, day: occasion.day, year: occasion.birthYear, from: now, calendar: calendar) {
                if let existing = occasion.moments.first(where: { $0.year == year }) {
                    // The date changed (edited birthday): keep the Moment, move its day, reset the heads-up.
                    if existing.dueDate != date && existing.status == .upcoming {
                        existing.dueDate = date
                        existing.headsUpAt = nil
                    }
                } else {
                    let m = Moment(year: year, dueDate: date)
                    context.insert(m)
                    m.occasion = occasion
                }
            }
            // A moved birthday can leave a stale, untouched Moment behind.
            let valid = Set(OccasionRules.occurrences(type: occasion.type, month: occasion.month, day: occasion.day, year: occasion.birthYear, from: now, calendar: calendar).map(\.year))
            for m in occasion.moments where m.status == .upcoming && m.acts.isEmpty && !valid.contains(m.year)
                && m.dueDate >= calendar.startOfDay(for: now) {
                context.delete(m)
            }
        }

        let today = calendar.startOfDay(for: now)
        let moments = (try? context.fetch(FetchDescriptor<Moment>())) ?? []
        for m in moments {
            switch m.status {
            case .upcoming, .planning:
                if m.plan?.isDone == true || (m.dueDate <= today && m.anyActDone) {
                    m.status = .done
                } else if OccasionDates.daysBetween(m.dueDate, today, calendar: calendar) >= 1 {
                    m.status = .missed
                    m.missedAt = now
                }
            case .missed:
                if OccasionDates.daysBetween(m.dueDate, today, calendar: calendar) > missedCloseDays { m.status = .closed }
            default:
                break
            }
        }
        try? context.save()
    }

    /// Upcoming and open Moments for Home, soonest first, within the next 12 months.
    @MainActor
    static func visibleMoments(_ context: ModelContext, now: Date = Date(), calendar: Calendar = .current) -> [Moment] {
        let today = calendar.startOfDay(for: now)
        let horizon = calendar.date(byAdding: .month, value: 12, to: today)!
        let all = (try? context.fetch(FetchDescriptor<Moment>(sortBy: [SortDescriptor(\.dueDate)]))) ?? []
        return all.filter { m in
            guard m.person != nil else { return false }
            if m.status == .missed { return true }
            if m.status == .done { return m.dueDate >= today && !m.greetingSent }
            return !m.status.isSettled && m.dueDate >= today && m.dueDate < horizon
        }
    }

    /// True when the Moment is waiting on the user right now (shown first on Home).
    static func needsAction(_ m: Moment, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let days = OccasionDates.daysBetween(now, m.dueDate, calendar: calendar)
        switch m.status {
        case .missed: return true
        case .upcoming: return days == 0 || (m.occasion?.effectiveRing ?? .outer) != .outer && days <= (m.occasion?.effectiveRing.leadDays ?? 0)
        case .planning:
            if days == 0 { return true }
            if let plan = m.plan, plan.kind.hasCutoff, !plan.isDone { return days <= OccasionDates.cutoffDays }
            return false
        case .done: return days == 0 && !m.greetingSent
        default: return false
        }
    }

    /// One line for the ledger: "Blue gardening gloves, and a photo message".
    static func whatWasDone(_ m: Moment) -> String {
        var parts: [String] = []
        if let plan = m.plan, plan.isDone {
            switch plan.kind {
            case .gift: parts.append(plan.title ?? "A gift")
            case .card: parts.append("A card")
            case .call: parts.append("A call")
            case .message: parts.append("A message")
            case .dinner: parts.append("Dinner together")
            case .other: parts.append(plan.title ?? "Something special")
            }
        }
        if let g = m.greeting, g.isDone {
            let text = g.kind == .call ? "a call" : (g.photoFile != nil ? "a photo message" : "a message")
            if parts.isEmpty || !sameKind(m, g) { parts.append(text) }
        }
        guard let first = parts.first else { return "A note" }
        if parts.count == 1 { return first.prefix(1).uppercased() + first.dropFirst() }
        return "\(first.prefix(1).uppercased() + first.dropFirst()), and \(parts[1])"
    }

    private static func sameKind(_ m: Moment, _ greeting: Act) -> Bool {
        guard let plan = m.plan, plan.isDone else { return false }
        return plan.kind == greeting.kind && (plan.kind == .call || plan.kind == .message)
    }
}
