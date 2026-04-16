import Foundation
import SwiftData
import UserNotifications

@MainActor
final class AutoTranscriptionManager {
    static let shared = AutoTranscriptionManager()

    private init() {
        requestNotificationPermission()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Starts background transcription for a recording.
    func startTranscription(for recording: Recording) {
        recording.title = String(localized: "正在转录中…")
        recording.isTranscribing = true

        let fileURL = recording.fileURL
        let recordingID = recording.id
        let defaultTitle = recording.date.recordingTitle
        guard let container = recording.modelContext?.container else { return }

        Task {
            let transcriptionService = TranscriptionService()
            let aiService = AIService()

            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let url = documentsDir.appendingPathComponent(fileURL)

            do {
                // Step 1: Transcribe (async, off-main for network)
                let result = try await transcriptionService.transcribeWithUtterances(audioURL: url)

                // Step 2: Polish (async, off-main for network)
                let polishedText = try await aiService.polishTranscription(result.formattedText)

                // Step 3: Generate title (async)
                var newTitle = defaultTitle
                if let title = try? await aiService.generateTitle(transcription: polishedText) {
                    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { newTitle = trimmed }
                }

                // Step 4: Classify tags (async)
                var tags: [String] = []
                if let classified = try? await aiService.classifyRecording(transcription: polishedText), !classified.isEmpty {
                    tags = classified
                }

                // Step 5: Speaker matching
                let speakerNames = Self.matchSpeakers(audioURL: url, utterances: result.utterances, container: container)

                // Batch update recording on the main context so the view
                // observing it sees the changes and autosave persists them.
                let context = container.mainContext
                let descriptor = FetchDescriptor<Recording>(predicate: #Predicate { $0.id == recordingID })
                if let rec = try? context.fetch(descriptor).first {
                    rec.setSpeakerUtterances(result.utterances)
                    rec.transcription = polishedText
                    rec.title = newTitle
                    if !tags.isEmpty { rec.tags = tags }
                    for (key, value) in speakerNames {
                        rec.speakerNames[key] = value
                    }
                    rec.isTranscribing = false
                    try? context.save()
                }

                // Step 6: Generate embeddings in background
                Self.generateEmbeddingsInBackground(recordingID: recordingID, transcription: polishedText, container: container)

                Self.sendNotification(
                    title: String(localized: "转录完成"),
                    body: String(localized: "「\(newTitle)」已完成转录")
                )
            } catch {
                #if DEBUG
                print("❌ Auto-transcription failed: \(error)")
                #endif
                let context = container.mainContext
                let descriptor = FetchDescriptor<Recording>(predicate: #Predicate { $0.id == recordingID })
                if let rec = try? context.fetch(descriptor).first {
                    rec.title = defaultTitle
                    rec.isTranscribing = false
                    try? context.save()
                }
            }
        }
    }

    // MARK: - Helpers

    private static func matchSpeakers(audioURL: URL, utterances: [SpeakerUtterance], container: ModelContainer) -> [String: String] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SpeakerProfile>()
        guard let profiles = try? context.fetch(descriptor), !profiles.isEmpty else { return [:] }

        let voiceprintService = VoiceprintService()
        let matches = voiceprintService.matchSpeakers(audioURL: audioURL, utterances: utterances, profiles: profiles)
        var result: [String: String] = [:]
        for (speaker, match) in matches {
            let label = LanguageManager.shared.speakerLabel(speaker)
            result[label] = match.profileName
        }
        return result
    }

    private static func generateEmbeddingsInBackground(recordingID: UUID, transcription: String, container: ModelContainer) {
        Task.detached(priority: .utility) {
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<Recording>(predicate: #Predicate { $0.id == recordingID })
            guard let recording = try? context.fetch(descriptor).first else { return }
            try? await EmbeddingService.shared.generateEmbeddings(for: recording, context: context)
        }
    }

    private static func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
