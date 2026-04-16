import Testing
import SwiftData
@testable import VoiceMemo_iOS

@Suite("Recording Model Tests")
struct RecordingTests {

    // MARK: - formattedDuration

    @Test func formattedDuration_zero() async throws {
        let container = try await TestModelContainer.create()
        let context = ModelContext(container)
        let r = Recording(title: "Test", fileURL: "t.m4a")
        r.duration = 0
        context.insert(r)
        #expect(r.formattedDuration == "0:00")
    }

    @Test func formattedDuration_oneMinuteFiveSeconds() async throws {
        let container = try await TestModelContainer.create()
        let context = ModelContext(container)
        let r = Recording(title: "Test", fileURL: "t.m4a")
        r.duration = 65
        context.insert(r)
        #expect(r.formattedDuration == "1:05")
    }

    @Test func formattedDuration_oneHour() async throws {
        let container = try await TestModelContainer.create()
        let context = ModelContext(container)
        let r = Recording(title: "Test", fileURL: "t.m4a")
        r.duration = 3600
        context.insert(r)
        #expect(r.formattedDuration == "60:00")
    }

    @Test func formattedDuration_fiveSeconds() async throws {
        let container = try await TestModelContainer.create()
        let context = ModelContext(container)
        let r = Recording(title: "Test", fileURL: "t.m4a")
        r.duration = 5
        context.insert(r)
        #expect(r.formattedDuration == "0:05")
    }

    // MARK: - formattedFileSize

    @Test func formattedFileSize_zero() async throws {
        let container = try await TestModelContainer.create()
        let context = ModelContext(container)
        let r = Recording(title: "Test", fileURL: "t.m4a")
        r.fileSize = 0
        context.insert(r)
        #expect(r.formattedFileSize == "Zero KB")
    }

    @Test func formattedFileSize_oneMB() async throws {
        let container = try await TestModelContainer.create()
        let context = ModelContext(container)
        let r = Recording(title: "Test", fileURL: "t.m4a")
        r.fileSize = 1_048_576
        context.insert(r)
        #expect(r.formattedFileSize.contains("MB"))
    }

    // MARK: - extractSpeakers

    @Test func extractSpeakers_normalCase() {
        let text = "【说话人1】你好 【说话人2】世界"
        let speakers = Recording.extractSpeakers(from: text)
        #expect(speakers == ["说话人1", "说话人2"])
    }

    @Test func extractSpeakers_deduplicatesPreservingOrder() {
        let text = "【说话人2】A 【说话人1】B 【说话人2】C"
        let speakers = Recording.extractSpeakers(from: text)
        #expect(speakers == ["说话人2", "说话人1"])
    }

    @Test func extractSpeakers_emptyString() {
        let speakers = Recording.extractSpeakers(from: "")
        #expect(speakers.isEmpty)
    }

    @Test func extractSpeakers_noTags() {
        let speakers = Recording.extractSpeakers(from: "这里没有说话人标签")
        #expect(speakers.isEmpty)
    }

    // MARK: - applyingSpeakerNames

    @Test func applyingSpeakerNames_replaces() async throws {
        let container = try await TestModelContainer.create()
        let context = ModelContext(container)
        let r = Recording(title: "Test", fileURL: "t.m4a")
        context.insert(r)
        r.speakerNames = ["说话人1": "Alice"]
        let result = r.applyingSpeakerNames(to: "【说话人1】你好")
        #expect(result == "【Alice】你好")
    }

    @Test func applyingSpeakerNames_skipsEmptyName() async throws {
        let container = try await TestModelContainer.create()
        let context = ModelContext(container)
        let r = Recording(title: "Test", fileURL: "t.m4a")
        context.insert(r)
        r.speakerNames = ["说话人1": ""]
        let result = r.applyingSpeakerNames(to: "【说话人1】你好")
        #expect(result == "【说话人1】你好")
    }

    @Test func applyingSpeakerNames_noMatch() async throws {
        let container = try await TestModelContainer.create()
        let context = ModelContext(container)
        let r = Recording(title: "Test", fileURL: "t.m4a")
        context.insert(r)
        r.speakerNames = ["说话人3": "Bob"]
        let result = r.applyingSpeakerNames(to: "【说话人1】你好")
        #expect(result == "【说话人1】你好")
    }

    // MARK: - speakerUtterances round-trip

    @Test func speakerUtterances_roundTrip() async throws {
        let container = try await TestModelContainer.create()
        let context = ModelContext(container)
        let r = Recording(title: "Test", fileURL: "t.m4a")
        context.insert(r)

        let utterances = [
            SpeakerUtterance(speaker: "A", text: "Hello", startMs: 0, endMs: 1000),
            SpeakerUtterance(speaker: "B", text: "World", startMs: 1000, endMs: 2000),
        ]
        r.setSpeakerUtterances(utterances)

        let decoded = r.speakerUtterances
        #expect(decoded != nil)
        #expect(decoded?.count == 2)
        #expect(decoded?[0].speaker == "A")
        #expect(decoded?[0].text == "Hello")
        #expect(decoded?[1].startMs == 1000)
    }

    @Test func speakerUtterances_nilWhenNoJSON() async throws {
        let container = try await TestModelContainer.create()
        let context = ModelContext(container)
        let r = Recording(title: "Test", fileURL: "t.m4a")
        context.insert(r)
        #expect(r.speakerUtterances == nil)
    }

    // MARK: - segmentsForSpeaker

    @Test func segmentsForSpeaker_filtersAndConverts() async throws {
        let container = try await TestModelContainer.create()
        let context = ModelContext(container)
        let r = Recording(title: "Test", fileURL: "t.m4a")
        context.insert(r)

        let utterances = [
            SpeakerUtterance(speaker: "A", text: "Hello", startMs: 0, endMs: 1000),
            SpeakerUtterance(speaker: "B", text: "Hi", startMs: 1000, endMs: 2000),
            SpeakerUtterance(speaker: "A", text: "Bye", startMs: 3000, endMs: 4500),
        ]
        r.setSpeakerUtterances(utterances)

        let segments = r.segmentsForSpeaker("A")
        #expect(segments.count == 2)
        #expect(segments[0].startTime == 0.0)
        #expect(segments[0].endTime == 1.0)
        #expect(segments[1].startTime == 3.0)
        #expect(segments[1].endTime == 4.5)
    }

    @Test func segmentsForSpeaker_noMatch() async throws {
        let container = try await TestModelContainer.create()
        let context = ModelContext(container)
        let r = Recording(title: "Test", fileURL: "t.m4a")
        context.insert(r)
        r.setSpeakerUtterances([
            SpeakerUtterance(speaker: "A", text: "Hello", startMs: 0, endMs: 1000),
        ])
        let segments = r.segmentsForSpeaker("Z")
        #expect(segments.isEmpty)
    }
}
