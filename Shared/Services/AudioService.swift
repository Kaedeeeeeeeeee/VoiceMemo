import Foundation

protocol AudioRecorderProtocol: AnyObject {
    var isRecording: Bool { get }
    var currentTime: TimeInterval { get }
    var averagePower: Float { get }
    func startRecording() -> URL?
    func stopRecording() -> (url: URL, duration: TimeInterval)?
    func pauseRecording()
    func resumeRecording()
}

protocol AudioPlayerProtocol: AnyObject {
    var isPlaying: Bool { get }
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }
    func play(url: URL)
    func pause()
    func stop()
    func seek(to time: TimeInterval)
    func setRate(_ rate: Float)
}
