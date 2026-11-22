import CoreGraphics

/// Where each name sits on Home's timeline so no two names touch and no name is crossed by another day's line
/// (Graham, Nov 21, 2026). Plain geometry, unit tested; the view measures the names and draws the result.
///
/// Names are placed one at a time in date order. Each tries every height, to the right of its line and then to the
/// left, with its full wording first, then its shorter wording. When nothing fits, the name drops and only its
/// line shows, short, along the axis.
enum BandLayout {
    struct Item {
        /// Where the day's line stands.
        var x: CGFloat
        /// The width of each wording, full first.
        var widths: [CGFloat]
    }

    struct Placed: Equatable {
        /// Index into the heights; nil when the name dropped.
        var level: Int?
        var left: Bool
        /// Which wording fit.
        var option: Int
    }

    /// Space between a name and its line, and between neighbours.
    static let inset: CGFloat = 4
    static let gap: CGFloat = 8
    static let labelHeight: CGFloat = 22

    /// `tops`: the heights a name may sit at, in order of preference, measured down from the top; the axis is below
    /// them all. `minX`: the left edge names may not cross.
    static func place(_ items: [Item], tops: [CGFloat], minX: CGFloat = 0) -> [Placed] {
        struct Box { var lo: CGFloat; var hi: CGFloat; var top: CGFloat }
        var boxes: [Box] = []
        // Each placed line: its x and where it starts (the top of its own name, or the lowest height when dropped).
        var lines: [(x: CGFloat, top: CGFloat)] = []
        let lowest = tops.max() ?? 0
        var out: [Placed] = []

        func span(_ x: CGFloat, _ w: CGFloat, left: Bool) -> (CGFloat, CGFloat) {
            left ? (x - inset - w, x - inset) : (x + inset, x + inset + w)
        }

        for item in items {
            var chosen: Placed?
            search: for (option, w) in item.widths.enumerated() {
                for (level, top) in tops.enumerated() {
                    for left in [false, true] {
                        let (lo, hi) = span(item.x, w, left: left)
                        if lo < minX { continue }
                        // Another name on the same row, too close.
                        let rowsTouch = boxes.contains { b in
                            abs(b.top - top) < labelHeight && lo < b.hi + gap && b.lo < hi + gap
                        }
                        // Another day's line running down through this name.
                        let crossed = lines.contains { l in l.top < top && l.x > lo - 2 && l.x < hi + 2 }
                        // This day's line running down through a name already placed lower.
                        let crosses = boxes.contains { b in b.top > top && item.x > b.lo - 2 && item.x < b.hi + 2 }
                        if !rowsTouch && !crossed && !crosses {
                            chosen = Placed(level: level, left: left, option: option)
                            boxes.append(Box(lo: lo, hi: hi, top: top))
                            lines.append((item.x, top))
                            break search
                        }
                    }
                }
            }
            if let chosen {
                out.append(chosen)
            } else {
                out.append(Placed(level: nil, left: false, option: 0))
                lines.append((item.x, lowest))
            }
        }
        return out
    }
}
