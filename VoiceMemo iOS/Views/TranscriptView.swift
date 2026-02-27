import SwiftUI

struct TranscriptView: View {
    @Bindable var recording: Recording
    @State private var transcriptionService = TranscriptionService()
    @State private var aiService = AIService()
    @State private var error: String?
    @State private var isEditing = false
    @State private var editedText = ""
    @State private var transcriptionPhase = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if recording.isTranscribing {
                    ProgressView(transcriptionPhase.isEmpty ? "正在转写..." : transcriptionPhase)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if let transcription = recording.transcription {
                    HStack {
                        Spacer()
                        Button(isEditing ? "完成" : "编辑") {
                            if isEditing {
                                recording.transcription = editedText
                                isEditing = false
                            } else {
                                editedText = transcription
                                isEditing = true
                            }
                        }
                        .font(.subheadline)
                    }
                    .padding(.horizontal)

                    if isEditing {
                        TextEditor(text: $editedText)
                            .font(.body)
                            .frame(minHeight: 200)
                            .padding(.horizontal)
                    } else {
                        Text(transcription)
                            .font(.body)
                            .textSelection(.enabled)
                            .padding()
                    }
                } else if let error {
                    ContentUnavailableView {
                        Label("转写失败", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("重试") {
                            self.error = nil
                            startTranscription()
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "text.badge.plus")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)

                        Text("将录音转换为文字")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Button("开始转写") {
                            startTranscription()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                }
            }
        }
    }

    private func startTranscription() {
        recording.isTranscribing = true

        Task {
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let url = documentsDir.appendingPathComponent(recording.fileURL)

            do {
                transcriptionPhase = "正在语音识别..."
                let rawText = try await transcriptionService.transcribe(audioURL: url)

                transcriptionPhase = "正在智能润色..."
                let polishedText = try await aiService.polishTranscription(rawText)
                recording.transcription = polishedText

                // Auto-generate title if it's still the default date format
                if recording.title.hasPrefix("录音 ") {
                    Task {
                        if let title = try? await aiService.generateTitle(transcription: polishedText) {
                            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                recording.title = trimmed
                            }
                        }
                    }
                }
            } catch {
                self.error = error.localizedDescription
            }
            recording.isTranscribing = false
        }
    }
}
