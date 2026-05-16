import AVFoundation
import CoreMotion
import SwiftUI
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
    var weekdays: Set<Int> = [2, 3, 4, 5, 6]
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
        .init(id: "sea", name: "Brisa del mar", baseFrequency: 392, color: .teal)
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

    private let key = "alarma.native.alarms.v1"
    private let sleepKey = "alarma.native.sleepAlarm.v1"

    var notificationAlarms: [Alarm] {
        [sleepAlarm]
    }

    init() {
        load()
        loadSleepAlarm()
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

    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "dev"
        return "v\(version)\nbuild \(build)"
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 1, green: 0.98, blue: 0.92), Color(red: 0.98, green: 0.82, blue: 0.66)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    header
                    hero
                }
                .padding(.horizontal, 18)
                .padding(.top, 28)
                .padding(.bottom, 36)
            }
        }
        .sheet(isPresented: $editingSleepAlarm) {
            EditAlarmView(
                alarm: store.sleepAlarm,
                title: "Alarma principal",
                onSave: { updated in store.updateSleepAlarm(updated) },
                onDelete: nil
            )
        }
        .fullScreenCover(isPresented: Binding(get: { session.isActive }, set: { if !$0 { session.stop() } })) {
            if let alarm = session.activeAlarm {
                NightActiveView(alarm: alarm)
            }
        }
        .fullScreenCover(item: $session.ringingAlarm) { alarm in
            RingView(alarm: alarm)
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
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Despertador")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.orange)
                    .textCase(.uppercase)
                Text("Alarma")
                    .font(.system(size: 54, weight: .bold, design: .serif))
                    .foregroundStyle(Color(red: 0.31, green: 0.15, blue: 0.08))
            }
            Spacer()
            VStack(spacing: 10) {
                Text(appVersionText)
                    .font(.caption.weight(.black))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(red: 0.31, green: 0.15, blue: 0.08))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.74))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Alarma principal")
                .font(.headline)
                .foregroundStyle(Color(red: 0.86, green: 0.28, blue: 0.16))
            TimeNumberPicker(hour: sleepHourBinding, minute: sleepMinuteBinding)
            Text("Para dormir y despertar - subida \(Int(store.sleepAlarm.fadeDuration / 60)) min")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color(red: 0.41, green: 0.20, blue: 0.11).opacity(0.76))
            HStack {
                Button {
                    session.start(alarm: store.sleepAlarm)
                } label: {
                    Text("Empezar noche")
                        .font(.headline.weight(.black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(Color.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Button("Ajustar") {
                    editingSleepAlarm = true
                }
                .font(.headline.weight(.black))
                .frame(width: 96, height: 58)
                .background(Color.white.opacity(0.55))
                .foregroundStyle(Color(red: 0.31, green: 0.15, blue: 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(18)
        .background(
            SunsetScene()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.16))
                )
        )
    }

    private var sleepHourBinding: Binding<Int> {
        Binding {
            store.sleepAlarm.hour
        } set: { hour in
            var alarm = store.sleepAlarm
            alarm.hour = hour
            store.updateSleepAlarm(alarm)
        }
    }

    private var sleepMinuteBinding: Binding<Int> {
        Binding {
            store.sleepAlarm.minute
        } set: { minute in
            var alarm = store.sleepAlarm
            alarm.minute = minute
            store.updateSleepAlarm(alarm)
        }
    }

}

struct TimeNumberPicker: View {
    @Binding var hour: Int
    @Binding var minute: Int

    var body: some View {
        HStack(spacing: 0) {
            Picker("Hora", selection: $hour) {
                ForEach(0..<24, id: \.self) { value in
                    Text(String(format: "%02d", value))
                        .font(.system(size: 64, weight: .bold, design: .serif))
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 118, height: 116)
            .clipped()

            Text(":")
                .font(.system(size: 68, weight: .bold, design: .serif))
                .foregroundStyle(Color(red: 0.31, green: 0.15, blue: 0.08))
                .offset(y: -2)

            Picker("Minuto", selection: $minute) {
                ForEach(0..<60, id: \.self) { value in
                    Text(String(format: "%02d", value))
                        .font(.system(size: 64, weight: .bold, design: .serif))
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 118, height: 116)
            .clipped()
        }
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .tint(Color(red: 0.31, green: 0.15, blue: 0.08))
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
    var title = "Editar alarma"
    var allowRepeatDays = true
    let onSave: (Alarm) -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre", text: $alarm.label)
                    DatePicker("Hora", selection: timeBinding, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                }

                if allowRepeatDays {
                    Section("Dias") {
                    HStack {
                        ForEach(Weekday.all) { day in
                            Button(day.short) {
                                if alarm.weekdays.contains(day.calendarValue) {
                                    alarm.weekdays.remove(day.calendarValue)
                                } else {
                                    alarm.weekdays.insert(day.calendarValue)
                                }
                            }
                            .font(.headline.weight(.black))
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .background(alarm.weekdays.contains(day.calendarValue) ? Color.orange.opacity(0.25) : Color.gray.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    }
                }

                Section("Musicas posibles") {
                    Button("Deseleccionar todas") {
                        alarm.soundIds.removeAll()
                    }
                    ForEach(AlarmSound.all) { sound in
                        HStack {
                            Toggle(sound.name, isOn: Binding(
                                get: { alarm.soundIds.contains(sound.id) },
                                set: { enabled in
                                    if enabled {
                                        if !alarm.soundIds.contains(sound.id) { alarm.soundIds.append(sound.id) }
                                    } else {
                                        alarm.soundIds.removeAll { $0 == sound.id }
                                    }
                                }
                            ))
                            Button("Probar") {
                                AlarmSoundPlayer.preview(sound: sound)
                            }
                            .font(.caption.weight(.black))
                            .buttonStyle(.bordered)
                        }
                    }
                    Text("Si eliges mas de una, la app escoge una al azar.")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                Section("Despertar") {
                    Toggle("Volumen progresivo", isOn: $alarm.fadeInEnabled)
                    Slider(value: $alarm.fadeDuration, in: 30...300, step: 30) {
                        Text("Subida")
                    } minimumValueLabel: {
                        Text("30s")
                    } maximumValueLabel: {
                        Text("5m")
                    }
                    Toggle("Mover para posponer", isOn: $alarm.motionSnooze)
                    Stepper("Posponer \(alarm.snoozeMinutes) min", value: $alarm.snoozeMinutes, in: 5...20, step: 5)
                }

                if onDelete != nil {
                    Section {
                        Button("Eliminar", role: .destructive) {
                            onDelete?()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        alarm.randomSound = alarm.soundIds.count > 1
                        onSave(alarm)
                        dismiss()
                    }
                }
            }
        }
    }

    private var timeBinding: Binding<Date> {
        Binding {
            var components = DateComponents()
            components.hour = alarm.hour
            components.minute = alarm.minute
            return Calendar.current.date(from: components) ?? Date()
        } set: { date in
            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            alarm.hour = components.hour ?? alarm.hour
            alarm.minute = components.minute ?? alarm.minute
        }
    }
}

struct NightActiveView: View {
    @EnvironmentObject private var session: NightSession
    let alarm: Alarm

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.12, green: 0.09, blue: 0.16), Color(red: 0.28, green: 0.14, blue: 0.13)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Noche activa")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.orange)
                    .textCase(.uppercase)
                Text(session.now, format: .dateTime.hour().minute())
                    .font(.system(size: 86, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                Text("Despertar a las \(alarm.timeText)")
                    .font(.title3.weight(.black))
                    .foregroundStyle(.orange)
                Text("Puedes bloquear el movil. No fuerces el cierre de la app.")
                    .font(.subheadline.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.horizontal)
                Spacer()
                Button("Terminar noche") {
                    session.stop()
                }
                .font(.headline.weight(.black))
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Color.white.opacity(0.92))
                .foregroundStyle(Color(red: 0.31, green: 0.15, blue: 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(24)
        }
    }
}

struct RingView: View {
    @EnvironmentObject private var session: NightSession
    @EnvironmentObject private var store: AlarmStore
    let alarm: Alarm

    var body: some View {
        ZStack {
            SunsetScene()
                .ignoresSafeArea()
            LinearGradient(colors: [Color.white.opacity(0.06), Color(red: 0.24, green: 0.10, blue: 0.06).opacity(0.56)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 22) {
                Spacer()
                Text(alarm.timeText)
                    .font(.system(size: 100, weight: .bold, design: .serif))
                    .foregroundStyle(Color(red: 0.31, green: 0.15, blue: 0.08))
                Text(alarm.motionSnooze ? "Mueve el movil para posponer" : "Alarma sonando")
                    .font(.title2.weight(.black))
                    .foregroundStyle(.orange)
                ProgressView(value: session.motionProgress)
                    .tint(.white)
                    .padding(.horizontal, 40)
                    .onChange(of: session.motionProgress) { value in
                        if value > 0.92 { session.snooze(store: store) }
                    }
                Spacer()
                Button("Posponer") { session.snooze(store: store) }
                    .font(.title2.weight(.black))
                    .frame(maxWidth: .infinity)
                    .frame(height: 74)
                    .background(Color.orange)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                Button("Apagar") { session.stop() }
                    .font(.title2.weight(.black))
                    .frame(maxWidth: .infinity)
                    .frame(height: 74)
                    .background(Color.white.opacity(0.92))
                    .foregroundStyle(Color(red: 0.31, green: 0.15, blue: 0.08))
                    .clipShape(Capsule())
            }
            .padding(24)
        }
    }
}

