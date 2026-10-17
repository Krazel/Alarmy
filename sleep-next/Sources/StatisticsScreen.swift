import SwiftUI
import Charts

struct MetricRow: View {
    let title: String
    let value: String
    var body: some View {
        HStack(alignment:.firstTextBaseline) { Text(title).foregroundStyle(Color.ink.opacity(0.65)); Spacer(minLength:16); Text(value).monospacedDigit().multilineTextAlignment(.trailing) }.font(.subheadline).padding(.vertical,3)
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
    @State private var showNaps = false
    @State private var estimates: [UUID:[SleepStage]] = [:]
    @State private var loading = false
    @State private var sounds = false
    private var words: Words { store.words }
    private var nights: [SleepSession] {
        let cutoff = Calendar.current.date(byAdding:.day,value:-(days-1),to:Calendar.current.startOfDay(for:Date())) ?? .distantPast
        return store.archive.sessions.filter { ($0.isNap == true) == showNaps && (days == 0 || ($0.end ?? $0.checkpoint) >= cutoff) }.sorted { $0.start < $1.start }
    }
    private var estimatedNights: [SleepSession] { nights.filter { NightMetrics(nights:[$0]).sleepEstimate(estimates[$0.id] ?? []) != nil } }
    private func average(_ values:[Double?]) -> Double? { let n = values.compactMap {$0}; return n.isEmpty ? nil : n.reduce(0,+)/Double(n.count) }
    private var meanSleep: Double? { average(nights.map { NightMetrics(nights:[$0]).sleepEstimate(estimates[$0.id] ?? []) }) }
    private var meanGoalSleep: Double? { average(nights.map { let c = SleepContinuity(nights:[$0],stages:estimates[$0.id] ?? []); return c.coverage >= 0.99 ? c.asleep : nil }) }
    private func stageMean(_ key: String) -> Double? { average(estimatedNights.map { NightMetrics(nights:[$0]).sleepSeconds(estimates[$0.id] ?? [],key:key) }) }
    private func feelingCount(_ feeling: MorningFeeling) -> Int {
        Set(nights.map { CalendarDay.key($0.end ?? $0.checkpoint) }).filter { store.archive.pages[$0]?.feeling == feeling }.count
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:14) {
                    PageHeading(title: words("statistics"))
                    Picker(words("period"), selection: $days) {
                        Text(words("weekPeriod")).tag(7); Text(words("monthPeriod")).tag(30); Text(words("yearPeriod")).tag(365); Text(words("allTime")).tag(0)
                    }.pickerStyle(.segmented).accessibilityIdentifier("statistics-period")
                    Picker(words("sessionType"),selection:$showNaps) { Text(words("nightSession")).tag(false); Text(words("nap")).tag(true) }.pickerStyle(.segmented).accessibilityIdentifier("statistics-session-type")
                    if store.journalPreview { Text(words("exampleOnly")).font(.caption).foregroundStyle(Color.rust) }
                    if nights.isEmpty { Text(words("noNight")).padding(.vertical,32) }
                    else {
                        overview
                        HStack(alignment: .top, spacing: 12) {
                            statTile("bedRegularity", value: nights.count > 1 ? "± " + DiaryPresentation.duration(SleepMath.clockStats(nights.map { $0.analysisSession.start }).map { $0.spread * 60 }) : "—", symbol: "chart.bar.fill")
                            statTile("inBed", value: DiaryPresentation.duration(average(nights.map { NightMetrics(nights: [$0]).inBed })), symbol: "bed.double")
                        }
                        if !showNaps {
                            NavigationLink { ScrollView { rhythms.padding(20) }.background(Color.paper).navigationTitle(words("scheduleLink")) } label: {
                                ReviewLink(title: words("scheduleLink"), symbol: "clock", subtitle: words("scheduleSubtitle"))
                            }.buttonStyle(.plain)
                        }
                        Button { sounds = true } label: { ReviewLink(title: words("sounds"), symbol: "waveform", subtitle: words("soundSubtitle")) }.buttonStyle(.plain).accessibilityIdentifier("statistics-sounds")
                        NavigationLink {
                            ScrollView { ExtraStatistics(nights: nights, stages: estimates).padding(20) }.background(Color.paper).navigationTitle(words("habits"))
                        } label: { ReviewLink(title: words("habits"), symbol: "leaf", subtitle: words("habitsSubtitle")) }.buttonStyle(.plain)
                        NavigationLink {
                            ScrollView {
                                VStack(spacing: 16) {
                                    stagesCard
                                    HStack(alignment: .top, spacing: 12) {
                                        statTile("latencyHealth",value:DiaryPresentation.duration(average(nights.map { NightMetrics(nights:[$0]).sleepLatency(estimates[$0.id] ?? []) })),symbol:"clock")
                                        statTile("healthAwakenings",value:average(nights.map { SleepContinuity(nights:[$0],stages:estimates[$0.id] ?? []).awakenings.map(Double.init) }).map { String(format:"%.1f",$0) } ?? "—",symbol:"moon.zzz")
                                    }
                                    feelings
                                    details
                                }.padding(20)
                            }.background(Color.paper).navigationTitle(words("sleepDetails"))
                        } label: { ReviewLink(title: words("sleepDetails"), symbol: "chart.xyaxis.line", subtitle: words("moreStatistics")) }.buttonStyle(.plain).accessibilityIdentifier("statistics-stage-details")
                        Text("\(nights.count) · " + words("nights")).font(.caption).foregroundStyle(Color.ink.opacity(0.5)).frame(maxWidth:.infinity)
                    }
                }.padding(20)
            }.background(Color.paper).foregroundStyle(Color.ink).tint(.rust)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button { dismiss() } label: { Image(systemName:"xmark") }.accessibilityIdentifier("close-statistics").accessibilityLabel(words("done")) } }
                .task(id:"\(days)-\(showNaps)-\(LocalSleepEstimator.cacheKey(nights))") { await loadAnalysis() }
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
                Text(DiaryPresentation.duration(meanSleep)).font(.system(size:44,design:.serif)).accessibilityIdentifier("statistics-sleep")
                Text(words("meanSleep")).font(.caption).foregroundStyle(Color.ink.opacity(0.6))
                if loading { ProgressView() }
                if !estimatedNights.isEmpty {
                Chart(nights) { night in
                    if let seconds = NightMetrics(nights:[night]).sleepEstimate(estimates[night.id] ?? []) {
                        BarMark(x:.value(words("nights"),night.end ?? night.checkpoint,unit:.day),y:.value(words("asleepShort"),seconds/3600)).foregroundStyle(DiaryPresentation.color("core")).cornerRadius(4)
                    }
                }.frame(height:210).chartYScale(domain:0...max(8,nights.map { NightMetrics(nights:[$0]).sleepEstimate(estimates[$0.id] ?? []) ?? 0 }.max().map {$0/3600} ?? 8)).chartYAxisLabel("h").accessibilityLabel(words("meanSleep"))
                }
                Text("\(estimatedNights.count) / \(nights.count) · " + words("healthNights")).font(.caption2).foregroundStyle(Color.ink.opacity(0.5))
                if estimatedNights.isEmpty { Text(words("compactHealthEmpty")).font(.caption).foregroundStyle(Color.ink.opacity(0.55)) }
            }
        }
    }
    private var rhythms: some View {
        let nights = self.nights.map(\.analysisSession)
        let bedtime = SleepMath.clockStats(nights.map(\.start))
        let wake = SleepMath.clockStats(nights.map { $0.end ?? $0.checkpoint })
        let shown = Array(nights.suffix(14))
        let starts = shown.map { (SleepMath.clockMinutes($0.start)+720).truncatingRemainder(dividingBy:1440)/60 }
        let ends = zip(shown,starts).map { $1+$0.duration/3600 }
        let lower = floor(starts.min() ?? 0), upper = max(lower+1,ceil(ends.max() ?? 24))
        return PaperCard(padding:18) {
            VStack(alignment:.leading,spacing:12) {
                Text(words("sleepSchedule")).font(.system(size:23,design:.serif))
                Chart(Array(nights.suffix(14))) { night in
                    let start = (SleepMath.clockMinutes(night.start)+720).truncatingRemainder(dividingBy:1440)/60
                    BarMark(xStart:.value(words("bedtime"),start),xEnd:.value(words("wakeTime"),start+night.duration/3600),y:.value(words("nights"),(night.end ?? night.checkpoint).formatted(.dateTime.day().month(.abbreviated).locale(words.locale))),height:.fixed(9))
                        .foregroundStyle(DiaryPresentation.color("deep").opacity(0.65)).cornerRadius(4)
                }.frame(height:max(65,CGFloat(min(nights.count,14))*22)).chartXScale(domain:lower...upper).chartXAxis {
                    AxisMarks(values:.stride(by:3)) { value in
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
                MetricRow(title:words("weekendShift"),value:AnalysisInsights.weekendShift(nights).map { ($0 >= 0 ? "+ " : "− ") + SleepMath.duration(abs($0)) } ?? "—")
                Text(words("weekendHint")).font(.caption2).foregroundStyle(Color.ink.opacity(0.55))
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
                    Text(words("localEstimate")).font(.caption2).foregroundStyle(Color.ink.opacity(0.55))
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
            if !showNaps {
                MetricRow(title:words("sleepGoal"),value:SleepMath.duration(Double(store.archive.preferences.sleepGoalMinutes ?? 480)*60))
                MetricRow(title:words("goalDifference"),value:meanGoalSleep.map { ($0 >= Double(store.archive.preferences.sleepGoalMinutes ?? 480)*60 ? "+ " : "− ") + SleepMath.duration(abs($0-Double(store.archive.preferences.sleepGoalMinutes ?? 480)*60)) } ?? "—")
            }
            MetricRow(title:words("estimatedRest"),value:SleepMath.duration(average(nights.map { NightMetrics(nights:[$0]).rest })))
            MetricRow(title:words("quietLatency"),value:SleepMath.duration(average(nights.map { NightMetrics(nights:[$0]).quietLatency })))
            MetricRow(title:words("analysisCoverage"),value:metrics.coverage.map { "\(Int($0*100))%" } ?? "—")
            MetricRow(title:words("captureTime"),value:metrics.epochs.isEmpty ? "—" : SleepMath.duration(metrics.observed))
            MetricRow(title:words("soundActivity"),value:SleepMath.duration(metrics.activity))
            Text(words("restHint")).font(.caption).foregroundStyle(Color.ink.opacity(0.6))
            Text(words("nightHistory")).font(.system(size:23,design:.serif))
            ForEach(nights.reversed()) { night in
                DisclosureGroup((night.end ?? night.checkpoint).formatted(date:.abbreviated,time:.omitted)) {
                    ContinuityCard(nights:[night],stages:estimates[night.id] ?? [],words:words)
                    AlarmMetrics(night:night,words:words)
                }
            }
        }
    }
    private func loadAnalysis() async {
        estimates = [:]
        #if DEBUG
        if store.testMode && ProcessInfo.processInfo.arguments.contains("--stage-fixture") {
            for night in nights { estimates[night.id] = DiaryPresentation.fixtureStages(night) }; return
        }
        #endif
        loading = true; defer { loading = false }
        let source = nights
        let result = await Task.detached(priority:.userInitiated) {
            Dictionary(uniqueKeysWithValues:source.map {($0.id,LocalSleepEstimator.stages(night:$0))})
        }.value
        if !Task.isCancelled {estimates = result}
    }
}
