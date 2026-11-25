import SwiftUI

/// Pinch or double-tap to zoom from 1x to 4x, and drag to look around while zoomed. VoiceOver zooms with its own zoom
/// action. Used for a mailed card opened full screen (Graham, Nov 25, 2026). Draws nothing itself and loads nothing.
struct Zoomable<Content: View>: View {
    var label: String
    @ViewBuilder var content: Content

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            content
                .scaleEffect(scale)
                .offset(offset)
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(magnify(in: geo.size).simultaneously(with: pan(in: geo.size)))
                .onTapGesture(count: 2) { set(scale: scale > 1 ? 1 : 2.5, in: geo.size) }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label)
                .accessibilityAddTraits(.isImage)
                .accessibilityHint("Double-tap with two fingers or pinch to zoom")
                .accessibilityZoomAction { action in
                    set(scale: action.direction == .zoomIn ? min(scale + 1, 4) : max(scale - 1, 1), in: geo.size)
                }
        }
        .clipped()
    }

    private func magnify(in size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in scale = min(max(lastScale * value.magnification, 1), 4) }
            .onEnded { _ in
                if scale <= 1.01 { set(scale: 1, in: size) } else { lastScale = scale; clampOffset(in: size) }
            }
    }

    private func pan(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height)
            }
            .onEnded { _ in if scale > 1 { clampOffset(in: size) } }
    }

    /// Keeps the zoomed picture from being dragged off the screen.
    private func clampOffset(in size: CGSize) {
        let c = ZoomMath.clamp(offset, scale: scale, in: size)
        withAnimation(Motion.animation(.easeOut(duration: 0.2))) { offset = c }
        lastOffset = c
    }

    private func set(scale new: CGFloat, in size: CGSize) {
        let c = new == 1 ? .zero : ZoomMath.clamp(offset, scale: new, in: size)
        withAnimation(Motion.animation(.easeOut(duration: 0.25))) {
            scale = new
            offset = c
        }
        lastScale = new
        lastOffset = c
    }
}

/// How far a zoomed picture may move: never past its own edges.
enum ZoomMath {
    static func clamp(_ offset: CGSize, scale: CGFloat, in size: CGSize) -> CGSize {
        let maxX = max(0, size.width * (scale - 1) / 2), maxY = max(0, size.height * (scale - 1) / 2)
        return CGSize(width: min(max(offset.width, -maxX), maxX), height: min(max(offset.height, -maxY), maxY))
    }
}
