import Testing
import SwiftData
import Foundation
@testable import VoiceMemo_iOS

@Suite("Marker Export Tests")
struct MarkerExportTests {

    private func makeRecordingWithMarkers(container: ModelContainer) -> Recording {
        let context = ModelContext(container)
        let r = Recording(title: "测试录音", fileURL: "test.m4a")
        r.duration = 300
        r.transcription = "这是转写内容"
        r.summary = "## 摘要\n这是摘要内容"
        context.insert(r)

        let m1 = RecordingMarker(timestamp: 65, text: "重要标记")
        m1.recording = r
        r.markers.append(m1)
        context.insert(m1)

        let m2 = RecordingMarker(timestamp: 180, text: "第二个标记")
        m2.recording = r
        r.markers.append(m2)
        context.insert(m2)

        return r
    }

    // MARK: - RecordingMarker.photoURL / photoData

    @Test func photoURL_nilWhenNoFileName() async throws {
        let container = try await TestModelContainer.create()
        let context = ModelContext(container)
        let marker = RecordingMarker(timestamp: 0, text: "test")
        context.insert(marker)
        #expect(marker.photoURL == nil)
        #expect(marker.photoData == nil)
    }

    @Test func photoURL_constructsPathFromFileName() async throws {
        let container = try await TestModelContainer.create()
        let context = ModelContext(container)
        let marker = RecordingMarker(timestamp: 0, text: "test", photoFileName: "marker_abc.jpg")
        context.insert(marker)
        #expect(marker.photoURL != nil)
        #expect(marker.photoURL!.lastPathComponent == "marker_abc.jpg")
    }

    // MARK: - Recording.markersSection

    @Test func markersSection_emptyWhenNoMarkers() async throws {
        let container = try await TestModelContainer.create()
        let context = ModelContext(container)
        let r = Recording(title: "Test", fileURL: "t.m4a")
        context.insert(r)
        #expect(r.markersSection(markdown: true) == "")
        #expect(r.markersSection(markdown: false) == "")
    }

    @Test func markersSection_markdownFormat() async throws {
        let container = try await TestModelContainer.create()
        let r = makeRecordingWithMarkers(container: container)
        let section = r.markersSection(markdown: true)
        #expect(section.contains("## 标记"))
        #expect(section.contains("- **[01:05]** 重要标记"))
        #expect(section.contains("- **[03:00]** 第二个标记"))
    }

    @Test func markersSection_plainTextFormat() async throws {
        let container = try await TestModelContainer.create()
        let r = makeRecordingWithMarkers(container: container)
        let section = r.markersSection(markdown: false)
        #expect(section.contains("标记"))
        #expect(!section.contains("## "))
        #expect(section.contains("[01:05] 重要标记"))
        #expect(section.contains("[03:00] 第二个标记"))
    }

    @Test func markersSection_sortedByTimestamp() async throws {
        let container = try await TestModelContainer.create()
        let context = ModelContext(container)
        let r = Recording(title: "Test", fileURL: "t.m4a")
        context.insert(r)

        // Insert in reverse order
        let m2 = RecordingMarker(timestamp: 120, text: "后面的")
        m2.recording = r
        r.markers.append(m2)
        context.insert(m2)

        let m1 = RecordingMarker(timestamp: 30, text: "前面的")
        m1.recording = r
        r.markers.append(m1)
        context.insert(m1)

        let section = r.markersSection(markdown: false)
        let lines = section.components(separatedBy: "\n").filter { !$0.isEmpty }
        // "标记" header first, then sorted markers
        #expect(lines[0] == "标记")
        #expect(lines[1].contains("00:30"))
        #expect(lines[2].contains("02:00"))
    }

    // MARK: - ExportService with markers

    @Test func exportMarkdown_includesMarkers() async throws {
        let container = try await TestModelContainer.create()
        let r = makeRecordingWithMarkers(container: container)
        let url = ExportService.exportMarkdown(recording: r, contentType: .transcription)
        defer { if let url { try? FileManager.default.removeItem(at: url) } }
        let content = try String(contentsOf: url!, encoding: .utf8)
        #expect(content.contains("## 标记"))
        #expect(content.contains("01:05"))
        #expect(content.contains("重要标记"))
    }

    @Test func exportMarkdown_noMarkersSectionWhenEmpty() async throws {
        let container = try await TestModelContainer.create()
        let context = ModelContext(container)
        let r = Recording(title: "Test", fileURL: "t.m4a")
        r.transcription = "内容"
        context.insert(r)
        let url = ExportService.exportMarkdown(recording: r, contentType: .transcription)
        defer { if let url { try? FileManager.default.removeItem(at: url) } }
        let content = try String(contentsOf: url!, encoding: .utf8)
        #expect(!content.contains("## 标记"))
    }

    @Test func exportPlainText_includesMarkers() async throws {
        let container = try await TestModelContainer.create()
        let r = makeRecordingWithMarkers(container: container)
        let url = ExportService.exportPlainText(recording: r, contentType: .transcription)
        defer { if let url { try? FileManager.default.removeItem(at: url) } }
        let content = try String(contentsOf: url!, encoding: .utf8)
        #expect(content.contains("[01:05] 重要标记"))
        #expect(content.contains("[03:00] 第二个标记"))
        // Plain text should not have markdown formatting
        #expect(!content.contains("**"))
    }

    @Test func exportMarkdown_summaryAlsoIncludesMarkers() async throws {
        let container = try await TestModelContainer.create()
        let r = makeRecordingWithMarkers(container: container)
        let url = ExportService.exportMarkdown(recording: r, contentType: .summary)
        defer { if let url { try? FileManager.default.removeItem(at: url) } }
        let content = try String(contentsOf: url!, encoding: .utf8)
        #expect(content.contains("## 摘要"))
        #expect(content.contains("## 标记"))
        #expect(content.contains("重要标记"))
    }

    @Test func exportMarkdown_bothContentIncludesMarkers() async throws {
        let container = try await TestModelContainer.create()
        let r = makeRecordingWithMarkers(container: container)
        let url = ExportService.exportMarkdown(recording: r, contentType: .both)
        defer { if let url { try? FileManager.default.removeItem(at: url) } }
        let content = try String(contentsOf: url!, encoding: .utf8)
        #expect(content.contains("## 转写"))
        #expect(content.contains("## 摘要"))
        #expect(content.contains("## 标记"))
    }

    // MARK: - PDFRenderer with markers

    @Test func pdfRenderer_producesFileWithMarkers() async throws {
        let container = try await TestModelContainer.create()
        let r = makeRecordingWithMarkers(container: container)
        let url = PDFRenderer.render(
            title: r.title,
            content: r.transcription!,
            type: "转写",
            markers: r.sortedMarkers
        )
        defer { if let url { try? FileManager.default.removeItem(at: url) } }
        #expect(url != nil)
        let data = try Data(contentsOf: url!)
        #expect(data.count > 0)
    }

    @Test func pdfRenderer_producesFileWithoutMarkers() async throws {
        let url = PDFRenderer.render(title: "Test", content: "Content", type: "转写")
        defer { if let url { try? FileManager.default.removeItem(at: url) } }
        #expect(url != nil)
    }
}
