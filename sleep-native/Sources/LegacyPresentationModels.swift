import SwiftUI
import Combine

enum SleepTheme: String, CaseIterable, Identifiable {
    case sunset
    case night

    var id: String { rawValue }

    var title: String {
        L("Alarma")
    }

    var activeTitle: String {
        switch self {
        case .sunset: return L("Buenas noches")
        case .night: return L("La noche ha comenzado")
        }
    }

    var primary: Color {
        switch self {
        case .sunset: return Color(red: 0.86, green: 0.34, blue: 0.20)
        case .night: return Color(red: 0.37, green: 0.83, blue: 0.88)
        }
    }

    var text: Color {
        switch self {
        case .sunset: return Color(red: 0.30, green: 0.17, blue: 0.10)
        case .night: return Color.white
        }
    }

    var secondaryText: Color {
        switch self {
        case .sunset: return Color(red: 0.49, green: 0.39, blue: 0.31)
        case .night: return Color(red: 0.63, green: 0.76, blue: 0.86)
        }
    }
}

enum AppAppearance: String, Codable, CaseIterable, Identifiable {
    case automatic
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return L("Auto")
        case .light: return L("Claro")
        case .dark: return L("Oscuro")
        }
    }

    var resolvedTheme: SleepTheme {
        switch self {
        case .light:
            return .sunset
        case .dark:
            return .night
        case .automatic:
            let hour = Calendar.current.component(.hour, from: Date())
            return (hour >= 20 || hour < 8) ? .night : .sunset
        }
    }
}

enum NightSoundRetention: Int, CaseIterable, Identifiable {
    case never = 0
    case oneDay = 1
    case oneWeek = 7
    case oneMonth = 30
    case threeMonths = 90

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .never: return L("Nunca")
        case .oneDay: return L("1 día")
        case .oneWeek: return L("7 días")
        case .oneMonth: return L("30 días")
        case .threeMonths: return L("90 días")
        }
    }

    var days: Int? {
        rawValue == 0 ? nil : rawValue
    }
}

enum AppMonetizationConfig {
    static let adsEnabled = false
    static let supportPromptEnabled = false
    static let supportPromptIntervalDays = 14
    static let minimumMonthlySupport = "0,99 €"
    static let monthlySupportOptions = ["0,99 €", "3 €", "5 €", "10 €", "15 €", "30 €", "50 €", "100 €", "300 €"]
}

struct AlarmSound: Identifiable, Hashable {
    let id: String
    let name: String
    let fileName: String
    let baseFrequency: Double
    let color: Color

    static let defaultIds = ["bosque-amanecer", "despertar-suave", "lo-fi-alarm"]

    static var all: [AlarmSound] { [
        .init(id: "funny-alarm", name: "Funny alarm", fileName: "funny-alarm", baseFrequency: 330, color: .orange),
        .init(id: "bosque-amanecer", name: L("Bosque al amanecer"), fileName: "bosque-al-amanecer", baseFrequency: 220, color: .green),
        .init(id: "despertar-suave", name: L("Despertar suave"), fileName: "despertar-suave", baseFrequency: 262, color: .mint),
        .init(id: "lo-fi-alarm", name: "Lo-fi alarm clock", fileName: "lo-fi-alarm-clock", baseFrequency: 196, color: .purple)
    ] }
}

struct CustomAlarmSound: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    var fileName: String

    var soundId: String { "custom:\(fileName)" }
}

enum AppTab: Hashable {
    case alarm
    case journal
    case settings
}

@MainActor
final class AppNavigation: ObservableObject {
    @Published var selectedTab: AppTab = .alarm
    @Published var requestedJournalDate: Date?

    func openJournal(for date: Date = Date()) {
        requestedJournalDate = date
        selectedTab = .journal
    }
}

struct DreamEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var day: Date
    var notes = ""
    var wakeMood: WakeMood?
    var soundClips: [SleepSoundClip] = []
    var score: Int?
    var awakeMinutes = 0
    var snoreEvents = 0
    var strongBreathingEvents = 0
    var talkingEvents = 0
    var coughEvents = 0
    var audioClips = 0
    var sleepStartedAt: Date?
    var sleepEndedAt: Date?
    var lightSleepMinutes = 0
    var deepSleepMinutes = 0
    var samples: [SleepStageSample] = []

    init(day: Date) {
        self.day = day
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case day
        case notes
        case wakeMood
        case soundClips
        case score
        case awakeMinutes
        case snoreEvents
        case strongBreathingEvents
        case talkingEvents
        case coughEvents
        case audioClips
        case sleepStartedAt
        case sleepEndedAt
        case lightSleepMinutes
        case deepSleepMinutes
        case samples
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        day = try container.decode(Date.self, forKey: .day)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        wakeMood = try container.decodeIfPresent(WakeMood.self, forKey: .wakeMood)
        soundClips = try container.decodeIfPresent([SleepSoundClip].self, forKey: .soundClips) ?? []
        score = try container.decodeIfPresent(Int.self, forKey: .score)
        awakeMinutes = try container.decodeIfPresent(Int.self, forKey: .awakeMinutes) ?? 0
        snoreEvents = try container.decodeIfPresent(Int.self, forKey: .snoreEvents) ?? 0
        strongBreathingEvents = try container.decodeIfPresent(Int.self, forKey: .strongBreathingEvents) ?? 0
        talkingEvents = try container.decodeIfPresent(Int.self, forKey: .talkingEvents) ?? 0
        coughEvents = try container.decodeIfPresent(Int.self, forKey: .coughEvents) ?? 0
        audioClips = try container.decodeIfPresent(Int.self, forKey: .audioClips) ?? soundClips.count
        sleepStartedAt = try container.decodeIfPresent(Date.self, forKey: .sleepStartedAt)
        sleepEndedAt = try container.decodeIfPresent(Date.self, forKey: .sleepEndedAt)
        lightSleepMinutes = try container.decodeIfPresent(Int.self, forKey: .lightSleepMinutes) ?? 0
        deepSleepMinutes = try container.decodeIfPresent(Int.self, forKey: .deepSleepMinutes) ?? 0
        samples = try container.decodeIfPresent([SleepStageSample].self, forKey: .samples) ?? []
    }

    var dayKey: String {
        Self.key(for: day)
    }

    var hasSleepData: Bool {
        sleepStartedAt != nil || sleepEndedAt != nil || !samples.isEmpty || audioClips > 0 || !soundClips.isEmpty || snoreEvents > 0 || strongBreathingEvents > 0 || talkingEvents > 0 || coughEvents > 0
    }

    static func key(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

struct SleepStageSample: Identifiable, Codable, Equatable {
    enum Stage: String, Codable, Equatable {
        case awake
        case light
        case deep
        case rem

        var title: String {
            switch self {
            case .awake: return L("Despierto")
            case .light: return L("Ligero")
            case .deep: return L("Profundo")
            case .rem: return L("REM")
            }
        }
    }

    var id = UUID()
    var date: Date
    var endDate: Date?
    var stage: Stage
    var movement: Double
    var soundEvents: Int
}

struct SleepAudioEvent {
    enum Kind: String, CaseIterable, Codable {
        case snore
        case strongBreathing
        case talking
        case cough
        case unknown

        var title: String {
            switch self {
            case .snore: return L("Ronquido")
            case .strongBreathing: return L("Respiración")
            case .talking: return L("Voz")
            case .cough: return L("Tos")
            case .unknown: return L("Otro sonido")
            }
        }

        var color: Color {
            switch self {
            case .snore: return Color(red: 0.94, green: 0.45, blue: 0.17)
            case .strongBreathing: return Color(red: 0.30, green: 0.78, blue: 0.74)
            case .talking: return Color(red: 0.62, green: 0.42, blue: 0.92)
            case .cough: return Color(red: 0.96, green: 0.68, blue: 0.18)
            case .unknown: return .gray
            }
        }

        var assetName: String {
            switch self {
            case .snore: return "sound-snore"
            case .strongBreathing: return "sound-breathing"
            case .talking: return "sound-voice"
            case .cough: return "sound-cough"
            case .unknown: return "sound-wave"
            }
        }
    }

    let day: Date
    let kind: Kind
    let fileURL: URL
}

struct SleepSoundClip: Identifiable, Codable, Equatable {
    var id = UUID()
    var date: Date
    var kind: SleepAudioEvent.Kind
    var filePath: String

    var fileURL: URL {
        URL(fileURLWithPath: filePath)
    }
}

enum WakeMood: String, CaseIterable, Identifiable, Codable {
    case exhausted
    case tired
    case neutral
    case calm
    case energized

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw { case "rested": self = .energized; case "okay": self = .neutral
        default: guard let value = Self(rawValue: raw) else { throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown mood")) }; self = value }
    }
    var id: String { rawValue }

    var title: String {
        switch self {
        case .exhausted: return L("Agotado")
        case .tired: return L("Cansado")
        case .neutral: return L("Normal")
        case .calm: return L("Calmado")
        case .energized: return L("Con fuerza")
        }
    }

    var face: String {
        switch self {
        case .exhausted: return "mood-exhausted"
        case .tired: return "mood-tired"
        case .neutral: return "mood-neutral"
        case .calm: return "mood-calm"
        case .energized: return "mood-energized"
        }
    }

    var color: Color {
        switch self {
        case .exhausted: return Color(red: 0.76, green: 0.22, blue: 0.18)
        case .tired: return Color.orange
        case .neutral: return Color.gray
        case .calm: return Color.mint
        case .energized: return Color.green
        }
    }
}

struct DiaryAssetImage: View {
    let name: String

    var body: some View {
        if let image = image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Color.clear
        }
    }

    private var image: UIImage? {
        if let uiImage = UIImage(named: name) {
            return uiImage
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "DiaryAssets") {
            return UIImage(contentsOfFile: url.path)
        }
        return nil
    }
}

