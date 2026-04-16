import Testing
import SwiftData
import Foundation
@testable import VoiceMemo_iOS

@Suite("ChatModels Tests")
struct ChatModelsTests {

    @Test func chatConversation_initDefaults() async throws {
        let container = try await TestModelContainer.create()
        let context = ModelContext(container)
        let conversation = ChatConversation(title: "Test Chat")
        context.insert(conversation)
        #expect(conversation.title == "Test Chat")
        #expect(conversation.recordingID == nil)
        #expect(conversation.messages.isEmpty)
    }

    @Test func chatConversation_withRecordingID() async throws {
        let container = try await TestModelContainer.create()
        let context = ModelContext(container)
        let rid = UUID()
        let conversation = ChatConversation(recordingID: rid, title: "Chat")
        context.insert(conversation)
        #expect(conversation.recordingID == rid)
    }

    @Test func persistedChatMessage_initFields() async throws {
        let container = try await TestModelContainer.create()
        let context = ModelContext(container)
        let ids = [UUID(), UUID()]
        let message = PersistedChatMessage(role: "user", content: "Hello", sourceRecordingIDs: ids)
        context.insert(message)
        #expect(message.role == "user")
        #expect(message.content == "Hello")
        #expect(message.sourceRecordingIDs.count == 2)
    }
}
