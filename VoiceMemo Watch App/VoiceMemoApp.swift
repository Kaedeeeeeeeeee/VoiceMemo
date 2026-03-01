import SwiftUI
import SwiftData
import AVFoundation

@main
struct VoiceMemoWatchApp: App {
    @State private var shouldStartRecording = false

    init() {
        // Pre-warm WCSession so it's ready when RecordingView needs it
        _ = WatchConnectivityService.shared

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
        }
        .modelContainer(for: Recording.self)
    }
}
