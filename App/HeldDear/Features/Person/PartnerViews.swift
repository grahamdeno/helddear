import SwiftUI

/// Who an anniversary is with (Nov 22, 2026): one of the user's people, so the day is shared by both pages, or a
/// typed name for someone who isn't in the app.
struct PartnerPicker: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let owner: Person
    let current: String?
    let currentID: UUID?
    let onPick: (Person?, String?) -> Void
    @State private var typed = ""

    var body: some View {
        let people = model.allPeople()
        let partners = Set(people.filter { Relationship.group($0.relationship) == .partner }.map(\.id))
        let choices = AnniversaryLinks.choices(for: owner.id, typed: typed,
                                               people: people.map { .init(id: $0.id, name: $0.name, fullName: $0.fullName) },
                                               partnerIDs: partners)
        let clean = typed.trimmingCharacters(in: .whitespaces)
        FlowScreen(onClose: { dismiss() }) {
            Question(title: "Who is \(DisplayName.plain(owner.name)) married to?",
                     subtitle: "Pick someone in Held Dear to share the day on both pages, or type a name.", style: .title)
            TextField("Search or type a name", text: $typed)
                .textInputAutocapitalization(.words).autocorrectionDisabled()
                .textStyle(.body)
                .padding(.horizontal, Brand.space4).frame(minHeight: 56)
                .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
            VStack(alignment: .leading, spacing: 0) {
                if !clean.isEmpty && !choices.contains(where: { $0.name.caseInsensitiveCompare(clean) == .orderedSame }) {
                    OptionRow(title: "Use \u{201C}\(clean)\u{201D}", caption: "Not in Held Dear") { pick(nil, clean) }
                }
                ForEach(choices.prefix(30), id: \.id) { c in
                    OptionRow(title: c.name, caption: c.id == currentID ? "Chosen" : (partners.contains(c.id) ? "Partner" : nil)) {
                        pick(people.first { $0.id == c.id }, nil)
                    }
                }
            }
            if current != nil || currentID != nil {
                TextLink(title: "No one") { pick(nil, nil) }.padding(.leading, -8)
            }
        } footer: { EmptyView() }
        .onAppear { if currentID == nil { typed = current ?? "" } }
    }

    private func pick(_ person: Person?, _ name: String?) {
        onPick(person, name)
        dismiss()
    }
}

/// Two anniversaries that look like one couple's day, offered once to combine. Nothing combines without a tap.
struct CombineAnniversaryCard: View {
    @EnvironmentObject var model: AppModel
    let keep: Occasion
    let drop: Occasion

    var body: some View {
        let a = DisplayName.plain(keep.person?.name ?? "")
        let b = DisplayName.plain(drop.person?.name ?? "")
        let date = OccasionDates.date(month: keep.month, day: keep.day, year: 2028).formatted(.dateTime.month(.wide).day())
        VStack(alignment: .leading, spacing: Brand.space3) {
            Text("One anniversary for \(a) and \(b)?").textStyle(.headline)
            Text("Both have one on \(date). Make it one shared day: it shows on both pages, with one reminder.")
                .textStyle(.body, color: Brand.inkSoft)
            HStack(spacing: Brand.space4) {
                Button { model.combine(keep: keep, drop: drop) } label: {
                    Text("Make it one").textStyle(.bodyStrong, color: Brand.onAction)
                        .padding(.horizontal, Brand.space4).frame(minHeight: 44)
                        .background(Brand.action, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
                }
                TextLink(title: "Keep both") { model.skipCombine(keep, drop) }
            }
        }
        .padding(Brand.space5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
    }
}
