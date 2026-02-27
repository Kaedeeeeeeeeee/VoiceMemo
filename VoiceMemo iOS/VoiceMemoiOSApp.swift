import SwiftUI
import SwiftData

@main
struct VoiceMemoiOSApp: App {
    @State private var connectivity = PhoneConnectivityService()

    var body: some Scene {
        WindowGroup {
            RecordingListView()
                .environment(connectivity)
        }
        .modelContainer(for: Recording.self)
    }
}
