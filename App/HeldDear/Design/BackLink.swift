import SwiftUI
import UIKit

/// The back link on a page pushed from Home: "‹ Home", "‹ People", "‹ Christmas", "‹ Anna". It names where you came
/// from, so the way back is always in words (version B, approved Nov 20, 2026).
struct BackLink: ViewModifier {
    let title: String
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        // A plain bar in the page colour, with the back link as words, not a glass button (approved Nov 20, 2026).
        content
            .navigationBarBackButtonHidden(true)
            .background(BackLink.swipeBack)
            .toolbarBackground(Brand.page, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").font(.body.weight(.semibold))
                            Text(title).lineLimit(1)
                        }
                        .foregroundStyle(Brand.action)
                        // The bar gives a leading item little width; keep the words whole (feedback on build 1019).
                        .fixedSize()
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back to \(title)")
                }
                .sharedBackgroundVisibility(.hidden)
            }
    }
}

extension View {
    func backLink(_ title: String) -> some View { modifier(BackLink(title: title)) }
}

/// Hiding the system back button also turns off swiping from the left edge to go back. This turns the swipe back on,
/// only in the navigation stack of a page that shows a back link (Fable N3, Nov 21, 2026). It used to be changed for
/// every navigation controller in the app, flows and sheets included.
private final class SwipeBackDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = SwipeBackDelegate()
    weak var navigation: UINavigationController?

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        (navigation?.viewControllers.count ?? 0) > 1
    }
}

private struct SwipeBackEnabler: UIViewControllerRepresentable {
    final class Controller: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let nav = navigationController, let pop = nav.interactivePopGestureRecognizer else { return }
            let delegate = SwipeBackDelegate.shared
            delegate.navigation = nav
            pop.delegate = delegate
            pop.isEnabled = true
        }
    }
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {}
}

extension BackLink {
    static var swipeBack: some View { SwipeBackEnabler().frame(width: 0, height: 0).accessibilityHidden(true) }
}
