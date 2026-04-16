import ActivityKit
import Foundation

// NOTE: This is the widget-extension-local copy of the attributes type.
// The main iOS app target uses the copy at Shared/Models/RecordingActivityAttributes.swift.
// Both files MUST stay in sync (same type name, same Codable shape) because
// ActivityKit matches activities across processes by attribute type name + shape.
struct RecordingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var isPaused: Bool
        var timerStartDate: Date
        var frozenElapsed: TimeInterval
        var recordingTitle: String
        var source: RecordingSource

        public enum RecordingSource: String, Codable, Hashable {
            case phone
            case watch
        }
    }

    // Stable identifier for the active recording session, used by Live Activity
    // buttons to route pending marker / pending photo intents back to the right
    // recording once the app resumes.
    var recordingId: String
}
