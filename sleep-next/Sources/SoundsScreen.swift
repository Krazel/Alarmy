import SwiftUI
struct SoundsScreen: View {
    @EnvironmentObject var store: SleepStore
    @Environment(\.dismiss) private var dismiss
    let sessionIDs: [UUID]
    @State private var detail: NightClip?
    private var nights: [SleepSession] { store.archive.sessions.filter { sessionIDs.contains($0.id) } }
    private var clips: [NightClip] { nights.flatMap(\.clips).filter(\.recognized).sorted { $0.created < $1.created } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageHeading(title: store.words("nightSounds"), subtitle: nights.count == 1 ? nights.first?.start.formatted(.dateTime.day().month(.wide).locale(store.words.locale)) : nil)
                    ReviewNotice(text: "\(clips.count) " + store.words("savedClips") + " · " + DiaryPresentation.duration(clips.reduce(0) { $0 + $1.duration }))
                    SoundAnalysisStatus(nights: nights, words: store.words)
                    if clips.isEmpty { Text(store.words("noClips")).font(.subheadline) }
                    ForEach(SoundKind.allCases.filter { kind in clips.contains { $0.kind == kind } }, id: \.self) { kind in categoryButton(kind) }
                    DisclosureGroup(store.words("soundSchedule")) { ChartSoundHours(clips: clips, words: store.words).padding(.top, 12) }
                    DisclosureGroup(store.words("soundTotals")) {
                        VStack(spacing: 8) {
                            ForEach(SoundKind.allCases.filter { $0 != .other }, id: \.self) { kind in
                                MetricRow(title: store.words(kind.rawValue), value: SleepMath.duration(NightMetrics(nights: nights).soundSeconds(kind)))
                            }
                            Text(store.words("soundStatsHint")).font(.caption).foregroundStyle(.secondary)
                        }.padding(.top, 12)
                    }
                }.padding(20)
            }.background(Color.paper).foregroundStyle(Color.ink).tint(.rust).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(store.words("done")) { dismiss() }.accessibilityIdentifier("close-sounds") } }
                .sheet(item: $detail) { clip in ClipDetail(clipID: clip.id, category: clip.kind, day: clip.created, audio: store.audio, sessionIDs: sessionIDs) }
                .onDisappear { store.audio.stopPlayback() }
        }
    }
    private func categoryButton(_ kind: SoundKind) -> some View {
        let group = clips.filter { $0.kind == kind }
        let duration = group.reduce(0.0) { $0 + $1.duration }
        return Button { store.audio.stopPlayback(); detail = group.first } label: {
            PaperCard(padding: 20) {
                HStack(spacing: 20) {
                    Image(systemName: kind.symbol).font(.system(size: 34, weight: .light)).frame(width: 48).foregroundStyle(kind == .snore ? Color.rust : Color.ink)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.words(kind.rawValue)).font(.system(size: 23, design: .serif))
                        Text("\(group.count) " + store.words("savedClips") + " · " + (duration < 60 ? DiaryPresentation.clipTime(duration) : DiaryPresentation.duration(duration))).font(.caption).foregroundStyle(Color.ink.opacity(0.6))
                        GeometryReader { geo in
                            Capsule().fill(Color.ink.opacity(0.1))
                            Capsule().fill(kind == .snore ? Color.rust : Color.ink.opacity(0.7)).frame(width: geo.size.width * Double(group.count) / Double(max(1, clips.count)))
                        }.frame(height: 7).accessibilityHidden(true)
                    }
                    Spacer(minLength: 0); Image(systemName: "chevron.right").font(.caption)
                }.foregroundStyle(Color.ink)
            }
        }.buttonStyle(.plain).accessibilityIdentifier("clip-category-\(kind.rawValue)")
            .accessibilityLabel(store.words(kind.rawValue)).accessibilityValue("\(group.count) " + store.words("savedClips"))
    }
}
