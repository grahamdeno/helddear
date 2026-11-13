import Contacts
import ContactsUI
import SwiftUI
import UIKit

/// "Add from contacts", any time after setup.
/// Always Apple's contact picker, presented directly by UIKit (it needs no Contacts permission and returns the
/// chosen person's details, birthday included). Presented after a short pause so a closing menu or sheet can't
/// leave it blank (build 1006 bug, Nov 12). A person with a birthday is added straight away; one without opens
/// Add a birthday with the name filled in.
struct AddFromContactsModifier: ViewModifier {
    @EnvironmentObject var model: AppModel
    @Binding var isPresented: Bool
    @State private var result: String?

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, open in
                guard open else { return }
                isPresented = false
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    ContactPickerPresenter.shared.present { contact in picked(contact) }
                }
            }
            .alert(result ?? "", isPresented: Binding(get: { result != nil }, set: { if !$0 { result = nil } })) {
                Button("OK", role: .cancel) {}
            }
    }

    private func picked(_ contact: CNContact) {
        let given = contact.isKeyAvailable(CNContactGivenNameKey) ? contact.givenName : ""
        let family = contact.isKeyAvailable(CNContactFamilyNameKey) ? contact.familyName : ""
        let nick = contact.isKeyAvailable(CNContactNicknameKey) ? contact.nickname : ""
        let name = !nick.isEmpty ? nick : (!given.isEmpty ? given : family)
        let full = [given, family].filter { !$0.isEmpty }.joined(separator: " ")

        if model.allPeople().contains(where: { $0.contactID == contact.identifier }) {
            result = "\(name.isEmpty ? "They're" : name + " is") already in Held Dear."
            return
        }
        if contact.isKeyAvailable(CNContactBirthdayKey), let b = contact.birthday, let month = b.month, let day = b.day,
           month != NSDateComponentUndefined, day != NSDateComponentUndefined, !name.isEmpty {
            let year = (b.year == nil || b.year == NSDateComponentUndefined) ? nil : b.year
            model.addPerson(name: name, fullName: full.isEmpty ? nil : full, contactID: contact.identifier,
                            month: month, day: day, year: year)
            model.commit()
            result = "\(name) added."
            return
        }
        model.route = .addBirthday(name.isEmpty ? "" : "\(name), ")
    }
}

extension View {
    func addFromContacts(isPresented: Binding<Bool>) -> some View {
        modifier(AddFromContactsModifier(isPresented: isPresented))
    }
}
