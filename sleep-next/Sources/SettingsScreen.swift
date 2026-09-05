import SwiftUI
import UniformTypeIdentifiers

struct SoundScreen: View {
    @EnvironmentObject var store: SleepStore
    @Environment(\.dismiss) var dismiss
    @State private var importing = false
    var body: some View {
        NavigationStack {
            List {
                Section { ForEach(ToneLibrary.builtins, id: \.self) { id in ToneRow(id: id, title: id.capitalized, audio: store.audio) } } footer: { Text(store.words("soundHint")) }
                if !store.archive.tones.isEmpty { Section { ForEach(store.archive.tones) { tone in ToneRow(id: tone.id, title: tone.name, audio: store.audio) } } }
                Section { Button { importing = true } label: { Label(store.words("import"), systemImage: "square.and.arrow.down") } } footer: { Text(store.words("importHint")) }
            }.scrollContentBackground(.hidden).background(Color.paper).navigationTitle(store.words("sounds")).navigationBarTitleDisplayMode(.inline)
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
        HStack(spacing: 16) {
            Button {
                if audio.playing == id { audio.stopPlayback() }
                else if let url = ToneLibrary.url(id, imported: store.archive.tones) { do { try audio.play(url: url, id: id) } catch { store.error = error.localizedDescription } }
            } label: { Image(systemName: audio.playing == id ? "stop.circle" : "play.circle").font(.title2) }.buttonStyle(.borderless).accessibilityLabel(store.words(audio.playing == id ? "stop" : "play") + " " + title)
            Text(title).foregroundStyle(Color.ink)
            Spacer()
            Button {
                store.plan { plan in if plan.sounds.contains(id) { if plan.sounds.count > 1 { plan.sounds.removeAll { $0 == id } } } else { plan.sounds.append(id) } }
            } label: { Image(systemName: store.archive.plan.sounds.contains(id) ? "checkmark.circle.fill" : "circle").font(.title3) }.buttonStyle(.borderless).accessibilityLabel(title).accessibilityValue(store.archive.plan.sounds.contains(id) ? "1" : "0")
        }.padding(.vertical, 10)
    }
}
struct SettingsScreen: View {
    @EnvironmentObject var store: SleepStore
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(store.words("appearance"), selection: Binding(get: { store.archive.preferences.appearance }, set: { value in store.preferences { $0.appearance = value } })) { ForEach(["auto", "dawn", "night"], id: \.self) { Text(store.words($0)).tag($0) } }.accessibilityIdentifier("appearance")
                    Picker(store.words("language"), selection: Binding(get: { store.archive.preferences.language }, set: { value in store.preferences { $0.language = value } })) { Text(store.words("system")).tag("system"); Text("Español").tag("es"); Text("English").tag("en") }.accessibilityIdentifier("language")
                    Toggle(store.words("openJournal"), isOn: Binding(get: { store.archive.preferences.openJournal }, set: { value in store.preferences { $0.openJournal = value } }))
                }
                Section {
                    Toggle(store.words("record"), isOn: Binding(get: { store.archive.preferences.record }, set: { value in store.preferences { $0.record = value } }))
                    Picker(store.words("retention"), selection: Binding(get: { store.archive.preferences.keepDays }, set: { value in store.preferences { $0.keepDays = value }; Task { await store.prune() } })) { Text(store.words("forever")).tag(0); ForEach([1,7,30,90], id: \.self) { Text("\($0) " + store.words("days")).tag($0) } }
                } header: { Text(store.words("privacy")) } footer: { Text(store.words("recordHint")) }
                Section {
                    Toggle(store.words("health"), isOn: Binding(get: { store.archive.preferences.health }, set: { value in
                        if !value { store.preferences { $0.health = false } }
                        else { Task { do { try await HealthReader().authorize(); store.preferences { $0.health = true } } catch { store.error = error.localizedDescription } } }
                    }))
                    Button { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } } label: { Label(store.words("permissions"), systemImage: "arrow.up.right.square") }
                } footer: { Text(store.words("healthHint")) }
                Section {
                    Text(store.words(WakeScheduler.systemAlarms ? "nativeInfo" : "fallbackInfo")).font(.subheadline)
                    if WakeScheduler.systemAlarms { Text(store.words("nativeExtra")).font(.caption).foregroundStyle(.secondary) }
                } header: { Text(store.words("reliability")) }
                Section {
                    Label(store.words("local"), systemImage: "lock.shield")
                    Text(store.words("localHint")).font(.caption).foregroundStyle(.secondary)
                } footer: { Text(store.words("about") + " · 1.0") }
            }.scrollContentBackground(.hidden).background(Color.paper).navigationTitle(store.words("settings")).toolbarBackground(.visible, for: .tabBar)
        }
    }
}
