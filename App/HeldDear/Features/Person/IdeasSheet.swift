import SwiftUI

/// Lifetime: four ideas for this person's next day, written on the iPhone from what the user saved.
/// Save any idea to the person's list with one tap.
struct IdeasSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let person: Person
    let moment: Moment?
    @State private var ideas: [OnDeviceIdeas.Idea] = []
    @State private var saved: Set<String> = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        FlowScreen(onClose: { dismiss() }) {
            Question(title: "Ideas for \(person.name)",
                     subtitle: "Written on this iPhone from what you saved about \(person.name). Nothing leaves your phone.")
            if loading {
                HStack(spacing: Brand.space3) {
                    ProgressView()
                    Text("Thinking about \(person.name)…").textStyle(.callout, color: Brand.inkMuted)
                }
                .padding(.vertical, Brand.space4)
            }
            if let error { Text(error).textStyle(.callout, color: Brand.inkMuted) }
            ForEach(ideas, id: \.title) { idea in
                VStack(alignment: .leading, spacing: Brand.space2) {
                    Text(idea.title).font(Brand.serif(22, relativeTo: .title3)).foregroundStyle(Brand.ink)
                    Text(idea.why).textStyle(.callout, color: Brand.inkMuted)
                    if saved.contains(idea.title) {
                        Text("Saved to \(person.name)'s ideas").textStyle(.caption, color: Brand.inkMuted)
                    } else {
                        TextLink(title: "Save this idea") {
                            model.addWish(to: person, text: idea.title)
                            saved.insert(idea.title)
                        }
                        .padding(.leading, -8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Brand.space3)
                .overlay(alignment: .top) { Rectangle().fill(Brand.line).frame(height: 1) }
            }
            if person.loves.isEmpty && !loading {
                Text("Add what \(person.name) loves on \(person.name)'s page and the ideas get much better.")
                    .textStyle(.caption, color: Brand.inkMuted)
            }
        } footer: {
            SecondaryButton(title: "More ideas") { Task { await load() } }.disabled(loading)
        }
        .task { await load() }
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            ideas = try await OnDeviceIdeas.gifts(for: PersonFacts(person: person, moment: moment))
            if ideas.isEmpty { error = "No ideas this time. Try again." }
        } catch {
            self.error = "Couldn't think of ideas right now. Try again."
        }
    }
}
