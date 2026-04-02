import Foundation
import SwiftData

@Model
final class SpeakerProfile {
    var id: UUID
    var name: String
    var embedding: [Double]
    var sampleCount: Int
    var totalSampleDuration: Double
    var createdAt: Date
    var updatedAt: Date

    init(name: String, embedding: [Double], sampleCount: Int = 1, totalSampleDuration: Double = 0) {
        self.id = UUID()
        self.name = name
        self.embedding = embedding
        self.sampleCount = sampleCount
        self.totalSampleDuration = totalSampleDuration
        self.createdAt = .now
        self.updatedAt = .now
    }
}
