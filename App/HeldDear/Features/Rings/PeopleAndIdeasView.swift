import SwiftUI

/// Everyone and saved ideas on one page, with a switch at the top (approved Nov 20, 2026). Opened from "Everyone ›"
/// on Home's timeline.
struct PeopleAndIdeasView: View {
    enum Tab: Hashable { case people, ideas, finds }
    @State private var tab: Tab = .people

    var body: some View {
        Group {
            switch tab {
            case .people: RingsView()
            case .ideas: SavedIdeasView()
            case .finds: FindsView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Show", selection: $tab) {
                    Text("People").tag(Tab.people)
                    Text("Ideas").tag(Tab.ideas)
                    Text("Finds").tag(Tab.finds)
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
            }
        }
    }
}
