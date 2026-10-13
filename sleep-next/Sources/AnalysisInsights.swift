import Foundation

enum SleepHabit: String, Codable, CaseIterable, Identifiable {
    case lateCoffee, exercise, stress, lateMeal, alcohol
    var id: String { rawValue }
}

struct SessionCorrection: Codable, Equatable {
    let start: Date
    let end: Date
    func valid(for night: SleepSession) -> Bool {
        start >= night.start && end <= (night.end ?? night.checkpoint) && end > start
    }
}

extension SleepSession {
    // Preserve raw capture timestamps. Trimming cannot create observations.
    var analysisSession: SleepSession {
        guard let correction, correction.valid(for:self) else { return self }
        var value = self
        value.start = correction.start; value.end = correction.end; value.checkpoint = correction.end
        value.correction = nil
        return value
    }
}

struct SleepContinuity {
    let stages: [SleepStage]
    let metrics: NightMetrics
    init(nights: [SleepSession], stages: [SleepStage]) {
        let metrics = NightMetrics(nights:nights)
        self.metrics = metrics
        self.stages = HealthReader.normalize(stages.flatMap { stage in
            metrics.clipped([DateInterval(start:stage.start,end:max(stage.start,stage.end))]).map {
                SleepStage(id:UUID(),start:$0.start,end:$0.end,key:stage.key)
            }
        })
    }
    var asleep: Double? { metrics.healthSeconds(stages) }
    var coverage: Double { metrics.inBed > 0 ? SleepMath.seconds(stages.map { DateInterval(start:$0.start,end:$0.end) }) / metrics.inBed : 0 }
    // Partial coverage is not complete-night sleep efficiency or latency.
    var efficiency: Double? { coverage >= 0.99 ? asleep.map { $0 / metrics.inBed } : nil }
    var latency: Double? { metrics.healthLatency(stages) }
    var awakenings: Int? { coverage >= 0.99 ? DiaryPresentation.awakenings(stages) : nil }
    var awakeDuringSleep: Double? {
        guard coverage >= 0.99, let first = stages.first(where:{$0.key != "awake"}),
              let last = stages.last(where:{$0.key != "awake"}) else { return nil }
        return stages.filter { $0.key == "awake" && $0.start >= first.start && $0.end <= last.end }.reduce(0) { $0+$1.end.timeIntervalSince($1.start) }
    }
    var longestSleep: Double? {
        guard asleep != nil else { return nil }
        return SleepMath.union(stages.filter {$0.key != "awake"}.map { DateInterval(start:$0.start,end:$0.end) }).map(\.duration).max()
    }
}

enum AnalysisInsights {
    static func average(_ values: [Double?]) -> Double? {
        let values = values.compactMap {$0}.filter(\.isFinite)
        return values.isEmpty ? nil : values.reduce(0,+)/Double(values.count)
    }
    static func clockDifference(_ a: Double, _ b: Double) -> Double {
        (a-b+2160).truncatingRemainder(dividingBy:1440)-720
    }
    static func weekendShift(_ nights: [SleepSession], calendar: Calendar = .current) -> Double? {
        let values = nights.filter {$0.isNap != true}.map(\.analysisSession)
        let weekend = values.filter { calendar.isDateInWeekend($0.end ?? $0.checkpoint) }
        let weekdays = values.filter { !calendar.isDateInWeekend($0.end ?? $0.checkpoint) }
        guard weekend.count >= 2, weekdays.count >= 2,
              let a = SleepMath.clockStats(weekend.map {$0.end ?? $0.checkpoint},calendar:calendar),
              let b = SleepMath.clockStats(weekdays.map {$0.end ?? $0.checkpoint},calendar:calendar) else { return nil }
        return clockDifference(a.mean,b.mean)*60
    }
    struct HabitComparison {
        let taggedDays: Int
        let otherDays: Int
        let taggedBed: Double
        let otherBed: Double
    }
    static func habit(_ habit: SleepHabit, nights: [SleepSession], pages: [String:JournalPage]) -> HabitComparison? {
        let days = Dictionary(grouping:nights.filter {$0.isNap != true},by:{CalendarDay.key($0.end ?? $0.checkpoint)})
        var tagged: [Double] = [], other: [Double] = []
        for (key,nights) in days {
            guard let habits = pages[key]?.habits else { continue }
            let seconds = NightMetrics(nights:nights).inBed
            if habits.contains(habit) { tagged.append(seconds) } else { other.append(seconds) }
        }
        guard tagged.count >= 3, other.count >= 3 else { return nil }
        return HabitComparison(taggedDays:tagged.count,otherDays:other.count,taggedBed:average(tagged)!,otherBed:average(other)!)
    }
    // CSV excludes diary text, filenames and audio. Blank measurements stay blank.
    static func csv(nights: [SleepSession], pages: [String:JournalPage], stages: [UUID:[SleepStage]], words: Words) -> String {
        func cell(_ text: String) -> String { "\"" + text.replacingOccurrences(of:"\"",with:"\"\"") + "\"" }
        func minutes(_ seconds: Double?) -> String { seconds.map { String(format:"%.1f",locale:Locale(identifier:"en_US_POSIX"),$0/60) } ?? "" }
        let headers = ["date","sessionType","bedtime","wakeTime","bedMinutes","sleepMinutes","dataSource","analysisCoverage","snoozes","feeling","habits"]
        var rows = [headers.map {cell(words("csv-"+$0))}.joined(separator:",")]
        let iso = ISO8601DateFormatter()
        for raw in nights.sorted(by:{$0.start < $1.start}) {
            let night = raw.analysisSession, m = NightMetrics(nights:[night])
            let page = pages[CalendarDay.key(raw.end ?? raw.checkpoint)]
            let sleep = m.healthSeconds(stages[raw.id] ?? [])
            let values = [CalendarDay.key(raw.end ?? raw.checkpoint),words(raw.isNap == true ? "nap" : "nightSession"),iso.string(from:night.start),iso.string(from:night.end ?? night.checkpoint),minutes(m.inBed),minutes(sleep),sleep == nil ? words("unavailable") : words("healthSource"),m.coverage.map {String(format:"%.1f",$0*100)} ?? "",raw.alarmStatsTracked == true && raw.hasAlarm ? String(raw.snoozeDates?.count ?? 0) : "",page?.feeling.map {words($0.key)} ?? "",page?.habits.map {$0.map {words($0.rawValue)}.joined(separator:"; ")} ?? ""]
            rows.append(values.map(cell).joined(separator:","))
        }
        return "\u{FEFF}" + rows.joined(separator:"\r\n")
    }
}

extension SleepStore {
    func setHabit(_ habit: SleepHabit, day: Date) {
        let key = CalendarDay.key(day)
        commit { value in
            var habits = value.pages[key]?.habits ?? []
            if habits.contains(habit) { habits.removeAll {$0 == habit} } else { habits.append(habit) }
            value.pages[key,default:JournalPage()].habits = habits
        }
    }
    func recordNoHabits(day: Date) { let key = CalendarDay.key(day); commit {$0.pages[key,default:JournalPage()].habits = []} }
    func correctSession(id: UUID, start: Date, end: Date, nap: Bool, reset: Bool = false) async -> Bool {
        guard let raw = archive.sessions.first(where:{$0.id == id}) else { return false }
        let correction = SessionCorrection(start:start,end:end)
        guard reset || correction.valid(for:raw) else { return false }
        return await commit { value in
            guard let i = value.sessions.firstIndex(where:{$0.id == id}) else { return }
            value.sessions[i].correction = reset ? nil : correction
            value.sessions[i].isNap = nap
        }.value
    }
}
