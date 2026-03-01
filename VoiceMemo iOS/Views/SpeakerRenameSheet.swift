import SwiftUI

struct SpeakerRenameSheet: View {
    @Bindable var recording: Recording
    @Environment(\.dismiss) private var dismiss
    @State private var editingNames: [String: String] = [:]

    private var speakers: [String] {
        Recording.extractSpeakers(from: recording.transcription ?? "")
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
    }

    private func binding(for speaker: String) -> Binding<String> {
        Binding(
            get: { editingNames[speaker] ?? "" },
            set: { editingNames[speaker] = $0 }
        )
    }
}
