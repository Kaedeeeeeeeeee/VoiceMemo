import SwiftUI
import SwiftData

@main
struct VoiceMemoMacApp: App {
    @StateObject private var languageManager = LanguageManager()
    let modelContainer: ModelContainer

    init() {
        _ = SubscriptionManager.shared
        _ = TrialManager.shared

        let container = try! ModelContainer(for: Recording.self, ChatConversation.self, PersistedChatMessage.self)
        self.modelContainer = container
    }

    var body: some Scene {
        WindowGroup {
            MacMainView()
                .environmentObject(languageManager)
                .environment(\.locale, languageManager.locale ?? .current)
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 720)
    }
}
