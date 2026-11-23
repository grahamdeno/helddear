import ContactsUI
import Photos
import PhotosUI
import SwiftUI
import UIKit

/// Person: name, ring, photo set, open wishes, occasions, ledger by year. A browse screen: tap any item to change it.
struct PersonView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let person: Person
    /// The occasion (a Moment's id) to show first, when the page was opened from it.
    var focus: UUID? = nil
    /// One page in: relationship, days, reminders, card photos and Remove.
    var showsDetails = false
    /// One part on its own page, opened from its tile.
    var part: PersonPart? = nil
    @State private var selectedID: UUID?
    /// Past the photo, the page's own bar shows: the back link and the person's name.
    @State private var pastHero = false
    @State private var showRing = false
    @State private var addingTo: Moment?
    @State private var linking = false
    @State private var editingDate = false
    /// Several photos at once (Graham, Nov 21, 2026): pick as many as you like in one go.
    @State private var photoItems: [PhotosPickerItem] = []
    /// Progress and the result of adding a big set of photos.
    @State private var photoNote: String?
    /// A photo opened from the strip: shown large with plain buttons, in place of a press-and-hold menu.
    @State private var photoToManage: String?
    /// The anniversary getting a couple photo, and the picked photo (Graham, Nov 21, 2026).
    @State private var couplePhotoFor: Occasion?
    @State private var couplePick: PhotosPickerItem?
    @State private var wishToEdit: Wish?
    @State private var entryToEdit: LedgerEntry?
    @State private var editedLine = ""
    @State private var confirmRemove = false
    @State private var editingAddress = false
    @State private var editingPhone = false
    @State private var showLifetime = false
    @State private var editingPortrait = false
    @State private var addingOccasion = false
    @State private var occasionToEdit: Occasion?
    @State private var showIdeas = false
    @State private var sendingCard = false
    @State private var sharingDay: Moment?
    @State private var familyAsk: FamilyAsk?
    @State private var editingFamily = false
    @State private var familyToggle = 0
    @State private var alertToggle = 0
    @State private var messageFor: Moment?
    @ObservedObject private var purchases = Purchases.shared

    var body: some View {
        let _ = model.revision
        Group {
            if showsDetails { detailsPage } else if let part { partPage(part) } else { mainPage }
        }
        .background(Brand.page.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $addingTo) { m in
            PlanView(moment: m, onClose: { addingTo = nil }, startOnAdd: true)
                .environmentObject(model)
        }
        .fullScreenCover(item: $sharingDay) { day in
            ShareDayFlow(moment: day) { sharingDay = nil }.environmentObject(model)
        }
        .fullScreenCover(item: $familyAsk) { ask in
            FamilyInFlow(person: person, moment: ask.moment, followUp: ask.followUp) { familyAsk = nil; familyToggle += 1 }
                .environmentObject(model)
        }
        .sheet(isPresented: $editingFamily, onDismiss: { familyToggle += 1 }) { FamilyRecipientsSheet(person: person) }
        .sheet(item: $messageFor, onDismiss: { alertToggle += 1 }) { m in
            DayMessageEditor(person: person, moment: m).environmentObject(model)
        }
        .fullScreenCover(isPresented: $sendingCard) {
            ReasonCardFlow(person: person) { sendingCard = false }.environmentObject(model)
        }
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
                model.keepContactDetails(ContactImport.Pick(contact), on: person)
                model.commit()
            }
        }
        .sheet(isPresented: $editingDate) { BirthdayEditor(person: person).presentationDetents([.medium]) }
        .sheet(isPresented: $showLifetime) { LifetimeView() }
        .sheet(isPresented: $editingPortrait) { PortraitEditor(person: person).presentationDetents([.large]) }
        .sheet(isPresented: $addingOccasion) { AddOccasionView(person: person) }
        .sheet(isPresented: $editingAddress) { AddressEditor(person: person) }
        .onAppear {
            // From the six-week "What does Ana love?" alert.
            if model.openLovesFor == person.id { model.openLovesFor = nil; editingPortrait = true }
            // From the two-week or three-day alert: straight to the flow, which starts on who to ask.
            if let id = model.openFamilyFor, let m = model.moment(id), m.person?.id == person.id {
                model.openFamilyFor = nil
                let record = FamilyCircle.shared.record(for: id)
                familyAsk = FamilyAsk(moment: m, followUp: record.choice == .card && !record.followedUp)
            }
        }
        .sheet(isPresented: $editingPhone) { PhoneEditor(person: person).presentationDetents([.medium]) }
        .sheet(isPresented: $showIdeas) { IdeasSheet(person: person, moment: model.nextMoment(for: person)) }
        .confirmationDialog(occasionToEdit.map { $0.type.subject(name: person.name, partner: $0.partnerName) } ?? "",
                            isPresented: Binding(get: { occasionToEdit != nil }, set: { if !$0 { occasionToEdit = nil } }),
                            titleVisibility: .visible) {
            if let o = occasionToEdit, o.type == .anniversary {
                let has = OccasionPhotos.file(for: o.id) != nil
                Button(has ? "Change the couple photo" : "Add a couple photo") { couplePhotoFor = o }
                if has { Button("Remove the couple photo") { OccasionPhotos.set(nil, for: o.id); model.save() } }
            }
            Button("Remove", role: .destructive) { if let o = occasionToEdit { model.removeOccasion(o) } }
        }
        .photosPicker(isPresented: Binding(get: { couplePhotoFor != nil }, set: { if !$0 && couplePick == nil { couplePhotoFor = nil } }),
                      selection: $couplePick, matching: .images)
        .onChange(of: couplePick) { _, item in
            guard let item, let o = couplePhotoFor else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let file = PhotoStore.save(data: data) {
                    OccasionPhotos.set(file, for: o.id)
                    model.save()
                }
                couplePick = nil
                couplePhotoFor = nil
            }
        }
        .onChange(of: photoItems) { _, items in addPhotos(items) }
        .sheet(item: Binding(get: { photoToManage.map { ManagedPhoto(file: $0) } }, set: { photoToManage = $0?.file })) { p in
            PhotoActions(file: p.file, isTop: p.file == person.photoFiles.last,
                         useAtTop: {
                             person.photoFiles.removeAll { $0 == p.file }
                             person.photoFiles.append(p.file)
                             model.save()
                             photoToManage = nil
                         },
                         remove: {
                             photoToManage = nil
                             model.removePhotoWithUndo(p.file, from: person)
                         }, personName: DisplayName.plain(person.name))
                .presentationDetents([.medium, .large])
        }
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
        .confirmationDialog("Remove \(DisplayName.plain(person.name)) from Held Dear?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                model.route = nil
                model.navPath = []
                model.delete(person)
            }
        } message: {
            Text("Their saved ideas and yearly record go too. Your contacts are not changed.")
        }
    }

    // MARK: The page (approved Nov 20, 2026)

    /// The person's page: the photo hero, the day cards, the selected day's plan grouped by what it is, what they
    /// love, then one row to everything else.
    private var mainPage: some View {
        let moments = planMoments
        let selected = moments.first { $0.id == (selectedID ?? focus) } ?? moments.first
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PersonHero(person: person, line: heroLine, tag: heroTag)
                    .padding(.horizontal, -Brand.space5)
                VStack(alignment: .leading, spacing: Brand.space5) {
                    actionsRow
                    if let next = model.nextMoment(for: person) {
                        FamilyInSuggestion(person: person, moment: next) { followUp in
                            familyAsk = FamilyAsk(moment: next, followUp: followUp)
                        }
                        .id(familyToggle)
                    }
                    if !moments.isEmpty {
                        PersonDayCards(moments: moments, selectedID: Binding(get: { selected?.id }, set: { if let id = $0 { selectedID = id } }),
                                       addTitle: purchases.hasLifetime ? "Add a day" : "Add a day · Lifetime") {
                            if purchases.hasLifetime { addingOccasion = true } else { showLifetime = true }
                        }
                    }
                    if let selected {
                        PersonPlanSection(moment: selected) { addingTo = selected }
                    }
                    // Four doors, one tap each, instead of every section stacked (Graham, Nov 22, 2026).
                    partTiles
                    if purchases.hasLifetime, let entry = oneYearAgo { lookBack(entry) }
                    if !person.ledger.isEmpty {
                        section("Through the years") {
                            ForEach(person.sortedLedger, id: \.id) { entry in ledgerRow(entry) }
                        }
                    }
                }
                .padding(.top, Brand.space3)
            }
            .padding(.horizontal, Brand.space5)
            .padding(.bottom, Brand.space6)
        }
        .ignoresSafeArea(edges: .top)
        .onScrollGeometryChange(for: Bool.self) { g in
            g.contentOffset.y + g.contentInsets.top > PersonHero.height - 150
        } action: { _, past in
            withAnimation(.easeOut(duration: 0.2)) { pastHero = past }
        }
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .top) { topBar }
    }

    /// Over the photo, the back link sits on a solid dark pill so it reads on any photo and stays clear of the name.
    /// Scrolled past the photo, a plain bar in the page colour takes over with the back link and the person's name.
    @ViewBuilder private var topBar: some View {
        let back = model.backTitle(for: .person(person.id, focus: focus))
        if pastHero {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Button { dismiss() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").font(.body.weight(.semibold))
                            Text(back).lineLimit(1)
                        }
                        .foregroundStyle(Brand.action)
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back to \(back)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(DisplayName.plain(person.name)).font(Brand.serif(19, relativeTo: .headline)).foregroundStyle(Brand.ink)
                        .lineLimit(1)
                        .accessibilityAddTraits(.isHeader)
                    Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                }
                .padding(.horizontal, Brand.space4)
                Rectangle().fill(Brand.line).frame(height: 1)
            }
            .background(Brand.page.ignoresSafeArea(edges: .top))
            .transition(.opacity)
        } else {
            HStack {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.body.weight(.semibold))
                        Text(back).lineLimit(1)
                    }
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.leading, 10).padding(.trailing, 14)
                    .frame(minHeight: 40)
                    .background(Color.black.opacity(0.72), in: Capsule())
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to \(back)")
                Spacer()
            }
            .padding(.horizontal, Brand.space4)
            .transition(.opacity)
        }
    }

    /// Everything else about the person, one page in from their page.
    /// Everything else about the person, one page in (restructured Nov 21, 2026): short groups whose rows show
    /// their value and open one thing. Nothing appears or disappears depending on what's missing.
    private var detailsPage: some View {
        let name = DisplayName.plain(person.name)
        let phone = model.phone(for: person)
        let contactAddress = ContactsService.shared.mailAddress(contactID: person.contactID)
        return ScrollView {
            VStack(alignment: .leading, spacing: Brand.space5) {
                Text("\(name)'s details").textStyle(.title).accessibilityAddTraits(.isHeader)
                group("About") {
                    YouRow(icon: "heart", title: "Relationship", detail: person.relationship ?? "Add", caption: nil) {
                        model.push(.relationship(person.id))
                    }
                    YouDivider()
                    YouRow(icon: "bell", title: "Reminders", detail: person.ring.label, caption: nil) { showRing = true }
                    YouDivider()
                    YouRow(icon: "person.crop.circle", title: "Contact", detail: person.contactID == nil ? "Link" : "Linked",
                           caption: person.contactID == nil ? "For their number, address and photo" : nil) { linking = true }
                }
                group("Days") {
                    ForEach(Array(sortedOccasions.enumerated()), id: \.element.id) { i, o in
                        if i > 0 { YouDivider() }
                        YouRow(icon: dayIcon(o), title: dayTitle(o), detail: dayValue(o),
                               caption: o.type == .anniversary
                                   ? (OccasionPhotos.file(for: o.id) != nil ? "Couple photo set" : "Tap to add a couple photo") : nil) {
                            if o.type == .birthday { editingDate = true } else { occasionToEdit = o }
                        }
                    }
                    ForEach(contactOffers) { d in
                        YouDivider()
                        YouRow(icon: "plus.circle", title: ContactDates.title(d),
                               detail: OccasionDates.date(month: d.month, day: d.day, year: 2028).formatted(.dateTime.month(.abbreviated).day()),
                               caption: "On \(name)'s contact. Tap to add") { addContactDate(d) }
                    }
                    YouDivider()
                    YouRow(icon: "plus", title: purchases.hasLifetime ? "Add a day" : "Add a day · Lifetime", detail: nil, caption: nil) {
                        if purchases.hasLifetime { addingOccasion = true } else { showLifetime = true }
                    }
                }
                group("Reaching \(name)") {
                    YouRow(icon: "phone", title: "Phone", detail: phone ?? "Add",
                           caption: person.manualPhone == nil && phone != nil ? "From Contacts" : nil) { editingPhone = true }
                    YouDivider()
                    YouRow(icon: "envelope", title: "Mailing address",
                           detail: contactAddress.map { _ in "From Contacts" } ?? (person.mailingAddress == nil ? "Add" : "Saved"),
                           caption: contactAddress?.oneLine ?? person.mailingAddress?.oneLine) {
                        if contactAddress == nil { editingAddress = true }
                    }
                }
                group("Family") {
                    Toggle(isOn: Binding(get: { familyIsOn }, set: { FamilyCircle.shared.setOn($0, for: person.id); familyToggle += 1
                                                                        Task { await model.scheduleAlerts() } })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Suggest getting the family in").textStyle(.body)
                            Text("Two weeks before \(name)'s days: ask the people you pick to add a note or send a card.")
                                .textStyle(.caption, color: Brand.inkMuted)
                        }
                    }
                    .tint(Brand.action)
                    .padding(.vertical, Brand.space3)
                    .id(familyToggle)
                    YouDivider()
                    YouRow(icon: "person.2", title: "Who to ask", detail: familyCountText, caption: nil) { editingFamily = true }
                        .id(familyToggle)
                }
                group("Cards") {
                    Toggle(isOn: Binding(get: { person.showAgeOnCard }, set: { person.showAgeOnCard = $0; model.save() })) {
                        Text("Show \(name)'s age on the card").textStyle(.body)
                    }
                    .tint(Brand.action)
                    .padding(.vertical, Brand.space3)
                }
                if let next = model.nextMoment(for: person) {
                    if AppFeatures.familyPages { FamilyPageSection(person: person, moment: next) }
                    scheduleCard(next)
                }
                TextLink(title: "Remove \(name) from Held Dear") { confirmRemove = true }
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Brand.space5)
            .padding(.vertical, 16)
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Brand.space2) {
            Eyebrow(text: title).padding(.leading, Brand.space1)
            VStack(spacing: 0) { content() }
                .buttonStyle(PressStyle())
                .padding(.horizontal, Brand.space4)
                .background(Brand.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func dayIcon(_ o: Occasion) -> String {
        switch o.type {
        case .birthday: "gift"
        case .anniversary: "heart.circle"
        default: o.type.kind == .holiday ? "star" : "calendar"
        }
    }

    private func dayTitle(_ o: Occasion) -> String {
        if o.type == .birthday { return "Birthday" }
        if o.type == .anniversary, let p = o.partnerName { return "Anniversary with \(p)" }
        return o.type.title(partner: o.partnerName)
    }

    private func dayValue(_ o: Occasion) -> String {
        // A holiday shows its next real date, worked out by its own rule.
        if o.type.kind == .holiday, o.type != .custom,
           let next = OccasionRules.nextDate(type: o.type, month: o.month, day: o.day, from: Date()) {
            return next.formatted(.dateTime.month(.abbreviated).day())
        }
        let date = OccasionDates.date(month: o.month, day: o.day, year: 2028)
        if let y = o.birthYear { return date.formatted(.dateTime.month(.abbreviated).day()) + ", \(y)" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    /// The contact card's other dates, not already here (Graham, Nov 21, 2026).
    private var contactOffers: [ContactDate] {
        let _ = model.revision
        return ContactDates.offers(ContactsService.shared.dates(contactID: person.contactID),
                                   existing: person.occasions.map { ($0.type, $0.month, $0.day) })
    }

    private func addContactDate(_ d: ContactDate) {
        guard purchases.hasLifetime else { showLifetime = true; return }
        if d.isAnniversary {
            model.addOccasion(person, type: .anniversary, month: d.month, day: d.day, year: d.year,
                              partnerName: ContactsService.shared.partnerName(contactID: person.contactID))
        } else {
            model.addOccasion(person, type: .event, month: d.month, day: d.day, year: d.year, partnerName: ContactDates.title(d))
        }
    }

    // MARK: The person page's parts (restructured Nov 21, 2026)

    /// Message, Call, Card and Share day, as round buttons under the photo. Message and Call show only with a number.
    private var actionsRow: some View {
        let phone = model.phone(for: person)
        let digits = phone?.filter { $0.isNumber || $0 == "+" } ?? ""
        return HStack(alignment: .top, spacing: 0) {
            if !digits.isEmpty {
                actionButton("Message", icon: "message") { if let u = URL(string: "sms:\(digits)") { UIApplication.shared.open(u) } }
                actionButton("Call", icon: "phone") { if let u = URL(string: "tel:\(digits)") { UIApplication.shared.open(u) } }
            }
            actionButton("Card", icon: "envelope") { sendingCard = true }
            if let day = model.nextPersonalMoment(for: person) {
                actionButton("Share day", icon: "square.and.arrow.up") { sharingDay = day }
            }
            if let next = model.nextMoment(for: person), next.status != .missed {
                actionButton("Ideas", icon: "lightbulb") { model.route = .ideas(next.id) }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func actionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 18, weight: .regular)).foregroundStyle(Brand.action)
                    .frame(width: 48, height: 48)
                    .background(Brand.card, in: Circle())
                Text(title).font(.caption.weight(.medium)).foregroundStyle(Brand.inkSoft).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }

    private func header(_ title: String, link: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Eyebrow(text: title)
            Spacer()
            Button(link, action: action).font(.callout.weight(.medium)).foregroundStyle(Brand.action).frame(minHeight: 44)
        }
    }

    // MARK: Tiles and part pages

    private var partTiles: some View {
        let name = DisplayName.plain(person.name)
        let ideas = person.openWishes.count
        let photos = person.photoFiles.count
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: Brand.space3), GridItem(.flexible(), spacing: Brand.space3)],
                         spacing: Brand.space3) {
            PartTile(icon: "heart", title: "Loves",
                     detail: person.loves.isEmpty ? "Add what \(name) loves" : person.loves.prefix(2).joined(separator: ", "),
                     empty: person.loves.isEmpty) { model.push(.personPart(person.id, .loves)) }
            PartTile(icon: "lightbulb", title: "Ideas",
                     detail: ideas == 0 ? "Save an idea" : (ideas == 1 ? "1 saved" : "\(ideas) saved"),
                     empty: ideas == 0) {
                // The same Ideas page as the Ideas button: saved first, suggestions when asked (Nov 22, 2026).
                if let next = model.nextMoment(for: person) { model.route = .ideas(next.id) }
                else { model.push(.personPart(person.id, .ideas)) }
            }
            PartTile(icon: "photo.on.rectangle", title: "Photos",
                     detail: photos == 0 ? "Add photos" : (photos == 1 ? "1 photo" : "\(photos) photos"),
                     empty: photos == 0, image: PhotoStore.load(person.photoFiles.last)) { model.push(.personPart(person.id, .photos)) }
            PartTile(icon: "person.text.rectangle", title: "Details", detail: detailsCaption, empty: false) {
                model.push(.personDetails(person.id))
            }
        }
    }

    private func partPage(_ part: PersonPart) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Brand.space5) {
                switch part {
                case .loves:
                    Text("What \(DisplayName.plain(person.name)) loves").textStyle(.title).accessibilityAddTraits(.isHeader)
                    portrait
                    TextLink(title: person.loves.isEmpty ? "+ Add what \(DisplayName.plain(person.name)) loves" : "Edit") { editingPortrait = true }
                        .padding(.leading, -8)
                case .ideas:
                    Text("Ideas for \(DisplayName.plain(person.name))").textStyle(.title).accessibilityAddTraits(.isHeader)
                    savedIdeasSection
                case .photos:
                    Text("\(DisplayName.plain(person.name))'s photos").textStyle(.title).accessibilityAddTraits(.isHeader)
                    photosSection
                }
            }
            .padding(.horizontal, Brand.space5)
            .padding(.vertical, 16)
        }
    }

    private var savedIdeasSection: some View {
        let wishes = person.openWishes
        return VStack(alignment: .leading, spacing: Brand.space2) {
            header("Saved", link: "+ Save") { model.route = .addWish(person.id) }
            if wishes.isEmpty {
                Text("Links and ideas you save for \(DisplayName.plain(person.name)) show here.")
                    .textStyle(.caption, color: Brand.inkMuted)
            } else {
                VStack(spacing: 0) {
                    ForEach(wishes, id: \.id) { wish in
                        Button { wishToEdit = wish } label: {
                            HStack(spacing: Brand.space3) {
                                WishPreview(wish: wish).frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Brand.inkMuted)
                                    .accessibilityHidden(true)
                            }
                            .padding(.vertical, Brand.space2)
                            .frame(minHeight: 52)
                            .overlay(alignment: .bottom) { Rectangle().fill(Brand.line).frame(height: 1) }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressStyle())
                        .accessibilityHint(wishCaption(wish))
                    }
                }
            }
        }
    }

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: Brand.space2) {
            if person.photoFiles.isEmpty {
                Eyebrow(text: "Photos")
                photoNudge
            } else {
                Eyebrow(text: "Photos")
                photoStrip
                Text(photoNote ?? "The first is the photo at the top of this page. Tap one to change that or remove it.")
                    .textStyle(.caption, color: photoNote == nil ? Brand.inkMuted : Brand.ink)
            }
            if let b = person.birthday {
                BirthdayMemories(person: person, month: b.month, day: b.day) { showLifetime = true }
                // Library photos from past birthdays, to keep or skip (Graham, Nov 22, 2026).
                BirthdaySuggestionsView(person: person, month: b.month, day: b.day)
            }
        }
    }

    private var heroLine: String {
        let rel = person.relationship.map { "Your " + $0.lowercased() }
        guard let next = model.nextPersonalMoment(for: person) ?? model.nextMoment(for: person) else {
            return rel ?? "No day saved yet"
        }
        let date = next.dueDate.formatted(.dateTime.month(.abbreviated).day())
        let what: String
        if next.type == .birthday, let t = next.turning { what = "turns \(t) on \(date)" }
        else { what = "\(next.label.lowercased()) on \(date)" }
        return [rel, what].compactMap { $0 }.joined(separator: " · ")
    }

    private var heroTag: String? {
        guard let next = model.nextMoment(for: person) else { return nil }
        let days = OccasionDates.daysBetween(Date(), next.dueDate)
        if days == 0 { return "Today" }
        return days == 1 ? "1 day" : (days < 60 ? "\(days) days" : nil)
    }

    private var detailsCaption: String {
        var bits: [String] = []
        if let r = person.relationship { bits.append(r) }
        let n = person.occasions.count
        bits.append(n == 1 ? "1 day" : "\(n) days")
        bits.append(person.ring.label.lowercased() + " reminders")
        return bits.joined(separator: " · ")
    }

    /// The days on this page's cards: the one it was opened from first if it isn't coming soon, then every day in
    /// the next twelve months, soonest first.
    private var planMoments: [Moment] {
        let today = Calendar.current.startOfDay(for: Date())
        let horizon = Calendar.current.date(byAdding: .day, value: 366, to: today) ?? today
        var moments = person.occasions.flatMap(\.moments)
            .filter { $0.dueDate >= today && $0.dueDate <= horizon && $0.status != .missed }
            .sorted { $0.dueDate < $1.dueDate }
        if let focus, !moments.contains(where: { $0.id == focus }),
           let m = person.occasions.flatMap(\.moments).first(where: { $0.id == focus }) {
            moments.insert(m, at: 0)
        }
        return Array(moments.prefix(6))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Brand.space4) {
            HStack(alignment: .bottom, spacing: Brand.space4) {
                VStack(alignment: .leading, spacing: Brand.space2) {
                    Text(person.name).font(Brand.display(NameSize.page(person.name))).tracking(-1.5)
                        .foregroundStyle(Brand.ink).lineLimit(NameSize.maxLines).minimumScaleFactor(0.8)
                        .multilineTextAlignment(.leading)
                    if let next = model.nextMoment(for: person) {
                        Text(subline(next)).font(Brand.display(20, relativeTo: .title3, italic: true)).foregroundStyle(Brand.inkSoft)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HeroPhoto(person: person, height: 132).frame(width: 100)
            }
            Button { showRing = true } label: { Tag(text: person.ring.label) }
                .buttonStyle(.plain)
                .accessibilityHint("Changes how early Held Dear reminds you")
        }
    }

    private func subline(_ next: Moment) -> String {
        let date = next.dueDate.formatted(.dateTime.month(.wide).day())
        let what = next.countLine.map { $0.prefix(1).lowercased() + $0.dropFirst() } ?? next.label.lowercased()
        return next.type.kind == .holiday ? "\(next.type.title(partner: next.occasion?.partnerName)), \(date)" : "\(date), \(what)"
    }

    /// The portrait, written as sentences: what they love, sizes, good to know.
    private var portrait: some View {
        VStack(alignment: .leading, spacing: Brand.space4) {
            if person.loves.isEmpty {
                Button { editingPortrait = true } label: {
                    Text("What does \(DisplayName.plain(person.name)) love? Add it and every idea gets better.")
                        .font(Brand.serif(22, relativeTo: .title3, italic: true)).foregroundStyle(Brand.inkSoft)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
            } else {
                Button { editingPortrait = true } label: {
                    lovesSentence.font(Brand.serif(24, relativeTo: .title3)).foregroundStyle(Brand.ink)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Edit what \(DisplayName.plain(person.name)) loves")
            }
            if person.sizes != nil || person.goodToKnow != nil {
                HStack(alignment: .top, spacing: Brand.space4) {
                    if let sizes = person.sizes { portraitLine("Sizes", sizes) }
                    if let note = person.goodToKnow { portraitLine("Good to know", note) }
                }
            }
            // Saved ideas show in their own section below. They're often the user's own finds, not something the
            // person asked for, so the portrait no longer says "Mentioned wanting" (Graham, Nov 22, 2026).
        }
    }

    /// "Loves gardening, dark chocolate and the Cubs."
    private var lovesSentence: Text {
        let items = person.loves
        var t = Text("Loves ").foregroundColor(Brand.inkSoft)
        for (i, item) in items.enumerated() {
            if i > 0 { t = t + Text(i == items.count - 1 ? " and " : ", ").foregroundColor(Brand.inkSoft) }
            t = t + Text(item)
        }
        return t + Text(".").foregroundColor(Brand.inkSoft)
    }

    private func portraitLine(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).textStyle(.eyebrow)
            Text(value).textStyle(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "Coming up from Held Dear": the coming heads-up, order-by and message-ready alerts for this person. Each coming
    /// one can be turned off, and back on (Graham, Nov 22, 2026).
    private func scheduleCard(_ m: Moment) -> some View {
        let stops = AlertPlanner.schedule(for: model.state(for: m))
        let now = Date()
        return VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Coming up from Held Dear").padding(.bottom, Brand.space2)
            // Who gets these, in plain words (Graham, Nov 22, 2026): an older reader may think the message goes out alone.
            Text("These reminders come to you. Nothing goes to \(DisplayName.plain(person.name)) unless you tap Send.")
                .textStyle(.caption, color: Brand.inkMuted).padding(.bottom, Brand.space3)
            if stops.isEmpty {
                Text(m.status.isSettled || m.status == .done ? "This year is taken care of." : "On the day, you're reminded to send a message.")
                    .textStyle(.body)
            }
            ForEach(Array(stops.enumerated()), id: \.offset) { i, stop in
                let past = stop.date <= now
                HStack(alignment: .top, spacing: Brand.space3) {
                    VStack(spacing: 0) {
                        ZStack {
                            Circle().fill(past ? Brand.line : Brand.accent).frame(width: 10, height: 10)
                            if past {
                                Image(systemName: "checkmark").font(.system(size: 7, weight: .semibold)).foregroundStyle(Brand.inkMuted)
                            }
                        }
                        .padding(.top, 6)
                        if i < stops.count - 1 { Rectangle().fill(Brand.line).frame(width: 2).frame(maxHeight: .infinity) }
                    }
                    .frame(width: 12)
                    let off = CancelledAlerts.isOff(stop.alertID)
                    VStack(alignment: .leading, spacing: 2) {
                        Text((stop.showsTime ? stop.date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
                                             : stop.date.formatted(.dateTime.month(.abbreviated).day())) + (off ? " · Off" : ""))
                            .textStyle(.caption, color: Brand.inkMuted)
                        Text(stop.label).textStyle(.body, color: past || off ? Brand.inkMuted : Brand.ink)
                            .strikethrough(off, color: Brand.inkMuted)
                        if stop.alertID.hasPrefix("dayof-"), !past {
                            // The message itself: read it here, tap to write, change or reset it (Nov 22, 2026).
                            let usual = m.type.greeting(name: DisplayName.plain(person.name))
                            let saved = DayMessages.message(for: m.id)
                            Button { messageFor = m } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\u{201C}\(saved ?? usual)\u{201D}")
                                        .font(Brand.serif(16, relativeTo: .body, italic: true)).foregroundStyle(Brand.inkSoft)
                                        .multilineTextAlignment(.leading).lineLimit(3)
                                    Text(saved == nil ? "Write your own message" : "Change the message")
                                        .textStyle(.caption, color: Brand.action)
                                }
                                .padding(.top, 4)
                                .frame(minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Message for \(DisplayName.plain(person.name)): \(saved ?? usual)")
                            .accessibilityHint("Opens it to write or change")
                            if model.phone(for: person) == nil {
                                TextLink(title: "Add \(DisplayName.plain(person.name))'s number to text it") { editingPhone = true }
                                    .padding(.leading, -8)
                            }
                        }
                    }
                    .padding(.bottom, Brand.space3)
                    Spacer(minLength: 0)
                    if !past {
                        TextLink(title: off ? "Turn on" : "Turn off") {
                            CancelledAlerts.set(stop.alertID, off: !off)
                            alertToggle += 1
                            Task { await model.scheduleAlerts() }
                        }
                        .accessibilityLabel(off ? "Turn on: \(stop.label)" : "Turn off: \(stop.label)")
                    }
                }
                .id("\(stop.alertID)-\(alertToggle)")
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
                ShareLink(item: Image(uiImage: image), preview: SharePreview("\(DisplayName.plain(person.name)), \(entry.year)", image: Image(uiImage: image))) {
                    Text("Share as keepsake").font(TypeStyle.callout.strong)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .foregroundStyle(Brand.action)
                        .background(Brand.page, in: RoundedRectangle(cornerRadius: Brand.radiusSm, style: .continuous))
                }
            }
        }
        .padding(Brand.space4)
        .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
    }

    /// A skipped Get ahead photo: one quiet next step.
    private var photoNudge: some View {
        PhotosPicker(selection: $photoItems, maxSelectionCount: nil, selectionBehavior: .ordered, matching: .images,
                             preferredItemEncoding: .automatic, photoLibrary: .shared()) {
            HStack(spacing: 14) {
                Image(systemName: "plus").font(.system(size: 20, weight: .regular)).foregroundStyle(Brand.ink)
                    .frame(width: 56, height: 56)
                    .background(Brand.faceFills[0], in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Choose photos of \(DisplayName.plain(person.name))").font(TypeStyle.callout.strong).foregroundStyle(Brand.ink)
                    Text("Pick as many as you like: photos from their days are kept, plus 30 more. For a whole album, use Share in the Photos app and choose Held Dear.")
                        .textStyle(.caption, color: Brand.inkMuted).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Brand.space4)
            .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Brand.space2) {
            Eyebrow(text: title)
            content()
        }
    }

    private var familyIsOn: Bool {
        FamilyIn.isOn(ring: person.ring, override: FamilyCircle.shared.override(for: person.id))
    }

    private var familyCountText: String {
        let n = FamilyCircle.shared.recipients(for: person.id).count
        return n == 0 ? "Add" : (n == 1 ? "1 person" : "\(n) people")
    }

    private var sortedOccasions: [Occasion] {
        person.occasions.sorted { a, b in
            if a.type == .birthday { return true }
            if b.type == .birthday { return false }
            return (nextDate(a) ?? .distantFuture) < (nextDate(b) ?? .distantFuture)
        }
    }

    private func nextDate(_ o: Occasion) -> Date? {
        let today = Calendar.current.startOfDay(for: Date())
        return o.moments.filter { $0.dueDate >= today }.map(\.dueDate).min()
    }

    /// The plan row's second line: how many parts are ready, or an invitation when there is no plan yet.
    private func planCaption(_ m: Moment) -> String {
        m.isPlanMoment
            ? PlanReadiness.summary(ready: m.partsReady, total: m.planParts.count, subject: m.subject)
            : "Parts, steps and who it's from"
    }

    private func occasionCaption(_ o: Occasion) -> String {
        let today = Calendar.current.startOfDay(for: Date())
        guard let next = o.moments.filter({ $0.dueDate >= today }).min(by: { $0.dueDate < $1.dueDate }) else {
            return o.type.kind == .once ? "Passed" : "Next year"
        }
        let date = OccasionDates.longDate(next.dueDate)
        if let count = next.countLine { return "\(date) · \(count.prefix(1).lowercased() + count.dropFirst())" }
        return date
    }

    private func wishCaption(_ wish: Wish) -> String {
        if let m = model.nextMoment(for: person), m.plan?.wishID == wish.id { return "Planned for this year" }
        return wish.savedLine
    }

    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                PhotosPicker(selection: $photoItems, maxSelectionCount: nil, selectionBehavior: .ordered, matching: .images,
                             preferredItemEncoding: .automatic, photoLibrary: .shared()) {
                    Image(systemName: "plus").font(.system(size: 20, weight: .regular)).foregroundStyle(Brand.action)
                        .frame(width: 88, height: 88)
                        .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusSm, style: .continuous))
                }
                .accessibilityLabel("Add a photo")
                ForEach(person.photoFiles.reversed(), id: \.self) { file in
                    if let image = PhotoStore.load(file) {
                        let isTop = file == person.photoFiles.last
                        Button { photoToManage = file } label: {
                            Image(uiImage: image).resizable().scaledToFill()
                                .frame(width: 88, height: 88)
                                .clipShape(RoundedRectangle(cornerRadius: Brand.radiusSm, style: .continuous))
                                .overlay(alignment: .bottomLeading) {
                                    if isTop {
                                        Text("Top").font(.caption2.weight(.semibold)).foregroundStyle(Brand.page)
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(Brand.ink, in: Capsule())
                                            .padding(6)
                                    }
                                }
                        }
                        .buttonStyle(PressStyle())
                        .accessibilityLabel(isTop ? "Photo at the top of the page" : "Photo")
                        .accessibilityHint("Opens the photo, to use it at the top or remove it")
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
                    Text(String(entry.year)).font(Brand.serif(22, relativeTo: .title3)).foregroundStyle(Brand.ink)
                    Text(entry.what).font(TypeStyle.body.strong).foregroundStyle(Brand.ink)
                    if let line = entry.line { Text(line).textStyle(.callout, color: Brand.ink.opacity(0.85)) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, Brand.space3)
            .overlay(alignment: .bottom) { Rectangle().fill(Brand.line).frame(height: 1) }
        }
        .buttonStyle(.plain)
    }

    private func addPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        let days = person.occasions.map { (month: $0.month, day: $0.day) }
        let name = DisplayName.plain(person.name)
        photoItems = []
        Task {
            // Saved as it goes, four at a time, with a count on the page, so a big set never ends with nothing
            // (build 1039 bug, Nov 22, 2026). Photos near their days are always kept, plus 30 more.
            var fromDays = 0, extra = 0, skipped = 0, done = 0
            let total = items.count
            for start in stride(from: 0, to: total, by: 4) {
                let batch = Array(items[start..<min(start + 4, total)])
                let datas = await withTaskGroup(of: (Int, Data?).self) { group in
                    for (i, item) in batch.enumerated() { group.addTask { (i, try? await item.loadTransferable(type: Data.self)) } }
                    var out = [Data?](repeating: nil, count: batch.count)
                    for await (i, d) in group { out[i] = d }
                    return out
                }
                var added: [String] = []
                for (i, data) in datas.enumerated() {
                    done += 1
                    guard let data else { skipped += 1; continue }
                    // The day taken from the photo's own details, or from the library when those were left off
                    // (Nov 22, 2026), so it lands under the right past birthday.
                    let taken = PhotoStore.takenDate(data) ?? BirthdaySuggestions.takenDate(localIdentifier: batch[i].itemIdentifier)
                    let near = taken.map { ChosenPhotos.nearDay($0, days: days, within: 3) } ?? false
                    if !near && extra >= 30 { skipped += 1; continue }
                    let file: String? = autoreleasepool { PhotoStore.save(data: data, taken: taken) }
                    if let file { added.append(file); if near { fromDays += 1 } else { extra += 1 } } else { skipped += 1 }
                }
                if !added.isEmpty {
                    person.photoFiles.insert(contentsOf: added.reversed(), at: 0)
                    model.save()
                }
                if total > 4 { photoNote = "Adding \(done) of \(total)…" }
            }
            photoNote = skipped == 0 ? (total > 4 ? "Added \(fromDays + extra) photos." : nil)
                : "Kept \(fromDays) from \(name)'s days and \(extra) more. \(skipped) stayed in Photos."
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
                Text("How close is \(DisplayName.plain(person.name))?").textStyle(.title)
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
                                Text(ring.label).font(TypeStyle.body.strong).foregroundStyle(Brand.ink)
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
            Text("\(DisplayName.plain(person.name))'s birthday").textStyle(.headline)
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

/// Apple's contact picker with checkmarks: implementing the plural delegate method turns on picking several.
/// A separate delegate from ContactPickerPresenter, which links one contact to one person.
@MainActor
final class MultiContactPickerPresenter: NSObject, CNContactPickerDelegate {
    static let shared = MultiContactPickerPresenter()
    private var onPick: (([CNContact]) -> Void)?

    func present(onPick: @escaping ([CNContact]) -> Void) {
        guard let top = ContactPickerPresenter.topViewController() else { return }
        self.onPick = onPick
        let picker = CNContactPickerViewController()
        picker.delegate = self
        top.present(picker, animated: true)
    }

    nonisolated func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
        Task { @MainActor in
            let callback = self.onPick
            self.onPick = nil
            try? await Task.sleep(nanoseconds: 450_000_000)
            callback?(contacts)
        }
    }

    nonisolated func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        Task { @MainActor in self.onPick = nil }
    }
}

/// Edit the portrait: loves (comma separated), sizes, and one line of good to know.
/// Change or clear the address kept for a person (story 2.13). Contacts are never written.
struct AddressEditor: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let person: Person
    @State private var address = MailAddress()
    @State private var hadOne = false

    var body: some View {
        FlowScreen(onClose: { dismiss() }) {
            Question(title: "\(DisplayName.plain(person.name))'s address",
                     subtitle: "For mailed cards. It stays with your plans and is never added to Contacts.", style: .title)
            AddressForm(address: $address)
        } footer: {
            PrimaryButton(title: "Save") {
                person.mailingAddress = address
                model.save()
                dismiss()
            }
            .disabled(!address.isComplete)
            if hadOne {
                TextLink(title: "Clear the address") {
                    person.mailingAddress = nil
                    model.save()
                    dismiss()
                }
            }
        }
        .onAppear {
            if let saved = person.mailingAddress { address = saved; hadOne = true }
            else { address.firstName = DisplayName.plain(person.name).split(separator: " ").first.map(String.init) ?? "" }
        }
    }
}

struct PortraitEditor: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let person: Person
    @State private var loves = ""
    @State private var sizes = ""
    @State private var note = ""

    var body: some View {
        FlowScreen(onClose: { dismiss() }) {
            Question(title: "What does \(DisplayName.plain(person.name)) love?",
                     subtitle: "Your words, kept on this iPhone. Held Dear uses them for ideas and card words.")
            LineField(label: "Loves, separated by commas", text: $loves, placeholder: "Gardening, dark chocolate, the Cubs")
            LineField(label: "Sizes", text: $sizes, placeholder: "M tops, 8.5 shoes", showsDictation: false)
            LineField(label: "Good to know", text: $note, placeholder: "Allergic to lilies")
        } footer: {
            PrimaryButton(title: "Save") {
                person.loves = loves.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                person.sizes = sizes.trimmingCharacters(in: .whitespaces).nilIfEmpty
                person.goodToKnow = note.trimmingCharacters(in: .whitespaces).nilIfEmpty
                model.save()
                dismiss()
            }
        }
        .onAppear {
            loves = person.loves.joined(separator: ", ")
            sizes = person.sizes ?? ""
            note = person.goodToKnow ?? ""
        }
    }
}

/// Wraps chips onto as many lines as they need.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for v in subviews {
            let size = v.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: min(maxX, width), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for v in subviews {
            let size = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Photos from past birthdays, from the photos the user chose for this person (Nov 21, 2026), by the day each was
/// taken. Free shows the most recent year; Lifetime shows every year.
struct BirthdayMemories: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject private var purchases = Purchases.shared
    let person: Person
    let month: Int
    let day: Int
    var showLifetime: () -> Void

    var body: some View {
        let years = ChosenPhotos.birthdayYears(files: person.photoFiles, month: month, day: day)
        VStack(alignment: .leading, spacing: Brand.space3) {
            if !years.isEmpty {
                Text("On \(DisplayName.plain(person.name))'s birthdays").textStyle(.headline)
                ForEach(purchases.hasLifetime ? years : Array(years.prefix(1))) { y in yearRow(y) }
                if !purchases.hasLifetime && years.count > 1 {
                    TextLink(title: "See all \(years.count) years with Lifetime", action: showLifetime)
                }
            }
        }
    }

    private func yearRow(_ y: ChosenPhotos.Year) -> some View {
        VStack(alignment: .leading, spacing: Brand.space2) {
            Text(String(y.year)).font(Brand.serif(22, relativeTo: .title3)).foregroundStyle(Brand.ink)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(y.files, id: \.self) { file in
                        if let image = PhotoStore.load(file) {
                            Image(uiImage: image).resizable().scaledToFill()
                                .frame(width: 104, height: 104)
                                .clipShape(RoundedRectangle(cornerRadius: Brand.radiusSm, style: .continuous))
                                .accessibilityLabel("Photo from \(y.year)")
                        }
                    }
                }
            }
        }
    }
}

struct AssetThumb: View {
    let asset: PHAsset
    let side: CGFloat
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Brand.card
            if let image { Image(uiImage: image).resizable().scaledToFill() }
        }
        .frame(width: side, height: side)
        .clipped()
        .task(id: asset.localIdentifier) { image = await PhotoMemories.shared.thumbnail(asset, side: side) }
    }
}

/// Add an occasion: first what kind (one decision), then the date if it needs one.
struct AddOccasionView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let person: Person
    @State private var type: OccasionType?
    @State private var date = Date()
    @State private var knowsYear = false
    @State private var partner = ""

    var body: some View {
        if let type { dateStep(type) } else { pickStep }
    }

    private var choices: [OccasionType] {
        OccasionType.allCases.filter { t in
            (t != .birthday || OccasionOffer.offersBirthday(existing: person.occasions.map(\.type)))
                && !(t.kind == .holiday && person.occasions.contains { $0.type == t })
                && (t.kind != .holiday || (Holidays.enabled().contains(t)
                    && OccasionOffer.offersHoliday(t, relationship: person.relationship)))
                && (t.kind != .once || OccasionOffer.bigDays.contains(t))
        }
    }

    private var pickStep: some View {
        FlowScreen(onClose: { dismiss() }) {
            Question(title: "What else matters for \(DisplayName.plain(person.name))?")
            section("Every year", choices.filter { $0.kind == .yearly }.sorted { $0 == .birthday && $1 != .birthday })
            section("Holidays", choices.filter { $0.kind == .holiday })
            ownHolidays
            section("Big days", OccasionOffer.bigDays.filter(choices.contains))
        }
    }

    /// Holidays the user added (story 2.10) that this person isn't in yet.
    @ViewBuilder private var ownHolidays: some View {
        let own = CustomHolidays.all().filter { h in
            !person.occasions.contains { $0.type == .custom && CustomHolidays.sameName($0.partnerName ?? "", h.name) }
        }
        if !own.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow(text: "Your holidays")
                ForEach(own) { h in
                    OptionRow(title: h.name, caption: OccasionDates.date(month: h.month, day: h.day, year: 2028)
                        .formatted(.dateTime.month(.wide).day())) {
                        model.addToHoliday(person, ref: h.ref, year: Calendar.current.component(.year, from: Date()))
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder private func section(_ title: String, _ items: [OccasionType]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow(text: title)
                ForEach(items) { t in
                    OptionRow(title: t == .event ? "Something else" : t.label, caption: caption(t)) {
                        if t.needsDate { type = t } else { save(t) }
                    }
                }
            }
        }
    }

    private func caption(_ t: OccasionType) -> String? {
        switch t {
        case .christmas: "December 25"
        case .valentines: "February 14"
        case .mothersDay: "Second Sunday in May"
        case .fathersDay: "Third Sunday in June"
        case .anniversary: "Theirs, or yours together"
        case .event: "A recital, a retirement, a new home"
        default: nil
        }
    }

    private func dateStep(_ t: OccasionType) -> some View {
        FlowScreen(onClose: { type = nil }) {
            Question(title: t == .event ? "What's the day?" : (t.kind == .once ? "When is \(t.subject(name: person.name))?" : "When is it?"))
            if t == .event {
                LineField(label: "What is it?", text: $partner, placeholder: "Ballet recital", showsDictation: true)
            }
            DatePicker(t.label, selection: $date, displayedComponents: .date)
                .datePickerStyle(.wheel).labelsHidden().frame(maxWidth: .infinity)
            if t == .anniversary {
                LineField(label: "With (optional)", text: $partner, placeholder: "Dad", showsDictation: false)
            }
            if t == .anniversary || t == .birthday {
                Toggle(t.yearLabel, isOn: $knowsYear).textStyle(.body).tint(Brand.action)
            }
        } footer: {
            let missingName = t == .event && partner.trimmingCharacters(in: .whitespaces).isEmpty
            PrimaryButton(title: "Save") { save(t) }
                .disabled(missingName)
                .opacity(missingName ? 0.45 : 1)
        }
    }

    private func save(_ t: OccasionType) {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let year: Int? = t.kind == .once ? c.year : ((t == .anniversary || t == .birthday) && knowsYear ? c.year : nil)
        model.addOccasion(person, type: t, month: c.month ?? 1, day: c.day ?? 1, year: year,
                          partnerName: t == .anniversary || t == .event ? partner.trimmingCharacters(in: .whitespaces).nilIfEmpty : nil)
        dismiss()
    }
}

/// The person's years on a line, oldest to newest, ending with this year ("Still open" until something is done).
struct PersonYears: View {
    let person: Person

    var body: some View {
        let year = Calendar.current.component(.year, from: Date())
        let past = Array(person.sortedLedger.filter { $0.year < year }.prefix(3).reversed())
        let thisYear = person.sortedLedger.first { $0.year == year }
        VStack(alignment: .leading, spacing: Brand.space3) {
            Text("\(DisplayName.plain(person.name))'s years").textStyle(.eyebrow)
            ZStack(alignment: .top) {
                Rectangle().fill(Brand.ink).frame(height: 1.5).offset(y: 44)
                HStack(alignment: .top, spacing: Brand.space2) {
                    ForEach(past, id: \.id) { e in column(String(e.year), e.what, current: false) }
                    column(String(year), thisYear?.what ?? "Still open", current: true, open: thisYear == nil)
                    if past.count < 3 { Spacer(minLength: 0) }
                }
            }
        }
        .padding(.horizontal, Brand.space5)
        .padding(.vertical, Brand.space4)
        .background(Brand.card)
        .accessibilityElement(children: .combine)
    }

    private func column(_ year: String, _ what: String, current: Bool, open: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(year).font(Brand.display(22, relativeTo: .title3)).foregroundStyle(current ? Brand.action : Brand.inkMuted)
            Circle().fill(current ? Brand.action : Brand.inkMuted).frame(width: current ? 13 : 9, height: current ? 13 : 9)
                .padding(.top, current ? 2 : 4)
            Text(what)
                .font(open ? Brand.serif(15, relativeTo: .callout, italic: true) : .subheadline)
                .foregroundStyle(current ? Brand.action : Brand.inkSoft)
                .lineLimit(3)
        }
        .frame(maxWidth: 90, alignment: .leading)
    }
}


/// A number for the message on the day, when Contacts has none or a different one should be used (Nov 21, 2026).
struct PhoneEditor: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let person: Person
    @State private var number = ""

    var body: some View {
        let fromContact = ContactsService.shared.phone(contactID: person.contactID)
        FlowScreen(onClose: { dismiss() }) {
            Question(title: "\(DisplayName.plain(person.name))'s number", subtitle: fromContact.map { "Contacts has \($0). Add another here to use it instead." }
                     ?? "For the message on the day. Kept in Held Dear, never added to Contacts.", style: .title)
            TextField(fromContact ?? "Add a number", text: $number)
                .keyboardType(.phonePad).textStyle(.body)
                .padding(.horizontal, Brand.space4).frame(minHeight: 56)
                .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
            if person.manualPhone != nil {
                TextLink(title: fromContact == nil ? "Clear the number" : "Use the number from Contacts") {
                    person.manualPhone = nil
                    model.commit()
                    dismiss()
                }
                .padding(.leading, -8)
            }
        } footer: {
            PrimaryButton(title: "Save") {
                let trimmed = number.trimmingCharacters(in: .whitespaces)
                person.manualPhone = trimmed.isEmpty ? nil : trimmed
                model.commit()
                dismiss()
            }
        }
        .onAppear { number = person.manualPhone ?? "" }
    }
}

struct ManagedPhoto: Identifiable { let file: String; var id: String { file } }

/// A photo opened from a person's strip: big, with its two choices as plain buttons below (Nov 21, 2026).
struct PhotoActions: View {
    @State private var choosingFocus = false
    let file: String
    let isTop: Bool
    var useAtTop: () -> Void
    var remove: () -> Void
    var personName: String = ""

    var body: some View {
        VStack(spacing: Brand.space4) {
            if let image = PhotoStore.load(file) {
                Image(uiImage: image).resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .frame(maxHeight: 320)
                    .accessibilityHidden(true)
            }
            if !isTop { SecondaryButton(title: "Use at the top") { useAtTop() } }
            TextLink(title: PhotoFocus.box(for: file) == nil ? "Choose who it centers on" : "Change who it centers on") {
                choosingFocus = true
            }
            TextLink(title: personName.isEmpty ? "Remove this photo" : "Remove from \(personName)'s photos") { remove() }
            Text("It comes off this person only, with Undo. It stays in your Photos.")
                .textStyle(.caption, color: Brand.inkMuted).multilineTextAlignment(.center)
        }
        .padding(Brand.space5)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Brand.page.ignoresSafeArea())
        .fullScreenCover(isPresented: $choosingFocus) { FocusPicker(file: file) { choosingFocus = false } }
    }
}


/// Choose who or what a photo centers on (Graham, Nov 22, 2026): tap a face in the row of faces, or pinch to zoom
/// the photo and tap any spot. The round preview shows what Home and the person's page will use.
struct FocusPicker: View {
    let file: String
    var close: () -> Void
    @State private var faces: [CGRect] = []
    @State private var focus: CGRect?
    @State private var image: UIImage?
    @State private var zoom: CGFloat = 1
    @State private var zoomStart: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var panStart: CGSize = .zero
    /// Fine-tuning (Graham, Nov 22, 2026): the box as first chosen, for the zoom slider, and where a drag began.
    @State private var base: CGRect?
    @State private var dragStart: CGRect?

    private func same(_ a: CGRect?, _ b: CGRect) -> Bool {
        guard let a else { return false }
        return abs(a.midX - b.midX) < 0.01 && abs(a.midY - b.midY) < 0.01
    }

    var body: some View {
        FlowScreen(onClose: close) {
            Question(title: "Who should it center on?",
                     subtitle: faces.count > 1 ? "Tap a face below. Or pinch the photo to zoom and tap any spot." : "Pinch to zoom, then tap any spot.",
                     style: .title)
            if let image {
                if faces.count > 1 {
                    // Every face, big enough to tap without aiming.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Brand.space3) {
                            ForEach(Array(faces.enumerated()), id: \.offset) { i, f in
                                Button { choose(f) } label: {
                                    crop(image, f, share: 0.7)
                                        .frame(width: 64, height: 64).clipShape(Circle())
                                        .overlay { Circle().strokeBorder(same(focus, f) ? Brand.action : Brand.raisedLine, lineWidth: same(focus, f) ? 3 : 1) }
                                }
                                .buttonStyle(PressStyle())
                                .accessibilityLabel("Face \(i + 1)")
                                .accessibilityAddTraits(same(focus, f) ? [.isButton, .isSelected] : .isButton)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                GeometryReader { geo in
                    let fit = fitted(image.size, in: geo.size)
                    ZStack(alignment: .topLeading) {
                        Image(uiImage: image).resizable().scaledToFit()
                            .frame(width: fit.width, height: fit.height)
                        if let focus {
                            Circle().strokeBorder(Brand.action, lineWidth: 3 / zoom)
                                .frame(width: max(focus.width * fit.width, focus.height * fit.height) * 1.3,
                                       height: max(focus.width * fit.width, focus.height * fit.height) * 1.3)
                                .position(x: focus.midX * fit.width, y: focus.midY * fit.height)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(width: fit.width, height: fit.height)
                    .contentShape(Rectangle())
                    // The tap is read before zooming, so it lands on the photo's own spot at any zoom.
                    .onTapGesture { p in
                        let spot = CGPoint(x: p.x / fit.width, y: p.y / fit.height)
                        choose(faces.first { $0.insetBy(dx: -$0.width * 0.3, dy: -$0.height * 0.3).contains(spot) }
                            ?? PhotoFocus.box(around: spot, imageSize: image.size, share: 0.12))
                    }
                    .scaleEffect(zoom)
                    .offset(pan)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .gesture(MagnifyGesture()
                        .onChanged { zoom = min(6, max(1, zoomStart * $0.magnification)) }
                        .onEnded { _ in zoomStart = zoom; if zoom == 1 { pan = .zero; panStart = .zero } })
                    .simultaneousGesture(DragGesture(minimumDistance: 8)
                        .onChanged { g in
                            guard zoom > 1 else { return }
                            pan = CGSize(width: panStart.width + g.translation.width, height: panStart.height + g.translation.height)
                        }
                        .onEnded { _ in panStart = pan })
                    .onTapGesture(count: 2) {
                        withAnimation(.snappy) { zoom = zoom > 1 ? 1 : 3; zoomStart = zoom; if zoom == 1 { pan = .zero; panStart = .zero } }
                    }
                }
                .frame(height: 340)
                .background(Brand.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                if let focus {
                    // How it looks on Home, and fine-tuning right on it: drag to move, slide to zoom.
                    VStack(spacing: Brand.space3) {
                        crop(image, focus, share: 0.5)
                            .frame(width: 180, height: 180).clipShape(Circle())
                            .overlay { Circle().strokeBorder(Brand.raisedLine, lineWidth: 1) }
                            .contentShape(Circle())
                            .gesture(DragGesture(minimumDistance: 1)
                                .onChanged { g in nudge(by: g.translation, previewSide: 180, imageSize: image.size) }
                                .onEnded { _ in dragStart = nil })
                            .accessibilityLabel("How it looks on Home")
                            .accessibilityHint("Drag to move the photo in the circle")
                            .accessibilityAdjustableAction { dir in
                                zoomBy(dir == .increment ? 0.9 : 1.1)
                            }
                        HStack(spacing: Brand.space3) {
                            Text("Closer").textStyle(.caption, color: Brand.inkMuted)
                            Slider(value: Binding(get: { sizeFactor }, set: { setSize($0) }), in: 0.5...2.5)
                                .tint(Brand.action)
                                .accessibilityLabel("Zoom")
                            Text("Wider").textStyle(.caption, color: Brand.inkMuted)
                        }
                        Text("Drag the circle to move the photo. Slide to zoom.").textStyle(.caption, color: Brand.inkMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, Brand.space2)
                }
            }
            if PhotoFocus.box(for: file) != nil {
                TextLink(title: "Go back to the largest face") { PhotoFocus.set(nil, for: file); close() }.padding(.leading, -8)
            }
        } footer: {
            PrimaryButton(title: "Use this") {
                if let focus { PhotoFocus.set(focus, for: file) }
                close()
            }
        }
        .task {
            image = PhotoStore.load(file)
            focus = PhotoFocus.box(for: file)
            if let image { faces = await FaceFinder.shared.faces(in: image) }
            if focus == nil { focus = faces.first }
            base = focus
        }
    }

    private func choose(_ r: CGRect) { focus = r; base = r }

    /// How much wider (above 1) or closer (below 1) than first chosen.
    private var sizeFactor: Double {
        guard let focus, let base, base.width > 0 else { return 1 }
        return Double(focus.width / base.width)
    }

    private func setSize(_ factor: Double) {
        guard let focus, let base else { return }
        self.focus = PhotoFocus.resized(focus, base: base, factor: CGFloat(factor))
    }

    private func zoomBy(_ k: CGFloat) { setSize(sizeFactor * Double(k)) }

    /// A drag on the circle moves the photo with the finger: the focus moves the other way.
    private func nudge(by t: CGSize, previewSide: CGFloat, imageSize: CGSize) {
        guard let focus else { return }
        let start = dragStart ?? focus
        if dragStart == nil { dragStart = focus }
        self.focus = PhotoFocus.nudged(start, by: t, previewSide: previewSide, imageSize: imageSize)
    }

    /// A square crop around a box, the way Home frames a face.
    @ViewBuilder private func crop(_ image: UIImage, _ box: CGRect, share: CGFloat) -> some View {
        if let cg = image.cgImage {
            let size = CGSize(width: cg.width, height: cg.height)
            let square = FaceFrame.portraitSquare(face: PhotoFocus.pixels(box, imageSize: size), imageSize: size, faceShare: share)
            if let c = cg.cropping(to: square.integral) {
                Image(uiImage: UIImage(cgImage: c)).resizable().scaledToFill()
            }
        }
    }

    private func fitted(_ size: CGSize, in box: CGSize) -> CGSize {
        let scale = min(box.width / max(size.width, 1), box.height / max(size.height, 1))
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
}

/// One "Get the family in" flow to open: the day, and whether it's the three-day follow-up.
struct FamilyAsk: Identifiable {
    let moment: Moment
    let followUp: Bool
    var id: UUID { moment.id }
}

/// A door on a person's page: an icon, a name, and one line of what's inside (Nov 22, 2026).
struct PartTile: View {
    var icon: String
    var title: String
    var detail: String
    var empty: Bool
    var image: UIImage? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Brand.space2) {
                HStack {
                    if let image {
                        Image(uiImage: image).resizable().scaledToFill().frame(width: 32, height: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    } else {
                        Image(systemName: icon).font(.system(size: 20, weight: .light)).foregroundStyle(Brand.action)
                            .frame(height: 32)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Brand.inkMuted)
                }
                Text(title).font(Brand.serif(20, relativeTo: .title3)).foregroundStyle(Brand.ink)
                Text(detail).textStyle(.caption, color: empty ? Brand.action : Brand.inkMuted)
                    .lineLimit(2).multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .padding(Brand.space4)
            .background(Brand.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Brand.raisedLine, lineWidth: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(detail)")
        .accessibilityAddTraits(.isButton)
    }
}

/// The message for a person's day (Graham, Nov 22, 2026): write it ahead, change it, or go back to the usual.
struct DayMessageEditor: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let person: Person
    let moment: Moment
    @State private var text = ""

    private var name: String { DisplayName.plain(person.name) }
    private var usual: String { moment.type.greeting(name: name) }
    private var saved: String? { DayMessages.message(for: moment.id) }

    var body: some View {
        FlowScreen(onClose: { dismiss() }) {
            Question(title: "The message for \(name)",
                     subtitle: "Ready on \(OccasionDates.shortDate(moment.dueDate)) when you tap the alert. You can still change it then.",
                     style: .title)
            TextField("Write the message", text: $text, axis: .vertical)
                .lineLimit(3...8)
                .font(Brand.serif(19, relativeTo: .body, italic: true))
                .foregroundStyle(Brand.ink)
                .padding(Brand.space4)
                .frame(minHeight: 120, alignment: .topLeading)
                .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
            WriteForMe(kind: .message, facts: { PersonFacts(person: person, moment: moment) }, text: $text)
            if saved != nil {
                TextLink(title: "Go back to the usual: \u{201C}\(usual)\u{201D}") {
                    DayMessages.set(nil, for: moment.id, usual: usual)
                    dismiss()
                }
                .padding(.leading, -8)
            }
        } footer: {
            PrimaryButton(title: "Save the message") {
                DayMessages.set(text, for: moment.id, usual: usual)
                dismiss()
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .onAppear { text = saved ?? usual }
    }
}
