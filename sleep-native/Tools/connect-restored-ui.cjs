const fs=require('fs');
const dir='sleep-native/Sources/';
let s=fs.readFileSync(dir+'SleepStore.swift','utf8');
s=s.replace('    }\n\n    func change',`        if data.nightlyAlarm == nil {
            var alarm = data.alarms.first ?? WakeAlarm()
            alarm.oneShotDate = nil; alarm.enabled = true; alarm.weekdays = []
            alarm.sounds = AlarmSound.defaultIds; alarm.shakeToSnooze = true
            data.nightlyAlarm = alarm
        }
    }

    func change`);
s=s.replace('    func cleanExpiredClips(now: Date = Date()) {','    func cleanExpiredClips(now: Date = Date()) {\n        guard data.retentionDays > 0 else { return }');
fs.writeFileSync(dir+'SleepStore.swift',s);
s=fs.readFileSync(dir+'NightEngine.swift','utf8');
s='import UIKit\n'+s;
s=s.replace('    private var starting = false',`    private var starting = false
    @Published var motionProgress = 0.0
    @Published private(set) var lightLevel = 0.0
    private var previousBrightness: CGFloat?
    private var previousIdleTimer: Bool?
    private let classificationQueue = DispatchQueue(label: "Alarma.clipClassification", qos: .utility)
    func configure(store: SleepStore, scheduler: ReminderScheduler) { self.store = store; self.scheduler = scheduler }
    var isActive: Bool { phase != .idle }
    var activeAlarm: WakeAlarm? { store?.data.activeNight?.alarm }
    var ringingAlarm: WakeAlarm? { phase == .ringing || phase == .snoozing ? activeAlarm : nil }
    var isSnoozing: Bool { phase == .snoozing }
    var snoozedUntil: Date? { isSnoozing ? wakeAt : nil }
    func start(alarm: WakeAlarm, dreamStore: DreamStore, recordAudio: Bool, soundRetentionDays: Int?) {
        guard let scheduler else { return }
        Task { await start(alarm: alarm, store: dreamStore.store, scheduler: scheduler) }
    }
    func stop() { finish() }
    private func restoreDisplay() {
        if let previousBrightness { UIScreen.main.brightness = previousBrightness }
        if let previousIdleTimer { UIApplication.shared.isIdleTimerDisabled = previousIdleTimer }
        previousBrightness = nil; previousIdleTimer = nil; lightLevel = 0
    }`);
s=s.replace('            phase = .sleeping;',`            previousBrightness = UIScreen.main.brightness
            previousIdleTimer = UIApplication.shared.isIdleTimerDisabled
            if alarm.lightWakeEnabled { UIApplication.shared.isIdleTimerDisabled = true }
            phase = .sleeping;`);
s=s.replace('        if phase == .ringing {\n            let fade',`        if phase == .ringing {
            if active.alarm.lightWakeEnabled {
                lightLevel = min(1, now.timeIntervalSince(ringStarted) / Double(max(1, active.alarm.lightWakeMinutes) * 60))
                UIScreen.main.brightness = max(previousBrightness ?? 0, CGFloat(lightLevel))
            }
            let fade`);
s=s.replace('                    if self.shakeSamples >= 2', '                    self.motionProgress = min(1, Double(self.shakeSamples) / 2)\n                    if self.shakeSamples >= 2');
s=s.replace('        phase = .snoozing\n        motion.', '        phase = .snoozing\n        lightLevel = 0; motionProgress = 0\n        if let previousBrightness { UIScreen.main.brightness = previousBrightness }\n        motion.');
s=s.replace('        timer?.invalidate(); timer = nil','        restoreDisplay(); motionProgress = 0\n        timer?.invalidate(); timer = nil');
s=s.replace('await scheduler.sync(store.data.alarms)','await scheduler.sync([])');
s=s.replace('Bundle.main.url(forResource: name, withExtension: "wav")','SleepStore.soundURL(name)');
s=s.replace('        let sound = active.alarm.chooseSound(previous: store.data.lastSound)',`        var playable = active.alarm
        playable.sounds = playable.sounds.filter { SleepStore.soundURL($0) != nil }
        let sound = playable.chooseSound(previous: store.data.lastSound)`);
s=s.replace('            clipCount += 1',`            clipCount += 1
            classificationQueue.async {
                let kind = ClipClassifier.classify(url: url)
                Task { @MainActor in store.setClipKind(id: clip.id, kind: kind) }
            }`);
fs.writeFileSync(dir+'NightEngine.swift',s);
let p=fs.readFileSync('sleep-native/Info.plist','utf8');
p=p.replace('<key>LSRequiresIPhoneOS</key>', '<key>CFBundleDevelopmentRegion</key><string>en</string>\n<key>CFBundleLocalizations</key><array><string>en</string><string>es</string></array>\n<key>NSHealthShareUsageDescription</key><string>Show sleep stages already recorded in Apple Health in your sleep journal.</string>\n<key>LSRequiresIPhoneOS</key>');
fs.writeFileSync('sleep-native/Info.plist',p);
fs.writeFileSync('sleep-native/AlarmaSleep.entitlements','<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>com.apple.developer.healthkit</key><true/></dict></plist>');
p=fs.readFileSync('sleep-native/project.yml','utf8').replace("MARKETING_VERSION: '0.1'","MARKETING_VERSION: '0.2'").replace('        INFOPLIST_FILE: Info.plist','        INFOPLIST_FILE: Info.plist\n        CODE_SIGN_ENTITLEMENTS: AlarmaSleep.entitlements');fs.writeFileSync('sleep-native/project.yml',p);
p=fs.readFileSync('.github/workflows/sleep-native.yml','utf8').replaceAll('0.1-build','0.2-build');fs.writeFileSync('.github/workflows/sleep-native.yml',p);
