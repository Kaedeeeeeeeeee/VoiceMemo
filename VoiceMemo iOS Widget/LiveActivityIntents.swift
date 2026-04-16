import AppIntents
import Foundation

/// Tapped when the user wants to add a named marker at the current
/// recording timestamp. We cannot show a text field on the lock screen,
/// so `openAppWhenRun = true` makes iOS prompt for Face ID / Touch ID and
/// then launch the main app. The app drains the pending action queue on
/// `scenePhase == .active` and presents `AddMarkerSheet`.
struct AddMarkerLiveActivityIntent: AppIntent {
    static let title: LocalizedStringResource = "添加标记"
    static let description = IntentDescription("在当前录音位置添加带文字的标记。")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "录音 ID")
    var recordingId: String

    @Parameter(title: "时间戳")
    var timestamp: Double

    init() {}

    init(recordingId: String, timestamp: Double) {
        self.recordingId = recordingId
        self.timestamp = timestamp
    }

    func perform() async throws -> some IntentResult {
        let action = PendingLiveActivityAction(
            kind: .addMarker,
            recordingId: recordingId,
            timestamp: timestamp
        )
        PendingActionStore.enqueueAction(action)
        return .result()
    }
}

/// Tapped when the user wants to take a photo for the current recording.
/// Same pattern as above — enqueue the action, let iOS unlock the device,
/// the main app picks it up and opens the camera.
struct TakePhotoLiveActivityIntent: AppIntent {
    static let title: LocalizedStringResource = "拍照"
    static let description = IntentDescription("为当前录音拍一张标记照片。")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "录音 ID")
    var recordingId: String

    @Parameter(title: "时间戳")
    var timestamp: Double

    init() {}

    init(recordingId: String, timestamp: Double) {
        self.recordingId = recordingId
        self.timestamp = timestamp
    }

    func perform() async throws -> some IntentResult {
        let action = PendingLiveActivityAction(
            kind: .takePhoto,
            recordingId: recordingId,
            timestamp: timestamp
        )
        PendingActionStore.enqueueAction(action)
        return .result()
    }
}
