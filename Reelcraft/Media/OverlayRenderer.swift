import Foundation
import UIKit
import CoreImage

/// Renders text overlays to transparent CIImages at the project's render size.
enum OverlayRenderer {

    static func image(for overlay: TextOverlay, renderSize: CGSize) -> CIImage? {
        let text = overlay.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, renderSize.width > 0, renderSize.height > 0 else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: renderSize, format: format)
        let ui = renderer.image { context in
            let cg = context.cgContext
            let base = renderSize.height

            let fontSize: CGFloat
            let weight: UIFont.Weight
            let tracking: CGFloat
            switch overlay.style {
            case .headline:
                fontSize = base * 0.075
                weight = .heavy
                tracking = -base * 0.0016
            case .pill:
                fontSize = base * 0.048
                weight = .bold
                tracking = 0
            case .caption:
                fontSize = base * 0.042
                weight = .bold
                tracking = 0
            case .plain:
                fontSize = base * 0.045
                weight = .semibold
                tracking = 0
            }

            let font = UIFont.systemFont(ofSize: fontSize, weight: weight)
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            paragraph.lineBreakMode = .byWordWrapping
            paragraph.lineSpacing = fontSize * 0.12

            let color = UIColor(hex: overlay.colorHex)
            var attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph,
                .kern: tracking,
            ]
            if overlay.style == .headline || overlay.style == .plain {
                let shadow = NSShadow()
                shadow.shadowColor = UIColor.black.withAlphaComponent(0.55)
                shadow.shadowBlurRadius = base * 0.012
                shadow.shadowOffset = CGSize(width: 0, height: base * 0.004)
                attributes[.shadow] = shadow
            }

            let maxWidth = renderSize.width * 0.84
            let bounding = (text as NSString).boundingRect(
                with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
            let textSize = CGSize(width: ceil(bounding.width) + 4, height: ceil(bounding.height) + 4)
            let centerY = renderSize.height * overlay.position.yFraction
            var textRect = CGRect(
                x: (renderSize.width - textSize.width) / 2,
                y: centerY - textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )

            switch overlay.style {
            case .pill, .caption:
                let padX = base * 0.03
                let padY = base * 0.016
                let pillRect = textRect.insetBy(dx: -padX, dy: -padY)
                let radius = overlay.style == .caption ? base * 0.012 : pillRect.height / 2
                let path = UIBezierPath(roundedRect: pillRect, cornerRadius: radius)
                UIColor.black.withAlphaComponent(overlay.style == .caption ? 0.62 : 0.5).setFill()
                path.fill()
                cg.setBlendMode(.normal)
            case .headline:
                // A short ember underline gives headlines their own rhythm.
                let barWidth = min(textRect.width * 0.5, base * 0.16)
                let barHeight = max(3, base * 0.006)
                let barRect = CGRect(
                    x: (renderSize.width - barWidth) / 2,
                    y: textRect.minY - barHeight * 2.4,
                    width: barWidth,
                    height: barHeight
                )
                let barPath = UIBezierPath(roundedRect: barRect, cornerRadius: barHeight / 2)
                UIColor(hex: 0xFF5C38).setFill()
                barPath.fill()
            case .plain:
                break
            }

            textRect.origin.y += 1
            (text as NSString).draw(
                with: textRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
        }

        guard let cgImage = ui.cgImage else { return nil }
        return CIImage(cgImage: cgImage)
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
