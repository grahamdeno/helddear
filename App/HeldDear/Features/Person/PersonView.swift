import ContactsUI
import PhotosUI
import SwiftUI

/// Person: name, ring, photo set, open wishes, occasions, ledger by year. A browse screen: tap any item to change it.
struct PersonView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let person: Person
    @State private var showRing = false
    @State private var linking = false
    @State private var editingDate = false
    @State private var photoItem: PhotosPickerItem?
    @State private var wishToEdit: Wish?
    @State private var entryToEdit: LedgerEntry?
    @State private var editedLine = ""
    @State private var confirmRemove = false
    @State private var phoneText = ""

    var body: some View {
        let _ = model.revision
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if person.contactID == nil { linkRow }
                if model.phone(for: person) == nil { phoneRow }
                section("Occasions") {
                    if let b = person.birthday, let next = model.nextMoment(for: person) {
                        OptionRow(title: "Birthday", caption: birthdayCaption(b, next)) { editingDate = true }
                    }
                }
                section("Wishes") {
                    ForEach(person.openWishes, id: \.id) { wish in
                        OptionRow(title: wish.text, caption: wishCaption(wish)) { wishToEdit = wish }
                    }
                    SecondaryButton(title: "Save a wish") { model.route = .addWish(person.id) }
                }
                section("Photos for the day") { photoStrip }
                if !person.ledger.isEmpty {
                    section("\(person.name)'s years") {
                        ForEach(person.sortedLedger, id: \.id) { entry in ledgerRow(entry) }
                    }
                }
                TextLink(title: "Remove \(person.name)") { confirmRemove = true }
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Brand.space5)
            .padding(.vertical, 16)
        }
        .background(Brand.page.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showRing) { RingSheet(person: person).presentationDetents([.medium]) }
        .sheet(isPresented: $linking) {
            ContactPicker { contact in
                person.contactID = contact.identifier
                if contact.isKeyAvailable(CNContactGivenNameKey) && contact.isKeyAvailable(CNContactFamilyNameKey) {
                    let full = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
                    if !full.isEmpty { person.fullName = full }
                }
                model.commit()
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $editingDate) { BirthdayEditor(person: person).presentationDetents([.medium]) }
        .onChange(of: photoItem) { _, item in addPhoto(item) }
        .confirmationDialog(wishToEdit?.text ?? "", isPresented: Binding(get: { wishToEdit != nil }, set: { if !$0 { wishToEdit = nil } }),
                            titleVisibility: .visible) {
            Button("Mark as given") { wishToEdit?.status = .used; model.commit() }
            Button("Remove it", role: .destructive) { wishToEdit?.status = .dismissed; model.commit() }
        }
        .alert("One line for \(entryToEdit.map { String($0.year) } ?? "")", isPresented: Binding(get: { entryToEdit != nil }, set: { if !$0 { entryToEdit = nil } })) {
            TextField("Your line", text: $editedLine)
            Button("Save") { entryToEdit?.line = editedLine.nilIfEmpty; model.save() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Remove \(person.name) from Held Dear?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                model.route = nil
                dismiss()
                model.delete(person)
            }
        } message: {
            Text("Their wishes and yearly record go too. Your contacts are not changed.")
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Face(person: person, size: 72)
            VStack(alignment: .leading, spacing: 6) {
                Text(person.name).textStyle(.title)
                Button { showRing = true } label: { Tag(text: person.ring.label) }
                    .buttonStyle(.plain)
                    .accessibilityHint("Changes how early Held Dear reminds you")
            }
        }
    }

    private var linkRow: some View {
        OptionRow(title: "Link to a contact", caption: "For their number, address and photo") { linking = true }
    }

    private var phoneRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Phone number, for the message on the day").font(TypeStyle.caption.font.weight(.bold)).foregroundStyle(Brand.inkMuted)
            HStack {
                TextField("Add a number", text: $phoneText).keyboardType(.phonePad).textStyle(.body)
                if !phoneText.isEmpty {
                    Button("Save") {
                        person.manualPhone = phoneText
                        model.commit()
                    }
                    .font(TypeStyle.callout.font.weight(.bold))
                }
            }
            .padding(.horizontal, Brand.space4).frame(minHeight: 56)
            .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
        }
        .onAppear { phoneText = person.manualPhone ?? "" }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Brand.space2) {
            Eyebrow(text: title)
            content()
        }
    }

    private func birthdayCaption(_ b: Occasion, _ next: Moment) -> String {
        let date = OccasionDates.longDate(next.dueDate)
        if let t = next.turning { return "\(date) · turning \(t)" }
        return date
    }

    private func wishCaption(_ wish: Wish) -> String {
        if let m = model.nextMoment(for: person), m.plan?.wishID == wish.id { return "Planned for this year" }
        return wish.savedLine
    }

    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Image(systemName: "plus").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(Brand.action)
                        .frame(width: 88, height: 88)
                        .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusSm, style: .continuous))
                }
                .accessibilityLabel("Add a photo")
                ForEach(person.photoFiles.reversed(), id: \.self) { file in
                    if let image = PhotoStore.load(file) {
                        Image(uiImage: image).resizable().scaledToFill()
                            .frame(width: 88, height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: Brand.radiusSm, style: .continuous))
                            .contextMenu {
                                Button("Remove photo", role: .destructive) {
                                    person.photoFiles.removeAll { $0 == file }
                                    PhotoStore.delete(file)
                                    model.save()
                                }
                            }
                    }
                }
            }
        }
    }

    private func ledgerRow(_ entry: LedgerEntry) -> some View {
        Button {
            editedLine = entry.line ?? ""
            entryToEdit = entry
        } label: {
            HStack(spacing: 14) {
                PhotoTile(image: PhotoStore.load(entry.photoFile), label: "No photo", height: 72, radius: Brand.radiusMd)
                    .frame(width: 72)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(entry.year)).textStyle(.eyebrow, color: Brand.inkMuted)
                    Text(entry.what).font(TypeStyle.body.font.weight(.heavy)).foregroundStyle(Brand.ink)
                    if let line = entry.line { Text(line).textStyle(.callout, color: Brand.ink.opacity(0.85)) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func addPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self), let file = PhotoStore.save(data: data) {
                person.photoFiles.append(file)
                model.save()
            }
            photoItem = nil
        }
    }
}

/// R2. "How close is Dan?"
struct RingSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let person: Person

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Face(person: person, size: 52)
                Text("How close is \(person.name)?").textStyle(.title)
            }
            VStack(spacing: Brand.space2) {
                ForEach(Ring.allCases) { ring in
                    let on = person.ring == ring
                    Button {
                        person.ring = ring
                        if let m = model.nextMoment(for: person), m.status == .upcoming { m.headsUpAt = nil }
                        model.commit()
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ring.label).font(TypeStyle.body.font.weight(.heavy)).foregroundStyle(Brand.ink)
                                Text(ring.promise).textStyle(.caption, color: Brand.inkMuted)
                            }
                            Spacer()
                            if on { CheckBadge() }
                        }
                        .padding(.vertical, Brand.space3).padding(.horizontal, Brand.space4)
                        .frame(minHeight: 64)
                        .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous).stroke(on ? Brand.action : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            Text("Only you see this. It changes how early Held Dear reminds you.").textStyle(.caption, color: Brand.inkMuted)
        }
        .padding(Brand.space5)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Brand.page.ignoresSafeArea())
    }
}

/// Change a birthday. Birth year is optional and used only for milestones.
struct BirthdayEditor: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let person: Person
    @State private var date = Date()
    @State private var knowsYear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(person.name)'s birthday").textStyle(.headline)
            DatePicker("Birthday", selection: $date, displayedComponents: .date)
                .datePickerStyle(.wheel).labelsHidden()
                .frame(maxWidth: .infinity)
            Toggle("I know the year", isOn: $knowsYear).textStyle(.body).tint(Brand.action)
            PrimaryButton(title: "Save") {
                let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
                if let b = person.birthday, !knowsYear { b.birthYear = nil }
                model.setBirthday(person, month: c.month ?? 1, day: c.day ?? 1, year: knowsYear ? c.year : nil)
                dismiss()
            }
        }
        .padding(Brand.space5)
        .background(Brand.page.ignoresSafeArea())
        .onAppear {
            guard let b = person.birthday else { return }
            knowsYear = b.birthYear != nil
            date = Calendar.current.date(from: DateComponents(year: b.birthYear ?? 2000, month: b.month, day: b.day)) ?? Date()
        }
    }
}

/// The system contact picker. Picking needs no Contacts permission.
struct ContactPicker: UIViewControllerRepresentable {
    var onPick: (CNContact) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let vc = CNContactPickerViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: CNContactPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onPick: (CNContact) -> Void
        init(onPick: @escaping (CNContact) -> Void) { self.onPick = onPick }
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) { onPick(contact) }
    }
}
