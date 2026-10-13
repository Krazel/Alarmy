import SwiftUI
import UniformTypeIdentifiers

struct AnalysisCSV: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws { text = String(decoding:configuration.file.regularFileContents ?? Data(),as:UTF8.self) }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents:Data(text.utf8)) }
}

struct HabitEditor: View {
    @EnvironmentObject var store: SleepStore
    let day: Date
    var body: some View {
        DisclosureGroup(store.words("habits")) {
            VStack(alignment:.leading,spacing:10) {
                ForEach(SleepHabit.allCases) { habit in
                    Button { store.setHabit(habit,day:day) } label: {
                        HStack { Text(store.words(habit.rawValue)); Spacer(); Image(systemName:store.page(day).habits?.contains(habit) == true ? "checkmark.circle.fill" : "circle") }
                    }.accessibilityIdentifier("habit-"+habit.rawValue).accessibilityValue(store.words(store.page(day).habits?.contains(habit) == true ? "yes" : "no"))
                }
                Button(store.words("noHabits")) { store.recordNoHabits(day:day) }.font(.caption)
                Text(store.words(store.page(day).habits == nil ? "habitsUnknown" : "habitsSaved")).font(.caption).foregroundStyle(.secondary)
            }.padding(.top,12)
        }.tint(.rust)
    }
}

struct SessionEditor: View {
    @EnvironmentObject var store: SleepStore
    @Environment(\.dismiss) private var dismiss
    let night: SleepSession
    @State private var start: Date
    @State private var end: Date
    @State private var nap: Bool
    @State private var saving = false
    init(night: SleepSession) {
        self.night = night
        _start = State(initialValue:night.analysisSession.start)
        _end = State(initialValue:night.analysisSession.end ?? night.checkpoint)
        _nap = State(initialValue:night.isNap == true)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(store.words("bedtime"),selection:$start,in:night.start...(night.end ?? night.checkpoint))
                    DatePicker(store.words("wakeTime"),selection:$end,in:night.start...(night.end ?? night.checkpoint))
                    Toggle(store.words("nap"),isOn:$nap).accessibilityIdentifier("session-nap")
                } footer: { Text(store.words("correctionHint")) }
                Button(store.words("restoreTimes")) { Task { saving = true; defer {saving = false}; if await store.correctSession(id:night.id,start:start,end:end,nap:nap,reset:true) {dismiss()} } }.disabled(saving)
            }.navigationTitle(store.words("editSession")).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement:.cancellationAction) { Button(store.words("cancel")) { dismiss() } }
                    ToolbarItem(placement:.confirmationAction) {
                        Button(store.words("save")) { Task { saving = true; defer {saving = false}; if await store.correctSession(id:night.id,start:start,end:end,nap:nap) {dismiss()} } }
                            .disabled(saving || end <= start).accessibilityIdentifier("save-session")
                    }
                }
        }
    }
}

struct NightDetails: View {
    @EnvironmentObject var store: SleepStore
    @Environment(\.dismiss) private var dismiss
    let ids: [UUID]
    let stages: [SleepStage]
    @State private var editing: SleepSession?
    private var nights: [SleepSession] { store.archive.sessions.filter {ids.contains($0.id)} }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing:16) {
                    ContinuityCard(nights:nights,stages:stages,words:store.words)
                    Text(store.words("localMethodHint")).font(.caption).foregroundStyle(.secondary)
                    ForEach(nights) { night in
                        PaperCard {
                            VStack(alignment:.leading,spacing:12) {
                                Text(store.words(night.isNap == true ? "nap" : "nightSession")).font(.title3)
                                MetricRow(title:store.words("bedtime"),value:night.analysisSession.start.formatted(date:.omitted,time:.shortened))
                                MetricRow(title:store.words("wakeTime"),value:(night.analysisSession.end ?? night.checkpoint).formatted(date:.omitted,time:.shortened))
                                AlarmMetrics(night:night,words:store.words)
                                Button(store.words("editSession")) { editing = night }.accessibilityIdentifier("edit-session")
                            }
                        }
                    }
                    PaperCard {
                        let m = NightMetrics(nights:nights)
                        VStack(alignment:.leading,spacing:10) {
                            Text(store.words("captureQuality")).font(.title3)
                            MetricRow(title:store.words("analysisCoverage"),value:m.coverage.map {"\(Int($0*100))%"} ?? "—")
                            MetricRow(title:store.words("missingTime"),value:SleepMath.duration(max(0,m.inBed-m.observed)))
                            AcousticTimeline(metrics:m,words:store.words)
                            Text(store.words("captureQualityHint")).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }.padding(20)
            }.background(Color.paper).navigationTitle(store.words("nightAnalysis")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button(store.words("done")) {dismiss()} } }
                .sheet(item:$editing) { SessionEditor(night:$0) }
        }.foregroundStyle(Color.ink).tint(.rust)
    }
}

struct ContinuityCard: View {
    let nights: [SleepSession]
    let stages: [SleepStage]
    let words: Words
    var body: some View {
        let value = SleepContinuity(nights:nights,stages:stages)
        return PaperCard {
            VStack(alignment:.leading,spacing:10) {
                Text(words("continuity")).font(.system(size:23,design:.serif))
                MetricRow(title:words("sleepLatency"),value:SleepMath.duration(value.latency))
                MetricRow(title:words("awakenings"),value:value.awakenings.map(String.init) ?? "—")
                MetricRow(title:words("awakeDuringSleep"),value:SleepMath.duration(value.awakeDuringSleep))
                MetricRow(title:words("longestSleep"),value:SleepMath.duration(value.longestSleep))
                MetricRow(title:words("efficiency"),value:value.efficiency.map {"\(Int($0*100))%"} ?? "—")
                Text(words(stages.isEmpty ? "automaticPending" : "localEstimate")).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct AlarmMetrics: View {
    let night: SleepSession
    let words: Words
    var body: some View {
        VStack(alignment:.leading,spacing:6) {
            if night.hasAlarm {
                MetricRow(title:words("snoozes"),value:night.alarmStatsTracked == true ? "\(night.snoozeDates?.count ?? 0)" : "—")
                MetricRow(title:words("scheduledAlarm"),value:night.wake.formatted(date:.omitted,time:.shortened))
                MetricRow(title:words("observedAlarm"),value:night.alarmObservedAt?.formatted(date:.omitted,time:.shortened) ?? "—")
                if let observed = night.alarmObservedAt, let end = night.end, end >= observed {
                    MetricRow(title:words("timeToStop"),value:SleepMath.duration(end.timeIntervalSince(observed)))
                }
                if night.mode == .smart { MetricRow(title:words("smartUsed"),value:words(night.smartTriggered == true ? "yes" : "no")) }
                Text(words("alarmStatsHint")).font(.caption2).foregroundStyle(.secondary)
            } else { Text(words("analysis")).font(.caption) }
        }
    }
}

struct ExtraStatistics: View {
    @EnvironmentObject var store: SleepStore
    let nights: [SleepSession]
    let stages: [UUID:[SleepStage]]
    @State private var comparing = false
    @State private var exporting = false
    private var words: Words {store.words}
    var body: some View {
        VStack(alignment:.leading,spacing:14) {
            DisclosureGroup(words("habitsAndFeelings")) { habits.padding(.top,12) }.accessibilityIdentifier("habit-statistics")
            DisclosureGroup(words("alarmStatistics")) {
                let tracked = nights.filter {$0.alarmStatsTracked == true && $0.hasAlarm}
                MetricRow(title:words("snoozesMean"),value:AnalysisInsights.average(tracked.map {Double($0.snoozeDates?.count ?? 0)}).map {String(format:"%.1f",$0)} ?? "—")
                Text("\(tracked.count) / \(nights.count) · " + words("sessionsWithData")).font(.caption)
                Text(words("alarmStatsHint")).font(.caption2).foregroundStyle(.secondary)
            }
            Button { comparing = true } label: { Label(words("compareNights"),systemImage:"rectangle.split.2x1") }.disabled(nights.count < 2).accessibilityIdentifier("compare-nights")
            Button { exporting = true } label: { Label(words("exportCSV"),systemImage:"square.and.arrow.up") }.accessibilityIdentifier("export-analysis")
            Text(words("exportHint")).font(.caption2).foregroundStyle(.secondary)
        }.sheet(isPresented:$comparing) { CompareNights(nights:nights,stages:stages) }
            .fileExporter(isPresented:$exporting,document:AnalysisCSV(text:AnalysisInsights.csv(nights:nights,pages:store.archive.pages,stages:stages,words:words)),contentType:.commaSeparatedText,defaultFilename:"Alarma-\(CalendarDay.key(Date()))") { result in
                if case .failure(let error) = result {store.error = error.localizedDescription}
            }
    }
    private var habits: some View {
        VStack(alignment:.leading,spacing:12) {
            ForEach(SleepHabit.allCases) { habit in
                VStack(alignment:.leading,spacing:4) {
                    Text(words(habit.rawValue)).font(.subheadline.bold())
                    if let result = AnalysisInsights.habit(habit,nights:nights,pages:store.archive.pages) {
                        Text(words("meanBed") + ": " + SleepMath.duration(result.taggedBed) + " / " + SleepMath.duration(result.otherBed)).font(.caption)
                        Text("\(result.taggedDays) / \(result.otherDays) · " + words("withWithoutHabit")).font(.caption2)
                    } else { Text(words("habitMinimum")).font(.caption).foregroundStyle(.secondary) }
                }
            }
            Divider()
            ForEach(MorningFeeling.allCases) { feeling in
                let group = Dictionary(grouping:nights.filter {$0.isNap != true && store.page($0.end ?? $0.checkpoint).feeling == feeling},by:{CalendarDay.key($0.end ?? $0.checkpoint)})
                MetricRow(title:words(feeling.key),value:group.count >= 3 ? SleepMath.duration(AnalysisInsights.average(group.values.map {NightMetrics(nights:$0).inBed})) : "—")
            }
            Text(words("feelingComparisonHint")).font(.caption2).foregroundStyle(.secondary)
            Text(words("associationHint")).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

struct CompareNights: View {
    @EnvironmentObject var store: SleepStore
    @Environment(\.dismiss) private var dismiss
    let nights: [SleepSession]
    let stages: [UUID:[SleepStage]]
    @State private var first: UUID?
    @State private var second: UUID?
    var body: some View {
        NavigationStack {
            Form {
                selection(store.words("firstNight"),value:$first)
                selection(store.words("secondNight"),value:$second)
                ForEach([first,second].compactMap {$0}.enumerated().map {ComparisonSlot(index:$0.offset,id:$0.element)},id:\.index) { slot in
                    if let night = nights.first(where:{$0.id == slot.id}) {
                        Section(night.start.formatted(date:.abbreviated,time:.shortened)) {
                            MetricRow(title:store.words("inBed"),value:SleepMath.duration(NightMetrics(nights:[night]).inBed))
                            MetricRow(title:store.words("asleepShort"),value:SleepMath.duration(NightMetrics(nights:[night]).sleepSeconds(stages[night.id] ?? [])))
                            MetricRow(title:store.words("analysisCoverage"),value:NightMetrics(nights:[night]).coverage.map {"\(Int($0*100))%"} ?? "—")
                            MetricRow(title:store.words("feeling"),value:store.words(store.page(night.end ?? night.checkpoint).feeling?.key ?? "unrated"))
                            MetricRow(title:store.words("sounds"),value:"\(NightMetrics(nights:[night]).soundCount)")
                        }
                    }
                }
            }.navigationTitle(store.words("compareNights")).navigationBarTitleDisplayMode(.inline)
                .toolbar {ToolbarItem(placement:.confirmationAction) {Button(store.words("done")) {dismiss()}}}
                .onAppear {first = nights.last?.id; second = nights.dropLast().last?.id}
        }
    }
    private func selection(_ title: String,value: Binding<UUID?>) -> some View {
        Picker(title,selection:value) {ForEach(nights) {night in Text(night.start.formatted(date:.abbreviated,time:.shortened)).tag(Optional(night.id))}}
    }
}
private struct ComparisonSlot {let index: Int; let id: UUID}
