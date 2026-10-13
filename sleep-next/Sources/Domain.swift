import Foundation

enum AlarmMode: String, Codable, CaseIterable { case analysis, exact, smart }

struct AlarmPlan: Codable, Equatable {
    var mode: AlarmMode?
    var windowMinutes: Int?
    var resolvedMode: AlarmMode { mode ?? .exact }
    var window: Int { [15,30,45,60].contains(windowMinutes ?? 30) ? (windowMinutes ?? 30) : 30 }
    var hour = 7
    var minute = 30
    var sounds = ["aurora", "lumen", "brisa"]
    var gradual = true
    var snoozeMinutes = 5
    var motionSnooze = true
    var lightMinutes = 0
    var clock: String { String(format: "%02d:%02d", hour, minute) }
    func next(after now: Date, calendar: Calendar = .current) -> Date? {
        guard (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        return calendar.nextDate(after: now, matching: DateComponents(hour: hour, minute: minute, second: 0), matchingPolicy: .nextTime, repeatedTimePolicy: .first)
    }
    func sound(excluding previous: String?) -> String {
        let choices = sounds.isEmpty ? ["aurora"] : sounds
        let remaining = choices.filter { $0 != previous }
        return (remaining.isEmpty ? choices : remaining).randomElement() ?? "aurora"
    }
}
enum MorningFeeling: Int, Codable, CaseIterable, Identifiable {
    case exhausted, tired, steady, peaceful, bright
    var id: Int { rawValue }
    var key: String { ["exhausted", "tired", "steady", "peaceful", "bright"][rawValue] }
}
enum SoundKind: String, Codable, CaseIterable {
    case snore, breath, voice, cough, other
    var symbol: String {
        switch self {
        case .snore: return "zzz"
        case .breath: return "wind"
        case .voice: return "bubble.left"
        case .cough: return "waveform.path"
        case .other: return "waveform"
        }
    }
}
struct SoundEvent: Codable, Equatable, Identifiable {
    let start: Double
    var duration: Double
    let kind: SoundKind
    var confidence: Double
    var id: String { "\(kind.rawValue)-\(start)" }
}
struct NightClip: Codable, Equatable, Identifiable {
    let id: UUID
    let created: Date
    let filename: String
    let duration: Double
    var kind: SoundKind = .other
    var analysisDone = false
    var suggestion = false
    var events: [SoundEvent]?
    var analysisVersion: Int?
    var analysisFailed: Bool?
}
struct SleepSession: Codable, Equatable, Identifiable {
    let id: UUID
    var start: Date
    var checkpoint: Date
    var end: Date?
    var wake: Date
    var alarmID: UUID
    let soundID: String
    var interrupted = false
    var clips: [NightClip] = []
    var capturePaused: Bool?
    var captureSpans: [CaptureSpan]?
    var resumeCaptureAfterAlarm: Bool?
    var mode: AlarmMode?
    var windowStart: Date?
    var latestWake: Date?
    var backupAlarmID: UUID?
    var smartTriggered: Bool?
    var retainAudio: Bool?
    var acousticEpochs: [AcousticEpoch]?
    var soundSummaries: [NightSoundSummary]?
    var soundAnalysisIncomplete: Bool?
    var correction: SessionCorrection?
    var isNap: Bool?
    var snoozeDates: [Date]?
    var alarmObservedAt: Date?
    var alarmStatsTracked: Bool?
    var hasAlarm: Bool { mode != .analysis }
    var hasActiveSmartWindow: Bool { mode == .smart && windowStart != nil && smartTriggered != true }
    var editableAlarmTime: Date { hasActiveSmartWindow ? (latestWake ?? wake) : wake }
    var duration: TimeInterval { max(0, (end ?? checkpoint).timeIntervalSince(start)) }
    func snoozed(until wake: Date) -> SleepSession {
        var next = self
        next.alarmID = UUID(); next.wake = wake
        next.windowStart = nil; next.backupAlarmID = nil
        if resumeCaptureAfterAlarm == true { next.capturePaused = false }
        next.resumeCaptureAfterAlarm = nil
        return next
    }
}
struct CaptureSpan: Codable, Equatable, Identifiable {
    let id: UUID
    let start: Date
    var end: Date
    var reason: String
}
struct JournalPage: Codable, Equatable {
    var feeling: MorningFeeling?
    var text = ""
    // nil means the user has not recorded habits, not an unexposed control day.
    var habits: [SleepHabit]?
}
struct ImportedTone: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let filename: String
}
struct Preferences: Codable, Equatable {
    var sleepGoalMinutes: Int?
    var analyze: Bool?
    var analysisEnabled: Bool { record && (analyze ?? true) }
    var language = "system"
    var appearance = "auto"
    var record = false
    var sensitivity: Double?
    var keepDays = 90
    var openJournal = true
    var health = false
}
struct AppArchive: Codable, Equatable {
    var schema = 1
    var revision = 0
    var plan = AlarmPlan()
    var preferences = Preferences()
    var active: SleepSession?
    var sessions: [SleepSession] = []
    var pages: [String: JournalPage] = [:]
    var tones: [ImportedTone] = []
    var lastSound: String?
    // Optional for archives created by 1.1(1). Persist deletion intent before touching audio.
    var pendingClipDeletions: [String]?
    mutating func queueClipDeletion(_ filenames: [String]) {
        pendingClipDeletions = Array(Set((pendingClipDeletions ?? []) + filenames)).sorted()
    }
    mutating func completeClipDeletion(_ filenames: [String]) {
        let removed = Set(filenames)
        for i in sessions.indices { sessions[i].clips.removeAll { removed.contains($0.filename) } }
        active?.clips.removeAll { removed.contains($0.filename) }
        pendingClipDeletions?.removeAll { removed.contains($0) }
        if pendingClipDeletions?.isEmpty == true { pendingClipDeletions = nil }
    }
}
enum CalendarDay {
    static func key(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year,.month,.day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    static func week(around day: Date, calendar: Calendar = .current) -> [Date] {
        let start = calendar.startOfDay(for: day)
        let offset = (calendar.component(.weekday, from: start) + 5) % 7
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0-offset, to: start) }
    }
    static func month(around day: Date, calendar: Calendar = .current) -> [Date?] {
        guard let start = calendar.dateInterval(of: .month, for: day)?.start,
              let days = calendar.range(of: .day, in: .month, for: day) else { return [] }
        let offset = (calendar.component(.weekday, from: start) + 5) % 7
        let count = ((offset + days.count + 6) / 7) * 7
        return (0..<count).map { index in
            let dayIndex = index - offset
            guard (0..<days.count).contains(dayIndex) else { return nil }
            return calendar.date(byAdding: .day, value: dayIndex, to: start)
        }
    }
}
enum DiskLocation {
    static let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("AlarmaNext", isDirectory: true)
    static var clips: URL { root.appendingPathComponent("Clips", isDirectory: true) }
    static var tones: URL { FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("Sounds", isDirectory: true) }
    static func child(_ name: String, of directory: URL) -> URL? {
        guard !name.isEmpty, name == (name as NSString).lastPathComponent, !name.contains("..") else { return nil }
        return directory.appendingPathComponent(name)
    }
}
