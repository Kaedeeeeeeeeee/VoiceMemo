import Foundation
import SwiftData

@Model
final class RecordingMarker {
    var id: UUID
    var timestamp: TimeInterval
    var text: String
    var photoFileName: String?
    var createdAt: Date
    var recording: Recording?

    init(
        timestamp: TimeInterval,
        text: String,
        photoFileName: String? = nil
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.text = text
        self.photoFileName = photoFileName
        self.createdAt = .now
    }

    var formattedTimestamp: String {
        let minutes = Int(timestamp) / 60
        let seconds = Int(timestamp) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var photoURL: URL? {
        guard let photoFileName else { return nil }
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDir.appendingPathComponent(photoFileName)
    }

    var photoData: Data? {
        guard let photoURL else { return nil }
        return try? Data(contentsOf: photoURL)
    }
}
