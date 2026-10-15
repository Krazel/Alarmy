import SwiftUI

struct SoundAnalysisStatus: View {
    let nights: [SleepSession]
    let words: Words
    var body: some View {
        let metrics = NightMetrics(nights:nights)
        VStack(alignment:.leading,spacing:3) {
            if metrics.pendingSoundCount > 0 {Text("\(metrics.pendingSoundCount) " + words("soundQueue"))}
            if metrics.failedSoundCount > 0 {Text("\(metrics.failedSoundCount) " + words("soundRetry"))}
        }.font(.caption2).foregroundStyle(.secondary).accessibilityIdentifier("sound-analysis-status")
    }
}
