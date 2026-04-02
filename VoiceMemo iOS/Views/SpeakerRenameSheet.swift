import SwiftUI

struct SpeakerRenameSheet: View {
    @Bindable var recording: Recording
    @Environment(\.dismiss) private var dismiss
    @State private var editingNames: [String: String] = [:]
    @State private var enrollSpeakerLabel: String?

    private var speakers: [String] {
        Recording.extractSpeakers(from: recording.transcription ?? "")
    }

    private var hasUtteranceData: Bool {
        recording.speakerUtterances != nil
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(speakers, id: \.self) { speaker in
                    HStack {
                        Text(speaker)
                            .font(.subheadline)
                            .foregroundStyle(GlassTheme.textTertiary)
                            .frame(width: 80, alignment: .leading)
                        TextField("自定义名称", text: binding(for: speaker))
                            .font(.body)
                            .foregroundStyle(GlassTheme.textPrimary)

                        if hasUtteranceData, let name = editingNames[speaker], !name.isEmpty {
                            Button {
                                enrollSpeakerLabel = speaker
                            } label: {
                                Image(systemName: "waveform.badge.person.crop")
                                    .font(.subheadline)
                                    .foregroundStyle(GlassTheme.accent)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .navigationTitle("说话人重命名")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        recording.speakerNames = editingNames
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(.regularMaterial)
        .onAppear {
            editingNames = recording.speakerNames
        }
        .sheet(item: enrollSpeakerBinding) { item in
            VoiceprintEnrollSheet(
                speakerLabel: item.label,
                speakerName: editingNames[item.speaker] ?? "",
                recording: recording
            )
        }
    }

    private func binding(for speaker: String) -> Binding<String> {
        Binding(
            get: { editingNames[speaker] ?? "" },
            set: { editingNames[speaker] = $0 }
        )
    }

    /// Maps speaker display name (e.g. "说话人A") to the utterance speaker label (e.g. "A")
    private func utteranceLabelForSpeaker(_ speaker: String) -> String {
        // Speaker names from extractSpeakers are like "说话人A" or "Speaker A"
        // Utterance labels are just "A", "B", etc.
        if let last = speaker.last, last.isLetter && last.isUppercase {
            return String(last)
        }
        return speaker
    }

    private var enrollSpeakerBinding: Binding<EnrollItem?> {
        Binding(
            get: {
                guard let speaker = enrollSpeakerLabel else { return nil }
                return EnrollItem(speaker: speaker, label: utteranceLabelForSpeaker(speaker))
            },
            set: { enrollSpeakerLabel = $0?.speaker }
        )
    }
}

private struct EnrollItem: Identifiable {
    let speaker: String  // display name, e.g. "说话人A"
    let label: String    // utterance label, e.g. "A"
    var id: String { speaker }
}
