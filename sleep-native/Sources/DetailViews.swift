import SwiftUI
import Charts

struct AlarmEditor: View {
    @EnvironmentObject private var store: SleepStore
    @EnvironmentObject private var engine: NightEngine
    @EnvironmentObject private var reminders: ReminderScheduler
    @Environment(\.dismiss) private var dismiss
    @State var alarm: WakeAlarm
    @State private var deleting = false
    @State private var saving = false
    @FocusState private var nameFocused: Bool
    private var time: Binding<Date> {
        Binding(get: { Calendar.current.date(from: DateComponents(hour: alarm.hour, minute: alarm.minute)) ?? Date() }, set: { value in
            alarm.hour = Calendar.current.component(.hour, from: value)
            alarm.minute = Calendar.current.component(.minute, from: value)
        })
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Wake-up time", selection: time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel).labelsHidden().frame(maxWidth: .infinity)
                    TextField("Alarm name", text: $alarm.name).focused($nameFocused)
                        .onChange(of: alarm.name) { alarm.name = String($0.prefix(40)) }
                }
                Section("Repeat") {
                    ForEach(WakeAlarm.days, id: \.0) { day in
                        Toggle(day.1, isOn: Binding(get: { alarm.weekdays.contains(day.0) }, set: { enabled in
                            if enabled { alarm.weekdays.insert(day.0) } else { alarm.weekdays.remove(day.0) }
                        }))
                    }
                }
                Section {
                    ForEach(SoundChoice.all) { sound in
                        HStack(spacing: 14) {
                            Button { engine.playPreview(sound.id) } label: {
                                Image(systemName: engine.previewID == sound.id ? "stop.circle.fill" : "play.circle")
                                    .font(.title2).frame(width: 44, height: 44)
                            }.buttonStyle(.borderless).accessibilityLabel("Preview \(sound.title)")
                            Toggle(isOn: Binding(get: { alarm.sounds.contains(sound.id) }, set: { selected in
                                if selected { alarm.sounds.append(sound.id) }
                                else if alarm.sounds.count > 1 { alarm.sounds.removeAll { $0 == sound.id } }
                            })) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(sound.title)
                                    Text(sound.subtitle).font(.caption).foregroundStyle(Palette.muted)
                                }
                            }
                        }
                    }
                    Toggle("Shuffle selected sounds", isOn: $alarm.shuffle)
                } header: { Text("Wake-up sounds") } footer: { Text("Keep at least one sound selected. Shuffle avoids the last sound when possible.") }
                Section("Gentle wake-up") {
                    Picker("Volume fade-in", selection: $alarm.fadeSeconds) {
                        Text("Off").tag(0); Text("30 seconds").tag(30); Text("1 minute").tag(60); Text("3 minutes").tag(180)
                    }
                    Picker("Snooze", selection: $alarm.snoozeMinutes) {
                        ForEach([3,5,10,15], id: \.self) { Text("\($0) minutes").tag($0) }
                    }
                    Toggle("Shake to snooze", isOn: $alarm.shakeToSnooze)
                    Text("Fade-in and shake-to-snooze apply during an active night. The iPhone's media volume determines the maximum loudness.")
                        .font(.caption).foregroundStyle(Palette.muted)
                }
                if store.data.alarms.contains(where: { $0.id == alarm.id }) {
                    Section { Button("Delete alarm", role: .destructive) { deleting = true } }
                }
            }.scrollContentBackground(.hidden).background(Palette.background)
                .scrollDismissesKeyboard(.interactively)
                .navigationTitle("Your morning").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            nameFocused = false; saving = true
                            alarm.name = alarm.name.trimmingCharacters(in: .whitespacesAndNewlines)
                            if alarm.name.isEmpty { alarm.name = "Morning" }
                            store.saveAlarm(alarm)
                            Task {
                                if alarm.enabled { _ = await reminders.requestPermission() }
                                await reminders.sync(store.data.alarms)
                                saving = false
                                if store.error == nil { dismiss() }
                            }
                        }.disabled(saving)
                    }
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { nameFocused = false } }
                }
                .confirmationDialog("Delete this alarm?", isPresented: $deleting, titleVisibility: .visible) {
                    Button("Delete alarm", role: .destructive) {
                        store.change { $0.alarms.removeAll { $0.id == alarm.id } }
                        Task { await reminders.sync(store.data.alarms) }
                        if store.error == nil { dismiss() }
                    }
                }.onDisappear { engine.stopPreview() }
        }
    }
}

struct ActiveNightView: View {
    @EnvironmentObject private var engine: NightEngine
    @EnvironmentObject private var store: SleepStore
    @State private var confirmingEnd = false
    @State private var snoozing = false
    let finish: () -> Void
    private var ringing: Bool { engine.phase == .ringing }
    var body: some View {
        ZStack {
            NightLandscape()
            VStack(spacing: 22) {
                Spacer()
                Image(systemName: ringing ? "sun.horizon" : "moon.zzz").font(.system(size: 40, weight: .ultraLight)).foregroundStyle(Palette.gold)
                Text(ringing ? "Hello, new day." : engine.phase == .snoozing ? "A little more rest." : "Nothing to do. Just rest.")
                    .font(.system(size: 28, design: .serif)).multilineTextAlignment(.center)
                Text(engine.now, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                    .font(.system(size: 76, weight: .ultraLight, design: .rounded)).monospacedDigit()
                if let wake = engine.wakeAt {
                    Label("Wake-up \(wake.formatted(date: .omitted, time: .shortened))", systemImage: "alarm")
                        .font(.subheadline).foregroundStyle(Palette.gold)
                }
                if engine.recording {
                    Label("Sound clips stay on this iPhone", systemImage: "mic.fill").font(.caption).foregroundStyle(Palette.muted)
                }
                Spacer()
                if ringing {
                    GoldButton(title: "Snooze · \(store.data.activeNight?.alarm.snoozeMinutes ?? 5) min", symbol: "zzz") {
                        snoozing = true
                        Task { await engine.snooze(); snoozing = false }
                    }.disabled(snoozing)
                    Button("I'm awake") { finish() }.font(.headline).padding(18).foregroundStyle(.white)
                } else {
                    Text("You can lock your iPhone. Keep Alarma running.")
                        .font(.caption).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                    Button("End this night") { confirmingEnd = true }
                        .font(.subheadline).padding(18).frame(maxWidth: .infinity)
                        .background(.white.opacity(0.07), in: Capsule()).foregroundStyle(.white)
                }
            }.padding(30).padding(.bottom, 20)
        }.interactiveDismissDisabled()
            .confirmationDialog("End your night and stop its alarm?", isPresented: $confirmingEnd, titleVisibility: .visible) {
                Button("End night", role: .destructive) { finish() }
            }
    }
}

struct JournalView: View {
    @EnvironmentObject private var store: SleepStore
    @State private var selected: NightEntry?
    private var recent: [NightEntry] { Array(store.data.entries.prefix(7).reversed()) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    Text("A little closer\nto your nights.").font(.system(size: 33, design: .serif)).padding(.top, 12)
                    Text("Your own record of rest.").foregroundStyle(Palette.muted)
                    if store.data.entries.isEmpty {
                        Card {
                            VStack(alignment: .leading, spacing: 18) {
                                Image(systemName: "book.closed").font(.largeTitle).foregroundStyle(Palette.gold)
                                Text("A fresh page for tomorrow.").font(.title3)
                                Text("Start a night from Tonight. In the morning, add how you feel and anything you remember.")
                                    .foregroundStyle(Palette.muted).font(.subheadline).lineSpacing(4)
                            }.padding(.vertical, 20)
                        }
                    } else {
                        Card {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("RECENT NIGHTS").font(.caption).tracking(2).foregroundStyle(Palette.gold)
                                Chart(recent) { entry in
                                    BarMark(x: .value("Night", entry.endedAt, unit: .day), y: .value("Hours recorded", entry.duration / 3600))
                                        .foregroundStyle(Palette.gold.gradient).cornerRadius(5)
                                }.frame(height: 150).chartYAxis { AxisMarks(position: .leading) }
                                Text("Recorded session time, not measured sleep stages.").font(.caption).foregroundStyle(Palette.muted)
                            }
                        }
                        ForEach(store.data.entries) { entry in
                            Button { selected = entry } label: {
                                Card {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(entry.endedAt, format: .dateTime.weekday(.wide).month(.abbreviated).day()).font(.subheadline)
                                            Text(entry.interrupted ? "Interrupted session" : entry.mood?.title ?? "How did you wake up?").font(.caption).foregroundStyle(Palette.muted)
                                        }
                                        Spacer()
                                        Text(entry.durationText).font(.title3).foregroundStyle(Palette.gold)
                                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.muted)
                                    }
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                }.padding(24)
            }.background(Palette.background).navigationTitle("Journal").navigationBarTitleDisplayMode(.inline)
                .sheet(item: $selected) { entry in EntryEditor(entry: entry) }
        }
    }
}

struct EntryEditor: View {
    @EnvironmentObject private var store: SleepStore
    @EnvironmentObject private var engine: NightEngine
    @Environment(\.dismiss) private var dismiss
    @State var entry: NightEntry
    @State private var deleting = false
    @FocusState private var notesFocused: Bool
    var body: some View {
        NavigationStack {
            Form {
                Section("Your night") {
                    LabeledContent("Recorded time", value: entry.durationText)
                    LabeledContent("Started", value: entry.startedAt.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Ended", value: entry.endedAt.formatted(date: .abbreviated, time: .shortened))
                    if entry.interrupted { Text("This session was interrupted. Its duration ends at the last recorded checkpoint.").font(.caption).foregroundStyle(Palette.gold) }
                }
                Section("How do you feel?") {
                    HStack {
                        ForEach(WakeMood.allCases) { mood in
                            Button { entry.mood = mood } label: {
                                VStack(spacing: 10) { Image(systemName: mood.symbol).font(.title2); Text(mood.title).font(.caption) }
                                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                                    .foregroundStyle(entry.mood == mood ? Palette.background : Palette.gold)
                                    .background(entry.mood == mood ? Palette.gold : Palette.card, in: RoundedRectangle(cornerRadius: 15))
                            }.buttonStyle(.plain).accessibilityAddTraits(entry.mood == mood ? .isSelected : [])
                        }
                    }.listRowBackground(Color.clear)
                }
                Section("Dreams & notes") {
                    TextEditor(text: $entry.notes).frame(minHeight: 140).focused($notesFocused)
                        .accessibilityLabel("Dreams and notes")
                        .onChange(of: entry.notes) { entry.notes = String($0.prefix(10000)) }
                }
                Section {
                    if entry.clips.isEmpty { Text("No sound clips saved for this night.").foregroundStyle(Palette.muted) }
                    ForEach(entry.clips) { clip in
                        HStack {
                            Button {
                                engine.playPreview(clip.id.uuidString, url: SleepStore.clipsDirectory.appendingPathComponent(clip.fileName))
                            } label: {
                                Label("\(clip.date.formatted(date: .omitted, time: .shortened)) · \(Int(clip.seconds))s",
                                      systemImage: engine.previewID == clip.id.uuidString ? "stop.circle.fill" : "play.circle")
                            }.buttonStyle(.borderless)
                            Spacer()
                            Button(role: .destructive) {
                                engine.stopPreview()
                                store.deleteClip(clip, entryID: entry.id)
                                if store.error == nil { entry.clips.removeAll { $0.id == clip.id } }
                            } label: { Image(systemName: "trash").padding(10) }.buttonStyle(.borderless).accessibilityLabel("Delete sound clip")
                        }
                    }
                } header: { Text("Night sounds") } footer: { Text("Clips are triggered by louder sounds. They are not classified as snoring, breathing or speech.") }
                Section { Button("Delete this night", role: .destructive) { deleting = true } }
            }.scrollContentBackground(.hidden).background(Palette.background).scrollDismissesKeyboard(.interactively)
                .navigationTitle("Your night").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { notesFocused = false; store.saveEntry(entry); if store.error == nil { dismiss() } } }
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { notesFocused = false } }
                }
                .confirmationDialog("Delete this night and its sound clips?", isPresented: $deleting, titleVisibility: .visible) {
                    Button("Delete night", role: .destructive) { store.deleteEntry(entry); if store.error == nil { dismiss() } }
                }.onDisappear { engine.stopPreview() }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: SleepStore
    @EnvironmentObject private var reminders: ReminderScheduler
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Record night sounds", isOn: Binding(get: { store.data.recordSounds }, set: { enabled in store.change { $0.recordSounds = enabled } }))
                    Picker("Delete clips after", selection: Binding(get: { store.data.retentionDays }, set: { days in
                        store.change { $0.retentionDays = days }; store.cleanExpiredClips()
                    })) {
                        Text("1 day").tag(1); Text("7 days").tag(7); Text("30 days").tag(30)
                    }
                } header: { Text("Night sounds") } footer: {
                    Text("Off by default. Microphone permission is requested when starting a night with recording enabled. Up to 120 short clips per night are stored on your iPhone. Expired clips are removed when you use the app.")
                }
                Section("Wake-up reminders") {
                    LabeledContent("Notifications", value: reminders.authorized ? "Enabled" : "Not enabled")
                    Button("Open iPhone settings") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
                    Text("Start a night for continuous audio. Backup reminders use the iPhone's notification sound and respect Silent mode and Focus. Test volume before relying on an alarm.")
                        .font(.caption).foregroundStyle(Palette.muted)
                }
                Section("Made for quieter nights") {
                    Label("Stored on this iPhone", systemImage: "iphone")
                    Label("No account or analytics", systemImage: "lock.shield")
                    Text("Alarma records time spent in an active night session and your own notes. It does not measure sleep stages or diagnose sleep conditions.")
                        .font(.subheadline).foregroundStyle(Palette.muted)
                    LabeledContent("Version", value: "0.1 (1)")
                }
            }.scrollContentBackground(.hidden).background(Palette.background)
                .navigationTitle("Settings")
        }
    }
}
