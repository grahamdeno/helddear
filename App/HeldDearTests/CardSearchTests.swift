import XCTest
@testable import HeldDear

/// Finding a mailed card by category and search (Nov 22, 2026).
final class CardSearchTests: XCTestCase {
    func testApostrophesAndCaseDontMatter() {
        XCTAssertTrue(CardSearch.matches("mothers day", name: "Happy Mother's Day", description: nil, category: nil))
        XCTAssertTrue(CardSearch.matches("Mother's Day", name: "Bloom", description: nil, category: "Mother's Day"))
        XCTAssertTrue(CardSearch.matches("MOTHER\u{2019}S DAY", name: "Bloom", description: "For a mother's day", category: nil))
    }

    func testEverydayWordsFindTheirAlikes() {
        XCTAssertTrue(CardSearch.matches("mom", name: "Happy Mother's Day", description: nil, category: nil))
        XCTAssertTrue(CardSearch.matches("xmas", name: "Merry Christmas", description: nil, category: nil))
        XCTAssertTrue(CardSearch.matches("flowers", name: "Rustic Flower", description: nil, category: nil))
    }

    func testEveryWordMustMatchAndEmptyShowsAll() {
        XCTAssertTrue(CardSearch.matches("dog birthday", name: "Pup Party", description: "A dog in a hat", category: "Birthday"))
        XCTAssertFalse(CardSearch.matches("dog sympathy", name: "Pup Party", description: "A dog in a hat", category: "Birthday"))
        XCTAssertTrue(CardSearch.matches("  ", name: "Anything", description: nil, category: nil))
        XCTAssertFalse(CardSearch.matches("art", name: "Party", description: nil, category: nil), "matches at word starts only")
    }

    func testMenuOpensOnTheOccasionsOwnCategory() {
        XCTAssertEqual(CardSearch.startingSection(own: "Birthday", names: ["Love", "Birthday"]), "Birthday")
        XCTAssertEqual(CardSearch.startingSection(own: "Gone", names: ["Love", "Birthday"]), "Love")
        XCTAssertNil(CardSearch.startingSection(own: nil, names: []))
    }
}
