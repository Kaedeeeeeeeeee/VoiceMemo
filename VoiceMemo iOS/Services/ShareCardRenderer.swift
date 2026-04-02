import UIKit

enum ShareCardRenderer {

    static func render(recording: Recording) -> UIImage? {
        let width: CGFloat = 1080
        let height: CGFloat = 1350
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))

        return renderer.image { ctx in
            let cgCtx = ctx.cgContext

            // Dark gradient background
            let colors = [
                UIColor(red: 0.08, green: 0.08, blue: 0.14, alpha: 1.0).cgColor,
                UIColor(red: 0.12, green: 0.10, blue: 0.20, alpha: 1.0).cgColor,
                UIColor(red: 0.06, green: 0.06, blue: 0.10, alpha: 1.0).cgColor,
            ]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0.0, 0.5, 1.0])!
            cgCtx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: width, y: height), options: [])

            let margin: CGFloat = 80
            let contentWidth = width - margin * 2
            var cursorY: CGFloat = 120

            // App icon / decorative element
            let iconRect = CGRect(x: margin, y: cursorY, width: 60, height: 60)
            let iconPath = UIBezierPath(roundedRect: iconRect, cornerRadius: 14)
            UIColor(red: 0.4, green: 0.3, blue: 0.9, alpha: 0.6).setFill()
            iconPath.fill()

            let micAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 30),
                .foregroundColor: UIColor.white,
            ]
            let mic = "🎙"
            let micSize = mic.size(withAttributes: micAttrs)
            mic.draw(at: CGPoint(x: iconRect.midX - micSize.width / 2, y: iconRect.midY - micSize.height / 2), withAttributes: micAttrs)

            cursorY += 100

            // Title
            let titleFont = UIFont.systemFont(ofSize: 56, weight: .bold)
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.white,
            ]
            let titleRect = CGRect(x: margin, y: cursorY, width: contentWidth, height: 200)
            let titleStr = recording.title as NSString
            let titleBounds = titleStr.boundingRect(with: CGSize(width: contentWidth, height: 200), options: [.usesLineFragmentOrigin], attributes: titleAttrs, context: nil)
            titleStr.draw(in: titleRect, withAttributes: titleAttrs)
            cursorY += ceil(titleBounds.height) + 30

            // Date & Duration
            let metaFont = UIFont.systemFont(ofSize: 28, weight: .medium)
            let metaColor = UIColor(white: 0.6, alpha: 1.0)
            let metaAttrs: [NSAttributedString.Key: Any] = [
                .font: metaFont,
                .foregroundColor: metaColor,
            ]
            let dateStr = DateFormatter.localizedString(from: recording.date, dateStyle: .long, timeStyle: .short)
            let metaText = "\(dateStr)  ·  \(recording.formattedDuration)"
            (metaText as NSString).draw(in: CGRect(x: margin, y: cursorY, width: contentWidth, height: 50), withAttributes: metaAttrs)
            cursorY += 70

            // Divider
            let dividerPath = UIBezierPath()
            dividerPath.move(to: CGPoint(x: margin, y: cursorY))
            dividerPath.addLine(to: CGPoint(x: width - margin, y: cursorY))
            UIColor(white: 1.0, alpha: 0.15).setStroke()
            dividerPath.lineWidth = 1
            dividerPath.stroke()
            cursorY += 50

            // Summary excerpt (first 200 chars)
            if let summary = recording.summary {
                let excerptFont = UIFont.systemFont(ofSize: 34, weight: .regular)
                let excerptColor = UIColor(white: 0.85, alpha: 1.0)
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineSpacing = 10
                let excerptAttrs: [NSAttributedString.Key: Any] = [
                    .font: excerptFont,
                    .foregroundColor: excerptColor,
                    .paragraphStyle: paragraphStyle,
                ]
                let excerpt = String(summary.prefix(200)) + (summary.count > 200 ? "..." : "")
                let excerptRect = CGRect(x: margin, y: cursorY, width: contentWidth, height: height - cursorY - 200)
                (excerpt as NSString).draw(in: excerptRect, withAttributes: excerptAttrs)
            }

            // Watermark at bottom
            let watermarkFont = UIFont.systemFont(ofSize: 24, weight: .medium)
            let watermarkAttrs: [NSAttributedString.Key: Any] = [
                .font: watermarkFont,
                .foregroundColor: UIColor(white: 0.4, alpha: 1.0),
            ]
            let watermark = "Recorded with PodNote"
            let watermarkSize = (watermark as NSString).size(withAttributes: watermarkAttrs)
            (watermark as NSString).draw(
                at: CGPoint(x: width - margin - watermarkSize.width, y: height - 80 - watermarkSize.height),
                withAttributes: watermarkAttrs
            )
        }
    }
}
