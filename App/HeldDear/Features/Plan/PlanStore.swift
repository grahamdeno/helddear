import Foundation
import SwiftData

extension Moment {
    /// The plan parts in the order the plan shows them: sortOrder, then the order they were made.
    var planParts: [Act] {
        acts.filter { $0.role == .plan }.sorted {
            $0.sortOrder == $1.sortOrder ? $0.createdAt < $1.createdAt : $0.sortOrder < $1.sortOrder
        }
    }

    /// A moment planned on the plan screen: more than one plan part, or any plan part with a stored step.
    var isPlanMoment: Bool {
        let parts = planParts
        return PlanMoment.isPlanMoment(planParts: parts.count, anyStoredStep: parts.contains { $0.step != nil })
    }

    var partsReady: Int { planParts.filter(\.isReady).count }
}

/// Changes to a plan's parts, on the models only. `AppModel` calls these and then saves, so a screen and a test make
/// the same changes. Nothing here runs unless the user changes a step or adds a part.
enum PlanStore {
    /// A plan act the older one-thing flow made itself: nothing the plan screen stores is on it. The older flow may
    /// replace these; it never touches a part the plan screen made.
    static func isOldFlowPlan(_ a: Act) -> Bool {
        a.role == .plan && !a.isDone && a.step == nil && a.label == nil && a.note == nil && a.ownerIDs.isEmpty
    }

    /// Deletes only the unfinished plan acts the older flow made. Returns how many were deleted.
    @discardableResult
    static func removeOldFlowPlans(of m: Moment, in context: ModelContext) -> Int {
        let old = m.acts.filter(isOldFlowPlan)
        for act in old { context.delete(act) }
        return old.count
    }

    /// Keeps a plan moment's status in step with its parts. Older single plans are left exactly as they are, and
    /// missed, late, let go and closed moments never change here.
    static func syncStatus(_ m: Moment) {
        guard m.isPlanMoment else { return }
        let parts = m.planParts
        if let next = PlanMoment.status(current: m.status, ready: parts.filter(\.isReady).count, total: parts.count) {
            m.status = next
        }
    }

    /// Stores the step the user picked. Reaching the kind's ready step completes the part (and uses its wish);
    /// moving off it undoes both, so a stored step and the completed date can't drift apart.
    static func setStep(_ act: Act, to step: String, now: Date = Date()) {
        guard act.role == .plan else { return }
        let family = PartSteps.family(forKindRaw: act.kindRaw)
        guard PartSteps.isValid(step, family: family) else { return }
        act.step = step
        let m = act.moment
        if PartSteps.isReady(step: step, family: family) {
            if act.completedAt == nil { act.complete(.user, at: now) }
            if let wish = wish(for: act, in: m), wish.status == .open { wish.status = .used }
        } else {
            act.completedAt = nil
            act.confirmedRaw = nil
            if let wish = wish(for: act, in: m), wish.status == .used {
                let sharedByAnotherReadyPart = (m?.planParts ?? []).contains {
                    $0 !== act && $0.wishID == act.wishID && $0.isReady
                }
                if !sharedByAnotherReadyPart { wish.status = .open }
            }
        }
        if let m { syncStatus(m) }
    }

    /// The older flow's Done. A plan act with a stored step is completed through `setStep` at its kind's ready step,
    /// so its step, completed date, wish and the moment's status agree. Any other plan act is completed as before.
    /// Either way the status of a plan moment is then brought in step with its parts.
    static func completePlan(_ m: Moment, how: ConfirmedBy = .user) {
        if let plan = m.plan, plan.step != nil {
            setStep(plan, to: PartSteps.readyStep(for: PartSteps.family(forKindRaw: plan.kindRaw)))
        } else {
            m.plan?.complete(how)
            if let wishID = m.plan?.wishID, let wish = m.person?.wishes.first(where: { $0.id == wishID }) {
                wish.status = .used
            }
            m.status = .done
        }
        syncStatus(m)
    }

    /// Adds a part at the end: step not started, from You. The moment becomes a plan moment.
    @discardableResult
    static func addPart(to m: Moment, kind: ActKind, label: String?, in context: ModelContext) -> Act {
        let act = Act(role: .plan, kind: kind)
        let name = label?.trimmingCharacters(in: .whitespacesAndNewlines)
        act.label = (name?.isEmpty ?? true) ? nil : name
        act.step = "open"
        act.sortOrder = (m.planParts.map(\.sortOrder).max() ?? -1) + 1
        context.insert(act)
        act.moment = m
        syncStatus(m)
        return act
    }

    static func setOwners(_ act: Act, to ids: [UUID]) { act.ownerIDs = ids }

    static func setNote(_ act: Act, to text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        act.note = t.isEmpty ? nil : t
    }

    private static func wish(for act: Act, in m: Moment?) -> Wish? {
        guard let id = act.wishID else { return nil }
        return m?.person?.wishes.first { $0.id == id }
    }
}
