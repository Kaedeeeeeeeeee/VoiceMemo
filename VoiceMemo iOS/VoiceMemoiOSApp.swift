import SwiftUI
import SwiftData

@main
struct VoiceMemoiOSApp: App {
    @State private var connectivity = PhoneConnectivityService()
    @State private var languageManager = LanguageManager()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(connectivity)
                .environment(languageManager)
                .environment(\.locale, languageManager.locale ?? .current)
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: Recording.self)
    }
}
