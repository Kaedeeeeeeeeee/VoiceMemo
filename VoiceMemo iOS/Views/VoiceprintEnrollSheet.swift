import SwiftUI
import SwiftData

struct VoiceprintEnrollSheet: View {
    let speakerLabel: String
    let speakerName: String
    let recording: Recording
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var voiceprintService = VoiceprintService()
    @State private var isEnrolling = false
    @State private var enrollmentSuccess = false
    @State private var errorMessage: String?

    private var segments: [SpeakerSegment] {
        recording.segmentsForSpeaker(speakerLabel)
    }

    private var totalDuration: Double {
        segments.reduce(0) { $0 + $1.duration }
    }

    private var audioURL: URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDir.appendingPathComponent(recording.fileURL)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Speaker info
                VStack(spacing: 12) {
                    Image(systemName: "waveform.badge.person.crop")
                        .font(.system(size: 40))
                        .foregroundStyle(GlassTheme.accent)

                    Text(speakerName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(GlassTheme.textPrimary)
                }
                .padding(.top, 20)

                // Segment info
                VStack(spacing: 8) {
                    HStack {
                        Text("音频片段")
                            .foregroundStyle(GlassTheme.textTertiary)
                        Spacer()
                        Text("\(segments.count) 段")
                            .foregroundStyle(GlassTheme.textPrimary)
                    }
                    HStack {
                        Text("总时长")
                            .foregroundStyle(GlassTheme.textTertiary)
                        Spacer()
                        Text(String(format: "%.1f 秒", totalDuration))
                            .foregroundStyle(GlassTheme.textPrimary)
                    }
                }
                .font(.subheadline)
                .padding()
                .glassCard()
                .padding(.horizontal)

                if enrollmentSuccess {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.green)
                        Text("声纹已保存")
                            .font(.subheadline)
                            .foregroundStyle(GlassTheme.textSecondary)
                    }
                } else if let error = errorMessage {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 36))
                            .foregroundStyle(.yellow)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(GlassTheme.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                }

                Spacer()

                if !enrollmentSuccess {
                    Button {
                        enrollVoiceprint()
                    } label: {
                        HStack(spacing: 8) {
                            if isEnrolling {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isEnrolling ? "正在提取声纹..." : "保存声纹")
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .glassButton(prominent: true)
                    .disabled(isEnrolling || segments.isEmpty)
                    .padding(.horizontal)
                }
            }
            .navigationTitle("声纹注册")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(enrollmentSuccess ? "完成" : "取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(.regularMaterial)
    }

    private func enrollVoiceprint() {
        guard !segments.isEmpty else { return }
        isEnrolling = true
        errorMessage = nil

        Task {
            do {
                // Check for existing profile with same name
                var descriptor = FetchDescriptor<SpeakerProfile>(
                    predicate: #Predicate { $0.name == speakerName }
                )
                descriptor.fetchLimit = 1
                let existing = try? modelContext.fetch(descriptor).first

                let profile = try voiceprintService.enrollSpeaker(
                    name: speakerName,
                    audioURL: audioURL,
                    segments: segments,
                    existingProfile: existing
                )

                if existing == nil {
                    modelContext.insert(profile)
                }
                try modelContext.save()

                enrollmentSuccess = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isEnrolling = false
        }
    }
}
