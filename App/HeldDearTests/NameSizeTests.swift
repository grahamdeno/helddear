import XCTest
@testable import HeldDear

/// Long names step down in size, then wrap (feedback on build 1011).
final class NameSizeTests: XCTestCase {
    func testPage_longNamesGetSmallerButNeverTiny() {
        XCTAssertEqual(NameSize.page("Mom"), 96)
        XCTAssertEqual(NameSize.page("Marcus"), 96)
        XCTAssertEqual(NameSize.page("Miriam Hollowell Danver"), 52)
        XCTAssertGreaterThan(NameSize.page("Christopher"), NameSize.page("Miriam Hollowell Danver"))
    }

    func testSizesNeverGrowWithLength() {
        var last: CGFloat = .infinity
        for n in 1...40 {
            let size = NameSize.page(String(repeating: "a", count: n))
            XCTAssertLessThanOrEqual(size, last)
            last = size
        }
    }

    func testNamesMayWrapToTwoLines() {
        XCTAssertEqual(NameSize.maxLines, 2)
    }

    func testPlainName_dropsEmojiKeepsLettersAndDigits() {
        XCTAssertEqual(DisplayName.plain("Marcus 🕑"), "Marcus")
        XCTAssertEqual(DisplayName.plain("Zoë"), "Zoë")
        XCTAssertEqual(DisplayName.plain("Mom ❤️"), "Mom")
        XCTAssertEqual(DisplayName.plain("Room 2"), "Room 2")
        XCTAssertEqual(DisplayName.plain("🎂"), "🎂", "A name that is only emoji is kept")
    }

    func testRelationshipChoices_everydayWordsAndTheirGroups() {
        XCTAssertEqual(Relationship.mainChoices, ["Wife", "Husband", "Son", "Daughter", "Mom", "Dad", "Friend"])
        XCTAssertEqual(Relationship.moreChoices.count, 26)
        XCTAssertEqual(Relationship.group("Niece"), .extended)
        XCTAssertEqual(Relationship.group("Stepmom"), .parent)
        XCTAssertEqual(Relationship.group("Boss"), .community)
        XCTAssertEqual(Set(Relationship.choices).count, Relationship.choices.count, "No word twice")
        for word in Relationship.choices {
            XCTAssertNotEqual(Relationship.group(word), .unknown, word)
        }
        XCTAssertEqual(Relationship.group("Mom"), .parent)
        XCTAssertEqual(Relationship.group("Grandma"), .parent)
        XCTAssertEqual(Relationship.group("Wife"), .partner)
    }
}
