import SwiftUI

@main
struct AlarmaSleepApp: App {
    @StateObject private var store: SleepStore
    @StateObject private var dreams: DreamStore
    @StateObject private var engine = NightEngine()
    @StateObject private var reminders = ReminderScheduler()
    @StateObject private var navigation = AppNavigation()
    init() {
        let bar = UITabBarAppearance()
        bar.configureWithOpaqueBackground()
        bar.backgroundColor = .secondarySystemBackground
        bar.stackedLayoutAppearance.normal.iconColor = .secondaryLabel
        bar.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.secondaryLabel]
        UITabBar.appearance().standardAppearance = bar
        UITabBar.appearance().scrollEdgeAppearance = bar
        UITabBar.appearance().unselectedItemTintColor = .secondaryLabel
        let value = SleepStore()
        L10n.language = value.language
        _store = StateObject(wrappedValue: value)
        _dreams = StateObject(wrappedValue: DreamStore(store: value))
    }
    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store).environmentObject(dreams).environmentObject(engine)
                .environmentObject(reminders).environmentObject(navigation)
                .environment(\.locale, L10n.locale)
                .preferredColorScheme(store.sleepTheme == .night ? .dark : .light)
                .task {
                    engine.configure(store: store, scheduler: reminders)
                    store.recoverInterruptedNight(); store.cleanExpiredClips()
                    await reminders.sync([])
                }
        }
    }
}

struct RootTabView: View {
    @EnvironmentObject private var store: SleepStore
    @EnvironmentObject private var engine: NightEngine
    @EnvironmentObject private var reminders: ReminderScheduler
    @EnvironmentObject private var navigation: AppNavigation
    @EnvironmentObject private var dreams: DreamStore
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        TabView(selection: $navigation.selectedTab) {
            ContentView().toolbarBackground(.visible, for: .tabBar).tabItem { Label(L("Alarmas"), systemImage: "alarm.fill") }.tag(AppTab.alarm)
            DreamJournalView().toolbarBackground(.visible, for: .tabBar).tabItem { Label(L("Diario"), systemImage: "book.closed.fill") }.tag(AppTab.journal)
            SettingsView().toolbarBackground(.visible, for: .tabBar).tabItem { Label(L("Ajustes"), systemImage: "gearshape.fill") }.tag(AppTab.settings)
        }
        .id(store.language)
        .tint(store.sleepTheme.primary)
        .alert(L("Alarma"), isPresented: Binding(get: { message != nil }, set: { if !$0 { clearErrors() } })) {
            Button(L("Entendido")) { clearErrors() }
        } message: { Text(message ?? "") }
        .onChange(of: store.language) { _ in dreams.healthMessage = nil }
        .onChange(of: navigation.selectedTab) { _ in engine.stopPreview() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { store.cleanExpiredClips(); Task { await reminders.refreshPermission(); await dreams.refreshHealth() } }
            else if engine.phase == .idle { engine.stopPreview() }
        }
    }
    private var message: String? { store.error ?? engine.error ?? reminders.error }
    private func clearErrors() { store.error = nil; engine.error = nil; reminders.error = nil }
}
