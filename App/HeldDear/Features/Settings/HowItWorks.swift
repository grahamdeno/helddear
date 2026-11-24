import SwiftUI

/// "How Held Dear works" (UX-12, Nov 24, 2026): one plain page, opened from You, for anyone who wants the whole idea
/// in a minute. Each section is a heading and a few short lines, read top to bottom; nothing on it can be tapped.
struct HowItWorksView: View {
    struct Section: Identifiable {
        let id: String
        let icon: String
        let lines: [String]
    }

    static let sections: [Section] = [
        Section(id: "Your people", icon: "person.2", lines: [
            "Held Dear finds the birthdays saved in your contacts, and you choose who matters.",
            "To add someone by hand, tap + Add on Home.",
        ]),
        Section(id: "Home", icon: "house", lines: [
            "The big name is whoever's day comes next.",
            "Swipe the name left or right to move through the year.",
            "The line at the bottom shows everyone coming up. Tap a name on it to see that day.",
        ]),
        Section(id: "A plan for each day", icon: "checklist", lines: [
            "A day is a few parts, like a card, a call, a gift or a cake.",
            "Each part says who's doing it and by when. Home shows how many are ready.",
        ]),
        Section(id: "Ideas", icon: "gift", lines: [
            "Save an idea for someone whenever you think of it.",
            "It's waiting for you when their day comes.",
        ]),
        Section(id: "Alerts", icon: "bell", lines: [
            "Held Dear lets you know early enough to plan, and again on the day.",
            "Turn alerts on or off in You, under Alerts.",
        ]),
        Section(id: "Each year", icon: "book.closed", lines: [
            "After each day, Held Dear keeps one line about what you did, so you can look back.",
        ]),
        Section(id: "Your data", icon: "lock", lines: [
            "Everything stays on your iPhone, and in your own iCloud if you turn it on.",
            "To remove everything, go to You, then Export and import, then Delete all my data.",
        ]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Brand.space5) {
            ForEach(Self.sections) { section in
                VStack(alignment: .leading, spacing: Brand.space2) {
                    Label {
                        Text(section.id).textStyle(.bodyStrong)
                    } icon: {
                        Image(systemName: section.icon).foregroundStyle(Brand.action)
                    }
                    .accessibilityAddTraits(.isHeader)
                    ForEach(section.lines, id: \.self) { line in
                        Text(line).textStyle(.body).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
