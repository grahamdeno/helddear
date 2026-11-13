import SwiftUI
import UIKit

/// On the Person page: start a family page for the next day, or manage the one that exists.
struct FamilyPageSection: View {
    @EnvironmentObject var model: AppModel
    let person: Person
    let moment: Moment
    @State private var starting = false
    @State private var notes: [FamilyPages.Note] = []
    @State private var loadError: String?
    @State private var noteToRemove: FamilyPages.Note?
    @State private var confirmDelete = false

    var body: some View {
        let days = OccasionDates.daysBetween(Date(), moment.dueDate)
        VStack(alignment: .leading, spacing: Brand.space3) {
            if let invite = moment.familyInviteURL.flatMap(URL.init(string:)),
               let gift = moment.familyGiftURL.flatMap(URL.init(string:)) {
                Text("Notes for \(person.name)").textStyle(.headline)
                Text(countLine).textStyle(.callout, color: Brand.inkMuted)
                if days <= 0 {
                    ShareLink(item: gift, message: Text(moment.type.greeting(name: person.name))) {
                        buttonLabel("Send \(person.name) the page", filled: true)
                    }
                    ShareLink(item: invite) { buttonLabel("Invite more family", filled: false) }
                } else {
                    ShareLink(item: invite, message: Text("Add a note for \(person.name)'s \(moment.type.label.lowercased()). \(person.name) sees them all on the day.")) {
                        buttonLabel("Invite family", filled: true)
                    }
                    Text("On the day, send \(person.name) the page from here.").textStyle(.caption, color: Brand.inkMuted)
                }
                ForEach(notes) { n in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(n.text).textStyle(.body)
                        Text(n.name).textStyle(.caption, color: Brand.inkMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Brand.space3)
                    .overlay(alignment: .top) { Rectangle().fill(Brand.line).frame(height: 1) }
                    .contextMenu { Button("Remove note", role: .destructive) { noteToRemove = n } }
                }
                if let loadError { Text(loadError).textStyle(.caption, color: Brand.error) }
                TextLink(title: "Delete the page") { confirmDelete = true }
            } else if days >= 2 {
                OptionRow(title: "Gather notes from family",
                          caption: "A page for \(person.name)'s day. Family adds notes from a link, no app needed.") { starting = true }
            }
        }
        .task(id: moment.familyPageID) { await load() }
        .sheet(isPresented: $starting) { FamilyPageFlow(person: person, moment: moment) }
        .confirmationDialog("Remove this note from \(noteToRemove?.name ?? "")?", isPresented: Binding(get: { noteToRemove != nil }, set: { if !$0 { noteToRemove = nil } }),
                            titleVisibility: .visible) {
            Button("Remove", role: .destructive) { if let n = noteToRemove { Task { await remove(n) } } }
        }
        .confirmationDialog("Delete the page and every note on it?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await deletePage() } }
        } message: {
            Text("The links stop working. This can't be undone.")
        }
    }

    private var countLine: String {
        switch notes.count {
        case 0: "No notes yet."
        case 1: "1 note so far. Only you and \(person.name) see them."
        default: "\(notes.count) notes so far. Only you and \(person.name) see them."
        }
    }

    private func buttonLabel(_ title: String, filled: Bool) -> some View {
        Text(title).font(TypeStyle.bodyStrong.font)
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(filled ? Brand.onAction : Brand.action)
            .background(filled ? Brand.action : Color.clear, in: Rectangle())
            .overlay(Rectangle().stroke(Brand.action, lineWidth: 1))
    }

    private func load() async {
        guard let id = moment.familyPageID, let key = moment.familyOwnerKey else { notes = []; return }
        do {
            notes = try await FamilyPages.notes(id: id, ownerKey: key)
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func remove(_ n: FamilyPages.Note) async {
        guard let id = moment.familyPageID, let key = moment.familyOwnerKey else { return }
        do {
            try await FamilyPages.removeNote(id: id, ownerKey: key, noteID: n.id)
            notes.removeAll { $0.id == n.id }
        } catch { loadError = error.localizedDescription }
    }

    private func deletePage() async {
        guard let id = moment.familyPageID, let key = moment.familyOwnerKey else { return }
        do {
            try await FamilyPages.delete(id: id, ownerKey: key)
        } catch let e as FamilyPages.Failure where e.message != "This page has ended." {
            loadError = e.message
            return
        } catch {}
        moment.familyPageID = nil; moment.familyOwnerKey = nil
        moment.familyInviteURL = nil; moment.familyGiftURL = nil
        notes = []
        model.save()
    }
}

/// Make a family page: what it is and what leaves the phone, your name, a line for family, then make it.
struct FamilyPageFlow: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let person: Person
    let moment: Moment
    @State private var fromName = MailAddress.saved?.firstName ?? ""
    @State private var line = ""
    @State private var includePhoto = true
    @State private var working = false
    @State private var error: String?

    private var photo: UIImage? { PhotoStore.load(person.photoFiles.last) }

    var body: some View {
        FlowScreen(onClose: { dismiss() }) {
            Question(title: "Gather notes for \(person.name)?",
                     subtitle: "Held Dear makes a private page. Family adds notes from a link, with no app or account. On the day, you send \(person.name) the page.")
            LineField(label: "Your name, as family knows you", text: $fromName, placeholder: "Graham", showsDictation: false)
            LineField(label: "A line for family (optional)", text: $line,
                      placeholder: "Write a note for \(person.name) by \(OccasionDates.shortDate(OccasionDates.adding(days: -1, to: moment.dueDate)))")
            if photo != nil {
                Toggle(isOn: $includePhoto) { Text("Put \(person.name)'s photo at the top").textStyle(.body) }.tint(Brand.action)
            }
            Text("The page keeps \(person.name)'s first name, the date, your name and line\(photo != nil ? ", the photo" : "") and family's notes on Held Dear's server. All of it is deleted 30 days after the day. You can delete it sooner.")
                .textStyle(.caption, color: Brand.inkMuted)
            if let error { Text(error).textStyle(.callout, color: Brand.error) }
        } footer: {
            PrimaryButton(title: working ? "Making the page…" : "Make the page") { Task { await make() } }
                .disabled(working || fromName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func make() async {
        working = true
        defer { working = false }
        do {
            let c = try await FamilyPages.create(firstName: person.name, occasion: moment.type, date: moment.dueDate,
                                                 fromName: fromName.trimmingCharacters(in: .whitespaces),
                                                 message: line.trimmingCharacters(in: .whitespacesAndNewlines),
                                                 photo: includePhoto ? photo : nil)
            moment.familyPageID = c.id
            moment.familyOwnerKey = c.ownerKey
            moment.familyInviteURL = c.inviteURL
            moment.familyGiftURL = c.giftURL
            model.save()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
