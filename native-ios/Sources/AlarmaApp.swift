import AVFoundation
import CoreMotion
import SwiftUI
import UIKit
import UserNotifications

@main
struct AlarmaApp: App {
    @StateObject private var store = AlarmStore()
    @StateObject private var session = NightSession()

    init() {
        AlarmSoundPlayer.configurePlaybackSession()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(session)
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
    var soundIds: [String] = ["sunrise", "piano", "rain"]
    var randomSound = true
    var fadeInEnabled = true
    var fadeDuration = 180.0
    var motionSnooze = true
    var snoozeMinutes = 5
    var enabled = true
    var lastRingKey: String?

    var timeText: String {
        String(format: "%02d:%02d", hour, minute)
    }

    var repeatText: String {
        if weekdays.isEmpty { return "Una vez" }
        if weekdays.count == 7 { return "Todos los dias" }
        if weekdays == [2, 3, 4, 5, 6] { return "Laborables" }
        return Weekday.all.filter { weekdays.contains($0.calendarValue) }.map(\.short).joined(separator: " ")
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

struct AlarmSound: Identifiable, Hashable {
    let id: String
    let name: String
    let baseFrequency: Double
    let color: Color

    static let all: [AlarmSound] = [
        .init(id: "sunrise", name: "Amanecer", baseFrequency: 220, color: .orange),
        .init(id: "sunset", name: "Atardecer", baseFrequency: 196, color: .pink),
        .init(id: "piano", name: "Piano suave", baseFrequency: 262, color: .brown),
        .init(id: "rain", name: "Lluvia lenta", baseFrequency: 174, color: .blue),
        .init(id: "sea", name: "Brisa del mar", baseFrequency: 392, color: .teal),
        .init(id: "forest", name: "Bosque nocturno", baseFrequency: 146, color: .green),
        .init(id: "wind", name: "Viento suave", baseFrequency: 185, color: .cyan),
        .init(id: "bells", name: "Campanas suaves", baseFrequency: 330, color: .yellow),
        .init(id: "chimes", name: "Carillones", baseFrequency: 440, color: .mint),
        .init(id: "harp", name: "Arpa lenta", baseFrequency: 294, color: .purple),
        .init(id: "river", name: "Rio tranquilo", baseFrequency: 247, color: .indigo),
        .init(id: "white-noise", name: "Ruido blanco", baseFrequency: 128, color: .gray)
    ]
}

@MainActor
final class AlarmStore: ObservableObject {
    @Published var alarms: [Alarm] = [] {
        didSet { save() }
    }
    @Published var sleepAlarm = Alarm(label: "Noche", hour: 7, minute: 30, weekdays: [], soundIds: ["sunrise", "sunset", "piano", "rain"], randomSound: true, enabled: true) {
        didSet { saveSleepAlarm() }
    }
    @Published var sleepTheme: SleepTheme = .sunset {
        didSet { UserDefaults.standard.set(sleepTheme.rawValue, forKey: themeKey) }
    }

    private let key = "alarma.native.alarms.v1"
    private let sleepKey = "alarma.native.sleepAlarm.v1"
    private let themeKey = "alarma.native.sleepTheme.v1"

    var notificationAlarms: [Alarm] {
        [sleepAlarm]
    }

    init() {
        load()
        loadSleepAlarm()
        loadTheme()
        if alarms.isEmpty {
            alarms = [
                Alarm(),
                Alarm(label: "Fin de semana", hour: 9, minute: 0, weekdays: [1, 7], soundIds: ["sea"], randomSound: false, enabled: false)
            ]
        }
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

    private func loadTheme() {
        guard let rawValue = UserDefaults.standard.string(forKey: themeKey),
              let theme = SleepTheme(rawValue: rawValue) else {
            return
        }
        sleepTheme = theme
    }
}

final class NotificationScheduler {
    static let shared = NotificationScheduler()

    func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .timeSensitive])
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

    private let motion = CMMotionManager()
    private let sound = AlarmSoundPlayer()
    private var clockTimer: Timer?
    private var motionTimer: Timer?
    private var alarmMonitor: DispatchSourceTimer?
    private var firedRingKeys: Set<String> = []
    private var backgroundGuardActive = false

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
        activeAlarm = alarm
        backgroundGuardActive = true
        UIApplication.shared.isIdleTimerDisabled = true
        sound.startKeepAlive()
        startClock()
        startMotionIfNeeded(alarm)
    }

    func stop() {
        activeAlarm = nil
        ringingAlarm = nil
        motionProgress = 0
        clockTimer?.invalidate()
        motionTimer?.invalidate()
        motion.stopDeviceMotionUpdates()
        sound.stop()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func ring(_ alarm: Alarm) {
        ringingAlarm = alarm
        activeAlarm = nil
        backgroundGuardActive = false
        UIApplication.shared.isIdleTimerDisabled = true
        sound.start(for: alarm)
        startMotionIfNeeded(alarm)
    }

    func snooze(store: AlarmStore) {
        guard let alarm = ringingAlarm else { return }
        sound.stop()
        var snoozed = alarm
        let date = Calendar.current.date(byAdding: .minute, value: alarm.snoozeMinutes, to: Date()) ?? Date()
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        snoozed.id = UUID()
        snoozed.label = "\(alarm.label) pospuesta"
        snoozed.hour = components.hour ?? alarm.hour
        snoozed.minute = components.minute ?? alarm.minute
        snoozed.weekdays = []
        snoozed.enabled = true
        ringingAlarm = nil
        store.upsert(snoozed)
        start(alarm: snoozed)
    }

    private func startClock() {
        clockTimer?.invalidate()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.now = Date() }
        }
    }

    private func startMotionIfNeeded(_ alarm: Alarm) {
        motionTimer?.invalidate()
        motion.stopDeviceMotionUpdates()
        motionProgress = 0
        guard alarm.motionSnooze, motion.isDeviceMotionAvailable else { return }
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
}

final class AlarmSoundPlayer {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var rampTimer: Timer?
    private var phase = 0.0
    private var gain: Float = 0.04

    static func preview(sound: AlarmSound) {
        let player = AlarmSoundPlayer()
        player.startPreview(sound: sound)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
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

        let sampleRate = 44_100.0
        gain = 0.0008
        phase = 0

        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList in
            guard let self else { return noErr }
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let value = Float(sin(self.phase)) * self.gain
                self.phase += 2.0 * Double.pi * 110.0 / sampleRate
                if self.phase > 2.0 * Double.pi { self.phase -= 2.0 * Double.pi }
                for buffer in buffers {
                    let pointer = buffer.mData!.assumingMemoryBound(to: Float.self)
                    pointer[frame] = value
                }
            }
            return noErr
        }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        sourceNode = node
        try? engine.start()
    }

    func start(for alarm: Alarm) {
        stop()
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
        try? session.setActive(true)

        let soundId = alarm.soundIds.count > 1 ? (alarm.soundIds.randomElement() ?? "sunrise") : (alarm.soundIds.first ?? "sunrise")
        let sound = AlarmSound.all.first { $0.id == soundId } ?? AlarmSound.all[0]
        play(sound: sound, initialGain: alarm.fadeInEnabled ? 0.035 : 0.85)

        if alarm.fadeInEnabled {
            let started = Date()
            rampTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
                guard let self else { return }
                let elapsed = Date().timeIntervalSince(started)
                let progress = min(1, elapsed / max(1, alarm.fadeDuration))
                self.gain = Float(0.035 + progress * 0.865)
                if progress >= 1 { timer.invalidate() }
            }
        }
    }

    private func startPreview(sound: AlarmSound) {
        stop()
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        play(sound: sound, initialGain: 0.22)
    }

    private func play(sound: AlarmSound, initialGain: Float) {
        let sampleRate = 44_100.0
        gain = initialGain
        phase = 0

        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList in
            guard let self else { return noErr }
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let envelope = 0.55 + 0.45 * sin(self.phase * 0.012)
                let value = Float(sin(self.phase) * envelope) * self.gain
                self.phase += 2.0 * Double.pi * sound.baseFrequency / sampleRate
                if self.phase > 2.0 * Double.pi { self.phase -= 2.0 * Double.pi }
                for buffer in buffers {
                    let pointer = buffer.mData!.assumingMemoryBound(to: Float.self)
                    pointer[frame] = value
                }
            }
            return noErr
        }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        sourceNode = node
        try? engine.start()
    }

    func stop() {
        rampTimer?.invalidate()
        rampTimer = nil
        if engine.isRunning { engine.stop() }
        if let sourceNode {
            engine.detach(sourceNode)
        }
        sourceNode = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: AlarmStore
    @EnvironmentObject private var session: NightSession
    @Environment(\.scenePhase) private var scenePhase
    @State private var editingSleepAlarm = false

    private var appIdentityText: String {
        let name = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
            ?? "Alarma"
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "dev"
        return "\(name) iPhone - v\(version) build \(build)"
    }

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
        .fullScreenCover(isPresented: Binding(get: { session.isActive }, set: { if !$0 { session.stop() } })) {
            if let alarm = session.activeAlarm {
                NightActiveView(alarm: alarm, theme: store.sleepTheme)
            }
        }
        .fullScreenCover(item: $session.ringingAlarm) { alarm in
            RingView(alarm: alarm, theme: store.sleepTheme)
        }
        .onAppear {
            session.startAlarmMonitor { [store.sleepAlarm] }
            session.syncBackgroundGuard(alarms: [store.sleepAlarm])
        }
        .onChange(of: store.sleepAlarm) { alarm in
            session.syncBackgroundGuard(alarms: [alarm])
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background || phase == .inactive {
                session.syncBackgroundGuard(alarms: [store.sleepAlarm])
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(store.sleepTheme.title)
                    .font(.system(size: 46, weight: .bold, design: .serif))
                    .foregroundStyle(store.sleepTheme.text)
                    .minimumScaleFactor(0.75)

                Text(appIdentityText)
                    .font(.caption.weight(.black))
                    .foregroundStyle(store.sleepTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    store.sleepTheme = store.sleepTheme == .sunset ? .night : .sunset
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
                Text("Cada noche")
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
                backgroundImage
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

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

    private var backgroundImage: Image {
        let assetName = theme == .sunset ? "SunsetBackground" : "NightBackground"
        let fileName = theme == .sunset ? "sunset-background" : "night-background"
        if let uiImage = UIImage(named: assetName) {
            return Image(uiImage: uiImage)
        }
        if let url = Bundle.main.url(forResource: fileName, withExtension: "png"),
           let uiImage = UIImage(contentsOfFile: url.path) {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: theme == .sunset ? "sun.max.fill" : "moon.stars.fill")
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
                    Text("\(alarm.repeatText) - aviso iOS, sin audio todo el dia")
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
    }

    private var panelFill: Color {
        theme == .sunset ? Color.white.opacity(0.52) : Color.white.opacity(0.07)
    }

    private var soundSummary: String {
        let selected = AlarmSound.all.filter { alarm.soundIds.contains($0.id) }
        if selected.isEmpty { return "Ninguna seleccionada" }
        if selected.count == 1 { return selected[0].name }
        return "\(selected.count) seleccionadas"
    }
}

struct TimeEditPanel: View {
    @Binding var alarm: Alarm
    let theme: SleepTheme

    var body: some View {
        HStack(spacing: 16) {
            TimeStepperColumn(
                title: "Hora",
                value: alarm.hour,
                range: 0...23,
                theme: theme,
                onChange: { alarm.hour = $0 }
            )

            Text(":")
                .font(.system(size: 58, weight: .bold, design: .serif))
                .foregroundStyle(theme.text.opacity(0.72))
                .padding(.top, 26)

            TimeStepperColumn(
                title: "Min",
                value: alarm.minute,
                range: 0...59,
                theme: theme,
                onChange: { alarm.minute = $0 }
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(theme == .sunset ? Color.white.opacity(0.54) : Color.white.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(theme == .sunset ? Color.white.opacity(0.20) : Color.white.opacity(0.16), lineWidth: 1))
        )
        .foregroundStyle(.white)
    }
}

struct TimeStepperColumn: View {
    let title: String
    let value: Int
    let range: ClosedRange<Int>
    let theme: SleepTheme
    let onChange: (Int) -> Void
    @State private var lastStep = 0

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.caption.weight(.black))
                .foregroundStyle(theme.secondaryText)
            Text(String(format: "%02d", value))
                .font(.system(size: 54, weight: .bold, design: .serif))
                .foregroundStyle(theme.text)
                .frame(maxWidth: .infinity)
                .frame(height: 96)
                .background(theme == .sunset ? Color.white.opacity(0.32) : Color.black.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .contentShape(Rectangle())
                .gesture(dragGesture)
            Text("Arrastra")
                .font(.caption2.weight(.black))
                .foregroundStyle(theme.secondaryText.opacity(0.76))
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.primary)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { gesture in
                let step = Int((-gesture.translation.height / 18).rounded(.towardZero))
                guard step != lastStep else { return }
                let delta = step - lastStep
                lastStep = step
                onChange(wrapped(value + delta))
            }
            .onEnded { _ in
                lastStep = 0
            }
    }

    private func wrapped(_ rawValue: Int) -> Int {
        if rawValue < range.lowerBound { return range.upperBound }
        if rawValue > range.upperBound { return range.lowerBound }
        return rawValue
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

struct SoundPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var alarm: Alarm
    let theme: SleepTheme

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
    }
}

struct SoundSelector: View {
    @Binding var alarm: Alarm
    let theme: SleepTheme
    let showAll: Bool

    var body: some View {
        VStack(spacing: 8) {
            ForEach(visibleSounds) { sound in
                soundRow(sound)
            }
        }
    }

    private var visibleSounds: [AlarmSound] {
        showAll ? AlarmSound.all : Array(AlarmSound.all.prefix(5))
    }

    private func soundRow(_ sound: AlarmSound) -> some View {
        Button {
            if alarm.soundIds.contains(sound.id) {
                alarm.soundIds.removeAll { $0 == sound.id }
            } else {
                alarm.soundIds.append(sound.id)
            }
            alarm.randomSound = alarm.soundIds.count > 1
            AlarmSoundPlayer.preview(sound: sound)
        } label: {
            rowContent(icon: icon(for: sound.id), title: sound.name, subtitle: subtitle(for: sound), selected: alarm.soundIds.contains(sound.id))
        }
        .buttonStyle(.plain)
    }

    private func rowContent(icon: String, title: String, subtitle: String?, selected: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3.weight(.bold))
                .frame(width: 34)
                .foregroundStyle(theme.primary)
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
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.title2.weight(.bold))
                .foregroundStyle(selected ? theme.primary : theme.secondaryText.opacity(0.45))
        }
        .foregroundStyle(theme.text)
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(theme == .sunset ? Color.white.opacity(0.44) : Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? theme.primary.opacity(0.58) : theme.secondaryText.opacity(0.16), lineWidth: 1))
    }

    private func icon(for id: String) -> String {
        switch id {
        case "sunrise": return "sunrise.fill"
        case "sunset": return "water.waves"
        case "piano": return "pianokeys"
        case "rain": return "cloud.rain.fill"
        case "sea": return "water.waves"
        case "forest": return "tree.fill"
        case "wind": return "wind"
        case "bells": return "bell.fill"
        case "chimes": return "sparkles"
        case "harp": return "music.note"
        case "river": return "drop.fill"
        case "white-noise": return "waveform"
        default: return "music.note"
        }
    }

    private func subtitle(for sound: AlarmSound) -> String {
        switch sound.id {
        case "sunrise": return "Suave y brillante"
        case "sunset": return "Calido y lento"
        case "piano": return "Notas suaves"
        case "rain": return "Constante y relajante"
        case "sea": return "Olas tranquilas"
        case "forest": return "Ambiente profundo"
        case "wind": return "Aire ligero"
        case "bells": return "Tonos claros"
        case "chimes": return "Textura ligera"
        case "harp": return "Melodia lenta"
        case "river": return "Agua continua"
        case "white-noise": return "Fondo uniforme"
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

    var body: some View {
        ZStack {
            SleepBackdrop(theme: theme)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer(minLength: 86)

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

                Label("Mueve el movil\npara posponer", systemImage: "iphone.radiowaves.left.and.right")
                    .font(.title3.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme == .sunset ? Color.white.opacity(0.92) : theme.primary)

                Spacer()

                Button {
                    session.stop()
                } label: {
                    Label("Terminar", systemImage: "stop.fill")
                        .font(.title2.weight(.black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 72)
                        .background(theme == .sunset ? Color.white.opacity(0.88) : Color.white.opacity(0.10))
                        .foregroundStyle(theme == .sunset ? Color(red: 0.30, green: 0.17, blue: 0.10) : Color.white)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(theme == .night ? Color.white.opacity(0.14) : Color.clear, lineWidth: 1))
                }
                .padding(.bottom, 30)
            }
            .padding(24)
        }
    }
}

struct RingView: View {
    @EnvironmentObject private var session: NightSession
    @EnvironmentObject private var store: AlarmStore
    let alarm: Alarm
    let theme: SleepTheme

    var body: some View {
        ZStack {
            SleepBackdrop(theme: theme)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer(minLength: 108)
                Text("La noche ha comenzado")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(theme == .sunset ? Color.white : theme.primary)

                Text(alarm.timeText)
                    .font(.system(size: 100, weight: .bold, design: .serif))
                    .foregroundStyle(Color.white.opacity(0.94))

                Image(systemName: theme == .sunset ? "moon.fill" : "moon.stars.fill")
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(theme == .sunset ? Color.white.opacity(0.88) : theme.primary)

                Text(alarm.motionSnooze ? "Mueve el movil\npara posponer" : "Alarma sonando")
                    .font(.title2.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme == .sunset ? Color.white.opacity(0.94) : theme.primary)

                ProgressView(value: session.motionProgress)
                    .tint(.white)
                    .padding(.horizontal, 40)
                    .onChange(of: session.motionProgress) { value in
                        if value > 0.92 { session.snooze(store: store) }
                    }

                Spacer()

                if theme == .night {
                    HStack(spacing: 22) {
                        RingCircleButton(title: "Posponer", icon: "moon.zzz.fill", fill: theme.primary.opacity(0.24), action: { session.snooze(store: store) })
                        RingCircleButton(title: "Terminar", icon: "stop.fill", fill: Color.white.opacity(0.10), action: { session.stop() })
                    }
                } else {
                    Button { session.snooze(store: store) } label: {
                        Label("Posponer", systemImage: "iphone.radiowaves.left.and.right")
                            .font(.title2.weight(.black))
                            .frame(maxWidth: .infinity)
                            .frame(height: 72)
                            .background(theme.primary)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    Button { session.stop() } label: {
                        Label("Terminar", systemImage: "stop.fill")
                            .font(.title2.weight(.black))
                            .frame(maxWidth: .infinity)
                            .frame(height: 72)
                            .background(Color.white.opacity(0.88))
                            .foregroundStyle(Color(red: 0.30, green: 0.17, blue: 0.10))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(24)
        }
    }
}

struct RingCircleButton: View {
    let title: String
    let icon: String
    let fill: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .black))
                Text(title)
                    .font(.headline.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(fill)
            .foregroundStyle(.white)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
        }
    }
}

