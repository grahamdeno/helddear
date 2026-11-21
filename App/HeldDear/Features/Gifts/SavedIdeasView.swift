import SwiftUI

/// Ideas (version B, approved Nov 20, 2026): every saved wish, by person. Tap one to open that person's page.
/// Saving from anywhere with Share lands here too.
struct SavedIdeasView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let _ = model.revision
        let people = model.allPeople().filter { !$0.openWishes.isEmpty }
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Ideas").textStyle(.title).accessibilityAddTraits(.isHeader)
                Text("Saved from anywhere with Share, or typed here.")
                    .font(Brand.serif(18, relativeTo: .callout, italic: true)).foregroundStyle(Brand.inkSoft)
                    .padding(.top, Brand.space1)
                    .padding(.bottom, Brand.space5)
                if people.isEmpty {
                    Text("No ideas saved yet. When someone mentions something they'd love, save it here.")
                        .textStyle(.body, color: Brand.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, Brand.space4)
                }
                ForEach(people, id: \.id) { p in
                    VStack(alignment: .leading, spacing: 0) {
                        Eyebrow(text: p.name).padding(.bottom, Brand.space2)
                        ForEach(p.openWishes, id: \.id) { wish in row(wish, person: p) }
                    }
                    .padding(.bottom, Brand.space5)
                }
                SecondaryButton(title: "Save an idea") { model.route = .addWish(nil) }
            }
            .padding(.horizontal, Brand.space5)
            .padding(.vertical, 8)
        }
        .background(Brand.page.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ wish: Wish, person: Person) -> some View {
        Button { model.push(.person(person.id, focus: nil)) } label: {
            HStack(spacing: Brand.space3) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(wish.text).textStyle(.bodyStrong).multilineTextAlignment(.leading)
                    Text(caption(wish)).textStyle(.caption, color: Brand.inkMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Brand.inkMuted)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, Brand.space3)
            .frame(minHeight: 56)
            .overlay(alignment: .bottom) { Rectangle().fill(Brand.line).frame(height: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityHint("Opens \(person.name)")
    }

    private func caption(_ wish: Wish) -> String {
        let saved = "Saved \(wish.capturedAt.formatted(.dateTime.month(.abbreviated).day()))"
        if let host = wish.url.flatMap(URL.init(string:))?.host() { return "\(saved) · \(host)" }
        return saved
    }
}
