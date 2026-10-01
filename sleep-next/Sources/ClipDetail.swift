import SwiftUI

struct ClipDetail: View {
    @EnvironmentObject var store: SleepStore
    @Environment(\.dismiss) private var dismiss
    @State private var clipID: UUID
    @State private var deleting = false
    @ObservedObject var audio: NightAudio
    init(clipID: UUID, audio: NightAudio) { _clipID = State(initialValue: clipID); self.audio = audio }
    private var clips: [NightClip] { store.sessions(store.selectedDay).flatMap(\.clips).sorted { $0.created < $1.created } }
    private var clip: NightClip? { clips.first { $0.id == clipID } }
    private var index: Int { clips.firstIndex { $0.id == clipID } ?? 0 }
    private func clock(_ seconds: Double) -> String { let s = max(0, Int(seconds)); return String(format: "%02d:%02d", s/60, s%60) }
    var body: some View {
        NavigationStack {
            ScrollView {
                if let clip {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(clip.created.formatted(.dateTime.day().month(.wide).hour().minute().locale(store.words.locale))).font(.system(size: 25, design: .serif))
                        PaperCard {
                            VStack(spacing: 20) {
                                HStack { ClipPlay(clip: clip, audio: audio); Spacer(); Text(store.words(clip.kind.rawValue)).font(.title3); if clip.suggestion { Image(systemName: "sparkle") } }
                                Slider(value: Binding(get: { audio.playing == clip.id.uuidString ? audio.playbackTime : 0 }, set: { audio.seek(to: $0) }), in: 0...max(1, clip.duration))
                                    .disabled(audio.playing != clip.id.uuidString).accessibilityLabel(store.words("playbackPosition"))
                                HStack { Text(clock(audio.playing == clip.id.uuidString ? audio.playbackTime : 0)); Spacer(); Text(clock(clip.duration)) }.font(.caption).monospacedDigit()
                                HStack {
                                    Button { move(-1) } label: { Label(store.words("previousClip"), systemImage: "backward.end") }.disabled(index == 0)
                                    Spacer(); Text("\(index+1) / \(clips.count)").font(.caption); Spacer()
                                    Button { move(1) } label: { Label(store.words("nextClip"), systemImage: "forward.end") }.disabled(index+1 >= clips.count)
                                }.font(.caption)
                            }
                        }
                        VStack(alignment: .leading, spacing: 14) {
                            Text(store.words("recognizedIntervals")).font(.system(size: 23, design: .serif))
                            Text(store.words("intervalHint")).font(.caption).foregroundStyle(Color.ink.opacity(0.6))
                            if store.analyzing.contains(clip.id) { ProgressView(store.words("analyzing")) }
                            else if clip.analysisFailed == true { Text(store.words("analysisError")).font(.subheadline) }
                            else if !clip.analysisDone { Text(store.words("analysisPending")).font(.subheadline) }
                            else if clip.events?.isEmpty != false { Text(store.words("unidentified")).font(.subheadline) }
                            ForEach(clip.events ?? []) { event in
                                Button {
                                    do {
                                        if audio.playing != clip.id.uuidString, let url = DiskLocation.child(clip.filename, of: DiskLocation.clips) { try audio.play(url: url, id: clip.id.uuidString) }
                                        audio.seek(to: event.start)
                                    } catch { store.error = error.localizedDescription }
                                } label: {
                                    HStack { Image(systemName: "play.circle"); Text(store.words(event.kind.rawValue)); Spacer(); Text(clock(event.start) + " – " + clock(event.start+event.duration)).monospacedDigit() }.font(.subheadline).padding(14).background(Color.card, in: RoundedRectangle(cornerRadius: 14))
                                }
                            }
                            Button(store.words("reanalyze")) { Task { await store.analyze(clip) } }.disabled(store.analyzing.contains(clip.id)).accessibilityIdentifier("reanalyze-clip")
                        }
                        PaperCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Text(store.words("correctLabel")).font(.headline)
                                Menu { ForEach(SoundKind.allCases, id: \.self) { kind in Button(store.words(kind.rawValue)) { store.label(clip, kind: kind) }.accessibilityIdentifier("clip-label-\(kind.rawValue)") } } label: { Label(store.words(clip.kind.rawValue), systemImage: "pencil") }.accessibilityIdentifier("correct-clip-label")
                                Text(store.words("clipHint")).font(.caption).foregroundStyle(Color.ink.opacity(0.6))
                            }
                        }
                        Button(store.words("delete"), role: .destructive) { deleting = true }.frame(maxWidth: .infinity).padding().accessibilityIdentifier("delete-clip")
                    }.padding(22)
                }
            }.background(Color.paper).foregroundStyle(Color.ink).tint(.rust)
            .navigationTitle(store.words("clipDetail")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(store.words("done")) { dismiss() } } }
            .confirmationDialog(store.words("deleteClip"), isPresented: $deleting, titleVisibility: .visible) {
                Button(store.words("delete"), role: .destructive) { if let clip { Task { await store.delete(clip); dismiss() } } }
            }
            .alert(store.words("error"), isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                Button(store.words("done")) { store.error = nil }
            } message: { Text(store.error ?? "") }
            .onAppear { store.clipPresented = true }
            .onDisappear { store.clipPresented = false; if audio.playing == clipID.uuidString { audio.stopPlayback() } }
        }
    }
    private func move(_ delta: Int) {
        let next = index + delta
        guard clips.indices.contains(next) else { return }
        audio.stopPlayback(); clipID = clips[next].id
    }
}
