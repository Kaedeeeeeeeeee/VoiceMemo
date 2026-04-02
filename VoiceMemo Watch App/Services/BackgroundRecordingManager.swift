import Foundation
import Observation

extension Notification.Name {
    static let callRecordingCompleted = Notification.Name("callRecordingCompleted")
}

@Observable
final class BackgroundRecordingManager {
    static let shared = BackgroundRecordingManager()

    var isCallRecording = false
    private let recorder = WatchAudioRecorder()

    func startCallRecording() {
        // Don't interrupt a manual recording
        guard !recorder.isRecording else {
            #if DEBUG
            print("⏺️ [Watch] Already recording, skipping call recording")
            #endif
            return
        }

        #if DEBUG
        print("📞 [Watch] Starting call recording")
        #endif

        let url = recorder.startRecording()
        if url != nil {
            isCallRecording = true
        }
    }

    func stopCallRecording() {
        guard isCallRecording else { return }

        #if DEBUG
        print("📞 [Watch] Stopping call recording")
        #endif

        isCallRecording = false

        guard let result = recorder.stopRecording() else {
            #if DEBUG
            print("⚠️ [Watch] No recording result from stopRecording")
            #endif
            return
        }

        // Send to iPhone
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: result.url.path))?[.size] as? Int64 ?? 0
        let metadata: [String: Any] = [
            "title": "通话录音 \(Date.now.recordingTitle)",
            "duration": result.duration,
            "date": Date.now.timeIntervalSince1970,
            "fileSize": fileSize,
            "isCallRecording": true
        ]
        WatchConnectivityService.shared.sendRecording(url: result.url, metadata: metadata)

        // Notify local app to create Recording model
        NotificationCenter.default.post(
            name: .callRecordingCompleted,
            object: nil,
            userInfo: [
                "url": result.url,
                "duration": result.duration,
                "fileSize": fileSize
            ]
        )
    }
}
