import SwiftUI

struct JournalScreen: View {
    @EnvironmentObject var store: SleepStore
    @State private var statistics = false
    @State private var calendar = false
    @State private var openedClip: NightClip?
    @State private var examples = false
    @FocusState private var editingNote: Bool
    @State private var stages: [SleepStage] = []
    private var nights: [SleepSession] { store.sessions(store.selectedDay) }
    private var clips: [NightClip] { nights.flatMap(\.clips) }
    private var duration: Double { NightMetrics(nights:nights).inBed }
    var body: some View {
        NavigationStack {
            ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if store.journalPreview {
                        Label(store.words("exampleOnly"), systemImage: "flask").font(.caption).foregroundStyle(Color.rust)
                    } else if store.developerMode {
                        Button { examples = true } label: { Label(store.words("journalExamples"), systemImage: "flask") }.font(.subheadline).accessibilityIdentifier("journal-examples")
                    }
                    week
                    feeling
                    notes
                    summary { editingNote = false; withAnimation(.easeInOut(duration:0.3)) { scroll.scrollTo("night-sounds",anchor:.top) } }
                    if !nights.isEmpty { NightAnalysisCard(nights:nights,stages:stages,feeling:store.page(store.selectedDay).feeling,words:store.words) }
                    healthCard
                    soundCard.id("night-sounds")
                    HStack { Spacer(); Image(systemName: store.journalPreview ? "flask" : "lock"); Text(store.words(store.journalPreview ? "exampleOnly" : (store.writeFailed ? "savePending" : (store.saving ? "saving" : "saved")))); Spacer() }.font(.caption2).foregroundStyle(Color.ink.opacity(0.5)).padding(.bottom, 18)
                }.padding(.horizontal, 22).padding(.top, 18)
            }.scrollIndicators(.hidden).background(Color.paper)
            }
            .overlay(alignment: .top) {
                GeometryReader { geometry in
                    Color.paper.frame(height: geometry.safeAreaInsets.top).frame(maxHeight: .infinity, alignment: .top).ignoresSafeArea(edges: .top)
                }.allowsHitTesting(false).accessibilityHidden(true)
            }
            .toolbar(.hidden, for: .navigationBar).toolbarBackground(.visible, for: .tabBar)
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button(store.words("done")) { editingNote = false } } }
            .sheet(isPresented: $calendar) {
                JournalCalendar(month: store.selectedDay).presentationDetents([.large])
            }
            .sheet(isPresented: $statistics) { StatisticsScreen() }
            .sheet(isPresented: $examples) { JournalExamples(language: store.archive.preferences.language, appearance: store.archive.preferences.appearance) }
            .sheet(item: $openedClip) { ClipDetail(clipID: $0.id, category: $0.kind, day: store.selectedDay, audio: store.audio) }
            .task(id: CalendarDay.key(store.selectedDay)) { await store.analyzeClips(for: store.selectedDay) }
            .task(id: CalendarDay.key(store.selectedDay) + String(store.archive.preferences.health)) {
                stages = []
                if store.archive.preferences.health && !store.journalPreview {
                    do {
                        var values: [SleepStage] = []
                        for night in nights { values += try await HealthReader().stages(from:night.start,to:night.end ?? night.checkpoint) }
                        if !Task.isCancelled { stages = HealthReader.normalize(values) }
                    } catch { store.error = error.localizedDescription }
                }
            }
        }
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(store.words("journal")).font(.system(size: 35, weight: .regular, design: .serif))
                Spacer()
                Button { calendar = true } label: { Image(systemName: "calendar").font(.system(size: 19)).padding(12).background(Color.card, in: Circle()) }.accessibilityIdentifier(store.journalPreview ? "example-calendar" : "calendar").accessibilityLabel(store.words("calendar"))
            }
            Button { statistics = true } label: { Label(store.words("statistics"),systemImage:"chart.bar.xaxis") }.accessibilityIdentifier("statistics")
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
                            DayFeeling(feeling: store.page(day).feeling).frame(width: 24, height: 24)
                        }.frame(maxWidth: .infinity).padding(.vertical, 13).foregroundStyle(selected ? Color.paper : Color.ink.opacity(day > Date() ? 0.25 : 0.7)).background(selected ? Color.ink : Color.clear, in: Capsule())
                    }.disabled(Calendar.current.startOfDay(for: day) > Calendar.current.startOfDay(for: Date())).accessibilityLabel(day.formatted(date: .complete, time: .omitted) + ", " + store.words(store.page(day).feeling?.key ?? "unrated")).accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }.padding(.vertical, 4)
    }
    private func moveWeek(_ amount: Int) { if let date = Calendar.current.date(byAdding: .day, value: amount*7, to: store.selectedDay) { store.selectedDay = min(date, Date()) } }
    private func summary(openSounds: @escaping () -> Void) -> some View {
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
                    Button(action:openSounds) {
                        HStack { Text(store.words("soundsRecorded")); Spacer(); Text("\(NightMetrics(nights:nights).soundCount)").monospacedDigit(); Image(systemName:"chevron.right").font(.caption) }.foregroundStyle(Color.rust)
                    }.accessibilityIdentifier("summary-sounds").accessibilityValue("\(NightMetrics(nights:nights).soundCount)")
                    ForEach(nights) { night in
                        HStack { Text(night.start, style: .time); Rectangle().fill(Color.rust.opacity(0.35)).frame(height: 2); Text(night.end ?? night.checkpoint, style: .time) }.font(.caption).monospacedDigit()
                        if let spans = night.captureSpans, !spans.isEmpty {
                            let seconds = spans.reduce(0.0) { $0 + max(0, $1.end.timeIntervalSince($1.start)) }
                            Text(store.words("captureTime") + " · \(Int(seconds)/60) min").font(.caption)
                            Text(store.words("captureGaps")).font(.caption2).foregroundStyle(Color.ink.opacity(0.5))
                        }
                        if night.interrupted { Text(store.words("interrupted")).font(.caption2).foregroundStyle(Color.rust) }
                    }
                }
            }
        }
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
                if !store.journalPreview {
                    HStack { Rectangle().fill(Color.ink.opacity(0.1)).frame(height: 1); Text(store.words(store.writeFailed ? "savePending" : (store.saving ? "saving" : "saved"))).font(.system(size: 9)).foregroundStyle(Color.ink.opacity(0.4)) }
                }
            }
        }
    }
    private var soundCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack { Image(systemName: "waveform").foregroundStyle(Color.rust); Text(store.words("nightSounds")).font(.system(size: 21, design: .serif)); Spacer(); Text("\(clips.count)").font(.caption).foregroundStyle(Color.ink.opacity(0.5)) }
                if clips.isEmpty { Text(store.words("noClips")).font(.subheadline).foregroundStyle(Color.ink.opacity(0.55)) }
                else {
                    Text(store.words("categoryHint")).font(.caption).foregroundStyle(Color.ink.opacity(0.55))
                    VStack(spacing: 4) {
                        ForEach(SoundKind.allCases, id: \.self) { kind in
                            let group = clips.filter { $0.kind == kind }.sorted { $0.created < $1.created }
                            if let first = group.first {
                                Button { openedClip = first } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: kind.symbol).font(.system(size: 18)).foregroundStyle(Color.rust).frame(width: 36, height: 36).background(Color.rust.opacity(0.08), in: Circle())
                                        Text(store.words(kind.rawValue)).font(.subheadline)
                                        Spacer()
                                        Text("\(group.count)").font(.system(.subheadline, design: .rounded).weight(.semibold)).monospacedDigit().padding(.horizontal, 10).padding(.vertical, 5).background(Color.rust.opacity(0.08), in: Capsule())
                                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.ink.opacity(0.4))
                                    }.foregroundStyle(Color.ink).padding(.vertical, 5).contentShape(Rectangle())
                                }.buttonStyle(.plain).accessibilityIdentifier("clip-category-\(kind.rawValue)")
                                    .accessibilityLabel(store.words(kind.rawValue)).accessibilityValue("\(group.count) " + store.words("savedClips"))
                            }
                        }
                    }
                }
            }
        }
    }
    private var healthCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 14) {
                Label(store.words("health"), systemImage: "heart").font(.system(size: 21, design: .serif))
                if stages.isEmpty {
                    Text(store.words(store.archive.preferences.health ? "healthEmpty" : "healthHint")).font(.caption).foregroundStyle(Color.ink.opacity(0.6))
                    if !store.archive.preferences.health && !store.journalPreview { Button(store.words("connectHealth")) { Task { do { try await HealthReader().authorize(); store.preferences { $0.health = true } } catch { store.error = error.localizedDescription } } }.font(.subheadline) }
                } else { StageChart(stages: stages, words: store.words); Text(store.words("healthHint")).font(.caption2).foregroundStyle(Color.ink.opacity(0.5)) }
            }
        }
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
        } label: { Image(systemName: audio.playing == clip.id.uuidString ? "stop.fill" : "play.fill").font(.caption).frame(width: 38, height: 38).background(Color.rust.opacity(0.09), in: Circle()) }.disabled(store.journalPreview).accessibilityLabel(store.words(store.journalPreview ? "exampleAudio" : (audio.playing == clip.id.uuidString ? "stop" : "play")))
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
