import SwiftUI

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

struct AIConversationView: View {
    let recording: Recording
    @State private var aiService = AIService()
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            if recording.transcription == nil {
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
            } else if messages.isEmpty {
                suggestionsView
            } else {
                messagesView
            }

            // Input bar
            HStack(spacing: 10) {
                TextField("针对录音内容提问...", text: $inputText, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .foregroundStyle(GlassTheme.textPrimary)
                    .adaptiveGlassEffect(in: Capsule())
                    .disabled(recording.transcription == nil)

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
        .background(Color.clear)
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

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, let transcription = recording.transcription else { return }

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        inputText = ""
        isLoading = true

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
                messages.append(ChatMessage(role: .assistant, content: response))
            } catch {
                messages.append(ChatMessage(role: .assistant, content: "抱歉，出现了错误：\(error.localizedDescription)"))
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
