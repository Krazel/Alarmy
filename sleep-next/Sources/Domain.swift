import Foundation

struct AlarmPlan: Codable, Equatable {
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
enum SoundKind: String, Codable, CaseIterable { case snore, breath, voice, cough, other }
struct NightClip: Codable, Equatable, Identifiable {
    let id: UUID
    let created: Date
    let filename: String
    let duration: Double
    var kind: SoundKind = .other
    var analysisDone = false
    var suggestion = false
}
struct SleepSession: Codable, Equatable, Identifiable {
    let id: UUID
    let start: Date
    var checkpoint: Date
    var end: Date?
    var wake: Date
    var alarmID: UUID
    let soundID: String
    var interrupted = false
    var clips: [NightClip] = []
    var duration: TimeInterval { max(0, (end ?? checkpoint).timeIntervalSince(start)) }
}
struct JournalPage: Codable, Equatable {
    var feeling: MorningFeeling?
    var text = ""
}
struct ImportedTone: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let filename: String
}
struct Preferences: Codable, Equatable {
    var language = "system"
    var appearance = "auto"
    var record = false
    var keepDays = 30
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
