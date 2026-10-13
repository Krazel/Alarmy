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
        let metrics = self.metrics
        return PaperCard {
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
    @State private var days = 7
    @State private var health: [UUID:[SleepStage]] = [:]
    @State private var loading = false
    @State private var sounds = false
    private var words: Words { store.words }
    private var nights: [SleepSession] {
        let cutoff = Calendar.current.date(byAdding:.day,value:-(days-1),to:Calendar.current.startOfDay(for:Date())) ?? .distantPast
        return store.archive.sessions.filter { days == 0 || ($0.end ?? $0.checkpoint) >= cutoff }.sorted { $0.start < $1.start }
    }
    private var healthNights: [SleepSession] { nights.filter { NightMetrics(nights:[$0]).healthSeconds(health[$0.id] ?? []) != nil } }
    private func average(_ values:[Double?]) -> Double? { let n = values.compactMap {$0}; return n.isEmpty ? nil : n.reduce(0,+)/Double(n.count) }
    private var meanSleep: Double? { average(nights.map { NightMetrics(nights:[$0]).healthSeconds(health[$0.id] ?? []) }) }
    private func stageMean(_ key: String) -> Double? { average(healthNights.map { NightMetrics(nights:[$0]).healthSeconds(health[$0.id] ?? [],key:key) }) }
    private func feelingCount(_ feeling: MorningFeeling) -> Int {
        Set(nights.map { CalendarDay.key($0.end ?? $0.checkpoint) }).filter { store.archive.pages[$0]?.feeling == feeling }.count
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:14) {
                    if let first = nights.first, let last = nights.last {
                        Text((first.end ?? first.checkpoint).formatted(.dateTime.day().month(.abbreviated).locale(words.locale)) + " – " + (last.end ?? last.checkpoint).formatted(.dateTime.day().month(.abbreviated).locale(words.locale)))
                            .font(.subheadline).frame(maxWidth:.infinity)
                    }
                    Picker(words("period"),selection:$days) { ForEach([7,30,90,0],id:\.self) { n in Text(n == 0 ? words("allTime") : "\(n) " + words("days")).tag(n) } }.pickerStyle(.segmented).accessibilityIdentifier("statistics-period")
                    if store.journalPreview { Text(words("exampleOnly")).font(.caption).foregroundStyle(Color.rust) }
                    if nights.isEmpty { Text(words("noNight")).padding(.vertical,32) }
                    else {
                        overview
                        rhythms
                        stagesCard
                        HStack(alignment:.top,spacing:12) {
                            statTile("latencyHealth",value:DiaryPresentation.duration(average(nights.map { NightMetrics(nights:[$0]).healthLatency(health[$0.id] ?? []) })),symbol:"clock")
                            statTile("healthAwakenings",value:average(nights.map { DiaryPresentation.awakenings(health[$0.id] ?? []).map(Double.init) }).map { String(format:"%.1f",$0) } ?? "—",symbol:"moon.zzz")
                        }
                        feelings
                        Button { sounds = true } label: { SoundSummaryRow(nights:nights,words:words) }.buttonStyle(.plain).accessibilityIdentifier("statistics-sounds")
                        DisclosureGroup(words("acousticDetails")) { details.padding(.top,14) }
                        Text("\(nights.count) · " + words("nights")).font(.caption).foregroundStyle(Color.ink.opacity(0.5)).frame(maxWidth:.infinity)
                    }
                }.padding(20)
            }.background(Color.paper).foregroundStyle(Color.ink).tint(.rust)
                .navigationTitle(words("statistics")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button { dismiss() } label: { Image(systemName:"xmark") }.accessibilityIdentifier("close-statistics").accessibilityLabel(words("done")) } }
                .task(id:days) { await loadHealth() }
                .sheet(isPresented:$sounds) { SoundsScreen(sessionIDs:nights.map(\.id)) }
        }
    }
    private func statTile(_ key: String,value: String,symbol: String) -> some View {
        PaperCard(padding:15) {
            VStack(alignment:.leading,spacing:8) {
                Image(systemName:symbol).foregroundStyle(Color.rust)
                CompactMetric(title:words(key),value:value)
            }
        }
    }
    private var overview: some View {
        PaperCard(padding:18) {
            VStack(alignment:.leading,spacing:12) {
                Text(words("averages")).font(.system(size:23,design:.serif))
                Text(DiaryPresentation.duration(meanSleep)).font(.system(size:36,design:.serif)).accessibilityIdentifier("statistics-sleep")
                Text(words("meanSleep")).font(.caption).foregroundStyle(Color.ink.opacity(0.6))
                if loading { ProgressView() }
                Chart(nights) { night in
                    if let seconds = NightMetrics(nights:[night]).healthSeconds(health[night.id] ?? []) {
                        BarMark(x:.value(words("nights"),night.end ?? night.checkpoint,unit:.day),y:.value(words("asleepShort"),seconds/3600)).foregroundStyle(DiaryPresentation.color("core")).cornerRadius(4)
                    }
                }.frame(height:125).chartYScale(domain:0...max(8,nights.map { NightMetrics(nights:[$0]).healthSeconds(health[$0.id] ?? []) ?? 0 }.max().map {$0/3600} ?? 8)).chartYAxisLabel("h").accessibilityLabel(words("meanSleep"))
                HStack {
                    CompactMetric(title:words("meanBed"),value:DiaryPresentation.duration(average(nights.map(\.duration))))
                    Divider()
                    CompactMetric(title:words("usualRating"),value:MorningFeeling.allCases.max { feelingCount($0) < feelingCount($1) }.flatMap { feelingCount($0) > 0 ? words($0.key) : nil } ?? "—")
                }.fixedSize(horizontal:false,vertical:true)
                Text("\(healthNights.count) / \(nights.count) · " + words("healthNights")).font(.caption2).foregroundStyle(Color.ink.opacity(0.5))
                if healthNights.isEmpty { Text(words("compactHealthEmpty")).font(.caption).foregroundStyle(Color.ink.opacity(0.55)) }
            }
        }
    }
    private var rhythms: some View {
        let bedtime = SleepMath.clockStats(nights.map(\.start))
        let wake = SleepMath.clockStats(nights.map { $0.end ?? $0.checkpoint })
        return PaperCard(padding:18) {
            VStack(alignment:.leading,spacing:12) {
                Text(words("sleepSchedule")).font(.system(size:23,design:.serif))
                Chart(Array(nights.suffix(14))) { night in
                    let start = (SleepMath.clockMinutes(night.start)+720).truncatingRemainder(dividingBy:1440)/60
                    BarMark(xStart:.value(words("bedtime"),start),xEnd:.value(words("wakeTime"),start+night.duration/3600),y:.value(words("nights"),(night.end ?? night.checkpoint).formatted(.dateTime.day().month(.abbreviated).locale(words.locale))))
                        .foregroundStyle(DiaryPresentation.color("deep").opacity(0.65)).cornerRadius(4)
                }.frame(height:max(65,CGFloat(min(nights.count,14))*17)).chartXAxis {
                    AxisMarks(values:.stride(by:4)) { value in
                        AxisGridLine(); AxisValueLabel { if let hour = value.as(Double.self) { Text(String(format:"%02d:00",(Int(hour)+12)%24)).font(.system(size:9)) } }
                    }
                }.accessibilityLabel(words("sleepSchedule"))
                if nights.count > 14 { Text(words("latestSchedule")).font(.caption2) }
                HStack {
                    CompactMetric(title:words("bedtime"),value:SleepMath.clock(bedtime?.mean))
                    CompactMetric(title:words("wakeTime"),value:SleepMath.clock(wake?.mean))
                }
                Divider()
                MetricRow(title:words("bedRegularity"),value:nights.count > 1 ? "± " + DiaryPresentation.duration(bedtime.map {$0.spread*60}) : "—")
                MetricRow(title:words("wakeRegularity"),value:nights.count > 1 ? "± " + DiaryPresentation.duration(wake.map {$0.spread*60}) : "—")
                Text(words("regularityHint")).font(.caption2).foregroundStyle(Color.ink.opacity(0.55))
            }
        }
    }
    private var stagesCard: some View {
        let keys = ["core","deep","rem","asleep"].filter { (stageMean($0) ?? 0) > 0 }
        let total = keys.reduce(0.0) { $0+(stageMean($1) ?? 0) }
        return PaperCard(padding:18) {
            VStack(alignment:.leading,spacing:16) {
                Text(words("sleepStages")).font(.system(size:23,design:.serif)).accessibilityIdentifier("statistics-stages")
                if keys.isEmpty { Text(words("compactHealthEmpty")).font(.caption).foregroundStyle(Color.ink.opacity(0.55)) }
                else {
                    HStack(spacing:18) {
                        ZStack {
                            ForEach(keys,id:\.self) { key in
                                let before = keys.prefix { $0 != key }.reduce(0.0) { $0+(stageMean($1) ?? 0) }
                                Circle().trim(from:before/total,to:(before+(stageMean(key) ?? 0))/total).stroke(DiaryPresentation.color(key),lineWidth:20).rotationEffect(.degrees(-90))
                            }
                            Text(DiaryPresentation.duration(meanSleep)).font(.system(size:19,design:.serif)).minimumScaleFactor(0.7).lineLimit(1).padding(16)
                        }.frame(width:125,height:125).padding(10).accessibilityLabel(words("meanSleep") + ": " + DiaryPresentation.duration(meanSleep))
                        VStack(spacing:12) {
                            ForEach(keys,id:\.self) { key in
                                VStack(alignment:.leading,spacing:4) {
                                    HStack(spacing:5) { Circle().fill(DiaryPresentation.color(key)).frame(width:8,height:8); Text(words(key)).font(.caption) }
                                    Text(DiaryPresentation.duration(stageMean(key))).font(.system(size:19,design:.serif))
                                }.frame(maxWidth:.infinity,alignment:.leading)
                            }
                        }
                    }
                    HStack {
                        ProgressView(value:(stageMean("awake") ?? 0)/max(1,total+(stageMean("awake") ?? 0))).tint(DiaryPresentation.color("awake")).frame(maxWidth:110)
                        Spacer(); VStack(alignment:.trailing,spacing:3) { Text(words("awakeSeparate")).font(.caption2); Text(DiaryPresentation.duration(stageMean("awake"))).font(.subheadline) }
                    }
                    Text(words("healthMean")).font(.caption2).foregroundStyle(Color.ink.opacity(0.55))
                }
            }
        }
    }
    private var feelings: some View {
        PaperCard(padding:15) {
            VStack(alignment:.leading,spacing:8) {
                Text(words("feeling")).font(.system(size:21,design:.serif))
                HStack(alignment:.top,spacing:2) {
                    ForEach(MorningFeeling.allCases) { feeling in
                        VStack(spacing:4) {
                            FeelingFace(feeling:feeling).frame(maxHeight:54)
                            Text("\(feelingCount(feeling))").font(.system(size:19,design:.serif))
                            Text(words(feeling.key)).font(.system(size:9)).lineLimit(1).minimumScaleFactor(0.6)
                        }.frame(maxWidth:.infinity).accessibilityElement(children:.combine)
                    }
                }
                Text(words("ratingHint")).font(.caption2).foregroundStyle(Color.ink.opacity(0.55))
            }
        }
    }
    private var details: some View {
        VStack(alignment:.leading,spacing:16) {
            let metrics = NightMetrics(nights:nights)
            MetricRow(title:words("estimatedRest"),value:SleepMath.duration(average(nights.map { NightMetrics(nights:[$0]).rest })))
            MetricRow(title:words("quietLatency"),value:SleepMath.duration(average(nights.map { NightMetrics(nights:[$0]).quietLatency })))
            MetricRow(title:words("analysisCoverage"),value:metrics.coverage.map { "\(Int($0*100))%" } ?? "—")
            MetricRow(title:words("captureTime"),value:metrics.epochs.isEmpty ? "—" : SleepMath.duration(metrics.observed))
            MetricRow(title:words("soundActivity"),value:SleepMath.duration(metrics.activity))
            Text(words("restHint")).font(.caption).foregroundStyle(Color.ink.opacity(0.6))
            Text(words("nightHistory")).font(.system(size:23,design:.serif))
            ForEach(nights.reversed()) { night in
                DisclosureGroup((night.end ?? night.checkpoint).formatted(date:.abbreviated,time:.omitted)) {
                    NightAnalysisCard(nights:[night],stages:health[night.id] ?? [],feeling:store.page(night.end ?? night.checkpoint).feeling,words:words)
                }
            }
        }
    }
    private func loadHealth() async {
        health = [:]
        #if DEBUG
        if store.testMode && ProcessInfo.processInfo.arguments.contains("--health-fixture") {
            for night in nights { health[night.id] = DiaryPresentation.fixtureStages(night) }; return
        }
        #endif
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
