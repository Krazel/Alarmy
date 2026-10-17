#if DEBUG
import SwiftUI

// Simulator-only catalogue. Never available in a release build or normal launch.
enum DesignCapture {
    static var route: String? {
        guard ProcessInfo.processInfo.arguments.contains("--ui-test") else { return nil }
        return ProcessInfo.processInfo.arguments.first(where: {$0.hasPrefix("--gallery=")}).map {String($0.dropFirst(10))}
    }
}
struct DesignCaptureScreen: View {
    @EnvironmentObject var store: SleepStore
    let route: String
    private var nights: [SleepSession] {store.sessions(store.selectedDay)}
    var body: some View {
        content.tint(.rust).foregroundStyle(Color.ink).accessibilityIdentifier("design-capture-ready").task {
            store.archive.preferences.appearance = ["home-night", "night", "ringing"].contains(route) ? "night" : "dawn"
            if ["night", "ringing", "active-editor"].contains(route) {
                let now = Date(), wake = now.addingTimeInterval(8*3600)
                store.archive.active = SleepSession(id:UUID(),start:now,checkpoint:now,wake:wake,alarmID:UUID(),soundID:"aurora")
                store.audio.waveform = (0..<64).map {0.5 + 0.2*sin(Double($0)*0.3)}
                store.ringing = route == "ringing"
            }
        }
    }
    @ViewBuilder private var content: some View {
        switch route {
        case "home", "home-night", "journal", "settings":
            TabView(selection:Binding(get: {route == "journal" ? 1 : (route == "settings" ? 2 : 0)},set:{_ in})) {
                AlarmScreen().tabItem {Label(store.words("alarm"),systemImage:"moon.stars")}.tag(0)
                JournalScreen().tabItem {Label(store.words("journal"),systemImage:"book.closed")}.tag(1)
                SettingsScreen().tabItem {Label(store.words("settings"),systemImage:"slider.horizontal.3")}.tag(2)
            }
        case "alarm-editor": AlarmEditor()
        case "tones": SoundScreen()
        case "night", "ringing": NightScreen()
        case "active-editor": ActiveAlarmEditor(date:Date().addingTimeInterval(8*3600))
        case "calendar": JournalCalendar(month:store.selectedDay)
        case "statistics": StatisticsScreen()
        case "details": NightDetails(ids:nights.map(\.id),stages:LocalSleepEstimator.stages(nights:nights))
        case "session-editor": if let night = nights.first {SessionEditor(night:night)}
        case "sounds": SoundsScreen(sessionIDs:nights.map(\.id))
        case "clip": if let clip = nights.flatMap(\.clips).first(where:{$0.kind == .cough}) {ClipDetail(clipID:clip.id,category:.cough,day:store.selectedDay,audio:store.audio)}
        case "compare": CompareNights(nights:store.archive.sessions,stages:Dictionary(uniqueKeysWithValues:store.archive.sessions.map {($0.id,LocalSleepEstimator.stages(night:$0))}))
        case "examples": JournalExamples(language:"es",appearance:"dawn")
        default: EmptyView()
        }
    }
}
#endif
