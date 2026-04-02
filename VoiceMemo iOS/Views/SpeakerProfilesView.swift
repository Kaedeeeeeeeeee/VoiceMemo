import SwiftUI
import SwiftData

struct SpeakerProfilesView: View {
    @Query(sort: \SpeakerProfile.updatedAt, order: .reverse) private var profiles: [SpeakerProfile]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            RadialBackgroundView()

            if profiles.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "waveform.badge.person.crop")
                        .font(.system(size: 40))
                        .foregroundStyle(GlassTheme.textMuted)
                    Text("还没有保存的声纹")
                        .font(.headline)
                        .foregroundStyle(GlassTheme.textSecondary)
                    Text("在说话人重命名中保存声纹后，新录音将自动识别")
                        .font(.subheadline)
                        .foregroundStyle(GlassTheme.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                List {
                    ForEach(profiles) { profile in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.name)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundStyle(GlassTheme.textPrimary)
                                HStack(spacing: 8) {
                                    Text("\(profile.sampleCount) 段样本")
                                    Text("·")
                                    Text(String(format: "%.0f 秒", profile.totalSampleDuration))
                                    Text("·")
                                    Text(profile.updatedAt.formatted(.relative(presentation: .named)))
                                }
                                .font(.caption)
                                .foregroundStyle(GlassTheme.textTertiary)
                            }
                            Spacer()
                            Image(systemName: "waveform")
                                .font(.caption)
                                .foregroundStyle(GlassTheme.accent)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .glassCard()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                modelContext.delete(profile)
                                try? modelContext.save()
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("声纹管理")
        .navigationBarTitleDisplayMode(.inline)
    }
}
