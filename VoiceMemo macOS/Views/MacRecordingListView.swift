import SwiftUI
import SwiftData

private enum MacRecordingFilter: String, CaseIterable {
    case all = "全部"
    case hasSummary = "已摘要"
    case mac = "Mac"
}

private enum MacDateGroup: String, CaseIterable {
    case today = "今天"
    case yesterday = "昨天"
    case lastWeek = "上周"
    case earlier = "更早"
}

struct MacRecordingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recording.date, order: .reverse) private var recordings: [Recording]
    @Binding var selectedRecording: Recording?
    @State private var searchText = ""
    @State private var activeFilter: MacRecordingFilter = .all
    @State private var recordingToDelete: Recording?
    @State private var recordingToRename: Recording?
    @State private var renameText = ""

    private var filteredRecordings: [Recording] {
        var result = recordings
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        switch activeFilter {
        case .all: break
        case .hasSummary:
            result = result.filter { $0.summary != nil }
        case .mac:
            result = result.filter { $0.source == .mac }
        }
        return result
    }

    private func groupedRecordings() -> [(MacDateGroup, [Recording])] {
        let calendar = Calendar.current
        var groups: [MacDateGroup: [Recording]] = [:]

        for recording in filteredRecordings {
            let group: MacDateGroup
            if calendar.isDateInToday(recording.date) {
                group = .today
            } else if calendar.isDateInYesterday(recording.date) {
                group = .yesterday
            } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()),
                      recording.date > weekAgo {
                group = .lastWeek
            } else {
                group = .earlier
            }
            groups[group, default: []].append(recording)
        }

        return MacDateGroup.allCases.compactMap { group in
            guard let items = groups[group], !items.isEmpty else { return nil }
            return (group, items)
        }
    }

    var body: some View {
        ZStack {
            MacRadialBackgroundView()

            VStack(spacing: 0) {
                // Search
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(MacGlassTheme.textMuted)
                    TextField("搜索录音", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                        .foregroundStyle(MacGlassTheme.textPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .macGlassCard(radius: 10)
                .padding(.horizontal)
                .padding(.top, 8)

                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MacRecordingFilter.allCases, id: \.rawValue) { filter in
                            MacGlassChip(
                                title: filter.rawValue,
                                isActive: activeFilter == filter
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    activeFilter = filter
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 8)
                .padding(.bottom, 4)

                if filteredRecordings.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "waveform.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(MacGlassTheme.textMuted)
                        Text("暂无录音")
                            .font(.headline)
                            .foregroundStyle(MacGlassTheme.textSecondary)
                    }
                    Spacer()
                } else {
                    List(selection: $selectedRecording) {
                        let groups = groupedRecordings()
                        ForEach(groups, id: \.0) { group, items in
                            Section {
                                ForEach(items) { recording in
                                    MacRecordingRow(recording: recording)
                                        .tag(recording)
                                        .opacity(recording.isTranscribing ? 0.6 : 1.0)
                                        .allowsHitTesting(!recording.isTranscribing)
                                        .contextMenu {
                                            Button {
                                                renameText = recording.title
                                                recordingToRename = recording
                                            } label: {
                                                Label("重命名", systemImage: "pencil")
                                            }
                                            Divider()
                                            Button(role: .destructive) {
                                                recordingToDelete = recording
                                            } label: {
                                                Label("删除", systemImage: "trash")
                                            }
                                        }
                                        .listRowBackground(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(selectedRecording?.id == recording.id ? MacGlassTheme.surfaceMedium : Color.clear)
                                        )
                                }
                            } header: {
                                MacGlassSectionHeader(title: group.rawValue)
                            }
                        }
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("录音列表")
        .alert("确认删除", isPresented: .init(
            get: { recordingToDelete != nil },
            set: { if !$0 { recordingToDelete = nil } }
        )) {
            Button("取消", role: .cancel) { recordingToDelete = nil }
            Button("删除", role: .destructive) {
                if let recording = recordingToDelete {
                    deleteRecording(recording)
                }
                recordingToDelete = nil
            }
        } message: {
            Text("删除后无法恢复，确定要删除这条录音吗？")
        }
        .alert("重命名录音", isPresented: .init(
            get: { recordingToRename != nil },
            set: { if !$0 { recordingToRename = nil } }
        )) {
            TextField("录音名称", text: $renameText)
            Button("取消", role: .cancel) { recordingToRename = nil }
            Button("确定") {
                if let recording = recordingToRename, !renameText.isEmpty {
                    recording.title = renameText
                }
                recordingToRename = nil
            }
        }
    }

    private func deleteRecording(_ recording: Recording) {
        if selectedRecording?.id == recording.id {
            selectedRecording = nil
        }
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDir.appendingPathComponent(recording.fileURL)
        try? FileManager.default.removeItem(at: fileURL)
        modelContext.delete(recording)
    }
}

// MARK: - Recording Row

struct MacRecordingRow: View {
    let recording: Recording

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(MacGlassTheme.surfaceMedium)
                    .frame(width: 36, height: 36)
                Image(systemName: "waveform")
                    .font(.system(size: 13))
                    .foregroundStyle(.white)

                if recording.transcription != nil {
                    Circle()
                        .fill(MacGlassTheme.accent)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Text("AI")
                                .font(.system(size: 6, weight: .bold))
                                .foregroundStyle(.white)
                        )
                        .offset(x: 14, y: -14)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(recording.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(MacGlassTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(recording.date.shortDisplay)
                    Text("·")
                    Text(recording.formattedDuration)
                    if recording.source == .mac {
                        Label("Mac", systemImage: "desktopcomputer")
                    } else if recording.source == .watch {
                        Label("Watch", systemImage: "applewatch")
                    }
                }
                .font(.caption2)
                .foregroundStyle(MacGlassTheme.textTertiary)
            }

            Spacer()

            if recording.isTranscribing || recording.isSummarizing {
                HStack(spacing: 4) {
                    MacPulsingDot()
                    Text("处理中")
                        .font(.caption2)
                        .foregroundStyle(MacGlassTheme.textTertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
