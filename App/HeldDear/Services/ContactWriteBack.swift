import Contacts
import Foundation

/// The one place Held Dear writes to Contacts (Graham approved, Nov 22, 2026): adding a birthday to a contact card
/// that has none, only when the person taps "Add to Contacts". It never changes anything else, never overwrites a
/// birthday, and never removes anything. `scripts/privacy_guard.py` allows Contacts writes in this file only.
enum ContactWriteBack {
    /// True when the card exists and has no birthday. Without access it can't tell, so it offers (asking on tap).
    static func lacksBirthday(contactID: String) -> Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        guard status == .authorized || status == .limited else { return true }
        guard let c = try? CNContactStore().unifiedContact(withIdentifier: contactID,
                                                           keysToFetch: [CNContactBirthdayKey as CNKeyDescriptor])
        else { return false }
        return c.birthday?.month == nil
    }

    /// Adds the birthday to the card. Asks for Contacts access first if needed. Returns whether it was saved.
    static func addBirthday(contactID: String, month: Int, day: Int, year: Int?) async -> Bool {
        let store = CNContactStore()
        let status = CNContactStore.authorizationStatus(for: .contacts)
        if status == .notDetermined {
            guard (try? await store.requestAccess(for: .contacts)) == true else { return false }
        } else if status != .authorized && status != .limited {
            return false
        }
        guard let contact = try? store.unifiedContact(withIdentifier: contactID,
                                                      keysToFetch: [CNContactBirthdayKey as CNKeyDescriptor]),
              contact.birthday?.month == nil,
              let mutable = contact.mutableCopy() as? CNMutableContact else { return false }
        var b = DateComponents()
        b.month = month
        b.day = day
        if let year { b.year = year }
        mutable.birthday = b
        let request = CNSaveRequest()
        request.update(mutable)
        do {
            try store.execute(request)
            return true
        } catch {
            return false
        }
    }
}
