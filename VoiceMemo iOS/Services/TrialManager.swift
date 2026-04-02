import Foundation
import Security
import Observation

@Observable
final class TrialManager {
    static let shared = TrialManager()

    private(set) var monthlyAIUsageCount: Int = 0
    private(set) var currentMonth: String = ""

    private static let usageCountKey = "monthlyAIUsageCount"
    private static let currentMonthKey = "monthlyAICurrentMonth"
    private static let maxFreeAIPerMonth = 3

    // Legacy keys for migration
    private static let legacyUserDefaultsKey = "trialRecordingID"
    private static let keychainService = "com.podnote.trial"
    private static let keychainAccount = "trialRecordingID"

    private init() {
        resetIfNewMonth()
    }

    // MARK: - Public API

    /// Whether the user can access AI features.
    /// Returns true if subscribed, or if monthly free AI uses haven't been exhausted.
    func canAccessAI(for recording: Recording) -> Bool {
        if SubscriptionManager.shared.isSubscribed { return true }
        resetIfNewMonth()
        return monthlyAIUsageCount < Self.maxFreeAIPerMonth
    }

    /// Attempts to use a free AI credit.
    /// Returns true if AI access is granted (subscribed or free uses remaining).
    /// Returns false if free uses exhausted — caller should show paywall.
    func claimTrialIfNeeded() -> Bool {
        if SubscriptionManager.shared.isSubscribed { return true }
        resetIfNewMonth()

        if monthlyAIUsageCount < Self.maxFreeAIPerMonth {
            monthlyAIUsageCount += 1
            saveUsage()
            return true
        }

        return false
    }

    /// Attempts to use a free AI credit for this recording.
    /// Returns true if AI access is granted (subscribed or free uses remaining).
    /// Returns false if free uses exhausted — caller should show paywall.
    func claimTrialIfNeeded(for recording: Recording) -> Bool {
        if SubscriptionManager.shared.isSubscribed { return true }
        resetIfNewMonth()

        if monthlyAIUsageCount < Self.maxFreeAIPerMonth {
            monthlyAIUsageCount += 1
            saveUsage()
            return true
        }

        return false
    }

    /// Number of free AI uses remaining this month.
    var remainingFreeUses: Int {
        resetIfNewMonth()
        return max(0, Self.maxFreeAIPerMonth - monthlyAIUsageCount)
    }

    /// Whether any trial has been claimed (for backward compat with UI).
    var isTrialClaimed: Bool {
        monthlyAIUsageCount > 0
    }

    /// Whether the given recording is a trial recording (always false in new model).
    func isTrialRecording(_ recording: Recording) -> Bool {
        false
    }

    // MARK: - Month Reset

    private func resetIfNewMonth() {
        let thisMonth = Self.monthKey()
        if currentMonth != thisMonth {
            currentMonth = thisMonth
            monthlyAIUsageCount = 0
            saveUsage()
        } else {
            loadUsage()
        }
    }

    private static func monthKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }

    // MARK: - Persistence

    private func loadUsage() {
        let savedMonth = UserDefaults.standard.string(forKey: Self.currentMonthKey) ?? ""
        if savedMonth == currentMonth {
            monthlyAIUsageCount = UserDefaults.standard.integer(forKey: Self.usageCountKey)
        } else {
            monthlyAIUsageCount = 0
        }
    }

    private func saveUsage() {
        UserDefaults.standard.set(currentMonth, forKey: Self.currentMonthKey)
        UserDefaults.standard.set(monthlyAIUsageCount, forKey: Self.usageCountKey)
    }
}
