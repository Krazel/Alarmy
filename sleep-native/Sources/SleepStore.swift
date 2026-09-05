import Foundation
import Combine

@MainActor
final class SleepStore: ObservableObject {
    @Published private(set) var data: SleepData
    @Published var error: String?
    private let file: URL
    private var canWrite = true
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AlarmaSleep", isDirectory: true)
    }
    static var clipsDirectory: URL { directory.appendingPathComponent("Clips", isDirectory: true) }

    init(file: URL? = nil) {
        self.file = file ?? Self.directory.appendingPathComponent("sleep-data.json")
        do {
            try FileManager.default.createDirectory(at: self.file.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: self.file.path) {
                data = try JSONDecoder().decode(SleepData.self, from: Data(contentsOf: self.file))
                guard data.version == 1 else { throw CocoaError(.fileReadCorruptFile) }
            } else {
                data = SleepData()
                data.alarms[0].oneShotDate = data.alarms[0].nextDate(after: Date())
            }
        } catch {
            data = SleepData(); canWrite = false
            self.error = L("Your saved data could not be opened. It has been preserved. Restart the app to try again.")
        }
        if data.nightlyAlarm == nil {
            var alarm = data.alarms.first ?? WakeAlarm()
            alarm.oneShotDate = nil; alarm.enabled = true; alarm.weekdays = []
            alarm.sounds = AlarmSound.defaultIds; alarm.shakeToSnooze = true
            data.nightlyAlarm = alarm
        }
    }

    func change(_ update: (inout SleepData) -> Void) {
        guard canWrite else { error = L("Saved data is unavailable. Restart before making changes."); return }
        var candidate = data
        update(&candidate)
        do {
            let encoded = try JSONEncoder().encode(candidate)
            try encoded.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            data = candidate
        } catch { self.error = LF("Could not save your changes: %@", String(describing: error.localizedDescription)) }
    }
    func saveAlarm(_ input: WakeAlarm) {
        var alarm = input
        alarm.oneShotDate = nil
        if alarm.enabled && alarm.weekdays.isEmpty { alarm.oneShotDate = alarm.nextDate(after: Date()) }
        change { value in
            if let index = value.alarms.firstIndex(where: { $0.id == alarm.id }) { value.alarms[index] = alarm }
            else if value.alarms.count < 8 { value.alarms.append(alarm) }
        }
    }
    func expireOneShotAlarms(now: Date = Date()) {
        let activeID = data.activeNight?.alarm.id
        guard data.alarms.contains(where: { $0.enabled && $0.weekdays.isEmpty && $0.id != activeID && ($0.oneShotDate ?? .distantFuture) <= now }) else { return }
        change { value in
            for index in value.alarms.indices {
                let alarm = value.alarms[index]
                if alarm.weekdays.isEmpty && alarm.id != activeID && (alarm.oneShotDate ?? .distantFuture) <= now {
                    value.alarms[index].enabled = false
                }
            }
        }
    }
    func saveEntry(_ entry: NightEntry) {
        change { value in
            if let index = value.entries.firstIndex(where: { $0.id == entry.id }) {
                value.entries[index].notes = entry.notes
                value.entries[index].mood = entry.mood
            }
        }
    }
    func finishNight(at date: Date, interrupted: Bool = false) {
        guard let active = data.activeNight else { return }
        let entry = NightEntry(id: active.id, startedAt: active.startedAt, endedAt: date,
                               interrupted: interrupted, clips: active.clips)
        change {
            $0.entries.insert(entry, at: 0)
            $0.activeNight = nil
        }
    }
    func recoverInterruptedNight() {
        guard let active = data.activeNight else { return }
        finishNight(at: active.lastCheckpoint, interrupted: true)
    }
    func deleteEntry(_ entry: NightEntry) {
        change { $0.entries.removeAll { $0.id == entry.id } }
        guard !data.entries.contains(where: { $0.id == entry.id }) else { return }
        for clip in entry.clips { deleteClipFile(clip) }
    }
    func deleteClip(_ clip: SoundClip, entryID: UUID) {
        change { value in
            guard let index = value.entries.firstIndex(where: { $0.id == entryID }) else { return }
            value.entries[index].clips.removeAll { $0.id == clip.id }
        }
        if !data.entries.flatMap(\.clips).contains(where: { $0.id == clip.id }) { deleteClipFile(clip) }
    }
    func cleanExpiredClips(now: Date = Date()) {
        guard data.retentionDays > 0 else { return }
        let cutoff = now.addingTimeInterval(-Double(data.retentionDays) * 86400)
        let expired = data.entries.flatMap(\.clips).filter { $0.date < cutoff }
        guard !expired.isEmpty else { return }
        change { value in
            for index in value.entries.indices { value.entries[index].clips.removeAll { $0.date < cutoff } }
        }
        let kept = Set(data.entries.flatMap(\.clips).map(\.id))
        for clip in expired where !kept.contains(clip.id) { deleteClipFile(clip) }
    }
    private func deleteClipFile(_ clip: SoundClip) {
        guard clip.fileName == (clip.fileName as NSString).lastPathComponent else { return }
        let url = Self.clipsDirectory.appendingPathComponent(clip.fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do { try FileManager.default.removeItem(at: url) }
        catch { self.error = LF("An audio file could not be deleted. %@", String(describing: error.localizedDescription)) }
    }
}
