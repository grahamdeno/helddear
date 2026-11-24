import Foundation
import Photos
import SwiftUI

/// "Around [name]'s birthdays" (Graham, Nov 22, 2026): library photos from the day before, of and after each past
/// birthday, offered on the person's Photos page. Keep saves one to the person (with its day taken); Skip hides it
/// for good. Nothing is saved unless kept. Which photos were kept or skipped is remembered on this phone only.
enum BirthdaySuggestions {
    private static let keptKey = "birthdaySuggestions.kept"
    private static let lookKey = "birthdaySuggestions.look"

    /// Whether to look in the library for this person (Graham, Nov 22, 2026): asked when the person is added, never
    /// assumed, since many people have no photos around their birthday. Nil means not asked yet; someone already
    /// sorted counts as yes.
    static func looks(for personID: UUID, _ d: UserDefaults = .standard) -> Bool? {
        if let v = ((d.dictionary(forKey: lookKey) as? [String: Bool]) ?? [:])[personID.uuidString] { return v }
        return kept(for: personID, d).isEmpty && skipped(for: personID, d).isEmpty ? nil : true
    }

    static func setLooks(_ on: Bool, for personID: UUID, _ d: UserDefaults = .standard) {
        var all = (d.dictionary(forKey: lookKey) as? [String: Bool]) ?? [:]
        all[personID.uuidString] = on
        d.set(all, forKey: lookKey)
    }
    private static let skippedKey = "birthdaySuggestions.skipped"

    /// The photos still to offer: not kept, not skipped.
    static func offer(_ ids: [String], kept: Set<String>, skipped: Set<String>) -> [String] {
        ids.filter { !kept.contains($0) && !skipped.contains($0) }
    }

    static func kept(for personID: UUID, _ d: UserDefaults = .standard) -> Set<String> { load(keptKey, personID, d) }
    static func skipped(for personID: UUID, _ d: UserDefaults = .standard) -> Set<String> { load(skippedKey, personID, d) }
    static func markKept(_ id: String, for personID: UUID, _ d: UserDefaults = .standard) { add(id, keptKey, personID, d) }
    static func markSkipped(_ id: String, for personID: UUID, _ d: UserDefaults = .standard) { add(id, skippedKey, personID, d) }
    /// Undo for Skip (Nov 22, 2026).
    static func unmarkSkipped(_ id: String, for personID: UUID, _ d: UserDefaults = .standard) {
        var all = (d.dictionary(forKey: skippedKey) as? [String: [String]]) ?? [:]
        all[personID.uuidString]?.removeAll { $0 == id }
        d.set(all, forKey: skippedKey)
    }

    private static func load(_ key: String, _ personID: UUID, _ d: UserDefaults) -> Set<String> {
        Set(((d.dictionary(forKey: key) as? [String: [String]]) ?? [:])[personID.uuidString] ?? [])
    }

    private static func add(_ id: String, _ key: String, _ personID: UUID, _ d: UserDefaults) {
        var all = (d.dictionary(forKey: key) as? [String: [String]]) ?? [:]
        var list = all[personID.uuidString] ?? []
        if !list.contains(id) { list.append(id) }
        all[personID.uuidString] = list
        d.set(all, forKey: key)
    }

    /// The day a library photo was taken, for a photo picked by hand whose file didn't say (Nov 22, 2026).
    static func takenDate(localIdentifier: String?) -> Date? {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard let id = localIdentifier, status == .authorized || status == .limited else { return nil }
        return PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject?.creationDate
    }
}

/// The section on a person's Photos page: each past birthday's library photos, Keep or Skip on each.
struct BirthdaySuggestionsView: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject private var library = PhotoMemories.shared
    let person: Person
    let month: Int
    let day: Int
    @State private var years: [PhotoMemories.Year] = []
    @State private var kept: Set<String> = []
    @State private var skipped: Set<String> = []
    @State private var saving: Set<String> = []
    @State private var viewing: SuggestedPhoto?

    private var name: String { DisplayName.plain(person.name) }

    @State private var look: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: Brand.space3) {
            if look != true {
                // Not asked yet, or said no: one quiet offer, never a page full of other people's photos.
                if look == nil {
                    Text("Photos from \(name)'s past birthdays?").textStyle(.headline)
                    Text("Held Dear can look in your library for photos taken around \(name)'s birthdays, for you to keep or skip.")
                        .textStyle(.caption, color: Brand.inkMuted)
                    HStack(spacing: Brand.space4) {
                        TextLink(title: "Look in my library") { turnOn() }
                        TextLink(title: "Not for \(name)") { BirthdaySuggestions.setLooks(false, for: person.id); look = false }
                    }
                    .padding(.leading, -8)
                } else {
                    TextLink(title: "Look for photos from \(name)'s past birthdays") { turnOn() }
                        .padding(.leading, -8)
                }
            } else if library.canRead {
                let shown = years.compactMap { y -> (Int, [PHAsset])? in
                    let ids = BirthdaySuggestions.offer(y.assets.map(\.localIdentifier), kept: kept, skipped: skipped)
                    let assets = y.assets.filter { ids.contains($0.localIdentifier) }
                    return assets.isEmpty ? nil : (y.year, assets)
                }
                if !shown.isEmpty {
                    Text("Around \(name)'s birthdays").textStyle(.headline).accessibilityAddTraits(.isHeader)
                    Text("From your library, the day before to the day after. Keep the ones with \(name); the rest stay in Photos.")
                        .textStyle(.caption, color: Brand.inkMuted)
                    ForEach(shown, id: \.0) { year, assets in
                        VStack(alignment: .leading, spacing: Brand.space2) {
                            Text(String(year)).font(Brand.serif(22, relativeTo: .title3)).foregroundStyle(Brand.ink)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(alignment: .top, spacing: Brand.space2) {
                                    ForEach(assets, id: \.localIdentifier) { asset in tile(asset, year: year) }
                                }
                            }
                        }
                    }
                }
            } else {
                Text("Around \(name)'s birthdays").textStyle(.headline)
                Text("Held Dear can show photos from your library taken around \(name)'s past birthdays, for you to keep or skip.")
                    .textStyle(.caption, color: Brand.inkMuted)
                TextLink(title: "Allow photo access") { Task { await library.requestAccess(); load() } }
                    .padding(.leading, -8)
            }
        }
        .task { look = BirthdaySuggestions.looks(for: person.id); if look == true { load() } }
        .fullScreenCover(item: $viewing) { v in
            SuggestionViewer(asset: v.asset, caption: "\(name)'s birthday, \(v.year)", name: name,
                             onKeep: { keep(v.asset) }, onSkip: { skip(v.asset.localIdentifier) })
        }
    }

    private func tile(_ asset: PHAsset, year: Int) -> some View {
        let id = asset.localIdentifier
        return VStack(spacing: 6) {
            Button { viewing = SuggestedPhoto(asset: asset, year: year) } label: {
                AssetThumb(asset: asset, side: 120)
                    .clipShape(RoundedRectangle(cornerRadius: Brand.radiusSm, style: .continuous))
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Photo from \(year)")
            .accessibilityHint("Opens it full screen")
            HStack(spacing: 0) {
                Button { keep(asset) } label: {
                    Text(saving.contains(id) ? "Keeping…" : "Keep").font(.callout.weight(.semibold)).foregroundStyle(Brand.action)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel("Keep this photo from \(year) for \(name)")
                Button { skip(id) } label: {
                    Text("Skip").font(.callout).foregroundStyle(Brand.inkMuted).frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel("Skip this photo")
            }
        }
        .frame(width: 120)
        .disabled(saving.contains(id))
    }

    private func turnOn() {
        BirthdaySuggestions.setLooks(true, for: person.id)
        look = true
        Task {
            if !library.canRead { await library.requestAccess() }
            load()
        }
    }

    private func load() {
        kept = BirthdaySuggestions.kept(for: person.id)
        skipped = BirthdaySuggestions.skipped(for: person.id)
        years = library.years(month: month, day: day, perYear: 12)
    }

    private func keep(_ asset: PHAsset) {
        let id = asset.localIdentifier
        saving.insert(id)
        Task {
            if let image = await library.bestLocalImage(asset), let file = PhotoStore.save(image, taken: asset.creationDate) {
                // Added behind the others, so the photo at the top of the page stays as it is.
                person.photoFiles.insert(file, at: 0)
                model.save()
                BirthdaySuggestions.markKept(id, for: person.id)
                kept.insert(id)
            }
            saving.remove(id)
        }
    }

    private func skip(_ id: String) {
        BirthdaySuggestions.markSkipped(id, for: person.id)
        withMotion(.snappy) { _ = skipped.insert(id) }
        // "Photo skipped · Undo" for a few seconds (Graham, Nov 22, 2026).
        let personID = person.id
        model.offerUndo("Photo skipped") {
            BirthdaySuggestions.unmarkSkipped(id, for: personID)
            withMotion(.snappy) { _ = skipped.remove(id) }
        }
    }
}

/// A suggested photo opened full screen.
struct SuggestedPhoto: Identifiable {
    let asset: PHAsset
    let year: Int
    var id: String { asset.localIdentifier }
}

/// A library photo from a past birthday, full screen (Graham, Nov 22, 2026): pinch or double-tap to zoom, then
/// Keep it for the person or Skip it.
struct SuggestionViewer: View {
    @Environment(\.dismiss) private var dismiss
    let asset: PHAsset
    let caption: String
    let name: String
    var onKeep: () -> Void
    var onSkip: () -> Void
    @State private var image: UIImage?
    @State private var zoom: CGFloat = 1
    @State private var baseZoom: CGFloat = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
                    .scaleEffect(zoom)
                    .gesture(MagnifyGesture()
                        .onChanged { zoom = min(max(baseZoom * $0.magnification, 1), 5) }
                        .onEnded { _ in baseZoom = zoom })
                    .onTapGesture(count: 2) { withMotion(.snappy) { zoom = zoom > 1 ? 1 : 2.5; baseZoom = zoom } }
                    .accessibilityLabel("Photo from \(caption)")
                    .accessibilityAction(named: zoom > 1 ? "Zoom out" : "Zoom in") {
                        withMotion(.snappy) { zoom = zoom > 1 ? 1 : 2.5; baseZoom = zoom }
                    }
            } else {
                ProgressView().tint(.white)
            }
        }
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.15), in: Circle())
            }
            .accessibilityLabel("Close")
            .padding(.leading, Brand.space4).padding(.top, Brand.space2)
        }
        .overlay(alignment: .top) {
            Text(caption).font(.callout.weight(.semibold)).foregroundStyle(.white.opacity(0.9))
                .padding(.top, Brand.space4)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: Brand.space3) {
                Button { onSkip(); dismiss() } label: {
                    Text("Skip").font(.body.weight(.semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                Button { onKeep(); dismiss() } label: {
                    Text("Keep for \(name)").font(.body.weight(.semibold)).foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
            .padding(.horizontal, Brand.space5)
            .padding(.bottom, Brand.space4)
        }
        .task(id: asset.localIdentifier) { image = await PhotoMemories.shared.bestLocalImage(asset) }
    }
}

/// Asked right after a person is added (Graham, Nov 22, 2026): look for their birthday photos, or not.
struct BirthdayPhotosAsk: View {
    let person: Person
    var onDone: () -> Void

    var body: some View {
        let name = DisplayName.plain(person.name)
        FlowScreen {
            Question(title: "Look for photos from \(name)'s birthdays?",
                     subtitle: "Held Dear can show photos from your library taken around \(name)'s past birthdays, for you to keep or skip. Say no if you won't have any.")
            OptionRow(title: "Yes, look in my library", caption: "Shown on \(name)'s Photos page",
                      action: {
                          BirthdaySuggestions.setLooks(true, for: person.id)
                          Task { if !PhotoMemories.shared.canRead { await PhotoMemories.shared.requestAccess() }; onDone() }
                      }, leading: { EmptyView() }, trailing: { Image(systemName: "chevron.right").foregroundStyle(Brand.inkMuted) })
            OptionRow(title: "No, not for \(name)", caption: "You can turn it on later on the Photos page",
                      action: { BirthdaySuggestions.setLooks(false, for: person.id); onDone() },
                      leading: { EmptyView() }, trailing: { Image(systemName: "chevron.right").foregroundStyle(Brand.inkMuted) })
        }
    }
}
