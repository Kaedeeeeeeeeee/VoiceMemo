import SwiftUI

struct MacTranscriptView: View {
    @Bindable var recording: Recording
    @State private var transcriptionService = TranscriptionService()
    @State private var aiService = AIService()
    @State private var error: String?
    @State private var isEditing = false
    @State private var editedText = ""
    @State private var transcriptionPhase = ""
    @State private var showSpeakerSheet = false
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            if recording.isTranscribing {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(MacGlassTheme.accent)
                        .scaleEffect(1.2)
                    Text(phaseText.isEmpty ? "正在转写..." : phaseText)
                        .font(.subheadline)
                        .foregroundStyle(MacGlassTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if recording.transcription != nil {
                ZStack {
                    ScrollView {
                        VStack(spacing: 0) {
                            if !speakers.isEmpty {
                                speakerBanner
                            }
                            Text(recording.applyingSpeakerNames(to: recording.transcription ?? ""))
                                .font(.body)
                                .foregroundStyle(MacGlassTheme.textSecondary)
                                .textSelection(.enabled)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .macGlassCard()
                                .padding(.horizontal)
                                .padding(.top, 4)
                                .padding(.bottom, 60)
                        }
                    }
                    .opacity(isEditing ? 0 : 1)

                    TextEditor(text: $editedText)
                        .font(.body)
                        .foregroundStyle(MacGlassTheme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .padding()
                        .frame(maxHeight: .infinity)
                        .macGlassCard()
                        .padding(.horizontal)
                        .padding(.top, 4)
                        .opacity(isEditing ? 1 : 0)
                        .allowsHitTesting(isEditing)
                }

                // Edit/Done button
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
                            .foregroundStyle(MacGlassTheme.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                        }
                        .macGlassCard(radius: 12)
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                        .padding()
                    }
                }
            } else if let error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(MacGlassTheme.accent)
                    Text("转写失败")
                        .font(.headline)
                        .foregroundStyle(MacGlassTheme.textPrimary)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(MacGlassTheme.textTertiary)
                        .multilineTextAlignment(.center)
                    Button("重试") {
                        self.error = nil
                        startTranscription()
                    }
                    .macGlassButton()
                    .foregroundStyle(MacGlassTheme.accent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "text.badge.plus")
                        .font(.system(size: 40))
                        .foregroundStyle(MacGlassTheme.textMuted)

                    Text("将录音转换为文字")
                        .font(.headline)
                        .foregroundStyle(MacGlassTheme.textSecondary)

                    Button {
                        startTranscription()
                    } label: {
                        Text("开始转写")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                    .macGlassButton(prominent: true)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.clear)
        .sheet(isPresented: $showPaywall) {
            MacPaywallPlaceholder()
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
                    .foregroundStyle(MacGlassTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("说话人重命名")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(MacGlassTheme.textPrimary)
                    let named = recording.speakerNames.values.filter { !$0.isEmpty }.count
                    if named > 0 {
                        Text("已命名 \(named) 位说话人")
                            .font(.caption)
                            .foregroundStyle(MacGlassTheme.textTertiary)
                    } else {
                        Text("检测到 \(speakers.count) 位说话人，点击设置名称")
                            .font(.caption)
                            .foregroundStyle(MacGlassTheme.textTertiary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(MacGlassTheme.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .macGlassCard()
            .padding(.horizontal)
            .padding(.top, 4)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showSpeakerSheet) {
            MacSpeakerRenameView(recording: recording)
                .frame(width: 300, height: 300)
        }
    }

    private var phaseText: String {
        switch transcriptionService.currentPhase {
        case .uploading:    return "正在上传音频..."
        case .transcribing: return "正在语音识别..."
        case .polling:      return "正在等待转写结果..."
        case .idle:         return transcriptionPhase
        }
    }

    private func startTranscription() {
        guard TrialManager.shared.claimTrialIfNeeded(for: recording) else {
            showPaywall = true
            return
        }

        recording.isTranscribing = true

        Task {
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let url = documentsDir.appendingPathComponent(recording.fileURL)

            do {
                let rawText = try await transcriptionService.transcribe(audioURL: url)
                transcriptionPhase = "正在智能润色..."
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

// MARK: - Speaker Rename (macOS popover)

struct MacSpeakerRenameView: View {
    @Bindable var recording: Recording

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("说话人重命名")
                .font(.headline)
                .foregroundStyle(MacGlassTheme.textPrimary)

            let speakers = Recording.extractSpeakers(from: recording.transcription ?? "")
            ForEach(speakers, id: \.self) { speaker in
                HStack {
                    Text(speaker)
                        .font(.subheadline)
                        .foregroundStyle(MacGlassTheme.textSecondary)
                        .frame(width: 70, alignment: .leading)

                    TextField("输入名称", text: Binding(
                        get: { recording.speakerNames[speaker] ?? "" },
                        set: { recording.speakerNames[speaker] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.subheadline)
                }
            }
        }
        .padding()
        .background(MacGlassTheme.background)
    }
}

// MARK: - Paywall placeholder for macOS

struct MacPaywallPlaceholder: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 40))
                .foregroundStyle(MacGlassTheme.accent)
            Text("升级到 PodNote Pro")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(MacGlassTheme.textPrimary)
            Text("解锁全部 AI 功能")
                .font(.subheadline)
                .foregroundStyle(MacGlassTheme.textSecondary)
            Button("关闭") { dismiss() }
                .macGlassButton()
        }
        .frame(width: 360, height: 280)
        .background(MacGlassTheme.background)
    }
}
