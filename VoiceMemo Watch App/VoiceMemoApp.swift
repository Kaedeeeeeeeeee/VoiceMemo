import SwiftUI
import SwiftData
import AVFoundation

@main
struct VoiceMemoWatchApp: App {
    @State private var shouldStartRecording = false

    init() {
        // Pre-warm WCSession so it's ready when RecordingView needs it
        _ = WatchConnectivityService.shared

        // Pre-warm BackgroundRecordingManager for call recording
        _ = BackgroundRecordingManager.shared

        // Pre-warm AVAudioSession to avoid slow first-use delay
        Task.detached(priority: .utility) {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.record, mode: .default)
        }
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView(shouldStartRecording: $shouldStartRecording)
            }
            .onOpenURL { url in
                if url.scheme == "voicememo" && url.host == "record" {
                    shouldStartRecording = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .callRecordingCompleted)) { notification in
                handleCallRecordingCompleted(notification)
            }
        }
        .modelContainer(for: Recording.self)
    }

    @MainActor
    private func handleCallRecordingCompleted(_ notification: Notification) {
        guard let url = notification.userInfo?["url"] as? URL,
              let duration = notification.userInfo?["duration"] as? TimeInterval,
              let fileSize = notification.userInfo?["fileSize"] as? Int64 else { return }

        let title = "通话录音 \(Date.now.recordingTitle)"
        let recording = Recording(
            title: title,
            duration: duration,
            fileURL: url.lastPathComponent,
            fileSize: fileSize,
            source: .watch
        )

        // Insert into SwiftData via shared model container
        guard let container = try? ModelContainer(for: Recording.self) else { return }
        let context = container.mainContext
        context.insert(recording)
        try? context.save()

        #if DEBUG
        print("📞 [Watch] Saved call recording: \(title)")
        #endif
    }
}
