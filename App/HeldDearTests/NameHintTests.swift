import XCTest
@testable import HeldDear

/// The light through the name on Home (Nov 22, 2026): first few launches, never after a tap, never with Reduce Motion.
final class NameHintTests: XCTestCase {
    func testWhenItPlays() {
        XCTAssertTrue(NameHint.shows(launches: 1, tapped: false, reduceMotion: false))
        XCTAssertTrue(NameHint.shows(launches: 4, tapped: false, reduceMotion: false))
        XCTAssertFalse(NameHint.shows(launches: 5, tapped: false, reduceMotion: false))
        XCTAssertFalse(NameHint.shows(launches: 0, tapped: false, reduceMotion: false))
        XCTAssertFalse(NameHint.shows(launches: 2, tapped: true, reduceMotion: false))
        XCTAssertFalse(NameHint.shows(launches: 2, tapped: false, reduceMotion: true))
    }

    func testTapIsRemembered() {
        let d = UserDefaults(suiteName: "NameHintTests")!
        d.removePersistentDomain(forName: "NameHintTests")
        XCTAssertFalse(NameHint.tapped(d))
        NameHint.markTapped(d)
        XCTAssertTrue(NameHint.tapped(d))
    }

    func testANewStylePlaysAgainOnce() {
        let d = UserDefaults(suiteName: "NameHintStyleTests")!
        d.removePersistentDomain(forName: "NameHintStyleTests")
        d.set(1, forKey: NameHint.styleKey)
        d.set(true, forKey: NameHint.tappedKey)
        d.set(9, forKey: NameHint.launchesKey)
        NameHint.resetForNewStyle(d)
        XCTAssertFalse(NameHint.tapped(d))
        XCTAssertEqual(d.integer(forKey: NameHint.launchesKey), 0)
        XCTAssertEqual(d.integer(forKey: NameHint.styleKey), NameHint.style)
    }
}
