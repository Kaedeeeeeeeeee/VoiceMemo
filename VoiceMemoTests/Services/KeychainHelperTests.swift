import Testing
import Foundation
@testable import VoiceMemo_iOS

@Suite("KeychainHelper Tests")
struct KeychainHelperTests {

    @Test func saveAndLoadString() {
        let key = "test_string_\(UUID().uuidString)"
        defer { KeychainHelper.delete(forKey: key) }

        let saved = KeychainHelper.save("hello_world", forKey: key)
        #expect(saved == true)

        let loaded = KeychainHelper.loadString(forKey: key)
        #expect(loaded == "hello_world")
    }

    @Test func saveAndLoadData() {
        let key = "test_data_\(UUID().uuidString)"
        defer { KeychainHelper.delete(forKey: key) }

        let data = Data([0x01, 0x02, 0x03])
        let saved = KeychainHelper.save(data, forKey: key)
        #expect(saved == true)

        let loaded = KeychainHelper.load(forKey: key)
        #expect(loaded == data)
    }

    @Test func loadNonExistentKey() {
        let key = "nonexistent_\(UUID().uuidString)"
        #expect(KeychainHelper.load(forKey: key) == nil)
        #expect(KeychainHelper.loadString(forKey: key) == nil)
    }

    @Test func deleteRemovesValue() {
        let key = "test_delete_\(UUID().uuidString)"
        KeychainHelper.save("to_delete", forKey: key)
        KeychainHelper.delete(forKey: key)
        #expect(KeychainHelper.loadString(forKey: key) == nil)
    }

    @Test func overwriteValue() {
        let key = "test_overwrite_\(UUID().uuidString)"
        defer { KeychainHelper.delete(forKey: key) }

        KeychainHelper.save("first", forKey: key)
        KeychainHelper.save("second", forKey: key)
        #expect(KeychainHelper.loadString(forKey: key) == "second")
    }

    @Test func saveEmptyString() {
        let key = "test_empty_\(UUID().uuidString)"
        defer { KeychainHelper.delete(forKey: key) }

        let saved = KeychainHelper.save("", forKey: key)
        #expect(saved == true)

        let loaded = KeychainHelper.loadString(forKey: key)
        #expect(loaded == "")
    }
}
