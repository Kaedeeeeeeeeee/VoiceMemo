import Testing
import SwiftData
import Foundation
@testable import VoiceMemo_iOS

@Suite("EmbeddingChunk Tests")
struct EmbeddingChunkTests {

    @Test func embedding_roundTrip() async throws {
        let container = try await TestModelContainer.create()
        let context = ModelContext(container)
        let values: [Float] = [1.0, 2.5, -3.14, 0.0]
        let chunk = EmbeddingChunk(recordingID: UUID(), chunkIndex: 0, chunkText: "test", embedding: values)
        context.insert(chunk)

        let result = chunk.embedding
        #expect(result.count == 4)
        for (a, b) in zip(values, result) {
            #expect(Swift.abs(a - b) < Float(0.001))
        }
    }

    @Test func embedding_emptyArray() async throws {
        let container = try await TestModelContainer.create()
        let context = ModelContext(container)
        let chunk = EmbeddingChunk(recordingID: UUID(), chunkIndex: 0, chunkText: "test", embedding: [])
        context.insert(chunk)
        #expect(chunk.embedding.isEmpty)
    }

    @Test func embedding_largeArray() async throws {
        let container = try await TestModelContainer.create()
        let context = ModelContext(container)
        let values = (0..<1536).map { Float($0) * 0.001 }
        let chunk = EmbeddingChunk(recordingID: UUID(), chunkIndex: 0, chunkText: "test", embedding: values)
        context.insert(chunk)
        #expect(chunk.embedding.count == 1536)
    }

    @Test func embeddingData_sizeMatchesFloatCount() async throws {
        let container = try await TestModelContainer.create()
        let context = ModelContext(container)
        let values: [Float] = [1.0, 2.0, 3.0]
        let chunk = EmbeddingChunk(recordingID: UUID(), chunkIndex: 0, chunkText: "test", embedding: values)
        context.insert(chunk)
        #expect(chunk.embeddingData.count == 3 * MemoryLayout<Float>.size)
    }
}
