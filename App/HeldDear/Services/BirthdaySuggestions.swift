import Foundation
import Photos
import SwiftUI

/// "Around [name]'s birthdays" (Graham, Nov 22, 2026): library photos from the day before, of and after each past
/// birthday, offered on the person's Photos page. Keep saves one to the person (with its day taken); Skip hides it
/// for good. Nothing is saved unless kept. Which photos were kept or skipped is remembered on this phone only.
enum BirthdaySuggestions {
    private static let keptKey = "birthdaySuggestions.kept"
    private static let skippedKey = "birthdaySuggestions.skipped"

    /// The photos still to offer: not kept, not skipped.
    static func offer(_ ids: [String], kept: Set<String>, skipped: Set<String>) -> [String] {
        ids.filter { !kept.contains($0) && !skipped.contains($0) }
    }

    static func kept(for personID: UUID, _ d: UserDefaults = .standard) -> Set<String> { load(keptKey, personID, d) }
    static func skipped(for personID: UUID, _ d: UserDefaults = .standard) -> Set<String> { load(skippedKey, personID, d) }
    static func markKept(_ id: String, for personID: UUID, _ d: UserDefaults = .standard) { add(id, keptKey, personID, d) }
    static func markSkipped(_ id: String, for personID: UUID, _ d: UserDefaults = .standard) { add(id, skippedKey, personID, d) }

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

    private var name: String { DisplayName.plain(person.name) }

    var body: some View {
        VStack(alignment: .leading, spacing: Brand.space3) {
            if library.canRead {
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
        .task { load() }
    }

    private func tile(_ asset: PHAsset, year: Int) -> some View {
        let id = asset.localIdentifier
        return VStack(spacing: 6) {
            AssetThumb(asset: asset, side: 120)
                .clipShape(RoundedRectangle(cornerRadius: Brand.radiusSm, style: .continuous))
                .accessibilityLabel("Photo from \(year)")
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
        withAnimation(.snappy) { _ = skipped.insert(id) }
    }
}
