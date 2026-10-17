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
    @ViewBuilder private var appContent: some View {
        #if DEBUG
        if let route = DesignCapture.route {
            if store.loaded {DesignCaptureScreen(route:route)} else {ProgressView()}
        } else {RootScreen()}
        #else
        RootScreen()
        #endif
    }
    var body: some Scene {
        WindowGroup {
            appContent.environmentObject(store)
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
                    if newValue == .active { Task { await store.resume(); store.retryPendingClipAnalysis() } }
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
                if scheme == .dark { nightHome } else { ScrollView {
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
                        Button { Task { await store.start() } } label: { HStack { if store.busy { ProgressView() }; Image(systemName: "moon.zzz"); Text(store.words("start")) } }.buttonStyle(PrimaryButton()).disabled(store.busy).accessibilityIdentifier("begin-night")
                        Spacer(minLength: 160)
                    }.padding(.horizontal, 26)
                }.scrollIndicators(.hidden) }
            }.toolbar(.hidden, for: .navigationBar).toolbarBackground(.visible, for: .tabBar)
            .sheet(isPresented: $editor) { AlarmEditor() }
            .sheet(isPresented: $music) { SoundScreen() }
        }
    }
    private var nightHome: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 26) {
                    Text("Alarma").font(.system(size: 30, design: .serif)).frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: max(20, geo.size.height * 0.12))
                    Text(store.words("tonight")).font(.caption).tracking(2).opacity(0.75)
                    Button { editor = true } label: {
                        VStack(spacing: 12) {
                            Text(store.archive.plan.resolvedMode == .analysis ? store.words("analysis") : store.archive.plan.clock)
                                .font(.system(size: store.archive.plan.resolvedMode == .analysis ? 34 : 78, weight: .regular, design: .serif)).monospacedDigit()
                                .lineLimit(1).minimumScaleFactor(0.6)
                            HStack(spacing: 8) { Text(store.words(store.archive.plan.resolvedMode.rawValue)); Image(systemName: "chevron.down").font(.caption) }.font(.subheadline)
                        }.frame(maxWidth: .infinity).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("edit-alarm")
                    if store.archive.plan.resolvedMode != .analysis {
                        Button { music = true } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "music.note")
                                Text(store.archive.plan.shuffled ? store.words("randomSound") + " · \(store.archive.plan.sounds.count)" : toneName)
                                Image(systemName: "chevron.right").font(.caption2)
                            }.font(.subheadline).padding(14).background(.white.opacity(0.08), in: Capsule())
                        }.buttonStyle(.plain).accessibilityIdentifier("sounds")
                    }
                    Spacer(minLength: max(28, geo.size.height * 0.24))
                    Button { Task { await store.start() } } label: {
                        HStack { if store.busy { ProgressView() }; Text(store.words("start")) }
                            .font(.system(size: 18, design: .serif)).frame(maxWidth: .infinity).padding(.vertical, 20)
                            .background(.ultraThinMaterial, in: Capsule())
                    }.buttonStyle(.plain).disabled(store.busy).accessibilityIdentifier("begin-night")
                }.padding(26).frame(minHeight: geo.size.height)
            }.scrollIndicators(.hidden).foregroundStyle(Color(red: 0.96, green: 0.94, blue: 0.87))
        }
    }
    private var toneName: String {
        let id = store.archive.plan.sounds.first ?? "aurora"
        return store.archive.tones.first { $0.id == id }?.name ?? id.capitalized
    }

}
struct AlarmEditor: View {
    @EnvironmentObject var store: SleepStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = AlarmPlan()
    @State private var loaded = false
    private var time: Binding<Date> { Binding(get: { Calendar.current.date(bySettingHour: draft.hour, minute: draft.minute, second: 0, of: Date()) ?? Date() }, set: { draft.hour = Calendar.current.component(.hour, from: $0); draft.minute = Calendar.current.component(.minute, from: $0) }) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PageHeading(title: store.words("edit"))
                    PaperCard(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(AlarmMode.allCases, id: \.self) { mode in
                                Button { draft.mode = mode } label: {
                                    HStack(spacing: 15) {
                                        Image(systemName: draft.resolvedMode == mode ? "largecircle.fill.circle" : "circle").foregroundStyle(draft.resolvedMode == mode ? Color.rust : Color.ink.opacity(0.4))
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(store.words(mode.rawValue)).font(.system(size: 19, design: .serif))
                                            Text(store.words(mode == .analysis ? "modeAnalysisShort" : (mode == .smart ? "modeSmartShort" : "modeExactShort"))).font(.caption).foregroundStyle(Color.ink.opacity(0.6))
                                        }
                                        Spacer(minLength: 0)
                                    }.padding(18).contentShape(Rectangle())
                                }.buttonStyle(.plain).accessibilityIdentifier("alarm-mode-" + mode.rawValue).accessibilityAddTraits(draft.resolvedMode == mode ? .isSelected : [])
                                if mode != AlarmMode.allCases.last { Divider().padding(.leading, 18) }
                            }
                        }
                    }
                    if draft.resolvedMode != .analysis {
                        PaperCard(padding: 12) {
                            VStack(spacing: 8) {
                                DatePicker(store.words("wake"), selection: time, displayedComponents: .hourAndMinute).datePickerStyle(.wheel).labelsHidden()
                                if let next = draft.next(after: Date()) { Label(next.formatted(.dateTime.weekday(.wide).day().month().locale(store.words.locale)), systemImage: "calendar").font(.subheadline).padding(.bottom, 8) }
                            }
                        }
                        if draft.resolvedMode == .smart {
                            PaperCard(padding: 18) { VStack(alignment: .leading, spacing: 10) {
                                Picker(store.words("wakeWindow"), selection: Binding(get: { draft.window }, set: { draft.windowMinutes = $0 })) { ForEach([15,30,45,60], id: \.self) { Text("\($0) min").tag($0) } }
                                Text(store.words("latestWake")).font(.caption).foregroundStyle(.secondary)
                            } }
                        }
                        PaperCard(padding: 18) {
                            VStack(spacing: 16) {
                                Picker(selection: $draft.snoozeMinutes) { ForEach([1,3,5,10,15], id: \.self) { Text("\($0) min").tag($0) } } label: { Label(store.words("snoozeTime"), systemImage: "zzz") }
                                Divider()
                                Toggle(isOn: $draft.gradual) { Label(store.words("gentle"), systemImage: "speaker.wave.2") }
                                DisclosureGroup(store.words("moreOptions")) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text(store.words("gentleHint")).font(.caption)
                                        Toggle(store.words("motion"), isOn: $draft.motionSnooze)
                                        Text(store.words("motionHint")).font(.caption)
                                    }.padding(.top, 12)
                                }
                            }
                        }
                        ReviewNotice(text: store.words(WakeScheduler.systemAlarms ? "nativeExtra" : "fallbackInfo"))
                    } else { ReviewNotice(text: store.words("analysisHint")) }
                }.padding(20)
            }.background(Color.paper).foregroundStyle(Color.ink).tint(.rust)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(store.words("cancel")) { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button(store.words("save")) { draft.lightMinutes = 0; store.plan { $0 = draft }; dismiss() }.accessibilityIdentifier("save-alarm") }
                }.onAppear { if !loaded { draft = store.archive.plan; loaded = true } }
        }
    }
}
