import SwiftUI
import SwiftData
import AVFoundation

@main
struct VoiceMemoWatchApp: App {
    @State private var shouldStartRecording = false
    private let sharedModelContainer: ModelContainer

    init() {
        let container = try! ModelContainer(for: Recording.self, RecordingMarker.self)
        self.sharedModelContainer = container

        // Pre-warm WCSession so it's ready when RecordingView needs it, and
        // give it the shared container so file-transfer completions can mark
        // recordings as synced without relying on view-scoped model contexts.
        WatchConnectivityService.shared.modelContainer = container

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
        .modelContainer(sharedModelContainer)
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

        let context = sharedModelContainer.mainContext
        context.insert(recording)
        try? context.save()

        #if DEBUG
        print("📞 [Watch] Saved call recording: \(title)")
        #endif
    }
}
