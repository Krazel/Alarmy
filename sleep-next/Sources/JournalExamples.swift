import SwiftUI

enum JournalScenario: String, CaseIterable, Identifiable {
    case variedWeek, quiet, short, sounds, interrupted, empty
    var id: String { rawValue }
    var key: String { "example-" + rawValue }

    func archive(now: Date = Date(), words: Words, calendar: Calendar = .current) -> (AppArchive, Date) {
        var value = AppArchive()
        value.preferences.language = words.spanish ? "es" : "en"
        let day = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))!
        // Populate three weeks so the weekly strip and month can both be explored.
        for index in 0..<21 {
            let date = calendar.date(byAdding: .day, value: -index, to: day)!
            let end = calendar.date(bySettingHour: 7, minute: 30, second: 0, of: date)!
            let minutes = [485, 345, 420, 510, 390, 460, 435][index % 7]
            let start = end.addingTimeInterval(-Double(minutes)*60)
            value.sessions.append(SleepSession(id: UUID(), start: start, checkpoint: end, end: end, wake: end, alarmID: UUID(), soundID: "aurora"))
            value.pages[CalendarDay.key(date, calendar: calendar)] = JournalPage(feeling: MorningFeeling.allCases[index % 5], text: "")
        }
        let key = CalendarDay.key(day, calendar: calendar)
        switch self {
        case .variedWeek:
            value.pages[key] = JournalPage(feeling: .peaceful, text: words("exampleNoteCalm"))
        case .quiet:
            value.pages[key] = JournalPage(feeling: .bright, text: words("exampleNoteQuiet"))
        case .short:
            let end = value.sessions[0].end!
            value.sessions[0] = SleepSession(id: UUID(), start: end.addingTimeInterval(-4*3600-20*60), checkpoint: end, end: end, wake: end, alarmID: UUID(), soundID: "aurora")
            value.pages[key] = JournalPage(feeling: .exhausted, text: words("exampleNoteShort"))
        case .sounds:
            let start = value.sessions[0].start
            value.sessions[0].clips = SoundKind.allCases.enumerated().map { index, kind in
                var clip = NightClip(id: UUID(), created: start.addingTimeInterval(Double(index+1)*3600), filename: "example-\(index).demo", duration: Double([18,24,12,8,16][index]))
                clip.kind = kind; clip.analysisDone = true; clip.suggestion = true
                clip.analysisVersion = SoundTagger.version
                clip.events = [SoundEvent(start: 2, duration: 4, kind: kind, confidence: 0.8)]
                return clip
            }
            value.pages[key] = JournalPage(feeling: .steady, text: words("exampleNoteSounds"))
        case .interrupted:
            value.sessions[0].interrupted = true
            let start = value.sessions[0].start, end = value.sessions[0].end!
            value.sessions[0].captureSpans = [
                CaptureSpan(id: UUID(), start: start, end: start.addingTimeInterval(3*3600), reason: "recordInterrupted"),
                CaptureSpan(id: UUID(), start: start.addingTimeInterval(4*3600), end: end, reason: "recordPaused")
            ]
            value.pages[key] = JournalPage(feeling: .tired, text: words("exampleNoteInterrupted"))
        case .empty:
            value.sessions.removeFirst(); value.pages.removeValue(forKey: key)
        }
        return (value, day)
    }
}

struct JournalExamples: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var preview = SleepStore(journalPreview: true)
    @State private var scenario: JournalScenario = .variedWeek
    let language: String
    let appearance: String
    private var words: Words { Words(language: language) }
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(words("journalExamples")).font(.headline)
                    Spacer()
                    Button(words("done")) { dismiss() }.accessibilityIdentifier("close-journal-examples")
                }
                Picker(words("exampleScenario"), selection: $scenario) {
                    ForEach(JournalScenario.allCases) { Text(words($0.key)).tag($0) }
                }.pickerStyle(.menu).accessibilityIdentifier("example-scenario")
                Text(words("exampleOnly")).font(.caption).foregroundStyle(Color.ink.opacity(0.65))
            }.padding(20).background(Color.card)
            JournalScreen().environmentObject(preview)
        }.background(Color.paper).tint(.rust).foregroundStyle(Color.ink)
            .environment(\.locale, words.locale)
            .preferredColorScheme(appearance == "night" ? .dark : (appearance == "dawn" ? .light : nil))
            .onAppear { select() }
            .onChange(of: scenario) { _ in select() }
    }
    private func select() {
        let (archive, day) = scenario.archive(words: words)
        preview.archive = archive; preview.selectedDay = day; preview.loaded = true
    }
}
