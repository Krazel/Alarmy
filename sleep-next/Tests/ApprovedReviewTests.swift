import XCTest
import AVFoundation
@testable import AlarmaNext

final class ApprovedReviewTests: XCTestCase {
    func testFixedAndLegacyRandomSoundSelection() throws {
        var plan = AlarmPlan()
        plan.sounds = ["aurora", "brisa"]
        XCTAssertTrue(plan.shuffled)
        XCTAssertEqual(plan.sound(excluding: "aurora"), "brisa")
        plan.shuffle = false
        XCTAssertEqual(plan.sound(excluding: "aurora"), "aurora")
        let copy = try JSONDecoder().decode(AlarmPlan.self, from: JSONEncoder().encode(plan))
        XCTAssertFalse(copy.shuffled)
        plan.sounds = []
        XCTAssertEqual(plan.sound(excluding: nil), "aurora")
    }

    func testWaveformReadsLocalAudioAndPreservesSilence() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        defer { try? FileManager.default.removeItem(at: url) }
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 8000, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8000))
        buffer.frameLength = 8000
        for i in 0..<8000 { buffer.floatChannelData![0][i] = i < 4000 ? 0 : 0.5 }
        do { let file = try AVAudioFile(forWriting: url, settings: format.settings); try file.write(from: buffer) }
        let wave = try ClipEnvelope.read(url, buckets: 8)
        XCTAssertEqual(Array(wave.prefix(4)), [0,0,0,0])
        XCTAssertEqual(Array(wave.suffix(4)), [1,1,1,1])
    }
}
