import CoreGraphics

/// Framing a photo on a face (Nov 21, 2026). Plain geometry so it's unit tested; the face itself is found on the
/// phone by Apple's Vision framework (Services/FaceFinder.swift). Nothing leaves the phone.
enum FaceFrame {
    /// A square crop around a face for a round portrait: the face fills about half the square, sits a little above
    /// the middle so the chin isn't cut, and the square stays inside the photo. Pixel units, top-left origin.
    /// With no face, the largest centered square.
    static func portraitSquare(face: CGRect?, imageSize: CGSize, faceShare: CGFloat = 0.5) -> CGRect {
        let maxSide = min(imageSize.width, imageSize.height)
        guard let face, face.width > 0, face.height > 0 else {
            return CGRect(x: (imageSize.width - maxSide) / 2, y: (imageSize.height - maxSide) / 2, width: maxSide, height: maxSide)
        }
        let side = min(maxSide, max(face.width, face.height) / faceShare)
        let centerX = face.midX
        let centerY = face.midY + face.height * 0.08
        let x = min(max(0, centerX - side / 2), imageSize.width - side)
        let y = min(max(0, centerY - side / 2), imageSize.height - side)
        return CGRect(x: x, y: y, width: side, height: side)
    }

    /// A crop of the given shape (width / height) for a photo across the top of a share image: as much of the photo
    /// as fits, with the face centered across and its middle about 38% of the way down. Pixel units, top-left origin.
    static func bannerRect(face: CGRect?, imageSize: CGSize, aspect: CGFloat) -> CGRect {
        let width = min(imageSize.width, imageSize.height * aspect)
        let height = width / aspect
        let centerX = face?.midX ?? imageSize.width / 2
        let x = min(max(0, centerX - width / 2), imageSize.width - width)
        let y: CGFloat
        if let face { y = min(max(0, face.midY - height * 0.38), imageSize.height - height) }
        else { y = (imageSize.height - height) / 2 }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Vision's boxes are normalized with the origin at the bottom left; this gives pixels from the top left.
    static func pixelRect(normalized box: CGRect, imageSize: CGSize) -> CGRect {
        CGRect(x: box.minX * imageSize.width, y: (1 - box.maxY) * imageSize.height,
               width: box.width * imageSize.width, height: box.height * imageSize.height)
    }

    /// The largest face, which is usually the person the photo was saved for.
    static func largest(_ faces: [CGRect]) -> CGRect? {
        faces.max { $0.width * $0.height < $1.width * $1.height }
    }
}
