import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers

/// The Held Dear Lifetime offer. Reached only from Settings, a locked card design, or once after the
/// first yearly line. The close button shows at once. No countdown timers, no blur, no nagging.
struct LifetimeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var purchases = Purchases.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Brand.action).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Close")
                Spacer()
            }
            .padding(.horizontal, 10)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    CirclesMark(size: 64).frame(maxWidth: .infinity).padding(.top, 8)
                    if purchases.hasLifetime {
                        Text("Thank you. It's all yours.").textStyle(.display).frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Held Dear Lifetime").textStyle(.display)
                        Text("Everything that keeps you from missing anyone stays free. Lifetime adds more ways to make it personal.")
                            .textStyle(.body, color: Brand.ink.opacity(0.85))
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        benefit("rectangle.portrait.on.rectangle.portrait", "Every card design, in your own words")
                        benefit("lock.iphone", "A countdown on your Lock Screen")
                        benefit("clock.arrow.circlepath", "1 year ago, and a yearly keepsake to share")
                        benefit("calendar.badge.plus", "Anniversaries, holidays and life moments, not just birthdays")
                        benefit("sparkles", "Gift ideas and card words, written on your iPhone")
                        benefit("photo.on.rectangle", "Every year of birthday photos, from your library")
                    }
                    .padding(Brand.space4 + 4)
                    .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
                }
                .padding(.horizontal, Brand.space5)
            }
            VStack(spacing: Brand.space2) {
                if purchases.hasLifetime {
                    PrimaryButton(title: "Done") { dismiss() }
                } else {
                    PrimaryButton(title: purchases.isWorking ? "One moment…" : "Get Lifetime · \(purchases.priceText)") {
                        Task { await purchases.buy() }
                    }
                    .disabled(purchases.isWorking)
                    Text("One payment. No subscription. Shared with your family.")
                        .textStyle(.caption, color: Brand.inkMuted).multilineTextAlignment(.center)
                    TextLink(title: "Restore purchase") { Task { await purchases.restore() } }
                }
            }
            .padding(.horizontal, Brand.space5)
            .padding(.bottom, 12)
        }
        .background(Brand.page.ignoresSafeArea())
        .alert(purchases.message ?? "", isPresented: Binding(get: { purchases.message != nil }, set: { if !$0 { purchases.message = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private func benefit(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Brand.action).frame(width: 28)
                .accessibilityHidden(true)
            Text(text).textStyle(.bodyStrong).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// The app's three-circle mark, drawn in code.
/// The Held Dear mark (same as the app icon): a horizon line, two quiet marks and one oxblood mark rising
/// from a dot. Kept under its old name so callers don't change.
struct CirclesMark: View {
    var size: CGFloat
    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, y = w * 0.63
            ctx.fill(Path(CGRect(x: w * 0.13, y: y - w * 0.013, width: w * 0.74, height: w * 0.026)), with: .color(Brand.ink))
            for (x, h) in [(0.29, 0.15), (0.71, 0.23)] as [(CGFloat, CGFloat)] {
                ctx.fill(Path(CGRect(x: w * x - w * 0.011, y: y - w * h, width: w * 0.022, height: w * h)), with: .color(Brand.ink))
            }
            ctx.fill(Path(CGRect(x: w * 0.47 - w * 0.018, y: y - w * 0.37, width: w * 0.036, height: w * 0.37)), with: .color(Brand.action))
            let r = w * 0.058
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.47 - r, y: y - r, width: r * 2, height: r * 2)), with: .color(Brand.action))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Settings: Lifetime, people, Lock Screen privacy, and what stays on the phone.
struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject private var purchases = Purchases.shared
    @State private var showLifetime = false
    @State private var addingFromContacts = false
    @AppStorage("lockScreenInitialsOnly", store: UserDefaults(suiteName: AppGroup.identifier)) private var initialsOnly = false
    @AppStorage("yourName") private var yourName = ""
    @AppStorage(AppFeatures.homeMedallionKey) private var medallionOn = true
    @AppStorage("cardSignature") private var signedAs = ""
    @State private var makingCard = false
    @State private var addingHoliday = false
    @State private var holidayToEdit: CustomHoliday?
    @State private var exportItems: [Any]?
    @State private var exportFailed = false
    @State private var exporting = false
    @State private var importing = false
    @State private var keepInICloud = ICloudSync.isOn
    @State private var yourPhotoItem: PhotosPickerItem?
    @State private var yourPhotoFile = YouProfile.photoFile
    @State private var editingBirthday = false
    @State private var addingAnniversary = false
    @State private var importNote: String?
    @State private var pendingImport: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("You").textStyle(.title).accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: Brand.space2) {
                    Eyebrow(text: "Your name")
                    TextField("Your first name", text: $yourName)
                        .textContentType(.givenName)
                        .textStyle(.body)
                        .padding(.horizontal, Brand.space4)
                        .frame(minHeight: 52)
                        .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
                    Text("Shown in the circle on Home.").textStyle(.caption, color: Brand.inkMuted)
                }
                VStack(alignment: .leading, spacing: Brand.space2) {
                    Eyebrow(text: "Your photo and dates")
                    PhotosPicker(selection: $yourPhotoItem, matching: .images) {
                        HStack(spacing: Brand.space3) {
                            YourPhotoCircle(file: yourPhotoFile, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(yourPhotoFile == nil ? "Add your photo" : "Change your photo").textStyle(.body)
                                Text("Shown with your partner's on your anniversary.").textStyle(.caption, color: Brand.inkMuted)
                            }
                            Spacer()
                        }
                        .frame(minHeight: 52)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    OptionRow(title: YouProfile.birthday().map { "Your birthday, \(YouDates.text($0))" } ?? "Add your birthday",
                              caption: "Kept on this iPhone.") { editingBirthday = true }
                    OptionRow(title: "Add your anniversary",
                              caption: "Pick your partner. Their page gets the day, with both your photos.") { addingAnniversary = true }
                }
                VStack(alignment: .leading, spacing: Brand.space2) {
                    Eyebrow(text: "Cards from you")
                    OptionRow(title: "Make a card", caption: "For Christmas or any reason. Text it or post it.") { makingCard = true }
                    TextField("Sign cards as (like The Hollands)", text: $signedAs)
                        .textStyle(.body)
                        .padding(.horizontal, Brand.space4)
                        .frame(minHeight: 52)
                        .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
                        .accessibilityLabel("Sign cards as")
                    Text("Your cards end with \"from\" and this. Empty uses your name.").textStyle(.caption, color: Brand.inkMuted)
                }
                VStack(alignment: .leading, spacing: Brand.space2) {
                    Eyebrow(text: "Held Dear Lifetime")
                    OptionRow(title: purchases.hasLifetime ? "Lifetime is on" : "Held Dear Lifetime",
                              caption: purchases.hasLifetime ? "Thank you" : "Every card design, Lock Screen, look-back · \(purchases.priceText)") {
                        showLifetime = true
                    }
                }
                if purchases.isTestBuild && AppFeatures.testFlightTools {
                    VStack(alignment: .leading, spacing: Brand.space2) {
                        Eyebrow(text: "TestFlight only")
                        Toggle(isOn: Binding(get: { purchases.hasLifetime },
                                             set: { on in Task { await purchases.setTestOverride(on) } })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Lifetime for testing").textStyle(.bodyStrong)
                                Text("Turns the paid features on without buying. Not in the App Store version. A sandbox purchase also works and is free.")
                                    .textStyle(.caption, color: Brand.inkMuted)
                            }
                        }
                        .tint(Brand.action)
                        .padding(.vertical, Brand.space3).padding(.horizontal, Brand.space4)
                        .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
                    Toggle(isOn: $medallionOn) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Home medallion").textStyle(.bodyStrong)
                            Text("The face in a warm-toned circle with the name on its rim. Off brings back the small circle.")
                                .textStyle(.caption, color: Brand.inkMuted)
                        }
                    }
                    .tint(Brand.action)
                    .padding(.vertical, Brand.space3).padding(.horizontal, Brand.space4)
                    .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
                    }
                }
                VStack(alignment: .leading, spacing: Brand.space2) {
                    Eyebrow(text: "Holidays you celebrate")
                    ForEach(Holidays.offeredIn1_0) { type in
                        Toggle(isOn: Binding(get: { Holidays.enabled().contains(type) },
                                             set: { on in Holidays.setEnabled(type, on); model.save() })) {
                            Text(type.label).textStyle(.body)
                        }
                        .tint(Brand.action)
                        .padding(.vertical, Brand.space3).padding(.horizontal, Brand.space4)
                        .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
                    }
                }
                VStack(alignment: .leading, spacing: Brand.space2) {
                    Eyebrow(text: "Your own holidays")
                    let _ = model.revision
                    let own = CustomHolidays.all()
                    ForEach(own) { h in
                        let count = model.customHolidayPeople(h.name).count
                        OptionRow(title: h.name,
                                  caption: "\(OccasionDates.date(month: h.month, day: h.day, year: 2028).formatted(.dateTime.month(.wide).day())) · \(count) \(count == 1 ? "person" : "people")") {
                            holidayToEdit = h
                        }
                    }
                    TextLink(title: "+ Add a holiday") { addingHoliday = true }.padding(.leading, -8)
                    Text("Your own holidays keep the same date each year. Six weeks before, Held Dear reminds you to change it if it moves.")
                        .textStyle(.caption, color: Brand.inkMuted)
                }
                VStack(alignment: .leading, spacing: Brand.space2) {
                    Eyebrow(text: "People")
                    OptionRow(title: "Add from contacts", caption: "Pick several at once") { addingFromContacts = true }
                    OptionRow(title: "Add someone", caption: "A name and a date to remember") { model.route = .addBirthday("") }
                }
                VStack(alignment: .leading, spacing: Brand.space2) {
                    Eyebrow(text: "Lock Screen")
                    Toggle(isOn: $initialsOnly) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Initials only").textStyle(.bodyStrong)
                            Text("The Lock Screen widget shows initials instead of names").textStyle(.caption, color: Brand.inkMuted)
                        }
                    }
                    .tint(Brand.action)
                    .padding(.vertical, Brand.space3).padding(.horizontal, Brand.space4)
                    .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
                    .onChange(of: initialsOnly) { _, _ in model.writeSnapshots() }
                }
                VStack(alignment: .leading, spacing: Brand.space2) {
                    Eyebrow(text: "Photos")
                    PhotoAccessRow().refreshing()
                }
                VStack(alignment: .leading, spacing: Brand.space2) {
                    Eyebrow(text: "Alerts")
                    OptionRow(title: model.notificationsAllowed ? "Alerts are on" : "Alerts are off",
                              caption: "Change them in the Settings app") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
                VStack(alignment: .leading, spacing: Brand.space2) {
                    Eyebrow(text: "Your data")
                    OptionRow(title: "Export my data",
                              caption: exporting ? "Getting your file ready…" : exportFailed ? "The export didn't work. Nothing was changed. Try again."
                                                    : "Everything you've added, with photos, in one file. You choose where it goes.") {
                        exportData()
                    }
                    Toggle(isOn: $keepInICloud) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Keep in iCloud").textStyle(.body)
                            Text(keepInICloud == ICloudSync.isOnAtLaunch
                                 ? "Your plans and photos, in your own iCloud, on your iPhones. Held Dear never sees them."
                                 : "Takes effect the next time Held Dear opens. Everything stays on this iPhone either way.")
                                .textStyle(.caption, color: Brand.inkMuted)
                        }
                    }
                    .tint(Brand.action)
                    .onChange(of: keepInICloud) { _, on in ICloudSync.isOn = on }
                    OptionRow(title: "Import my data",
                              caption: importNote ?? "Puts back everything from an export file: people, days, plans, ideas, years and photos.") {
                        importing = true
                    }
                }
                Text("Your plans stay yours: on your phone and in your own iCloud. Held Dear only sees a card you choose to mail. Held Dear has no account. Purchases go through Apple. A mailed card sends only its message and the two addresses to Handwrytten, to mail it.")
                    .textStyle(.caption, color: Brand.inkMuted)
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"))")
                    .textStyle(.caption, color: Brand.inkMuted)
            }
            .padding(.horizontal, Brand.space5)
            .padding(.vertical, 8)
        }
        .background(Brand.page.ignoresSafeArea())
        .sheet(isPresented: $showLifetime) { LifetimeView() }
        .sheet(isPresented: $editingBirthday) { YourBirthdayEditor() }
        .sheet(isPresented: $addingAnniversary) { YourAnniversaryFlow().environmentObject(model) }
        .onChange(of: yourPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let file = PhotoStore.save(data: data) {
                    YouProfile.photoFile = file
                    yourPhotoFile = file
                    model.revision += 1
                }
                yourPhotoItem = nil
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.zip, .folder, .json]) { result in
            guard case .success(let url) = result else { return }
            if DataImport.storeIsEmpty(model.context) { importData(url, replacing: false) } else { pendingImport = url }
        }
        .confirmationDialog(replaceQuestion, isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }),
                            titleVisibility: .visible) {
            Button("Replace with the export", role: .destructive) {
                if let url = pendingImport { importData(url, replacing: true) }
                pendingImport = nil
            }
        } message: {
            Text("If anything in the file doesn't check out, nothing on this iPhone changes.")
        }
        .sheet(isPresented: Binding(get: { exportItems != nil }, set: { if !$0 { exportItems = nil } })) {
            ShareSheet(items: exportItems ?? []) { _ in exportItems = nil }
        }
        .fullScreenCover(isPresented: $addingHoliday) { OwnHolidayFlow(editing: nil) { addingHoliday = false }.environmentObject(model) }
        .fullScreenCover(item: $holidayToEdit) { h in OwnHolidayFlow(editing: h) { holidayToEdit = nil }.environmentObject(model) }
        .fullScreenCover(isPresented: $makingCard) { MakeCardFlow { makingCard = false }.environmentObject(model) }
        .addFromContacts(isPresented: $addingFromContacts)
    }

    private var replaceQuestion: String {
        let now = DataImport.current(model.context)
        return "This iPhone has \(now.people) \(now.people == 1 ? "person" : "people") and \(now.parts) plan \(now.parts == 1 ? "item" : "items"). Replace them with the export?"
    }

    /// Reads the picked export (zip, folder or JSON) and puts it in. The export file itself is only read.
    private func importData(_ url: URL, replacing: Bool) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            // A coordinated read, so a file still in iCloud Drive is downloaded first.
            var coordinationError: NSError?
            var folderResult: Result<URL, Error> = .failure(DataImport.Failure.notAnExport)
            NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readable in
                folderResult = Result { try DataImport.exportFolder(fromPicked: readable) }
            }
            if let coordinationError { throw coordinationError }
            let folder = try folderResult.get()
            let s = try DataImport.restore(folder: folder, into: model.context, replacing: replacing)
            importNote = "Put back \(s.people) people, \(s.acts) plan items and \(s.photos) photos."
            model.commit()
            Task { await model.refresh() }
        } catch DataImport.Failure.notAnExport {
            importNote = "That file isn't a Held Dear export. Nothing was changed."
        } catch {
            importNote = "The import didn't check out, so nothing was changed. Try again."
        }
    }

    /// Writes the file and opens the share sheet. The file goes nowhere else.
    private func exportData() {
        guard !exporting else { return }
        exporting = true
        Task {
            do {
                exportItems = [try await DataExport.exportInBackground(context: model.context)]
                exportFailed = false
            } catch {
                exportFailed = true
            }
            exporting = false
        }
    }
}

// MARK: - Your photo and dates (Nov 21, 2026)

/// The user's own photo in a circle, or "You" when there's none.
struct YourPhotoCircle: View {
    let file: String?
    var size: CGFloat = 44
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Circle().fill(Brand.raised)
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else { Text("You").font(.system(size: size * 0.28, weight: .medium)).foregroundStyle(Brand.ink) }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay { Circle().strokeBorder(Brand.raisedLine, lineWidth: 1) }
        .task(id: file) { image = await FaceFinder.shared.yourPortrait(side: size) }
        .accessibilityHidden(true)
    }
}

enum YouDates {
    static func text(_ d: YouProfile.Day) -> String {
        var c = DateComponents(); c.month = d.month; c.day = d.day; c.year = d.year ?? 2000
        guard let date = Calendar.current.date(from: c) else { return "" }
        return d.year == nil ? date.formatted(.dateTime.month(.wide).day()) : date.formatted(.dateTime.month(.wide).day().year())
    }
}

/// One screen: the user's birthday, with or without the year.
struct YourBirthdayEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var knowsYear = true
    @State private var had = false

    var body: some View {
        FlowScreen(onClose: { dismiss() }) {
            Question(title: "Your birthday", subtitle: "Kept on this iPhone.", style: .title)
            DatePicker("Birthday", selection: $date, displayedComponents: .date)
                .datePickerStyle(.wheel).labelsHidden()
            Toggle("I'll include the year", isOn: $knowsYear).textStyle(.body).tint(Brand.action)
        } footer: {
            PrimaryButton(title: "Save") {
                let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
                YouProfile.setBirthday(.init(month: c.month ?? 1, day: c.day ?? 1, year: knowsYear ? c.year : nil))
                dismiss()
            }
            if had {
                TextLink(title: "Remove your birthday") { YouProfile.setBirthday(nil); dismiss() }
            }
        }
        .onAppear {
            guard let b = YouProfile.birthday() else { return }
            had = true
            var c = DateComponents(); c.month = b.month; c.day = b.day; c.year = b.year ?? 2000
            date = Calendar.current.date(from: c) ?? Date()
            knowsYear = b.year != nil
        }
    }
}

/// The user's own anniversary: pick the partner, then the date. It's saved on the partner's page as an
/// anniversary with the user, so both photos show.
struct YourAnniversaryFlow: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var partner: Person?
    @State private var date = Date()
    @State private var knowsYear = true

    var body: some View {
        if let partner {
            FlowScreen(onClose: { dismiss() }) {
                Question(title: "Your anniversary with \(DisplayName.plain(partner.name))", subtitle: nil, style: .title)
                DatePicker("Anniversary", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.wheel).labelsHidden()
                Toggle("I'll include the year", isOn: $knowsYear).textStyle(.body).tint(Brand.action)
            } footer: {
                PrimaryButton(title: "Save") {
                    let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
                    let you = (UserDefaults.standard.string(forKey: "yourName") ?? "").trimmingCharacters(in: .whitespaces)
                    model.addOccasion(partner, type: .anniversary, month: c.month ?? 1, day: c.day ?? 1,
                                      year: knowsYear ? c.year : nil, partnerName: you.isEmpty ? "you" : you)
                    dismiss()
                }
            }
        } else {
            FlowScreen(onClose: { dismiss() }) {
                Question(title: "Who's your partner?", subtitle: "Pick them from your people.", style: .title)
                VStack(spacing: 0) {
                    ForEach(model.allPeople().sorted { $0.name < $1.name }) { p in
                        OptionRow(title: DisplayName.plain(p.name), caption: nil) { partner = p }
                    }
                }
            } footer: { EmptyView() }
        }
    }
}

/// Whether Held Dear can look for birthday photos, and the one tap that changes it (Nov 21, 2026). iOS lists
/// Full Access in Settings only after the app has asked, so the first tap asks.
struct PhotoAccessRow: View {
    @ObservedObject private var photos = PhotoMemories.shared

    var body: some View {
        switch photos.status {
        case .authorized:
            OptionRow(title: "Full access to your photos", caption: "Held Dear finds photos from past birthdays by date. They stay in your library.") { openSettings() }
        case .notDetermined:
            OptionRow(title: "Find photos from past birthdays", caption: "Choose Full Access so Held Dear can find them all, by date.") {
                Task { await photos.requestAccess() }
            }
        case .limited:
            OptionRow(title: "Held Dear sees only some photos", caption: "Choose Full Access in Settings, under Photos, to find them all.") { openSettings() }
        default:
            OptionRow(title: "Photos are off for Held Dear", caption: "Choose Full Access in Settings, under Photos, to find birthday photos.") { openSettings() }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
}

extension PhotoAccessRow {
    /// Refreshes when the app comes back, so a change in Settings shows right away.
    func refreshing() -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            PhotoMemories.shared.refresh()
        }
    }
}
