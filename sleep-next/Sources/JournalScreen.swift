import SwiftUI

struct JournalScreen: View {
    @EnvironmentObject var store: SleepStore
    @State private var calendar = false
    @FocusState private var editingNote: Bool
    @State private var stages: [SleepStage] = []
    private var nights: [SleepSession] { store.sessions(store.selectedDay) }
    private var clips: [NightClip] { nights.flatMap(\.clips) }
    private var duration: Double { nights.reduce(0) { $0 + $1.duration } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    week
                    summary
                    feeling
                    notes
                    soundCard
                    healthCard
                    HStack { Spacer(); Image(systemName: "lock"); Text(store.words("saved")); Spacer() }.font(.caption2).foregroundStyle(Color.ink.opacity(0.5)).padding(.bottom, 18)
                }.padding(.horizontal, 22).padding(.top, 18)
            }.scrollIndicators(.hidden).background(Color.paper).toolbar(.hidden, for: .navigationBar).toolbarBackground(.visible, for: .tabBar)
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button(store.words("done")) { editingNote = false } } }
            .sheet(isPresented: $calendar) {
                NavigationStack {
                    DatePicker(store.words("calendar"), selection: $store.selectedDay, in: ...Date(), displayedComponents: .date).datePickerStyle(.graphical).padding().background(Color.paper)
                        .navigationTitle(store.words("calendar")).navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(store.words("done")) { calendar = false } } }
                }.presentationDetents([.medium, .large])
            }
            .task(id: CalendarDay.key(store.selectedDay)) { await store.analyzeClips(for: store.selectedDay) }
            .task(id: CalendarDay.key(store.selectedDay) + String(store.archive.preferences.health)) {
                stages = []
                if store.archive.preferences.health {
                    do { let values = try await HealthReader().stages(for: store.selectedDay); if !Task.isCancelled { stages = values } } catch { store.error = error.localizedDescription }
                }
            }
        }
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(store.words("journal")).font(.system(size: 35, weight: .regular, design: .serif))
                Spacer()
                Button { calendar = true } label: { Image(systemName: "calendar").font(.system(size: 19)).padding(12).background(Color.card, in: Circle()) }.accessibilityIdentifier("calendar").accessibilityLabel(store.words("calendar"))
            }
            Text(store.words("yourNight")).font(.subheadline).foregroundStyle(Color.ink.opacity(0.6))
        }
    }
    private var week: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Button { moveWeek(-1) } label: { Image(systemName: "chevron.left").padding(7) }.accessibilityLabel(store.words("calendar") + " −7")
                Spacer()
                Text(store.selectedDay.formatted(.dateTime.month(.wide).year().locale(store.words.locale))).font(.system(size: 14, weight: .medium)).textCase(.uppercase).tracking(1)
                Spacer()
                Button { moveWeek(1) } label: { Image(systemName: "chevron.right").padding(7) }.disabled(Calendar.current.isDate(store.selectedDay, equalTo: Date(), toGranularity: .weekOfYear)).accessibilityLabel(store.words("calendar") + " +7")
            }.foregroundStyle(Color.ink)
            HStack(spacing: 4) {
                ForEach(CalendarDay.week(around: store.selectedDay), id: \.self) { day in
                    let selected = Calendar.current.isDate(day, inSameDayAs: store.selectedDay)
                    Button { store.selectedDay = day } label: {
                        VStack(spacing: 10) {
                            Text(day.formatted(.dateTime.weekday(.narrow).locale(store.words.locale))).font(.system(size: 10, weight: .medium))
                            Text(day.formatted(.dateTime.day())).font(.system(size: 17, weight: selected ? .semibold : .regular, design: .rounded))
                            Circle().fill(store.sessions(day).isEmpty && store.page(day).text.isEmpty && store.page(day).feeling == nil ? .clear : (selected ? Color.paper : Color.rust)).frame(width: 4, height: 4)
                        }.frame(maxWidth: .infinity).padding(.vertical, 13).foregroundStyle(selected ? Color.paper : Color.ink.opacity(day > Date() ? 0.25 : 0.7)).background(selected ? Color.ink : Color.clear, in: Capsule())
                    }.disabled(Calendar.current.startOfDay(for: day) > Calendar.current.startOfDay(for: Date())).accessibilityLabel(day.formatted(date: .complete, time: .omitted))
                }
            }
        }.padding(.vertical, 4)
    }
    private func moveWeek(_ amount: Int) { if let date = Calendar.current.date(byAdding: .day, value: amount*7, to: store.selectedDay) { store.selectedDay = min(date, Date()) } }
    private var summary: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack { Eyebrow(text: store.words("overview")); Spacer(); Image(systemName: "moon.stars").foregroundStyle(Color.rust) }
                if nights.isEmpty {
                    Text(store.words("noNight")).font(.system(size: 23, design: .serif))
                    Text(store.words("noNightHint")).font(.subheadline).foregroundStyle(Color.ink.opacity(0.65)).fixedSize(horizontal: false, vertical: true)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(Int(duration)/3600)").font(.system(size: 46, weight: .light, design: .rounded)); Text("h").font(.title3).foregroundStyle(Color.ink.opacity(0.5))
                        Text("\((Int(duration)%3600)/60)").font(.system(size: 46, weight: .light, design: .rounded)); Text("min").font(.subheadline).foregroundStyle(Color.ink.opacity(0.5))
                    }
                    Text(store.words("inBed")).font(.caption).foregroundStyle(Color.ink.opacity(0.6))
                    ForEach(nights) { night in
                        HStack { Text(night.start, style: .time); Rectangle().fill(Color.rust.opacity(0.35)).frame(height: 2); Text(night.end ?? night.checkpoint, style: .time) }.font(.caption).monospacedDigit()
                        if night.interrupted { Text(store.words("interrupted")).font(.caption2).foregroundStyle(Color.rust) }
                    }
                }
            }
        }.accessibilityIdentifier("night-summary")
    }
    private var feeling: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(store.words("feeling")).font(.system(size: 23, design: .serif)).fixedSize(horizontal: false, vertical: true)
            Text(store.words("feelingHint")).font(.caption).foregroundStyle(Color.ink.opacity(0.55))
            HStack(alignment: .top, spacing: 3) {
                ForEach(MorningFeeling.allCases) { value in
                    let chosen = store.page(store.selectedDay).feeling == value
                    Button { store.feeling(value, day: store.selectedDay) } label: {
                        VStack(spacing: 6) { FeelingFace(feeling: value, selected: chosen); Text(store.words(value.key)).font(.system(size: 10, weight: chosen ? .semibold : .regular)).lineLimit(1).minimumScaleFactor(0.7).foregroundStyle(chosen ? Color.rust : Color.ink.opacity(0.6)) }.frame(maxWidth: .infinity)
                    }.accessibilityIdentifier("feeling-\(value.rawValue)").accessibilityLabel(store.words(value.key)).accessibilityAddTraits(chosen ? .isSelected : [])
                }
            }
        }.padding(.vertical, 5)
    }
    private var notes: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) { Text(store.words("notes")).font(.system(size: 23, design: .serif)); Spacer(minLength: 10); Image(systemName: "pencil.line").foregroundStyle(Color.rust).padding(.top, 4) }
                ZStack(alignment: .topLeading) {
                    if store.page(store.selectedDay).text.isEmpty { Text(store.words("notesHint")).font(.subheadline).foregroundStyle(Color.ink.opacity(0.4)).padding(.top, 8).padding(.leading, 5).allowsHitTesting(false) }
                    TextEditor(text: Binding(get: { store.page(store.selectedDay).text }, set: { store.note($0, day: store.selectedDay) })).font(.system(size: 16)).lineSpacing(6).scrollContentBackground(.hidden).frame(minHeight: 120).focused($editingNote).accessibilityIdentifier("journal-note")
                }
                HStack { Rectangle().fill(Color.ink.opacity(0.1)).frame(height: 1); Text(store.words(store.saving ? "saving" : "saved")).font(.system(size: 9)).foregroundStyle(Color.ink.opacity(0.4)) }
            }
        }
    }
    private var soundCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack { Image(systemName: "waveform").foregroundStyle(Color.rust); Text(store.words("nightSounds")).font(.system(size: 21, design: .serif)); Spacer(); Text("\(clips.count)").font(.caption).foregroundStyle(Color.ink.opacity(0.5)) }
                if clips.isEmpty { Text(store.words("noClips")).font(.subheadline).foregroundStyle(Color.ink.opacity(0.55)) }
                else { Text(store.words("clipHint")).font(.caption).foregroundStyle(Color.ink.opacity(0.55)); ForEach(clips) { clip in ClipRow(clip: clip) } }
            }
        }
    }
    private var healthCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 14) {
                Label(store.words("health"), systemImage: "heart").font(.system(size: 21, design: .serif))
                if stages.isEmpty {
                    Text(store.words(store.archive.preferences.health ? "healthEmpty" : "healthHint")).font(.caption).foregroundStyle(Color.ink.opacity(0.6))
                    if !store.archive.preferences.health { Button(store.words("connectHealth")) { Task { do { try await HealthReader().authorize(); store.preferences { $0.health = true } } catch { store.error = error.localizedDescription } } }.font(.subheadline) }
                } else { StageChart(stages: stages, words: store.words); Text(store.words("healthHint")).font(.caption2).foregroundStyle(Color.ink.opacity(0.5)) }
            }
        }
    }
}
struct ClipRow: View {
    @EnvironmentObject var store: SleepStore
    let clip: NightClip
    var body: some View {
        HStack(spacing: 12) {
            ClipPlay(clip: clip, audio: store.audio)
            VStack(alignment: .leading, spacing: 3) { Text(clip.created, style: .time).font(.caption); Text("\(Int(clip.duration)) s").font(.caption2).foregroundStyle(Color.ink.opacity(0.5)) }
            Spacer()
            Menu {
                ForEach(SoundKind.allCases, id: \.self) { kind in Button(store.words(kind.rawValue)) { store.label(clip, kind: kind) } }
                Button(store.words("delete"), role: .destructive) { Task { await store.delete(clip) } }
            } label: { HStack { Text(store.words(clip.kind.rawValue)); if clip.suggestion { Image(systemName: "sparkle") }; Image(systemName: "chevron.down") }.font(.caption) }
        }.padding(.vertical, 6)
    }
}
struct ClipPlay: View {
    @EnvironmentObject var store: SleepStore
    let clip: NightClip
    @ObservedObject var audio: NightAudio
    var body: some View {
        Button {
            if audio.playing == clip.id.uuidString { audio.stopPlayback() }
            else if let url = DiskLocation.child(clip.filename, of: DiskLocation.clips) { do { try audio.play(url: url, id: clip.id.uuidString) } catch { store.error = error.localizedDescription } }
        } label: { Image(systemName: audio.playing == clip.id.uuidString ? "stop.fill" : "play.fill").font(.caption).frame(width: 38, height: 38).background(Color.rust.opacity(0.09), in: Circle()) }.accessibilityLabel(store.words(audio.playing == clip.id.uuidString ? "stop" : "play"))
    }
}
struct StageChart: View {
    let stages: [SleepStage]; let words: Words
    private let keys = ["awake", "rem", "core", "deep", "asleep"]
    private func color(_ key: String) -> Color { switch key { case "deep": return .indigo; case "rem": return .purple; case "awake": return .rust; default: return .teal } }
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            GeometryReader { geo in
                if let start = stages.map(\.start).min(), let end = stages.map(\.end).max() {
                    let total = max(1, end.timeIntervalSince(start))
                    ForEach(stages) { stage in
                        RoundedRectangle(cornerRadius: 3).fill(color(stage.key).opacity(0.75)).frame(width: max(2, stage.end.timeIntervalSince(stage.start)/total*geo.size.width), height: 14).offset(x: stage.start.timeIntervalSince(start)/total*geo.size.width, y: Double(keys.firstIndex(of: stage.key) ?? 4)*19)
                    }
                }
            }.frame(height: 90)
            HStack { ForEach(keys.filter { key in stages.contains { $0.key == key } }, id: \.self) { key in HStack(spacing: 3) { Circle().fill(color(key)).frame(width: 5, height: 5); Text(words(key)).font(.system(size: 9)) } } }
        }.accessibilityLabel(words("health"))
    }
}
