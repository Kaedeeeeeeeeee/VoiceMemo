import SwiftUI

struct RecordingRowView: View {
    let recording: Recording

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(recording.title)
                .font(.headline)
                .lineLimit(1)

            HStack {
                Label(recording.formattedDuration, systemImage: "waveform")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(recording.date.shortDisplay)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
