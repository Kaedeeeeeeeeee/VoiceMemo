import Testing
import SwiftData
import Foundation
@testable import VoiceMemo_iOS

@Suite("ExportService Tests")
struct ExportServiceTests {

    private func makeRecording(
        title: String = "测试录音",
        transcription: String? = "这是转写内容",
        summary: String? = "## 摘要\n这是摘要内容",
        container: ModelContainer
    ) -> Recording {
        let context = ModelContext(container)
        let r = Recording(title: title, fileURL: "test.m4a")
        r.duration = 125
        r.transcription = transcription
        r.summary = summary
        context.insert(r)
        return r
    }

    // MARK: - Markdown

    @Test func exportMarkdown_hasCorrectExtension() async throws {
        let container = try await TestModelContainer.create()
        let r = makeRecording(container: container)
        let url = ExportService.exportMarkdown(recording: r, contentType: .transcription)
        defer { if let url { try? FileManager.default.removeItem(at: url) } }
        #expect(url?.pathExtension == "md")
    }

    @Test func exportMarkdown_containsFrontMatter() async throws {
        let container = try await TestModelContainer.create()
        let r = makeRecording(container: container)
        let url = ExportService.exportMarkdown(recording: r, contentType: .transcription)
        defer { if let url { try? FileManager.default.removeItem(at: url) } }
        let content = try String(contentsOf: url!, encoding: .utf8)
        #expect(content.hasPrefix("---"))
        #expect(content.contains("title:"))
        #expect(content.contains("duration:"))
    }

    @Test func exportMarkdown_transcriptionContent() async throws {
        let container = try await TestModelContainer.create()
        let r = makeRecording(container: container)
        let url = ExportService.exportMarkdown(recording: r, contentType: .transcription)
        defer { if let url { try? FileManager.default.removeItem(at: url) } }
        let content = try String(contentsOf: url!, encoding: .utf8)
        #expect(content.contains("## 转写"))
        #expect(content.contains("这是转写内容"))
    }

    @Test func exportMarkdown_summaryContent() async throws {
        let container = try await TestModelContainer.create()
        let r = makeRecording(container: container)
        let url = ExportService.exportMarkdown(recording: r, contentType: .summary)
        defer { if let url { try? FileManager.default.removeItem(at: url) } }
        let content = try String(contentsOf: url!, encoding: .utf8)
        #expect(content.contains("## 摘要"))
    }

    @Test func exportMarkdown_bothContent() async throws {
        let container = try await TestModelContainer.create()
        let r = makeRecording(container: container)
        let url = ExportService.exportMarkdown(recording: r, contentType: .both)
        defer { if let url { try? FileManager.default.removeItem(at: url) } }
        let content = try String(contentsOf: url!, encoding: .utf8)
        #expect(content.contains("## 转写"))
        #expect(content.contains("## 摘要"))
    }

    // MARK: - Plain Text

    @Test func exportPlainText_hasCorrectExtension() async throws {
        let container = try await TestModelContainer.create()
        let r = makeRecording(container: container)
        let url = ExportService.exportPlainText(recording: r, contentType: .transcription)
        defer { if let url { try? FileManager.default.removeItem(at: url) } }
        #expect(url?.pathExtension == "txt")
    }

    @Test func exportPlainText_containsTitleAndDuration() async throws {
        let container = try await TestModelContainer.create()
        let r = makeRecording(container: container)
        let url = ExportService.exportPlainText(recording: r, contentType: .transcription)
        defer { if let url { try? FileManager.default.removeItem(at: url) } }
        let content = try String(contentsOf: url!, encoding: .utf8)
        #expect(content.contains("测试录音"))
        #expect(content.contains("2:05"))
    }

    @Test func exportPlainText_noMarkdownHeaders() async throws {
        let container = try await TestModelContainer.create()
        let r = makeRecording(container: container)
        let url = ExportService.exportPlainText(recording: r, contentType: .summary)
        defer { if let url { try? FileManager.default.removeItem(at: url) } }
        let content = try String(contentsOf: url!, encoding: .utf8)
        #expect(!content.contains("## "))
    }
}
