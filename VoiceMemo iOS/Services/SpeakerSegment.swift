import Foundation

/// Raw utterance data from AssemblyAI, before formatting
struct SpeakerUtterance: Codable {
    let speaker: String      // "A", "B", "C"
    let text: String
    let startMs: Int
    let endMs: Int
}

/// Time range for a speaker's audio segment
struct SpeakerSegment {
    let startTime: Double    // seconds
    let endTime: Double      // seconds

    var duration: Double { endTime - startTime }
}

/// Result from transcription that includes both formatted text and raw utterance data
struct TranscriptionResult {
    let formattedText: String
    let utterances: [SpeakerUtterance]
}
