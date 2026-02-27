import WatchConnectivity
import Observation

@Observable
final class WatchConnectivityService: NSObject, WCSessionDelegate {
    var isReachable = false
    var transferProgress: Double = 0
    private var wcSession: WCSession?

    override init() {
        super.init()
        if WCSession.isSupported() {
            wcSession = WCSession.default
            wcSession?.delegate = self
            wcSession?.activate()
        }
    }

    func sendRecording(url: URL, metadata: [String: Any]) {
        guard let session = wcSession, session.activationState == .activated else {
            print("WCSession not activated")
            return
        }

        let transfer = session.transferFile(url, metadata: metadata)
        print("Started file transfer: \(transfer)")
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
        if let error {
            print("WCSession activation failed: \(error)")
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }
}
