import SwiftUI
import UserNotifications

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
                .onChange(of: phase) { newValue in
                    if newValue == .active { Task { await store.resume() } }
                    else { store.audio.restoreScreen(); if store.archive.active == nil { store.audio.stopPlayback() } }
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
        .alert(store.words("error"), isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button(store.words("done")) { store.error = nil } } message: { Text(store.error ?? "") }
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
                                        Text(store.archive.plan.clock).font(.system(size: 70, weight: .light, design: .rounded)).monospacedDigit().minimumScaleFactor(0.7)
                                        Spacer(minLength: 5); Image(systemName: "slider.horizontal.3").font(.title3)
                                    }.foregroundStyle(Color.ink)
                                }.accessibilityIdentifier("edit-alarm")
                                HStack { Image(systemName: "sunrise"); Text(store.words("wake")); Spacer(); Text(store.archive.plan.next(after: Date()) ?? Date(), style: .date).lineLimit(1).minimumScaleFactor(0.7) }.font(.caption).foregroundStyle(Color.ink.opacity(0.65))
                                Divider()
                                Button { music = true } label: { HStack(spacing: 12) { Image(systemName: "waveform"); Text(store.words("sounds")); Spacer(); Text("\(store.archive.plan.sounds.count) " + store.words("selected")).font(.caption); Image(systemName: "chevron.right").font(.caption2) } }.font(.subheadline).foregroundStyle(Color.ink).accessibilityIdentifier("sounds")
                            }
                        }
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
            }.scrollContentBackground(.hidden).background(Color.paper).navigationTitle(store.words("edit")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(store.words("done")) { dismiss() } } }
        }
    }
}
struct NightScreen: View {
    @EnvironmentObject var store: SleepStore
    @State private var confirm = false
    var body: some View {
        ZStack {
            NightLandscape()
            VStack(spacing: 30) {
                Spacer()
                Image(systemName: store.ringing ? "sun.max" : "moon.stars").font(.system(size: 40, weight: .ultraLight))
                Text(store.words(store.ringing ? "morning" : "goodnight")).font(.system(size: 36, design: .serif))
                if let night = store.archive.active {
                    VStack(spacing: 10) { Text(store.words("until")).font(.caption2).tracking(3); Text(night.wake, style: .time).font(.system(size: 68, weight: .ultraLight, design: .rounded)).monospacedDigit() }
                    Label(store.words(store.audio.isRecording ? "recording" : "noRecording"), systemImage: store.audio.isRecording ? "waveform" : "moon").font(.caption).opacity(0.7)
                }
                Spacer()
                if store.ringing {
                    Button { Task { await store.snooze() } } label: { Text(store.words("snooze") + " · \(store.archive.plan.snoozeMinutes) min") }.buttonStyle(PrimaryButton())
                    Button(store.words("dismiss")) { Task { await store.finish() } }.padding()
                } else { Button(store.words("end")) { confirm = true }.font(.subheadline).padding(20).frame(maxWidth: .infinity).overlay(Capsule().stroke(.white.opacity(0.3))).accessibilityIdentifier("finish-night") }
            }.padding(32).padding(.bottom, 20).foregroundStyle(Color(red: 0.96, green: 0.92, blue: 0.83))
        }.preferredColorScheme(.dark).interactiveDismissDisabled().disabled(store.busy)
        .confirmationDialog(store.words("endTitle"), isPresented: $confirm, titleVisibility: .visible) {
            Button(store.words("end"), role: .destructive) { Task { await store.finish() } }
        } message: { Text(store.words("endHint")) }
    }
}
