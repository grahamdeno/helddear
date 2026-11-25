import XCTest
import SwiftUI
@testable import HeldDear

/// UX-10, UX-12 and the 1.0 privacy line (Nov 24, 2026).
final class UXFollowUpTests: XCTestCase {
    func testPrivacyLineMatchesTheBuild() {
        XCTAssertEqual(AppFeatures.privacyLine.contains("mail"), AppFeatures.mailedCards)
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

/// The privacy manifest ships in the app and says what the App Privacy answers say (Nov 24, 2026).
final class PrivacyManifestTests: XCTestCase {
    func testManifestShipsAndMatchesTheApprovedAnswers() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"), "PrivacyInfo.xcprivacy is not in the app")
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
        XCTAssertEqual(plist["NSPrivacyTracking"] as? Bool, false)
        XCTAssertEqual((plist["NSPrivacyTrackingDomains"] as? [Any])?.count, 0)
        // Mailed cards (approved Nov 25, 2026): name, address, card content and order record, for app functionality only.
        let collected = (plist["NSPrivacyCollectedDataTypes"] as? [[String: Any]]) ?? []
        XCTAssertEqual(Set(collected.compactMap { $0["NSPrivacyCollectedDataType"] as? String }), [
            "NSPrivacyCollectedDataTypeName", "NSPrivacyCollectedDataTypePhysicalAddress",
            "NSPrivacyCollectedDataTypeOtherUserContent", "NSPrivacyCollectedDataTypePurchaseHistory"])
        for c in collected {
            XCTAssertEqual(c["NSPrivacyCollectedDataTypeTracking"] as? Bool, false)
            XCTAssertEqual(c["NSPrivacyCollectedDataTypePurposes"] as? [String], ["NSPrivacyCollectedDataTypePurposeAppFunctionality"])
        }
        let types = (plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]]) ?? []
        XCTAssertEqual(types.compactMap { $0["NSPrivacyAccessedAPIType"] as? String }, ["NSPrivacyAccessedAPICategoryUserDefaults"])
    }
}
