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

    static func extractSpeakers(from text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "【(说话人\\d+)】") else { return [] }
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
}
