import SwiftUI

struct RecordingRowView: View {
    let recording: Recording

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(recording.title)
                .font(.headline)
                .foregroundStyle(WatchGlassTheme.textPrimary)
                .lineLimit(1)

            HStack {
                Label(recording.formattedDuration, systemImage: "waveform")
                    .font(.caption)
                    .foregroundStyle(WatchGlassTheme.textTertiary)

                Spacer()

                Text(recording.date.shortDisplay)
                    .font(.caption2)
                    .foregroundStyle(WatchGlassTheme.textMuted)
            }
        }
        .padding(.vertical, 2)
    }
}
