import Contacts
import UIKit

/// Reads birthdays, phone numbers, addresses and photos from Contacts. Read only: Held Dear never writes a contact.
struct ContactInfo: Identifiable, Hashable {
    var id: String
    var displayName: String
    var fullName: String
    var month: Int?
    var day: Int?
    var year: Int?
}

final class ContactsService {
    static let shared = ContactsService()
    private let store = CNContactStore()
    private var thumbnailCache: [String: UIImage] = [:]

    enum Access { case notDetermined, denied, limited, full }

    var access: Access {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .notDetermined: return .notDetermined
        case .authorized: return .full
        case .limited: return .limited
        default: return .denied
        }
    }

    var canRead: Bool { access == .full || access == .limited }

    func requestAccess() async -> Access {
        _ = try? await store.requestAccess(for: .contacts)
        return access
    }

    private var baseKeys: [CNKeyDescriptor] {
        [CNContactIdentifierKey, CNContactGivenNameKey, CNContactFamilyNameKey, CNContactNicknameKey,
         CNContactOrganizationNameKey, CNContactBirthdayKey] as [CNKeyDescriptor]
    }

    /// Every contact the app can see, with birthday fields when they exist.
    func allContacts() -> [ContactInfo] {
        guard canRead else { return [] }
        var result: [ContactInfo] = []
        let request = CNContactFetchRequest(keysToFetch: baseKeys)
        request.unifyResults = true
        try? store.enumerateContacts(with: request) { contact, _ in
            result.append(Self.info(contact))
        }
        return result
    }

    func contacts(matching name: String) -> [ContactInfo] {
        guard canRead, !name.isEmpty else { return [] }
        let predicate = CNContact.predicateForContacts(matchingName: name)
        let found = (try? store.unifiedContacts(matching: predicate, keysToFetch: baseKeys)) ?? []
        return found.map(Self.info)
    }

    func contact(id: String) -> ContactInfo? {
        guard canRead, let c = try? store.unifiedContact(withIdentifier: id, keysToFetch: baseKeys) else { return nil }
        return Self.info(c)
    }

    static func info(_ c: CNContact) -> ContactInfo {
        let full = [c.givenName, c.familyName].filter { !$0.isEmpty }.joined(separator: " ")
        let display = !c.nickname.isEmpty ? c.nickname : (!c.givenName.isEmpty ? c.givenName : (full.isEmpty ? c.organizationName : full))
        return ContactInfo(id: c.identifier, displayName: display, fullName: full.isEmpty ? display : full,
                           month: c.birthday?.month, day: c.birthday?.day,
                           year: c.birthday?.year == NSDateComponentUndefined ? nil : c.birthday?.year)
    }

    // MARK: Live fields

    func phone(contactID: String?) -> String? {
        guard canRead, let id = contactID,
              let c = try? store.unifiedContact(withIdentifier: id, keysToFetch: [CNContactPhoneNumbersKey as CNKeyDescriptor])
        else { return nil }
        let mobile = c.phoneNumbers.first { $0.label == CNLabelPhoneNumberMobile || $0.label == CNLabelPhoneNumberiPhone }
        return (mobile ?? c.phoneNumbers.first)?.value.stringValue
    }

    func address(contactID: String?) -> String? {
        guard canRead, let id = contactID,
              let c = try? store.unifiedContact(withIdentifier: id, keysToFetch: [CNContactPostalAddressesKey as CNKeyDescriptor]),
              let postal = c.postalAddresses.first?.value
        else { return nil }
        return CNPostalAddressFormatter.string(from: postal, style: .mailingAddress)
    }

    func thumbnail(contactID: String?) -> UIImage? {
        guard canRead, let id = contactID else { return nil }
        if let cached = thumbnailCache[id] { return cached }
        guard let c = try? store.unifiedContact(withIdentifier: id, keysToFetch: [CNContactThumbnailImageDataKey as CNKeyDescriptor]),
              let data = c.thumbnailImageData, let image = UIImage(data: data)
        else { return nil }
        thumbnailCache[id] = image
        return image
    }

    func photo(contactID: String?) -> UIImage? {
        guard canRead, let id = contactID,
              let c = try? store.unifiedContact(withIdentifier: id, keysToFetch: [CNContactImageDataKey as CNKeyDescriptor]),
              let data = c.imageData
        else { return nil }
        return UIImage(data: data)
    }
}
