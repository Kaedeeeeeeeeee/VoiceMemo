import AVFoundation
import WatchKit
import WidgetKit
import Observation

@Observable
final class WatchAudioRecorder: NSObject, WKExtendedRuntimeSessionDelegate {
    var isRecording = false
    var isPaused = false
    var currentTime: TimeInterval = 0
    var averagePower: Float = 0

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var timer: Timer?
    private var session: WKExtendedRuntimeSession?

    // Stable identifier for this recording, used to route iPhone-side
    // Live Activity events (the iPhone creates an activity with this id
    // so that lock-screen marker/photo buttons can tag their pending
    // actions with the right recording).
    private(set) var activeRecordingId: String?

    override init() {
        super.init()
    }

    func startRecording() -> URL? {
        // Lightweight steps on main thread for instant UI feedback.
        isRecording = true
        isPaused = false
        currentTime = 0
        averagePower = 0

        let url = Self.newRecordingURL()
        self.recordingURL = url

        let recordingId = UUID().uuidString
        activeRecordingId = recordingId
        let startDate = Date.now

        // Tell the iPhone to bring up a Live Activity remote-control surface.
        WatchConnectivityService.shared.notifyRecordingStarted(
            recordingId: recordingId,
            title: Date.now.recordingTitle,
            timerStartDate: startDate
        )

        // Immediate haptic so the press feels responsive.
        WKInterfaceDevice.current().play(.start)

        // Extended runtime session is cheap to start on main (actual acquisition
        // is async via its delegate), and we need it up front so watchOS doesn't
        // throttle the app while we're waiting on the AVAudioSession to activate.
        startExtendedSession()

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        // AVAudioSession.setActive(true) routinely takes 200–600ms on watchOS.
        // Running it on the main thread stalls the navigation-push animation
        // into RecordingView, which is the "cold start" jank the user feels.
        // Move it, plus AVAudioRecorder creation and the actual .record() kick,
        // onto a background task; hop back to main to commit the recorder and
        // start the metering timer once audio is actually rolling.
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let avSession = AVAudioSession.sharedInstance()
                // setCategory is idempotent and is already pre-warmed in
                // VoiceMemoApp.init(), so this call is essentially a no-op
                // but kept for correctness on cold paths.
                try avSession.setCategory(.record, mode: .default)
                try avSession.setActive(true)

                let recorder = try AVAudioRecorder(url: url, settings: settings)
                recorder.isMeteringEnabled = true
                recorder.record()

                await MainActor.run {
                    guard let self else { return }
                    // Guard against the user cancelling the recording before
                    // the background task finishes (stopRecording was called
                    // during the setup window).
                    guard self.isRecording, self.recordingURL == url else {
                        recorder.stop()
                        try? AVAudioSession.sharedInstance().setActive(false)
                        return
                    }
                    self.audioRecorder = recorder
                    self.startTimer()
                }
            } catch {
                #if DEBUG
                print("Failed to start recording: \(error)")
                #endif
                await MainActor.run {
                    guard let self else { return }
                    self.isRecording = false
                    self.recordingURL = nil
                    self.stopExtendedSession()
                }
            }
        }

        return url
    }

    func stopRecording() -> (url: URL, duration: TimeInterval)? {
        // Handle cancellation during the async startup window where the
        // recorder hasn't been wired up yet but the UI already thinks we're
        // recording. Clean up state and tell the caller there's nothing
        // to save. The detached task in startRecording() sees isRecording
        // flip to false and bails out as well.
        guard let recorder = audioRecorder, let url = recordingURL else {
            isRecording = false
            isPaused = false
            currentTime = 0
            averagePower = 0
            stopExtendedSession()
            recordingURL = nil
            return nil
        }

        let duration = recorder.currentTime
        recorder.stop()

        if let recordingId = activeRecordingId {
            WatchConnectivityService.shared.notifyRecordingStopped(recordingId: recordingId)
        }
        activeRecordingId = nil

        isRecording = false
        isPaused = false
        currentTime = 0
        averagePower = 0

        stopTimer()
        stopExtendedSession()
        WKInterfaceDevice.current().play(.stop)

        audioRecorder = nil
        recordingURL = nil

        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            #if DEBUG
            print("Failed to deactivate audio session: \(error)")
            #endif
        }

        // Save last recording info for Widget
        saveLastRecordingInfo(title: url.deletingPathExtension().lastPathComponent)

        return (url, duration)
    }

    func pauseRecording() {
        audioRecorder?.pause()
        isPaused = true
        stopTimer()
        WKInterfaceDevice.current().play(.click)
        if let recordingId = activeRecordingId {
            WatchConnectivityService.shared.notifyRecordingPaused(
                recordingId: recordingId,
                frozenElapsed: currentTime
            )
        }
    }

    func resumeRecording() {
        audioRecorder?.record()
        isPaused = false
        startTimer()
        WKInterfaceDevice.current().play(.click)
        if let recordingId = activeRecordingId {
            WatchConnectivityService.shared.notifyRecordingResumed(
                recordingId: recordingId,
                timerStartDate: Date.now.addingTimeInterval(-currentTime)
            )
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let recorder = self.audioRecorder else { return }
            recorder.updateMeters()
            self.currentTime = recorder.currentTime
            self.averagePower = recorder.averagePower(forChannel: 0)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func startExtendedSession() {
        let newSession = WKExtendedRuntimeSession()
        newSession.delegate = self
        session = newSession
        newSession.start()
    }

    private func stopExtendedSession() {
        session?.invalidate()
        session = nil
    }

    // MARK: - WKExtendedRuntimeSessionDelegate

    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        #if DEBUG
        print("⌚️ Extended runtime session started")
        #endif
    }

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        #if DEBUG
        print("⌚️ Extended runtime session will expire")
        #endif
    }

    func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {
        #if DEBUG
        print("⌚️ Extended runtime session invalidated: reason=\(reason.rawValue) error=\(error?.localizedDescription ?? "nil")")
        #endif
    }

    static func newRecordingURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "recording_\(UUID().uuidString).m4a"
        return documentsPath.appendingPathComponent(fileName)
    }

    static func recordingsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func saveLastRecordingInfo(title: String) {
        let defaults = UserDefaults(suiteName: "group.com.zhangshifeng.VoiceMemo")
        defaults?.set(title, forKey: "lastRecordingTitle")
        defaults?.set(Date.now.timeIntervalSince1970, forKey: "lastRecordingDate")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
