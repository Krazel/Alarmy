import SwiftUI

struct ClipDetail: View {
    @EnvironmentObject var store: SleepStore
    @Environment(\.dismiss) private var dismiss
    @State private var clipID: UUID
    @State private var deleting = false
    @State private var lastIndex = 0
    @State private var envelope: [Double] = []
    let sessionIDs: [UUID]?
    let category: SoundKind
    let day: Date
    @ObservedObject var audio: NightAudio
    init(clipID: UUID, category: SoundKind, day: Date, audio: NightAudio, sessionIDs: [UUID]? = nil) {
        self.sessionIDs = sessionIDs
        _clipID = State(initialValue: clipID); self.category = category; self.day = day; self.audio = audio
    }
    private var clips: [NightClip] { (sessionIDs.map { ids in store.archive.sessions.filter { ids.contains($0.id) } } ?? store.sessions(day)).flatMap(\.clips).filter { $0.kind == category }.sorted { $0.created < $1.created } }
    private var clip: NightClip? { clips.first { $0.id == clipID } }
    private var index: Int { clips.firstIndex { $0.id == clipID } ?? 0 }
    private func clock(_ seconds: Double) -> String { let s = max(0, Int(seconds)); return String(format: "%02d:%02d", s/60, s%60) }
    var body: some View {
        NavigationStack {
            ScrollView {
                if let clip {
                    VStack(alignment: .leading, spacing: 24) {
                        if store.journalPreview { Text(store.words("exampleAudio")).font(.caption).foregroundStyle(Color.rust) }
                        PageHeading(title: store.words(clip.kind.rawValue), subtitle: store.words("fragment") + " \(index+1) " + store.words("of") + " \(clips.count)")
                        Text(clip.created.formatted(.dateTime.hour().minute().locale(store.words.locale)) + " · " + DiaryPresentation.duration(clip.duration)).font(.subheadline)
                        VStack(spacing: 20) {
                            if envelope.isEmpty { Text(store.words("waveUnavailable")).font(.caption).foregroundStyle(.secondary).frame(height: 160) }
                            else { RecordedWaveform(values: envelope, progress: audio.playing == clip.id.uuidString ? audio.playbackTime/max(1,clip.duration) : 0).frame(height: 160) }
                            Slider(value: Binding(get: { audio.playing == clip.id.uuidString ? audio.playbackTime : 0 }, set: { audio.seek(to: $0) }), in: 0...max(1, clip.duration))
                                .disabled(audio.playing != clip.id.uuidString).accessibilityLabel(store.words("playbackPosition"))
                            HStack { Text(clock(audio.playing == clip.id.uuidString ? audio.playbackTime : 0)); Spacer(); Text(clock(clip.duration)).accessibilityIdentifier("sound-duration") }.font(.caption).monospacedDigit()
                            HStack(spacing: 36) {
                                Button { move(-1) } label: { Image(systemName: "backward.end.fill").frame(width: 44, height: 44) }.disabled(index == 0).accessibilityIdentifier("previous-clip").accessibilityLabel(store.words("previousClip"))
                                Button { playOrPause(clip) } label: {
                                    Image(systemName: audio.playing == clip.id.uuidString && !audio.playbackPaused ? "pause.fill" : "play.fill")
                                        .font(.system(size: 28)).frame(width: 76, height: 76).foregroundStyle(Color.paper).background(Color.ink, in: Circle())
                                }.disabled(store.journalPreview).accessibilityIdentifier("play-clip").accessibilityLabel(store.words(audio.playing == clip.id.uuidString && !audio.playbackPaused ? "pause" : "play"))
                                Button { move(1) } label: { Image(systemName: "forward.end.fill").frame(width: 44, height: 44) }.disabled(index+1 >= clips.count).accessibilityIdentifier("next-clip").accessibilityLabel(store.words("nextClip"))
                            }.frame(maxWidth: .infinity)
                            Text("\(index+1) / \(clips.count)").font(.caption).accessibilityIdentifier("clip-position")
                        }
                        PaperCard(padding: 16) {
                            VStack(alignment: .leading, spacing: 10) {
                                Menu { ForEach(SoundKind.allCases, id: \.self) { kind in Button(store.words(kind.rawValue)) { store.label(clip, kind: kind) }.accessibilityIdentifier("clip-label-\(kind.rawValue)") } } label: {
                                    HStack { Image(systemName: "tag"); Text(store.words("correctLabel")); Spacer(); Text(store.words(clip.kind.rawValue)); Image(systemName: "chevron.down").font(.caption) }
                                }.accessibilityIdentifier("correct-clip-label")
                                Text(store.words("clipHint")).font(.caption).foregroundStyle(Color.ink.opacity(0.6))
                            }
                        }
                        DisclosureGroup(store.words("recognizedIntervals")) {
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
                                }.disabled(store.journalPreview)
                            }
                            Button(store.words("reanalyze")) { Task { await store.analyze(clip) } }.disabled(store.journalPreview || store.analyzing.contains(clip.id)).accessibilityIdentifier("reanalyze-clip")
                        }
                        }
                        Button(store.words("delete"), role: .destructive) { deleting = true }.frame(maxWidth: .infinity).padding().accessibilityIdentifier("delete-clip")
                    }.padding(22)
                }
            }.background(Color.paper).foregroundStyle(Color.ink).tint(.rust)
            .navigationTitle(store.words("nightSounds")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(store.words("done")) { dismiss() }.accessibilityIdentifier("close-clip") } }
            .confirmationDialog(store.words("deleteClip"), isPresented: $deleting, titleVisibility: .visible) {
                Button(store.words("delete"), role: .destructive) { if let clip { Task { _ = await store.delete(clip) } } }
            }
            .alert(store.words("error"), isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                if store.writeFailed { Button(store.words("retrySave")) { Task { await store.retrySaving() } } }
                Button(store.words("done")) { store.error = nil }
            } message: { Text(store.error ?? "") }
            .task(id: clipID) {
                envelope = []
                if let clip, let url = DiskLocation.child(clip.filename, of: DiskLocation.clips) {
                    let result = await Task.detached(priority: .utility) { (try? ClipEnvelope.read(url)) ?? [] }.value
                    if !Task.isCancelled { envelope = result }
                }
            }
            .onAppear { store.clipPresented = true; reconcile() }
            .onChange(of: clips) { _ in reconcile() }
            .onDisappear { store.clipPresented = false; if audio.playing == clipID.uuidString { audio.stopPlayback() } }
        }
    }
    private func playOrPause(_ clip: NightClip) {
        if audio.playing == clip.id.uuidString { audio.togglePause() }
        else if let url = DiskLocation.child(clip.filename, of: DiskLocation.clips) {
            do { try audio.play(url: url, id: clip.id.uuidString) } catch { store.error = error.localizedDescription }
        }
    }
    // Classification, deletion and retention can change the open group. Stay in
    // the category, preserving the current clip or selecting its nearest neighbour.
    private func reconcile() {
        if let current = clips.firstIndex(where: { $0.id == clipID }) { lastIndex = current; return }
        if !store.journalPreview { audio.stopPlayback() }
        guard !clips.isEmpty else { dismiss(); return }
        lastIndex = min(lastIndex, clips.count - 1)
        clipID = clips[lastIndex].id
    }
    private func move(_ delta: Int) {
        let next = index + delta
        guard clips.indices.contains(next) else { return }
        if !store.journalPreview { audio.stopPlayback() }
        clipID = clips[next].id
        lastIndex = next
    }
}
