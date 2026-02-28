import SwiftUI
import SwiftData

@main
struct VoiceMemoiOSApp: App {
    @State private var connectivity = PhoneConnectivityService()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(connectivity)
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: Recording.self)
    }
}
