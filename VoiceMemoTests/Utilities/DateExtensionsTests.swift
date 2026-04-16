import Testing
import Foundation
@testable import VoiceMemo_iOS

@Suite("Date Extensions Tests")
struct DateExtensionsTests {

    @Test func recordingTitle_containsYear() {
        let date = Date(timeIntervalSince1970: 1700000000) // 2023-11-14
        let title = date.recordingTitle
        #expect(title.contains("2023"))
    }

    @Test func recordingTitle_format() {
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 2
        components.hour = 15
        components.minute = 30
        let date = calendar.date(from: components)!
        let title = date.recordingTitle
        #expect(title.contains("2026-04-02"))
        #expect(title.contains("15:30"))
    }

    @Test func shortDisplay_isNotEmpty() {
        let display = Date.now.shortDisplay
        #expect(!display.isEmpty)
    }
}
