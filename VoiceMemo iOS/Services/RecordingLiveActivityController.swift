#if canImport(ActivityKit)
import ActivityKit
import Foundation

/// Central owner of the recording Live Activity. Both the iPhone-local
/// recorder (`iOSAudioRecorder`) and the Watch remote-control path
/// (`PhoneConnectivityService` receiving messages from the Watch) route
/// through this controller, so there is always at most one activity and
/// it's shaped consistently regardless of source.
@MainActor
final class RecordingLiveActivityController {
    static let shared = RecordingLiveActivityController()

    private var currentActivity: Activity<RecordingActivityAttributes>?
    private var currentRecordingId: String?
    private var currentSource: RecordingActivityAttributes.ContentState.RecordingSource = .phone
    private(set) var currentTimerStartDate: Date?

    private init() {}

    // Latest attributes the activity was started with. Intents resumed
    // from the lock screen read this to know which recording to attach
    // pending markers/photos to.
    var activeRecordingId: String? { currentRecordingId }
    var activeSource: RecordingActivityAttributes.ContentState.RecordingSource { currentSource }

    func start(
        recordingId: String,
        title: String,
        source: RecordingActivityAttributes.ContentState.RecordingSource,
        timerStartDate: Date = .now
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            #if DEBUG
            print("ℹ️ Live Activities disabled by user — skipping start")
            #endif
            return
        }

        // If an activity is already running (e.g. stale from last session),
        // end it before starting a new one.
        if currentActivity != nil {
            end(frozenElapsed: 0)
        }

        let attributes = RecordingActivityAttributes(recordingId: recordingId)
        let state = RecordingActivityAttributes.ContentState(
            isPaused: false,
            timerStartDate: timerStartDate,
            frozenElapsed: 0,
            recordingTitle: title,
            source: source
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
            currentRecordingId = recordingId
            currentSource = source
            currentTimerStartDate = timerStartDate
        } catch {
            #if DEBUG
            print("❌ Failed to start Live Activity: \(error)")
            #endif
        }
    }

    func update(isPaused: Bool, accumulatedElapsed: TimeInterval) {
        guard let activity = currentActivity, let recordingId = currentRecordingId else { return }
        let title = activity.content.state.recordingTitle
        let source = activity.content.state.source

        let state: RecordingActivityAttributes.ContentState
        if isPaused {
            state = .init(
                isPaused: true,
                timerStartDate: .now,
                frozenElapsed: accumulatedElapsed,
                recordingTitle: title,
                source: source
            )
            currentTimerStartDate = nil
        } else {
            let resumedStart = Date.now.addingTimeInterval(-accumulatedElapsed)
            state = .init(
                isPaused: false,
                timerStartDate: resumedStart,
                frozenElapsed: 0,
                recordingTitle: title,
                source: source
            )
            currentTimerStartDate = resumedStart
        }

        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
        _ = recordingId
    }

    func end(frozenElapsed: TimeInterval) {
        guard let activity = currentActivity else { return }
        let title = activity.content.state.recordingTitle
        let source = activity.content.state.source

        let finalState = RecordingActivityAttributes.ContentState(
            isPaused: true,
            timerStartDate: .now,
            frozenElapsed: frozenElapsed,
            recordingTitle: title,
            source: source
        )

        Task {
            await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
        }

        currentActivity = nil
        currentRecordingId = nil
        currentTimerStartDate = nil
        currentSource = .phone
    }

    /// Returns the elapsed seconds from when the current active recording
    /// started. Used by AppIntents fired from the Live Activity to compute
    /// the timestamp of a marker/photo action.
    func currentElapsed() -> TimeInterval? {
        guard let activity = currentActivity else { return nil }
        let state = activity.content.state
        if state.isPaused {
            return state.frozenElapsed
        }
        return Date.now.timeIntervalSince(state.timerStartDate)
    }
}
#endif
