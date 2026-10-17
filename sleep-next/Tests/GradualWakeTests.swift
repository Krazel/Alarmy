import XCTest
import AVFoundation
@testable import AlarmaNext

final class GradualWakeTests: XCTestCase {
    func testSystemSoundContainsCrescendoOnBothChannelsAndPreservesOriginal() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("original.caf"), output = directory.appendingPathComponent("crescendo.caf")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 8000, channels: 2))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8000))
        buffer.frameLength = 8000
        for channel in 0..<2 { for frame in 0..<8000 { buffer.floatChannelData![channel][frame] = channel == 0 ? 0.5 : -0.25 } }
        do { let file = try AVAudioFile(forWriting: source, settings: format.settings); try file.write(from: buffer) }
        let before = try Data(contentsOf: source)
        try GradualWake.render(source: source, destination: output)
        XCTAssertEqual(try Data(contentsOf: source), before)
        let file = try AVAudioFile(forReading: output)
        XCTAssertEqual(Double(file.length)/file.processingFormat.sampleRate, 29, accuracy: 0.001)
        XCTAssertEqual(file.fileFormat.commonFormat, .pcmFormatInt16)
        let rendered = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: rendered)
        for channel in 0..<2 {
            let samples = rendered.floatChannelData![channel], amplitude: Float = channel == 0 ? 0.5 : -0.25
            // Inspect actual PCM at start, halfway, full volume and the tail.
            for seconds in [0.0,12.5,25,28] {
                XCTAssertEqual(samples[Int(seconds*8000)], amplitude * GradualWake.gain(at: seconds), accuracy: 0.0001)
            }
            XCTAssertLessThan(abs(samples[0]), abs(samples[100_000]))
            XCTAssertLessThan(abs(samples[100_000]), abs(samples[200_000]))
        }
        #if !targetEnvironment(simulator)
        // Data Protection is a device feature, absent from simulator metadata.
        let attributes = try FileManager.default.attributesOfItem(atPath: output.path)
        let protection = (attributes[.protectionKey] as? FileProtectionType)?.rawValue ?? (attributes[.protectionKey] as? String)
        XCTAssertEqual(protection, FileProtectionType.completeUntilFirstUserAuthentication.rawValue)
        #endif
    }

    func testAlarmSoundSelectionEnabledDisabledAndMissingImport() async throws {
        let unchanged = try await ToneLibrary.alarmFilename("aurora", imported: [], gradual: false)
        XCTAssertEqual(unchanged, "aurora.wav")
        let name = try await ToneLibrary.alarmFilename("aurora", imported: [], gradual: true)
        XCTAssertEqual(name, "gradual-v1-aurora.caf")
        let url = DiskLocation.tones.appendingPathComponent(name)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let contents = try Data(contentsOf: url)
        let cached = try await ToneLibrary.alarmFilename("aurora", imported: [], gradual: true)
        XCTAssertEqual(cached, name); XCTAssertEqual(try Data(contentsOf: url), contents)
        let fallback = try await ToneLibrary.alarmFilename("missing", imported: [], gradual: true)
        XCTAssertEqual(fallback, name)
    }

    @MainActor
    func testDisabledSunriseNeverChangesBrightnessOrAutoLock() {
        let screen = TestWakeScreen(), audio = NightAudio(screen: screen)
        for original in [0.0, 0.4, 1.0] {
            screen.brightness = original
            for minutes in [0,3,5,10,15] {
                for offset in [-600.0,0,600] {
                    audio.updateLight(wake: Date().addingTimeInterval(offset), minutes: minutes)
                    audio.restoreScreen()
                    XCTAssertEqual(screen.brightness, original)
                    XCTAssertFalse(screen.idleDisabled)
                }
            }
        }
    }
}
@MainActor
private final class TestWakeScreen: WakeScreenControl {
    var brightness: CGFloat = 0.7
    var idleDisabled = false
}
