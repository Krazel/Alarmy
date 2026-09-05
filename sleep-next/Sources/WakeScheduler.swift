import Foundation
import UserNotifications
import AlarmKit
import ActivityKit
import SwiftUI
import AppIntents

@available(iOS 26.0, *)
struct WakeMetadata: AlarmMetadata { var session: String }

enum WakeFailure: Error { case permission }
struct WakeScheduler {
    static var systemAlarms: Bool { if #available(iOS 26.0, *) { return true }; return false }
    func schedule(id: UUID, date: Date, filename: String, words: Words) async throws {
        if #available(iOS 26.0, *) {
            let manager = AlarmManager.shared
            var state = manager.authorizationState
            if state == .notDetermined { state = try await manager.requestAuthorization() }
            guard state == .authorized else { throw WakeFailure.permission }
            let stop = AlarmButton(text: LocalizedStringResource(stringLiteral: words("dismiss")), textColor: .white, systemImageName: "sun.max.fill")
            let alert = AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: words("morning")), stopButton: stop)
            let attributes = AlarmAttributes<WakeMetadata>(presentation: AlarmPresentation(alert: alert), metadata: WakeMetadata(session: id.uuidString), tintColor: .orange)
            let config = AlarmManager.AlarmConfiguration<WakeMetadata>(schedule: .fixed(date), attributes: attributes, stopIntent: WakeStopIntent(alarmID: id.uuidString), sound: .named(filename))
            _ = try await manager.schedule(id: id, configuration: config)
        } else {
            let center = UNUserNotificationCenter.current()
            guard try await center.requestAuthorization(options: [.alert, .sound]) else { throw WakeFailure.permission }
            let settings = await center.notificationSettings()
            guard settings.soundSetting == .enabled else { throw WakeFailure.permission }
            let content = UNMutableNotificationContent()
            content.title = words("morning"); content.body = words("dismiss")
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: filename))
            content.categoryIdentifier = "WAKE"
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
            try await center.add(UNNotificationRequest(identifier: id.uuidString, content: content, trigger: trigger))
        }
    }
    func cancel(id: UUID) throws {
        if #available(iOS 26.0, *) { if try AlarmManager.shared.alarms.contains(where: { $0.id == id }) { try AlarmManager.shared.cancel(id: id) } }
        else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id.uuidString])
        }
    }
}

struct WakeDismissal: Codable {
    let alarmID: String
    let date: Date
    static var file: URL { DiskLocation.root.appendingPathComponent("dismissal.json") }
    static func take() -> WakeDismissal? {
        guard let data = try? Data(contentsOf: file), let value = try? JSONDecoder().decode(Self.self, from: data) else { return nil }
        try? FileManager.default.removeItem(at: file)
        return value
    }
}
@available(iOS 26.0, *)
struct WakeStopIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Finish night"
    static var openAppWhenRun = true
    @Parameter(title: "Alarm") var alarmID: String
    init() { alarmID = "" }
    init(alarmID: String) { self.alarmID = alarmID }
    func perform() async throws -> some IntentResult {
        try FileManager.default.createDirectory(at: DiskLocation.root, withIntermediateDirectories: true)
        try JSONEncoder().encode(WakeDismissal(alarmID: alarmID, date: Date())).write(to: WakeDismissal.file, options: .atomic)
        await MainActor.run { NotificationCenter.default.post(name: Notification.Name("WakeDismissed"), object: nil) }
        return .result()
    }
}
