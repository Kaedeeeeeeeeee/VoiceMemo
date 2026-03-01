import SwiftUI
import SwiftData

@main
struct VoiceMemoiOSApp: App {
    @State private var connectivity = PhoneConnectivityService()
    @StateObject private var languageManager = LanguageManager()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(connectivity)
                .environmentObject(languageManager)
                .environment(\.locale, languageManager.locale ?? .current)
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [Recording.self, ChatConversation.self, PersistedChatMessage.self])
    }
}
