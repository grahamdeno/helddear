import SwiftUI

/// Swipe a row left to show Remove; swipe far to remove at once (Graham, Nov 21, 2026). Replaces press-and-hold menus,
/// which felt clunky. Vertical scrolling still wins for vertical drags. VoiceOver keeps its named action.
struct SwipeToRemove: ViewModifier {
    var title: String = "Remove"
    var action: () -> Void
    @State private var offset: CGFloat = 0
    @State private var open = false
    private let reveal: CGFloat = 92

    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            if offset < 0 {
                Button {
                    withAnimation(.snappy) { offset = 0; open = false }
                    action()
                } label: {
                    Text(title).font(.callout.weight(.semibold)).foregroundStyle(Brand.onAction)
                        .frame(width: max(reveal, -offset), alignment: .center)
                        .frame(maxHeight: .infinity)
                        .background(Brand.action)
                }
                .buttonStyle(.plain)
                .accessibilityHidden(true)
            }
            content
                .offset(x: offset)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 18)
                        .onChanged { g in
                            guard abs(g.translation.width) > abs(g.translation.height) * 1.4 else { return }
                            let base: CGFloat = open ? -reveal : 0
                            offset = min(0, base + g.translation.width)
                        }
                        .onEnded { g in
                            guard abs(g.translation.width) > abs(g.translation.height) * 1.4 else {
                                withAnimation(.snappy) { offset = open ? -reveal : 0 }
                                return
                            }
                            if offset < -reveal * 2.2 {
                                withAnimation(.snappy) { offset = 0; open = false }
                                action()
                            } else if offset < -reveal / 2 {
                                withAnimation(.snappy) { offset = -reveal; open = true }
                            } else {
                                withAnimation(.snappy) { offset = 0; open = false }
                            }
                        }
                )
        }
        .clipped()
    }
}

extension View {
    func swipeToRemove(_ title: String = "Remove", action: @escaping () -> Void) -> some View {
        modifier(SwipeToRemove(title: title, action: action))
    }
}

/// "Gift removed · Undo" along the bottom for a few seconds after something is removed.
struct UndoBanner: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        if let note = model.undo {
            HStack(spacing: Brand.space3) {
                Text(note.text).textStyle(.callout, color: Brand.page).lineLimit(1)
                Spacer(minLength: Brand.space2)
                Button("Undo") { model.undoRemoval() }
                    .font(.callout.weight(.semibold)).foregroundStyle(Brand.page).frame(minHeight: 44)
            }
            .padding(.horizontal, Brand.space4)
            .background(Brand.ink, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, Brand.space4)
            .padding(.bottom, Brand.space2)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityAction(named: "Undo") { model.undoRemoval() }
        }
    }
}
