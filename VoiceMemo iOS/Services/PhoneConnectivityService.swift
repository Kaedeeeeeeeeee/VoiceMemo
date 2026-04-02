import WatchConnectivity
import SwiftData
import Observation

@Observable
final class PhoneConnectivityService: NSObject, WCSessionDelegate {
    var isReachable = false
    var isWatchPaired = false
    var isWatchAppInstalled = false
    var receivedFileURL: URL?
    var onRecordingReceived: ((URL, [String: Any]) -> Void)?

    private var wcSession: WCSession?

    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            wcSession = session
            session.delegate = self
            session.activate()
            #if DEBUG
            print("📱 [iOS] WCSession activating...")
            #endif
        } else {
            #if DEBUG
            print("⚠️ [iOS] WCSession not supported on this device")
            #endif
        }
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        #if DEBUG
        print("📱 [iOS] WCSession activation completed: \(activationState.rawValue)")
        print("   - isPaired: \(session.isPaired)")
        print("   - isWatchAppInstalled: \(session.isWatchAppInstalled)")
        print("   - isReachable: \(session.isReachable)")
        print("   - hasContentPending: \(session.hasContentPending)")
        #endif

        Task { @MainActor in
            self.isReachable = session.isReachable
            self.isWatchPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
        if let error {
            #if DEBUG
            print("❌ [iOS] WCSession activation failed: \(error)")
            #endif
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        #if DEBUG
        print("📱 [iOS] WCSession became inactive")
        #endif
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        #if DEBUG
        print("📱 [iOS] WCSession deactivated, reactivating...")
        #endif
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        #if DEBUG
        print("📱 [iOS] WCSession reachability changed: \(session.isReachable)")
        #endif
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        #if DEBUG
        print("📱 [iOS] Watch state changed - isPaired: \(session.isPaired), isWatchAppInstalled: \(session.isWatchAppInstalled)")
        #endif
        Task { @MainActor in
            self.isWatchPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
    }

    func sendCommandToWatch(_ command: [String: Any]) {
        guard let session = wcSession, session.activationState == .activated else {
            #if DEBUG
            print("⚠️ [iOS] WCSession not activated, cannot send command")
            #endif
            return
        }
        guard session.isReachable else {
            #if DEBUG
            print("⚠️ [iOS] Watch not reachable, command not sent")
            #endif
            return
        }
        session.sendMessage(command, replyHandler: nil) { error in
            #if DEBUG
            print("❌ [iOS] Failed to send command to Watch: \(error)")
            #endif
        }
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let metadata = file.metadata ?? [:]
        let sourceURL = file.fileURL

        #if DEBUG
        print("📥 [iOS] Received file from Watch!")
        print("   - Source: \(sourceURL.lastPathComponent)")
        print("   - Metadata: \(metadata)")
        #endif

        // Copy to documents directory
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = sourceURL.lastPathComponent
        let destinationURL = documentsDir.appendingPathComponent(fileName)

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

            // Validate file size
            let copiedAttributes = try? FileManager.default.attributesOfItem(atPath: destinationURL.path)
            let copiedSize = copiedAttributes?[.size] as? Int64 ?? 0

            if copiedSize == 0 {
                #if DEBUG
                print("⚠️ [iOS] Received zero-byte file, discarding: \(fileName)")
                #endif
                try? FileManager.default.removeItem(at: destinationURL)
                return
            }

            if let expectedSize = metadata["fileSize"] as? Int64, expectedSize > 0, copiedSize != expectedSize {
                #if DEBUG
                print("⚠️ [iOS] File size mismatch: expected \(expectedSize), got \(copiedSize). Keeping file.")
                #endif
            }

            #if DEBUG
            print("✅ [iOS] File saved to: \(destinationURL.lastPathComponent)")
            #endif

            Task { @MainActor in
                self.onRecordingReceived?(destinationURL, metadata)
            }
        } catch {
            #if DEBUG
            print("❌ [iOS] Failed to save received file: \(error)")
            #endif
        }
    }
}
