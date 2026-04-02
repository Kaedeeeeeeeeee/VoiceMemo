import Foundation
import SwiftData
import Observation

struct SearchResult: Identifiable {
    let id: UUID
    let recording: Recording
    let score: Float
    let excerpts: [String]
}

@Observable
final class KnowledgeBaseSearchService {

    private static let chineseStopWords: Set<String> = [
        "的", "了", "在", "是", "我", "有", "和", "就", "不", "人",
        "都", "一", "一个", "上", "也", "很", "到", "说", "要", "去",
        "你", "会", "着", "没有", "看", "好", "自己", "这", "他", "她",
        "吗", "吧", "啊", "呢", "哦", "嗯", "那", "这个", "那个",
        "什么", "怎么", "为什么", "哪", "哪里", "哪个", "多少",
        "可以", "就是", "但是", "然后", "因为", "所以", "如果",
        "还是", "或者", "以及", "而且", "不过", "虽然", "但",
        "把", "被", "从", "对", "给", "让", "用", "比", "跟",
        "the", "a", "an", "is", "are", "was", "were", "be", "been",
        "being", "have", "has", "had", "do", "does", "did", "will",
        "would", "could", "should", "may", "might", "can", "shall",
        "to", "of", "in", "for", "on", "with", "at", "by", "from",
        "as", "into", "through", "during", "before", "after",
        "and", "but", "or", "nor", "not", "so", "yet", "both",
        "it", "its", "this", "that", "these", "those", "i", "me",
        "my", "we", "our", "you", "your", "he", "him", "his",
        "she", "her", "they", "them", "their", "what", "which",
        "who", "whom", "how", "when", "where", "why",
    ]

    // MARK: - Semantic Search

    func semanticSearch(query: String, in recordings: [Recording], context: ModelContext) async throws -> [SearchResult] {
        let embeddingService = EmbeddingService.shared
        let transcribed = recordings.filter { $0.transcription != nil && !($0.transcription?.isEmpty ?? true) }
        guard !transcribed.isEmpty else { return [] }

        // Split recordings into those with/without embeddings
        var withEmbeddings: [Recording] = []
        var withoutEmbeddings: [Recording] = []
        for recording in transcribed {
            if embeddingService.hasEmbeddings(for: recording.id, context: context) {
                withEmbeddings.append(recording)
            } else {
                withoutEmbeddings.append(recording)
            }
        }

        var allResults: [SearchResult] = []

        // Semantic search for recordings with embeddings
        if !withEmbeddings.isEmpty {
            let queryEmbedding = try await embeddingService.embedQuery(query)
            let recordingIDs = withEmbeddings.map(\.id)
            let chunks = embeddingService.searchChunks(
                queryEmbedding: queryEmbedding,
                recordingIDs: recordingIDs,
                context: context,
                topK: 15
            )

            // Group chunks by recording, take best score per recording
            var bestByRecording: [UUID: (Float, [String])] = [:]
            for (chunk, score) in chunks {
                let excerpt = chunk.chunkText.count > 300 ? String(chunk.chunkText.prefix(300)) + "..." : chunk.chunkText
                if let existing = bestByRecording[chunk.recordingID] {
                    var excerpts = existing.1
                    if excerpts.count < 3 { excerpts.append(excerpt) }
                    bestByRecording[chunk.recordingID] = (max(existing.0, score), excerpts)
                } else {
                    bestByRecording[chunk.recordingID] = (score, [excerpt])
                }
            }

            for recording in withEmbeddings {
                if let (score, excerpts) = bestByRecording[recording.id] {
                    allResults.append(SearchResult(
                        id: recording.id,
                        recording: recording,
                        score: score,
                        excerpts: excerpts
                    ))
                }
            }
        }

        // Keyword fallback for recordings without embeddings
        if !withoutEmbeddings.isEmpty {
            let keywordResults = searchRecordings(query: query, in: withoutEmbeddings)
            // Normalize keyword scores to 0..1 range for merging
            let maxKeywordScore = keywordResults.map(\.score).max() ?? 1
            let normalizedResults = keywordResults.map { result in
                SearchResult(
                    id: result.id,
                    recording: result.recording,
                    score: maxKeywordScore > 0 ? result.score / maxKeywordScore * 0.5 : 0,
                    excerpts: result.excerpts
                )
            }
            allResults.append(contentsOf: normalizedResults)
        }

        if allResults.isEmpty {
            return fallbackResults(from: recordings)
        }

        return Array(allResults.sorted { $0.score > $1.score }.prefix(5))
    }

    // MARK: - Keyword Search (fallback)

    func searchRecordings(query: String, in recordings: [Recording]) -> [SearchResult] {
        let keywords = extractKeywords(from: query)
        guard !keywords.isEmpty else {
            return fallbackResults(from: recordings)
        }

        var results: [SearchResult] = []

        for recording in recordings {
            guard let transcription = recording.transcription, !transcription.isEmpty else { continue }

            var score: Float = 0
            var excerpts: [String] = []

            let transcriptionLower = transcription.lowercased()
            let titleLower = recording.title.lowercased()
            let summaryLower = (recording.summary ?? "").lowercased()

            for keyword in keywords {
                let kw = keyword.lowercased()

                let transcriptionHits = countOccurrences(of: kw, in: transcriptionLower)
                score += Float(transcriptionHits)

                if titleLower.contains(kw) {
                    score += 5
                }

                if summaryLower.contains(kw) {
                    score += 3
                }

                if let excerpt = extractExcerpt(around: kw, in: transcription) {
                    excerpts.append(excerpt)
                }
            }

            if score > 0 {
                let uniqueExcerpts = Array(Set(excerpts).prefix(3))
                results.append(SearchResult(
                    id: recording.id,
                    recording: recording,
                    score: score,
                    excerpts: uniqueExcerpts
                ))
            }
        }

        if results.isEmpty {
            return fallbackResults(from: recordings)
        }

        return Array(results.sorted { $0.score > $1.score }.prefix(5))
    }

    func buildContext(from results: [SearchResult]) -> String {
        var context = ""
        let maxLength = 12000

        for result in results {
            let header = "【\(result.recording.title)】(\(result.recording.date.formatted(.dateTime.year().month().day())))\n"

            if !result.excerpts.isEmpty {
                let excerptText = result.excerpts.joined(separator: "\n...\n")
                let entry = header + excerptText + "\n\n"
                if context.count + entry.count > maxLength { break }
                context += entry
            } else if let summary = result.recording.summary, !summary.isEmpty {
                let entry = header + String(summary.prefix(400)) + "\n\n"
                if context.count + entry.count > maxLength { break }
                context += entry
            }
        }

        return context
    }

    // MARK: - Private

    private func extractKeywords(from query: String) -> [String] {
        let separators = CharacterSet.whitespaces
            .union(.punctuationCharacters)
            .union(CharacterSet(charactersIn: "\u{FF0C}\u{3002}\u{FF1F}\u{FF01}\u{3001}\u{FF1B}\u{FF1A}\u{201C}\u{201D}\u{2018}\u{2019}\u{FF08}\u{FF09}"))

        let tokens = query.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var keywords: [String] = []
        for token in tokens {
            let lower = token.lowercased()
            if Self.chineseStopWords.contains(lower) { continue }
            if token.count <= 1 { continue }
            keywords.append(token)
        }

        return keywords
    }

    private func countOccurrences(of substring: String, in string: String) -> Int {
        var count = 0
        var searchRange = string.startIndex..<string.endIndex
        while let range = string.range(of: substring, options: .caseInsensitive, range: searchRange) {
            count += 1
            searchRange = range.upperBound..<string.endIndex
        }
        return count
    }

    private func extractExcerpt(around keyword: String, in text: String, windowSize: Int = 200) -> String? {
        guard let range = text.range(of: keyword, options: .caseInsensitive) else { return nil }

        let center = text.distance(from: text.startIndex, to: range.lowerBound)
        let halfWindow = windowSize / 2

        let startOffset = max(0, center - halfWindow)
        let endOffset = min(text.count, center + keyword.count + halfWindow)

        let startIndex = text.index(text.startIndex, offsetBy: startOffset)
        let endIndex = text.index(text.startIndex, offsetBy: endOffset)

        var excerpt = String(text[startIndex..<endIndex])

        if startOffset > 0 { excerpt = "..." + excerpt }
        if endOffset < text.count { excerpt = excerpt + "..." }

        return excerpt
    }

    private func fallbackResults(from recordings: [Recording]) -> [SearchResult] {
        let transcribed = recordings
            .filter { $0.transcription != nil && !($0.transcription?.isEmpty ?? true) }
            .sorted { $0.date > $1.date }
            .prefix(10)

        return transcribed.map { recording in
            let excerpt: [String]
            if let summary = recording.summary, !summary.isEmpty {
                excerpt = [String(summary.prefix(300))]
            } else if let transcription = recording.transcription {
                excerpt = [String(transcription.prefix(300))]
            } else {
                excerpt = []
            }
            return SearchResult(
                id: recording.id,
                recording: recording,
                score: 0,
                excerpts: excerpt
            )
        }
    }
}
