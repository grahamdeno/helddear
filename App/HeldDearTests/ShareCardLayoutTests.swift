import XCTest
@testable import HeldDear

final class ShareCardLayoutTests: XCTestCase {
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d))! }

    func testSevenMonthsWithTheDayInTheMiddle() {
        let months = ShareCardLayout.months(around: date(2026, 12, 17), calendar: cal)
        XCTAssertEqual(months.map { cal.component(.month, from: $0) }, [9, 10, 11, 12, 1, 2, 3])
    }

    func testDotSitsInsideItsMonth() {
        let p = ShareCardLayout.position(of: date(2026, 12, 17), calendar: cal)
        XCTAssertGreaterThan(p, 3.0 / 7)
        XCTAssertLessThan(p, 4.0 / 7)
    }

    func testNoAgeUnlessAdded() {
        XCTAssertEqual(ShareCardLayout.subline(type: .birthday, partner: nil, count: 40, addAge: false), "birthday")
        XCTAssertEqual(ShareCardLayout.subline(type: .birthday, partner: nil, count: 40, addAge: true), "turns 40")
        XCTAssertEqual(ShareCardLayout.subline(type: .anniversary, partner: "Graham", count: 11, addAge: false), "anniversary")
        XCTAssertEqual(ShareCardLayout.subline(type: .anniversary, partner: "Graham", count: 11, addAge: true), "11th anniversary")
        XCTAssertEqual(ShareCardLayout.subline(type: .event, partner: "Ballet recital", count: nil, addAge: true), "Ballet recital")
    }

    func testRampEasesAndClamps() {
        XCTAssertEqual(ShareCardLayout.ramp(0, from: 1, to: 2), 0)
        XCTAssertEqual(ShareCardLayout.ramp(3, from: 1, to: 2), 1)
        XCTAssertGreaterThan(ShareCardLayout.ramp(1.5, from: 1, to: 2), 0.5)
    }

    func testBannerKeepsTheFaceAndTheShape() {
        let size = CGSize(width: 2000, height: 1500)
        let face = CGRect(x: 1200, y: 300, width: 300, height: 300)
        let r = FaceFrame.bannerRect(face: face, imageSize: size, aspect: 390.0 / 290.0)
        XCTAssertEqual(r.width / r.height, 390.0 / 290.0, accuracy: 0.01)
        XCTAssertTrue(r.contains(face))
        XCTAssertTrue(CGRect(origin: .zero, size: size).contains(r.integral.insetBy(dx: 1, dy: 1)))
    }
}
