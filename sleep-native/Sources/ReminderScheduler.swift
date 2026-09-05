import Foundation
import Combine
import UserNotifications

@MainActor
final class ReminderScheduler: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var authorized = false
    @Published var error: String?
    private let center = UNUserNotificationCenter.current()
    private var generation = 0
    private var syncing = false
    private var requestedAlarms: [WakeAlarm] = []
    override init() { super.init(); center.delegate = self }
    func refreshPermission() async {
        let settings = await center.notificationSettings()
        authorized = settings.authorizationStatus == .authorized
    }
    func requestPermission() async -> Bool {
        do {
            authorized = try await center.requestAuthorization(options: [.alert, .sound])
            if !authorized { error = "Enable notifications in iPhone Settings to receive backup reminders." }
            return authorized
        } catch { self.error = error.localizedDescription; return false }
    }
    func sync(_ alarms: [WakeAlarm]) async {
        requestedAlarms = alarms
        generation += 1
        guard !syncing else { return }
        syncing = true
        defer { syncing = false }
        repeat {
            let requestGeneration = generation
            await replaceReminders(requestedAlarms)
            if requestGeneration == generation { break }
        } while true
    }
    private func replaceReminders(_ alarms: [WakeAlarm]) async {
        let existing = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: existing.filter { $0.identifier.hasPrefix("alarm-") }.map(\.identifier))
        await refreshPermission()
        guard authorized else { return }
        for alarm in alarms.prefix(8) where alarm.enabled {
            guard alarm.nextDate(after: Date()) != nil else { continue }
            let days: [Int?] = alarm.weekdays.isEmpty ? [nil] : alarm.weekdays.sorted().map { Optional($0) }
            for day in days {

                let content = UNMutableNotificationContent()
                content.title = alarm.name.isEmpty ? "Good morning" : alarm.name
                content.body = "Your wake-up reminder. Open Alarma to start your day."
                content.sound = .default
                var date = DateComponents()
                date.hour = alarm.hour; date.minute = alarm.minute; date.weekday = day
                // A one-shot uses the full next local date so it cannot ring again tomorrow.
                if day == nil, let next = alarm.nextDate(after: Date()) {
                    date = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: next)
                }
                let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: day != nil)
                let id = "alarm-\(alarm.id)-\(day ?? 0)"
                do { try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger)) }
                catch { self.error = "Could not schedule a reminder: \(error.localizedDescription)" }
            }
        }
    }
    func scheduleNight(at date: Date) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Good morning"
        content.body = "It's time to wake up. Open Alarma."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        try await center.add(UNNotificationRequest(identifier: "night-backup", content: content, trigger: trigger))
    }
    func cancelNight() {
        center.removePendingNotificationRequests(withIdentifiers: ["night-backup"])
        center.removeDeliveredNotifications(withIdentifiers: ["night-backup"])
    }
    func cancelReminder(for alarm: WakeAlarm) {
        let ids = (0...7).map { "alarm-\(alarm.id)-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
