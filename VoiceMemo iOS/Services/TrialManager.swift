import Foundation
import Security
import Observation

@Observable
final class TrialManager {
    static let shared = TrialManager()

    private(set) var trialRecordingID: UUID?

    private static let userDefaultsKey = "trialRecordingID"
    private static let keychainService = "com.podnote.trial"
    private static let keychainAccount = "trialRecordingID"

    private init() {
        trialRecordingID = loadTrialID()
    }

    // MARK: - Public API

    /// Whether the user can access AI features for the given recording.
    /// Returns true if subscribed, or if this is the trial recording.
    func canAccessAI(for recording: Recording) -> Bool {
        if SubscriptionManager.shared.isSubscribed { return true }
        if let trialID = trialRecordingID, trialID == recording.id { return true }
        return false
    }

    /// Attempts to claim the trial for this recording.
    /// Returns true if AI access is granted (subscribed or trial claimed).
    /// Returns false if trial was already claimed for another recording.
    func claimTrialIfNeeded(for recording: Recording) -> Bool {
        if SubscriptionManager.shared.isSubscribed { return true }

        // Already the trial recording
        if let trialID = trialRecordingID, trialID == recording.id { return true }

        // Trial not yet claimed — claim it
        if trialRecordingID == nil {
            trialRecordingID = recording.id
            saveTrialID(recording.id)
            return true
        }

        // Trial already claimed for a different recording
        return false
    }

    /// Whether the given recording is the trial recording.
    func isTrialRecording(_ recording: Recording) -> Bool {
        trialRecordingID == recording.id
    }

    /// Whether any trial has been claimed.
    var isTrialClaimed: Bool {
        trialRecordingID != nil
    }

    // MARK: - Persistence

    private func loadTrialID() -> UUID? {
        // Prefer Keychain (survives uninstall)
        if let keychainValue = loadFromKeychain() {
            // Sync to UserDefaults if missing
            if UserDefaults.standard.string(forKey: Self.userDefaultsKey) == nil {
                UserDefaults.standard.set(keychainValue.uuidString, forKey: Self.userDefaultsKey)
            }
            return keychainValue
        }

        // Fallback to UserDefaults
        if let stored = UserDefaults.standard.string(forKey: Self.userDefaultsKey),
           let uuid = UUID(uuidString: stored) {
            // Sync to Keychain
            saveToKeychain(uuid)
            return uuid
        }

        return nil
    }

    private func saveTrialID(_ id: UUID) {
        UserDefaults.standard.set(id.uuidString, forKey: Self.userDefaultsKey)
        saveToKeychain(id)
    }

    // MARK: - Keychain

    private func saveToKeychain(_ id: UUID) {
        let data = id.uuidString.data(using: .utf8)!

        // Delete existing
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func loadFromKeychain() -> UUID? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8),
              let uuid = UUID(uuidString: string) else {
            return nil
        }

        return uuid
    }
}
