import SwiftUI
import UserNotifications
import AVFoundation

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) { completionHandler([]) }
}
@main
struct AlarmaNextApp: App {
    @StateObject private var store = SleepStore()
    @Environment(\.scenePhase) private var phase
    private let notifications = NotificationDelegate()
    init() {
        UNUserNotificationCenter.current().delegate = notifications
        let bar = UITabBarAppearance(); bar.configureWithOpaqueBackground()
        bar.backgroundColor = UIColor(Color.paper)
        bar.stackedLayoutAppearance.normal.iconColor = .secondaryLabel
        bar.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.secondaryLabel]
        UITabBar.appearance().standardAppearance = bar; UITabBar.appearance().scrollEdgeAppearance = bar
    }
    var body: some Scene {
        WindowGroup {
            RootScreen().environmentObject(store)
                .environment(\.locale, store.words.locale)
                .preferredColorScheme(store.archive.preferences.appearance == "night" ? .dark : (store.archive.preferences.appearance == "dawn" ? .light : nil))
                .task { await store.load() }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("WakeDismissed"))) { _ in Task { await store.resume() } }
                .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { notification in
                    if let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt {
                        let options = (notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt) ?? 0
                        Task { await store.interruption(began: raw == AVAudioSession.InterruptionType.began.rawValue, shouldResume: AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume)) }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { note in
                    let raw = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt) ?? 0
                    if store.audio.isRecording && [1,2,7].contains(raw) { Task { await store.pauseCapture(reason: "recordRoute") } }
                }
                .onReceive(NotificationCenter.default.publisher(for: .AVAudioEngineConfigurationChange)) { _ in
                    if store.audio.needsRebuild { Task { await store.pauseCapture(reason: "recordRoute") } }
                }
                .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.mediaServicesWereResetNotification)) { _ in
                    Task { await store.pauseCapture(reason: "recordReset") }
                }
                .onChange(of: phase) { newValue in
                    if newValue == .active { Task { await store.resume() } }
                    else { Task { await store.flush() }; store.audio.restoreScreen(); if store.archive.active == nil { store.audio.stopPlayback() } }
                }
        }
    }
}
struct RootScreen: View {
    @EnvironmentObject var store: SleepStore
    var body: some View {
        Group {
            if !store.loaded { ProgressView() }
            else if store.failed { VStack(spacing: 20) { Image(systemName: "externaldrive.badge.exclamationmark").font(.largeTitle); Text(store.words("storageError")) }.padding(32) }
            else {
                TabView(selection: $store.tab) {
                    AlarmScreen().tabItem { Label(store.words("alarm"), systemImage: "moon.stars") }.tag(0)
                    JournalScreen().tabItem { Label(store.words("journal"), systemImage: "book.closed") }.tag(1)
                    SettingsScreen().tabItem { Label(store.words("settings"), systemImage: "slider.horizontal.3") }.tag(2)
                }.id(store.archive.preferences.language)
            }
        }.tint(.rust).foregroundStyle(Color.ink)
        .alert(store.words("error"), isPresented: Binding(get: { store.error != nil && store.archive.active == nil && !store.clipPresented }, set: { if !$0 && store.archive.active == nil && !store.clipPresented { store.error = nil } })) {
            if store.writeFailed { Button(store.words("retrySave")) { Task { await store.retrySaving() } } }
            Button(store.words("done")) { store.error = nil }
        } message: { Text(store.error ?? "") }
        .fullScreenCover(isPresented: Binding(get: { store.archive.active != nil }, set: { _ in })) { NightScreen().environmentObject(store).environment(\.locale, store.words.locale) }
    }
}
struct AlarmScreen: View {
    @EnvironmentObject var store: SleepStore
    @Environment(\.colorScheme) private var scheme
    @State private var editor = false
    @State private var music = false
    var body: some View {
        NavigationStack {
            ZStack {
                if scheme == .dark { NightLandscape() } else { GeometryReader { geo in Image("DawnArtwork").resizable().scaledToFill().frame(width: geo.size.width, height: geo.size.height).clipped() }.ignoresSafeArea() }
                ScrollView {
                    VStack(alignment: .leading, spacing: 25) {
                        HStack { Text("Alarma").font(.system(size: 34, weight: .regular, design: .serif)); Spacer(); Image(systemName: scheme == .dark ? "moon.stars" : "sun.horizon").font(.title3) }.padding(.top, 18)
                        Text(store.words("rest")).font(.system(size: 25, weight: .regular, design: .serif)).lineSpacing(3).padding(.top, 25)
                        PaperCard(padding: 26) {
                            VStack(alignment: .leading, spacing: 18) {
                                Eyebrow(text: store.words("tonight"))
                                Button { editor = true } label: {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(store.archive.plan.resolvedMode == .analysis ? store.words("analysis") : store.archive.plan.clock).font(.system(size: store.archive.plan.resolvedMode == .analysis ? 32 : 70, weight: .light, design: .rounded)).monospacedDigit().minimumScaleFactor(0.7)
                                        Spacer(minLength: 5); Image(systemName: "slider.horizontal.3").font(.title3)
                                    }.foregroundStyle(Color.ink)
                                }.accessibilityIdentifier("edit-alarm")
                                Text(store.words(store.archive.plan.resolvedMode.rawValue)).font(.subheadline)
                                if store.archive.plan.resolvedMode != .analysis {
                                HStack { Image(systemName: "sunrise"); Text(store.words("wake")); Spacer(); Text(store.archive.plan.next(after: Date()) ?? Date(), style: .date).lineLimit(1).minimumScaleFactor(0.7) }.font(.caption).foregroundStyle(Color.ink.opacity(0.65))
                                if store.archive.plan.resolvedMode == .smart { Text("\(store.archive.plan.window) min · " + store.words("windowBefore")).font(.caption) }
                                Divider()
                                Button { music = true } label: { HStack(spacing: 12) { Image(systemName: "waveform"); Text(store.words("sounds")); Spacer(); Text("\(store.archive.plan.sounds.count) " + store.words("selected")).font(.caption); Image(systemName: "chevron.right").font(.caption2) } }.font(.subheadline).foregroundStyle(Color.ink).accessibilityIdentifier("sounds")
                                }
                            }
                        }
                        Toggle(store.words("analyzeSounds"), isOn: Binding(get: { store.archive.preferences.analysisEnabled }, set: { value in store.preferences { $0.analyze = value } })).font(.subheadline).padding(16).background(Color.card.opacity(0.95), in: RoundedRectangle(cornerRadius: 18))
                        Toggle(isOn: Binding(get: { store.archive.preferences.record }, set: { value in store.preferences { $0.record = value } })) {
                            Label(store.words("record"), systemImage: "mic")
                        }.font(.subheadline).padding(16).background(Color.card.opacity(0.95), in: RoundedRectangle(cornerRadius: 18)).accessibilityIdentifier("record-toggle").disabled(!store.archive.preferences.analysisEnabled)
                        Button { Task { await store.start() } } label: { HStack { if store.busy { ProgressView() }; Image(systemName: "moon.zzz"); Text(store.words("start")) } }.buttonStyle(PrimaryButton()).disabled(store.busy).accessibilityIdentifier("begin-night")
                        Spacer(minLength: 160)
                    }.padding(.horizontal, 26)
                }.scrollIndicators(.hidden)
            }.toolbar(.hidden, for: .navigationBar).toolbarBackground(.visible, for: .tabBar)
            .sheet(isPresented: $editor) { AlarmEditor() }
            .sheet(isPresented: $music) { SoundScreen() }
        }
    }
}
struct AlarmEditor: View {
    @EnvironmentObject var store: SleepStore
    @Environment(\.dismiss) var dismiss
    private var time: Binding<Date> { Binding(get: { Calendar.current.date(bySettingHour: store.archive.plan.hour, minute: store.archive.plan.minute, second: 0, of: Date()) ?? Date() }, set: { date in store.plan { $0.hour = Calendar.current.component(.hour, from: date); $0.minute = Calendar.current.component(.minute, from: date) } }) }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(store.words("alarmMode"), selection: Binding(get: { store.archive.plan.resolvedMode }, set: { value in store.plan { $0.mode = value } })) {
                        ForEach(AlarmMode.allCases, id: \.self) { Text(store.words($0.rawValue)).tag($0) }
                    }.pickerStyle(.inline).accessibilityIdentifier("alarm-mode")
                } footer: { Text(store.words(store.archive.plan.resolvedMode == .analysis ? "analysisHint" : (store.archive.plan.resolvedMode == .smart ? "smartHint" : "exactHint"))) }
                if store.archive.plan.resolvedMode != .analysis {
                if store.archive.plan.resolvedMode == .smart {
                    Picker(store.words("wakeWindow"), selection: Binding(get: { store.archive.plan.window }, set: { value in store.plan { $0.windowMinutes = value } })) {
                        ForEach([15,30,45,60], id: \.self) { Text("\($0) min").tag($0) }
                    }
                    Text(store.words("latestWake")).font(.caption)
                }
                DatePicker(store.words("wake"), selection: time, displayedComponents: .hourAndMinute).datePickerStyle(.wheel).labelsHidden()
                Section {
                    Toggle(store.words("gentle"), isOn: Binding(get: { store.archive.plan.gradual }, set: { value in store.plan { $0.gradual = value } }))
                    Picker(store.words("snoozeTime"), selection: Binding(get: { store.archive.plan.snoozeMinutes }, set: { value in store.plan { $0.snoozeMinutes = value } })) { ForEach([1,3,5,10,15], id: \.self) { Text("\($0) min").tag($0) } }
                    Toggle(store.words("motion"), isOn: Binding(get: { store.archive.plan.motionSnooze }, set: { value in store.plan { $0.motionSnooze = value } }))
                } footer: { Text(store.words("motionHint")) }
                Section {
                    Picker(store.words("light"), selection: Binding(get: { store.archive.plan.lightMinutes }, set: { value in store.plan { $0.lightMinutes = value } })) { Text(store.words("off")).tag(0); ForEach([3,5,10,15], id: \.self) { Text("\($0) min").tag($0) } }
                } footer: { Text(store.words("lightHint")) }
                Section { Text(store.words(WakeScheduler.systemAlarms ? "nativeExtra" : "fallbackInfo")).font(.footnote) }
                }
            }.scrollContentBackground(.hidden).background(Color.paper).navigationTitle(store.words("edit")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(store.words("done")) { dismiss() } } }
        }
    }
}
