import UIKit
import SwiftUI

enum PDFRenderer {
    static func render(title: String, content: String, type: String) -> URL? {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 40
        let contentWidth = pageWidth - margin * 2
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let titleFont = UIFont.systemFont(ofSize: 24, weight: .bold)
        let typeFont = UIFont.systemFont(ofSize: 12, weight: .medium)
        let h1Font = UIFont.systemFont(ofSize: 22, weight: .bold)
        let h2Font = UIFont.systemFont(ofSize: 18, weight: .bold)
        let h3Font = UIFont.systemFont(ofSize: 16, weight: .bold)
        let bodyFont = UIFont.systemFont(ofSize: 14, weight: .regular)
        let bulletFont = UIFont.systemFont(ofSize: 14, weight: .regular)

        let textColor = UIColor.black
        let mutedColor = UIColor.darkGray

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { ctx in
            var cursorY: CGFloat = 0

            func beginNewPage() {
                ctx.beginPage()
                cursorY = margin
            }

            func ensureSpace(_ height: CGFloat) {
                if cursorY + height > pageHeight - margin {
                    beginNewPage()
                }
            }

            func drawText(_ text: String, font: UIFont, color: UIColor, indent: CGFloat = 0, spacingAfter: CGFloat = 6) {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color
                ]
                let maxWidth = contentWidth - indent
                let constraintSize = CGSize(width: maxWidth, height: .greatestFiniteMagnitude)
                let boundingRect = (text as NSString).boundingRect(
                    with: constraintSize,
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attrs,
                    context: nil
                )
                let textHeight = ceil(boundingRect.height)

                ensureSpace(textHeight + spacingAfter)

                let drawRect = CGRect(x: margin + indent, y: cursorY, width: maxWidth, height: textHeight)
                (text as NSString).draw(in: drawRect, withAttributes: attrs)
                cursorY += textHeight + spacingAfter
            }

            // First page
            beginNewPage()

            // Title
            drawText(title, font: titleFont, color: textColor, spacingAfter: 8)

            // Type label
            drawText(type, font: typeFont, color: mutedColor, spacingAfter: 12)

            // Separator line
            ensureSpace(10)
            let linePath = UIBezierPath()
            linePath.move(to: CGPoint(x: margin, y: cursorY))
            linePath.addLine(to: CGPoint(x: pageWidth - margin, y: cursorY))
            UIColor.lightGray.setStroke()
            linePath.lineWidth = 0.5
            linePath.stroke()
            cursorY += 16

            // Parse content lines
            let lines = content.components(separatedBy: "\n")

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if trimmed.isEmpty {
                    cursorY += 8
                    continue
                }

                if trimmed.hasPrefix("### ") {
                    let text = String(trimmed.dropFirst(4))
                    ensureSpace(24)
                    cursorY += 6
                    drawText(text, font: h3Font, color: textColor, spacingAfter: 4)
                } else if trimmed.hasPrefix("## ") {
                    let text = String(trimmed.dropFirst(3))
                    ensureSpace(28)
                    cursorY += 8
                    drawText(text, font: h2Font, color: textColor, spacingAfter: 6)
                } else if trimmed.hasPrefix("# ") {
                    let text = String(trimmed.dropFirst(2))
                    ensureSpace(32)
                    cursorY += 10
                    drawText(text, font: h1Font, color: textColor, spacingAfter: 8)
                } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                    let text = String(trimmed.dropFirst(2))
                    // Check nesting level
                    let leadingSpaces = line.prefix(while: { $0 == " " }).count
                    let nestLevel = leadingSpaces / 2
                    let indent: CGFloat = CGFloat(20 + nestLevel * 16)
                    let bullet = nestLevel > 0 ? "◦ " : "• "
                    drawText(bullet + text, font: bulletFont, color: textColor, indent: indent, spacingAfter: 4)
                } else {
                    drawText(trimmed, font: bodyFont, color: textColor, spacingAfter: 6)
                }
            }
        }

        let fileName = "\(title)_\(type).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("Failed to write PDF: \(error)")
            return nil
        }
    }
}

struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
