import UIKit

/// Photos the user saves to a person, kept as downscaled JPEGs inside the app. Nothing is uploaded.
enum PhotoStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    static func url(_ file: String) -> URL { directory.appendingPathComponent(file) }

    /// Saves a copy no larger than 1600 px on the long side; returns its file name.
    @discardableResult
    static func save(_ image: UIImage, maxSide: CGFloat = 1600) -> String? {
        let scaled = downscale(image, maxSide: maxSide)
        guard let data = scaled.jpegData(compressionQuality: 0.85) else { return nil }
        let name = UUID().uuidString + ".jpg"
        do { try data.write(to: url(name), options: .atomic) } catch { return nil }
        return name
    }

    static func save(data: Data) -> String? {
        guard let image = UIImage(data: data) else { return nil }
        return save(image)
    }

    /// Moves a photo from the share extension's inbox into the app.
    static func adopt(fileAt source: URL) -> String? {
        guard let data = try? Data(contentsOf: source) else { return nil }
        let name = save(data: data)
        try? FileManager.default.removeItem(at: source)
        return name
    }

    static func load(_ file: String?) -> UIImage? {
        guard let file else { return nil }
        return UIImage(contentsOfFile: url(file).path)
    }

    static func delete(_ file: String) {
        try? FileManager.default.removeItem(at: url(file))
    }

    static func downscale(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let side = max(image.size.width, image.size.height)
        guard side > maxSide else { return image }
        let scale = maxSide / side
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }
}
