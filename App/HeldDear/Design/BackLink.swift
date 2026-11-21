import SwiftUI
import UIKit

/// The back link on a page pushed from Home: "‹ Home", "‹ People", "‹ Christmas", "‹ Julia". It names where you came
/// from, so the way back is always in words (version B, approved Nov 20, 2026).
struct BackLink: ViewModifier {
    let title: String
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        // A plain bar in the page colour, with the back link as words, not a glass button (approved Nov 20, 2026).
        content
            .navigationBarBackButtonHidden(true)
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

/// Hiding the system back button also turns off swiping from the left edge to go back. This keeps the swipe.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
