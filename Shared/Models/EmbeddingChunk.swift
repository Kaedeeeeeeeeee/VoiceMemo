import Foundation
import SwiftData

@Model
final class EmbeddingChunk {
    var id: UUID
    var recordingID: UUID
    var chunkIndex: Int
    var chunkText: String
    var embeddingData: Data
    var createdAt: Date

    var embedding: [Float] {
        embeddingData.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float.self))
        }
    }

    init(recordingID: UUID, chunkIndex: Int, chunkText: String, embedding: [Float]) {
        self.id = UUID()
        self.recordingID = recordingID
        self.chunkIndex = chunkIndex
        self.chunkText = chunkText
        self.embeddingData = embedding.withUnsafeBytes { Data($0) }
        self.createdAt = .now
    }
}
