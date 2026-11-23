import Foundation

/// Demo mode for the UI walk (Story E, playbook standards/ux-audit.md). It exists only in debug builds and only with
/// the launch argument `-HeldDearDemo`; in a release build `isOn` is a constant false and nothing else here exists.
///
/// - `-demoDate 2026-12-10`: the app's date for the model rules that take one (default Dec 10, 2026).
/// - `-demoDays N`: moves that date N days on (journey 10, "away two weeks").
/// - `-demoPeople N`: how many made-up people (default 4; 0 shows the first-run screens; 300 for heavy data).
/// - `-demoOdd`: adds a 57-letter name and Arabic, Japanese and emoji names.
///
/// The store is in memory: nothing real is read and nothing is saved. No iCloud, Contacts, Photos or notifications.
enum DemoMode {
    #if DEBUG
    private static let arguments = ProcessInfo.processInfo.arguments

    static var isOn: Bool { arguments.contains("-HeldDearDemo") }

    private static func value(of flag: String) -> String? {
        guard let i = arguments.firstIndex(of: flag), i + 1 < arguments.count else { return nil }
        return arguments[i + 1]
    }

    /// The fixed date: noon on `-demoDate` (yyyy-MM-dd), Dec 10, 2026 when not given.
    static var baseDate: Date {
        let parts = (value(of: "-demoDate") ?? "2026-12-10").split(separator: "-").compactMap { Int($0) }
        var c = DateComponents()
        c.year = parts.count == 3 ? parts[0] : 2026
        c.month = parts.count == 3 ? parts[1] : 12
        c.day = parts.count == 3 ? parts[2] : 10
        c.hour = 12
        return Calendar.current.date(from: c) ?? Date()
    }

    static var days: Int { Int(value(of: "-demoDays") ?? "") ?? 0 }

    /// The demo clock: the fixed date plus `-demoDays`.
    static var now: Date { Calendar.current.date(byAdding: .day, value: days, to: baseDate) ?? baseDate }

    static var peopleCount: Int { max(0, Int(value(of: "-demoPeople") ?? "") ?? 4) }

    /// With no people the walk starts at the first-run screens; with people it starts at Home.
    static var onboarded: Bool { peopleCount > 0 }

    static var odd: Bool { arguments.contains("-demoOdd") }

    /// Made-up first names. None is a real family name (the privacy guard checks the code for those).
    static let names = ["Robin", "Jordan", "Casey", "Alex", "Morgan", "Riley", "Quinn", "Avery", "Sky", "Dana",
                        "Reese", "Emery", "Rowan", "Sage", "Blair", "Drew"]

    /// Days after the fixed date for the first people's birthdays, so Home has a next person, a soon one and a
    /// missed one once `-demoDays 14` moves the clock.
    private static let offsets = [3, 10, 17, 30, 45, 60, 90, 120, 150, 200, 250, 300]

    static func name(at index: Int) -> String {
        let base = names[index % names.count]
        return index < names.count ? base : "\(base) \(String(Character(UnicodeScalar(UInt8(65 + (index / names.count) % 26)))))"
    }

    /// Makes the people in `model`'s in-memory store. Called once from the model's init.
    @MainActor
    static func seed(into model: AppModel) {
        let calendar = Calendar.current
        var list: [String] = (0..<peopleCount).map { name(at: $0) }
        if odd {
            list += [String(String(repeating: "Mirabel", count: 9).prefix(57)), "نور", "さくら", "Sam 🎂"]
        }
        for (i, name) in list.enumerated() {
            let offset = i < offsets.count ? offsets[i] : 5 + (i * 7) % 360
            let date = calendar.date(byAdding: .day, value: offset, to: baseDate) ?? baseDate
            let c = calendar.dateComponents([.month, .day], from: date)
            _ = model.addPerson(name: name, fullName: nil, contactID: nil, month: c.month ?? 1, day: c.day ?? 1,
                                year: 1975 + (i * 3) % 40)
        }
        model.save()
    }
    #else
    static var isOn: Bool { false }
    static var now: Date { Date() }
    static var onboarded: Bool { false }
    #endif
}
