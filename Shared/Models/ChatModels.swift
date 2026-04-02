import Foundation
import SwiftData

@Model
final class ChatConversation {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \PersistedChatMessage.conversation)
    var messages: [PersistedChatMessage] = []
    var recordingID: UUID?

    init(recordingID: UUID? = nil, title: String = "") {
        self.id = UUID()
        self.title = title
        self.createdAt = .now
        self.updatedAt = .now
        self.recordingID = recordingID
    }
}

@Model
final class PersistedChatMessage {
    var id: UUID
    var role: String
    var content: String
    var timestamp: Date
    var conversation: ChatConversation?
    var sourceRecordingIDs: [UUID] = []

    init(role: String, content: String, sourceRecordingIDs: [UUID] = []) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = .now
        self.sourceRecordingIDs = sourceRecordingIDs
    }
}
