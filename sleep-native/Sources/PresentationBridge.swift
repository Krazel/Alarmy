import SwiftUI
import AVFoundation
import Combine

typealias Alarm = WakeAlarm
typealias AlarmStore = SleepStore
typealias NightSession = NightEngine

enum AppLanguage: String, Codable { case system, es, en }
struct JournalNote: Codable, Equatable { var notes = ""; var mood: WakeMood? }

extension WakeAlarm {
    var label: String { get { name } set { name = newValue } }
    var soundIds: [String] { get { sounds } set { sounds = newValue } }
    var randomSound: Bool { get { shuffle } set { shuffle = newValue } }
    var fadeInEnabled: Bool { get { fadeSeconds > 0 } set { fadeSeconds = newValue ? max(60, fadeSeconds) : 0 } }
    var fadeDuration: Double { get { Double(max(60, fadeSeconds)) } set { fadeSeconds = Int(newValue) } }
    var motionSnooze: Bool { get { shakeToSnooze } set { shakeToSnooze = newValue } }
    var lightWakeEnabled: Bool { get { lightWake ?? false } set { lightWake = newValue } }
    var lightWakeMinutes: Int { get { lightMinutes ?? 5 } set { lightMinutes = newValue } }
}

extension SleepStore {
    var sleepAlarm: WakeAlarm { data.nightlyAlarm! }
    var appearance: AppAppearance {
        get { data.appearance ?? .automatic }
        set { change { $0.appearance = newValue } }
    }
    var sleepTheme: SleepTheme { appearance.resolvedTheme }
    var language: AppLanguage {
        get { data.language ?? .system }
        set { change { $0.language = newValue }; L10n.language = data.language ?? .system }
    }
    var sleepRecordingEnabled: Bool {
        get { data.recordSounds }
        set { change { $0.recordSounds = newValue } }
    }
    var openJournalAfterAlarm: Bool {
        get { data.openJournal ?? true }
        set { change { $0.openJournal = newValue } }
    }
    var nightSoundRetention: NightSoundRetention {
        get { NightSoundRetention(rawValue: data.retentionDays) ?? .oneWeek }
        set { change { $0.retentionDays = newValue.rawValue }; cleanExpiredClips() }
    }
    var customSounds: [CustomAlarmSound] { data.customSounds ?? [] }
    var monetizationEnabled: Bool { true }
    var adsRemoved: Bool { false }
    func updateSleepAlarm(_ input: WakeAlarm) {
        var alarm = input
        alarm.oneShotDate = nil; alarm.weekdays = []; alarm.enabled = true
        alarm.sounds = alarm.sounds.filter { id in AlarmSound.all.contains { $0.id == id } || customSounds.contains { $0.soundId == id } }
        if alarm.sounds.isEmpty { alarm.sounds = AlarmSound.defaultIds }
        change { $0.nightlyAlarm = alarm }
    }
    static var customSoundsDirectory: URL { directory.appendingPathComponent("CustomSounds", isDirectory: true) }
    static func soundURL(_ id: String) -> URL? {
        if id.hasPrefix("custom:") {
            let name = String(id.dropFirst(7))
            guard name == (name as NSString).lastPathComponent else { return nil }
            let url = customSoundsDirectory.appendingPathComponent(name)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        if let sound = AlarmSound.all.first(where: { $0.id == id }) { return Bundle.main.url(forResource: sound.fileName, withExtension: "mp3") }
        return Bundle.main.url(forResource: id, withExtension: "wav")
    }
    func importCustomSound(from url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 50 * 1024 * 1024 else { error = L("La canción supera los 50 MB."); return }
            _ = try AVAudioPlayer(contentsOf: url)
            try FileManager.default.createDirectory(at: Self.customSoundsDirectory, withIntermediateDirectories: true)
            let fileName = UUID().uuidString + "." + url.pathExtension
            let destination = Self.customSoundsDirectory.appendingPathComponent(fileName)
            try FileManager.default.copyItem(at: url, to: destination)
            let sound = CustomAlarmSound(id: UUID().uuidString, name: url.deletingPathExtension().lastPathComponent, fileName: fileName)
            change { if $0.customSounds == nil { $0.customSounds = [] }; $0.customSounds?.append(sound) }
            if !customSounds.contains(sound) { try? FileManager.default.removeItem(at: destination) }
        } catch { self.error = LF("No se pudo importar la canción: %@", error.localizedDescription) }
    }
    func removeCustomSound(_ sound: CustomAlarmSound) {
        change { value in
            value.customSounds?.removeAll { $0.id == sound.id }
            value.nightlyAlarm?.sounds.removeAll { $0 == sound.soundId }
            if value.nightlyAlarm?.sounds.isEmpty == true { value.nightlyAlarm?.sounds = AlarmSound.defaultIds }
            for i in value.alarms.indices { value.alarms[i].sounds.removeAll { $0 == sound.soundId } }
        }
        guard !customSounds.contains(sound), let url = Self.soundURL(sound.soundId) else { return }
        do { try FileManager.default.removeItem(at: url) }
        catch { self.error = LF("No se pudo eliminar la canción: %@", error.localizedDescription) }
    }
    func deleteAllSoundClips() {
        let clips = data.entries.flatMap(\.clips)
        change { value in for i in value.entries.indices { value.entries[i].clips = [] } }
        let kept = Set(data.entries.flatMap(\.clips).map(\.id))
        for clip in clips where !kept.contains(clip.id) {
            guard clip.fileName == (clip.fileName as NSString).lastPathComponent else { continue }
            let url = Self.clipsDirectory.appendingPathComponent(clip.fileName)
            do { if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) } }
            catch { self.error = LF("No se pudo eliminar el audio: %@", error.localizedDescription) }
        }
    }
    func setClipKind(id: UUID, kind: SleepAudioEvent.Kind) {
        guard data.activeNight?.clips.contains(where: { $0.id == id }) == true || data.entries.contains(where: { $0.clips.contains(where: { $0.id == id }) }) else { return }
        change { value in
            if let i = value.activeNight?.clips.firstIndex(where: { $0.id == id }) { value.activeNight?.clips[i].kind = kind }
            for i in value.entries.indices {
                if let j = value.entries[i].clips.firstIndex(where: { $0.id == id }) { value.entries[i].clips[j].kind = kind }
            }
        }
    }
}

@MainActor
final class DreamStore: ObservableObject {
    let store: SleepStore
    @Published var healthMessage: String?
    @Published var samples: [SleepStageSample] = []
    private var subscription: AnyCancellable?
    let health = SleepHealthReader()
    init(store: SleepStore) {
        self.store = store
        subscription = store.$data.dropFirst().sink { [weak self] _ in self?.objectWillChange.send() }
    }
    func entry(for date: Date) -> DreamEntry {
        var result = DreamEntry(day: date)
        let nights = store.data.entries.filter { Calendar.current.isDate($0.endedAt, inSameDayAs: date) }
        result.sleepStartedAt = nights.map(\.startedAt).min(); result.sleepEndedAt = nights.map(\.endedAt).max()
        result.soundClips = nights.flatMap(\.clips).map { SleepSoundClip(id: $0.id, date: $0.date, kind: $0.kind ?? .unknown, filePath: SleepStore.clipsDirectory.appendingPathComponent($0.fileName).path) }
        result.audioClips = result.soundClips.count
        result.snoreEvents = result.soundClips.filter { $0.kind == .snore }.count
        result.strongBreathingEvents = result.soundClips.filter { $0.kind == .strongBreathing }.count
        result.talkingEvents = result.soundClips.filter { $0.kind == .talking }.count
        result.coughEvents = result.soundClips.filter { $0.kind == .cough }.count
        let note = store.data.journalNotes?[DreamEntry.key(for: date)]
        result.notes = note?.notes ?? nights.first?.notes ?? ""
        result.wakeMood = note != nil ? note?.mood : nights.first?.mood
        result.samples = healthSamples(for: date)
        return result
    }
    func upsert(_ entry: DreamEntry) {
        let note = JournalNote(notes: entry.notes, mood: entry.wakeMood)
        let key = entry.dayKey
        guard store.data.journalNotes?[key] != note else { return }
        store.change { if $0.journalNotes == nil { $0.journalNotes = [:] }; $0.journalNotes?[key] = note }
    }
    func pruneSoundClips(olderThanDays: Int?) { store.cleanExpiredClips() }
    func deleteAllSoundClips() { store.deleteAllSoundClips() }
    var soundStorageText: String {
        let size = store.data.entries.flatMap(\.clips).reduce(0) { sum, clip in
            sum + ((try? SleepStore.clipsDirectory.appendingPathComponent(clip.fileName).resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
    func connectHealth() async {
        do { try await health.authorize(); store.change { $0.healthConnected = true }; await refreshHealth() }
        catch { healthMessage = LF("No se pudo leer Salud: %@", error.localizedDescription) }
    }
    func refreshHealth() async {
        guard store.data.healthConnected == true else { return }
        do { samples = try await health.read(); healthMessage = samples.isEmpty ? L("No hay fases de sueño disponibles en Salud.") : L("Datos de Salud actualizados") }
        catch { healthMessage = LF("No se pudo leer Salud: %@", error.localizedDescription) }
    }
    func healthSamples(for day: Date) -> [SleepStageSample] {
        // Group nights by waking day, from noon the previous day until noon today.
        let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: day)!
        let start = Calendar.current.date(byAdding: .day, value: -1, to: noon)!
        return samples.filter { ($0.endDate ?? $0.date) > start && $0.date < noon }
    }
}
