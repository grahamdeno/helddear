import XCTest
@testable import HeldDear

final class AnniversaryPairTests: XCTestCase {
    private let mom = AnniversaryPair.Someone(id: UUID(), name: "Mom", fullName: "Ann Lee")
    private let dad = AnniversaryPair.Someone(id: UUID(), name: "Dad", fullName: "Ben Lee")
    private var people: [AnniversaryPair.Someone] { [mom, dad] }

    func testPartnerInTheAppByName() {
        XCTAssertEqual(AnniversaryPair.partner(type: .anniversary, partnerName: "Dad", extraRecipientIDs: [], ownerID: mom.id,
                                               people: people, yourName: "Sam"), .person(dad.id))
        XCTAssertEqual(AnniversaryPair.partner(type: .anniversary, partnerName: "ben lee", extraRecipientIDs: [], ownerID: mom.id,
                                               people: people, yourName: "Sam"), .person(dad.id))
    }

    func testTheUsersOwnAnniversary() {
        XCTAssertEqual(AnniversaryPair.partner(type: .anniversary, partnerName: "Sam", extraRecipientIDs: [], ownerID: mom.id,
                                               people: people, yourName: "Sam"), .you)
        XCTAssertEqual(AnniversaryPair.partner(type: .anniversary, partnerName: "you", extraRecipientIDs: [], ownerID: mom.id,
                                               people: people, yourName: ""), .you)
    }

    func testPartnerFromTheOtherRecipient() {
        XCTAssertEqual(AnniversaryPair.partner(type: .anniversary, partnerName: nil, extraRecipientIDs: [dad.id], ownerID: mom.id,
                                               people: people, yourName: "Sam"), .person(dad.id))
    }

    func testOnlyANameShowsInitials() {
        XCTAssertEqual(AnniversaryPair.partner(type: .anniversary, partnerName: "Alex Ray", extraRecipientIDs: [], ownerID: mom.id,
                                               people: people, yourName: "Sam"), .initials("Alex Ray"))
        XCTAssertEqual(AnniversaryPair.initials("Alex Ray"), "AR")
    }

    func testNothingToPair() {
        XCTAssertNil(AnniversaryPair.partner(type: .anniversary, partnerName: nil, extraRecipientIDs: [], ownerID: mom.id,
                                             people: people, yourName: "Sam"))
        XCTAssertNil(AnniversaryPair.partner(type: .birthday, partnerName: "Dad", extraRecipientIDs: [dad.id], ownerID: mom.id,
                                             people: people, yourName: "Sam"))
        XCTAssertNil(AnniversaryPair.partner(type: .anniversary, partnerName: "Mom", extraRecipientIDs: [mom.id], ownerID: mom.id,
                                             people: people, yourName: "Sam").flatMap { $0 == .person(mom.id) ? $0 : nil },
                     "Never pairs a person with themselves")
    }

    func testYourBirthdayKeepsOrDropsTheYear() throws {
        let d = try XCTUnwrap(UserDefaults(suiteName: "YouProfileTests"))
        d.removePersistentDomain(forName: "YouProfileTests")
        YouProfile.setBirthday(.init(month: 8, day: 5, year: nil), d)
        XCTAssertEqual(YouProfile.birthday(d), .init(month: 8, day: 5, year: nil))
        YouProfile.setBirthday(nil, d)
        XCTAssertNil(YouProfile.birthday(d))
    }
}
