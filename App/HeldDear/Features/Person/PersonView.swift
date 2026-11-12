import ContactsUI
import PhotosUI
import SwiftUI
import UIKit

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
    @State private var showLifetime = false
    @ObservedObject private var purchases = Purchases.shared

    var body: some View {
        let _ = model.revision
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if let next = model.nextMoment(for: person) { scheduleCard(next) }
                if purchases.hasLifetime, let entry = oneYearAgo { lookBack(entry) }
                if person.ring == .inner && person.photoFiles.isEmpty { photoNudge }
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
                section("Photos for the card") {
                    photoStrip
                    Toggle(isOn: Binding(get: { person.showAgeOnCard }, set: { person.showAgeOnCard = $0; model.save() })) {
                        Text("Show \(person.name)'s age on the card").textStyle(.body)
                    }
                    .tint(Brand.action)
                    .padding(.vertical, Brand.space3).padding(.horizontal, Brand.space4)
                    .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
                }
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
        .onChange(of: linking) { _, open in
            guard open else { return }
            linking = false
            ContactPickerPresenter.shared.present { contact in
                person.contactID = contact.identifier
                if contact.isKeyAvailable(CNContactGivenNameKey) && contact.isKeyAvailable(CNContactFamilyNameKey) {
                    let full = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
                    if !full.isEmpty { person.fullName = full }
                }
                model.commit()
            }
        }
        .sheet(isPresented: $editingDate) { BirthdayEditor(person: person).presentationDetents([.medium]) }
        .sheet(isPresented: $showLifetime) { LifetimeView() }
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
            Face(person: person, size: 96)
            VStack(alignment: .leading, spacing: 6) {
                Text(person.name).textStyle(.title)
                if let next = model.nextMoment(for: person) {
                    let date = next.dueDate.formatted(.dateTime.weekday(.wide).month(.wide).day())
                    Text(next.turning.map { "Turns \($0) on \(date)" } ?? "Birthday on \(date)")
                        .textStyle(.callout, color: Brand.inkMuted)
                }
                Button { showRing = true } label: { Tag(text: person.ring.label) }
                    .buttonStyle(.plain)
                    .accessibilityHint("Changes how early Held Dear reminds you")
            }
        }
    }

    /// "What Held Dear will do": the coming heads-up, order-by and message-ready dates for this person.
    private func scheduleCard(_ m: Moment) -> some View {
        let stops = AlertPlanner.schedule(for: model.state(for: m))
        let now = Date()
        return VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "What Held Dear will do").padding(.bottom, Brand.space3)
            if stops.isEmpty {
                Text(m.status.isSettled || m.status == .done ? "This year is taken care of." : "A message ready on the day.")
                    .textStyle(.body)
            }
            ForEach(Array(stops.enumerated()), id: \.offset) { i, stop in
                let past = stop.date <= now
                HStack(alignment: .top, spacing: Brand.space3) {
                    VStack(spacing: 0) {
                        ZStack {
                            Circle().fill(past ? Brand.line : Brand.accent).frame(width: 10, height: 10)
                            if past {
                                Image(systemName: "checkmark").font(.system(size: 7, weight: .heavy)).foregroundStyle(Brand.inkMuted)
                            }
                        }
                        .padding(.top, 6)
                        if i < stops.count - 1 { Rectangle().fill(Brand.line).frame(width: 2).frame(maxHeight: .infinity) }
                    }
                    .frame(width: 12)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stop.showsTime ? stop.date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
                                            : stop.date.formatted(.dateTime.month(.abbreviated).day()))
                            .textStyle(.caption, color: Brand.inkMuted)
                        Text(stop.label).textStyle(.body, color: past ? Brand.inkMuted : Brand.ink)
                    }
                    .padding(.bottom, Brand.space3)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(Brand.space4)
        .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
    }

    private var oneYearAgo: LedgerEntry? {
        let year = Calendar.current.component(.year, from: Date())
        return person.sortedLedger.first { $0.year == year - 1 } ?? person.sortedLedger.first { $0.year < year }
    }

    /// 1 year ago (Lifetime): last year's card and line, with a keepsake to share.
    private func lookBack(_ entry: LedgerEntry) -> some View {
        VStack(alignment: .leading, spacing: Brand.space3) {
            Eyebrow(text: "\(Calendar.current.component(.year, from: Date()) - entry.year == 1 ? "1 year ago" : String(entry.year))")
            HStack(alignment: .top, spacing: 14) {
                PhotoTile(image: PhotoStore.load(entry.cardFile ?? entry.photoFile), label: "Card", height: 112, radius: Brand.radiusSm)
                    .frame(width: 80)
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.what).textStyle(.bodyStrong)
                    if let line = entry.line { Text(line).textStyle(.body, color: Brand.ink.opacity(0.85)) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let image = Keepsake.image(person: person, entry: entry) {
                ShareLink(item: Image(uiImage: image), preview: SharePreview("\(person.name), \(entry.year)", image: Image(uiImage: image))) {
                    Text("Share as keepsake").font(TypeStyle.callout.font.weight(.heavy))
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .foregroundStyle(Brand.action)
                        .background(Brand.page, in: Capsule())
                }
            }
        }
        .padding(Brand.space4)
        .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
    }

    /// A skipped Get ahead photo: one quiet next step.
    private var photoNudge: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            HStack(spacing: 14) {
                Image(systemName: "plus").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(Brand.ink)
                    .frame(width: 56, height: 56)
                    .background(Brand.faceFills[0], in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add a photo for \(person.name)'s card").font(TypeStyle.callout.font.weight(.heavy)).foregroundStyle(Brand.ink)
                    Text("It stays on this iPhone").textStyle(.caption, color: Brand.inkMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Brand.space4)
            .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
        }
        .buttonStyle(.plain)
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
/// It must be presented directly by UIKit: wrapped in a SwiftUI sheet it shows a blank screen
/// (build 1003 bug, Nov 12). The picker dismisses itself when a contact is chosen or on Cancel.
@MainActor
final class ContactPickerPresenter: NSObject, CNContactPickerDelegate {
    static let shared = ContactPickerPresenter()
    private var onPick: ((CNContact) -> Void)?

    func present(onPick: @escaping (CNContact) -> Void) {
        guard let top = Self.topViewController() else { return }
        self.onPick = onPick
        let picker = CNContactPickerViewController()
        picker.delegate = self
        top.present(picker, animated: true)
    }

    nonisolated func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        Task { @MainActor in
            let callback = self.onPick
            self.onPick = nil
            // Let the picker finish dismissing before the app changes screens.
            try? await Task.sleep(nanoseconds: 450_000_000)
            callback?(contact)
        }
    }

    nonisolated func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        Task { @MainActor in self.onPick = nil }
    }

    static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        let window = scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
        var top = window?.rootViewController
        while let next = top?.presentedViewController, !next.isBeingDismissed { top = next }
        return top
    }
}
