import SwiftUI

/// A first-use tip: one line and "Got it", with a small drawn picture for the two tips about things outside Held
/// Dear. Shows once; dismissing it, or leaving the screen after it was seen, means it never shows again. It sits in
/// the page, above what it explains; when it's wholly on screen as the page opens, the rest of the screen dims
/// behind it (TipSpotlight.swift). Pass nil to show nothing.
struct TipLine: View {
    let tip: FirstUseTip?
    /// Set by "Got it": nothing more shows in this spot for the rest of the visit, so the next tip in the screen's
    /// list waits for another visit (Fable, PR #161).
    @State private var dismissed = false
    /// Whether this tip gets the spotlight, decided once from where it first lands: true only when it's wholly on
    /// screen then. Nil until measured.
    @State private var spotlight: Bool?
    /// The tip's latest global frame. The spotlight is decided once, after the page settles, from the latest tip and
    /// host frames, whichever arrived last (Fable, PR #164; build on 4157d7a decided too early and never dimmed).
    @State private var lastFrame: CGRect?
    @State private var settled = false
    @Environment(\.tipHostFrame) private var hostFrame
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    init(_ tip: FirstUseTip?) { self.tip = tip }

    /// The tip to show now, read on every update, so a tip that becomes due while the screen is open (the third free
    /// plan starts on the person's page) still appears. Hidden in the walk's demo mode unless it asks for tips.
    private var shown: FirstUseTip? {
        guard !dismissed, let tip, FirstUseTips.shouldShow(tip), !DemoMode.hidesTips else { return nil }
        return tip
    }

    // Build 1062 showed no tips: the old view waited on a .task that never ran while it was empty. A bare `if let`
    // needs no task, and a hidden tip adds no child to the parent stack, so it leaves no gap or extra spacing.
    var body: some View {
        if let tip = shown {
            VStack(alignment: .leading, spacing: Brand.space3) {
                if tip.hasPicture {
                    TipPicture(tip: tip)
                        .frame(maxWidth: .infinity)
                        .accessibilityElement()
                        .accessibilityLabel(tip.pictureSteps ?? "")
                }
                HStack(alignment: .firstTextBaseline, spacing: Brand.space3) {
                    Image(systemName: "lightbulb").foregroundStyle(Brand.inkSoft).accessibilityHidden(true)
                    Text(tip.line).font(TypeStyle.callout.font).foregroundStyle(Brand.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Got it") { dismiss(tip) }
                    .font(TypeStyle.callout.font.weight(.semibold))
                    .foregroundStyle(Brand.action)
                    .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityElement(children: .combine)
                .accessibilityHint("Tip. Shows once.")
                .accessibilityIdentifier("tip.\(tip.rawValue)")
            }
            .padding(.horizontal, Brand.space4).padding(.vertical, Brand.space3)
            // Its own look (Graham, Nov 28, 2026): a lighter fill than the page and a thin oxblood edge, so a tip
            // reads as a tip on any screen. The edge is a mark, not something to tap.
            .background(Brand.raised, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
            .overlay(alignment: .leading) {
                UnevenRoundedRectangle(topLeadingRadius: Brand.radiusMd, bottomLeadingRadius: Brand.radiusMd,
                                       style: .continuous)
                    .fill(Brand.action).frame(width: 3).accessibilityHidden(true)
            }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                lastFrame = frame
                if settled { decideSpotlight() }
            }
            // Decide once the page has settled (after launch sizing and any push), from the latest frames; if one
            // isn't known yet, the next measurement decides.
            .task {
                try? await Task.sleep(for: .milliseconds(350))
                settled = true
                decideSpotlight()
            }
            .anchorPreference(key: TipSpotlightKey.self, value: .bounds) { anchor in
                spotlight == true && !voiceOver ? TipSpotlightRequest(anchor: anchor, dismiss: { dismiss(tip) }) : nil
            }
            .onDisappear { FirstUseTips.markSeen(tip) }
        }
    }

    /// Wholly on screen (top and bottom inside the host) the first time both frames are known.
    private func decideSpotlight() {
        guard spotlight == nil, let frame = lastFrame, let host = hostFrame, frame.height > 0, host.height > frame.height
        else { return }
        spotlight = frame.minY >= host.minY && frame.maxY <= host.maxY
    }

    private func dismiss(_ tip: FirstUseTip) {
        FirstUseTips.markSeen(tip)
        withAnimation(Motion.animation(.easeOut(duration: 0.2))) { dismissed = true }
    }
}

/// A small drawn picture, not a screenshot of iOS, so it stays right when Apple changes the look. It plays once in
/// about two seconds and holds on its last frame; with Reduce Motion on, only the last frame shows.
struct TipPicture: View {
    let tip: FirstUseTip
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0

    var body: some View {
        Group {
            switch tip {
            case .shareIdeas: shareRow
            default: widgetAdd
            }
        }
        .frame(height: 96)
        .task {
            let last = 3
            if reduceMotion { step = last; return }
            for s in 1...last {
                try? await Task.sleep(for: .milliseconds(600))
                withAnimation(.easeOut(duration: 0.3)) { step = s }
            }
        }
    }

    /// Share, then the row of apps with Held Dear lit, and More at the end.
    private var shareRow: some View {
        VStack(spacing: Brand.space2) {
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.up").font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(step >= 1 ? Brand.action : Brand.inkSoft)
                Text("Share").font(.caption.weight(.semibold)).foregroundStyle(Brand.inkSoft)
            }
            .scaleEffect(step == 1 ? 1.12 : 1)
            HStack(spacing: 14) {
                appCircle(fill: Brand.line)
                appCircle(fill: Brand.line)
                VStack(spacing: 3) {
                    Circle().fill(step >= 2 ? Brand.action : Brand.line).frame(width: 34, height: 34)
                        .overlay(Image(systemName: "heart.fill").font(.system(size: 13)).foregroundStyle(Brand.onAction)
                            .opacity(step >= 2 ? 1 : 0))
                    Text("Held Dear").font(.system(size: 9, weight: .semibold)).foregroundStyle(Brand.ink)
                }
                .scaleEffect(step == 2 ? 1.1 : 1)
                VStack(spacing: 3) {
                    Circle().strokeBorder(step >= 3 ? Brand.action : Brand.line, lineWidth: 1.5).frame(width: 34, height: 34)
                        .overlay(Image(systemName: "ellipsis").font(.system(size: 13, weight: .bold)).foregroundStyle(Brand.inkSoft))
                    Text("More").font(.system(size: 9, weight: .semibold)).foregroundStyle(Brand.inkSoft)
                }
            }
            .opacity(step >= 1 ? 1 : 0.35)
            .offset(y: step >= 1 ? 0 : 8)
        }
    }

    private func appCircle(fill: Color) -> some View {
        VStack(spacing: 3) {
            Circle().fill(fill).frame(width: 34, height: 34)
            RoundedRectangle(cornerRadius: 2).fill(Brand.line).frame(width: 26, height: 5)
        }
    }

    /// Press and hold, the plus, then the Held Dear widget.
    private var widgetAdd: some View {
        HStack(spacing: 18) {
            VStack(spacing: 4) {
                Image(systemName: "hand.point.up.left.fill").font(.system(size: 22))
                    .foregroundStyle(step >= 1 ? Brand.action : Brand.inkSoft)
                Text("Hold").font(.caption2.weight(.semibold)).foregroundStyle(Brand.inkSoft)
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Brand.line)
            VStack(spacing: 4) {
                Image(systemName: "plus.circle.fill").font(.system(size: 24))
                    .foregroundStyle(step >= 2 ? Brand.action : Brand.line)
                Text("Plus").font(.caption2.weight(.semibold)).foregroundStyle(Brand.inkSoft)
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Brand.line)
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(step >= 3 ? Brand.page : Brand.line.opacity(0.4))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(step >= 3 ? Brand.action : Brand.line))
                    .overlay(Text("Ada · 3 days").font(.system(size: 8, weight: .semibold)).foregroundStyle(Brand.ink)
                        .opacity(step >= 3 ? 1 : 0))
                    .frame(width: 64, height: 44)
                Text("Held Dear").font(.caption2.weight(.semibold)).foregroundStyle(Brand.inkSoft)
            }
            .scaleEffect(step == 3 ? 1.06 : 1)
        }
    }
}
