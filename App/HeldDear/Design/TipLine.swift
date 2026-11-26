import SwiftUI

/// A first-use tip: one line and "Got it". Shows once; dismissing it, or leaving the screen after it was seen,
/// means it never shows again. Never covers anything: it sits in the page, above the content it explains.
struct TipLine: View {
    let tip: FirstUseTip
    @State private var visible: Bool

    init(_ tip: FirstUseTip) {
        self.tip = tip
        _visible = State(initialValue: FirstUseTips.shouldShow(tip) && !DemoMode.on)
    }

    var body: some View {
        if visible {
            HStack(alignment: .firstTextBaseline, spacing: Brand.space3) {
                Image(systemName: "lightbulb").foregroundStyle(Brand.inkSoft).accessibilityHidden(true)
                Text(tip.line).font(TypeStyle.callout.font).foregroundStyle(Brand.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Got it") {
                    FirstUseTips.markSeen(tip)
                    withAnimation(Motion.animation(.easeOut(duration: 0.2))) { visible = false }
                }
                .font(TypeStyle.callout.font.weight(.semibold))
                .foregroundStyle(Brand.action)
                .frame(minWidth: 44, minHeight: 44)
            }
            .padding(.horizontal, Brand.space4).padding(.vertical, Brand.space2)
            .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityHint("Tip. Shows once.")
            .onDisappear { FirstUseTips.markSeen(tip) }
        }
    }
}
