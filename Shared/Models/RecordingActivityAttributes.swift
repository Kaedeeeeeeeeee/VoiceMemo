#if canImport(ActivityKit)
import ActivityKit
import Foundation

struct RecordingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var isPaused: Bool
        var timerStartDate: Date
        var frozenElapsed: TimeInterval
    }
}
#endif
