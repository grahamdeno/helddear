import Photos
import SwiftUI

/// Photos the user has hidden from Held Dear, by the library's own id. Kept on this iPhone only; the photo itself is
/// never changed or deleted (feedback on build 1014).
enum HiddenPhotos {
    private static let key = "hiddenPhotoIDs"

    static func all(_ defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    static func hide(_ id: String, _ defaults: UserDefaults = .standard) {
        var set = all(defaults)
        set.insert(id)
        defaults.set(Array(set), forKey: key)
    }

    static func showAll(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }

    /// Past years with hidden photos taken out, and years left empty dropped.
    static func filter(_ years: [PhotoMemories.Year], hidden: Set<String> = all()) -> [PhotoMemories.Year] {
        years.compactMap { y in
            let kept = y.assets.filter { !hidden.contains($0.localIdentifier) }
            return kept.isEmpty ? nil : PhotoMemories.Year(year: y.year, assets: kept)
        }
    }
}

/// A photo opened full screen: use it on the card, or hide it from Held Dear.
struct PhotoViewer: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let asset: PHAsset
    let person: Person
    let caption: String
    var onHidden: () -> Void = {}

    @State private var image: UIImage?
    @State private var saved = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
                    .accessibilityLabel("Photo from \(caption)")
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
            VStack(spacing: Brand.space2) {
                Button {
                    use()
                } label: {
                    Text(saved ? "On \(DisplayName.plain(person.name))'s card" : "Use on \(DisplayName.plain(person.name))'s card")
                        .font(.body.weight(.semibold)).foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .disabled(saved || image == nil)
                Button {
                    HiddenPhotos.hide(asset.localIdentifier)
                    onHidden()
                    dismiss()
                } label: {
                    Text("Hide this photo from Held Dear").font(.body.weight(.semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .accessibilityHint("Held Dear stops showing it. The photo stays in your library.")
            }
            .padding(.horizontal, Brand.space5)
            .padding(.bottom, Brand.space4)
        }
        .task(id: asset.localIdentifier) { image = await PhotoMemories.shared.bestLocalImage(asset) }
    }

    private func use() {
        guard let image, let file = PhotoStore.save(image) else { return }
        person.photoFiles.append(file)
        model.save()
        saved = true
    }
}

/// A photo picked to open, so a sheet can present it.
struct PickedPhoto: Identifiable {
    let asset: PHAsset
    let caption: String
    var id: String { asset.localIdentifier }
}
