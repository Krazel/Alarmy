import SwiftUI

struct JournalScreen: View {
    @EnvironmentObject var store: SleepStore
    @State private var statistics = false
    @State private var calendar = false
    @State private var sounds = false
    @State private var examples = false
    @State private var details = false
    @FocusState private var editingNote: Bool
    @State private var stages: [SleepStage] = []
    private var nights: [SleepSession] { store.sessions(store.selectedDay) }
    private var clips: [NightClip] { nights.flatMap(\.clips) }
    private var duration: Double { NightMetrics(nights:nights).inBed }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    if store.journalPreview {
                        Label(store.words("exampleOnly"), systemImage: "flask").font(.caption).foregroundStyle(Color.rust)
                    } else if store.developerMode {
                        Button { examples = true } label: { Label(store.words("journalExamples"), systemImage: "flask") }.font(.subheadline).accessibilityIdentifier("journal-examples")
                    }
                    week
                    summary
                    if !nights.isEmpty {
                        Button { editingNote = false; sounds = true } label: {
                            SoundSummaryRow(nights:nights,words:store.words)
                        }.buttonStyle(.plain).accessibilityIdentifier("summary-sounds").accessibilityValue("\(NightMetrics(nights:nights).soundCount)")
                    }
                    feeling
                    notes
                    HabitEditor(day:store.selectedDay)
                    HStack { Spacer(); Image(systemName: store.journalPreview ? "flask" : "lock"); Text(store.words(store.journalPreview ? "exampleOnly" : (store.writeFailed ? "savePending" : (store.saving ? "saving" : "saved")))); Spacer() }.font(.caption2).foregroundStyle(Color.ink.opacity(0.5)).padding(.bottom, 18)
                }.padding(.horizontal, 20).padding(.top, 8)
            }.scrollIndicators(.hidden).background(Color.paper)
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
            .sheet(isPresented: $details) { NightDetails(ids:nights.map(\.id),stages:stages) }
            .sheet(isPresented: $sounds) { SoundsScreen(sessionIDs:nights.map(\.id)) }
            .task(id: CalendarDay.key(store.selectedDay)) { await store.analyzeClips(for: store.selectedDay) }
            .task(id: analysisKey) {
                stages = []
                #if DEBUG
                if store.testMode && ProcessInfo.processInfo.arguments.contains("--stage-fixture") {
                    stages = nights.flatMap { DiaryPresentation.fixtureStages($0) }; return
                }
                #endif
                let source = nights
                let result = await Task.detached(priority:.userInitiated) { LocalSleepEstimator.stages(nights:source) }.value
                if !Task.isCancelled { stages = result }
            }
        }
    }
    private var analysisKey: String { CalendarDay.key(store.selectedDay) + nights.map { "\($0.id)-\($0.acousticEpochs?.count ?? 0)-\($0.correction?.start.timeIntervalSince1970 ?? 0)-\($0.correction?.end.timeIntervalSince1970 ?? 0)" }.joined() }
    private var header: some View {
        HStack {
            Text(store.words("journal")).font(.system(size:32,design:.serif))
            Spacer()
            Button { statistics = true } label: { Image(systemName:"chart.bar.xaxis").frame(width:44,height:44).background(Color.card,in:Circle()) }
                .accessibilityIdentifier("statistics").accessibilityLabel(store.words("statistics"))
            Button { calendar = true } label: { Image(systemName:"calendar").frame(width:44,height:44).background(Color.card,in:Circle()) }
                .accessibilityIdentifier(store.journalPreview ? "example-calendar" : "calendar").accessibilityLabel(store.words("calendar"))
        }
    }
    private var week: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button { moveWeek(-1) } label: { Image(systemName: "chevron.left").padding(7) }.accessibilityLabel(store.words("calendar") + " −7")
                Spacer()
                Text(store.selectedDay.formatted(.dateTime.day().month(.wide).locale(store.words.locale))).font(.system(size: 14, weight: .medium)).textCase(.uppercase).tracking(1)
                Spacer()
                Button { moveWeek(1) } label: { Image(systemName: "chevron.right").padding(7) }.disabled(Calendar.current.isDate(store.selectedDay, equalTo: Date(), toGranularity: .weekOfYear)).accessibilityLabel(store.words("calendar") + " +7")
            }.foregroundStyle(Color.ink)
            HStack(spacing: 4) {
                ForEach(CalendarDay.week(around: store.selectedDay), id: \.self) { day in
                    let selected = Calendar.current.isDate(day, inSameDayAs: store.selectedDay)
                    Button { store.selectedDay = day } label: {
                        VStack(spacing: 3) {
                            Text(day.formatted(.dateTime.weekday(.narrow).locale(store.words.locale))).font(.system(size: 10, weight: .medium))
                            Text(day.formatted(.dateTime.day())).font(.system(size: 17, weight: selected ? .semibold : .regular, design: .rounded))
                            DayFeeling(feeling: store.page(day).feeling).frame(width: 20, height: 20)
                        }.frame(maxWidth: .infinity).padding(.vertical, 5).foregroundStyle(selected ? Color.paper : Color.ink.opacity(day > Date() ? 0.25 : 0.7)).background(selected ? Color.ink : Color.clear, in: Capsule())
                    }.disabled(Calendar.current.startOfDay(for: day) > Calendar.current.startOfDay(for: Date())).accessibilityLabel(day.formatted(date: .complete, time: .omitted) + ", " + store.words(store.page(day).feeling?.key ?? "unrated")).accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }.padding(.vertical, 4)
    }
    private func moveWeek(_ amount: Int) { if let date = Calendar.current.date(byAdding: .day, value: amount*7, to: store.selectedDay) { store.selectedDay = min(date, Date()) } }
    private var summary: some View {
        let metrics = NightMetrics(nights:nights)
        let stages = SleepContinuity(nights:nights,stages:self.stages).stages
        return PaperCard(padding:16) {
            VStack(alignment:.leading,spacing:10) {
                Text(store.words("overview")).font(.system(size:22,design:.serif)).accessibilityIdentifier("night-summary-title")
                if nights.isEmpty {
                    Text(store.words("noNightHint")).font(.subheadline).foregroundStyle(Color.ink.opacity(0.6))
                } else {
                    HStack(alignment:.top,spacing:8) {
                        CompactMetric(title:store.words("asleepShort"),value:DiaryPresentation.duration(metrics.sleepSeconds(stages)))
                        Divider()
                        CompactMetric(title:store.words("inBed"),value:DiaryPresentation.duration(metrics.inBed))
                    }.fixedSize(horizontal:false,vertical:true)
                    if stages.isEmpty {
                        Text(store.words("compactHealthEmpty")).font(.caption).foregroundStyle(Color.ink.opacity(0.55)).fixedSize(horizontal:false,vertical:true)
                        AcousticTimeline(metrics:metrics,words:store.words)
                    } else {
                        StageChart(stages:stages,words:store.words)
                        StageDurations(stages:stages,nights:nights,words:store.words)
                        Text(store.words("stageCoverage") + ": \(Int(SleepContinuity(nights:nights,stages:stages).coverage*100))%").font(.caption2).foregroundStyle(Color.ink.opacity(0.6))
                        Text(store.words("localEstimate")).font(.system(size:10)).foregroundStyle(Color.ink.opacity(0.5)).frame(maxWidth:.infinity,alignment:.trailing)
                    }
                    Button(store.words("nightDetails")) { details = true }.font(.caption).accessibilityIdentifier("night-details")
                    if nights.contains(where: \.interrupted) { Text(store.words("interrupted")).font(.caption2).foregroundStyle(Color.rust) }
                }
            }
        }
    }
    private var feeling: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(store.words("feeling")).font(.system(size: 21, design: .serif)).fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 3) {
                ForEach(MorningFeeling.allCases) { value in
                    let chosen = store.page(store.selectedDay).feeling == value
                    Button { store.feeling(value, day: store.selectedDay) } label: {
                        VStack(spacing: 6) { FeelingFace(feeling: value, selected: chosen).frame(maxHeight:56); Text(store.words(value.key)).font(.system(size: 10, weight: chosen ? .semibold : .regular)).lineLimit(1).minimumScaleFactor(0.7).foregroundStyle(chosen ? Color.rust : Color.ink.opacity(0.6)) }.frame(maxWidth: .infinity)
                    }.accessibilityIdentifier("feeling-\(value.rawValue)").accessibilityLabel(store.words(value.key)).accessibilityAddTraits(chosen ? .isSelected : [])
                }
            }
        }.padding(.vertical, 5)
    }
    private var notes: some View {
        PaperCard(padding:14) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top) { Text(store.words("notes")).font(.system(size: 21, design: .serif)); Spacer(minLength: 10); Image(systemName: "pencil.line").foregroundStyle(Color.rust).padding(.top, 4) }
                ZStack(alignment: .topLeading) {
                    if store.page(store.selectedDay).text.isEmpty { Text(store.words("notesHint")).font(.subheadline).foregroundStyle(Color.ink.opacity(0.4)).padding(.top, 8).padding(.leading, 5).allowsHitTesting(false) }
                    TextEditor(text: Binding(get: { store.page(store.selectedDay).text }, set: { store.note($0, day: store.selectedDay) })).font(.system(size: 16)).lineSpacing(6).scrollContentBackground(.hidden).frame(minHeight: 65).focused($editingNote).accessibilityIdentifier("journal-note")
                }
                if !store.journalPreview {
                    HStack { Rectangle().fill(Color.ink.opacity(0.1)).frame(height: 1); Text(store.words(store.writeFailed ? "savePending" : (store.saving ? "saving" : "saved"))).font(.system(size: 9)).foregroundStyle(Color.ink.opacity(0.4)) }
                }
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
