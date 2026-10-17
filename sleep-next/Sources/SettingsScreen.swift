import SwiftUI
import UniformTypeIdentifiers

struct SoundScreen: View {
    @EnvironmentObject var store: SleepStore
    @Environment(\.dismiss) var dismiss
    @State private var importing = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PageHeading(title: store.words("music"))
                    Picker(store.words("music"), selection: Binding(get: { store.archive.plan.shuffled }, set: { value in store.plan { $0.shuffle = value; if !value { $0.sounds = [ $0.sounds.first ?? "aurora" ] } } })) {
                        Text(store.words("fixedSound")).tag(false); Text(store.words("randomSound")).tag(true)
                    }.pickerStyle(.segmented).accessibilityIdentifier("tone-play-mode")
                    Text(store.words("localTones")).font(.system(size: 22, design: .serif))
                    PaperCard(padding: 8) { VStack(spacing: 0) {
                        ForEach(ToneLibrary.builtins, id: \.self) { id in ToneRow(id: id, title: id.capitalized, audio: store.audio); if id != ToneLibrary.builtins.last { Divider().padding(.leading, 68) } }
                    } }
                    if !store.archive.tones.isEmpty {
                        Text(store.words("importedTones")).font(.system(size: 22, design: .serif))
                        PaperCard(padding: 8) { VStack { ForEach(store.archive.tones) { tone in ToneRow(id: tone.id, title: tone.name, audio: store.audio) } } }
                    }
                    Text(store.words("toneSelection")).font(.caption).foregroundStyle(.secondary)
                    Button { importing = true } label: { ReviewLink(title: store.words("import"), symbol: "square.and.arrow.down") }.buttonStyle(.plain)
                    ReviewNotice(text: store.words("importHint"))
                }.padding(20)
            }.background(Color.paper).foregroundStyle(Color.ink).tint(.rust).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(store.words("done")) { dismiss() } } }
                .fileImporter(isPresented: $importing, allowedContentTypes: [.audio]) { result in switch result { case .success(let url): Task { await store.importTone(url) }; case .failure(let error): store.error = error.localizedDescription } }
                .onDisappear { store.audio.stopPlayback() }
        }
    }
}
struct ToneRow: View {
    @EnvironmentObject var store: SleepStore
    let id: String; let title: String
    @ObservedObject var audio: NightAudio
    var body: some View {
        HStack(spacing: 12) {
            Group {
                if ToneLibrary.builtins.contains(id) { Image(id == "aurora" ? "DawnArtwork" : "NightBackground").resizable().scaledToFill() }
                else { Image(systemName: "music.note").font(.title2).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.rust.opacity(0.1)) }
            }.frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 10)).accessibilityHidden(true)
            Text(title).font(.system(size: 18, design: .serif)).foregroundStyle(Color.ink)
            Spacer(minLength: 0)
            Button {
                if audio.playing == id { audio.stopPlayback() }
                else if let url = ToneLibrary.url(id, imported: store.archive.tones) { do { try audio.play(url: url, id: id) } catch { store.error = error.localizedDescription } }
            } label: { Image(systemName: audio.playing == id ? "stop.circle" : "play.circle").font(.title2).frame(width: 40, height: 44) }.buttonStyle(.borderless).accessibilityLabel(store.words(audio.playing == id ? "stop" : "play") + " " + title)
            Button {
                store.plan { plan in
                    if !plan.shuffled { plan.sounds = [id] }
                    else if plan.sounds.contains(id) { if plan.sounds.count > 1 { plan.sounds.removeAll { $0 == id } } }
                    else { plan.sounds.append(id) }
                }
            } label: { Image(systemName: store.archive.plan.sounds.contains(id) ? "checkmark.circle.fill" : "circle").font(.title3).frame(width: 40, height: 44) }.buttonStyle(.borderless).accessibilityLabel(title).accessibilityValue(store.archive.plan.sounds.contains(id) ? "1" : "0")
        }.padding(8)
    }
}
struct SettingsScreen: View {
    @EnvironmentObject var store: SleepStore
    @State private var examples = false
    @State private var confirmErase = false
    var body: some View {
        NavigationStack {
            Form {
                Section { PageHeading(title: store.words("settings")) }.listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                Section {
                    Picker(store.words("appearance"), selection: Binding(get: { store.archive.preferences.appearance }, set: { value in store.preferences { $0.appearance = value } })) { ForEach(["auto", "dawn", "night"], id: \.self) { Text(store.words($0)).tag($0) } }.accessibilityIdentifier("appearance")
                    Picker(store.words("language"), selection: Binding(get: { store.archive.preferences.language }, set: { value in store.preferences { $0.language = value } })) { Text(store.words("system")).tag("system"); Text("Español").tag("es"); Text("English").tag("en") }.accessibilityIdentifier("language")
                    Toggle(store.words("openJournal"), isOn: Binding(get: { store.archive.preferences.openJournal }, set: { value in store.preferences { $0.openJournal = value } }))
                } header: { Text(store.words("yourExperience")).font(.system(size: 20, design: .serif)) }
                Section {
                    Stepper(value:Binding(get:{ store.archive.preferences.sleepGoalMinutes ?? 480 },set:{ value in store.preferences { $0.sleepGoalMinutes = value } }),in:180...720,step:15) { MetricRow(title:store.words("sleepGoal"),value:SleepMath.duration(Double(store.archive.preferences.sleepGoalMinutes ?? 480)*60)) }
                } footer: { Text(store.words("goalHint")) }
                Section {
                    Toggle(store.words("recordAndAnalyze"), isOn: Binding(get: { store.archive.preferences.analysisEnabled }, set: { value in store.preferences { $0.record = value; $0.analyze = value } })).accessibilityIdentifier("record-toggle")
                    Picker(store.words("sensitivity"), selection: Binding(get: { store.archive.preferences.sensitivity ?? 10 }, set: { value in store.preferences { $0.sensitivity = value } })) {
                        Text(store.words("sensitive")).tag(6.0); Text(store.words("normalSensitivity")).tag(10.0); Text(store.words("lessSensitive")).tag(14.0)
                    }
                    Picker(store.words("retention"), selection: Binding(get: { store.archive.preferences.keepDays }, set: { value in store.preferences { $0.keepDays = value }; Task { await store.prune(); await store.refreshRecordingUsage() } })) { Text(store.words("forever")).tag(0); ForEach([1,7,30,90], id: \.self) { Text("\($0) " + store.words("days")).tag($0) } }
                } header: { Text(store.words("audioPrivacy")).font(.system(size: 20, design: .serif)) } footer: { Text(store.words("recordAndAnalyzeHint")) }
                Section {
                    HStack {
                        Text(store.words("savedRecordings")); Spacer()
                        if let usage = store.recordingUsage { Text(ByteCountFormatter.string(fromByteCount:usage.bytes,countStyle:.file)).monospacedDigit().accessibilityIdentifier("recording-storage-size") }
                        else { ProgressView() }
                    }
                    if let usage = store.recordingUsage { Text("\(usage.count) " + store.words("savedClips")).font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("recording-storage-count") }
                    Button(role:.destructive) { confirmErase = true } label: { Text(store.words("deleteAllRecordings")) }
                        .accessibilityIdentifier("delete-all-recordings")
                        .disabled(store.deletingRecordings || store.archive.active != nil || store.recordingUsage?.filenames.isEmpty != false)
                    if store.deletingRecordings { ProgressView() }
                } header: { Text(store.words("storage")) } footer: { Text(store.words("recordingStorageHint")) }
                Section {
                    Button { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } } label: { Label(store.words("permissions"), systemImage: "arrow.up.right.square") }
                    DisclosureGroup(store.words("localEstimate")) { Text(store.words("localMethodHint")).font(.caption) }
                } header: { Text(store.words("information")).font(.system(size: 20, design: .serif)) }
                Section {
                    Text(store.words(WakeScheduler.systemAlarms ? "nativeInfo" : "fallbackInfo")).font(.subheadline)
                    if WakeScheduler.systemAlarms { Text(store.words("nativeExtra")).font(.caption).foregroundStyle(.secondary) }
                } header: { Text(store.words("reliability")) }
                Section {
                    Label(store.words("local"), systemImage: "lock.shield")
                    Text(store.words("localHint")).font(.caption).foregroundStyle(.secondary)
                } footer: { Text(store.words("about") + " · " + (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")) }
                Section {
                    Toggle(store.words("developerMode"), isOn: $store.developerMode).accessibilityIdentifier("developer-mode")
                    if store.developerMode {
                        Button { examples = true } label: { Label(store.words("journalExamples"), systemImage: "flask") }
                    }
                } header: { Text(store.words("designExamples")) } footer: { Text(store.words("exampleOnly")) }
            }.scrollContentBackground(.hidden).background(Color.paper).navigationBarTitleDisplayMode(.inline).toolbarBackground(.visible, for: .tabBar)
                .task { await store.refreshRecordingUsage() }
                .alert(store.words("deleteAllRecordings"),isPresented:$confirmErase) {
                    Button(store.words("deleteAllRecordings"),role:.destructive) { Task { await store.deleteAllRecordings() } }
                    Button(store.words("cancel"),role:.cancel) {}
                } message: { Text(store.words("deleteRecordingsConfirm")) }
                .sheet(isPresented: $examples) { JournalExamples(language: store.archive.preferences.language, appearance: store.archive.preferences.appearance) }
        }
    }
}
