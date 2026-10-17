import SwiftUI
import AVFoundation

enum ClipEnvelope {
    static func read(_ url: URL, buckets: Int = 96) throws -> [Double] {
        let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        guard file.length > 0, buckets > 0, let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 4096) else { return [] }
        var peaks = Array(repeating: 0.0, count: buckets)
        while file.framePosition < file.length {
            if Task.isCancelled { return [] }
            let start = file.framePosition
            try file.read(into: buffer, frameCount: 4096)
            guard buffer.frameLength > 0, let channels = buffer.floatChannelData else { break }
            for frame in 0..<Int(buffer.frameLength) {
                let bucket = min(buckets-1, Int(Double(start + Int64(frame)) / Double(file.length) * Double(buckets)))
                for channel in 0..<Int(file.processingFormat.channelCount) { peaks[bucket] = max(peaks[bucket], Double(abs(channels[channel][frame]))) }
            }
        }
        let peak = max(0.001, peaks.max() ?? 0)
        return peaks.map { $0 / peak }
    }
}

struct RecordedWaveform: View {
    let values: [Double]
    var progress: Double
    var body: some View {
        Canvas { ctx, size in
            let count = max(1, values.count)
            for (index, value) in values.enumerated() {
                let height = max(2, min(1, value) * (size.height-8))
                let x = Double(index) / Double(count) * size.width
                let rect = CGRect(x: x, y: (size.height-height)/2, width: max(1, size.width/Double(count)*0.48), height: height)
                ctx.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(Color.ink.opacity(Double(index)/Double(count) <= progress ? 1 : 0.3)))
            }
        }.accessibilityHidden(true)
    }
}
