import PhotosUI
import UIKit
import SwiftUI

/// Get ahead on day one: for up to 5 inner-ring people, soonest birthday first, one wish and one photo each.
/// Every step can be skipped. One decision per screen.
struct GetAheadView: View {
    @EnvironmentObject var model: AppModel
    var onDone: () -> Void

    enum Step: Equatable { case intro, wish(Int), photo(Int), end }
    @State private var step: Step = .intro
    @State private var people: [Person] = []
    @State private var wish = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var helped = 0

    static let maxPeople = 5

    var body: some View {
        ZStack {
            switch step {
            case .intro: intro
            case .wish(let i): wishStep(i)
            case .photo(let i): photoStep(i)
            case .end: end
            }
        }
        .animation(.easeOut(duration: 0.22), value: step)
        .onAppear(perform: load)
        .onChange(of: photoItem) { _, item in savePhoto(item) }
    }

    private var intro: some View {
        FlowScreen {
            CirclesMark(size: 72).padding(.top, 60)
            Question(title: "Get ahead in two minutes", subtitle: "One wish and one photo for each person. Skip anyone.")
        } footer: {
            if let first = people.first {
                PrimaryButton(title: "Start with \(first.name)") { step = .wish(0) }
            }
            TextLink(title: "Later", action: onDone)
        }
    }

    private func counter(_ i: Int) -> String { "\(i + 1) of \(people.count)" }

    private func wishStep(_ i: Int) -> some View {
        let p = people[i]
        return FlowScreen {
            Question(tag: counter(i), title: "What would \(p.name) love this year?")
            LineField(label: "One line is plenty", text: $wish, placeholder: "A book, a day out, the blue scarf…") { saveWish(i) }
        } footer: {
            PrimaryButton(title: "Save") { saveWish(i) }
                .disabled(wish.trimmingCharacters(in: .whitespaces).isEmpty)
            TextLink(title: "Not sure yet") { wish = ""; step = .photo(i) }
        }
    }

    private func photoStep(_ i: Int) -> some View {
        let p = people[i]
        return FlowScreen {
            Question(tag: counter(i), title: "A photo of \(p.name) for the card?",
                     subtitle: "It goes on the birthday card. It stays on this iPhone.")
            Face(person: p, size: 120).frame(maxWidth: .infinity).padding(.top, 24)
        } footer: {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Text("Choose a photo").font(TypeStyle.callout.strong)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .foregroundStyle(Brand.onAction)
                    .background(Brand.action, in: Rectangle())
            }
            TextLink(title: "Skip") { next(after: i) }
        }
    }

    private var end: some View {
        FlowScreen {
            CirclesMark(size: 72).padding(.top, 60)
            Question(title: helped == 1 ? "You're ahead for 1 person." : "You're ahead for \(helped) people.",
                     subtitle: "Held Dear brings it all back when each birthday is near.")
        } footer: {
            PrimaryButton(title: "See your year", action: onDone)
        }
        .onAppear { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }

    private func saveWish(_ i: Int) {
        let t = wish.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        model.addWish(to: people[i], text: t)
        wish = ""
        helped = max(helped, i + 1)
        step = .photo(i)
    }

    private func savePhoto(_ item: PhotosPickerItem?) {
        guard let item, case .photo(let i) = step else { return }
        let person = people[i]
        Task {
            if let data = try? await item.loadTransferable(type: Data.self), let file = PhotoStore.save(data: data) {
                person.photoFiles.append(file)
                model.save()
                helped = max(helped, i + 1)
            }
            photoItem = nil
            next(after: i)
        }
    }

    private func next(after i: Int) {
        if i + 1 < people.count { step = .wish(i + 1) } else if helped > 0 { step = .end } else { onDone() }
    }

    private func load() {
        let now = Date()
        people = model.allPeople()
            .filter { $0.ring == .inner && $0.birthday != nil }
            .sorted {
                let a = OccasionDates.nextDate(month: $0.birthday!.month, day: $0.birthday!.day, onOrAfter: now)
                let b = OccasionDates.nextDate(month: $1.birthday!.month, day: $1.birthday!.day, onOrAfter: now)
                return a < b
            }
            .prefix(Self.maxPeople).map { $0 }
        if people.isEmpty { onDone() }
    }
}
