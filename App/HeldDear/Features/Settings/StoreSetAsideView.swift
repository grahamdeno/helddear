import SwiftUI

/// Shown once when the saved plans couldn't be opened (item 3.0a). The old file is kept on this iPhone, never
/// deleted. Two choices: share the kept plans, or carry on.
struct StoreSetAsideView: View {
    @EnvironmentObject var model: AppModel
    @State private var shareItems: [Any]?
    @State private var couldNotExport = false

    var body: some View {
        FlowScreen {
            Question(title: StoreSetAside.message, style: .title)
            if couldNotExport {
                Text("The export didn't work. Nothing was changed.")
                    .textStyle(.callout, color: Brand.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } footer: {
            VStack(spacing: Brand.space2) {
                PrimaryButton(title: StoreSetAside.exportTitle) { export() }
                SecondaryButton(title: StoreSetAside.continueTitle) { model.setAsideAcknowledged = true }
            }
        }
        .sheet(isPresented: Binding(get: { shareItems != nil }, set: { if !$0 { shareItems = nil } })) {
            ShareSheet(items: shareItems ?? []) { _ in shareItems = nil }
        }
    }

    private func export() {
        couldNotExport = false
        guard let store = StoreSetAside.storeToExport(kept: model.keptStoreURL, original: Store.configuration(url: nil).url),
              let zipped = try? DataExport.keptStoreBundle(storeURL: store) else {
            couldNotExport = true
            return
        }
        shareItems = [zipped]
    }
}
