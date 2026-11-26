import XCTest
@testable import HeldDear

final class FirstUseTipsTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        defaults = UserDefaults(suiteName: "FirstUseTipsTests")
        defaults.removePersistentDomain(forName: "FirstUseTipsTests")
    }

    func testEachTipShowsOnceThenNever() {
        for tip in FirstUseTip.allCases {
            XCTAssertTrue(FirstUseTips.shouldShow(tip, defaults))
            FirstUseTips.markSeen(tip, defaults)
            XCTAssertFalse(FirstUseTips.shouldShow(tip, defaults))
        }
    }

    func testSeeingOneTipLeavesTheOthers() {
        FirstUseTips.markSeen(.plan, defaults)
        XCTAssertTrue(FirstUseTips.shouldShow(.holiday, defaults))
    }

    func testResetShowsThemAgain() {
        FirstUseTip.allCases.forEach { FirstUseTips.markSeen($0, defaults) }
        FirstUseTips.resetAll(defaults)
        XCTAssertTrue(FirstUseTip.allCases.allSatisfy { FirstUseTips.shouldShow($0, defaults) })
    }

    func testEveryTipIsOneShortSentenceWithNoPronounsForPeople() {
        for tip in FirstUseTip.allCases {
            XCTAssertLessThanOrEqual(tip.line.count, 90, tip.rawValue)
            for w in [" he ", " she ", " his ", " her ", " they ", " them ", " their "] {
                XCTAssertFalse(" \(tip.line.lowercased()) ".contains(w), "\(tip.rawValue): \(w)")
            }
        }
    }
}
