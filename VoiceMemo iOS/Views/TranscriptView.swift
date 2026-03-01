import SwiftUI

struct TranscriptView: View {
    @Bindable var recording: Recording
    @State private var transcriptionService = TranscriptionService()
    @State private var aiService = AIService()
    @State private var error: String?
    @State private var isEditing = false
    @State private var editedText = ""
    @State private var transcriptionPhase = ""
    @State private var showSpeakerSheet = false

    var body: some View {
        ZStack {
                if recording.isTranscribing {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .tint(GlassTheme.accent)
                                    .scaleEffect(1.2)
                                Text(phaseText.isEmpty ? String(localized: "正在转写...") : phaseText)
                                    .font(.subheadline)
                                    .foregroundStyle(GlassTheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .glassCard()
                            .padding()
                        }
                    }
                } else if recording.transcription != nil {
                    ZStack {
                        // Read mode — always present, toggle visibility
                        ScrollView {
                            VStack(spacing: 0) {
                                if !speakers.isEmpty {
                                    speakerBanner
                                }
                                Text(recording.applyingSpeakerNames(to: recording.transcription ?? ""))
                                    .font(.body)
                                    .foregroundStyle(GlassTheme.textSecondary)
                                    .textSelection(.enabled)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .glassCard()
                                    .padding(.horizontal)
                                    .padding(.top, 4)
                                    .padding(.bottom, 80)
                            }
                        }
                        .opacity(isEditing ? 0 : 1)

                        // Edit mode — always present, toggle visibility
                        TextEditor(text: $editedText)
                            .font(.body)
                            .foregroundStyle(GlassTheme.textPrimary)
                            .scrollContentBackground(.hidden)
                            .padding()
                            .frame(maxHeight: .infinity)
                            .glassCard()
                            .padding(.horizontal)
                            .padding(.top, 4)
                            .opacity(isEditing ? 1 : 0)
                            .allowsHitTesting(isEditing)
                    }
                } else if let error {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
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
                                .glassButton()
                                .foregroundStyle(GlassTheme.accent)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .padding(.horizontal)
                        }
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
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
                                .glassButton(prominent: true)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        }
                    }
                }

            // Floating edit/done button
            if recording.transcription != nil && !recording.isTranscribing {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            if isEditing {
                                recording.transcription = editedText
                                isEditing = false
                            } else {
                                editedText = recording.transcription ?? ""
                                isEditing = true
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: isEditing ? "checkmark" : "pencil")
                                    .font(.caption)
                                Text(isEditing ? "完成" : "编辑")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(GlassTheme.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                        }
                        .glassCard(radius: 16)
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                        .padding()
                    }
                }
            }
        }
        .background(Color.clear)
        .sheet(isPresented: $showSpeakerSheet) {
            SpeakerRenameSheet(recording: recording)
        }
    }

    private var speakers: [String] {
        Recording.extractSpeakers(from: recording.transcription ?? "")
    }

    private var speakerBanner: some View {
        Button {
            showSpeakerSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "person.2")
                    .font(.caption)
                    .foregroundStyle(GlassTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("说话人重命名")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(GlassTheme.textPrimary)
                    let named = recording.speakerNames.values.filter { !$0.isEmpty }.count
                    if named > 0 {
                        Text("已命名 \(named) 位说话人")
                            .font(.caption)
                            .foregroundStyle(GlassTheme.textTertiary)
                    } else {
                        Text("检测到 \(speakers.count) 位说话人，点击设置名称")
                            .font(.caption)
                            .foregroundStyle(GlassTheme.textTertiary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(GlassTheme.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassCard()
            .padding(.horizontal)
            .padding(.top, 4)
        }
        .buttonStyle(.plain)
    }

    private var phaseText: String {
        switch transcriptionService.currentPhase {
        case .uploading:    return String(localized: "正在上传音频...")
        case .transcribing: return String(localized: "正在语音识别...")
        case .polling:      return String(localized: "正在等待转写结果...")
        case .idle:         return transcriptionPhase
        }
    }

    private func startTranscription() {
        recording.isTranscribing = true

        Task {
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let url = documentsDir.appendingPathComponent(recording.fileURL)

            do {
                let rawText = try await transcriptionService.transcribe(audioURL: url)

                transcriptionPhase = String(localized: "正在智能润色...")
                let polishedText = try await aiService.polishTranscription(rawText)
                recording.transcription = polishedText

                if recording.title.hasPrefix("录音 ") || recording.title.hasPrefix("Recording ") || recording.title.hasPrefix("Voice Memo ") {
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
