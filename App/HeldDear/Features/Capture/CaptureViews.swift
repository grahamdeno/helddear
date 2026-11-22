import SwiftUI

// MARK: B1. Add a date

struct AddBirthdayView: View {
    @EnvironmentObject var model: AppModel
    @State private var text: String

    init(initialText: String = "") {
        _text = State(initialValue: initialText)
    }
    @State private var showHint = false
    @State private var choices: [ContactInfo] = []
    @State private var pendingChange: (person: Person, parsed: ParsedBirthday)?
    @State private var whichOne: ParsedBirthday?
    /// The typed name is someone already here who has no birthday yet: open them, or add another (Fable N1).
    @State private var alreadyHere: (person: Person, parsed: ParsedBirthday)?
    /// A new person and the date typed for them, waiting on what the date is for.
    @State private var firstDate: (parsed: ParsedBirthday, contact: ContactInfo?)?
    /// The person just added, waiting on who they are to the user (one tap, or Skip for now).
    @State private var whoFor: Person?
    /// "Something else" chosen as the first date: its name, asked next.
    @State private var namingEvent = false
    @State private var eventName = ""

    private var parsed: ParsedBirthday? {
        guard var p = BirthdayParser.parse(text) else { return nil }
        p.name = NameCleanup.strip(p.name)
        return p
    }

    var body: some View {
        if let person = whoFor {
            RelationshipPicker(person: person, showsBack: false) { close() }
        } else if let change = pendingChange {
            confirmChange(change.person, change.parsed)
        } else if let first = firstDate, namingEvent {
            nameEvent(first.parsed, contact: first.contact)
        } else if let first = firstDate {
            whatFor(first.parsed, contact: first.contact)
        } else if let p = whichOne {
            whichView(p)
        } else if let here = alreadyHere {
            alreadyHereView(here.person, here.parsed)
        } else {
            entry
        }
    }

    private var entry: some View {
        FlowScreen(onClose: close) {
            Question(title: "Add someone", subtitle: "Say or type their name and a date to remember.", style: .display)
            LineField(label: "Name and date", text: $text, placeholder: "Mike, March 3", onSubmit: save)
            if showHint {
                Text("Try: Mike, March 3").textStyle(.caption, color: Brand.inkMuted).padding(.top, -12)
            }
            if let p = parsed { preview(p) }
        } footer: {
            PrimaryButton(title: "Save", action: save)
        }
        .onChange(of: text) { _, _ in
            showHint = false
            choices = parsed.map { ContactsService.shared.contacts(matching: $0.name) } ?? []
        }
    }

    @ViewBuilder private func preview(_ p: ParsedBirthday) -> some View {
        let date = OccasionDates.longDate(OccasionDates.date(month: p.month, day: p.day, year: 2028))
        if choices.count == 1, let c = choices.first {
            HStack(spacing: 12) {
                Face(name: c.displayName, initials: String(c.displayName.prefix(1)).uppercased(),
                     image: ContactsService.shared.thumbnail(contactID: c.id))
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.fullName).textStyle(.bodyStrong)
                    Text("From your contacts · \(date)").textStyle(.caption, color: Brand.inkMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                CheckBadge()
            }
            .padding(.vertical, 12).padding(.horizontal, 16)
            .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
        } else if choices.isEmpty {
            ContextLine(text: "New person: \(p.name), \(date)")
        }
    }

    private func save() {
        guard let p = parsed else { showHint = true; return }
        if let existing = model.allPeople().first(where: { NameCleanup.isSamePerson(p.name, name: $0.name, fullName: $0.fullName) }) {
            if let b = existing.birthday, !text.lowercased().contains("anniversary") {
                if b.month == p.month && b.day == p.day { close(); return }
                pendingChange = (existing, p)
            } else {
                alreadyHere = (existing, p)
            }
            return
        }
        switch choices.count {
        case 0: chooseFirstDate(p, contact: nil)
        case 1: chooseFirstDate(p, contact: choices[0])
        default: whichOne = p
        }
    }

    private func alreadyHereView(_ person: Person, _ p: ParsedBirthday) -> some View {
        let name = DisplayName.plain(person.name)
        return FlowScreen(onClose: { alreadyHere = nil }) {
            Question(title: "Already have \(name)", subtitle: "Open \(name)'s page to add this date there, or add another \(name).")
            VStack(spacing: 0) {
                OptionRow(title: "Open \(name)'s page", caption: nil) {
                    let id = person.id
                    close()
                    model.push(.person(id, focus: nil))
                }
                OptionRow(title: "Add another \(name)", caption: nil) {
                    alreadyHere = nil
                    switch choices.count {
                    case 0: chooseFirstDate(p, contact: nil)
                    case 1: chooseFirstDate(p, contact: choices[0])
                    default: whichOne = p
                    }
                }
            }
        }
    }

    private func whichView(_ p: ParsedBirthday) -> some View {
        FlowScreen(onClose: { whichOne = nil }) {
            Question(title: "Which \(p.name)?")
            VStack(spacing: Brand.space2) {
                ForEach(choices) { c in
                    OptionRow(title: c.fullName, caption: c.month.map { m in OccasionDates.longDate(OccasionDates.date(month: m, day: c.day ?? 1, year: 2028)) },
                              action: {
                                  whichOne = nil
                                  chooseFirstDate(p, contact: c)
                              },
                              leading: { Face(name: c.displayName, initials: String(c.displayName.prefix(1)).uppercased(),
                                              image: ContactsService.shared.thumbnail(contactID: c.id)) },
                              trailing: { ChevronDisc() })
                }
            }
        }
    }

    private func confirmChange(_ person: Person, _ p: ParsedBirthday) -> some View {
        let old = person.birthday.map { OccasionDates.longDate(OccasionDates.date(month: $0.month, day: $0.day, year: 2028)) } ?? ""
        let new = OccasionDates.longDate(OccasionDates.date(month: p.month, day: p.day, year: 2028))
        return FlowScreen(onClose: { pendingChange = nil }) {
            Spacer(minLength: 60)
            Question(title: "Change \(person.name)'s birthday from \(old) to \(new)?")
        } footer: {
            PrimaryButton(title: "Yes, change it") {
                model.setBirthday(person, month: p.month, day: p.day, year: p.year)
                close()
            }
            TextLink(title: "No, keep \(old)") { pendingChange = nil }
        }
    }

    /// The person is what's added; the date is whatever it's for. Typing "birthday" or "anniversary" answers it.
    private func chooseFirstDate(_ p: ParsedBirthday, contact: ContactInfo?) {
        let lower = text.lowercased()
        if lower.contains("birthday") { addFirst(.birthday, p, contact: contact) }
        else if lower.contains("anniversary") { addFirst(.anniversary, p, contact: contact) }
        else { firstDate = (p, contact) }
    }

    private func nameEvent(_ p: ParsedBirthday, contact: ContactInfo?) -> some View {
        let trimmed = eventName.trimmingCharacters(in: .whitespacesAndNewlines)
        return FlowScreen(onClose: { namingEvent = false }) {
            Question(title: "What's the day?", subtitle: "A name is enough, like Ballet recital.")
            LineField(label: "What is it?", text: $eventName, placeholder: "Ballet recital", showsDictation: true)
        } footer: {
            PrimaryButton(title: "Next") { addFirst(.event, p, contact: contact, eventName: trimmed) }
                .disabled(trimmed.isEmpty)
                .opacity(trimmed.isEmpty ? 0.45 : 1)
        }
    }

    private func addFirst(_ type: OccasionType, _ p: ParsedBirthday, contact: ContactInfo?, eventName: String? = nil) {
        namingEvent = false
        let person = model.addPerson(name: p.name, fullName: contact?.fullName, contactID: contact?.id, firstDate: type,
                                     month: p.month, day: p.day, year: type == .birthday ? (p.year ?? contact?.year) : p.year,
                                     eventName: eventName)
        if person.relationship == nil { firstDate = nil; whoFor = person } else { close() }
    }

    private func whatFor(_ p: ParsedBirthday, contact: ContactInfo?) -> some View {
        let date = OccasionDates.longDate(OccasionDates.date(month: p.month, day: p.day, year: 2028))
        let types = OccasionOffer.firstDate
        return FlowScreen(onClose: { firstDate = nil }) {
            Question(title: "What is \(date) for \(p.name)?", subtitle: "You can add more dates on \(p.name)'s page.")
            VStack(spacing: 0) {
                ForEach(types, id: \.self) { t in
                    OptionRow(title: t == .event ? "Something else" : t.label,
                              caption: t == .event ? "A recital, a retirement, a new home" : nil) {
                        if t == .event { eventName = ""; namingEvent = true } else { addFirst(t, p, contact: contact) }
                    }
                }
            }
        }
    }

    private func close() { model.route = nil }
}

// MARK: B2. Save a wish (typed or spoken)

struct AddWishView: View {
    @EnvironmentObject var model: AppModel
    var preselected: Person?
    @State private var text = ""
    @State private var chosen: Person?
    @State private var askWho = false

    var body: some View {
        if askWho {
            WhoIsThisFor(people: model.allPeople(), preview: text) { person in
                save(to: person, text: WishParser.parse(text, names: [person.name]).text)
            } onClose: { askWho = false }
        } else {
            FlowScreen(onClose: { model.route = nil }) {
                Question(title: preselected.map { "What would \($0.name) love?" } ?? "Save a wish",
                         subtitle: preselected == nil ? "Say or type it, like \"Ada wants blue skates\"." : "One line is plenty.")
                LineField(label: "The wish", text: $text, placeholder: preselected == nil ? "Ada wants blue skates" : "Blue gardening gloves",
                          onSubmit: submit)
                if let person = matched {
                    HStack(spacing: 12) {
                        Face(person: person)
                        Text("For \(person.name)").textStyle(.bodyStrong).frame(maxWidth: .infinity, alignment: .leading)
                        CheckBadge()
                    }
                    .padding(.vertical, 12).padding(.horizontal, 16)
                    .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
                }
            } footer: {
                PrimaryButton(title: "Save", action: submit)
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var matched: Person? {
        if let preselected { return preselected }
        let people = model.allPeople()
        guard let i = WishParser.parse(text, names: people.map(\.name)).index else { return nil }
        return people[i]
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if let preselected { save(to: preselected, text: trimmed); return }
        let people = model.allPeople()
        let result = WishParser.parse(trimmed, names: people.map(\.name))
        if let i = result.index { save(to: people[i], text: result.text) } else { askWho = true }
    }

    private func save(to person: Person, text: String) {
        model.addWish(to: person, text: text)
        model.route = nil
    }
}

/// "Who is this for?": inner ring first, then everyone.
struct WhoIsThisFor: View {
    var people: [Person]
    var preview: String
    var onPick: (Person) -> Void
    var onClose: () -> Void
    @State private var search = ""

    var body: some View {
        FlowScreen(onClose: onClose) {
            Question(title: "Who is this for?", subtitle: preview)
            if people.count > 12 {
                TextField("Search", text: $search).textStyle(.body)
                    .padding(.horizontal, Brand.space4).frame(minHeight: 48)
                    .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusSm, style: .continuous))
            }
            VStack(spacing: Brand.space2) {
                ForEach(sorted, id: \.id) { p in
                    OptionRow(title: p.name, caption: p.ring == .inner ? "Inner ring" : nil, action: { onPick(p) },
                              leading: { Face(person: p) }, trailing: { ChevronDisc() })
                }
            }
        }
    }

    private var sorted: [Person] {
        let list = search.isEmpty ? people : people.filter { $0.name.localizedCaseInsensitiveContains(search) }
        return list.sorted { a, b in
            if (a.ring == .inner) != (b.ring == .inner) { return a.ring == .inner }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }
}
