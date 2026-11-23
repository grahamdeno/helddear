import XCTest
@testable import HeldDear

/// "Around [name]'s birthdays" (Nov 22, 2026): kept and skipped photos aren't offered again, per person.
final class BirthdaySuggestionsTests: XCTestCase {
    func testKeptAndSkippedAreNotOfferedAgain() {
        XCTAssertEqual(BirthdaySuggestions.offer(["a", "b", "c", "d"], kept: ["b"], skipped: ["d"]), ["a", "c"])
        XCTAssertEqual(BirthdaySuggestions.offer([], kept: [], skipped: []), [])
    }

    func testRememberedPerPerson() {
        let d = UserDefaults(suiteName: "BirthdaySuggestionsTests")!
        d.removePersistentDomain(forName: "BirthdaySuggestionsTests")
        let ada = UUID(), bo = UUID()
        BirthdaySuggestions.markKept("x", for: ada, d)
        BirthdaySuggestions.markSkipped("y", for: ada, d)
        BirthdaySuggestions.markSkipped("y", for: ada, d)
        XCTAssertEqual(BirthdaySuggestions.kept(for: ada, d), ["x"])
        XCTAssertEqual(BirthdaySuggestions.skipped(for: ada, d), ["y"])
        XCTAssertTrue(BirthdaySuggestions.kept(for: bo, d).isEmpty)
        // Undo for Skip puts it back.
        BirthdaySuggestions.unmarkSkipped("y", for: ada, d)
        XCTAssertTrue(BirthdaySuggestions.skipped(for: ada, d).isEmpty)
    }

    func testAPhotosDayTakenStaysInItsFileName() {
        let cal = Calendar.current
        let date = cal.date(from: DateComponents(year: 2023, month: 12, day: 17, hour: 15))!
        let name = ChosenPhotos.fileName(id: "p", taken: date)
        XCTAssertEqual(name, "p_d20231217.jpg")
        XCTAssertEqual(ChosenPhotos.taken(name).map { cal.component(.day, from: $0) }, 17)
    }
}
