import UIKit

/// Two face-framed photos side by side as one banner, with a thin dark seam between (anniversary share card,
/// Nov 21, 2026). Made on the phone.
enum PairBanner {
    static func join(_ left: UIImage, _ right: UIImage, aspect: CGFloat, width: CGFloat = 1200) -> UIImage {
        let size = CGSize(width: width, height: (width / aspect).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let seam: CGFloat = 6
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor(red: 0.090, green: 0.082, blue: 0.075, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let half = (size.width - seam) / 2
            left.draw(in: CGRect(x: 0, y: 0, width: half, height: size.height))
            right.draw(in: CGRect(x: half + seam, y: 0, width: half, height: size.height))
        }
    }
}
