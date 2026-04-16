import Testing
import SwiftData
@testable import VoiceMemo_iOS

@Suite("RecordingMarker Tests")
struct RecordingMarkerTests {

    @Test func formattedTimestamp_zero() async throws {
        let container = try await TestModelContainer.create()
        let context = ModelContext(container)
        let marker = RecordingMarker(timestamp: 0, text: "test")
        context.insert(marker)
        #expect(marker.formattedTimestamp == "00:00")
    }

    @Test func formattedTimestamp_oneMinuteFiveSeconds() async throws {
        let container = try await TestModelContainer.create()
        let context = ModelContext(container)
        let marker = RecordingMarker(timestamp: 65, text: "test")
        context.insert(marker)
        #expect(marker.formattedTimestamp == "01:05")
    }

    @Test func formattedTimestamp_largeValue() async throws {
        let container = try await TestModelContainer.create()
        let context = ModelContext(container)
        let marker = RecordingMarker(timestamp: 3661, text: "test")
        context.insert(marker)
        #expect(marker.formattedTimestamp == "61:01")
    }

    @Test func formattedTimestamp_nineMinutes() async throws {
        let container = try await TestModelContainer.create()
        let context = ModelContext(container)
        let marker = RecordingMarker(timestamp: 599, text: "test")
        context.insert(marker)
        #expect(marker.formattedTimestamp == "09:59")
    }
}
