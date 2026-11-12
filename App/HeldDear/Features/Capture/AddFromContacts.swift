import Contacts
import ContactsUI
import SwiftUI
import UIKit

/// "Add from contacts", any time after setup.
/// Limited access: Apple's picker to share more people, then a sync brings in their birthdays.
/// Full access: every birthday already syncs, so the picker offers a person without one and opens Add a birthday.
/// Not decided yet: ask. Denied: Settings.
struct AddFromContactsModifier: ViewModifier {
    @EnvironmentObject var model: AppModel
    @Binding var isPresented: Bool
    @State private var showAccessPicker = false
    @State private var showContactPicker = false
    @State private var result: String?

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, open in
                guard open else { return }
                isPresented = false
                start()
            }
            .contactAccessPicker(isPresented: $showAccessPicker) { _ in
                finishSync()
            }
            .sheet(isPresented: $showContactPicker) {
                ContactPicker { contact in
                    showContactPicker = false
                    pickedWithFullAccess(contact)
                }
                .ignoresSafeArea()
            }
            .alert(result ?? "", isPresented: Binding(get: { result != nil }, set: { if !$0 { result = nil } })) {
                Button("OK", role: .cancel) {}
            }
    }

    private func start() {
        switch ContactsService.shared.access {
        case .limited:
            showAccessPicker = true
        case .full:
            showContactPicker = true
        case .notDetermined:
            Task {
                let access = await ContactsService.shared.requestAccess()
                if access == .full || access == .limited { finishSync() }
            }
        case .denied:
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        }
    }

    private func finishSync() {
        let added = model.syncContacts()
        model.commit()
        result = added == 0 ? "No new birthdays found. People without a birthday in Contacts can be added by name."
                            : (added == 1 ? "1 person added." : "\(added) people added.")
    }

    private func pickedWithFullAccess(_ contact: CNContact) {
        let name: String
        if contact.isKeyAvailable(CNContactNicknameKey), !contact.nickname.isEmpty {
            name = contact.nickname
        } else if contact.isKeyAvailable(CNContactGivenNameKey), !contact.givenName.isEmpty {
            name = contact.givenName
        } else {
            name = ""
        }
        if model.allPeople().contains(where: { $0.contactID == contact.identifier }) {
            result = "\(name.isEmpty ? "They're" : name + " is") already in Held Dear."
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
