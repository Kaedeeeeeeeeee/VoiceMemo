import SwiftUI
import SwiftData

@main
struct VoiceMemoiOSApp: App {
    @State private var connectivity = PhoneConnectivityService()
    @StateObject private var languageManager = LanguageManager()
    let modelContainer: ModelContainer

    init() {
        // Initialize subscription listener early
        _ = SubscriptionManager.shared
        _ = TrialManager.shared

        let container = try! ModelContainer(for: Recording.self, ChatConversation.self, PersistedChatMessage.self)
        self.modelContainer = container

        let context = container.mainContext
        _connectivity = State(wrappedValue: {
            let service = PhoneConnectivityService()
            service.onRecordingReceived = { url, metadata in
                let title = metadata["title"] as? String ?? url.deletingPathExtension().lastPathComponent
                let duration = metadata["duration"] as? TimeInterval ?? 0
                let fileSize = metadata["fileSize"] as? Int64 ?? 0

                var date = Date.now
                if let dateInterval = metadata["date"] as? TimeInterval {
                    date = Date(timeIntervalSince1970: dateInterval)
                }

                let recording = Recording(
                    title: title,
                    date: date,
                    duration: duration,
                    fileURL: url.lastPathComponent,
                    fileSize: fileSize,
                    source: .watch
                )
                context.insert(recording)
                try? context.save()
                print("✅ Received recording from Watch: \(title)")
            }
            return service
        }())
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(connectivity)
                .environmentObject(languageManager)
                .environment(\.locale, languageManager.locale ?? .current)
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }
}
