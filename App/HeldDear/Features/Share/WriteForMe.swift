import SwiftUI

/// "Write it for me" under a card's line (Graham, Nov 22, 2026): three lines from Apple's on-device model, written
/// on this iPhone from what the user saved about the person. Tap one to use it, or ask again. Shown only where
/// Apple Intelligence is on. Nothing leaves the phone.
struct WriteForMe: View {
    let kind: IdeaPrompts.LineKind
    let facts: () -> PersonFacts
    @Binding var text: String
    @State private var options: [String] = []
    @State private var writing = false
    @State private var failed = false

    var body: some View {
        if OnDeviceIdeas.isAvailable {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(options, id: \.self) { line in
                    Button { text = line; options = [] } label: {
                        HStack(alignment: .top, spacing: Brand.space3) {
                            Text(line).font(Brand.serif(17, relativeTo: .body, italic: true)).foregroundStyle(Brand.ink)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Text("Use").textStyle(.caption, color: Brand.action)
                        }
                        .padding(.vertical, Brand.space3)
                        .frame(minHeight: 44)
                        .overlay(alignment: .bottom) { Rectangle().fill(Brand.line).frame(height: 1) }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityHint("Uses this line")
                }
                if failed { Text("That didn't work. Try again.").textStyle(.caption, color: Brand.inkMuted).padding(.top, 4) }
                TextLink(title: writing ? "Writing on this iPhone…" : (options.isEmpty ? "Write it for me" : "Try others")) { write() }
                    .disabled(writing)
                    .padding(.leading, -8)
            }
        }
    }

    private func write() {
        writing = true
        failed = false
        Task {
            let result = (try? await OnDeviceIdeas.lines(kind, for: facts())) ?? []
            options = result
            failed = result.isEmpty
            writing = false
        }
    }
}
