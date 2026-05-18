import AVFoundation
import ActivityKit
import CoreMotion
import SwiftUI
import UIKit
import UserNotifications
import UniformTypeIdentifiers

@main
struct AlarmaApp: App {
    @StateObject private var store = AlarmStore()
    @StateObject private var session = NightSession()
    @StateObject private var dreams = DreamStore()
    @StateObject private var navigation = AppNavigation()

    init() {
        AlarmSoundPlayer.configurePlaybackSession()
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .environmentObject(session)
                .environmentObject(dreams)
                .environmentObject(navigation)
                .task {
                    await NotificationScheduler.shared.requestAuthorization()
                    await NotificationScheduler.shared.reschedule(alarms: store.notificationAlarms)
                }
        }
    }
}

struct Alarm: Identifiable, Codable, Equatable {
    var id = UUID()
    var label = "Manana"
    var hour = 7
    var minute = 30
    var weekdays: Set<Int> = []
    var soundIds: [String] = AlarmSound.defaultIds
    var randomSound = true
    var fadeInEnabled = true
    var fadeDuration = 180.0
    var motionSnooze = true
    var snoozeMinutes = 5
    var lightWakeEnabled = false
    var lightWakeMinutes = 5
    var enabled = true
    var lastRingKey: String?

    var timeText: String {
        String(format: "%02d:%02d", hour, minute)
    }

    var repeatText: String {
        if weekdays.isEmpty { return "Una vez" }
        if weekdays.count == 7 { return "Todos los días" }
        if weekdays == [2, 3, 4, 5, 6] { return "Laborables" }
        return Weekday.all.filter { weekdays.contains($0.calendarValue) }.map(\.short).joined(separator: " ")
    }
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}

struct Weekday: Identifiable, Hashable {
    let id: Int
    let short: String
    let calendarValue: Int

    static let all: [Weekday] = [
        .init(id: 0, short: "L", calendarValue: 2),
        .init(id: 1, short: "M", calendarValue: 3),
        .init(id: 2, short: "X", calendarValue: 4),
        .init(id: 3, short: "J", calendarValue: 5),
        .init(id: 4, short: "V", calendarValue: 6),
        .init(id: 5, short: "S", calendarValue: 7),
        .init(id: 6, short: "D", calendarValue: 1)
    ]
}

enum SleepTheme: String, CaseIterable, Identifiable {
    case sunset
    case night

    var id: String { rawValue }

    var title: String {
        "Alarma"
    }

    var activeTitle: String {
        switch self {
        case .sunset: return "Buenas noches"
        case .night: return "La noche ha comenzado"
        }
    }

    var primary: Color {
        switch self {
        case .sunset: return Color(red: 0.86, green: 0.34, blue: 0.20)
        case .night: return Color(red: 0.37, green: 0.83, blue: 0.88)
        }
    }

    var text: Color {
        switch self {
        case .sunset: return Color(red: 0.30, green: 0.17, blue: 0.10)
        case .night: return Color.white
        }
    }

    var secondaryText: Color {
        switch self {
        case .sunset: return Color(red: 0.49, green: 0.39, blue: 0.31)
        case .night: return Color(red: 0.63, green: 0.76, blue: 0.86)
        }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case automatic
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "Auto"
        case .light: return "Claro"
        case .dark: return "Oscuro"
        }
    }

    var resolvedTheme: SleepTheme {
        switch self {
        case .light:
            return .sunset
        case .dark:
            return .night
        case .automatic:
            let hour = Calendar.current.component(.hour, from: Date())
            return (hour >= 20 || hour < 8) ? .night : .sunset
        }
    }
}

struct AlarmSound: Identifiable, Hashable {
    let id: String
    let name: String
    let fileName: String
    let baseFrequency: Double
    let color: Color

    static let defaultIds = ["bosque-amanecer", "despertar-suave", "lo-fi-alarm"]

    static let all: [AlarmSound] = [
        .init(id: "funny-alarm", name: "Funny alarm", fileName: "funny-alarm", baseFrequency: 330, color: .orange),
        .init(id: "bosque-amanecer", name: "Bosque al amanecer", fileName: "bosque-al-amanecer", baseFrequency: 220, color: .green),
        .init(id: "despertar-suave", name: "Despertar suave", fileName: "despertar-suave", baseFrequency: 262, color: .mint),
        .init(id: "lo-fi-alarm", name: "Lo-fi alarm clock", fileName: "lo-fi-alarm-clock", baseFrequency: 196, color: .purple)
    ]
}

struct CustomAlarmSound: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    var fileName: String

    var soundId: String { "custom:\(fileName)" }
}

enum AppTab: Hashable {
    case alarm
    case journal
    case settings
}

@MainActor
final class AppNavigation: ObservableObject {
    @Published var selectedTab: AppTab = .alarm
    @Published var requestedJournalDate: Date?

    func openJournal(for date: Date = Date()) {
        requestedJournalDate = date
        selectedTab = .journal
    }
}

struct DreamEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var day: Date
    var notes = ""
    var score: Int?
    var awakeMinutes = 0
    var snoreEvents = 0
    var strongBreathingEvents = 0
    var talkingEvents = 0
    var audioClips = 0
    var sleepStartedAt: Date?
    var sleepEndedAt: Date?
    var lightSleepMinutes = 0
    var deepSleepMinutes = 0
    var samples: [SleepStageSample] = []

    var dayKey: String {
        Self.key(for: day)
    }

    var hasSleepData: Bool {
        sleepStartedAt != nil || sleepEndedAt != nil || !samples.isEmpty || audioClips > 0 || snoreEvents > 0 || strongBreathingEvents > 0 || talkingEvents > 0
    }

    static func key(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

struct SleepStageSample: Identifiable, Codable, Equatable {
    enum Stage: String, Codable, Equatable {
        case awake
        case light
        case deep

        var title: String {
            switch self {
            case .awake: return "Despierto"
            case .light: return "Ligero"
            case .deep: return "Profundo"
            }
        }
    }

    var id = UUID()
    var date: Date
    var stage: Stage
    var movement: Double
    var soundEvents: Int
}

@MainActor
final class DreamStore: ObservableObject {
    @Published var entries: [DreamEntry] = [] {
        didSet { save() }
    }

    private let key = "alarma.native.dreamEntries.v1"

    init() {
        load()
    }

    func entry(for date: Date) -> DreamEntry {
        let key = DreamEntry.key(for: date)
        return entries.first { $0.dayKey == key } ?? DreamEntry(day: date)
    }

    func upsert(_ entry: DreamEntry) {
        if let index = entries.firstIndex(where: { $0.dayKey == entry.dayKey }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
        entries.sort { $0.day > $1.day }
    }

    func addAudioEvent(day: Date, kind: SleepAudioEvent.Kind) {
        var entry = entry(for: day)
        entry.audioClips += 1
        switch kind {
        case .snore:
            entry.snoreEvents += 1
        case .strongBreathing:
            entry.strongBreathingEvents += 1
        case .talking:
            entry.talkingEvents += 1
        }
        let penalty = entry.snoreEvents * 2 + entry.strongBreathingEvents + entry.talkingEvents * 2 + entry.awakeMinutes / 8
        entry.score = max(35, min(95, 86 - penalty))
        upsert(entry)
    }

    func markSleepStarted(day: Date, at date: Date) {
        var entry = entry(for: day)
        entry.sleepStartedAt = entry.sleepStartedAt ?? date
        entry.sleepEndedAt = nil
        upsert(entry)
    }

    func markSleepEnded(day: Date, at date: Date) {
        var entry = entry(for: day)
        entry.sleepEndedAt = date
        recalculate(entry: &entry)
        upsert(entry)
    }

    func addSleepSample(day: Date, sample: SleepStageSample) {
        var entry = entry(for: day)
        entry.sleepStartedAt = entry.sleepStartedAt ?? sample.date
        entry.samples.append(sample)
        if entry.samples.count > 720 {
            entry.samples.removeFirst(entry.samples.count - 720)
        }
        recalculate(entry: &entry)
        upsert(entry)
    }

    private func recalculate(entry: inout DreamEntry) {
        entry.awakeMinutes = entry.samples.filter { $0.stage == .awake }.count
        entry.lightSleepMinutes = entry.samples.filter { $0.stage == .light }.count
        entry.deepSleepMinutes = entry.samples.filter { $0.stage == .deep }.count
        let penalty = entry.awakeMinutes * 2 + entry.snoreEvents * 2 + entry.strongBreathingEvents + entry.talkingEvents * 2
        let depthBonus = min(14, entry.deepSleepMinutes / 18)
        entry.score = max(35, min(96, 82 + depthBonus - penalty / 3))
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([DreamEntry].self, from: data) else {
            return
        }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

struct SleepAudioEvent {
    enum Kind {
        case snore
        case strongBreathing
        case talking
    }

    let day: Date
    let kind: Kind
    let fileURL: URL
}

final class SleepAudioAnalyzer {
    private var lastEventAt = Date.distantPast

    func rms(_ buffer: AVAudioPCMBuffer) -> Float {
        let count = Int(buffer.frameLength)
        guard count > 0, let channelData = buffer.floatChannelData else { return -120 }
        var sum: Float = 0
        let channels = Int(buffer.format.channelCount)
        for channelIndex in 0..<max(channels, 1) {
            let channel = channelData[channelIndex]
            for frameIndex in 0..<count {
                let sample = channel[frameIndex]
                sum += sample * sample
            }
        }
        let mean = sum / Float(count * max(channels, 1))
        return 20 * log10(max(sqrt(mean), 0.000_001))
    }

    func classify(rms: Float) -> SleepAudioEvent.Kind? {
        let now = Date()
        guard now.timeIntervalSince(lastEventAt) > 8 else { return nil }
        lastEventAt = now
        if rms > -24 { return .talking }
        if rms > -34 { return .snore }
        if rms > -46 { return .strongBreathing }
        return nil
    }
}

@MainActor
final class SleepAudioRecorder: ObservableObject {
    private let engine = AVAudioEngine()
    private let analyzer = SleepAudioAnalyzer()
    private var currentFile: AVAudioFile?
    private var currentURL: URL?
    private var writtenDuration: TimeInterval = 0
    private var didWrite = false
    private var tapInstalled = false
    private var day = Date()
    private var onEvent: ((SleepAudioEvent) -> Void)?
    private var saveOnlyWhenSound = true
    private let thresholdDB: Float = -50
    private let maxSegmentDuration: TimeInterval = 120

    func start(day: Date, saveOnlyWhenSound: Bool, onEvent: @escaping (SleepAudioEvent) -> Void) async {
        guard !engine.isRunning else { return }
        self.day = day
        self.saveOnlyWhenSound = saveOnlyWhenSound
        self.onEvent = onEvent
        do {
            try await requestMicrophonePermission()
            try configureAudioSession()
            try startNewSegment()
            try startEngine()
        } catch {
            stop()
        }
    }

    func stop() {
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        engine.stop()
        completeSegment()
    }

    private func requestMicrophonePermission() async throws {
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            return
        case .denied:
            throw RecorderError.microphoneDenied
        case .undetermined:
            let granted = await withCheckedContinuation { continuation in
                session.requestRecordPermission { continuation.resume(returning: $0) }
            }
            if !granted { throw RecorderError.microphoneDenied }
        @unknown default:
            throw RecorderError.microphoneDenied
        }
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker, .mixWithOthers])
        try session.setActive(true)
    }

    private func startEngine() throws {
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            Task { @MainActor in
                self?.handle(buffer)
            }
        }
        tapInstalled = true
        engine.prepare()
        try engine.start()
    }

    private func startNewSegment() throws {
        completeSegment()
        let url = try nextSegmentURL()
        let format = engine.inputNode.outputFormat(forBus: 0)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: Int(format.channelCount),
            AVEncoderBitRateKey: 64_000,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        currentFile = try AVAudioFile(forWriting: url, settings: settings)
        currentURL = url
        writtenDuration = 0
        didWrite = false
    }

    private func handle(_ buffer: AVAudioPCMBuffer) {
        let level = analyzer.rms(buffer)
        guard level >= thresholdDB || !saveOnlyWhenSound else { return }
        do {
            try currentFile?.write(from: buffer)
            didWrite = true
            writtenDuration += Double(buffer.frameLength) / buffer.format.sampleRate
            if level >= thresholdDB, let kind = analyzer.classify(rms: level), let url = currentURL {
                onEvent?(SleepAudioEvent(day: day, kind: kind, fileURL: url))
            }
            if writtenDuration >= maxSegmentDuration {
                try startNewSegment()
            }
        } catch {
            stop()
        }
    }

    private func completeSegment() {
        guard let url = currentURL else {
            currentFile = nil
            return
        }
        currentFile = nil
        if !didWrite || writtenDuration < 0.1 {
            try? FileManager.default.removeItem(at: url)
        }
        currentURL = nil
        writtenDuration = 0
        didWrite = false
    }

    private func nextSegmentURL() throws -> URL {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SleepAudio", isDirectory: true)
            .appendingPathComponent(DreamEntry.key(for: day), isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmmss"
        return root.appendingPathComponent("sleep-\(formatter.string(from: Date())).m4a")
    }
}

enum RecorderError: LocalizedError {
    case microphoneDenied

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            return "No hay permiso para usar el micrófono."
        }
    }
}

@MainActor
final class AlarmStore: ObservableObject {
    @Published var alarms: [Alarm] = [] {
        didSet { save() }
    }
    @Published var sleepAlarm = Alarm(label: "Noche", hour: 7, minute: 30, weekdays: [], soundIds: AlarmSound.defaultIds, randomSound: true, enabled: true) {
        didSet { saveSleepAlarm() }
    }
    @Published var appearance: AppAppearance = .automatic {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: appearanceKey) }
    }
    @Published var sleepRecordingEnabled = false {
        didSet { UserDefaults.standard.set(sleepRecordingEnabled, forKey: recordingEnabledKey) }
    }
    @Published var openJournalAfterAlarm = true {
        didSet { UserDefaults.standard.set(openJournalAfterAlarm, forKey: openJournalAfterAlarmKey) }
    }
    @Published var customSounds: [CustomAlarmSound] = [] {
        didSet { saveCustomSounds() }
    }

    private let key = "alarma.native.alarms.v1"
    private let sleepKey = "alarma.native.sleepAlarm.v1"
    private let appearanceKey = "alarma.native.appearance.v1"
    private let recordingEnabledKey = "alarma.native.sleepRecordingEnabled.v2"
    private let openJournalAfterAlarmKey = "alarma.native.openJournalAfterAlarm.v1"
    private let customSoundsKey = "alarma.native.customSounds.v1"
    private let alarmDefaultsMigrationKey = "alarma.native.alarmDefaults.v2"

    var notificationAlarms: [Alarm] {
        []
    }

    var sleepTheme: SleepTheme {
        appearance.resolvedTheme
    }

    init() {
        load()
        loadSleepAlarm()
        loadAppearance()
        loadRecordingSettings()
        loadJournalSettings()
        loadCustomSounds()
        migrateAlarmDefaultsIfNeeded()
        if alarms.isEmpty {
            alarms = [
                Alarm(),
                Alarm(label: "Fin de semana", hour: 9, minute: 0, weekdays: [1, 7], soundIds: ["despertar-suave"], randomSound: false, enabled: false)
            ]
        }
        normalizeStoredSounds()
    }

    func upsert(_ alarm: Alarm) {
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[index] = alarm
        } else {
            alarms.append(alarm)
        }
        Task { await NotificationScheduler.shared.reschedule(alarms: notificationAlarms) }
    }

    func delete(_ alarm: Alarm) {
        alarms.removeAll { $0.id == alarm.id }
        Task { await NotificationScheduler.shared.reschedule(alarms: notificationAlarms) }
    }

    func toggle(_ alarm: Alarm, enabled: Bool) {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[index].enabled = enabled
        Task { await NotificationScheduler.shared.reschedule(alarms: notificationAlarms) }
    }

    func updateSleepAlarm(_ alarm: Alarm) {
        sleepAlarm = alarm
        Task { await NotificationScheduler.shared.reschedule(alarms: notificationAlarms) }
    }

    func importCustomSound(from sourceURL: URL) {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess { sourceURL.stopAccessingSecurityScopedResource() }
        }

        let originalName = sourceURL.deletingPathExtension().lastPathComponent
        let fileExtension = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension
        let fileName = "\(UUID().uuidString).\(fileExtension)"

        do {
            let soundsDirectory = try customSoundsDirectory()
            let destinationURL = soundsDirectory.appendingPathComponent(fileName)
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            customSounds.append(CustomAlarmSound(id: UUID().uuidString, name: originalName, fileName: fileName))
        } catch {
            // Import errors are ignored in the UI for now; the picker remains open.
        }
    }

    func removeCustomSound(_ sound: CustomAlarmSound) {
        customSounds.removeAll { $0.id == sound.id }
        sleepAlarm.soundIds.removeAll { $0 == sound.soundId }
        alarms = alarms.map { alarm in
            var updated = alarm
            updated.soundIds.removeAll { $0 == sound.soundId }
            return updated
        }
        if let url = try? customSoundsDirectory().appendingPathComponent(sound.fileName) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Alarm].self, from: data) else {
            return
        }
        alarms = decoded
    }

    private func loadSleepAlarm() {
        guard let data = UserDefaults.standard.data(forKey: sleepKey),
              let decoded = try? JSONDecoder().decode(Alarm.self, from: data) else {
            return
        }
        sleepAlarm = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(alarms) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func saveSleepAlarm() {
        guard let data = try? JSONEncoder().encode(sleepAlarm) else { return }
        UserDefaults.standard.set(data, forKey: sleepKey)
    }

    private func loadAppearance() {
        guard let rawValue = UserDefaults.standard.string(forKey: appearanceKey),
              let appearance = AppAppearance(rawValue: rawValue) else {
            return
        }
        self.appearance = appearance
    }

    private func loadRecordingSettings() {
        if UserDefaults.standard.object(forKey: recordingEnabledKey) != nil {
            sleepRecordingEnabled = UserDefaults.standard.bool(forKey: recordingEnabledKey)
        }
    }

    private func loadJournalSettings() {
        if UserDefaults.standard.object(forKey: openJournalAfterAlarmKey) != nil {
            openJournalAfterAlarm = UserDefaults.standard.bool(forKey: openJournalAfterAlarmKey)
        }
    }

    private func migrateAlarmDefaultsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: alarmDefaultsMigrationKey) else { return }
        sleepAlarm.motionSnooze = true
        sleepAlarm.lightWakeEnabled = false
        sleepAlarm.lightWakeMinutes = 5
        sleepAlarm.fadeInEnabled = true
        sleepAlarm.fadeDuration = 180
        sleepAlarm.snoozeMinutes = 5
        sleepAlarm.soundIds = AlarmSound.defaultIds
        sleepAlarm.randomSound = sleepAlarm.soundIds.count > 1
        saveSleepAlarm()
        UserDefaults.standard.set(true, forKey: alarmDefaultsMigrationKey)
    }

    private func loadCustomSounds() {
        guard let data = UserDefaults.standard.data(forKey: customSoundsKey),
              let decoded = try? JSONDecoder().decode([CustomAlarmSound].self, from: data) else {
            return
        }
        customSounds = decoded
    }

    private func saveCustomSounds() {
        guard let data = try? JSONEncoder().encode(customSounds) else { return }
        UserDefaults.standard.set(data, forKey: customSoundsKey)
    }

    private func normalizeStoredSounds() {
        sleepAlarm.soundIds = normalizedSoundIds(sleepAlarm.soundIds)
        sleepAlarm.randomSound = sleepAlarm.soundIds.count > 1
        alarms = alarms.map { alarm in
            var updated = alarm
            updated.soundIds = normalizedSoundIds(alarm.soundIds)
            updated.randomSound = updated.soundIds.count > 1
            return updated
        }
    }

    private func normalizedSoundIds(_ ids: [String]) -> [String] {
        let builtinIds = Set(AlarmSound.defaultIds)
        let valid = ids.filter { builtinIds.contains($0) || $0.hasPrefix("custom:") }
        return valid.isEmpty ? AlarmSound.defaultIds : valid
    }

    private func customSoundsDirectory() throws -> URL {
        let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = baseURL.appendingPathComponent("CustomSounds", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

final class NotificationScheduler {
    static let shared = NotificationScheduler()
    private let ringingNotificationId = "alarm-ringing-visible"

    func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .timeSensitive])
    }

    func showRingingNotification(for alarm: Alarm) async {
        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: [ringingNotificationId])
        center.removePendingNotificationRequests(withIdentifiers: [ringingNotificationId])

        let content = UNMutableNotificationContent()
        content.title = alarm.label.isEmpty ? "Alarma" : alarm.label
        content.body = "La alarma está sonando."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: ringingNotificationId, content: content, trigger: trigger)
        try? await center.add(request)
    }

    func clearRingingNotification() {
        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: [ringingNotificationId])
        center.removePendingNotificationRequests(withIdentifiers: [ringingNotificationId])
    }

    func reschedule(alarms: [Alarm]) async {
        let center = UNUserNotificationCenter.current()
        let ids = alarms.flatMap { alarm in notificationIds(for: alarm) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        for alarm in alarms where alarm.enabled {
            await schedule(alarm)
        }
    }

    private func schedule(_ alarm: Alarm) async {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = alarm.label.isEmpty ? "Alarma" : alarm.label
        content.body = "Toca para abrir Alarma."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        if alarm.weekdays.isEmpty {
            var components = DateComponents()
            components.hour = alarm.hour
            components.minute = alarm.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: "alarm-\(alarm.id.uuidString)-once", content: content, trigger: trigger)
            try? await center.add(request)
            return
        }

        for day in alarm.weekdays {
            var components = DateComponents()
            components.weekday = day
            components.hour = alarm.hour
            components.minute = alarm.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "alarm-\(alarm.id.uuidString)-\(day)", content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    private func notificationIds(for alarm: Alarm) -> [String] {
        if alarm.weekdays.isEmpty { return ["alarm-\(alarm.id.uuidString)-once"] }
        return alarm.weekdays.map { "alarm-\(alarm.id.uuidString)-\($0)" }
    }
}

@MainActor
final class NightSession: ObservableObject {
    @Published var activeAlarm: Alarm?
    @Published var ringingAlarm: Alarm?
    @Published var now = Date()
    @Published var motionProgress = 0.0
    @Published private(set) var isSnoozing = false
    @Published private(set) var snoozedUntil: Date?
    @Published private(set) var lightLevel = 0.0

    private let motion = CMMotionManager()
    private let sound = AlarmSoundPlayer()
    private let sleepRecorder = SleepAudioRecorder()
    private var clockTimer: Timer?
    private var motionTimer: Timer?
    private var snoozeTimer: Timer?
    private var sleepAnalysisTimer: Timer?
    private var lightWakeStartedFor: UUID?
    private var sleepStartedAt: Date?
    private var sleepDay = Date()
    private var dreamStore: DreamStore?
    private var audioEventsSinceLastSample = 0
    private var originalBrightness: CGFloat?
    private var brightnessTimer: Timer?
    private var alarmMonitor: DispatchSourceTimer?
    private var firedRingKeys: Set<String> = []
    private var backgroundGuardActive = false
    private var liveActivityId: String?

    var isActive: Bool { activeAlarm != nil }

    func startAlarmMonitor(alarmsProvider: @escaping @MainActor () -> [Alarm]) {
        guard alarmMonitor == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "com.dmkr.alarma.monitor"))
        timer.schedule(deadline: .now(), repeating: 1)
        timer.setEventHandler { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.now = Date()
                self.checkDueAlarms(alarms: alarmsProvider())
            }
        }
        timer.resume()
        alarmMonitor = timer
    }

    func syncBackgroundGuard(alarms _: [Alarm]) {
        guard activeAlarm == nil, ringingAlarm == nil else { return }
        if backgroundGuardActive {
            sound.stop()
            backgroundGuardActive = false
        }
    }

    func start(alarm: Alarm) {
        isSnoozing = false
        snoozedUntil = nil
        snoozeTimer?.invalidate()
        lightLevel = 0
        lightWakeStartedFor = nil
        activeAlarm = alarm
        backgroundGuardActive = true
        UIApplication.shared.isIdleTimerDisabled = true
        sound.startKeepAlive()
        startClock()
        startMotionIfNeeded(alarm)
        endLockScreenActivity()
    }

    func stop() {
        endLockScreenActivity()
        NotificationScheduler.shared.clearRingingNotification()
        activeAlarm = nil
        ringingAlarm = nil
        isSnoozing = false
        snoozedUntil = nil
        lightLevel = 0
        lightWakeStartedFor = nil
        motionProgress = 0
        clockTimer?.invalidate()
        motionTimer?.invalidate()
        sleepAnalysisTimer?.invalidate()
        snoozeTimer?.invalidate()
        restoreBrightness()
        motion.stopDeviceMotionUpdates()
        sound.stop()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func ring(_ alarm: Alarm) {
        isSnoozing = false
        snoozedUntil = nil
        lightLevel = 0
        lightWakeStartedFor = nil
        snoozeTimer?.invalidate()
        ringingAlarm = alarm
        activeAlarm = nil
        backgroundGuardActive = false
        UIApplication.shared.isIdleTimerDisabled = true
        sleepAnalysisTimer?.invalidate()
        if alarm.lightWakeEnabled {
            startBrightnessRamp(minutes: alarm.lightWakeMinutes)
        }
        Task { await NotificationScheduler.shared.showRingingNotification(for: alarm) }
        sound.start(for: alarm)
        startMotionIfNeeded(alarm)
    }

    func snooze() {
        guard !isSnoozing, let alarm = ringingAlarm else { return }
        isSnoozing = true
        motionTimer?.invalidate()
        motion.stopDeviceMotionUpdates()
        motionProgress = 0
        endLockScreenActivity()
        NotificationScheduler.shared.clearRingingNotification()
        sound.stop()
        sound.startKeepAlive()
        restoreBrightness()
        var snoozed = alarm
        let date = Calendar.current.date(byAdding: .minute, value: alarm.snoozeMinutes, to: Date()) ?? Date()
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        snoozed.hour = components.hour ?? alarm.hour
        snoozed.minute = components.minute ?? alarm.minute
        snoozed.weekdays = []
        snoozed.enabled = true
        ringingAlarm = snoozed
        snoozedUntil = date
        snoozeTimer?.invalidate()
        snoozeTimer = Timer.scheduledTimer(withTimeInterval: max(1, date.timeIntervalSinceNow), repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.resumeSnoozedAlarm()
            }
        }
    }

    private func resumeSnoozedAlarm() {
        guard isSnoozing, let alarm = ringingAlarm else { return }
        isSnoozing = false
        snoozedUntil = nil
        lightLevel = 0
        motionProgress = 0
        if alarm.lightWakeEnabled {
            startBrightnessRamp(minutes: alarm.lightWakeMinutes)
        }
        Task { await NotificationScheduler.shared.showRingingNotification(for: alarm) }
        sound.start(for: alarm)
        startMotionIfNeeded(alarm)
    }

    private func startOrUpdateLockScreenActivity(for alarm: Alarm, isRinging: Bool) {
        guard #available(iOS 16.1, *), ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = AlarmActivityAttributes.ContentState(
            label: alarm.label.isEmpty ? "Alarma" : alarm.label,
            timeText: alarm.timeText,
            statusText: isRinging ? "Alarma sonando" : "Noche activa",
            isRinging: isRinging
        )

        if let activity = Activity<AlarmActivityAttributes>.activities.first(where: { $0.id == liveActivityId }) {
            Task {
                await activity.update(using: state)
            }
            return
        }

        let attributes = AlarmActivityAttributes(alarmId: alarm.id.uuidString)
        do {
            let activity = try Activity.request(
                attributes: attributes,
                contentState: state,
                pushType: nil
            )
            liveActivityId = activity.id
        } catch {
            liveActivityId = nil
        }
    }

    private func endLockScreenActivity() {
        guard #available(iOS 16.1, *) else { return }
        let activities = Activity<AlarmActivityAttributes>.activities.filter { activity in
            liveActivityId == nil || activity.id == liveActivityId
        }
        liveActivityId = nil
        for activity in activities {
            Task {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }

    private func startClock() {
        clockTimer?.invalidate()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.now = Date() }
        }
    }

    private func startMotionIfNeeded(_ alarm: Alarm, force: Bool = false) {
        motionTimer?.invalidate()
        motion.stopDeviceMotionUpdates()
        motionProgress = 0
        guard (alarm.motionSnooze || force), motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 0.12
        motion.startDeviceMotionUpdates()
        motionTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.consumeMotion() }
        }
    }

    private func consumeMotion() {
        guard let data = motion.deviceMotion else { return }
        let a = data.userAcceleration
        let magnitude = sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
        motionProgress = max(0, min(1, motionProgress * 0.88 + magnitude * 0.24))
    }

    private func startSleepAnalysisIfNeeded() {
        guard dreamStore != nil else { return }
        sleepAnalysisTimer?.invalidate()
        sleepAnalysisTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordSleepSample()
            }
        }
    }

    private func recordSleepSample() {
        guard let dreamStore, activeAlarm != nil else { return }
        let movement = motionProgress
        let sounds = audioEventsSinceLastSample
        audioEventsSinceLastSample = 0
        let stage: SleepStageSample.Stage
        if movement > 0.42 || sounds >= 3 {
            stage = .awake
        } else if movement > 0.16 || sounds > 0 {
            stage = .light
        } else {
            stage = .deep
        }
        let sample = SleepStageSample(date: Date(), stage: stage, movement: movement, soundEvents: sounds)
        dreamStore.addSleepSample(day: sleepDay, sample: sample)
        motionProgress = max(0, motionProgress * 0.45)
    }

    private func checkDueAlarms(alarms: [Alarm]) {
        guard ringingAlarm == nil else { return }
        syncBackgroundGuard(alarms: alarms)

        let date = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .weekday], from: date)
        let minuteKey = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short)

        if let active = activeAlarm,
           active.hour == components.hour,
           active.minute == components.minute,
           active.weekdays.isEmpty || active.weekdays.contains(components.weekday ?? 0) {
            let key = "\(active.id.uuidString)-\(minuteKey)"
            guard !firedRingKeys.contains(key) else { return }
            firedRingKeys.insert(key)
            ring(active)
            return
        }

        for alarm in alarms where alarm.enabled {
            guard alarm.hour == components.hour, alarm.minute == components.minute else { continue }
            guard alarm.weekdays.isEmpty || alarm.weekdays.contains(components.weekday ?? 0) else { continue }
            let key = "\(alarm.id.uuidString)-\(minuteKey)"
            guard !firedRingKeys.contains(key) else { continue }
            firedRingKeys.insert(key)
            ring(alarm)
            break
        }
    }

    private func restoreBrightness() {
        brightnessTimer?.invalidate()
        brightnessTimer = nil
        guard let brightness = originalBrightness else { return }
        UIScreen.main.brightness = brightness
        originalBrightness = nil
    }

    private func startBrightnessRamp(minutes: Int) {
        brightnessTimer?.invalidate()
        let base = originalBrightness ?? UIScreen.main.brightness
        originalBrightness = base
        let duration = max(1, TimeInterval(minutes * 60))
        let started = Date()
        brightnessTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            let progress = min(1, Date().timeIntervalSince(started) / duration)
            UIScreen.main.brightness = min(1, max(base, base + (1 - base) * progress))
            if progress >= 1 { timer.invalidate() }
        }
        brightnessTimer?.fire()
    }
}

final class AlarmSoundPlayer {
    private var audioPlayer: AVAudioPlayer?
    private var rampTimer: Timer?

    static func preview(sound: AlarmSound) {
        let player = AlarmSoundPlayer()
        player.startPreview(sound: sound)
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            player.stop()
        }
    }

    static func preview(customSound: CustomAlarmSound) {
        let player = AlarmSoundPlayer()
        player.startPreview(customSound: customSound)
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            player.stop()
        }
    }

    static func configurePlaybackSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
    }

    func startKeepAlive() {
        stop()
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        if let url = generatedToneURL(name: "keepalive", frequency: 110, amplitude: 0.0008, duration: 1.0) {
            playAudioFile(at: url, volume: 0.02, loop: true)
        }
    }

    func start(for alarm: Alarm) {
        stop()
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
        try? session.setActive(true)

        let fallbackSoundId = AlarmSound.defaultIds[0]
        let soundId = alarm.soundIds.count > 1 ? (alarm.soundIds.randomElement() ?? fallbackSoundId) : (alarm.soundIds.first ?? fallbackSoundId)
        if soundId.hasPrefix("custom:") {
            playCustomSound(fileName: String(soundId.dropFirst("custom:".count)), alarm: alarm)
            return
        }
        let sound = AlarmSound.all.first { $0.id == soundId } ?? AlarmSound.all[0]
        playBundledSound(sound, alarm: alarm)
    }

    private func startPreview(sound: AlarmSound) {
        stop()
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        playBundledFile(named: sound.fileName, volume: 0.55, loop: false)
    }

    private func startPreview(customSound: CustomAlarmSound) {
        stop()
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        playCustomFile(named: customSound.fileName, volume: 0.55, loop: false)
    }

    private func playBundledSound(_ sound: AlarmSound, alarm: Alarm) {
        let initialVolume: Float = alarm.fadeInEnabled ? 0.04 : 0.95
        if !playBundledFile(named: sound.fileName, volume: initialVolume, loop: true),
           let url = generatedToneURL(name: "alarm-\(sound.id)", frequency: sound.baseFrequency, amplitude: 0.82, duration: 2.0) {
            playAudioFile(at: url, volume: initialVolume, loop: true)
        }
        if alarm.fadeInEnabled {
            let started = Date()
            rampTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
                guard let self else { return }
                let elapsed = Date().timeIntervalSince(started)
                let progress = min(1, elapsed / max(1, alarm.fadeDuration))
                self.audioPlayer?.volume = Float(0.04 + progress * 0.91)
                if progress >= 1 { timer.invalidate() }
            }
        }
    }

    private func playCustomSound(fileName: String, alarm: Alarm) {
        let initialVolume: Float = alarm.fadeInEnabled ? 0.04 : 0.95
        playCustomFile(named: fileName, volume: initialVolume, loop: true)
        guard alarm.fadeInEnabled else { return }
        let started = Date()
        rampTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else { return }
            let elapsed = Date().timeIntervalSince(started)
            let progress = min(1, elapsed / max(1, alarm.fadeDuration))
            self.audioPlayer?.volume = Float(0.04 + progress * 0.91)
            if progress >= 1 { timer.invalidate() }
        }
    }

    @discardableResult
    private func playBundledFile(named fileName: String, volume: Float, loop: Bool) -> Bool {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "mp3") else { return false }
        return playAudioFile(at: url, volume: volume, loop: loop)
    }

    @discardableResult
    private func playCustomFile(named fileName: String, volume: Float, loop: Bool) -> Bool {
        guard let directory = try? customSoundsDirectory() else { return false }
        let url = directory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        return playAudioFile(at: url, volume: volume, loop: loop)
    }

    @discardableResult
    private func playAudioFile(at url: URL, volume: Float, loop: Bool) -> Bool {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = loop ? -1 : 0
            audioPlayer?.volume = volume
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            return true
        } catch {
            audioPlayer = nil
            return false
        }
    }

    private func customSoundsDirectory() throws -> URL {
        let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return baseURL.appendingPathComponent("CustomSounds", isDirectory: true)
    }

    func stop() {
        rampTimer?.invalidate()
        rampTimer = nil
        audioPlayer?.stop()
        audioPlayer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func generatedToneURL(name: String, frequency: Double, amplitude: Double, duration: Double) -> URL? {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AlarmaGeneratedAudio", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(name).wav")
        if FileManager.default.fileExists(atPath: url.path) { return url }

        let sampleRate = 44_100
        let channelCount = 1
        let bitsPerSample = 16
        let sampleCount = Int(Double(sampleRate) * duration)
        let byteRate = sampleRate * channelCount * bitsPerSample / 8
        let blockAlign = channelCount * bitsPerSample / 8
        let dataSize = sampleCount * blockAlign

        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        data.append(UInt32(36 + dataSize).littleEndianData)
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        data.append(UInt32(16).littleEndianData)
        data.append(UInt16(1).littleEndianData)
        data.append(UInt16(channelCount).littleEndianData)
        data.append(UInt32(sampleRate).littleEndianData)
        data.append(UInt32(byteRate).littleEndianData)
        data.append(UInt16(blockAlign).littleEndianData)
        data.append(UInt16(bitsPerSample).littleEndianData)
        data.append(contentsOf: Array("data".utf8))
        data.append(UInt32(dataSize).littleEndianData)

        for sample in 0..<sampleCount {
            let phase = 2.0 * Double.pi * frequency * Double(sample) / Double(sampleRate)
            let envelope = 0.55 + 0.45 * sin(phase * 0.012)
            let value = Int16(max(-1, min(1, sin(phase) * envelope * amplitude)) * Double(Int16.max))
            data.append(value.littleEndianData)
        }

        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

private extension FixedWidthInteger {
    var littleEndianData: Data {
        var value = littleEndian
        return Data(bytes: &value, count: MemoryLayout<Self>.size)
    }
}

struct RootTabView: View {
    @EnvironmentObject private var navigation: AppNavigation

    var body: some View {
        TabView(selection: $navigation.selectedTab) {
            ContentView()
                .tabItem {
                    Label("Alarma", systemImage: "alarm.fill")
                }
                .tag(AppTab.alarm)

            DreamJournalView()
                .tabItem {
                    Label("Diario", systemImage: "book.closed.fill")
                }
                .tag(AppTab.journal)

            SettingsView()
                .tabItem {
                    Label("Ajustes", systemImage: "gearshape.fill")
                }
                .tag(AppTab.settings)
        }
        .tint(Color(red: 0.86, green: 0.34, blue: 0.20))
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: AlarmStore
    @EnvironmentObject private var session: NightSession
    @EnvironmentObject private var dreams: DreamStore
    @EnvironmentObject private var navigation: AppNavigation
    @Environment(\.scenePhase) private var scenePhase
    @State private var editingSleepAlarm = false

    var body: some View {
        ZStack {
            SleepBackdrop(theme: store.sleepTheme)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.top, 56)

                AlarmHeroCard(
                    alarm: store.sleepAlarm,
                    theme: store.sleepTheme,
                    onAdjust: adjustSleepAlarm,
                    onEdit: { editingSleepAlarm = true }
                )
                .padding(.top, 30)

                Spacer()

                Button {
                    session.start(alarm: store.sleepAlarm)
                } label: {
                    Label("Empezar la noche", systemImage: "moon.stars.fill")
                        .font(.title3.weight(.black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 66)
                        .background(
                            LinearGradient(colors: [store.sleepTheme.primary.opacity(0.92), store.sleepTheme.primary.opacity(0.74)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .shadow(color: store.sleepTheme.primary.opacity(0.30), radius: 18, x: 0, y: 10)
                }
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $editingSleepAlarm) {
            EditAlarmView(
                alarm: store.sleepAlarm,
                theme: store.sleepTheme,
                onSave: { updated in store.updateSleepAlarm(updated) },
                onDelete: nil
            )
        }
        .fullScreenCover(isPresented: Binding(get: { session.isActive || session.ringingAlarm != nil }, set: { if !$0 { session.stop() } })) {
            if let alarm = session.ringingAlarm {
                RingView(alarm: alarm, theme: store.sleepTheme, onFinish: finishAlarm)
            } else if let alarm = session.activeAlarm {
                NightActiveView(alarm: alarm, theme: store.sleepTheme)
            }
        }
        .onAppear {
            session.startAlarmMonitor { [] }
            session.syncBackgroundGuard(alarms: [])
        }
        .onChange(of: store.sleepAlarm) { _ in
            session.syncBackgroundGuard(alarms: [])
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background || phase == .inactive {
                session.syncBackgroundGuard(alarms: [])
            }
        }
        .preferredColorScheme(store.sleepTheme == .night ? .dark : .light)
        .statusBarHidden(false)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(store.sleepTheme.title)
                    .font(.system(size: 46, weight: .bold, design: .serif))
                    .foregroundStyle(store.sleepTheme.text)
                    .minimumScaleFactor(0.75)
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    store.appearance = store.sleepTheme == .sunset ? .dark : .light
                }
            } label: {
                Image(systemName: store.sleepTheme == .sunset ? "moon.stars.fill" : "sun.max.fill")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 46, height: 46)
                    .background(store.sleepTheme == .sunset ? Color.white.opacity(0.72) : Color.white.opacity(0.10))
                    .foregroundStyle(store.sleepTheme.primary)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(store.sleepTheme == .sunset ? Color.black.opacity(0.05) : Color.white.opacity(0.14), lineWidth: 1))
                    .shadow(color: .black.opacity(store.sleepTheme == .sunset ? 0.10 : 0.28), radius: 12, x: 0, y: 8)
            }
            .accessibilityLabel(store.sleepTheme == .sunset ? "Activar modo noche" : "Activar modo claro")
        }
    }

    private func adjustSleepAlarm(component: TimeComponent, amount: Int) {
        var alarm = store.sleepAlarm
        switch component {
        case .hour:
            alarm.hour = (alarm.hour + amount + 24) % 24
        case .minute:
            alarm.minute = (alarm.minute + amount + 60) % 60
        }
        store.updateSleepAlarm(alarm)
    }

    private func finishAlarm() {
        session.stop()
        if store.openJournalAfterAlarm {
            navigation.openJournal(for: Date())
        }
    }

}

enum TimeComponent {
    case hour
    case minute
}

struct AlarmHeroCard: View {
    let alarm: Alarm
    let theme: SleepTheme
    let onAdjust: (TimeComponent, Int) -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(theme == .sunset ? Color(red: 0.78, green: 0.36, blue: 0.17).opacity(0.18) : theme.primary.opacity(0.16))
                        .frame(width: 52, height: 52)
                    Image(systemName: theme == .sunset ? "moon.stars.fill" : "moon.fill")
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(theme.primary)
                }
                Spacer()
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 18, weight: .black))
                        .frame(width: 46, height: 46)
                        .background(theme == .sunset ? Color.white.opacity(0.66) : Color.white.opacity(0.08))
                        .foregroundStyle(theme.primary)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(theme == .sunset ? Color.black.opacity(0.05) : theme.primary.opacity(0.22), lineWidth: 1))
                }
            }

            VStack(spacing: 8) {
                SwipeTimeText(timeText: alarm.timeText, textColor: theme.text, alignment: .center, onAdjust: onAdjust)
                    .frame(height: 86)
                Text("Descansa")
                    .font(.headline.weight(.black))
                    .foregroundStyle(theme.primary)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(theme == .sunset ? Color.white.opacity(0.50) : Color(red: 0.02, green: 0.13, blue: 0.20).opacity(0.68))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(theme == .sunset ? Color(red: 0.94, green: 0.70, blue: 0.45).opacity(0.42) : theme.primary.opacity(0.70), lineWidth: theme == .sunset ? 1 : 1.4)
                )
                .shadow(color: theme == .sunset ? Color(red: 0.55, green: 0.29, blue: 0.10).opacity(0.13) : theme.primary.opacity(0.22), radius: 18, x: 0, y: 10)
        )
    }
}

struct SwipeTimeText: View {
    let timeText: String
    var textColor = Color(red: 0.31, green: 0.15, blue: 0.08)
    var alignment: Alignment = .leading
    let onAdjust: (TimeComponent, Int) -> Void
    @State private var lastStep = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: alignment) {
                Text(timeText)
                    .font(.system(size: 78, weight: .bold, design: .serif))
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(textColor)
                    .allowsHitTesting(false)

                HStack(spacing: 0) {
                    Color.clear
                        .contentShape(Rectangle())
                        .highPriorityGesture(timeDragGesture(for: .hour))
                    Color.clear
                        .contentShape(Rectangle())
                        .highPriorityGesture(timeDragGesture(for: .minute))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: alignment)
        }
        .frame(height: 90)
        .frame(maxWidth: .infinity)
    }

    private func timeDragGesture(for component: TimeComponent) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                let step = Int((-value.translation.height / 18).rounded(.towardZero))
                guard step != lastStep else { return }
                let delta = step - lastStep
                lastStep = step
                onAdjust(component, delta)
            }
            .onEnded { _ in
                lastStep = 0
            }
    }
}

struct SleepBackdrop: View {
    let theme: SleepTheme

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let uiImage = backgroundUIImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    fallbackBackground
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }

                LinearGradient(
                    colors: theme == .sunset
                        ? [Color.white.opacity(0.42), Color.white.opacity(0.10), Color(red: 0.47, green: 0.20, blue: 0.10).opacity(0.22)]
                        : [Color.black.opacity(0.28), Color.black.opacity(0.08), Color.black.opacity(0.54)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .ignoresSafeArea()
        }
    }

    private var backgroundUIImage: UIImage? {
        let assetName = theme == .sunset ? "SunsetBackground" : "NightBackground"
        let fileName = theme == .sunset ? "sunset-background" : "night-background"
        if let uiImage = UIImage(named: assetName) {
            return uiImage
        }
        if let url = Bundle.main.url(forResource: fileName, withExtension: "png"),
           let uiImage = UIImage(contentsOfFile: url.path) {
            return uiImage
        }
        if let url = Bundle.main.url(forResource: fileName, withExtension: "jpg"),
           let uiImage = UIImage(contentsOfFile: url.path) {
            return uiImage
        }
        return nil
    }

    @ViewBuilder
    private var fallbackBackground: some View {
        if theme == .sunset {
            SunsetScene()
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.03, green: 0.08, blue: 0.16),
                        Color(red: 0.02, green: 0.17, blue: 0.28),
                        Color(red: 0.01, green: 0.03, blue: 0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Stars()
                    .fill(Color.white.opacity(0.76))
            }
        }
    }
}

struct Stars: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points: [(CGFloat, CGFloat, CGFloat)] = [
            (0.16, 0.10, 2), (0.28, 0.18, 1.4), (0.48, 0.12, 1.8), (0.68, 0.20, 1.2), (0.84, 0.11, 1.6),
            (0.20, 0.32, 1.2), (0.37, 0.28, 1.6), (0.58, 0.34, 1.3), (0.76, 0.31, 1.7), (0.90, 0.39, 1.1)
        ]
        for point in points {
            path.addEllipse(in: CGRect(x: rect.width * point.0, y: rect.height * point.1, width: point.2, height: point.2))
        }
        return path
    }
}

struct SunsetScene: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.86, blue: 0.64),
                        Color(red: 0.97, green: 0.55, blue: 0.31),
                        Color(red: 0.45, green: 0.20, blue: 0.12)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Circle()
                    .fill(Color(red: 1.0, green: 0.91, blue: 0.55).opacity(0.95))
                    .frame(width: size.width * 0.28, height: size.width * 0.28)
                    .position(x: size.width * 0.52, y: size.height * 0.54)

                mountain(color: Color(red: 0.76, green: 0.35, blue: 0.19).opacity(0.54), height: 0.64)
                mountain(color: Color(red: 0.45, green: 0.19, blue: 0.12).opacity(0.72), height: 0.78)

                cloud(x: size.width * 0.17, y: size.height * 0.24, scale: 0.82)
                cloud(x: size.width * 0.87, y: size.height * 0.18, scale: 0.56)
                birds
                    .stroke(Color(red: 0.40, green: 0.19, blue: 0.12).opacity(0.55), lineWidth: 1.5)
                    .frame(width: size.width * 0.24, height: size.height * 0.12)
                    .position(x: size.width * 0.76, y: size.height * 0.23)
            }
        }
    }

    private func mountain(color: Color, height: CGFloat) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            Path { path in
                path.move(to: CGPoint(x: 0, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: size.height * height))
                path.addLine(to: CGPoint(x: size.width * 0.22, y: size.height * (height - 0.16)))
                path.addLine(to: CGPoint(x: size.width * 0.44, y: size.height * (height - 0.05)))
                path.addLine(to: CGPoint(x: size.width * 0.66, y: size.height * (height - 0.22)))
                path.addLine(to: CGPoint(x: size.width, y: size.height * (height - 0.08)))
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.closeSubpath()
            }
            .fill(color)
        }
    }

    private func cloud(x: CGFloat, y: CGFloat, scale: CGFloat) -> some View {
        ZStack {
            Capsule().fill(Color.white.opacity(0.22)).frame(width: 82 * scale, height: 18 * scale)
            Circle().fill(Color.white.opacity(0.18)).frame(width: 36 * scale, height: 36 * scale).offset(x: -22 * scale, y: -7 * scale)
            Circle().fill(Color.white.opacity(0.18)).frame(width: 42 * scale, height: 42 * scale).offset(x: 6 * scale, y: -10 * scale)
        }
        .position(x: x, y: y)
    }

    private var birds: Path {
        Path { path in
            for index in 0..<3 {
                let x = CGFloat(index) * 28
                let y = CGFloat(index % 2) * 12
                path.move(to: CGPoint(x: x, y: y + 10))
                path.addQuadCurve(to: CGPoint(x: x + 14, y: y + 10), control: CGPoint(x: x + 7, y: y))
                path.addQuadCurve(to: CGPoint(x: x + 28, y: y + 10), control: CGPoint(x: x + 21, y: y))
            }
        }
    }
}

struct AlarmRow: View {
    let alarm: Alarm
    let onTap: () -> Void
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(alarm.timeText)
                        .font(.system(size: 44, weight: .bold, design: .serif))
                    Text(alarm.label)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.orange)
                    Text("\(alarm.repeatText) - aviso iOS, sin audio todo el día")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Toggle("", isOn: Binding(get: { alarm.enabled }, set: onToggle))
                .labelsHidden()
        }
        .padding(18)
        .background(Color.white.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct EditAlarmView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AlarmStore
    @State var alarm: Alarm
    @State private var choosingSounds = false
    let theme: SleepTheme
    let onSave: (Alarm) -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        ZStack {
            SleepBackdrop(theme: theme)
                .ignoresSafeArea()
                .overlay(theme == .sunset ? Color.white.opacity(0.45) : Color.black.opacity(0.14))

            VStack(spacing: 18) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .black))
                            .frame(width: 44, height: 44)
                            .background(theme == .sunset ? Color.white.opacity(0.58) : Color.white.opacity(0.08))
                            .foregroundStyle(theme.text)
                            .clipShape(Circle())
                    }

                    Spacer()
                    Text("Editar alarma")
                        .font(.title3.weight(.black))
                        .foregroundStyle(theme.text)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        TimeEditPanel(alarm: $alarm, theme: theme)

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Musicas posibles")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(theme.text)
                                Spacer()
                                Button("Escoger") {
                                    choosingSounds = true
                                }
                                .font(.headline.weight(.black))
                                .foregroundStyle(theme.primary)
                            }

                            Text(soundSummary)
                                .font(.subheadline.weight(.black))
                                .foregroundStyle(theme.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(panelFill)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        FadeDurationControl(duration: $alarm.fadeDuration, theme: theme)

                        Toggle(isOn: $alarm.motionSnooze) {
                            Label("Mover para posponer", systemImage: "iphone.radiowaves.left.and.right")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(theme.text)
                        }
                        .tint(theme.primary)
                        .padding(16)
                        .background(panelFill)
                        .clipShape(RoundedRectangle(cornerRadius: 18))

                        LightWakeControl(enabled: $alarm.lightWakeEnabled, minutes: $alarm.lightWakeMinutes, theme: theme)

                        SnoozePresetSelector(minutes: $alarm.snoozeMinutes, theme: theme)
                    }
                    .padding(.bottom, 4)
                }

                Button {
                    alarm.randomSound = alarm.soundIds.count > 1
                    alarm.weekdays = []
                    onSave(alarm)
                    dismiss()
                } label: {
                    Text("Guardar")
                        .font(.title3.weight(.black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            LinearGradient(colors: [theme.primary.opacity(0.95), theme.primary.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 58)
            .padding(.bottom, 28)
        }
        .sheet(isPresented: $choosingSounds) {
            SoundPickerSheet(alarm: $alarm, theme: theme)
        }
        .preferredColorScheme(theme == .night ? .dark : .light)
    }

    private var panelFill: Color {
        theme == .sunset ? Color.white.opacity(0.52) : Color.white.opacity(0.07)
    }

    private var soundSummary: String {
        let builtin = AlarmSound.all.filter { alarm.soundIds.contains($0.id) }.map(\.name)
        let custom = store.customSounds.filter { alarm.soundIds.contains($0.soundId) }.map(\.name)
        let selected = builtin + custom
        if selected.isEmpty { return "Ninguna seleccionada" }
        if selected.count == 1 { return selected[0] }
        return "\(selected.count) seleccionadas"
    }
}

struct TimeEditPanel: View {
    @Binding var alarm: Alarm
    let theme: SleepTheme

    var body: some View {
        DatePicker("Hora", selection: timeBinding, displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .frame(height: 164)
            .clipped()
            .colorScheme(theme == .sunset ? .light : .dark)
            .tint(theme.primary)
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(theme == .sunset ? Color.white.opacity(0.54) : Color.white.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(theme == .sunset ? Color.white.opacity(0.20) : Color.white.opacity(0.16), lineWidth: 1))
        )
        .foregroundStyle(.white)
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                components.hour = alarm.hour
                components.minute = alarm.minute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                alarm.hour = components.hour ?? alarm.hour
                alarm.minute = components.minute ?? alarm.minute
            }
        )
    }
}

struct SnoozePresetSelector: View {
    @Binding var minutes: Int
    let theme: SleepTheme
    private let options = [1, 3, 5, 10]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Posponer", systemImage: "moon.zzz.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(theme.text)

            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    Button {
                        minutes = option
                    } label: {
                        Text("\(option) min")
                            .font(.subheadline.weight(.black))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(minutes == option ? theme.primary.opacity(0.22) : panelFill)
                            .foregroundStyle(minutes == option ? theme.primary : theme.text)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(minutes == option ? theme.primary.opacity(0.58) : theme.secondaryText.opacity(0.16), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(panelFill)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var panelFill: Color {
        theme == .sunset ? Color.white.opacity(0.52) : Color.white.opacity(0.07)
    }
}

struct LightWakeControl: View {
    @Binding var enabled: Bool
    @Binding var minutes: Int
    let theme: SleepTheme
    private let options = [3, 5, 10, 15]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $enabled) {
                Label("Luz progresiva", systemImage: "sun.max.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(theme.text)
            }
            .tint(theme.primary)

            if enabled {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            minutes = option
                        } label: {
                            Text("\(option) min")
                                .font(.subheadline.weight(.black))
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(minutes == option ? theme.primary.opacity(0.22) : panelFill)
                                .foregroundStyle(minutes == option ? theme.primary : theme.text)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(minutes == option ? theme.primary.opacity(0.58) : theme.secondaryText.opacity(0.16), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(panelFill)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var panelFill: Color {
        theme == .sunset ? Color.white.opacity(0.52) : Color.white.opacity(0.07)
    }
}

struct SoundPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AlarmStore
    @Binding var alarm: Alarm
    let theme: SleepTheme
    @State private var importingSound = false

    var body: some View {
        ZStack {
            SleepBackdrop(theme: theme)
                .ignoresSafeArea()
                .overlay(theme == .sunset ? Color.white.opacity(0.48) : Color.black.opacity(0.24))

            VStack(spacing: 18) {
                HStack {
                    Text("Musicas posibles")
                        .font(.title3.weight(.black))
                        .foregroundStyle(theme.text)
                    Spacer()
                    Button {
                        importingSound = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline.weight(.black))
                            .frame(width: 38, height: 38)
                            .background(theme == .sunset ? Color.white.opacity(0.52) : Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .foregroundStyle(theme.primary)
                    Button("Hecho") {
                        dismiss()
                    }
                    .font(.headline.weight(.black))
                    .foregroundStyle(theme.primary)
                }

                ScrollView(showsIndicators: false) {
                    SoundSelector(alarm: $alarm, theme: theme, showAll: true)
                }

                Button("Deseleccionar") {
                    alarm.soundIds.removeAll()
                    alarm.randomSound = false
                }
                .font(.headline.weight(.black))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(theme.primary)
                .background(theme == .sunset ? Color.white.opacity(0.52) : Color.white.opacity(0.07))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.top, 58)
            .padding(.bottom, 28)
        }
        .fileImporter(isPresented: $importingSound, allowedContentTypes: [.audio], allowsMultipleSelection: false) { result in
            if case let .success(urls) = result, let url = urls.first {
                store.importCustomSound(from: url)
            }
        }
        .preferredColorScheme(theme == .night ? .dark : .light)
        .statusBarHidden(false)
    }
}

struct SoundSelector: View {
    @EnvironmentObject private var store: AlarmStore
    @Binding var alarm: Alarm
    let theme: SleepTheme
    let showAll: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(visibleSounds) { sound in
                soundRow(sound)
            }
            if !store.customSounds.isEmpty {
                Text("Tus canciones")
                    .font(.caption.weight(.black))
                    .foregroundStyle(theme.secondaryText)
                    .padding(.top, 8)
                ForEach(store.customSounds) { sound in
                    customSoundRow(sound)
                }
            }
        }
    }

    private var visibleSounds: [AlarmSound] {
        showAll ? AlarmSound.all : Array(AlarmSound.all.prefix(5))
    }

    private func soundRow(_ sound: AlarmSound) -> some View {
        rowContent(
            icon: icon(for: sound.id),
            title: sound.name,
            subtitle: subtitle(for: sound),
            selected: alarm.soundIds.contains(sound.id),
            onToggle: {
                toggleSound(sound.id)
            },
            onPreview: {
                AlarmSoundPlayer.preview(sound: sound)
            },
            onDelete: nil
        )
    }

    private func customSoundRow(_ sound: CustomAlarmSound) -> some View {
        rowContent(
            icon: "music.note",
            title: sound.name,
            subtitle: "Cancion importada",
            selected: alarm.soundIds.contains(sound.soundId),
            onToggle: {
                toggleSound(sound.soundId)
            },
            onPreview: {
                AlarmSoundPlayer.preview(customSound: sound)
            },
            onDelete: {
                store.removeCustomSound(sound)
            }
        )
    }

    private func rowContent(icon: String, title: String, subtitle: String?, selected: Bool, onToggle: @escaping () -> Void, onPreview: @escaping () -> Void, onDelete: (() -> Void)?) -> some View {
        HStack(spacing: 14) {
            Button(action: onToggle) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title2.weight(.bold))
                    .frame(width: 34)
                    .foregroundStyle(selected ? theme.primary : theme.secondaryText.opacity(0.45))
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.black))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.secondaryText)
                }
            }
            Spacer()
            Button(action: onPreview) {
                Image(systemName: "play.fill")
                    .font(.subheadline.weight(.black))
                    .frame(width: 34, height: 34)
                    .background(theme.primary.opacity(0.18))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.primary)
            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.secondaryText)
            }
        }
        .foregroundStyle(theme.text)
        .padding(.horizontal, 14)
        .frame(minHeight: 54)
        .background(theme == .sunset ? Color.white.opacity(0.44) : Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? theme.primary.opacity(0.58) : theme.secondaryText.opacity(0.16), lineWidth: 1))
    }

    private func toggleSound(_ id: String) {
        if alarm.soundIds.contains(id) {
            alarm.soundIds.removeAll { $0 == id }
        } else {
            alarm.soundIds.append(id)
        }
        alarm.randomSound = alarm.soundIds.count > 1
    }

    private func icon(for id: String) -> String {
        switch id {
        case "funny-alarm": return "bell.fill"
        case "bosque-amanecer": return "tree.fill"
        case "despertar-suave": return "sunrise.fill"
        case "lo-fi-alarm": return "music.note"
        default: return "music.note"
        }
    }

    private func subtitle(for sound: AlarmSound) -> String {
        switch sound.id {
        case "funny-alarm": return "Alarma clara"
        case "bosque-amanecer": return "Ambiente natural"
        case "despertar-suave": return "Entrada tranquila"
        case "lo-fi-alarm": return "Ritmo suave"
        default: return "Sonido"
        }
    }
}

struct FadeDurationControl: View {
    @Binding var duration: Double
    var theme: SleepTheme = .sunset

    private var durationText: String {
        if duration < 60 { return "\(Int(duration)) s" }
        let minutes = duration / 60
        if minutes.rounded() == minutes { return "\(Int(minutes)) min" }
        return String(format: "%.1f min", minutes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Volumen progresivo", systemImage: "waveform")
                Spacer()
                Text(durationText)
                    .font(.headline.weight(.black))
                    .foregroundStyle(theme.primary)
            }
            .foregroundStyle(theme.text)

            Slider(value: $duration, in: 60...600, step: 60) {
                Text("Subida")
            } minimumValueLabel: {
                Text("1 min")
            } maximumValueLabel: {
                Text("10 min")
            }
            .tint(theme.primary)
            .foregroundStyle(theme.secondaryText)
        }
        .padding(16)
        .background(theme == .sunset ? Color.white.opacity(0.52) : Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .onAppear {
            if duration < 60 { duration = 60 }
        }
    }
}

struct NightActiveView: View {
    @EnvironmentObject private var session: NightSession
    let alarm: Alarm
    let theme: SleepTheme
    @State private var showMotionHint = true
    @State private var showStartedTitle = true

    var body: some View {
        ZStack {
            SleepBackdrop(theme: theme)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer(minLength: 86)

                Text(Self.currentTimeFormatter.string(from: session.now))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme == .sunset ? Color.white.opacity(0.88) : Color.white.opacity(0.76))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(theme == .sunset ? Color.black.opacity(0.12) : Color.white.opacity(0.08))
                    .clipShape(Capsule())

                if theme == .sunset {
                    Text("Buenas noches")
                        .font(.system(size: 38, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                }

                Text(alarm.timeText)
                    .font(.system(size: 86, weight: .bold, design: .serif))
                    .foregroundStyle(theme == .sunset ? Color.white.opacity(0.96) : Color.white.opacity(0.92))

                Text("La noche ha comenzado")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme == .sunset ? Color.white : theme.primary)
                    .opacity(showStartedTitle ? 1 : 0)

                Label("Mueve el móvil\npara posponer", systemImage: "iphone.radiowaves.left.and.right")
                    .font(.title3.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme == .sunset ? Color.white.opacity(0.92) : theme.primary)
                    .opacity(showMotionHint ? 1 : 0)
                    .frame(height: showMotionHint ? 62 : 0)

                Spacer()

                Button {
                    session.stop()
                } label: {
                    Label("Terminar", systemImage: "stop.fill")
                        .font(.headline.weight(.black))
                        .padding(.horizontal, 22)
                        .frame(height: 48)
                        .background(theme == .sunset ? Color.white.opacity(0.36) : Color.white.opacity(0.08))
                        .foregroundStyle(theme == .sunset ? Color(red: 0.30, green: 0.17, blue: 0.10) : Color.white)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(theme == .night ? Color.white.opacity(0.14) : Color.clear, lineWidth: 1))
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 30)
            }
            .padding(24)
        }
        .preferredColorScheme(theme == .night ? .dark : .light)
        .statusBarHidden(false)
        .onAppear {
            showMotionHint = true
            showStartedTitle = true
            withAnimation(.easeOut(duration: 1.4).delay(2.2)) {
                showMotionHint = false
            }
            withAnimation(.easeOut(duration: 1.4).delay(4.2)) {
                showStartedTitle = false
            }
        }
    }

    private static let currentTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

struct RingView: View {
    @EnvironmentObject private var session: NightSession
    let alarm: Alarm
    let theme: SleepTheme
    var onFinish: (() -> Void)?

    var body: some View {
        ZStack {
            SleepBackdrop(theme: theme)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer(minLength: 108)
                Text("La noche ha comenzado")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(theme == .sunset ? Color.white : theme.primary)

                Text(displayedAlarm.timeText)
                    .font(.system(size: 100, weight: .bold, design: .serif))
                    .foregroundStyle(Color.white.opacity(0.94))

                Image(systemName: theme == .sunset ? "moon.fill" : "moon.stars.fill")
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(theme == .sunset ? Color.white.opacity(0.88) : theme.primary)

                Text(statusText)
                    .font(.title2.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme == .sunset ? Color.white.opacity(0.94) : theme.primary)

                ProgressView(value: session.motionProgress)
                    .tint(.white)
                    .padding(.horizontal, 40)
                    .opacity(session.isSnoozing ? 0 : 1)
                    .onChange(of: session.motionProgress) { value in
                        if value > 0.96 { session.snooze() }
                    }

                Spacer()

                VStack(spacing: 12) {
                    RingActionButton(
                        title: session.isSnoozing ? "Pospuesta" : "Posponer",
                        icon: "moon.zzz.fill",
                        fill: theme.primary,
                        foreground: theme == .sunset ? .white : Color(red: 0.01, green: 0.06, blue: 0.08),
                        disabled: session.isSnoozing,
                        action: { session.snooze() }
                    )
                    RingActionButton(
                        title: "Terminar",
                        icon: "stop.fill",
                        fill: theme == .sunset ? Color.white.opacity(0.90) : Color.white.opacity(0.18),
                        foreground: theme == .sunset ? Color(red: 0.30, green: 0.17, blue: 0.10) : .white,
                        action: { onFinish?() ?? session.stop() }
                    )
                }
            }
            .padding(24)
        }
        .preferredColorScheme(theme == .night ? .dark : .light)
        .statusBarHidden(false)
    }

    private var statusText: String {
        if session.isSnoozing, let date = session.snoozedUntil {
            return "Pospuesta hasta \(Self.snoozeFormatter.string(from: date))"
        }
        return displayedAlarm.motionSnooze ? "Mueve el móvil\npara posponer" : "Alarma sonando"
    }

    private var displayedAlarm: Alarm {
        session.ringingAlarm ?? alarm
    }

    private static let snoozeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

struct RingActionButton: View {
    let title: String
    let icon: String
    let fill: Color
    let foreground: Color
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(title)
                    .font(.title2.weight(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            } icon: {
                Image(systemName: icon)
                    .font(.title2.weight(.black))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(fill)
            .foregroundStyle(foreground)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
            .shadow(color: fill.opacity(0.24), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.72 : 1)
    }
}

struct DreamJournalView: View {
    @EnvironmentObject private var store: AlarmStore
    @EnvironmentObject private var dreams: DreamStore
    @EnvironmentObject private var navigation: AppNavigation
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var draft = DreamEntry(day: Date())
    @FocusState private var notesFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                SleepBackdrop(theme: store.sleepTheme)
                    .ignoresSafeArea()
                    .overlay(store.sleepTheme == .sunset ? Color.white.opacity(0.52) : Color.black.opacity(0.20))

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        DatePicker("Día", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(store.sleepTheme.primary)
                            .padding(14)
                            .background(panelFill)
                            .clipShape(RoundedRectangle(cornerRadius: 18))

                        calendarPreview

                        DreamScoreCard(entry: draft)

                        SleepStageChart(entry: draft)

                        VStack(alignment: .leading, spacing: 10) {
                            Label("Diario de sueños", systemImage: "book.closed.fill")
                                .font(.headline.weight(.black))
                            TextEditor(text: $draft.notes)
                                .focused($notesFocused)
                                .frame(minHeight: 170)
                                .scrollContentBackground(.hidden)
                                .padding(12)
                                .background(editorFill)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .foregroundStyle(store.sleepTheme.text)

                        VStack(alignment: .leading, spacing: 10) {
                            Label("Seguimiento nocturno", systemImage: "waveform")
                                .font(.headline.weight(.black))
                            metricRow("Tiempo en cama", value: bedDurationText)
                            metricRow("Tiempo dormido estimado", value: sleepDurationText)
                            metricRow("Despertares estimados", value: "\(draft.awakeMinutes) min")
                            metricRow("Sueño ligero", value: "\(draft.lightSleepMinutes) min")
                            metricRow("Sueño profundo", value: "\(draft.deepSleepMinutes) min")
                            metricRow("Ronquidos detectados", value: "\(draft.snoreEvents)")
                            metricRow("Respiración fuerte", value: "\(draft.strongBreathingEvents)")
                            metricRow("Voz detectada", value: "\(draft.talkingEvents)")
                            metricRow("Clips de audio guardados", value: "\(draft.audioClips)")
                        }
                        .padding(16)
                        .background(panelFill)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .foregroundStyle(store.sleepTheme.text)
                    }
                    .padding(20)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
                .simultaneousGesture(TapGesture().onEnded { notesFocused = false })
            }
            .navigationTitle("Diario de sueño")
            .onAppear { loadEntry() }
            .onChange(of: selectedDate) { _ in loadEntry() }
            .onChange(of: navigation.requestedJournalDate) { date in
                guard let date else { return }
                selectedDate = Calendar.current.startOfDay(for: date)
                loadEntry()
                notesFocused = true
            }
            .onChange(of: draft.notes) { _ in dreams.upsert(draft) }
            .preferredColorScheme(store.sleepTheme == .night ? .dark : .light)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Listo") { notesFocused = false }
                }
            }
        }
    }

    private func loadEntry() {
        draft = dreams.entry(for: selectedDate)
        draft.day = selectedDate
    }

    private func metricRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .font(.headline.weight(.black))
        }
        .font(.subheadline.weight(.bold))
    }

    private var sleepDurationText: String {
        let minutes = draft.lightSleepMinutes + draft.deepSleepMinutes
        guard minutes > 0 else { return "Sin datos" }
        return "\(minutes / 60) h \(minutes % 60) min"
    }

    private var bedDurationText: String {
        guard let started = draft.sleepStartedAt else { return "Sin datos" }
        let ended = draft.sleepEndedAt ?? Date()
        let minutes = max(0, Int(ended.timeIntervalSince(started) / 60))
        guard minutes > 0 else { return "Menos de 1 min" }
        return "\(minutes / 60) h \(minutes % 60) min"
    }

    private var panelFill: Color {
        store.sleepTheme == .sunset ? Color.white.opacity(0.62) : Color.white.opacity(0.08)
    }

    private var editorFill: Color {
        store.sleepTheme == .sunset ? Color.white.opacity(0.64) : Color.white.opacity(0.10)
    }

    private var calendarPreview: some View {
        HStack(spacing: 8) {
            ForEach(previewDates, id: \.self) { date in
                let entry = dreams.entry(for: date)
                Button {
                    selectedDate = Calendar.current.startOfDay(for: date)
                } label: {
                    VStack(spacing: 6) {
                        Text(Self.dayFormatter.string(from: date))
                            .font(.caption2.weight(.black))
                        Circle()
                            .fill(previewColor(for: entry))
                            .frame(width: 10, height: 10)
                        Text(previewText(for: entry))
                            .font(.caption2.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Calendar.current.isDate(date, inSameDayAs: selectedDate) ? store.sleepTheme.primary.opacity(0.18) : panelFill)
                    .foregroundStyle(store.sleepTheme.text)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var previewDates: [Date] {
        (-3...3).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: selectedDate) }
    }

    private func previewText(for entry: DreamEntry) -> String {
        guard entry.hasSleepData, let score = entry.score else { return "Sin datos" }
        if score >= 80 { return "Bien" }
        if score >= 60 { return "Regular" }
        return "Mal"
    }

    private func previewColor(for entry: DreamEntry) -> Color {
        guard entry.hasSleepData, let score = entry.score else { return store.sleepTheme.secondaryText.opacity(0.35) }
        if score >= 80 { return Color.green }
        if score >= 60 { return Color.orange }
        return Color.red }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
}

struct DreamScoreCard: View {
    @EnvironmentObject private var store: AlarmStore
    let entry: DreamEntry

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Color.black.opacity(0.08), lineWidth: 10)
                if entry.hasSleepData, let score = entry.score {
                    Circle()
                        .trim(from: 0, to: CGFloat(max(0, min(100, score))) / 100)
                        .stroke(Color(red: 0.86, green: 0.34, blue: 0.20), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(score)")
                        .font(.title.weight(.black))
                } else {
                    Text("--")
                        .font(.title.weight(.black))
                        .foregroundStyle(store.sleepTheme.secondaryText)
                }
            }
            .frame(width: 86, height: 86)

            VStack(alignment: .leading, spacing: 6) {
                Text("Puntuación de sueño")
                    .font(.headline.weight(.black))
                Text(entry.hasSleepData ? "Estimación orientativa basada en movimiento y audio cuando el seguimiento esté activo." : "Sin datos para este día. La puntuación aparecerá después de una noche registrada.")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(store.sleepTheme.secondaryText)
            }
            Spacer()
        }
        .padding(16)
        .background(store.sleepTheme == .sunset ? Color.white.opacity(0.62) : Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .foregroundStyle(store.sleepTheme.text)
    }
}

struct SleepStageChart: View {
    @EnvironmentObject private var store: AlarmStore
    let entry: DreamEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Gráfica de sueño", systemImage: "chart.bar.fill")
                .font(.headline.weight(.black))

            if entry.samples.isEmpty {
                Text("Sin muestras todavía. Se generarán al usar Empezar noche con el teléfono cerca.")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(store.sleepTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 18)
            } else {
                GeometryReader { proxy in
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(entry.samples.suffix(120)) { sample in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color(for: sample.stage))
                                .frame(width: max(2, proxy.size.width / CGFloat(min(entry.samples.count, 120)) - 2), height: height(for: sample.stage, total: proxy.size.height))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
                .frame(height: 110)

                HStack(spacing: 12) {
                    legend("Profundo", color: Color(red: 0.15, green: 0.38, blue: 0.74))
                    legend("Ligero", color: Color(red: 0.37, green: 0.83, blue: 0.88))
                    legend("Despierto", color: Color(red: 0.86, green: 0.34, blue: 0.20))
                }
            }
        }
        .padding(16)
        .background(store.sleepTheme == .sunset ? Color.white.opacity(0.62) : Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .foregroundStyle(store.sleepTheme.text)
    }

    private func color(for stage: SleepStageSample.Stage) -> Color {
        switch stage {
        case .deep: return Color(red: 0.15, green: 0.38, blue: 0.74)
        case .light: return Color(red: 0.37, green: 0.83, blue: 0.88)
        case .awake: return Color(red: 0.86, green: 0.34, blue: 0.20)
        }
    }

    private func height(for stage: SleepStageSample.Stage, total: CGFloat) -> CGFloat {
        switch stage {
        case .deep: return total * 0.35
        case .light: return total * 0.62
        case .awake: return total * 0.95
        }
    }

    private func legend(_ text: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.caption.weight(.bold))
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: AlarmStore
    @State private var editingSleepAlarm = false

    var body: some View {
        NavigationStack {
            ZStack {
                SleepBackdrop(theme: store.sleepTheme)
                    .ignoresSafeArea()
                    .overlay(store.sleepTheme == .sunset ? Color.white.opacity(0.52) : Color.black.opacity(0.20))

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        settingsGroup("Apariencia", systemImage: "circle.lefthalf.filled") {
                            Picker("Tema", selection: $store.appearance) {
                                ForEach(AppAppearance.allCases) { appearance in
                                    Text(appearance.title).tag(appearance)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        settingsGroup("Seguimiento nocturno", systemImage: "waveform") {
                            settingToggle("Abrir diario al terminar alarma", isOn: $store.openJournalAfterAlarm)
                            settingToggle("Grabar sonidos nocturnos", isOn: $store.sleepRecordingEnabled)
                            Text("La detección de ronquidos, respiración fuerte y voz se guarda localmente como estimación.")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(store.sleepTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        settingsGroup("Despertar", systemImage: "sunrise.fill") {
                            settingToggle("Mover para posponer", isOn: Binding(
                                get: { store.sleepAlarm.motionSnooze },
                                set: { enabled in
                                    var alarm = store.sleepAlarm
                                    alarm.motionSnooze = enabled
                                    store.updateSleepAlarm(alarm)
                                }
                            ))
                            settingRow("Posponer", value: "\(store.sleepAlarm.snoozeMinutes) min")
                            snoozeSelector

                            Divider().opacity(0.28)

                            settingToggle("Luz progresiva", isOn: Binding(
                                get: { store.sleepAlarm.lightWakeEnabled },
                                set: { enabled in
                                    var alarm = store.sleepAlarm
                                    alarm.lightWakeEnabled = enabled
                                    store.updateSleepAlarm(alarm)
                                }
                            ))
                            if store.sleepAlarm.lightWakeEnabled {
                                lightWakeSelector
                            }

                            Button {
                                editingSleepAlarm = true
                            } label: {
                                Label("Editar alarma", systemImage: "slider.horizontal.3")
                                    .font(.headline.weight(.black))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(store.sleepTheme.primary)
                                    .foregroundStyle(store.sleepTheme == .sunset ? .white : Color(red: 0.01, green: 0.06, blue: 0.08))
                                    .clipShape(Capsule())
                            }
                        }

                        Text(appIdentityText)
                            .font(.caption.weight(.black))
                            .foregroundStyle(store.sleepTheme.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 6)
                    }
                    .padding(20)
                    .foregroundStyle(store.sleepTheme.text)
                }
            }
            .navigationTitle("Ajustes")
            .preferredColorScheme(store.sleepTheme == .night ? .dark : .light)
            .sheet(isPresented: $editingSleepAlarm) {
                EditAlarmView(
                    alarm: store.sleepAlarm,
                    theme: store.sleepTheme,
                    onSave: { updated in store.updateSleepAlarm(updated) },
                    onDelete: nil
                )
            }
        }
    }

    private func settingsGroup<Content: View>(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.black))
            content()
        }
        .padding(16)
        .background(store.sleepTheme == .sunset ? Color.white.opacity(0.62) : Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func settingRow(_ title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.black))
                .foregroundStyle(store.sleepTheme.secondaryText)
        }
        .font(.subheadline.weight(.bold))
    }

    private func settingToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.subheadline.weight(.bold))
        }
        .tint(store.sleepTheme.primary)
    }

    private var appIdentityText: String {
        let name = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
            ?? "Alarma"
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "dev"
        return "\(name) iPhone - v\(version) build \(build)"
    }

    private var lightWakeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Empieza antes de la alarma")
                .font(.caption.weight(.bold))
                .foregroundStyle(store.sleepTheme.secondaryText)
            HStack(spacing: 8) {
                ForEach([5, 10], id: \.self) { minutes in
                    Button {
                        var alarm = store.sleepAlarm
                        alarm.lightWakeMinutes = minutes
                        store.updateSleepAlarm(alarm)
                    } label: {
                        Text("\(minutes) min")
                            .font(.caption.weight(.black))
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(store.sleepAlarm.lightWakeMinutes == minutes ? store.sleepTheme.primary.opacity(0.22) : Color.white.opacity(store.sleepTheme == .sunset ? 0.30 : 0.07))
                            .foregroundStyle(store.sleepAlarm.lightWakeMinutes == minutes ? store.sleepTheme.primary : store.sleepTheme.text)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var snoozeSelector: some View {
        HStack(spacing: 8) {
            ForEach([5, 10, 15], id: \.self) { minutes in
                Button {
                    var alarm = store.sleepAlarm
                    alarm.snoozeMinutes = minutes
                    store.updateSleepAlarm(alarm)
                } label: {
                    Text("\(minutes) min")
                        .font(.caption.weight(.black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(store.sleepAlarm.snoozeMinutes == minutes ? store.sleepTheme.primary.opacity(0.22) : Color.white.opacity(store.sleepTheme == .sunset ? 0.30 : 0.07))
                        .foregroundStyle(store.sleepAlarm.snoozeMinutes == minutes ? store.sleepTheme.primary : store.sleepTheme.text)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

