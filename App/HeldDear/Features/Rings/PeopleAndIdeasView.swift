import SwiftUI

/// Everyone and saved ideas on one page, with a switch at the top (approved Nov 20, 2026). Opened from "Everyone ›"
/// on Home's timeline.
struct PeopleAndIdeasView: View {
    @State private var showIdeas = false

    var body: some View {
        Group {
            if showIdeas { SavedIdeasView() } else { RingsView() }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Show", selection: $showIdeas) {
                    Text("People").tag(false)
                    Text("Ideas").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
        }
    }
}
