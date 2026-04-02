import SwiftUI

struct RecordingRowView: View {
    let recording: Recording

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(recording.title)
                    .font(.headline)
                    .foregroundStyle(WatchGlassTheme.textPrimary)
                    .lineLimit(1)

                if !recording.isSynced {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

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
