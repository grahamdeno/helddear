import Foundation

/// Demo mode for the accessibility walk (Story E, Nov 24, 2026). Debug builds only, and only with the launch argument
/// `-HeldDearDemo`: an in-memory store (never the real one, never iCloud), made-up people with days spread over the
/// coming months, onboarding done, and no system permission prompts. Dates are relative to the day it runs, so every
/// screen has something to show. `-HeldDearDemoHeavy` adds 300 people and odd names for the heavy-data journey.
enum DemoMode {
    static var on: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-HeldDearDemo")
        #else
        false
        #endif
    }

    static var heavy: Bool { on && ProcessInfo.processInfo.arguments.contains("-HeldDearDemoHeavy") }

    /// `-HeldDearDemoEmpty`: no people and onboarding not done, for the walk with every permission denied.
    static var empty: Bool { on && ProcessInfo.processInfo.arguments.contains("-HeldDearDemoEmpty") }

    /// `-HeldDearDemoTips`: first-use tips show (the walk hides them otherwise), Ben gets a started plan so his
    /// page has the plan tip, and Ada and Ben get Christmas so the holiday page has its tip. `-HeldDearDemoTipsReset` also marks every tip unseen at launch.
    static var tips: Bool { on && ProcessInfo.processInfo.arguments.contains("-HeldDearDemoTips") }
    static var hidesTips: Bool { on && !tips }

    /// `-HeldDearDemoFreeNoAI` (walk setup "free-no-ai", Nov 28, 2026): an iPhone without Apple Intelligence and
    /// without Lifetime, at the free plan limit. Ben, Cora and Dev have started plans (the three free ones), Elsie has a
    /// plan not yet started, and Ada has nothing saved, so Home offers "Plan Ada's birthday" (U2) and starting Elsie's
    /// plan opens Lifetime naming the three (U4).
    static var freeNoAI: Bool { on && ProcessInfo.processInfo.arguments.contains("-HeldDearDemoFreeNoAI") }

    /// Made-up people only (the privacy guard checks names): name, days from today to the birthday, ring.
    static let people: [(name: String, inDays: Int, ring: Ring)] = [
        ("Ada", 3, .inner), ("Ben", 12, .inner), ("Cora", 26, .middle), ("Dev", 41, .middle),
        ("Elsie", 63, .outer), ("Fitz", 95, .outer), ("Gwen", 140, .outer), ("Hal", 220, .outer),
    ]

    static let oddNames = ["Maximiliana Theodora Wilhelmina Featherstonehaugh-Cholmondeley", "ليلى", "さくら", "Zoë 🌻"]

    @MainActor
    static func seed(_ model: AppModel) {
        guard on else { return }
        if empty {
            model.onboarded = false
            model.firstVisitCardDismissed = false
            model.commit()
            return
        }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func add(_ name: String, _ days: Int, _ ring: Ring, year: Int?) {
            let date = cal.date(byAdding: .day, value: days, to: today)!
            let c = cal.dateComponents([.month, .day], from: date)
            _ = model.addPerson(name: name, fullName: name, contactID: nil, month: c.month!, day: c.day!, year: year, ring: ring)
        }
        for (i, p) in people.enumerated() { add(p.name, p.inDays, p.ring, year: 1960 + i * 7) }
        if heavy {
            for (i, n) in oddNames.enumerated() { add(n, 5 + i * 9, .outer, year: nil) }
            for i in 0..<300 { add("Person \(i + 1)", (i * 7) % 365, .outer, year: nil) }
        }
        if tips {
            if ProcessInfo.processInfo.arguments.contains("-HeldDearDemoTipsReset") { FirstUseTips.resetAll() }
            // Christmas for two people, so the holiday page (and its tip) exists.
            for name in ["Ada", "Ben"] {
                if let p = model.allPeople().first(where: { $0.name == name }) {
                    model.addOccasion(p, type: .christmas, month: 12, day: 25, year: nil)
                }
            }
            if let ben = model.allPeople().first(where: { $0.name == "Ben" }), let m = model.nextMoment(for: ben) {
                for s in PartSuggestions.starter(for: m.type, relationship: ben.relationship) {
                    _ = model.addPart(to: m, kind: s.kind, label: s.label)
                }
            }
        }
        if freeNoAI {
            func startPlan(_ name: String, started: Bool) {
                guard let p = model.allPeople().first(where: { $0.name == name }), let m = model.nextMoment(for: p) else { return }
                for s in PartSuggestions.starter(for: m.type, relationship: p.relationship) {
                    _ = model.addPart(to: m, kind: s.kind, label: s.label)
                }
                if started, let first = m.planParts.first { model.setStep(first, "idea") }
            }
            for name in ["Ben", "Cora", "Dev"] { startPlan(name, started: true) }
            startPlan("Elsie", started: false)
        }
        if !freeNoAI, let ada = model.allPeople().first(where: { $0.name == "Ada" }) {
            model.addWish(to: ada, text: "A watercolor class for two")
        }
        model.onboarded = true
        model.firstVisitCardDismissed = true
        model.commit()
    }
}
