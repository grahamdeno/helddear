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

    // Nov 22, 2026: a person picked again gets the card's number and address, never over what was typed.
    func testPickedAgainIsRefreshed() {
        let p = ContactImport.Pick(id: "c1", name: "Ada", month: 3, day: 4, phone: "555 0100")
        let out = ContactImport.sort([p, p], known: ["c1"])
        XCTAssertEqual(out.already, 2)
        XCTAssertEqual(out.again.map(\.id), ["c1"])
        XCTAssertTrue(out.ready.isEmpty)
    }

    func testFillsOnlyEmptyFields() {
        let home = MailAddress(firstName: "Ada", address1: "1 Elm St", city: "Town", state: "NC", zip: "28401")
        let p = ContactImport.Pick(id: "c1", name: "Ada", phone: "555 0100", address: home)
        let empty = p.fills(phone: nil, address: nil)
        XCTAssertEqual(empty.phone, "555 0100")
        XCTAssertEqual(empty.address, home)
        let typed = p.fills(phone: "555 0199", address: MailAddress(firstName: "Ada", address1: "2 Oak St", city: "City"))
        XCTAssertNil(typed.phone)
        XCTAssertNil(typed.address)
        XCTAssertEqual(p.fills(phone: "", address: nil).phone, "555 0100")
        XCTAssertNil(ContactImport.Pick(id: "c2", name: "Bo").fills(phone: nil, address: nil).phone)
    }

    func testSummaryMentionsDetails() {
        XCTAssertEqual(ContactImport.summary(.init(already: 1, detailsAdded: 1)),
                       "Already in Held Dear. Brought in a number or address from 1 card.")
    }
}
