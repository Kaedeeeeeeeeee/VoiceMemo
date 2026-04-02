import SwiftUI
import SwiftData

extension Notification.Name {
    static let seekToTime = Notification.Name("seekToTime")
}

struct MarkerListView: View {
    @Bindable var recording: Recording
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            if recording.sortedMarkers.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bookmark.slash")
                        .font(.system(size: 48))
                        .foregroundStyle(GlassTheme.textMuted)
                    Text("暂无标记")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(GlassTheme.textSecondary)
                    Text("录音时点击书签按钮添加标记")
                        .font(.subheadline)
                        .foregroundStyle(GlassTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(recording.sortedMarkers) { marker in
                        MarkerRow(marker: marker)
                            .onTapGesture {
                                NotificationCenter.default.post(
                                    name: .seekToTime,
                                    object: nil,
                                    userInfo: ["time": marker.timestamp]
                                )
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteMarker(marker)
                                } label: {
                                    Label("删除标记", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
            }
        }
    }

    private func deleteMarker(_ marker: RecordingMarker) {
        // Delete photo file if exists
        if let photoFileName = marker.photoFileName {
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let photoURL = documentsDir.appendingPathComponent(photoFileName)
            try? FileManager.default.removeItem(at: photoURL)
        }
        modelContext.delete(marker)
    }
}

// MARK: - Marker Row

private struct MarkerRow: View {
    let marker: RecordingMarker

    var body: some View {
        HStack(spacing: 12) {
            // Timestamp badge
            Text(marker.formattedTimestamp)
                .font(.caption)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(GlassTheme.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(GlassTheme.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

            // Text
            Text(marker.text)
                .font(.subheadline)
                .foregroundStyle(GlassTheme.textPrimary)
                .lineLimit(2)

            Spacer()

            // Photo thumbnail
            if let photoFileName = marker.photoFileName {
                let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let photoURL = documentsDir.appendingPathComponent(photoFileName)
                if let data = try? Data(contentsOf: photoURL),
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Image(systemName: "play.circle.fill")
                .font(.title3)
                .foregroundStyle(GlassTheme.textMuted)
        }
        .padding(12)
        .glassCard()
    }
}
