const fs=require('fs'),path=require('path');
const base=process.cwd(),old=path.resolve('../Alarma/native-ios'),src=fs.readFileSync(path.join(old,'Sources/AlarmaApp.swift'),'utf8');
const cut=(a,b)=>src.slice(src.indexOf(a),b?src.indexOf(b):undefined);
const write=(f,s)=>fs.writeFileSync(path.join(base,f),s);
let types='import SwiftUI\nimport Combine\n\n'+cut('enum SleepTheme:', 'enum AppMonetizationConfig')+cut('enum AppMonetizationConfig','@MainActor\nfinal class DreamStore:');
// Source line endings may be CRLF.
if(types.includes('final class DreamStore:')) types=types.slice(0,types.indexOf('@MainActor',types.indexOf('struct SleepStageSample:')));
let end=src.indexOf('final class DreamStore:');
types='import SwiftUI\nimport Combine\n\n'+src.slice(src.indexOf('enum SleepTheme:'),src.lastIndexOf('@MainActor',end));
types+=cut('struct SleepAudioEvent {','final class SleepAudioAnalyzer');
types+=cut('struct SleepSoundClip:', 'struct ContentView:');
types=types.replace('static let adsEnabled = true','static let adsEnabled = false').replace('static let supportPromptEnabled = true','static let supportPromptEnabled = false');
types=types.replace('case cough\n','case cough\n        case unknown\n').replace('case cough\r\n','case cough\r\n        case unknown\r\n');
types=types.replace('case .cough: return "Tos"','case .cough: return "Tos"\n            case .unknown: return "Otro sonido"').replace('case .cough: return Color(red: 0.96, green: 0.68, blue: 0.18)','case .cough: return Color(red: 0.96, green: 0.68, blue: 0.18)\n            case .unknown: return .gray').replace('case .cough: return "sound-cough"','case .cough: return "sound-cough"\n            case .unknown: return "sound-wave"');
types=types.replace('case deep\n','case deep\n        case rem\n').replace('case deep\r\n','case deep\r\n        case rem\r\n').replace('case .deep: return "Profundo"','case .deep: return "Profundo"\n            case .rem: return "REM"');
types=types.replace('var stage: Stage','var endDate: Date?\n    var stage: Stage');
types=types.replace('var id: String { rawValue }\n\n    var title: String {\n        switch self {\n        case .exhausted:', 'var id: String { rawValue }\n\n    var title: String {\n        switch self {\n        case .exhausted:');
// Backward-compatible mood decoding from the first rebuild.
const moodPos=types.indexOf('enum WakeMood:');
types=types.slice(0,moodPos)+types.slice(moodPos).replace('var id: String { rawValue }',`init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw { case "rested": self = .energized; case "okay": self = .neutral
        default: guard let value = Self(rawValue: raw) else { throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown mood")) }; self = value }
    }
    var id: String { rawValue }`);
write('sleep-native/Sources/LegacyPresentationModels.swift',types);
let ui='import SwiftUI\nimport AVFoundation\nimport MediaPlayer\nimport UniformTypeIdentifiers\n\n'+cut('struct ContentView:');
ui=ui.replace(/        \.onAppear \{\s*session.startAlarmMonitor[\s\S]*?        \.preferredColorScheme/, '        .preferredColorScheme');
ui=ui.replaceAll('session.snooze()', 'Task { await session.snooze() }');
ui=ui.replace('var onFinish: (() -> Void)?','var onFinish: (() -> Void)?');
ui=ui.replace('NightActiveView(alarm: alarm, theme: store.sleepTheme)','NightActiveView(alarm: alarm, theme: store.sleepTheme, onFinish: finishAlarm)');
ui=ui.replace('struct NightActiveView: View {','struct NightActiveView: View {\n    var onFinish: (() -> Void)? = nil'); // memberwise order will fix below
ui=ui.replace('NightActiveView(alarm: alarm, theme: store.sleepTheme, onFinish: finishAlarm)','NightActiveView(onFinish: finishAlarm, alarm: alarm, theme: store.sleepTheme)');
ui=ui.replace('                    session.stop()\n                } label:', '                    onFinish?()\n                } label:').replace('                    session.stop()\r\n                } label:', '                    onFinish?()\r\n                } label:');
ui=ui.replace('showMotionHint = true','showMotionHint = alarm.motionSnooze');
ui=ui.replace('struct SoundSelector: View {','struct SoundSelector: View {\n    @EnvironmentObject private var engine: NightEngine');
ui=ui.replace('AlarmSoundPlayer.preview(sound: sound)','engine.playPreview(sound.id)').replace('AlarmSoundPlayer.preview(customSound: sound)','engine.playPreview(sound.soundId)');
ui=ui.replace('struct SoundPickerSheet: View {','struct SoundPickerSheet: View {\n    @EnvironmentObject private var engine: NightEngine');
ui=ui.replace('        .fileImporter(', '        .onDisappear { engine.stopPreview() }\n        .fileImporter(');
ui=ui.replace('                store.removeCustomSound(sound)','                engine.stopPreview()\n                alarm.soundIds.removeAll { $0 == sound.soundId }\n                store.removeCustomSound(sound)');
ui=ui.replace('case .deep: return height * 0.70','case .deep: return height * 0.70\n        case .rem: return height * 0.30');
ui=ui.replace('            case .cough:', '            case .cough:');
ui=ui.replace('ForEach([5, 10],', 'ForEach([3, 5, 10, 15],');
ui=ui.replace('Text("Empieza antes de la alarma")','Text("La pantalla se ilumina al sonar")');
ui=ui.replace('Text("Con anuncios discretos")','Text("Apoyo mensual")');
ui=ui.replace('store.adsRemoved ? "Sin anuncios activo" : "Con anuncios discretos"','store.adsRemoved ? "Sin anuncios activo" : "Próximamente"');
ui=ui.replace('Con una aportación mensual ayudas a mantener la app y el equipo. Además, mientras esté activa, se quitan los anuncios.','El apoyo mensual todavía no está disponible. No se realizará ningún cargo.');
ui=ui.replace('La pantalla ya está preparada, pero falta conectar los productos de suscripción mensual en App Store Connect y StoreKit.','El apoyo mensual estará disponible en una próxima versión. Todavía no hay compras que restaurar.');
ui=ui.replace('                        settingsGroup("Apariencia"',`                        settingsGroup("Idioma", systemImage: "globe") {
                            Picker("Idioma", selection: $store.language) {
                                Text("Sistema").tag(AppLanguage.system)
                                Text("Castellano").tag(AppLanguage.es)
                                Text("English").tag(AppLanguage.en)
                            }.pickerStyle(.segmented).accessibilityIdentifier("language-picker")
                        }
                        settingsGroup("Apariencia"`);
ui=ui.replace('                            nightSoundRetentionControls', `                            nightSoundRetentionControls
                            Button("Conectar con Salud") { Task { await dreams.connectHealth() } }
                            Text("Las fases de sueño proceden de Salud. Sin registros compatibles, la gráfica permanece vacía.").font(.caption)
                            if let message = dreams.healthMessage { Text(message).font(.caption) }`);
ui=ui.replace('struct SleepStageChart: View {','struct SleepStageChart: View {\n    @EnvironmentObject private var dreams: DreamStore');
ui=ui.replace('        Array(entry.samples.suffix(120))','        dreams.healthSamples(for: entry.day)');
ui=ui.replace('            .onAppear { loadEntry() }','            .onAppear { loadEntry(); Task { await dreams.refreshHealth() } }\n            .onReceive(dreams.objectWillChange) { _ in DispatchQueue.main.async { loadEntry() } }');
ui=ui.replace('    private static let monthFormatter:', '    private static var monthFormatter:').replace('    private static let dateFormatter:', '    private static var dateFormatter:');
ui=ui.replaceAll('Locale(identifier: "es_ES")','L10n.locale');
ui=ui.replace('var onDelete: (() -> Void)?','var onDelete: (() -> Void)?');
write('sleep-native/Sources/LegacyViews.swift',ui);
fs.unlinkSync(path.join(base,'sleep-native/Sources/DetailViews.swift'));
let models=fs.readFileSync('sleep-native/Sources/Models.swift','utf8');
models=models.slice(0,models.indexOf('enum WakeMood:'))+models.slice(models.indexOf('struct SoundClip:'));
models=models.replace('    var shakeToSnooze = false','    var shakeToSnooze = true\n    var lightWake: Bool?\n    var lightMinutes: Int?');
models=models.replace('    var seconds: Double','    var seconds: Double\n    var kind: SleepAudioEvent.Kind?');
models=models.replace('    var version = 1','    var appearance: AppAppearance?\n    var language: AppLanguage?\n    var nightlyAlarm: WakeAlarm?\n    var openJournal: Bool?\n    var customSounds: [CustomAlarmSound]?\n    var journalNotes: [String: JournalNote]?\n    var healthConnected: Bool?\n    var version = 1');
models=models.replace('SoundChoice.all.map(\\.id).contains($0)','(SoundChoice.all.map(\\.id) + AlarmSound.all.map(\\.id)).contains($0) || $0.hasPrefix("custom:")');
write('sleep-native/Sources/Models.swift',models);
let presentation=fs.readFileSync('sleep-native/Sources/LegacyPresentationModels.swift','utf8').replace('enum AppAppearance: String,','enum AppAppearance: String, Codable,');
write('sleep-native/Sources/LegacyPresentationModels.swift',presentation);
for(const name of ['SunsetBackground','NightBackground'])fs.cpSync(path.join(old,'Resources/Assets.xcassets',name+'.imageset'),path.join(base,'sleep-native/Resources/Assets.xcassets',name+'.imageset'),{recursive:true});
for(const file of fs.readdirSync(path.join(old,'Resources/DiaryAssets'))){
 const name=path.parse(file).name,dir=path.join(base,'sleep-native/Resources/Assets.xcassets',name+'.imageset');fs.mkdirSync(dir,{recursive:true});fs.copyFileSync(path.join(old,'Resources/DiaryAssets',file),path.join(dir,file));fs.writeFileSync(path.join(dir,'Contents.json'),JSON.stringify({images:[{filename:file,idiom:'universal'}],info:{author:'xcode',version:1}}));
}
for(const file of fs.readdirSync(path.join(old,'Resources')).filter(f=>f.endsWith('.mp3')))fs.copyFileSync(path.join(old,'Resources',file),path.join(base,'sleep-native/Resources',file));
