import SwiftUI
import SwiftData

@main
struct VoiceMemoWatchApp: App {
    @State private var shouldStartRecording = false

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
