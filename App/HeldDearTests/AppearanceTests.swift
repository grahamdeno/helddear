import XCTest
import SwiftUI
@testable import HeldDear

final class AppearanceTests: XCTestCase {
    func testFollowsTheiPhoneUntilChosen() {
        XCTAssertNil(Appearance.from("").colorScheme)
        XCTAssertNil(Appearance.from("system").colorScheme)
        XCTAssertEqual(Appearance.from("light").colorScheme, .light)
        XCTAssertEqual(Appearance.from("dark").colorScheme, .dark)
        XCTAssertEqual(Appearance.allCases.map(\.title), ["Match iPhone", "Light", "Dark"])
    }
}
