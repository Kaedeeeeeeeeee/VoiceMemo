import Foundation
import SwiftData
import Accelerate

final class EmbeddingService {
    static let shared = EmbeddingService()

    private let proxyBaseURL = APIConfig.proxyBaseURL
    private let proxyAuthToken = APIConfig.proxyAuthToken

    private init() {}

    // MARK: - Public API

    func generateEmbeddings(for recording: Recording, context: ModelContext) async throws {
        guard let transcription = recording.transcription, !transcription.isEmpty else { return }

        // Delete existing chunks first
        deleteChunks(for: recording.id, context: context)

        let chunks = splitIntoChunks(transcription)
        let embeddings = try await fetchEmbeddings(for: chunks)

        for (index, (text, embedding)) in zip(chunks, embeddings).enumerated() {
            let chunk = EmbeddingChunk(
                recordingID: recording.id,
                chunkIndex: index,
                chunkText: text,
                embedding: embedding
            )
            context.insert(chunk)
        }
        try context.save()
    }

    func embedQuery(_ query: String) async throws -> [Float] {
        let results = try await fetchEmbeddings(for: [query])
        guard let first = results.first else {
            throw EmbeddingError.emptyResponse
        }
        return first
    }

    func searchChunks(
        queryEmbedding: [Float],
        recordingIDs: [UUID],
        context: ModelContext,
        topK: Int = 10
    ) -> [(EmbeddingChunk, Float)] {
        let descriptor = FetchDescriptor<EmbeddingChunk>(
            predicate: #Predicate { chunk in
                recordingIDs.contains(chunk.recordingID)
            }
        )
        guard let allChunks = try? context.fetch(descriptor), !allChunks.isEmpty else {
            return []
        }

        var scored: [(EmbeddingChunk, Float)] = []
        for chunk in allChunks {
            let similarity = cosineSimilarity(queryEmbedding, chunk.embedding)
            scored.append((chunk, similarity))
        }

        scored.sort { $0.1 > $1.1 }
        return Array(scored.prefix(topK))
    }

    func hasEmbeddings(for recordingID: UUID, context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<EmbeddingChunk>(
            predicate: #Predicate { $0.recordingID == recordingID }
        )
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    func deleteChunks(for recordingID: UUID, context: ModelContext) {
        let descriptor = FetchDescriptor<EmbeddingChunk>(
            predicate: #Predicate { $0.recordingID == recordingID }
        )
        if let chunks = try? context.fetch(descriptor) {
            for chunk in chunks {
                context.delete(chunk)
            }
        }
    }

    // MARK: - Chunking

    private func splitIntoChunks(_ text: String, targetSize: Int = 2000, overlap: Int = 200) -> [String] {
        let paragraphs = text.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        if paragraphs.isEmpty {
            // No paragraph breaks — split by character count
            return splitBySize(text, targetSize: targetSize, overlap: overlap)
        }

        var chunks: [String] = []
        var current = ""

        for paragraph in paragraphs {
            if current.isEmpty {
                current = paragraph
            } else if current.count + paragraph.count + 2 <= targetSize {
                current += "\n\n" + paragraph
            } else {
                chunks.append(current)
                // Overlap: take the tail of current chunk
                let overlapText = String(current.suffix(overlap))
                current = overlapText + "\n\n" + paragraph
            }
        }

        if !current.isEmpty {
            chunks.append(current)
        }

        return chunks
    }

    private func splitBySize(_ text: String, targetSize: Int, overlap: Int) -> [String] {
        var chunks: [String] = []
        var start = text.startIndex

        while start < text.endIndex {
            let end = text.index(start, offsetBy: targetSize, limitedBy: text.endIndex) ?? text.endIndex
            chunks.append(String(text[start..<end]))

            if end == text.endIndex { break }
            // Move back by overlap amount for next chunk
            let nextStart = text.index(end, offsetBy: -overlap, limitedBy: text.startIndex) ?? text.startIndex
            start = nextStart
        }

        return chunks
    }

    // MARK: - API

    private func fetchEmbeddings(for texts: [String]) async throws -> [[Float]] {
        guard let url = URL(string: "\(proxyBaseURL)/openai/v1/embeddings") else {
            throw EmbeddingError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(proxyAuthToken, forHTTPHeaderField: "X-App-Token")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "text-embedding-3-small",
            "input": texts
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw EmbeddingError.apiError(statusCode: statusCode, message: errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]] else {
            throw EmbeddingError.invalidResponse
        }

        // Sort by index to match input order
        let sorted = dataArray.sorted {
            ($0["index"] as? Int ?? 0) < ($1["index"] as? Int ?? 0)
        }

        return sorted.compactMap { item -> [Float]? in
            guard let embedding = item["embedding"] as? [Double] else { return nil }
            return embedding.map { Float($0) }
        }
    }

    // MARK: - Cosine Similarity (vDSP accelerated)

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dot: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        vDSP_dotpr(a, 1, b, 1, &dot, vDSP_Length(a.count))
        vDSP_dotpr(a, 1, a, 1, &normA, vDSP_Length(a.count))
        vDSP_dotpr(b, 1, b, 1, &normB, vDSP_Length(b.count))

        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0 else { return 0 }
        return dot / denominator
    }
}

enum EmbeddingError: LocalizedError {
    case apiError(statusCode: Int, message: String)
    case invalidResponse
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .apiError(let code, let msg): return "Embedding API error (\(code)): \(msg)"
        case .invalidResponse: return "Invalid embedding response"
        case .emptyResponse: return "Empty embedding response"
        }
    }
}
