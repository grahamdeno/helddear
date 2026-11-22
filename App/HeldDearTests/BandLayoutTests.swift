import XCTest
@testable import HeldDear

/// Home's timeline names never touch and no day's line runs through a name (Graham, Nov 21, 2026).
final class BandLayoutTests: XCTestCase {
    let tops: [CGFloat] = [96, 50, 74, 28]

    private func boxes(_ items: [BandLayout.Item], _ placed: [BandLayout.Placed]) -> [(lo: CGFloat, hi: CGFloat, top: CGFloat, x: CGFloat)] {
        zip(items, placed).compactMap { item, p in
            guard let level = p.level else { return nil }
            let w = item.widths[p.option]
            let lo = p.left ? item.x - BandLayout.inset - w : item.x + BandLayout.inset
            return (lo, lo + w, tops[level], item.x)
        }
    }

    private func assertClear(_ items: [BandLayout.Item], file: StaticString = #filePath, line: UInt = #line) {
        let placed = BandLayout.place(items, tops: tops)
        let b = boxes(items, placed)
        for i in b.indices {
            for j in b.indices where j > i {
                if abs(b[i].top - b[j].top) < BandLayout.labelHeight {
                    XCTAssertFalse(b[i].lo < b[j].hi && b[j].lo < b[i].hi, "names \(i) and \(j) overlap", file: file, line: line)
                }
            }
        }
        // No line crosses a name placed lower than where that line starts.
        let lines = zip(items, placed).map { ($0.x, $1.level.map { tops[$0] } ?? 96) }
        for box in b {
            for (x, top) in lines where top < box.top {
                XCTAssertFalse(x > box.lo && x < box.hi, "a line runs through a name", file: file, line: line)
            }
        }
    }

    func testCrowdedWinterFromTheScreenshot() {
        // An anniversary, a selected birthday, Christmas and two close birthdays: Nov to Feb at 118 points a month.
        let items: [BandLayout.Item] = [
            .init(x: 102, widths: [118, 82]),
            .init(x: 202, widths: [106]),
            .init(x: 232, widths: [80]),
            .init(x: 350, widths: [44]),
            .init(x: 354, widths: [56]),
        ]
        assertClear(items)
    }

    func testManyDaysInOneWeekStayClearOrDrop() {
        let items = (0..<10).map { BandLayout.Item(x: 100 + CGFloat($0) * 6, widths: [70, 30]) }
        assertClear(items)
        let placed = BandLayout.place(items, tops: tops)
        XCTAssertTrue(placed.contains { $0.level == nil }, "a very crowded week drops some names to just their lines")
    }

    func testRoomyDaysKeepFullWordingOnTheFirstHeight() {
        let items = [BandLayout.Item(x: 40, widths: [60, 30]), BandLayout.Item(x: 300, widths: [60, 30])]
        let placed = BandLayout.place(items, tops: tops)
        XCTAssertEqual(placed, [.init(level: 0, left: false, option: 0), .init(level: 0, left: false, option: 0)])
    }

    func testShorterWordingBeforeDropping() {
        // An earlier long name fills the low rows; a later day takes its short wording on a free row before dropping.
        let items = [BandLayout.Item(x: 100, widths: [160]), BandLayout.Item(x: 110, widths: [160]),
                     BandLayout.Item(x: 120, widths: [160]), BandLayout.Item(x: 300, widths: [600, 40])]
        let placed = BandLayout.place(items, tops: tops, minX: 0)
        assertClear(items)
        XCTAssertNotNil(placed.last?.level)
    }

    func testEveryNameShowsWhenAMonthIsCrowded() {
        // Twelve names in one December week (two on the same day), and one in March.
        var days = (0..<12).map { BandLayout.Day(month: 0, fraction: 0.5 + CGFloat($0 / 2 * 2 + $0 % 2) * 0.02, widths: [60, 30]) }
        days[1].fraction = days[0].fraction
        days.append(BandLayout.Day(month: 3, fraction: 0.5, widths: [60]))
        let fit = BandLayout.fit(days, months: 12, base: 118, lead: 24, tops: tops)
        XCTAssertTrue(fit.placed.allSatisfy { $0.level != nil }, "every name has a place")
        XCTAssertGreaterThan(fit.monthWidths[0], 118, "the crowded month grew")
        XCTAssertEqual(fit.monthWidths[3], 118, "a quiet month keeps its width")
        XCTAssertEqual(fit.monthStarts[1], 24 + fit.monthWidths[0])
    }

    func testQuietYearKeepsBaseWidths() {
        let days = [BandLayout.Day(month: 1, fraction: 0.2, widths: [50]), BandLayout.Day(month: 5, fraction: 0.7, widths: [50])]
        let fit = BandLayout.fit(days, months: 12, base: 118, lead: 24, tops: tops)
        XCTAssertEqual(fit.monthWidths, Array(repeating: 118, count: 12))
        XCTAssertEqual(fit.totalWidth, 24 * 2 + 118 * 12)
    }

    func testABusyDecemberFitsWithoutGrowingFar() {
        // Eight birthdays across one month, two on neighbouring days.
        let days = [0.1, 0.15, 0.3, 0.55, 0.56, 0.6, 0.8, 0.82].map { BandLayout.Day(month: 0, fraction: $0, widths: [70, 40]) }
        let fit = BandLayout.fit(days, months: 12, base: 118, lead: 24, tops: tops)
        XCTAssertTrue(fit.placed.allSatisfy { $0.level != nil })
        XCTAssertLessThan(fit.monthWidths[0], 800, "stepping names down keeps the month from growing much")
    }
}

