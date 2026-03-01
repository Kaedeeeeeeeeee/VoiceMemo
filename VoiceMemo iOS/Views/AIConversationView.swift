import SwiftUI
import SwiftData

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp = Date()

    enum Role {
        case user
        case assistant
    }
}

enum ConversationViewState: Equatable {
    case list
    case active
}

struct AIConversationView: View {
    let recording: Recording
    @Environment(\.modelContext) private var modelContext
    @State private var aiService = AIService()
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var viewState: ConversationViewState = .list
    @State private var conversations: [ChatConversation] = []
    @State private var activeConversation: ChatConversation?
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if recording.transcription == nil {
                noTranscriptionView
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
            }

            // Input bar (only in active state or list with no transcription guard above)
            if recording.transcription != nil {
                if case .active = viewState {
                    inputBar
                } else if conversations.isEmpty {
                    inputBar
                }
            }
        }
        .background(Color.clear)
        .task {
            loadConversations()
        }
    }

    // MARK: - Subviews

    private var noTranscriptionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.badge.xmark")
                .font(.system(size: 40))
                .foregroundStyle(GlassTheme.textMuted)
            Text("请先完成语音转写")
                .font(.headline)
                .foregroundStyle(GlassTheme.textSecondary)
            Text("AI 对话需要基于转写文本")
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
            // Back button
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
            TextField("针对录音内容提问...", text: $inputText, axis: .vertical)
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
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 36))
                    .foregroundStyle(GlassTheme.textMuted)
                    .padding(.top, 24)

                Text("针对录音内容提问")
                    .font(.subheadline)
                    .foregroundStyle(GlassTheme.textTertiary)

                let suggestions = [
                    "这段录音的主要内容是什么？",
                    "有哪些重要的决定或结论？",
                    "总结一下讨论的要点",
                    "有没有提到截止日期？"
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
                    ForEach(messages) { message in
                        GlassMessageBubble(message: message)
                            .id(message.id)
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

    // MARK: - Actions

    private func loadConversations() {
        let recordingID = recording.id
        var descriptor = FetchDescriptor<ChatConversation>(
            predicate: #Predicate { $0.recordingID == recordingID },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 50
        conversations = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func startNewConversation() {
        activeConversation = nil
        messages = []
        viewState = .active
    }

    private func createNewConversation(initialMessage: String?) {
        activeConversation = nil
        messages = []
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
        viewState = .active
    }

    private func returnToList() {
        messages = []
        activeConversation = nil
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
        let conversation = ChatConversation(recordingID: recording.id)
        modelContext.insert(conversation)
        activeConversation = conversation
        viewState = .active
        return conversation
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, let transcription = recording.transcription else { return }

        // If we're in list state (suggestions visible, no history), enter active state first
        if case .list = viewState {
            createNewConversation(initialMessage: text)
            return
        }

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        isInputFocused = false
        inputText = ""
        isLoading = true

        // Persist user message — create conversation on demand
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
                let conversationHistory = messages.map { msg in
                    AIService.ConversationMessage(
                        role: msg.role == .user ? "user" : "assistant",
                        content: msg.content
                    )
                }

                let response = try await aiService.chat(
                    transcription: transcription,
                    messages: conversationHistory
                )
                let assistantMessage = ChatMessage(role: .assistant, content: response)
                messages.append(assistantMessage)

                // Persist assistant message
                if let conversation = activeConversation {
                    let persistedMsg = PersistedChatMessage(role: "assistant", content: response)
                    persistedMsg.conversation = conversation
                    modelContext.insert(persistedMsg)
                    conversation.updatedAt = .now
                    try? modelContext.save()
                }
            } catch {
                let errorContent = "抱歉，出现了错误：\(error.localizedDescription)"
                messages.append(ChatMessage(role: .assistant, content: errorContent))
            }
            isLoading = false
        }
    }
}

struct GlassMessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            Text(message.content)
                .font(.body)
                .padding(12)
                .foregroundStyle(GlassTheme.textPrimary)
                .adaptiveGlassEffect(
                    tint: message.role == .user ? GlassTheme.accent : nil,
                    in: RoundedRectangle(cornerRadius: 16)
                )

            if message.role == .assistant { Spacer(minLength: 60) }
        }
        .padding(.horizontal)
    }
}
