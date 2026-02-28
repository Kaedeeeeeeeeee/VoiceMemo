import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct RecordingHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var recorder = iOSAudioRecorder()
    @State private var showFilePicker = false
    @State private var showTemplateAlert = false
    @State private var navigateToRecording = false
    var switchToTab: (AppTab) -> Void

    var body: some View {
        ZStack {
            RadialBackgroundView()

            VStack(spacing: 0) {
                Spacer()

                // Title block
                VStack(spacing: 6) {
                    GlassTheme.uppercaseLabel("AI Transcription")
                    Text("语音录制")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(GlassTheme.textPrimary)
                }
                .padding(.bottom, 40)

                // Concentric circles mic button
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(GlassTheme.surfaceLight, lineWidth: 1)
                        .frame(width: 260, height: 260)

                    // Middle ring
                    Circle()
                        .fill(GlassTheme.surfaceLight)
                        .overlay(
                            Circle()
                                .stroke(GlassTheme.borderSubtle, lineWidth: 0.5)
                        )
                        .frame(width: 200, height: 200)

                    // Inner button
                    Button {
                        navigateToRecording = true
                    } label: {
                        Circle()
                            .fill(GlassTheme.surfaceMedium)
                            .overlay(
                                Circle()
                                    .stroke(GlassTheme.borderMedium, lineWidth: 0.5)
                            )
                            .frame(width: 140, height: 140)
                            .overlay(
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(.white)
                            )
                    }
                    .buttonStyle(.plain)
                }

                // Status capsule
                HStack(spacing: 6) {
                    Circle()
                        .fill(GlassTheme.textMuted)
                        .frame(width: 6, height: 6)
                    Text("准备录音")
                        .font(.caption)
                        .foregroundStyle(GlassTheme.textTertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .glassCard(radius: 20)
                .padding(.top, 20)

                Text("轻触开始捕捉你的想法")
                    .font(.caption)
                    .foregroundStyle(GlassTheme.textMuted)
                    .padding(.top, 12)

                Spacer()

                // Bottom action buttons
                HStack(spacing: 16) {
                    Button {
                        showFilePicker = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.down")
                            Text("导入音频")
                        }
                        .font(.subheadline)
                        .foregroundStyle(GlassTheme.textSecondary)
                    }
                    .buttonStyle(GlassButtonStyle())

                    Button {
                        showTemplateAlert = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text")
                            Text("笔记模板")
                        }
                        .font(.subheadline)
                        .foregroundStyle(GlassTheme.textSecondary)
                    }
                    .buttonStyle(GlassButtonStyle())
                }
                .padding(.bottom, 24)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $navigateToRecording) {
            ActiveRecordingView(recorder: recorder) { url, duration in
                saveRecording(url: url, duration: duration)
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            handleImportedFile(result)
        }
        .alert("即将上线", isPresented: $showTemplateAlert) {
            Button("好的") { }
        } message: {
            Text("笔记模板功能即将上线，敬请期待")
        }
    }

    private func saveRecording(url: URL, duration: TimeInterval) {
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        let recording = Recording(
            title: Date.now.recordingTitle,
            duration: duration,
            fileURL: url.lastPathComponent,
            fileSize: fileSize,
            source: .phone
        )
        modelContext.insert(recording)
    }

    private func handleImportedFile(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let sourceURL = urls.first else { return }
        guard sourceURL.startAccessingSecurityScopedResource() else { return }
        defer { sourceURL.stopAccessingSecurityScopedResource() }

        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "imported_\(UUID().uuidString).m4a"
        let destURL = documentsDir.appendingPathComponent(fileName)

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: destURL.path)[.size] as? Int64) ?? 0
            let recording = Recording(
                title: sourceURL.deletingPathExtension().lastPathComponent,
                duration: 0,
                fileURL: fileName,
                fileSize: fileSize,
                source: .phone
            )
            modelContext.insert(recording)
        } catch {
            print("Failed to import audio: \(error)")
        }
    }
}
