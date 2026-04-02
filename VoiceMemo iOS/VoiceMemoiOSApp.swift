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

        let container = try! ModelContainer(for: Recording.self, RecordingMarker.self, ChatConversation.self, PersistedChatMessage.self, CustomSummaryTemplate.self, SpeakerProfile.self, EmbeddingChunk.self)
        self.modelContainer = container

        let context = container.mainContext
        _connectivity = State(wrappedValue: {
            let service = PhoneConnectivityService()
            service.onRecordingReceived = { url, metadata in
                let title = metadata["title"] as? String ?? url.deletingPathExtension().lastPathComponent
                let duration = metadata["duration"] as? TimeInterval ?? 0
                let fileSize = metadata["fileSize"] as? Int64 ?? 0
                let isCallRecording = metadata["isCallRecording"] as? Bool ?? false

                var date = Date.now
                if let dateInterval = metadata["date"] as? TimeInterval {
                    date = Date(timeIntervalSince1970: dateInterval)
                }

                let source: RecordingSource = isCallRecording ? .phoneCall : .watch

                let recording = Recording(
                    title: title,
                    date: date,
                    duration: duration,
                    fileURL: url.lastPathComponent,
                    fileSize: fileSize,
                    source: source
                )
                recording.isSynced = true
                context.insert(recording)
                do {
                    try context.save()
                    #if DEBUG
                    print("✅ Received recording from Watch: \(title) (call: \(isCallRecording))")
                    #endif

                    // Auto-transcribe Watch recording
                    AutoTranscriptionManager.shared.startTranscription(for: recording)
                } catch {
                    #if DEBUG
                    print("❌ Failed to save received recording: \(error)")
                    #endif
                }
            }

            // Configure CallObserverService with connectivity
            CallObserverService.shared.configure(connectivity: service)

            return service
        }())
    }

    @State private var deepLinkRecord = false

    var body: some Scene {
        WindowGroup {
            MainTabView(triggerRecord: $deepLinkRecord)
                .environment(connectivity)
                .environmentObject(languageManager)
                .environment(\.locale, languageManager.locale ?? .current)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    if url.scheme == "voicememo" && url.host == "record" {
                        deepLinkRecord = true
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}
