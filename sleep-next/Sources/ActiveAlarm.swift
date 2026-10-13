import Foundation
import UIKit

extension SleepStore {
    /// Changes only this night's timing. Recording and its session identity stay intact.
    func changeActiveAlarm(hour: Int, minute: Int, now: Date = Date(), calendar: Calendar = .current) async -> Bool {
        guard !busy, !ringing, !writeFailed, !failed, !journalPreview,
              let initial = archive.active, initial.hasAlarm else { return false }
        var choice = AlarmPlan(); choice.hour = hour; choice.minute = minute
        guard let date = choice.next(after: now, calendar: calendar) else { return false }
        guard initial.wake.timeIntervalSince(now) > 3 else { error = words("alarmTooClose"); return false }
        busy = true; editingActiveAlarm = true
        let background = UIApplication.shared.beginBackgroundTask(withName: "Change tonight's alarm")
        defer {
            editingActiveAlarm = false; busy = false
            if background != .invalid { UIApplication.shared.endBackgroundTask(background) }
        }
        // New capture commits wait at the persistence barrier; the microphone keeps running.
        if let preceding = writeTail { _ = await preceding.value }
        guard !writeFailed, let original = archive.active, original.id == initial.id else { return false }
        let replacement = UUID()
        var changed = false
        await audio.updateCaptureDeadline(.distantFuture)
        do {
            if let backup = original.backupAlarmID, !testMode { try scheduler.cancel(id: backup) }
            // Record the replacement ID before asking the OS to schedule it. If the
            // process exits halfway through, resume can remove this tracked backup.
            var staged = archive; staged.active?.backupAlarmID = replacement
            try await persistAlarmSnapshot(staged)
            archive.active?.backupAlarmID = replacement
            if !testMode { try await scheduler.schedule(id: replacement, date: date, filename: try await ToneLibrary.alarmFilename(original.soundID, imported: archive.tones, gradual: archive.plan.gradual), words: words) }
            var updated = archive
            updated.active?.alarmID = replacement; updated.active?.wake = date
            updated.active?.backupAlarmID = original.alarmID
            updated.active?.smartTriggered = false
            if original.hasActiveSmartWindow {
                let window = original.latestWake.flatMap { end in original.windowStart.map { end.timeIntervalSince($0) } } ?? Double(archive.plan.window * 60)
                updated.active?.latestWake = date; updated.active?.windowStart = date.addingTimeInterval(-window)
            } else { updated.active?.latestWake = nil; updated.active?.windowStart = nil }
            try await persistAlarmSnapshot(updated)
            // Publish only scheduling fields; input may have added clips/epochs while saving.
            archive.active?.alarmID = replacement; archive.active?.wake = date
            archive.active?.backupAlarmID = original.alarmID; archive.active?.smartTriggered = false
            archive.active?.latestWake = updated.active?.latestWake; archive.active?.windowStart = updated.active?.windowStart
            changed = true
            do {
                if !testMode { try scheduler.cancel(id: original.alarmID) }
                commit { if $0.active?.alarmID == replacement { $0.active?.backupAlarmID = nil } }
            } catch { self.error = words("alarmCleanupError") + " " + error.localizedDescription }
        } catch {
            self.error = words("alarmChangeFailed") + " " + error.localizedDescription
            do {
                if !testMode { try scheduler.cancel(id: replacement) }
                if archive.active?.backupAlarmID == replacement { commit { if $0.active?.backupAlarmID == replacement { $0.active?.backupAlarmID = nil } } }
            } catch { self.error = words("alarmCleanupError") + " " + error.localizedDescription }
        }
        await audio.updateCaptureDeadline(archive.active?.wake ?? original.wake)
        return changed
    }

    private func persistAlarmSnapshot(_ snapshot: AppArchive) async throws {
        _ = try await repository.update { value in
            let revision = value.revision; value = snapshot; value.revision = revision
        }
    }

    func cleanUpAlarmBackup() async {
        guard !busy, let night = archive.active, let backup = night.backupAlarmID else { return }
        busy = true; defer { busy = false }
        do {
            if !testMode { try scheduler.cancel(id: backup) }
            _ = await commit { if $0.active?.id == night.id && $0.active?.backupAlarmID == backup { $0.active?.backupAlarmID = nil } }.value
        } catch { self.error = words("alarmCleanupError") + " " + error.localizedDescription }
    }
}
