import Testing
import SwiftData
import Foundation
@testable import VoiceMemo_iOS

@Suite("KnowledgeBaseSearchService Tests")
struct KnowledgeBaseSearchServiceTests {

    private func makeRecording(
        title: String,
        transcription: String? = nil,
        summary: String? = nil,
        date: Date = .now,
        container: ModelContainer
    ) -> Recording {
        let context = ModelContext(container)
        let r = Recording(title: title, date: date, fileURL: "\(title).m4a")
        r.transcription = transcription
        r.summary = summary
        context.insert(r)
        return r
    }

    @Test func searchRecordings_matchesTranscription() async throws {
        let container = try await TestModelContainer.create()
        let service = KnowledgeBaseSearchService()
        let r = makeRecording(title: "会议", transcription: "讨论产品路线图和发布计划", container: container)

        let results = service.searchRecordings(query: "产品路线图", in: [r])
        #expect(results.count == 1)
        #expect(results[0].score > 0)
    }

    @Test func searchRecordings_titleBonus() async throws {
        let container = try await TestModelContainer.create()
        let service = KnowledgeBaseSearchService()
        let r1 = makeRecording(title: "产品路线图讨论", transcription: "一些内容", container: container)
        let r2 = makeRecording(title: "其他会议", transcription: "产品路线图 产品路线图", container: container)

        let results = service.searchRecordings(query: "产品路线图", in: [r1, r2])
        // r1 has title match bonus (+5) + transcription (0 hits)
        // r2 has no title match + transcription (2 hits)
        // r1 should rank higher due to title bonus
        #expect(results.count == 2)
        #expect(results[0].recording.title == "产品路线图讨论")
    }

    @Test func searchRecordings_summaryBonus() async throws {
        let container = try await TestModelContainer.create()
        let service = KnowledgeBaseSearchService()
        let r = makeRecording(title: "会议", transcription: "内容", summary: "讨论了产品路线图", container: container)

        let results = service.searchRecordings(query: "产品路线图", in: [r])
        #expect(results.count == 1)
        #expect(results[0].score >= 3) // summary bonus
    }

    @Test func searchRecordings_emptyQueryReturnsFallback() async throws {
        let container = try await TestModelContainer.create()
        let service = KnowledgeBaseSearchService()
        let r1 = makeRecording(title: "录音1", transcription: "内容1", date: Date(timeIntervalSince1970: 1000), container: container)
        let r2 = makeRecording(title: "录音2", transcription: "内容2", date: Date(timeIntervalSince1970: 2000), container: container)

        let results = service.searchRecordings(query: "", in: [r1, r2])
        // Fallback returns sorted by date desc
        #expect(results.count == 2)
        #expect(results[0].recording.title == "录音2")
    }

    @Test func searchRecordings_filtersStopWords() async throws {
        let container = try await TestModelContainer.create()
        let service = KnowledgeBaseSearchService()
        let r = makeRecording(title: "测试", transcription: "的了在是", container: container)

        // Query with only stop words should trigger fallback
        let results = service.searchRecordings(query: "的 了", in: [r])
        #expect(results.first?.score == 0) // fallback results have score 0
    }

    @Test func searchRecordings_filtersSingleCharTokens() async throws {
        let container = try await TestModelContainer.create()
        let service = KnowledgeBaseSearchService()
        let r = makeRecording(title: "测试", transcription: "一些内容", container: container)

        // Single char query should be filtered
        let results = service.searchRecordings(query: "a b", in: [r])
        #expect(results.first?.score == 0) // fallback
    }

    @Test func searchRecordings_maxFiveResults() async throws {
        let container = try await TestModelContainer.create()
        let service = KnowledgeBaseSearchService()
        var recordings: [Recording] = []
        for i in 0..<10 {
            recordings.append(makeRecording(title: "录音\(i)", transcription: "关键词 内容\(i)", container: container))
        }

        let results = service.searchRecordings(query: "关键词", in: recordings)
        #expect(results.count <= 5)
    }

    @Test func buildContext_containsTitles() async throws {
        let container = try await TestModelContainer.create()
        let r = makeRecording(title: "项目会议", transcription: "内容", container: container)
        let service = KnowledgeBaseSearchService()
        let searchResult = SearchResult(id: r.id, recording: r, score: 1.0, excerpts: ["一些摘录内容"])
        let context = service.buildContext(from: [searchResult])
        #expect(context.contains("【项目会议】"))
    }
}
