import SwiftUI
import Charts

struct MetricRow: View {
    let title: String
    let value: String
    var body: some View {
        HStack(alignment:.firstTextBaseline) { Text(title).foregroundStyle(Color.ink.opacity(0.65)); Spacer(minLength:16); Text(value).monospacedDigit().multilineTextAlignment(.trailing) }.font(.subheadline).padding(.vertical,3)
    }
}

struct NightAnalysisCard: View {
    let nights: [SleepSession]
    let stages: [SleepStage]
    let feeling: MorningFeeling?
    let words: Words
    private var metrics: NightMetrics { NightMetrics(nights:nights) }
    var body: some View {
        PaperCard {
            VStack(alignment:.leading,spacing:14) {
                Text(words("nightAnalysis")).font(.system(size:23,design:.serif))
                MetricRow(title:words("perceivedQuality"),value:words(feeling?.key ?? "unrated"))
                MetricRow(title:words("sleepHealth"),value:SleepMath.duration(metrics.healthSeconds(stages)))
                MetricRow(title:words("latencyHealth"),value:SleepMath.duration(metrics.healthLatency(stages)))
                if !stages.isEmpty {
                    ForEach(["awake","core","deep","rem","asleep"].filter { key in stages.contains { $0.key == key } },id:\.self) { key in
                        MetricRow(title:words(key) + " · " + words("healthSource"),value:SleepMath.duration(metrics.healthSeconds(stages,key:key)))
                    }
                }
                Text(words("stageSourceHint")).font(.caption).foregroundStyle(Color.ink.opacity(0.6))
                Divider()
                MetricRow(title:words("estimatedRest"),value:SleepMath.duration(metrics.rest))
                MetricRow(title:words("quietLatency"),value:SleepMath.duration(metrics.quietLatency))
                MetricRow(title:words("analysisCoverage"),value:metrics.coverage.map { "\(Int($0*100))%" } ?? "—")
                AcousticTimeline(metrics:metrics,words:words)
                Text(words("restHint")).font(.caption).foregroundStyle(Color.ink.opacity(0.6))
                Divider()
                MetricRow(title:words("soundActivity"),value:SleepMath.duration(metrics.activity))
                ForEach(SoundKind.allCases,id:\.self) { kind in MetricRow(title:words(kind.rawValue),value:SleepMath.duration(metrics.soundSeconds(kind))) }
                Text(words("soundStatsHint")).font(.caption).foregroundStyle(Color.ink.opacity(0.6))
            }
        }.accessibilityIdentifier("night-analysis")
    }
}

struct AcousticTimeline: View {
    let metrics: NightMetrics
    let words: Words
    var body: some View {
        VStack(alignment:.leading,spacing:8) {
            GeometryReader { geo in
                if let start = metrics.bed.first?.start, let end = metrics.bed.last?.end, end > start {
                    ZStack(alignment:.leading) {
                        RoundedRectangle(cornerRadius:5).fill(Color.ink.opacity(0.08))
                        ForEach(metrics.epochs) { epoch in
                            Rectangle().fill(epoch.quiet ? Color.teal.opacity(0.65) : Color.rust.opacity(0.8))
                                .frame(width:max(1,epoch.duration/end.timeIntervalSince(start)*geo.size.width))
                                .offset(x:max(0,epoch.start.timeIntervalSince(start)/end.timeIntervalSince(start)*geo.size.width))
                        }
                    }.clipped()
                }
            }.frame(height:24).accessibilityHidden(true)
            Text(words("timelineLegend")).font(.caption2).foregroundStyle(Color.ink.opacity(0.6))
        }
    }
}

struct StatisticsScreen: View {
    @EnvironmentObject var store: SleepStore
    @Environment(\.dismiss) private var dismiss
    @State private var days = 30
    @State private var health: [UUID:[SleepStage]] = [:]
    @State private var loading = false
    private var words: Words { store.words }
    private var nights: [SleepSession] {
        let cutoff = Calendar.current.date(byAdding:.day,value:-days,to:Date()) ?? .distantPast
        return store.archive.sessions.filter { days == 0 || ($0.end ?? $0.checkpoint) >= cutoff }.sorted { $0.start < $1.start }
    }
    private var healthNights: [SleepSession] { nights.filter { NightMetrics(nights:[$0]).healthSeconds(health[$0.id] ?? []) != nil } }
    private func average(_ values:[Double?]) -> Double? { let n = values.compactMap {$0}; return n.isEmpty ? nil : n.reduce(0,+)/Double(n.count) }
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment:.leading,spacing:20) {
                    Picker(words("period"),selection:$days) { ForEach([7,30,90,0],id:\.self) { n in Text(n == 0 ? words("allTime") : "\(n) " + words("days")).tag(n) } }.pickerStyle(.segmented)
                    if store.journalPreview { Text(words("exampleOnly")).font(.caption).foregroundStyle(Color.rust) }
                    if nights.isEmpty { Text(words("noNight")).padding(.vertical,32) }
                    else {
                        overview
                        rhythms
                        soundTotals
                        PaperCard {
                            VStack(alignment:.leading,spacing:14) {
                                Text(words("perceivedQuality")).font(.system(size:23,design:.serif))
                                ForEach(MorningFeeling.allCases) { feeling in
                                    let count = Set(nights.map { CalendarDay.key($0.end ?? $0.start) }).filter { store.archive.pages[$0]?.feeling == feeling }.count
                                    HStack { FeelingFace(feeling:feeling,selected:false).frame(width:30,height:30); MetricRow(title:words(feeling.key),value:String(count)) }
                                }
                            }
                        }
                        Text(words("nightHistory")).font(.system(size:23,design:.serif))
                        ForEach(nights.reversed()) { night in
                            PaperCard {
                                VStack(alignment:.leading,spacing:8) {
                                    Text((night.end ?? night.start).formatted(date:.abbreviated,time:.omitted)).font(.headline)
                                    MetricRow(title:words("inBed"),value:SleepMath.duration(night.duration))
                                    MetricRow(title:words("sleepHealth"),value:SleepMath.duration(NightMetrics(nights:[night]).healthSeconds(health[night.id] ?? [])))
                                    MetricRow(title:words("estimatedRest"),value:SleepMath.duration(NightMetrics(nights:[night]).rest))
                                }
                            }
                        }
                    }
                }.padding(22)
            }.background(Color.paper).navigationTitle(words("statistics")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button(words("done")) {dismiss()} } }
                .task(id:days) { await loadHealth() }
        }
    }
    private var overview: some View {
        PaperCard {
            VStack(alignment:.leading,spacing:12) {
                Text(words("averages")).font(.system(size:23,design:.serif))
                MetricRow(title:words("nights"),value:String(nights.count))
                MetricRow(title:words("inBed"),value:SleepMath.duration(average(nights.map { $0.duration })))
                MetricRow(title:words("sleepHealth"),value:SleepMath.duration(average(nights.map { NightMetrics(nights:[$0]).healthSeconds(health[$0.id] ?? []) })))
                MetricRow(title:words("latencyHealth"),value:SleepMath.duration(average(nights.map { NightMetrics(nights:[$0]).healthLatency(health[$0.id] ?? []) })))
                if loading { ProgressView() }
                Text("\(healthNights.count) / \(nights.count) · " + words("healthNights")).font(.caption).foregroundStyle(Color.ink.opacity(0.6))
                MetricRow(title:words("estimatedRest"),value:SleepMath.duration(average(nights.map { NightMetrics(nights:[$0]).rest })))
                MetricRow(title:words("quietLatency"),value:SleepMath.duration(average(nights.map { NightMetrics(nights:[$0]).quietLatency })))
                Text("\(nights.filter { !($0.acousticEpochs ?? []).isEmpty }.count) / \(nights.count) · " + words("acousticNights")).font(.caption).foregroundStyle(Color.ink.opacity(0.6))
                Text(words("restHint")).font(.caption).foregroundStyle(Color.ink.opacity(0.6))
                Chart(nights) { night in
                    BarMark(x:.value(words("nights"),night.end ?? night.checkpoint,unit:.day),y:.value(words("inBed"),night.duration/3600)).foregroundStyle(Color.rust.opacity(0.6))
                }.frame(height:140).chartYAxisLabel("h").accessibilityLabel(words("inBed"))
                Text(words("inBed")).font(.caption)
            }
        }
    }
    private var rhythms: some View {
        let bedtime = SleepMath.clockStats(nights.map(\.start))
        let wake = SleepMath.clockStats(nights.map { $0.end ?? $0.checkpoint })
        return PaperCard {
            VStack(alignment:.leading,spacing:12) {
                Text(words("sleepSchedule")).font(.system(size:23,design:.serif))
                MetricRow(title:words("bedtime"),value:SleepMath.clock(bedtime?.mean))
                MetricRow(title:words("wakeTime"),value:SleepMath.clock(wake?.mean))
                MetricRow(title:words("bedRegularity"),value:nights.count > 1 ? SleepMath.duration(bedtime.map {$0.spread*60}) : "—")
                MetricRow(title:words("wakeRegularity"),value:nights.count > 1 ? SleepMath.duration(wake.map {$0.spread*60}) : "—")
                Text(words("regularityHint")).font(.caption).foregroundStyle(Color.ink.opacity(0.6))
                Text(words("bedtimeHint")).font(.caption).foregroundStyle(Color.ink.opacity(0.6))
            }
        }
    }
    private var soundTotals: some View {
        let metrics = NightMetrics(nights:nights)
        return PaperCard {
            VStack(alignment:.leading,spacing:12) {
                Text(words("soundTotals")).font(.system(size:23,design:.serif))
                MetricRow(title:words("analysisCoverage"),value:metrics.coverage.map { "\(Int($0*100))%" } ?? "—")
                MetricRow(title:words("captureTime"),value:metrics.epochs.isEmpty ? "—" : SleepMath.duration(metrics.observed))
                MetricRow(title:words("soundActivity"),value:SleepMath.duration(metrics.activity))
                ForEach(SoundKind.allCases,id:\.self) { kind in MetricRow(title:words(kind.rawValue),value:SleepMath.duration(metrics.soundSeconds(kind))) }
                Text(words("soundStatsHint")).font(.caption).foregroundStyle(Color.ink.opacity(0.6))
            }
        }
    }
    private func loadHealth() async {
        health = [:]
        guard store.archive.preferences.health, !store.journalPreview else { return }
        loading = true; defer { loading = false }
        do {
            for night in nights {
                guard !Task.isCancelled else {return}
                let values = try await HealthReader().stages(from:night.start,to:night.end ?? night.checkpoint)
                guard !Task.isCancelled else {return}; health[night.id] = values
            }
        } catch { store.error = error.localizedDescription }
    }
}
