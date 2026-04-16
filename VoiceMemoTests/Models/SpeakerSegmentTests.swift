import Testing
import Foundation
@testable import VoiceMemo_iOS

@Suite("SpeakerSegment Tests")
struct SpeakerSegmentTests {

    @Test func duration_normal() {
        let segment = SpeakerSegment(startTime: 1.0, endTime: 3.5)
        #expect(segment.duration == 2.5)
    }

    @Test func duration_zeroLength() {
        let segment = SpeakerSegment(startTime: 5.0, endTime: 5.0)
        #expect(segment.duration == 0.0)
    }

    @Test func speakerUtterance_codableRoundTrip() throws {
        let utterance = SpeakerUtterance(speaker: "A", text: "Hello world", startMs: 100, endMs: 2500)
        let data = try JSONEncoder().encode(utterance)
        let decoded = try JSONDecoder().decode(SpeakerUtterance.self, from: data)
        #expect(decoded.speaker == "A")
        #expect(decoded.text == "Hello world")
        #expect(decoded.startMs == 100)
        #expect(decoded.endMs == 2500)
    }

    @Test func speakerUtterance_decodesFromJSON() throws {
        let json = """
        {"speaker":"B","text":"你好","startMs":0,"endMs":1000}
        """
        let decoded = try JSONDecoder().decode(SpeakerUtterance.self, from: Data(json.utf8))
        #expect(decoded.speaker == "B")
        #expect(decoded.text == "你好")
    }
}
