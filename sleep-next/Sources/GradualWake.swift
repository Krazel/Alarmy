import AVFoundation

/// A system alarm plays a file while the app is suspended. Bake the crescendo
/// into that file; an AVAudioPlayer timer cannot change the system alarm's gain.
enum GradualWake {
    static let soundDuration = 29.0
    static let fadeDuration = 25.0

    static func gain(at seconds: Double) -> Float {
        let progress = max(0, min(1, seconds / fadeDuration))
        // Equal changes in decibels avoid most of the perceived rise happening
        // immediately, as with a linear amplitude ramp.
        return Float(pow(10, (-40 + 40 * progress) / 20))
    }

    static func render(source: URL, destination: URL) throws {
        let input = try AVAudioFile(forReading: source, commonFormat: .pcmFormatFloat32, interleaved: false)
        let format = input.processingFormat
        let count = AVAudioFrameCount(min(input.length, AVAudioFramePosition(format.sampleRate * soundDuration)))
        guard count > 0, let original = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count) else { throw CocoaError(.fileReadCorruptFile) }
        try input.read(into: original, frameCount: count)
        guard original.frameLength > 0, let samples = original.floatChannelData else { throw CocoaError(.fileReadCorruptFile) }
        let frames = AVAudioFrameCount(format.sampleRate * soundDuration)
        guard let rendered = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames), let outputSamples = rendered.floatChannelData else { throw CocoaError(.fileReadCorruptFile) }
        rendered.frameLength = frames
        for frame in 0..<Int(frames) {
            let gain = gain(at: Double(frame) / format.sampleRate)
            for channel in 0..<Int(format.channelCount) {
                outputSamples[channel][frame] = samples[channel][frame % Int(original.frameLength)] * gain
            }
        }
        let directory = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let temporary = directory.appendingPathComponent(UUID().uuidString + ".caf")
        defer { try? FileManager.default.removeItem(at: temporary) }
        // Close the audio file before moving it into the system sound directory.
        do {
            let output = try AVAudioFile(forWriting: temporary, settings: [
                AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: format.channelCount, AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false
            ])
            try output.write(from: rendered)
        }
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: temporary.path)
        try FileManager.default.moveItem(at: temporary, to: destination)
    }
}

extension ToneLibrary {
    static func alarmFilename(_ id: String, imported: [ImportedTone], gradual: Bool) async throws -> String {
        guard gradual else { return filename(id, imported: imported) }
        guard let source = url(id, imported: imported) ?? url("aurora", imported: []) else { throw CocoaError(.fileNoSuchFile) }
        let name = "gradual-v1-" + source.deletingPathExtension().lastPathComponent + ".caf"
        let target = DiskLocation.tones.appendingPathComponent(name)
        if !FileManager.default.fileExists(atPath: target.path) {
            try await Task.detached(priority: .userInitiated) { try GradualWake.render(source: source, destination: target) }.value
        }
        return name
    }
}
