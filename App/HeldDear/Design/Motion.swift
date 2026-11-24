import SwiftUI
import UIKit

/// Reduce Motion everywhere (UX-10, Nov 24, 2026). With Reduce Motion on, things change in place with no movement:
/// slides and springs become instant, and anything that slides in fades instead. Short fades are kept, as Apple
/// allows. A moving card preview the person turns on themselves still plays.
enum Motion {
    static var reduced: Bool { UIAccessibility.isReduceMotionEnabled }

    /// The animation to use, or none when Reduce Motion is on.
    static func animation(_ animation: Animation) -> Animation? { reduced ? nil : animation }

    /// A slide-in that becomes a plain fade when Reduce Motion is on.
    static func slide(_ edge: Edge) -> AnyTransition {
        reduced ? .opacity : .move(edge: edge).combined(with: .opacity)
    }
}

/// `withAnimation`, honoring Reduce Motion.
@discardableResult
func withMotion<Result>(_ animation: Animation = .snappy, _ body: () throws -> Result) rethrows -> Result {
    try withAnimation(Motion.animation(animation), body)
}
