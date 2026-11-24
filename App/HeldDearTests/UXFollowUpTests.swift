import XCTest
import SwiftUI
@testable import HeldDear

/// UX-10, UX-12 and the 1.0 privacy line (Nov 24, 2026).
final class UXFollowUpTests: XCTestCase {
    func testPrivacyLineNamesNoServerIn1_0() {
        XCTAssertTrue(AppFeatures.privacyLine.contains("no account and no server"))
        XCTAssertFalse(AppFeatures.privacyLine.contains("mail"))
    }

    func testMotionKeepsAnimationWhenReduceMotionIsOff() throws {
        try XCTSkipIf(Motion.reduced, "The simulator has Reduce Motion on")
        XCTAssertNotNil(Motion.animation(.snappy))
    }

    func testHowItWorksIsShortAndPlain() {
        let sections = HowItWorksView.sections
        XCTAssertEqual(sections.map(\.id), ["Your people", "Home", "A plan for each day", "Ideas", "Alerts", "Each year", "Your data"])
        XCTAssertEqual(Set(sections.map(\.id)).count, sections.count)
        for line in sections.flatMap(\.lines) {
            XCTAssertFalse(line.contains("\u{2014}"), "No em-dashes: \(line)")
            XCTAssertLessThanOrEqual(line.count, 110, "Keep each line short: \(line)")
            let words = Set(line.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
            XCTAssertTrue(words.isDisjoint(with: ["he", "she", "him", "her", "his", "hers", "they", "them"]), "No pronouns for people: \(line)")
        }
    }

    func testHowItWorksPointsToRealPlaces() {
        let text = HowItWorksView.sections.flatMap(\.lines).joined(separator: " ")
        XCTAssertTrue(text.contains("+ Add"))
        XCTAssertTrue(text.contains("Delete all my data"))
        XCTAssertTrue(text.contains("Export and import"))
    }
}
