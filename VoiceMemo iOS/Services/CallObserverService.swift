import CallKit
import Observation
import SwiftUI

@Observable
final class CallObserverService: NSObject, CXCallObserverDelegate {
    static let shared = CallObserverService()

    @ObservationIgnored
    @AppStorage("autoRecordCalls") var isAutoRecordEnabled = false

    private let callObserver = CXCallObserver()
    private var isCallActive = false
    @ObservationIgnored
    private var connectivityService: PhoneConnectivityService?

    override init() {
        super.init()
        callObserver.setDelegate(self, queue: nil)
    }

    func configure(connectivity: PhoneConnectivityService) {
        self.connectivityService = connectivity
    }

    // MARK: - CXCallObserverDelegate

    nonisolated func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        Task { @MainActor in
            self.handleCallChange(call)
        }
    }

    @MainActor
    private func handleCallChange(_ call: CXCall) {
        guard isAutoRecordEnabled else { return }

        if call.hasConnected && !call.hasEnded && !isCallActive {
            isCallActive = true
            #if DEBUG
            print("📞 [iOS] Call connected — sending startRecording to Watch")
            #endif
            connectivityService?.sendCommandToWatch(["command": "startRecording"])
        } else if call.hasEnded && isCallActive {
            isCallActive = false
            #if DEBUG
            print("📞 [iOS] Call ended — sending stopRecording to Watch")
            #endif
            connectivityService?.sendCommandToWatch(["command": "stopRecording"])
        }
    }
}
