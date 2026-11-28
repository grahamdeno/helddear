import SwiftUI

/// Tip spotlight (Graham, Nov 28, 2026, for 1.0): while a first-use tip shows, the rest of the screen blurs and dims
/// so the tip stands out. Tapping "Got it" or anywhere on the blurred part clears the tip and marks it seen; nothing
/// behind the blur can be tapped or scrolled meanwhile. The tip asks for the spotlight only when it's wholly on screen
/// as the page opens, and never with VoiceOver on (then it's read in the page). Reduce Transparency dims without the
/// blur; Reduce Motion drops the fade. Hosts: Home's navigation stack and every full-screen route.
struct TipSpotlightRequest {
    let anchor: Anchor<CGRect>
    let dismiss: () -> Void
}

struct TipSpotlightKey: PreferenceKey {
    static let defaultValue: TipSpotlightRequest? = nil
    static func reduce(value: inout TipSpotlightRequest?, nextValue: () -> TipSpotlightRequest?) {
        value = value ?? nextValue()
    }
}

/// The host's frame in global space, so a tip can tell whether it's wholly on screen. Nil means no host: no spotlight.
private struct TipHostFrameKey: EnvironmentKey { static let defaultValue: CGRect? = nil }

extension EnvironmentValues {
    var tipHostFrame: CGRect? {
        get { self[TipHostFrameKey.self] }
        set { self[TipHostFrameKey.self] = newValue }
    }
}

/// The blurred, dimmed layer with the tip's shape cut out. Taps in the cut-out reach the tip; taps elsewhere clear it.
private struct SpotlightLayer: View {
    let hole: CGRect
    let dismiss: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let shape = CutOut(hole: hole, radius: Brand.radiusMd)
        ZStack {
            if !reduceTransparency { Rectangle().fill(.ultraThinMaterial) }
            Rectangle().fill(Color.black.opacity(reduceTransparency ? 0.55 : 0.3))
        }
        .mask(shape.fill(style: FillStyle(eoFill: true)))
        .contentShape(shape, eoFill: true)
        .onTapGesture(perform: dismiss)
        .accessibilityHidden(true)
        .transition(.opacity)
    }
}

/// The whole screen minus the tip's rounded rectangle (even-odd).
private struct CutOut: Shape {
    let hole: CGRect
    let radius: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path(rect.insetBy(dx: -200, dy: -200))
        p.addRoundedRect(in: hole, cornerSize: CGSize(width: radius, height: radius), style: .continuous)
        return p
    }
}

extension View {
    /// Draws the spotlight for any tip inside that asks for it.
    func tipSpotlightHost() -> some View { modifier(TipSpotlightHost()) }
}

private struct TipSpotlightHost: ViewModifier {
    @State private var frame: CGRect?

    func body(content: Content) -> some View {
        content
            .environment(\.tipHostFrame, frame)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
            .overlayPreferenceValue(TipSpotlightKey.self) { request in
                GeometryReader { proxy in
                    if let request {
                        SpotlightLayer(hole: proxy[request.anchor], dismiss: request.dismiss)
                    }
                }
                .ignoresSafeArea()
                .animation(Motion.animation(.easeOut(duration: 0.2)), value: request == nil)
            }
    }
}
