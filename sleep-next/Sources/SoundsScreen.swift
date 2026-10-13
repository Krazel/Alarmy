import SwiftUI

struct SoundsScreen: View {
    @EnvironmentObject var store: SleepStore
    @Environment(\.dismiss) private var dismiss
    let sessionIDs: [UUID]
    @State private var category: SoundKind = .cough
    @State private var selectedID: UUID?
    @State private var detail: NightClip?
    private var nights: [SleepSession] { store.archive.sessions.filter { sessionIDs.contains($0.id) } }
    private var clips: [NightClip] { nights.flatMap(\.clips).sorted { $0.created < $1.created } }
    private var group: [NightClip] { clips.filter { $0.kind == category } }
    private var selected: NightClip? { group.first { $0.id == selectedID } ?? group.first }
    private var index: Int { group.firstIndex { $0.id == selected?.id } ?? 0 }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:18) {
                    VStack(alignment:.leading,spacing:5) {
                        Text("\(NightMetrics(nights:nights).soundCount) " + store.words("sounds").lowercased()).font(.system(size:34,design:.serif))
                        Text("\(clips.count) " + store.words("savedClips") + " · " + DiaryPresentation.duration(clips.reduce(0) { $0+$1.duration })).font(.subheadline).foregroundStyle(Color.ink.opacity(0.6))
                    }
                    if clips.isEmpty { Text(store.words("noClips")).font(.subheadline) }
                    else {
                        LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:10) {
                            ForEach(SoundKind.allCases.filter { kind in clips.contains { $0.kind == kind } },id:\.self) { kind in
                                categoryButton(kind)
                            }
                        }
                        if let selected {
                            CategoryPlayer(clip:selected,index:index,count:group.count,audio:store.audio,previous:{move(-1)},next:{move(1)})
                            Button { detail = selected } label: { Label(store.words("clipDetails"),systemImage:"slider.horizontal.3") }.font(.subheadline).accessibilityIdentifier("sound-clip-details")
                        }
                    }
                    DisclosureGroup(store.words("soundTotals")) {
                        VStack(spacing:8) {
                            ForEach(SoundKind.allCases,id:\.self) { kind in
                                MetricRow(title:store.words(kind.rawValue),value:SleepMath.duration(NightMetrics(nights:nights).soundSeconds(kind)))
                            }
                            Text(store.words("soundStatsHint")).font(.caption).foregroundStyle(Color.ink.opacity(0.6))
                        }.padding(.top,12)
                    }.padding(.top,8)
                }.padding(20)
            }.background(Color.paper).foregroundStyle(Color.ink).tint(.rust)
                .navigationTitle(store.words("sounds")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button(store.words("done")) { dismiss() }.accessibilityIdentifier("close-sounds") } }
                .sheet(item:$detail) { clip in
                    ClipDetail(clipID:clip.id,category:clip.kind,day:nights.first { $0.clips.contains { $0.id == clip.id } }.map { $0.end ?? $0.checkpoint } ?? clip.created,audio:store.audio)
                }
                .onAppear { reconcile() }
                .onChange(of:clips) { _ in reconcile() }
                .onDisappear { store.audio.stopPlayback() }
        }
    }
    private func categoryButton(_ kind: SoundKind) -> some View {
        let count = clips.filter { $0.kind == kind }.count
        return Button {
            store.audio.stopPlayback(); category = kind; selectedID = nil
        } label: {
            HStack(spacing:10) {
                Image(systemName:kind.symbol).frame(width:38,height:38).background(Color.rust.opacity(0.09),in:Circle())
                VStack(alignment:.leading,spacing:5) { Text(store.words(kind.rawValue)).font(.subheadline); Text("\(count)").font(.system(size:20,design:.serif)) }
                Spacer(minLength:0)
            }.foregroundStyle(category == kind ? Color.rust : Color.ink).padding(13).frame(maxWidth:.infinity,alignment:.leading)
                .background(Color.card,in:RoundedRectangle(cornerRadius:20))
                .overlay(RoundedRectangle(cornerRadius:20).stroke(category == kind ? Color.rust : Color.ink.opacity(0.06),lineWidth:1))
        }.buttonStyle(.plain).accessibilityIdentifier("clip-category-\(kind.rawValue)")
            .accessibilityLabel(store.words(kind.rawValue)).accessibilityValue("\(count) " + store.words("savedClips")).accessibilityAddTraits(category == kind ? .isSelected : [])
    }
    private func reconcile() {
        if group.isEmpty, let first = clips.first { category = first.kind; selectedID = first.id }
        else if !group.contains(where: { $0.id == selectedID }) { selectedID = group.first?.id }
    }
    private func move(_ delta: Int) {
        let next = index+delta
        guard group.indices.contains(next) else { return }
        store.audio.stopPlayback(); selectedID = group[next].id
    }
}

private struct CategoryPlayer: View {
    @EnvironmentObject var store: SleepStore
    let clip: NightClip
    let index: Int
    let count: Int
    @ObservedObject var audio: NightAudio
    let previous: () -> Void
    let next: () -> Void
    var body: some View {
        PaperCard(padding:18) {
            VStack(spacing:18) {
                HStack {
                    Image(systemName:clip.kind.symbol).font(.title2).foregroundStyle(Color.rust)
                    VStack(alignment:.leading,spacing:4) {
                        Text(store.words(clip.kind.rawValue)).font(.system(size:22,design:.serif))
                        Text("\(index+1) / \(count)").font(.caption).accessibilityIdentifier("sound-position")
                    }
                    Spacer(); Text(clip.created,style:.time).font(.caption).monospacedDigit()
                }
                Slider(value:Binding(get:{ audio.playing == clip.id.uuidString ? audio.playbackTime : 0 },set:{ audio.seek(to:$0) }),in:0...max(1,clip.duration))
                    .disabled(audio.playing != clip.id.uuidString).accessibilityLabel(store.words("playbackPosition"))
                HStack { Text(DiaryPresentation.clipTime(audio.playing == clip.id.uuidString ? audio.playbackTime : 0)); Spacer(); Text(DiaryPresentation.clipTime(clip.duration)).accessibilityIdentifier("sound-duration") }.font(.caption).foregroundStyle(Color.ink.opacity(0.6))
                HStack(spacing:34) {
                    Button(action:previous) { Image(systemName:"backward.end.fill").frame(width:44,height:44) }.disabled(index == 0).accessibilityIdentifier("sound-previous").accessibilityLabel(store.words("previousClip"))
                    ClipPlay(clip:clip,audio:audio)
                    Button(action:next) { Image(systemName:"forward.end.fill").frame(width:44,height:44) }.disabled(index+1 >= count).accessibilityIdentifier("sound-next").accessibilityLabel(store.words("nextClip"))
                }.frame(maxWidth:.infinity)
            }
        }
    }
}
