import Foundation
import SwiftData

@Model
final class Recording {
    var id: UUID
    var title: String
    var date: Date
    var duration: TimeInterval
    var fileURL: String
    var fileSize: Int64
    var source: RecordingSource
    var transcription: String?
    var summary: String?
    var isTranscribing: Bool
    var isSummarizing: Bool
    var isSynced: Bool
    var summaryCache: [String: String] = [:]
    var speakerNames: [String: String] = [:]
    var speakerSegmentsJSON: String?
    var tags: [String] = []
    @Relationship(deleteRule: .cascade, inverse: \RecordingMarker.recording)
    var markers: [RecordingMarker] = []

    var sortedMarkers: [RecordingMarker] {
        markers.sorted { $0.timestamp < $1.timestamp }
    }

    func markersSection(markdown: Bool) -> String {
        let sorted = sortedMarkers
        guard !sorted.isEmpty else { return "" }
        var lines: [String] = []
        if markdown {
            lines.append("## 标记")
            lines.append("")
            for marker in sorted {
                lines.append("- **[\(marker.formattedTimestamp)]** \(marker.text)")
            }
        } else {
            lines.append("标记")
            lines.append("")
            for marker in sorted {
                lines.append("[\(marker.formattedTimestamp)] \(marker.text)")
            }
        }
        return lines.joined(separator: "\n")
    }

    init(
        title: String,
        date: Date = .now,
        duration: TimeInterval = 0,
        fileURL: String,
        fileSize: Int64 = 0,
        source: RecordingSource = .watch
    ) {
        self.id = UUID()
        self.title = title
        self.date = date
        self.duration = duration
        self.fileURL = fileURL
        self.fileSize = fileSize
        self.source = source
        self.transcription = nil
        self.summary = nil
        self.isTranscribing = false
        self.isSummarizing = false
        self.isSynced = false
        self.summaryCache = [:]
    }

    func applyingSpeakerNames(to text: String) -> String {
        var result = text
        for (original, custom) in speakerNames where !custom.isEmpty {
            result = result.replacingOccurrences(of: "【\(original)】", with: "【\(custom)】")
        }
        return result
    }

    func reversingSpeakerNames(in text: String) -> String {
        var result = text
        for (original, custom) in speakerNames where !custom.isEmpty {
            result = result.replacingOccurrences(of: "【\(custom)】", with: "【\(original)】")
        }
        return result
    }

    static func extractSpeakers(from text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "【(说话人[A-Z\\d]+)】") else { return [] }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        var seen = Set<String>()
        var speakers: [String] = []
        for match in matches {
            if let range = Range(match.range(at: 1), in: text) {
                let speaker = String(text[range])
                if seen.insert(speaker).inserted {
                    speakers.append(speaker)
                }
            }
        }
        return speakers
    }

    #if os(iOS)
    var speakerUtterances: [SpeakerUtterance]? {
        guard let json = speakerSegmentsJSON, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([SpeakerUtterance].self, from: data)
    }

    func setSpeakerUtterances(_ utterances: [SpeakerUtterance]) {
        if let data = try? JSONEncoder().encode(utterances),
           let json = String(data: data, encoding: .utf8) {
            speakerSegmentsJSON = json
        }
    }

    func segmentsForSpeaker(_ speakerLabel: String) -> [SpeakerSegment] {
        guard let utterances = speakerUtterances else { return [] }
        return utterances
            .filter { $0.speaker == speakerLabel }
            .map { SpeakerSegment(startTime: Double($0.startMs) / 1000.0, endTime: Double($0.endMs) / 1000.0) }
    }
    #endif

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

enum RecordingSource: String, Codable {
    case watch
    case phone
    case mac
    case phoneCall
}
