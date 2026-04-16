import Testing
import Foundation
import SwiftData
@testable import VoiceMemo_iOS

@Suite(.serialized)
struct TrialManagerTests {

    @Test func remainingFreeUses_maxIs3() {
        // Reset to a fresh month state
        let monthKey = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            return formatter.string(from: Date())
        }()
        UserDefaults.standard.set(monthKey, forKey: "monthlyAICurrentMonth")
        UserDefaults.standard.set(0, forKey: "monthlyAIUsageCount")

        let manager = TrialManager.shared
        // Force reload from defaults
        _ = manager.remainingFreeUses
        #expect(manager.remainingFreeUses <= 3)
    }

    @Test func isTrialClaimed_falseWhenNoUsage() {
        let monthKey = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            return formatter.string(from: Date())
        }()
        UserDefaults.standard.set(monthKey, forKey: "monthlyAICurrentMonth")
        UserDefaults.standard.set(0, forKey: "monthlyAIUsageCount")

        let manager = TrialManager.shared
        _ = manager.remainingFreeUses // trigger reload
        #expect(manager.isTrialClaimed == false)
    }

    @Test func isTrialRecording_alwaysFalse() async throws {
        let container = try await TestModelContainer.create()
        let context = ModelContext(container)
        let r = Recording(title: "Test", fileURL: "t.m4a")
        context.insert(r)
        #expect(TrialManager.shared.isTrialRecording(r) == false)
    }
}
