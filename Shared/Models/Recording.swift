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
