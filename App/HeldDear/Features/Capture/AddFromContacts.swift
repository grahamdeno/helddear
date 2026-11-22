import Contacts
import ContactsUI
import SwiftUI
import UIKit

/// "Add from contacts", any time after setup.
/// Always Apple's contact picker, presented directly by UIKit (it needs no Contacts permission and returns the
/// chosen people's details, birthdays included). Presented after a short pause so a closing menu or sheet can't
/// leave it blank (build 1006 bug, Nov 12). Several can be picked at once (Nov 21): people with a birthday are
/// added straight away; each one without gets Add a birthday with the name filled in, one after another.
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
                    MultiContactPickerPresenter.shared.present { contacts in picked(contacts) }
                }
            }
            .alert(result ?? "", isPresented: Binding(get: { result != nil }, set: { if !$0 { result = nil } })) {
                Button("OK", role: .cancel) {}
            }
    }

    private func picked(_ contacts: [CNContact]) {
        let outcome = ContactImport.sort(contacts.map(ContactImport.Pick.init), known: Set(model.allPeople().compactMap(\.contactID)))
        for p in outcome.ready {
            model.addPerson(name: p.name, fullName: p.fullName, contactID: p.id, month: p.month!, day: p.day!, year: p.year)
        }
        if !outcome.ready.isEmpty { model.commit() }
        let needDates = outcome.needDate.map(\.name)
        if let first = needDates.first {
            model.contactsToDate = Array(needDates.dropFirst())
            model.route = .addBirthday("\(first), ")
        } else {
            result = ContactImport.summary(outcome)
        }
    }
}

extension View {
    func addFromContacts(isPresented: Binding<Bool>) -> some View {
        modifier(AddFromContactsModifier(isPresented: isPresented))
    }
}
