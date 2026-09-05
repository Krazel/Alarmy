import SwiftUI

@main
struct AlarmaSleepApp: App {
    @StateObject private var store = SleepStore()
    @StateObject private var engine = NightEngine()
    @StateObject private var reminders = ReminderScheduler()
    var body: some Scene {
        WindowGroup {
            SleepRootView()
                .environmentObject(store).environmentObject(engine).environmentObject(reminders)
                .preferredColorScheme(.dark)
                .tint(Palette.gold)
                .task {
                    store.recoverInterruptedNight()
                    store.expireOneShotAlarms()
                    store.cleanExpiredClips()
                    await reminders.refreshPermission()
                    if store.data.onboardingComplete { await reminders.sync(store.data.alarms) }
                }
        }
    }
}

enum Palette {
    static let background = Color(red: 0.025, green: 0.06, blue: 0.10)
    static let card = Color(red: 0.065, green: 0.105, blue: 0.15)
    static let gold = Color(red: 0.91, green: 0.77, blue: 0.52)
    static let muted = Color(red: 0.61, green: 0.69, blue: 0.76)
}

struct SleepRootView: View {
    @EnvironmentObject private var store: SleepStore
    @EnvironmentObject private var engine: NightEngine
    @EnvironmentObject private var reminders: ReminderScheduler
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = 0
    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            if !store.data.onboardingComplete {
                WelcomeView()
            } else {
                TabView(selection: $tab) {
                    TonightView().tabItem { Label("Tonight", systemImage: "moon.stars") }.tag(0)
                    JournalView().tabItem { Label("Journal", systemImage: "book.closed") }.tag(1)
                    SettingsView().tabItem { Label("Settings", systemImage: "slider.horizontal.3") }.tag(2)
                }
                .toolbarBackground(Palette.background, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
            }
        }
        .fullScreenCover(isPresented: Binding(get: { engine.phase != .idle }, set: { _ in })) {
            ActiveNightView { engine.finish(); tab = 1 }
        }
        .alert("Alarma", isPresented: Binding(get: { message != nil }, set: { if !$0 { clearMessages() } })) {
            Button("OK") { clearMessages() }
        } message: { Text(message ?? "") }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                engine.tick()
                store.expireOneShotAlarms()
                store.cleanExpiredClips()
                Task { await reminders.refreshPermission() }
            } else if phase == .background { engine.stopPreview() }
        }
    }
    private var message: String? { store.error ?? engine.error ?? reminders.error }
    private func clearMessages() { store.error = nil; engine.error = nil; reminders.error = nil }
}

struct NightLandscape: View {
    var body: some View {
        GeometryReader { proxy in
            Image("NightLandscape").resizable().scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height).clipped()
        }.ignoresSafeArea().accessibilityHidden(true)
    }
}

struct GoldButton: View {
    let title: String
    var symbol = "moon.zzz.fill"
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.headline)
                .frame(maxWidth: .infinity).padding(.vertical, 19)
                .foregroundStyle(Palette.background).background(Palette.gold, in: RoundedRectangle(cornerRadius: 22))
        }.buttonStyle(.plain)
    }
}

struct Card<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card.opacity(0.95), in: RoundedRectangle(cornerRadius: 25))
            .overlay(RoundedRectangle(cornerRadius: 25).stroke(.white.opacity(0.06)))
    }
}

struct WelcomeView: View {
    @EnvironmentObject private var store: SleepStore
    var body: some View {
        ZStack {
            NightLandscape()
            LinearGradient(colors: [.clear, Palette.background.opacity(0.95)], startPoint: .center, endPoint: .bottom).ignoresSafeArea()
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("A L A R M A").font(.caption.weight(.semibold)).tracking(3).foregroundStyle(Palette.gold)
                        Spacer(minLength: 60)
                        Text("A softer end.\nA gentler beginning.")
                            .font(.system(size: 42, weight: .regular, design: .serif)).fixedSize(horizontal: false, vertical: true)
                        Text("Make room for rest, wake to a sound you love, and keep a little record of your nights.")
                            .font(.body).foregroundStyle(Palette.muted).lineSpacing(5)
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Gentle wake-up sounds", systemImage: "sun.horizon")
                            Label("Your private night journal", systemImage: "book.closed")
                            Label("Optional sound clips, saved on iPhone", systemImage: "lock")
                        }.font(.subheadline)
                        GoldButton(title: "Make tonight yours", symbol: "arrow.right") { store.change { $0.onboardingComplete = true } }
                        Text("No account needed. Your nights stay with you.").font(.caption).foregroundStyle(Palette.muted).frame(maxWidth: .infinity)
                    }.padding(28).padding(.bottom, 12).frame(minHeight: geometry.size.height)
                }
            }
        }
    }
}
struct TonightView: View {
    @EnvironmentObject private var store: SleepStore
    @EnvironmentObject private var engine: NightEngine
    @EnvironmentObject private var reminders: ReminderScheduler
    @State private var editing: WakeAlarm?
    @State private var starting = false
    @State private var preparation = false
    @State private var pendingStart = false
    private var next: WakeAlarm? {
        store.data.alarms.filter { $0.enabled && $0.nextDate(after: Date()) != nil }.sorted {
            ($0.nextDate(after: Date()) ?? .distantFuture) < ($1.nextDate(after: Date()) ?? .distantFuture)
        }.first
    }
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                NightLandscape()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack {
                            VStack(alignment: .leading, spacing: 7) {
                                Text(Date(), format: .dateTime.weekday(.wide).month(.abbreviated).day()).font(.caption).textCase(.uppercase).tracking(2).foregroundStyle(Palette.muted)
                                Text("Rest starts here.").font(.system(size: 31, design: .serif))
                            }
                            Spacer()
                            Image(systemName: "moon.stars").font(.title2).foregroundStyle(Palette.gold)
                        }.padding(.top, 16)
                        VStack(spacing: 12) {
                            Text("YOUR NEXT MORNING").font(.caption2.weight(.semibold)).tracking(2.5).foregroundStyle(Palette.gold)
                            Button { editing = next ?? WakeAlarm() } label: {
                                Text(next?.timeText ?? "--:--")
                                    .font(.system(size: 84, weight: .ultraLight, design: .rounded)).monospacedDigit().minimumScaleFactor(0.65)
                                    .foregroundStyle(.white)
                            }.accessibilityLabel("Edit wake-up time \(next?.timeText ?? "not set")")
                            if let next {
                                HStack(spacing: 8) {
                                    Text(next.name); Text("·"); Text(next.repeatText)
                                    Image(systemName: "pencil").font(.caption2)
                                }.font(.subheadline).foregroundStyle(Palette.muted)
                            } else { Text("Add an alarm to plan your morning.").font(.subheadline).foregroundStyle(Palette.muted) }
                        }.frame(maxWidth: .infinity).padding(.vertical, 34)
                        VStack(spacing: 13) {
                            GoldButton(title: starting ? "Preparing your night…" : "Begin tonight") { preparation = true }
                                .disabled(next == nil || starting).opacity(next == nil ? 0.45 : 1)
                            Label("A quiet soundscape plays through the night", systemImage: "waveform")
                                .font(.caption).foregroundStyle(Palette.muted)
                        }
                        HStack {
                            Text("Your alarms").font(.title3.weight(.medium))
                            Spacer()
                            Button { editing = WakeAlarm() } label: { Image(systemName: "plus").padding(12).background(.white.opacity(0.08), in: Circle()) }
                                .accessibilityLabel("Add alarm").disabled(store.data.alarms.count >= 8)
                        }
                        ForEach(store.data.alarms) { alarm in
                            Card {
                                HStack {
                                    Button { editing = alarm } label: {
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(alarm.timeText).font(.system(size: 32, weight: .light, design: .rounded)).monospacedDigit()
                                            Text("\(alarm.name) · \(alarm.repeatText)").font(.caption).foregroundStyle(Palette.muted)
                                        }.foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading)
                                    }.buttonStyle(.plain)
                                    Toggle("Enable \(alarm.name)", isOn: Binding(get: { alarm.enabled }, set: { enabled in
                                        var updated = alarm; updated.enabled = enabled; store.saveAlarm(updated)
                                        Task {
                                            if enabled { _ = await reminders.requestPermission() }
                                            await reminders.sync(store.data.alarms)
                                        }
                                    })).labelsHidden().tint(Palette.gold)
                                }
                            }
                        }
                        if !reminders.authorized {
                            Button { Task { _ = await reminders.requestPermission(); await reminders.sync(store.data.alarms) } } label: {
                                Label("Enable backup notifications", systemImage: "bell.badge").font(.subheadline)
                            }.padding(.vertical, 6)
                        }
                        Text("On iOS 16, start a night for continuous wake-up audio. Outside a night, alarms are notification reminders and follow Silent mode and Focus.")
                            .font(.caption).foregroundStyle(Palette.muted).lineSpacing(3)
                    }.padding(24)
                }
            }.toolbar(.hidden, for: .navigationBar)
                .sheet(item: $editing) { alarm in AlarmEditor(alarm: alarm) }
                .sheet(isPresented: $preparation, onDismiss: {
                    engine.stopPreview()
                    guard pendingStart, let next else { return }
                    pendingStart = false; starting = true
                    Task { await engine.start(alarm: next, store: store, scheduler: reminders); starting = false }
                }) {
                    NavigationStack {
                        VStack(alignment: .leading, spacing: 24) {
                            Image(systemName: "moon.zzz").font(.largeTitle).foregroundStyle(Palette.gold)
                            Text("Settle in for the night.").font(.largeTitle.weight(.light))
                            Text("Keep Alarma running and connect your charger. You can lock your iPhone. A quiet soundscape keeps playing until your wake-up time.")
                            Text("Check your speaker and media volume. Calls, audio interruptions or force-closing Alarma can stop continuous audio; the backup notification follows your iPhone's sound and Focus settings.")
                                .font(.subheadline).foregroundStyle(Palette.muted)
                            Button { engine.playPreview("dawn") } label: { Label("Test wake-up sound", systemImage: "play.circle") }
                            Spacer()
                            GoldButton(title: "Start my night") {
                                pendingStart = true
                                preparation = false
                            }
                        }.padding(28).background(Palette.background).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { preparation = false } } }
                    }
                }
        }
    }
}
