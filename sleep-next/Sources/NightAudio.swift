import AVFoundation
import UIKit
import CoreMotion

@MainActor
final class NightAudio: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var playing: String?
    private var player: AVAudioPlayer?
    private var recorder: AVAudioRecorder?
    private var meter: Timer?
    private var ramp: Timer?
    private var peak: Float = -160
    private var segmentStart = Date()
    private var segmentURL: URL?
    private var receive: ((NightClip) -> Void)?
    var onFailure: ((Error) -> Void)?
    private let motion = CMMotionManager()
    private var previousBrightness: CGFloat?
    private var previousIdle: Bool?
    var isRecording: Bool { recorder?.isRecording == true }

    func microphoneAllowed() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
        }
    }
    func startRecording(receive: @escaping (NightClip) -> Void) throws {
        self.receive = receive
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
        try FileManager.default.createDirectory(at: DiskLocation.clips, withIntermediateDirectories: true)
        try newSegment()
        meter = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
            guard let self, self.recorder != nil else { return }
            self.recorder?.updateMeters()
            self.peak = max(self.peak, self.recorder?.averagePower(forChannel: 0) ?? -160)
            if Date().timeIntervalSince(self.segmentStart) >= 30 {
                self.finishSegment()
                do { try self.newSegment() } catch { self.stopRecording(); self.onFailure?(error) }
            }
            }
        }
    }
    private func newSegment() throws {
        let url = DiskLocation.clips.appendingPathComponent(UUID().uuidString + ".m4a")
        let rec = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 22050, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 32000])
        rec.isMeteringEnabled = true
        guard rec.record() else { throw CocoaError(.fileWriteUnknown) }
        recorder = rec; segmentURL = url; segmentStart = Date(); peak = -160
    }
    private func finishSegment() {
        recorder?.stop(); recorder = nil
        guard let url = segmentURL else { return }; segmentURL = nil
        let duration = Date().timeIntervalSince(segmentStart)
        if peak > -35 && duration >= 2 {
            receive?(NightClip(id: UUID(), created: segmentStart, filename: url.lastPathComponent, duration: min(30, duration)))
        } else { try? FileManager.default.removeItem(at: url) }
    }
    func stopRecording() { meter?.invalidate(); meter = nil; finishSegment(); receive = nil }
    func play(url: URL, id: String, loop: Bool = false, gradual: Bool = false) throws {
        stopPlayback()
        let session = AVAudioSession.sharedInstance()
        if !isRecording { try session.setCategory(.playback, mode: .default) }
        try session.setActive(true)
        let audio = try AVAudioPlayer(contentsOf: url)
        audio.delegate = self; audio.numberOfLoops = loop ? -1 : 0; audio.volume = gradual ? 0.05 : 1
        guard audio.play() else { throw CocoaError(.fileReadUnknown) }
        player = audio; playing = id
        if gradual {
            ramp = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
                Task { @MainActor in
                guard let player = self?.player else { timer.invalidate(); return }
                player.volume = min(1, player.volume + 0.025)
                if player.volume >= 1 { timer.invalidate() }
                }
            }
        }
    }
    func stopPlayback() { ramp?.invalidate(); ramp = nil; player?.stop(); player = nil; playing = nil }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) { Task { @MainActor in self.stopPlayback() } }
    func watchMovement(action: @escaping () -> Void) {
        guard motion.isAccelerometerAvailable else { return }
        motion.accelerometerUpdateInterval = 0.2
        let after = Date().addingTimeInterval(3)
        motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let a = data?.acceleration, Date() > after else { return }
            if sqrt(a.x*a.x + a.y*a.y + a.z*a.z) > 1.65 { self?.motion.stopAccelerometerUpdates(); action() }
        }
    }
    func updateLight(wake: Date, minutes: Int) {
        guard minutes > 0 else { return }
        if previousBrightness == nil { previousBrightness = UIScreen.main.brightness; previousIdle = UIApplication.shared.isIdleTimerDisabled }
        UIApplication.shared.isIdleTimerDisabled = true
        let fraction = 1 - wake.timeIntervalSinceNow / Double(minutes * 60)
        if fraction > 0 { UIScreen.main.brightness = max(previousBrightness ?? 0.2, min(1, fraction)) }
    }
    func restoreScreen() {
        motion.stopAccelerometerUpdates()
        if let previousBrightness { UIScreen.main.brightness = previousBrightness }; previousBrightness = nil
        if let previousIdle { UIApplication.shared.isIdleTimerDisabled = previousIdle }; previousIdle = nil
    }
    func stopAll() {
        stopRecording(); stopPlayback(); restoreScreen()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

struct ToneLibrary {
    static let builtins = ["aurora", "lumen", "brisa"]
    static func url(_ id: String, imported: [ImportedTone]) -> URL? {
        if builtins.contains(id) { return Bundle.main.url(forResource: id, withExtension: "wav") }
        guard let tone = imported.first(where: { $0.id == id }) else { return nil }
        return DiskLocation.child(tone.filename, of: DiskLocation.tones)
    }
    static func filename(_ id: String, imported: [ImportedTone]) -> String { imported.first { $0.id == id }?.filename ?? "\(id).wav" }
    static func prepare(_ source: URL) throws -> ImportedTone {
        let access = source.startAccessingSecurityScopedResource(); defer { if access { source.stopAccessingSecurityScopedResource() } }
        try FileManager.default.createDirectory(at: DiskLocation.tones, withIntermediateDirectories: true)
        let input = try AVAudioFile(forReading: source)
        let format = input.processingFormat
        let frames = min(input.length, AVAudioFramePosition(format.sampleRate * 29))
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)) else { throw CocoaError(.fileReadCorruptFile) }
        try input.read(into: buffer, frameCount: AVAudioFrameCount(frames))
        let id = UUID().uuidString; let filename = id + ".caf"
        let target = DiskLocation.tones.appendingPathComponent(filename)
        do {
            let output = try AVAudioFile(forWriting: target, settings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: format.sampleRate, AVNumberOfChannelsKey: format.channelCount, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false])
            try output.write(from: buffer)
        } catch { try? FileManager.default.removeItem(at: target); throw error }
        return ImportedTone(id: id, name: source.deletingPathExtension().lastPathComponent, filename: filename)
    }
}
