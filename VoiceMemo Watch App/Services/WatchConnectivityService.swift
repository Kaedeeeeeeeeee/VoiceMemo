import WatchConnectivity
import Observation

extension Notification.Name {
    static let fileTransferCompleted = Notification.Name("fileTransferCompleted")
}

@Observable
final class WatchConnectivityService: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityService()

    var isReachable = false
    var isCompanionAppInstalled = false
    var transferProgress: Double = 0
    var lastTransferError: String?
    private var wcSession: WCSession?

    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            wcSession = session
            session.delegate = self
            session.activate()
            #if DEBUG
            print("📱 WCSession activating...")
            #endif
        } else {
            #if DEBUG
            print("⚠️ WCSession not supported")
            #endif
        }
    }

    func sendRecording(url: URL, metadata: [String: Any]) {
        guard let session = wcSession, session.activationState == .activated else {
            #if DEBUG
            print("❌ WCSession not activated, cannot send recording")
            #endif
            return
        }

        #if DEBUG
        print("📤 Sending recording to iPhone...")
        print("   - isCompanionAppInstalled: \(session.isCompanionAppInstalled)")
        print("   - isReachable: \(session.isReachable)")
        print("   - File: \(url.lastPathComponent)")
        print("   - Metadata: \(metadata)")
        #endif

        if !session.isCompanionAppInstalled {
            #if DEBUG
            print("⚠️ Companion iOS app is not installed on iPhone")
            #endif
        }

        let transfer = session.transferFile(url, metadata: metadata)
        #if DEBUG
        print("✅ File transfer started: \(transfer.file.fileURL.lastPathComponent)")
        #endif

        // Check outstanding transfers
        let outstanding = session.outstandingFileTransfers
        #if DEBUG
        print("📋 Outstanding transfers: \(outstanding.count)")
        #endif
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        #if DEBUG
        print("📱 WCSession activation completed: \(activationState.rawValue)")
        print("   - isCompanionAppInstalled: \(session.isCompanionAppInstalled)")
        print("   - isReachable: \(session.isReachable)")
        #endif

        Task { @MainActor in
            self.isReachable = session.isReachable
            self.isCompanionAppInstalled = session.isCompanionAppInstalled
        }
        if let error {
            #if DEBUG
            print("❌ WCSession activation failed: \(error)")
            #endif
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        #if DEBUG
        print("📱 WCSession reachability changed: \(session.isReachable)")
        #endif
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }

    nonisolated func sessionCompanionAppInstalledDidChange(_ session: WCSession) {
        #if DEBUG
        print("📱 Companion app installed changed: \(session.isCompanionAppInstalled)")
        #endif
        Task { @MainActor in
            self.isCompanionAppInstalled = session.isCompanionAppInstalled
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let command = message["command"] as? String else { return }
        #if DEBUG
        print("📱 [Watch] Received command: \(command)")
        #endif
        Task { @MainActor in
            switch command {
            case "startRecording":
                BackgroundRecordingManager.shared.startCallRecording()
            case "stopRecording":
                BackgroundRecordingManager.shared.stopCallRecording()
            default:
                break
            }
        }
    }

    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        let metadata = fileTransfer.file.metadata ?? [:]
        let recordingId = metadata["id"] as? String
        let success = error == nil

        #if DEBUG
        if let error {
            print("❌ File transfer failed: \(error.localizedDescription)")
        } else {
            print("✅ File transfer completed for: \(fileTransfer.file.fileURL.lastPathComponent)")
        }
        #endif

        Task { @MainActor in
            self.lastTransferError = error?.localizedDescription
        }

        NotificationCenter.default.post(
            name: .fileTransferCompleted,
            object: nil,
            userInfo: [
                "recordingId": recordingId ?? "",
                "success": success
            ]
        )
    }
}
