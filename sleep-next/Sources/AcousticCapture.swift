import Foundation

/// Deterministic 20 ms detector shared by live microphone and controlled-file tests.
final class AcousticSegmenter {
    enum Action { case begin(Int64, [Float]), append([Float]), end }
    let sampleRate: Double
    let margin: Double
    private let window: Int
    private var pending: [Float] = []
    private var ring: [[Float]] = []
    private var floorSamples: [Double] = []
    private var cursor: Int64 = 0
    private var attack = 0
    private var quiet = 0
    private var length = 0
    private var active = false
    private var continuing = false
    private(set) var noiseFloor = -65.0
    private(set) var level = -100.0
    private(set) var calibrated = false
    var emit: (Action) throws -> Void
    init(sampleRate: Double, margin: Double = 10, emit: @escaping (Action) throws -> Void) {
        self.sampleRate = sampleRate; self.margin = margin; self.emit = emit
        window = max(1, Int(sampleRate * 0.02))
    }
    func feed(_ samples: [Float]) throws {
        pending.append(contentsOf: samples)
        var offset = 0
        while pending.count - offset >= window {
            try frame(Array(pending[offset..<offset+window])); offset += window
        }
        if offset > 0 { pending.removeFirst(offset) }
    }
    private func frame(_ samples: [Float]) throws {
        cursor += Int64(samples.count)
        let power = samples.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(samples.count)
        level = max(-100, 10 * log10(max(1e-10, power)))
        if !active {
            floorSamples.append(level)
            if floorSamples.count > 500 { floorSamples.removeFirst() }
            if floorSamples.count >= 50 {
                calibrated = true
                if floorSamples.count % 5 == 0 {
                    let ordered = floorSamples.sorted()
                    noiseFloor = min(-25, max(-85, ordered[ordered.count/5]))
                }
            }
        }
        let loud = calibrated && level > max(-65, noiseFloor + margin)
        if active {
            try emit(.append(samples)); length += samples.count
            quiet = loud ? 0 : quiet + samples.count
            if quiet >= Int(sampleRate * 2) || length >= Int(sampleRate * 30) {
                try emit(.end); active = false; attack = 0
                continuing = quiet < Int(sampleRate * 2)
                ring.removeAll(); length = 0; quiet = 0
            }
        } else {
            ring.append(samples)
            while ring.count > 100 { ring.removeFirst() }
            attack = loud ? attack + samples.count : 0
            if attack >= Int(sampleRate * 0.06) {
                let lead = ring.flatMap { $0 }
                let begin = cursor - Int64(lead.count)
                try emit(.begin(begin, lead)); length = lead.count
                active = true; continuing = false; quiet = 0; ring.removeAll()
            } else if !loud { continuing = false }
        }
    }
    func finish() throws {
        if !pending.isEmpty { let tail = pending; pending.removeAll(); try frame(tail) }
        if active { try emit(.end); active = false }
        ring.removeAll()
    }
}

struct ClipReceipt: Codable {
    let nightID: UUID
    let clip: NightClip
}
struct OpenClip: Codable {
    let nightID: UUID
    let id: UUID
    let created: Date
    let sampleRate: Double
}
/// A tiny write-ahead spool. PCM can be recovered even if the process dies before
/// an audio container header or the main archive has been finalised.
final class ClipSpool {
    let directory: URL
    private var handle: FileHandle?
    private var current: OpenClip?
    private var lastSync = 0
    private var bytes = 0
    init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        var url = directory; var values = URLResourceValues(); values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }
    private func url(_ id: UUID, _ ext: String) -> URL { directory.appendingPathComponent(id.uuidString + ext) }
    func begin(nightID: UUID, created: Date, sampleRate: Double) throws {
        guard handle == nil else { throw CocoaError(.fileWriteUnknown) }
        let value = OpenClip(nightID: nightID, id: UUID(), created: created, sampleRate: sampleRate)
        try JSONEncoder().encode(value).write(to: url(value.id, ".open.json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        try Data().write(to: url(value.id, ".pcm"), options: .completeFileProtectionUntilFirstUserAuthentication)
        handle = try FileHandle(forWritingTo: url(value.id, ".pcm")); current = value; bytes = 0; lastSync = 0
    }
    func append(_ samples: [Float]) throws {
        guard let handle else { throw CocoaError(.fileWriteUnknown) }
        var data = Data(capacity: samples.count * 2)
        for sample in samples {
            let safe = sample.isFinite ? max(-1, min(1, sample)) : 0
            var value = Int16(safe * 32767).littleEndian
            withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
        }
        try handle.write(contentsOf: data); bytes += data.count
        if bytes - lastSync >= 96000 { try handle.synchronize(); lastSync = bytes }
    }
    func close() throws -> ClipReceipt? {
        guard let value = current else { return nil }
        try handle?.synchronize(); try handle?.close(); handle = nil; current = nil
        return try finalize(value)
    }
    private func finalize(_ value: OpenClip) throws -> ClipReceipt? {
        let raw = url(value.id, ".pcm")
        guard FileManager.default.fileExists(atPath: raw.path) else {
            if FileManager.default.fileExists(atPath: url(value.id, ".receipt.json").path) { try FileManager.default.removeItem(at: url(value.id, ".open.json")) }
            return nil
        }
        var pcm = try Data(contentsOf: raw); if pcm.count % 2 != 0 { pcm.removeLast() }
        if pcm.isEmpty { try FileManager.default.removeItem(at: raw); try FileManager.default.removeItem(at: url(value.id, ".open.json")); return nil }
        guard pcm.count <= 32_000_000, value.sampleRate >= 8000, value.sampleRate <= 192000 else { throw CocoaError(.fileReadCorruptFile) }
        var wav = Data()
        func string(_ s: String) { wav.append(contentsOf: s.utf8) }
        func u32(_ n: UInt32) { var n = n.littleEndian; withUnsafeBytes(of: &n) { wav.append(contentsOf: $0) } }
        func u16(_ n: UInt16) { var n = n.littleEndian; withUnsafeBytes(of: &n) { wav.append(contentsOf: $0) } }
        string("RIFF"); u32(UInt32(pcm.count + 36)); string("WAVEfmt "); u32(16); u16(1); u16(1)
        u32(UInt32(value.sampleRate)); u32(UInt32(value.sampleRate)*2); u16(2); u16(16); string("data"); u32(UInt32(pcm.count)); wav.append(pcm)
        let filename = value.id.uuidString + ".wav"
        try wav.write(to: directory.appendingPathComponent(filename), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        let receipt = ClipReceipt(nightID: value.nightID, clip: NightClip(id: value.id, created: value.created, filename: filename, duration: Double(pcm.count)/2/value.sampleRate))
        try JSONEncoder().encode(receipt).write(to: url(value.id, ".receipt.json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        try FileManager.default.removeItem(at: raw)
        try FileManager.default.removeItem(at: url(value.id, ".open.json"))
        return receipt
    }
    private(set) var recoveryFailures = 0
    func recover() throws -> [ClipReceipt] {
        for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) where file.lastPathComponent.hasSuffix(".open.json") {
            do { let value = try JSONDecoder().decode(OpenClip.self, from: Data(contentsOf: file)); _ = try finalize(value) } catch { recoveryFailures += 1 }
        }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasSuffix(".receipt.json") }.compactMap { file in
            guard let data = try? Data(contentsOf: file) else { return nil }
            do {
                let value = try JSONDecoder().decode(ClipReceipt.self, from: data)
                guard value.clip.filename == value.clip.id.uuidString + ".wav" else { recoveryFailures += 1; return nil }
                return value
            } catch { recoveryFailures += 1; return nil }
        }
    }
    static func acknowledge(_ receipt: ClipReceipt, directory: URL) throws {
        let file = directory.appendingPathComponent(receipt.clip.id.uuidString + ".receipt.json")
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
    }
}

/// All disk work and detector state are confined to this queue, not the render thread.
final class CaptureWorker: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.krazel.alarma.capture", qos: .utility)
    private let slots = DispatchSemaphore(value: 16)
    private let overflowLock = NSLock()
    private var overflowReported = false
    private let spool: ClipSpool
    private var detector: AcousticSegmenter!
    private var closed = false
    private var frames: Int64 = 0
    private var progressFrames: Int64 = 0
    private let start: Date
    private let deadline: Date
    private let rate: Double
    private var written = 0
    private let byteLimit: Int
    let receipt: (ClipReceipt) -> Void
    let progress: (Date, Double, Bool) -> Void
    let failure: (Error) -> Void
    let deadlineReached: () -> Void
    init(nightID: UUID, start: Date, deadline: Date, rate: Double, margin: Double, directory: URL, byteLimit: Int = 256*1024*1024, receipt: @escaping (ClipReceipt) -> Void, progress: @escaping (Date, Double, Bool) -> Void, failure: @escaping (Error) -> Void, deadlineReached: @escaping () -> Void) throws {
        spool = try ClipSpool(directory: directory); self.start = start; self.deadline = deadline; self.rate = rate; self.byteLimit = byteLimit
        self.receipt = receipt; self.progress = progress; self.failure = failure; self.deadlineReached = deadlineReached
        detector = AcousticSegmenter(sampleRate: rate, margin: margin) { [weak self] action in
            guard let self else { return }
            switch action {
            case .begin(let frame, let samples):
                try self.spool.begin(nightID: nightID, created: start.addingTimeInterval(Double(frame)/rate), sampleRate: rate)
                try self.write(samples)
            case .append(let samples): try self.write(samples)
            case .end: if let saved = try self.spool.close() { receipt(saved) }
            }
        }
    }
    private func write(_ samples: [Float]) throws {
        guard written + samples.count*2 <= byteLimit else { throw CocoaError(.fileWriteOutOfSpace) }
        try spool.append(samples); written += samples.count*2
    }
    func enqueue(_ samples: [Float]) {
        guard slots.wait(timeout: .now()) == .success else {
            if overflowLock.try() {
                if !overflowReported { overflowReported = true; queue.async { self.abort(CocoaError(.fileWriteUnknown)) } }
                overflowLock.unlock()
            }; return
        }
        queue.async { defer { self.slots.signal() }; self.process(samples) }
    }
    private func process(_ samples: [Float]) {
        guard !closed else { return }
        do {
            let available = max(0, Int64(deadline.timeIntervalSince(start)*rate) - frames)
            let count = min(samples.count, Int(available))
            if count > 0 { try detector.feed(Array(samples.prefix(count))); frames += Int64(count) }
            if frames - progressFrames >= Int64(rate) { progressFrames = frames; progress(start.addingTimeInterval(Double(frames)/rate), detector.level, detector.calibrated) }
            if count < samples.count { try finish(); deadlineReached() }
        } catch { if closed { failure(error) } else { abort(error) } }
    }
    private func finish() throws {
        guard !closed else { return }; closed = true
        try detector.finish()
        progress(start.addingTimeInterval(Double(frames)/rate), detector.level, detector.calibrated)
    }
    private func abort(_ error: Error) {
        guard !closed else { return }
        closed = true
        if let saved = try? spool.close() { receipt(saved) }
        failure(error)
    }
    #if DEBUG
    func feedControlled(_ samples: [Float]) async {
        await withCheckedContinuation { done in queue.async { self.process(samples); done.resume() } }
    }
    #endif
    @discardableResult
    func stop() async -> Date {
        await withCheckedContinuation { done in queue.async { do { try self.finish() } catch { self.failure(error) }; done.resume(returning: self.start.addingTimeInterval(Double(self.frames)/self.rate)) } }
    }
}
