import Foundation

struct WakeAlarm: Identifiable, Codable, Equatable {
    var id = UUID()
    var name = L("Morning")
    var hour = 7
    var minute = 30
    var weekdays: Set<Int> = [] // Calendar: Sunday = 1
    var enabled = true
    var oneShotDate: Date?
    var sounds: [String] = ["dawn", "drift", "chimes"]
    var shuffle = true
    var fadeSeconds = 60
    var snoozeMinutes = 5
    var shakeToSnooze = true
    var lightWake: Bool?
    var lightMinutes: Int?

    var timeText: String { String(format: "%02d:%02d", hour, minute) }
    var repeatText: String {
        if weekdays.isEmpty { return L("Once") }
        if weekdays.count == 7 { return L("Every day") }
        if weekdays == [2,3,4,5,6] { return L("Weekdays") }
        return Self.days.filter { weekdays.contains($0.0) }.map { $0.1 }.joined(separator: " · ")
    }
    static let days = [(2,"Mon"),(3,"Tue"),(4,"Wed"),(5,"Thu"),(6,"Fri"),(7,"Sat"),(1,"Sun")]
    func nextDate(after date: Date, calendar: Calendar = .current) -> Date? {
        guard enabled, (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        if weekdays.isEmpty, let oneShotDate { return oneShotDate > date ? oneShotDate : nil }
        let days: [Int?] = weekdays.isEmpty ? [nil] : weekdays.sorted().map { Optional($0) }
        return days.compactMap { day -> Date? in
            var components = DateComponents()
            components.hour = hour; components.minute = minute; components.second = 0
            components.weekday = day
            return calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime,
                                     repeatedTimePolicy: .first, direction: .forward)
        }.min()
    }
    func chooseSound(previous: String?) -> String {
        let valid = sounds.filter { (SoundChoice.all.map(\.id) + AlarmSound.all.map(\.id)).contains($0) || $0.hasPrefix("custom:") }
        guard shuffle else { return valid.first ?? "dawn" }
        let pool = valid.filter { $0 != previous }
        return (pool.isEmpty ? valid : pool).randomElement() ?? "dawn"
    }
}

struct SoundChoice: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    static let all = [
        Self(id: "dawn", title: "First light", subtitle: "Warm, slowly unfolding notes", symbol: "sun.horizon.fill"),
        Self(id: "drift", title: "Drift", subtitle: "A soft, floating melody", symbol: "water.waves"),
        Self(id: "chimes", title: "Moon chimes", subtitle: "Delicate, luminous tones", symbol: "sparkles")
    ]
}

struct SoundClip: Identifiable, Codable, Equatable {
    var id = UUID()
    var date: Date
    var fileName: String
    var seconds: Double
    var kind: SleepAudioEvent.Kind?
}

struct NightEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var startedAt: Date
    var endedAt: Date
    var interrupted = false
    var mood: WakeMood?
    var notes = ""
    var clips: [SoundClip] = []
    var duration: TimeInterval { max(0, endedAt.timeIntervalSince(startedAt)) }
    var durationText: String {
        let minutes = Int(duration / 60)
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

struct ActiveNight: Codable {
    var id = UUID()
    var startedAt: Date
    var lastCheckpoint: Date
    var wakeAt: Date
    var alarm: WakeAlarm
    var clips: [SoundClip] = []
}

struct SleepData: Codable {
    var appearance: AppAppearance?
    var language: AppLanguage?
    var nightlyAlarm: WakeAlarm?
    var openJournal: Bool?
    var customSounds: [CustomAlarmSound]?
    var journalNotes: [String: JournalNote]?
    var healthConnected: Bool?
    var version = 1
    var alarms: [WakeAlarm] = [WakeAlarm()]
    var entries: [NightEntry] = []
    var activeNight: ActiveNight?
    var recordSounds = false
    var retentionDays = 7
    var lastSound: String?
    var onboardingComplete = false
}
