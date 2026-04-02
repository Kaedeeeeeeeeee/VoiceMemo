import Foundation
import SwiftData
import UserNotifications

@MainActor
final class AutoTranscriptionManager {
    static let shared = AutoTranscriptionManager()

    private let transcriptionService = TranscriptionService()
    private let aiService = AIService()
    private let voiceprintService = VoiceprintService()

    private init() {
        requestNotificationPermission()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Starts background transcription for a recording. Sets title to "正在转录中…" and isTranscribing = true.
    func startTranscription(for recording: Recording) {
        recording.title = String(localized: "正在转录中…")
        recording.isTranscribing = true

        let fileURL = recording.fileURL

        Task {
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let url = documentsDir.appendingPathComponent(fileURL)

            do {
                let result = try await transcriptionService.transcribeWithUtterances(audioURL: url)
                recording.setSpeakerUtterances(result.utterances)

                let polishedText = try await aiService.polishTranscription(result.formattedText)
                recording.transcription = polishedText

                // Auto-match speakers against saved voiceprints
                autoMatchSpeakers(recording: recording, audioURL: url, utterances: result.utterances)

                // Auto-generate title
                if let title = try? await aiService.generateTitle(transcription: polishedText) {
                    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        recording.title = trimmed
                    } else {
                        recording.title = Date.now.recordingTitle
                    }
                } else {
                    recording.title = Date.now.recordingTitle
                }

                // Auto-classify recording with tags
                if recording.tags.isEmpty {
                    if let tags = try? await aiService.classifyRecording(transcription: polishedText), !tags.isEmpty {
                        recording.tags = tags
                    }
                }

                // Generate embeddings for knowledge base search
                if let container = recording.modelContext?.container {
                    let embeddingContext = ModelContext(container)
                    try? await EmbeddingService.shared.generateEmbeddings(for: recording, context: embeddingContext)
                }

                sendNotification(title: String(localized: "转录完成"), body: String(localized: "「\(recording.title)」已完成转录"))
            } catch {
                #if DEBUG
                print("❌ Auto-transcription failed: \(error)")
                #endif
                // Restore default title on failure
                recording.title = recording.date.recordingTitle
            }
            recording.isTranscribing = false
        }
    }

    private func autoMatchSpeakers(recording: Recording, audioURL: URL, utterances: [SpeakerUtterance]) {
        guard let container = try? ModelContainer(for: SpeakerProfile.self) else { return }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SpeakerProfile>()
        guard let profiles = try? context.fetch(descriptor), !profiles.isEmpty else { return }

        let matches = voiceprintService.matchSpeakers(audioURL: audioURL, utterances: utterances, profiles: profiles)
        for (speaker, match) in matches {
            let speakerLabel = LanguageManager.shared.isEnglish ? "Speaker \(speaker)" : "说话人\(speaker)"
            recording.speakerNames[speakerLabel] = match.profileName
        }
    }

    private func sendNotification(title: String, body: String) {
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
