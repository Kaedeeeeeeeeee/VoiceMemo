import SwiftUI
import SwiftData

struct KnowledgeBaseView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recording.date, order: .reverse) private var allRecordings: [Recording]
    @State private var aiService = AIService()
    @State private var searchService = KnowledgeBaseSearchService()
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var viewState: ConversationViewState = .list
    @State private var conversations: [ChatConversation] = []
    @State private var activeConversation: ChatConversation?
    @State private var lastSourceResults: [SearchResult] = []
    @FocusState private var isInputFocused: Bool
    @State private var showPaywall = false

    private var transcribedRecordings: [Recording] {
        allRecordings.filter { $0.transcription != nil && !($0.transcription?.isEmpty ?? true) }
    }

    var body: some View {
        VStack(spacing: 0) {
            if transcribedRecordings.isEmpty {
                emptyStateView
            } else {
                switch viewState {
                case .list:
                    if conversations.isEmpty {
                        suggestionsView
                    } else {
                        conversationListView
                    }
                case .active:
                    activeConversationView
                }

                if !transcribedRecordings.isEmpty {
                    if case .active = viewState {
                        inputBar
                    } else if conversations.isEmpty {
                        inputBar
                    }
                }
            }
        }
        .background(RadialBackgroundView())
        .navigationTitle("知识库")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .task {
            loadConversations()
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 40))
                .foregroundStyle(GlassTheme.textMuted)
            Text("知识库为空")
                .font(.headline)
                .foregroundStyle(GlassTheme.textSecondary)
            Text("完成录音转写后即可跨录音提问")
                .font(.subheadline)
                .foregroundStyle(GlassTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var conversationListView: some View {
        List {
            Button {
                startNewConversation()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("新对话")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(GlassTheme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .glassButton()
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

            ForEach(conversations) { conversation in
                Button {
                    enterConversation(conversation)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(conversation.title.isEmpty ? "新对话" : conversation.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(GlassTheme.textPrimary)
                                .lineLimit(1)
                            HStack(spacing: 8) {
                                Text("\(conversation.messages.count) 条消息")
                                Text("·")
                                Text(conversation.updatedAt.formatted(.relative(presentation: .named)))
                            }
                            .font(.caption)
                            .foregroundStyle(GlassTheme.textTertiary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(GlassTheme.textMuted)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .glassCard()
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        deleteConversation(conversation)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var activeConversationView: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    returnToList()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("返回")
                    }
                    .font(.subheadline)
                    .foregroundStyle(GlassTheme.accent)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 6)

            if messages.isEmpty {
                suggestionsView
            } else {
                messagesView
            }
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("跨录音提问...", text: $inputText, axis: .vertical)
                .focused($isInputFocused)
                .lineLimit(1...5)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .foregroundStyle(GlassTheme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .adaptiveGlassEffect(in: RoundedRectangle(cornerRadius: 20))

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, canSend ? GlassTheme.accent : GlassTheme.surfaceMedium)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading
    }

    private var suggestionsView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(GlassTheme.textMuted)
                    .padding(.top, 24)

                Text("跨录音智能问答")
                    .font(.subheadline)
                    .foregroundStyle(GlassTheme.textTertiary)

                let suggestions = [
                    String(localized: "我最近的录音都讨论了什么？"),
                    String(localized: "帮我总结过去一周的要点"),
                    String(localized: "有没有提到需要跟进的事项？"),
                    String(localized: "最近的会议有哪些决定？")
                ]

                VStack(spacing: 10) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            inputText = suggestion
                            sendMessage()
                        } label: {
                            Text(suggestion)
                                .font(.subheadline)
                                .foregroundStyle(GlassTheme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }
                        .glassButton()
                    }
                }
            }
            .padding()
        }
    }

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        VStack(spacing: 6) {
                            GlassMessageBubble(message: message)
                                .id(message.id)

                            // Show source cards after assistant messages
                            if message.role == .assistant {
                                let sources = sourcesForMessage(at: index)
                                if !sources.isEmpty {
                                    sourceCardsView(for: sources)
                                }
                            }
                        }
                    }

                    if isLoading {
                        HStack {
                            ProgressView()
                                .tint(GlassTheme.accent)
                                .padding(12)
                                .glassCard(radius: 12)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .onChange(of: messages.count) {
                if let last = messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private func sourceCardsView(for sources: [SearchResult]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(sources) { result in
                    NavigationLink {
                        RecordingDetailView(recording: result.recording)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.recording.title)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(GlassTheme.textPrimary)
                                .lineLimit(1)
                            Text(result.recording.date.formatted(.dateTime.month().day()))
                                .font(.caption2)
                                .foregroundStyle(GlassTheme.textTertiary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    }
                    .glassCard(radius: 8)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Actions

    private func loadConversations() {
        let nilUUID: UUID? = nil
        var descriptor = FetchDescriptor<ChatConversation>(
            predicate: #Predicate { $0.recordingID == nilUUID },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 50
        conversations = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func startNewConversation() {
        activeConversation = nil
        messages = []
        lastSourceResults = []
        viewState = .active
    }

    private func createNewConversation(initialMessage: String?) {
        activeConversation = nil
        messages = []
        lastSourceResults = []
        viewState = .active

        if let text = initialMessage {
            inputText = text
            sendMessage()
        }
    }

    private func enterConversation(_ conversation: ChatConversation) {
        activeConversation = conversation
        messages = conversation.messages
            .sorted { $0.timestamp < $1.timestamp }
            .map { ChatMessage(role: $0.role == "user" ? .user : .assistant, content: $0.content) }
        lastSourceResults = []
        viewState = .active
    }

    private func returnToList() {
        messages = []
        activeConversation = nil
        lastSourceResults = []
        viewState = .list
        loadConversations()
    }

    private func deleteConversation(_ conversation: ChatConversation) {
        modelContext.delete(conversation)
        try? modelContext.save()
        loadConversations()
    }

    private func ensureConversation() -> ChatConversation {
        if let existing = activeConversation {
            return existing
        }
        let conversation = ChatConversation(recordingID: nil)
        modelContext.insert(conversation)
        activeConversation = conversation
        viewState = .active
        return conversation
    }

    private func sourcesForMessage(at index: Int) -> [SearchResult] {
        // Show sources for the last assistant message only
        if index == messages.count - 1 && messages[index].role == .assistant {
            return lastSourceResults
        }

        // For persisted conversations, look up source recording IDs
        if let conversation = activeConversation {
            let sortedPersisted = conversation.messages.sorted { $0.timestamp < $1.timestamp }
            if index < sortedPersisted.count {
                let persisted = sortedPersisted[index]
                if !persisted.sourceRecordingIDs.isEmpty {
                    return persisted.sourceRecordingIDs.compactMap { sourceID in
                        allRecordings.first { $0.id == sourceID }.map { recording in
                            SearchResult(id: recording.id, recording: recording, score: 0, excerpts: [])
                        }
                    }
                }
            }
        }

        return []
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        guard TrialManager.shared.claimTrialIfNeeded() else {
            showPaywall = true
            return
        }

        if case .list = viewState {
            createNewConversation(initialMessage: text)
            return
        }

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        isInputFocused = false
        inputText = ""
        isLoading = true
        lastSourceResults = []

        let conversation = ensureConversation()
        let persistedMsg = PersistedChatMessage(role: "user", content: text)
        persistedMsg.conversation = conversation
        modelContext.insert(persistedMsg)
        if conversation.title.isEmpty {
            conversation.title = String(text.prefix(20))
        }
        conversation.updatedAt = .now
        try? modelContext.save()

        Task {
            do {
                // Search across all recordings (semantic + keyword fallback)
                let results = try await searchService.semanticSearch(query: text, in: transcribedRecordings, context: modelContext)
                let context = searchService.buildContext(from: results)

                await MainActor.run {
                    lastSourceResults = results
                }

                let conversationHistory = messages.map { msg in
                    AIService.ConversationMessage(
                        role: msg.role == .user ? "user" : "assistant",
                        content: msg.content
                    )
                }

                let response = try await aiService.knowledgeBaseChat(
                    context: context,
                    messages: conversationHistory
                )
                let assistantMessage = ChatMessage(role: .assistant, content: response)
                messages.append(assistantMessage)

                // Persist assistant message with source IDs
                if let conversation = activeConversation {
                    let sourceIDs = results.map { $0.recording.id }
                    let persistedMsg = PersistedChatMessage(
                        role: "assistant",
                        content: response,
                        sourceRecordingIDs: sourceIDs
                    )
                    persistedMsg.conversation = conversation
                    modelContext.insert(persistedMsg)
                    conversation.updatedAt = .now
                    try? modelContext.save()
                }
            } catch {
                let errorContent = String(localized: "抱歉，出现了错误：\(error.localizedDescription)")
                messages.append(ChatMessage(role: .assistant, content: errorContent))
            }
            isLoading = false
        }
    }
}
