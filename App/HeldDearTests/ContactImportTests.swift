import XCTest
@testable import HeldDear

final class ContactImportTests: XCTestCase {
    private typealias P = ContactImport.Pick

    func testSortsReadyNeedDateAndAlready() {
        let picks = [P(id: "a", name: "Sam", month: 3, day: 4), P(id: "b", name: "Lee"),
                     P(id: "c", name: "Ann", month: 1, day: 2), P(id: "d", name: "Kim", month: 5, day: 6)]
        let out = ContactImport.sort(picks, known: ["c"])
        XCTAssertEqual(out.ready.map(\.name), ["Sam", "Kim"])
        XCTAssertEqual(out.needDate.map(\.name), ["Lee"])
        XCTAssertEqual(out.already, 1)
    }

    func testSamePersonPickedTwiceCountsOnce() {
        let out = ContactImport.sort([P(id: "a", name: "Sam", month: 3, day: 4), P(id: "a", name: "Sam", month: 3, day: 4)], known: [])
        XCTAssertEqual(out.ready.count, 1)
        XCTAssertEqual(out.already, 1)
    }

    func testNamelessContactsAreLeftOut() {
        let out = ContactImport.sort([P(id: "a", name: "", month: 3, day: 4)], known: [])
        XCTAssertTrue(out.ready.isEmpty && out.needDate.isEmpty)
    }

    func testSummaryWords() {
        XCTAssertEqual(ContactImport.summary(.init(ready: [P(id: "a", name: "Sam")])), "Sam added.")
        XCTAssertEqual(ContactImport.summary(.init(ready: [P(id: "a", name: "Sam"), P(id: "b", name: "Lee")], already: 1)),
                       "2 added. 1 already in Held Dear.")
        XCTAssertEqual(ContactImport.summary(.init(already: 1)), "Already in Held Dear.")
        XCTAssertEqual(ContactImport.summary(.init()), "Nobody added.")
    }
}
