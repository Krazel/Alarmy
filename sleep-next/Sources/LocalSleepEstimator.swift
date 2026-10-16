import Foundation

/// Compact envelope features, not audio. Thresholds are engineering heuristics,
/// not PSG-trained probabilities or validated physiological measurements.
struct BreathingFeatures: Codable, Equatable {
    let version: Int
    let contrast: Double
    let periodicity: Double
    let intervalVariation: Double?
    let peaks: Int
    var usable: Bool { version == 1 && contrast >= 2 && contrast <= 24 && peaks >= 4 && peaks <= 22 && intervalVariation != nil }
}

enum RespiratoryEnvelope {
    /// 10 Hz log-energy envelope. Discarded after each 30-second epoch.
    static func features(_ values: [Double]) -> BreathingFeatures? {
        guard values.count >= 290 else { return nil }
        let ordered = values.sorted(), contrast = ordered[ordered.count*9/10]-ordered[ordered.count/10]
        let mean = values.reduce(0,+)/Double(values.count)
        let centered = values.map {$0-mean}
        let energy = centered.reduce(0) {$0+$1*$1}
        guard energy > 0.001 else { return BreathingFeatures(version:1,contrast:contrast,periodicity:0,intervalVariation:nil,peaks:0) }
        var best = 0.0
        for lag in 15...80 {
            var dot = 0.0, left = 0.0, right = 0.0
            for i in lag..<centered.count { let a = centered[i], b = centered[i-lag]; dot += a*b; left += a*a; right += b*b }
            best = max(best,dot/max(0.001,sqrt(left*right)))
        }
        let threshold = sqrt(energy/Double(values.count))*0.35
        var peaks: [Int] = []
        for i in 2..<(centered.count-2) {
            guard centered[i] > threshold, centered[i] >= centered[i-1], centered[i] > centered[i+1],
                  centered[i] >= centered[i-2], centered[i] >= centered[i+2] else { continue }
            if let last = peaks.last, i-last < 12 {
                if centered[i] > centered[last] {peaks[peaks.count-1] = i}
            } else {peaks.append(i)}
        }
        let intervals = zip(peaks,peaks.dropFirst()).map {Double($1-$0)/10}
        var variation: Double?
        if intervals.count >= 3, intervals.allSatisfy({$0 >= 1.2 && $0 <= 8}) {
            let average = intervals.reduce(0,+)/Double(intervals.count)
            variation = sqrt(intervals.reduce(0) {$0+pow($1-average,2)}/Double(intervals.count))/average
        }
        return BreathingFeatures(version:1,contrast:contrast,periodicity:min(1,best),intervalVariation:variation,peaks:peaks.count)
    }
}

enum LocalSleepEstimator {
    static let version = 2
    static func cacheKey(_ nights: [SleepSession]) -> Int {
        var hash = Hasher(); hash.combine(version)
        for night in nights {
            hash.combine(night.id); hash.combine(night.acousticEpochs?.count)
            hash.combine(night.correction?.start); hash.combine(night.correction?.end)
            hash.combine(night.soundSummaries?.count)
            for clip in night.clips {
                hash.combine(clip.id); hash.combine(clip.kind.rawValue); hash.combine(clip.analysisDone)
                for event in clip.events ?? [] {hash.combine(event.kind.rawValue); hash.combine(event.confidence)}
            }
        }
        return hash.finalize()
    }
    static func stages(nights: [SleepSession]) -> [SleepStage] { SleepStageTimeline.normalize(nights.flatMap {stages(night:$0)}) }
    static func stages(night raw: SleepSession) -> [SleepStage] {
        guard raw.localAnalysisVersion == nil || raw.localAnalysisVersion == 1 || raw.localAnalysisVersion == version else {return []}
        let night = raw.analysisSession
        let epochs = (night.acousticEpochs ?? []).filter {$0.duration >= 29 && $0.start >= night.start && $0.end <= (night.end ?? night.checkpoint)}.sorted {$0.start < $1.start}
        guard !epochs.isEmpty else {return []}
        // Speech-labelled fragments are a competing sound source, not breathing.
        let voices = NightMetrics(nights:[night]).summaries.flatMap { s in s.events.filter {$0.kind == .voice && $0.confidence >= 0.5}.map {DateInterval(start:s.start.addingTimeInterval($0.start),duration:max(0,$0.duration))} }
        // Bridge only short, actually recorded quiet interruptions bounded by
        // respiratory evidence on both sides. Never fill capture gaps or silence alone.
        let supported = epochs.map { epoch in
            epoch.breathing?.usable == true && (epoch.breathing?.periodicity ?? 0) >= 0.25 &&
            epoch.meanDBFS > -80 && epoch.meanDBFS < -12 && epoch.activeSeconds/epoch.duration < 0.4 &&
            !voices.contains {$0.start < epoch.end && $0.end > epoch.start}
        }
        var bridged = Set<Int>()
        var index = 0
        while index < epochs.count {
            if supported[index] { index += 1; continue }
            let begin = index
            while index < epochs.count && !supported[index] { index += 1 }
            guard begin > 0, index < epochs.count, index-begin <= 3,
                  epochs[begin..<index].allSatisfy({$0.quiet && $0.meanDBFS > -80 && $0.meanDBFS < -12}),
                  !voices.contains(where: {$0.start < epochs[index].start && $0.end > epochs[begin].start}) else {continue}
            let block = Array(epochs[(begin-1)...index])
            guard zip(block,block.dropFirst()).allSatisfy({abs($1.start.timeIntervalSince($0.end)) < 0.1}) else {continue}
            bridged.formUnion(begin..<index)
        }
        var result: [SleepStage] = [], candidate: [AcousticEpoch] = []
        var sleeping = false, stableSeconds = 0.0, variableSeconds = 0.0
        var prior: AcousticEpoch?
        for (index, epoch) in epochs.enumerated() {
            if let prior, abs(epoch.start.timeIntervalSince(prior.end)) > 0.1 {
                candidate = []; sleeping = false; stableSeconds = 0; variableSeconds = 0
            }
            defer {prior = epoch}
            let speech = voices.contains {$0.start < epoch.end && $0.end > epoch.start}
            let activity = epoch.activeSeconds/epoch.duration
            let feature = epoch.breathing
            let breathing = (supported[index] || bridged.contains(index)) && !speech
            // An isolated cough is not a wake event; need sustained activity.
            let priorActive = prior.map {$0.activeSeconds/$0.duration >= 0.4 && abs(epoch.start.timeIntervalSince($0.end)) < 0.1} ?? false
            if activity >= 0.4 && priorActive && !breathing {
                candidate = []; sleeping = false; stableSeconds = 0; variableSeconds = 0
                result.append(SleepStage(id:epoch.id,start:epoch.start,end:epoch.end,key:"awake")); continue
            }
            guard breathing, activity < 0.4 else {
                candidate = []; stableSeconds = 0; variableSeconds = 0
                // Unknown epochs remain holes; no carry-forward of sleep across gaps.
                sleeping = false
                continue
            }
            candidate.append(epoch)
            if !sleeping {
                guard candidate.reduce(0,{$0+$1.duration}) >= 300 else {continue}
                sleeping = true
                for item in candidate.dropLast() {result.append(SleepStage(id:item.id,start:item.start,end:item.end,key:"core"))}
            }
            let regular = !bridged.contains(index) && (feature?.periodicity ?? 0) >= 0.65 && (feature?.intervalVariation ?? 1) <= 0.15 && activity < 0.05
            let variable = !bridged.contains(index) && (feature?.periodicity ?? 0) >= 0.25 && (feature?.intervalVariation ?? 0) >= 0.22 && activity < 0.1
            stableSeconds = regular ? stableSeconds+epoch.duration : 0
            variableSeconds = variable ? variableSeconds+epoch.duration : 0
            // Experimental stage hypotheses from observed stability/variability.
            // Never synthesize fixed 90-minute cycles or predetermined percentages.
            let key = stableSeconds >= 600 ? "deep" : (variableSeconds >= 90 ? "rem" : "core")
            result.append(SleepStage(id:epoch.id,start:epoch.start,end:epoch.end,key:key))
            if candidate.count > 10 {candidate.removeFirst(candidate.count-10)}
        }
        return SleepStageTimeline.normalize(result)
    }
}
