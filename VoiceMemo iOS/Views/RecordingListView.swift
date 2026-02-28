import SwiftUI
import SwiftData

// MARK: - Filter

private enum RecordingFilter: String, CaseIterable {
    case all = "全部"
    case hasSummary = "已摘要"
    case favorites = "收藏"
    case watch = "Watch"
}

// MARK: - Date Group

private enum DateGroup: String, CaseIterable {
    case today = "今天"
    case yesterday = "昨天"
    case lastWeek = "上周"
    case earlier = "更早"
}

// MARK: - Main View

struct RecordingHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recording.date, order: .reverse) private var recordings: [Recording]
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var activeFilter: RecordingFilter = .all
    @State private var recordingToRename: Recording?
    @State private var renameText = ""
    @State private var recordingToDelete: Recording?
    var switchToTab: (AppTab) -> Void

    private var filteredRecordings: [Recording] {
        var result = recordings

        // Search filter
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }

        // Chip filter
        switch activeFilter {
        case .all: break
        case .hasSummary:
            result = result.filter { $0.summary != nil }
        case .favorites:
            break // No favorites feature yet
        case .watch:
            result = result.filter { $0.source == .watch }
        }

        return result
    }

    private func groupedRecordings() -> [(DateGroup, [Recording])] {
        let calendar = Calendar.current
        var groups: [DateGroup: [Recording]] = [:]

        for recording in filteredRecordings {
            let group: DateGroup
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

        return DateGroup.allCases.compactMap { group in
            guard let items = groups[group], !items.isEmpty else { return nil }
            return (group, items)
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                RadialBackgroundView()

                if filteredRecordings.isEmpty {
                    emptyState
                } else {
                    recordingsList
                }
            }

            // FAB
            Button {
                switchToTab(.home)
            } label: {
                Circle()
                    .fill(.white)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "mic.fill")
                            .font(.title3)
                            .foregroundStyle(.black)
                    )
                    .shadow(color: .white.opacity(0.15), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
        .navigationTitle("历史记录")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSearching.toggle()
                        if !isSearching { searchText = "" }
                    }
                } label: {
                    Image(systemName: isSearching ? "xmark" : "magnifyingglass")
                        .foregroundStyle(GlassTheme.textSecondary)
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
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

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.slash")
                .font(.system(size: 48))
                .foregroundStyle(GlassTheme.textMuted)

            Text("暂无录音")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(GlassTheme.textSecondary)

            Text("点击右下角按钮开始录音")
                .font(.subheadline)
                .foregroundStyle(GlassTheme.textMuted)
        }
    }

    // MARK: - List

    private var recordingsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Search bar
                if isSearching {
                    HStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.subheadline)
                                .foregroundStyle(GlassTheme.textMuted)
                            TextField("搜索录音", text: $searchText)
                                .font(.subheadline)
                                .foregroundStyle(GlassTheme.textPrimary)
                                .tint(GlassTheme.accent)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .glassCard(radius: 12)

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                searchText = ""
                                isSearching = false
                            }
                        } label: {
                            Text("取消")
                                .font(.subheadline)
                                .foregroundStyle(GlassTheme.textSecondary)
                        }
                    }
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(RecordingFilter.allCases, id: \.rawValue) { filter in
                            GlassChip(
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

                // Grouped recordings
                let groups = groupedRecordings()
                ForEach(groups, id: \.0) { group, items in
                    Section {
                        ForEach(items) { recording in
                            NavigationLink(destination: RecordingDetailView(recording: recording)) {
                                HistoryRecordingRow(recording: recording)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    recordingToDelete = recording
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    renameText = recording.title
                                    recordingToRename = recording
                                } label: {
                                    Label("重命名", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    } header: {
                        GlassSectionHeader(title: group.rawValue)
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }
                }
            }
            .padding(.bottom, 80)
        }
        .scrollContentBackground(.hidden)
    }

    private func deleteRecording(_ recording: Recording) {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDir.appendingPathComponent(recording.fileURL)
        try? FileManager.default.removeItem(at: fileURL)
        modelContext.delete(recording)
    }
}

// MARK: - History Row

struct HistoryRecordingRow: View {
    let recording: Recording

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(GlassTheme.surfaceMedium)
                    .frame(width: 44, height: 44)
                Image(systemName: "waveform")
                    .font(.system(size: 16))
                    .foregroundStyle(GlassTheme.accent)

                // AI badge
                if recording.transcription != nil {
                    Circle()
                        .fill(GlassTheme.accent)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Text("AI")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.white)
                        )
                        .offset(x: 16, y: -16)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(GlassTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(recording.date.shortDisplay)
                    Text("·")
                    Text(recording.formattedDuration)
                    if recording.source == .watch {
                        Label("Watch", systemImage: "applewatch")
                    }
                }
                .font(.caption)
                .foregroundStyle(GlassTheme.textTertiary)
            }

            Spacer()

            // Processing badge or chevron
            if recording.isTranscribing || recording.isSummarizing {
                processingBadge
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(GlassTheme.textMuted)
            }
        }
        .padding(14)
        .glassCard()
        .padding(.horizontal)
    }

    private var processingBadge: some View {
        HStack(spacing: 4) {
            PulsingDot()
            Text("处理中")
                .font(.caption2)
                .foregroundStyle(GlassTheme.textTertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .glassCard(radius: 12)
    }
}
