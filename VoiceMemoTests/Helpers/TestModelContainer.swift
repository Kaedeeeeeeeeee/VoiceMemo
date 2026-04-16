import SwiftData
@testable import VoiceMemo_iOS

enum TestModelContainer {
    @MainActor
    static func create() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Recording.self,
                 RecordingMarker.self,
                 ChatConversation.self,
                 PersistedChatMessage.self,
                 CustomSummaryTemplate.self,
                 SpeakerProfile.self,
                 EmbeddingChunk.self,
            configurations: config
        )
    }
}
