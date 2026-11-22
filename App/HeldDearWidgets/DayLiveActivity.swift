import ActivityKit
import SwiftUI
import WidgetKit

/// The Lock Screen card and Dynamic Island for a person's day or a soon arrival (Graham, Nov 22, 2026): the name in
/// the serif, one line, and the oxblood dot. Tapping opens the day (or the item) in Held Dear.
struct DayLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DayActivityAttributes.self) { context in
            LockCard(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Brand.page)
                .activitySystemActionForegroundColor(Brand.ink)
                .widgetURL(context.attributes.link)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Dot(size: 12).padding(.leading, 6).padding(.top, 6) }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.title).font(Brand.display(22, relativeTo: .title3)).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.line).font(Brand.display(15, relativeTo: .callout, italic: true)).foregroundStyle(.secondary)
                }
            } compactLeading: {
                Dot(size: 10)
            } compactTrailing: {
                Text(context.attributes.kind == .day ? "Today" : short(context.state.line)).font(.caption2.weight(.semibold))
            } minimal: {
                Dot(size: 10)
            }
            .widgetURL(context.attributes.link)
        }
    }

    private func short(_ line: String) -> String {
        line.replacingOccurrences(of: "Arrives ", with: "").prefix(3).capitalized
    }
}

private struct Dot: View {
    var size: CGFloat
    var body: some View { Circle().fill(Brand.action).frame(width: size, height: size).accessibilityHidden(true) }
}

private struct LockCard: View {
    let attributes: DayActivityAttributes
    let state: DayActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(attributes.kind == .day ? "TODAY" : "ON ITS WAY")
                    .font(.caption2.weight(.semibold)).tracking(1.5).foregroundStyle(Brand.inkMuted)
                Text(attributes.title).font(Brand.display(26, relativeTo: .title2)).foregroundStyle(Brand.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(state.line).font(Brand.display(16, relativeTo: .callout, italic: true)).foregroundStyle(Brand.inkSoft)
            }
            Spacer(minLength: 8)
            if state.total > 0 {
                HStack(spacing: 4) {
                    ForEach(0..<state.total, id: \.self) { i in
                        Circle().fill(i < state.ready ? Brand.action : Color.clear)
                            .overlay { Circle().strokeBorder(Brand.action, lineWidth: 1.2) }
                            .frame(width: 9, height: 9)
                    }
                }
                .accessibilityLabel("\(state.ready) of \(state.total) ready")
            } else {
                Dot(size: 12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .accessibilityElement(children: .combine)
    }
}
