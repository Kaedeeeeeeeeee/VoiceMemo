import WatchConnectivity
import Observation
import SwiftData

@Observable
final class WatchConnectivityService: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityService()

    var isReachable = false
    var isCompanionAppInstalled = false
    var transferProgress: Double = 0
    var lastTransferError: String?
    @ObservationIgnored var modelContainer: ModelContainer?
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

    /// Tell the paired iPhone that recording just started on the Watch,
    /// so the iPhone can put up a Live Activity as a remote-control surface.
    /// We prefer `sendMessage` (low latency when reachable) and fall back
    /// to `transferUserInfo` (queued, guaranteed delivery).
    func notifyRecordingStarted(recordingId: String, title: String, timerStartDate: Date) {
        let payload: [String: Any] = [
            "command": "watchRecordingStarted",
            "recordingId": recordingId,
            "title": title,
            "timerStartDate": timerStartDate.timeIntervalSince1970
        ]
        send(payload)
    }

    func notifyRecordingPaused(recordingId: String, frozenElapsed: TimeInterval) {
        send([
            "command": "watchRecordingPaused",
            "recordingId": recordingId,
            "frozenElapsed": frozenElapsed
        ])
    }

    func notifyRecordingResumed(recordingId: String, timerStartDate: Date) {
        send([
            "command": "watchRecordingResumed",
            "recordingId": recordingId,
            "timerStartDate": timerStartDate.timeIntervalSince1970
        ])
    }

    func notifyRecordingStopped(recordingId: String) {
        send([
            "command": "watchRecordingStopped",
            "recordingId": recordingId
        ])
    }

    private func send(_ payload: [String: Any]) {
        guard let session = wcSession, session.activationState == .activated else { return }
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                #if DEBUG
                print("⚠️ [Watch] sendMessage failed, falling back: \(error.localizedDescription)")
                #endif
                session.transferUserInfo(payload)
            }
        } else {
            session.transferUserInfo(payload)
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

            guard success, let recordingId, let container = self.modelContainer else { return }
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<Recording>(
                predicate: #Predicate { $0.id.uuidString == recordingId }
            )
            if let rec = try? context.fetch(descriptor).first {
                rec.isSynced = true
                try? context.save()
            }
        }
    }
}
