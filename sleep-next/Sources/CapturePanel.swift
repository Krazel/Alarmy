import SwiftUI

struct CapturePanel: View {
    @EnvironmentObject var store: SleepStore
    @ObservedObject var audio: NightAudio
    var body: some View {
        VStack(spacing: 10) {
            Label(store.words(audio.captureState), systemImage: audio.isRecording ? "waveform" : "mic.slash")
                .font(.caption).multilineTextAlignment(.center).accessibilityIdentifier("capture-state")
            if audio.isRecording {
                ProgressView(value: max(0, min(1, (audio.inputLevel + 80)/65))).tint(.orange).frame(width: 130).accessibilityLabel(store.words("record"))
                Text("\(store.archive.active?.clips.count ?? 0) · " + store.words("nightSounds")).font(.caption2)
                Button(store.words("pauseCapture")) { Task { await store.pauseCapture() } }.accessibilityIdentifier("pause-capture")
            } else if !store.ringing {
                Button(store.words(audio.captureState == "recordOff" ? "enableCapture" : "resumeCapture")) { Task { await store.resumeCapture() } }.accessibilityIdentifier("resume-capture")
            }
            Text(store.words("recordLimits")).font(.system(size: 11)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.padding(16).frame(maxWidth: .infinity).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
    }
}
