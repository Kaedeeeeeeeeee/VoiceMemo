import Foundation

enum ExportContentType {
    case transcription
    case summary
    case both
}

enum ExportService {

    // MARK: - Markdown

    static func exportMarkdown(recording: Recording, contentType: ExportContentType) -> URL? {
        var lines: [String] = []

        // YAML front matter
        lines.append("---")
        lines.append("title: \"\(recording.title)\"")
        lines.append("date: \(ISO8601DateFormatter().string(from: recording.date))")
        lines.append("duration: \(recording.formattedDuration)")
        lines.append("---")
        lines.append("")

        appendContent(to: &lines, recording: recording, contentType: contentType, markdown: true)

        let text = lines.joined(separator: "\n")
        return writeTemp(text, fileName: "\(recording.title).md")
    }

    // MARK: - Plain Text

    static func exportPlainText(recording: Recording, contentType: ExportContentType) -> URL? {
        var lines: [String] = []

        lines.append(recording.title)
        lines.append("日期: \(DateFormatter.localizedString(from: recording.date, dateStyle: .medium, timeStyle: .short))")
        lines.append("时长: \(recording.formattedDuration)")
        lines.append("")

        appendContent(to: &lines, recording: recording, contentType: contentType, markdown: false)

        let text = lines.joined(separator: "\n")
        return writeTemp(text, fileName: "\(recording.title).txt")
    }

    // MARK: - Word (.docx)

    static func exportWord(recording: Recording, contentType: ExportContentType) -> URL? {
        var lines: [String] = []
        appendContent(to: &lines, recording: recording, contentType: contentType, markdown: true)
        let content = lines.joined(separator: "\n")

        let paragraphs = buildWordParagraphs(title: recording.title, content: content)
        let documentXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
        \(paragraphs)
        </w:body>
        </w:document>
        """

        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        </Types>
        """

        let rels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """

        let files: [(path: String, data: Data)] = [
            ("[Content_Types].xml", Data(contentTypes.utf8)),
            ("_rels/.rels", Data(rels.utf8)),
            ("word/document.xml", Data(documentXML.utf8)),
        ]

        guard let zipData = ZIPBuilder.build(files: files) else { return nil }
        let fileName = "\(recording.title).docx"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try zipData.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - ZIP Package

    static func exportZIPPackage(recording: Recording) -> URL? {
        var files: [(path: String, data: Data)] = []

        // Audio file
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsDir.appendingPathComponent(recording.fileURL)
        if let audioData = try? Data(contentsOf: audioURL) {
            files.append((recording.fileURL, audioData))
        }

        // Transcription
        if let transcription = recording.transcription {
            let text = recording.applyingSpeakerNames(to: transcription)
            files.append(("transcription.txt", Data(text.utf8)))
        }

        // Summary
        if let summary = recording.summary {
            files.append(("summary.md", Data(summary.utf8)))
        }

        // Markers
        let markers = recording.sortedMarkers
        if !markers.isEmpty {
            var markerLines: [String] = []
            for marker in markers {
                markerLines.append("[\(marker.formattedTimestamp)] \(marker.text)")
            }
            files.append(("markers.txt", Data(markerLines.joined(separator: "\n").utf8)))

            for marker in markers {
                if let photoFileName = marker.photoFileName, let data = marker.photoData {
                    files.append(("markers/\(photoFileName)", data))
                }
            }
        }

        guard !files.isEmpty, let zipData = ZIPBuilder.build(files: files) else { return nil }
        let fileName = "\(recording.title).zip"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try zipData.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Helpers

    private static func appendContent(to lines: inout [String], recording: Recording, contentType: ExportContentType, markdown: Bool) {
        switch contentType {
        case .transcription:
            if let transcription = recording.transcription {
                let text = recording.applyingSpeakerNames(to: transcription)
                if markdown {
                    lines.append("## 转写")
                    lines.append("")
                }
                lines.append(markdown ? text : stripMarkdown(text))
            }
        case .summary:
            if let summary = recording.summary {
                if markdown {
                    lines.append("## 摘要")
                    lines.append("")
                }
                lines.append(markdown ? summary : stripMarkdown(summary))
            }
        case .both:
            if let transcription = recording.transcription {
                let text = recording.applyingSpeakerNames(to: transcription)
                if markdown {
                    lines.append("## 转写")
                    lines.append("")
                }
                lines.append(markdown ? text : stripMarkdown(text))
                lines.append("")
            }
            if let summary = recording.summary {
                if markdown {
                    lines.append("## 摘要")
                    lines.append("")
                }
                lines.append(markdown ? summary : stripMarkdown(summary))
            }
        }

        let markersText = recording.markersSection(markdown: markdown)
        if !markersText.isEmpty {
            lines.append("")
            lines.append(markersText)
        }
    }

    private static func stripMarkdown(_ text: String) -> String {
        var result = text
        // Remove headers
        result = result.replacingOccurrences(of: "(?m)^#{1,6}\\s+", with: "", options: .regularExpression)
        // Remove bold/italic
        result = result.replacingOccurrences(of: "\\*{1,3}(.+?)\\*{1,3}", with: "$1", options: .regularExpression)
        // Remove bullet markers
        result = result.replacingOccurrences(of: "(?m)^\\s*[-*]\\s+", with: "• ", options: .regularExpression)
        return result
    }

    private static func writeTemp(_ content: String, fileName: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Word XML Helpers

    private static func buildWordParagraphs(title: String, content: String) -> String {
        var xml = ""

        // Title paragraph
        xml += """
        <w:p><w:pPr><w:pStyle w:val="Title"/><w:jc w:val="center"/></w:pPr>
        <w:r><w:rPr><w:b/><w:sz w:val="48"/></w:rPr><w:t>\(escapeXML(title))</w:t></w:r></w:p>
        """

        let lines = content.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                xml += "<w:p/>\n"
            } else if trimmed.hasPrefix("### ") {
                let text = String(trimmed.dropFirst(4))
                xml += "<w:p><w:pPr><w:pStyle w:val=\"Heading3\"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val=\"28\"/></w:rPr><w:t>\(escapeXML(text))</w:t></w:r></w:p>\n"
            } else if trimmed.hasPrefix("## ") {
                let text = String(trimmed.dropFirst(3))
                xml += "<w:p><w:pPr><w:pStyle w:val=\"Heading2\"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val=\"32\"/></w:rPr><w:t>\(escapeXML(text))</w:t></w:r></w:p>\n"
            } else if trimmed.hasPrefix("# ") {
                let text = String(trimmed.dropFirst(2))
                xml += "<w:p><w:pPr><w:pStyle w:val=\"Heading1\"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val=\"36\"/></w:rPr><w:t>\(escapeXML(text))</w:t></w:r></w:p>\n"
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let text = String(trimmed.dropFirst(2))
                xml += "<w:p><w:pPr><w:ind w:left=\"720\"/></w:pPr><w:r><w:t>• \(escapeXML(text))</w:t></w:r></w:p>\n"
            } else {
                xml += "<w:p><w:r><w:t>\(escapeXML(trimmed))</w:t></w:r></w:p>\n"
            }
        }

        return xml
    }

    private static func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    // MARK: - ZIP Builder

    private enum ZIPBuilder {
        static func build(files: [(path: String, data: Data)]) -> Data? {
            var zipData = Data()
            var centralDirectory = Data()
            var offset: UInt32 = 0

            for file in files {
                let pathData = Data(file.path.utf8)
                let fileData = file.data
                let crc = crc32(fileData)

                // Local file header
                var local = Data()
                local.appendUInt32(0x04034b50) // signature
                local.appendUInt16(20) // version needed
                local.appendUInt16(0)  // flags
                local.appendUInt16(0)  // compression (stored)
                local.appendUInt16(0)  // mod time
                local.appendUInt16(0)  // mod date
                local.appendUInt32(crc)
                local.appendUInt32(UInt32(fileData.count)) // compressed size
                local.appendUInt32(UInt32(fileData.count)) // uncompressed size
                local.appendUInt16(UInt16(pathData.count))  // filename length
                local.appendUInt16(0)  // extra field length
                local.append(pathData)
                local.append(fileData)
                zipData.append(local)

                // Central directory entry
                var cd = Data()
                cd.appendUInt32(0x02014b50) // signature
                cd.appendUInt16(20) // version made by
                cd.appendUInt16(20) // version needed
                cd.appendUInt16(0)  // flags
                cd.appendUInt16(0)  // compression
                cd.appendUInt16(0)  // mod time
                cd.appendUInt16(0)  // mod date
                cd.appendUInt32(crc)
                cd.appendUInt32(UInt32(fileData.count))
                cd.appendUInt32(UInt32(fileData.count))
                cd.appendUInt16(UInt16(pathData.count))
                cd.appendUInt16(0)  // extra field length
                cd.appendUInt16(0)  // comment length
                cd.appendUInt16(0)  // disk number
                cd.appendUInt16(0)  // internal attrs
                cd.appendUInt32(0)  // external attrs
                cd.appendUInt32(offset) // local header offset
                cd.append(pathData)
                centralDirectory.append(cd)

                offset += UInt32(local.count)
            }

            let cdOffset = offset
            let cdSize = UInt32(centralDirectory.count)
            zipData.append(centralDirectory)

            // End of central directory
            var eocd = Data()
            eocd.appendUInt32(0x06054b50) // signature
            eocd.appendUInt16(0) // disk number
            eocd.appendUInt16(0) // cd disk
            eocd.appendUInt16(UInt16(files.count))
            eocd.appendUInt16(UInt16(files.count))
            eocd.appendUInt32(cdSize)
            eocd.appendUInt32(cdOffset)
            eocd.appendUInt16(0) // comment length
            zipData.append(eocd)

            return zipData
        }

        private static func crc32(_ data: Data) -> UInt32 {
            var crc: UInt32 = 0xFFFFFFFF
            for byte in data {
                crc ^= UInt32(byte)
                for _ in 0..<8 {
                    crc = (crc >> 1) ^ (crc & 1 == 1 ? 0xEDB88320 : 0)
                }
            }
            return crc ^ 0xFFFFFFFF
        }
    }
}

// MARK: - Data Extension for ZIP

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: 2))
    }

    mutating func appendUInt32(_ value: UInt32) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: 4))
    }
}
