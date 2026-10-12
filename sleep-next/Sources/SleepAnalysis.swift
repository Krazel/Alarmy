import Foundation

/// Acoustic observations are not physiological sleep stages. No audio is stored here.
struct AcousticEpoch: Codable, Equatable, Identifiable {
    let id: UUID
    let start: Date
    let duration: Double
    let activeSeconds: Double
    let meanDBFS: Double
    var end: Date { start.addingTimeInterval(duration) }
    var quiet: Bool { duration >= 29 && activeSeconds / duration < 0.05 }
}

struct NightSoundSummary: Codable, Equatable, Identifiable {
    let id: UUID
    let start: Date
    let duration: Double
    let events: [SoundEvent]
    let completed: Bool
    init(clip: NightClip) {
        id = clip.id; start = clip.created; duration = clip.duration
        completed = clip.analysisDone && clip.analysisFailed != true
        events = !clip.suggestion && completed
            ? [SoundEvent(start: 0, duration: clip.duration, kind: clip.kind, confidence: 1)]
            : (clip.events ?? [])
    }
}

enum SleepMath {
    static func union(_ ranges: [DateInterval]) -> [DateInterval] {
        var result: [DateInterval] = []
        for item in ranges.filter({ $0.duration > 0 }).sorted(by: { $0.start < $1.start }) {
            if let last = result.last, item.start <= last.end {
                result[result.count-1] = DateInterval(start: last.start, end: max(last.end, item.end))
            } else { result.append(item) }
        }
        return result
    }
    static func seconds(_ ranges: [DateInterval]) -> Double { union(ranges).reduce(0) { $0 + $1.duration } }
    static func clockMinutes(_ date: Date, calendar: Calendar = .current) -> Double {
        Double(calendar.component(.hour, from: date)*60 + calendar.component(.minute, from: date))
    }
    /// Circular mean and median absolute deviation; 23:55 and 00:05 are ten minutes apart.
    static func clockStats(_ dates: [Date], calendar: Calendar = .current) -> (mean: Double, spread: Double)? {
        guard !dates.isEmpty else { return nil }
        let values = dates.map { clockMinutes($0, calendar: calendar) }
        let x = values.reduce(0) { $0 + cos($1 * .pi / 720) }
        let y = values.reduce(0) { $0 + sin($1 * .pi / 720) }
        guard hypot(x, y) / Double(values.count) > 0.01 else { return nil }
        let mean = (atan2(y, x) * 720 / .pi + 1440).truncatingRemainder(dividingBy: 1440)
        let distances = values.map { min(abs($0-mean), 1440-abs($0-mean)) }.sorted()
        let i = distances.count/2
        return (mean, distances.count % 2 == 0 ? (distances[i-1]+distances[i])/2 : distances[i])
    }
    static func duration(_ seconds: Double?) -> String {
        guard let seconds, seconds.isFinite else { return "—" }
        let m = max(0, Int(seconds / 60))
        return m >= 60 ? "\(m/60) h \(m%60) min" : (seconds > 0 && m == 0 ? "<1 min" : "\(m) min")
    }
    static func clock(_ minutes: Double?) -> String {
        guard let minutes else { return "—" }; let n = Int(minutes.rounded()) % 1440
        return String(format: "%02d:%02d", n/60, n%60)
    }
}

struct NightMetrics {
    let nights: [SleepSession]
    var bed: [DateInterval] { SleepMath.union(nights.compactMap { n in n.duration > 0 ? DateInterval(start: n.start, duration: n.duration) : nil }) }
    var inBed: Double { SleepMath.seconds(bed) }
    var epochs: [AcousticEpoch] { nights.flatMap { $0.acousticEpochs ?? [] }.sorted { $0.start < $1.start } }
    func clipped(_ ranges: [DateInterval]) -> [DateInterval] {
        SleepMath.union(ranges.flatMap { a in bed.compactMap { b in
            let start = max(a.start,b.start), end = min(a.end,b.end)
            return end > start ? DateInterval(start: start, end: end) : nil
        } })
    }
    var observed: Double { SleepMath.seconds(clipped(epochs.map { DateInterval(start: $0.start, duration: max(0,$0.duration)) })) }
    var coverage: Double? { inBed > 0 && !epochs.isEmpty ? min(1, observed/inBed) : nil }
    var quietRuns: [DateInterval] {
        // Only contiguous, observed epochs count. Pauses never become quiet time.
        SleepMath.union(clipped(epochs.filter(\.quiet).map { DateInterval(start: $0.start, end: $0.end) }))
            .filter { $0.duration >= 600 - 0.01 }
    }
    var rest: Double? { epochs.isEmpty ? nil : SleepMath.seconds(quietRuns) }
    var quietLatency: Double? {
        guard nights.count == 1, let begin = bed.first?.start, let rest = quietRuns.first else { return nil }
        let prefix = DateInterval(start: begin, end: rest.start)
        let missing = prefix.duration - SleepMath.seconds(epochs.compactMap { epoch in
            let a = max(begin,epoch.start), b = min(rest.start,epoch.end)
            return b > a ? DateInterval(start:a,end:b) : nil
        })
        return missing <= 35 ? prefix.duration : nil
    }
    func healthSeconds(_ stages: [SleepStage], key: String? = nil) -> Double? {
        let all = clipped(stages.map { DateInterval(start:$0.start,end:$0.end) })
        guard !all.isEmpty else { return nil }
        return SleepMath.seconds(clipped(stages.filter { key == nil ? $0.key != "awake" : $0.key == key }.map { DateInterval(start:$0.start,end:$0.end) }))
    }
    func healthLatency(_ stages: [SleepStage]) -> Double? {
        guard nights.count == 1, let begin = bed.first?.start,
              let first = clipped(stages.filter { $0.key != "awake" }.map { DateInterval(start:$0.start,end:$0.end) }).first else { return nil }
        // Do not turn unobserved Health time before the first record into wakefulness.
        let prefix = first.start.timeIntervalSince(begin)
        let observedPrefix = SleepMath.seconds(clipped(stages.filter { $0.end <= first.start }.map { DateInterval(start:$0.start,end:$0.end) }))
        return prefix - observedPrefix <= 60 ? prefix : nil
    }
    var summaries: [NightSoundSummary] {
        var result: [UUID:NightSoundSummary] = [:]
        for n in nights {
            for s in n.soundSummaries ?? [] { result[s.id] = s }
            for c in n.clips where c.analysisDone { result[c.id] = NightSoundSummary(clip:c) }
        }
        return Array(result.values)
    }
    func soundSeconds(_ kind: SoundKind) -> Double? {
        guard summaries.contains(where: \.completed) else { return nil }
        return SleepMath.seconds(clipped(summaries.filter(\.completed).flatMap { s in s.events.filter { $0.kind == kind }.compactMap { e in
            let a = max(0,e.start), b = min(s.duration,e.start+e.duration)
            return b > a ? DateInterval(start:s.start.addingTimeInterval(a),duration:b-a) : nil
        } }))
    }
}

enum SmartWakePolicy {
    /// Conservative acoustic transition, NOT an inference of light sleep or wakefulness.
    static func shouldWake(_ night: SleepSession, now: Date) -> Bool {
        guard night.mode == .smart, night.smartTriggered != true,
              let start = night.windowStart, let latest = night.latestWake,
              now >= start, now.addingTimeInterval(15) < latest else { return false }
        let epochs = (night.acousticEpochs ?? []).sorted { $0.start < $1.start }
        guard let last = epochs.last, abs(now.timeIntervalSince(last.end)) < 5,
              last.duration >= 29, last.activeSeconds >= 5 else { return false }
        let prior = epochs.dropLast().suffix(20)
        guard prior.count == 20, prior.allSatisfy(\.quiet) else { return false }
        let sequence = Array(prior) + [last]
        return zip(sequence,sequence.dropFirst()).allSatisfy { abs($1.start.timeIntervalSince($0.end)) < 0.1 }
    }
}

/// Queue-confined accumulator observing every captured PCM frame, never UI samples.
final class EpochAccumulator {
    private var start: Date
    private var seconds = 0.0, active = 0.0, energy = 0.0
    private let emit: (AcousticEpoch) -> Void
    init(start: Date, emit: @escaping (AcousticEpoch) -> Void) { self.start = start; self.emit = emit }
    func add(duration: Double, level: Double, loud: Bool) {
        var remaining = duration
        while remaining > 0.000001 {
            let n = min(30-seconds,remaining)
            seconds += n; active += loud ? n : 0; energy += pow(10,level/10)*n; remaining -= n
            if seconds >= 29.999999 { flush() }
        }
    }
    func flush() {
        guard seconds > 0 else { return }
        let duration = seconds >= 29.999999 ? 30 : seconds
        emit(AcousticEpoch(id:UUID(),start:start,duration:duration,activeSeconds:active,meanDBFS:10*log10(max(1e-10,energy/seconds))))
        start = start.addingTimeInterval(duration); seconds = 0; active = 0; energy = 0
    }
}
