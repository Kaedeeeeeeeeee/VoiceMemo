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
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(GlassTheme.accent)
                            .scaleEffect(1.2)
                        Text(transcriptionPhase.isEmpty ? "正在转写..." : transcriptionPhase)
                            .font(.subheadline)
                            .foregroundStyle(GlassTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .glassCard()
                    .padding()
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
                        .foregroundStyle(GlassTheme.accent)
                    }
                    .padding(.horizontal)

                    if isEditing {
                        TextEditor(text: $editedText)
                            .font(.body)
                            .foregroundStyle(GlassTheme.textPrimary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 200)
                            .padding()
                            .glassCard()
                            .padding(.horizontal)
                    } else {
                        Text(transcription)
                            .font(.body)
                            .foregroundStyle(GlassTheme.textSecondary)
                            .textSelection(.enabled)
                            .padding()
                    }
                } else if let error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(GlassTheme.accent)
                        Text("转写失败")
                            .font(.headline)
                            .foregroundStyle(GlassTheme.textPrimary)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(GlassTheme.textTertiary)
                            .multilineTextAlignment(.center)
                        Button("重试") {
                            self.error = nil
                            startTranscription()
                        }
                        .buttonStyle(GlassButtonStyle(fill: GlassTheme.accent.opacity(0.3)))
                        .foregroundStyle(GlassTheme.accent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .padding(.horizontal)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "text.badge.plus")
                            .font(.system(size: 40))
                            .foregroundStyle(GlassTheme.textMuted)

                        Text("将录音转换为文字")
                            .font(.headline)
                            .foregroundStyle(GlassTheme.textSecondary)

                        Button {
                            startTranscription()
                        } label: {
                            Text("开始转写")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(GlassButtonStyle(fill: GlassTheme.accent))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                }
            }
        }
        .background(Color.clear)
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
