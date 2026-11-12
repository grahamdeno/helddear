import SwiftUI

/// Setup, once, under two minutes: A1 find birthdays, A2 choose the inner ring, A3 notifications.
struct OnboardingView: View {
    @EnvironmentObject var model: AppModel
    enum Step { case find, noneFound, denied, choose, notify }
    @State private var step: Step = .find
    @State private var addFirstAfterSetup = false

    var body: some View {
        ZStack {
            switch step {
            case .find: FindBirthdaysView(onResult: handleImport, onSkip: { addFirstAfterSetup = true; go(.notify) })
            case .noneFound:
                SetupMessage(title: "None of your contacts have birthdays yet",
                             detail: "Add the people you care about one at a time. It takes a few seconds each.",
                             button: "Add a birthday") { addFirstAfterSetup = true; go(.notify) }
            case .denied:
                SetupMessage(title: "Add people one at a time instead",
                             detail: "You can let Held Dear see your contacts later in Settings.",
                             button: "Add a birthday") { addFirstAfterSetup = true; go(.notify) }
            case .choose: ChooseInnerRingView { go(.notify) }
            case .notify: NotificationsSetupView(onDone: finish)
            }
        }
        .animation(.easeOut(duration: 0.25), value: step)
    }

    private func go(_ next: Step) {
        withAnimation(.easeOut(duration: 0.25)) { step = next }
    }

    private func handleImport(_ access: ContactsService.Access, _ count: Int) {
        switch access {
        case .full, .limited: go(count > 0 ? .choose : .noneFound)
        default: go(.denied)
        }
    }

    private func finish() {
        model.onboarded = true
        Task { await model.refresh() }
        if addFirstAfterSetup { model.route = .addBirthday }
    }
}

// MARK: A1

struct FindBirthdaysView: View {
    @EnvironmentObject var model: AppModel
    var onResult: (ContactsService.Access, Int) -> Void
    var onSkip: () -> Void
    @State private var working = false

    var body: some View {
        FlowScreen {
            HStack(spacing: Brand.space2) {
                ForEach(Array(["M", "D", "J", "A", "K"].enumerated()), id: \.offset) { i, letter in
                    Face(name: letter + "\(i)", initials: letter, image: nil, size: 56, fill: Brand.faceFills[i % 3])
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 80)
            Question(title: "Find the birthdays you already have")
            Text("Held Dear looks for birthdays already saved in your contacts. Nothing leaves your phone.")
                .textStyle(.body, color: Brand.ink.opacity(0.85))
        } footer: {
            PrimaryButton(title: working ? "Looking…" : "Allow contacts") { allow() }
                .disabled(working)
            TextLink(title: "Add people one at a time", action: onSkip)
        }
    }

    private func allow() {
        working = true
        Task {
            let access = await ContactsService.shared.requestAccess()
            var imported = 0
            if access == .full || access == .limited {
                imported = importContacts()
            }
            working = false
            onResult(access, imported)
        }
    }

    /// Pulls every birthday stored in contacts. Duplicates merge by contact link, silently.
    private func importContacts() -> Int {
        let existing = Set(model.allPeople().compactMap(\.contactID))
        var count = 0
        for c in ContactsService.shared.allContacts() {
            guard let month = c.month, let day = c.day, BirthdayParser.isValid(month: month, day: day),
                  !existing.contains(c.id) else { continue }
            let person = Person(name: c.displayName, fullName: c.fullName, contactID: c.id, ring: .outer)
            model.context.insert(person)
            let occasion = Occasion(month: month, day: day, birthYear: c.year)
            model.context.insert(occasion)
            occasion.person = person
            count += 1
        }
        MomentEngine.refresh(model.context)
        model.save()
        return count + existing.count
    }
}

struct SetupMessage: View {
    var title: String
    var detail: String
    var button: String
    var action: () -> Void

    var body: some View {
        FlowScreen {
            Spacer(minLength: 80)
            Question(title: title)
            Text(detail).textStyle(.body, color: Brand.ink.opacity(0.85))
        } footer: {
            PrimaryButton(title: button, action: action)
        }
    }
}

// MARK: A2

struct ChooseInnerRingView: View {
    @EnvironmentObject var model: AppModel
    var onDone: () -> Void
    @State private var picked: Set<UUID> = []
    @State private var search = ""
    @State private var people: [(person: Person, due: Date)] = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        FlowScreen {
            Question(title: "Who would you never want to miss?",
                     subtitle: "Pick a few. They get a 3-week heads-up. You can change this anytime.", style: .title)
            if people.count > 50 {
                TextField("Search", text: $search)
                    .textStyle(.body)
                    .padding(.horizontal, Brand.space4).frame(minHeight: 48)
                    .background(Brand.card, in: Capsule())
            }
            let shown = filtered
            if search.isEmpty {
                Eyebrow(text: "Coming up soonest")
                grid(Array(shown.prefix(12)))
                if shown.count > 12 {
                    Eyebrow(text: "Everyone else")
                    grid(Array(shown.dropFirst(12)))
                }
            } else {
                grid(shown)
            }
        } footer: {
            if !picked.isEmpty {
                Text("\(picked.count) picked").font(TypeStyle.callout.font.weight(.bold)).foregroundStyle(Brand.inkMuted)
            }
            PrimaryButton(title: picked.isEmpty ? "Skip for now" : "Done") {
                for entry in people where picked.contains(entry.person.id) { entry.person.ring = .inner }
                model.save()
                onDone()
            }
        }
        .onAppear(perform: load)
    }

    private var filtered: [(person: Person, due: Date)] {
        guard !search.isEmpty else { return people }
        return people.filter { $0.person.name.localizedCaseInsensitiveContains(search) || $0.person.fullName.localizedCaseInsensitiveContains(search) }
    }

    private func grid(_ items: [(person: Person, due: Date)]) -> some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(items, id: \.person.id) { item in
                let on = picked.contains(item.person.id)
                Button {
                    if on { picked.remove(item.person.id) } else { picked.insert(item.person.id) }
                } label: {
                    VStack(spacing: 6) {
                        ZStack(alignment: .bottomTrailing) {
                            Face(person: item.person, size: 64)
                                .padding(6)
                                .overlay(Circle().stroke(on ? Brand.action : Color.clear, lineWidth: 3))
                            if on { CheckBadge().offset(x: 2, y: 2) }
                        }
                        Text(item.person.name).font(TypeStyle.callout.font.weight(.heavy)).foregroundStyle(Brand.ink).lineLimit(1)
                        Text(OccasionDates.shortDate(item.due)).textStyle(.caption, color: Brand.inkMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(item.person.name), \(OccasionDates.longDate(item.due))")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    private func load() {
        let now = Date()
        people = model.allPeople().compactMap { p in
            guard let b = p.birthday else { return nil }
            return (p, OccasionDates.nextDate(month: b.month, day: b.day, onOrAfter: now))
        }
        .sorted { $0.due < $1.due }
        picked = Set(people.filter { $0.person.ring == .inner }.map(\.person.id))
    }
}

// MARK: A3

struct NotificationsSetupView: View {
    var onDone: () -> Void
    @State private var showDeniedNote = false

    var body: some View {
        FlowScreen {
            Spacer(minLength: 40)
            Question(title: "We'll tell you early enough to act")
            VStack(spacing: 10) {
                leadRow("3 weeks", "Your inner ring, with time to plan a gift or card")
                leadRow("1 week", "Close friends and family")
                leadRow("The day", "Everyone else, with a message ready to send")
            }
        } footer: {
            PrimaryButton(title: "Allow notifications") {
                Task {
                    let granted = await NotificationService.shared.requestAuthorization()
                    if granted { onDone() } else { showDeniedNote = true }
                }
            }
            TextLink(title: "Not now") { showDeniedNote = true }
        }
        .alert("Without alerts, check the widget or Home", isPresented: $showDeniedNote) {
            Button("OK", action: onDone)
        }
    }

    private func leadRow(_ tag: String, _ text: String) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Tag(text: tag)
            Text(text).textStyle(.callout, color: Brand.ink.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 14).padding(.horizontal, Brand.space4)
        .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
    }
}
