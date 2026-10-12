import Foundation

extension SleepStore {
    func observe(_ epoch: AcousticEpoch, nightID: UUID) {
        commit { value in
            if value.active?.id == nightID {
                if value.active?.acousticEpochs == nil { value.active?.acousticEpochs = [] }
                value.active?.acousticEpochs?.append(epoch)
            } else if let i = value.sessions.firstIndex(where: { $0.id == nightID }) {
                if value.sessions[i].acousticEpochs == nil { value.sessions[i].acousticEpochs = [] }
                value.sessions[i].acousticEpochs?.append(epoch)
            }
        }
        guard !busy, !smartScheduling, !writeFailed, !audioInterrupted, !ringing,
              let night = archive.active, night.id == nightID,
              SmartWakePolicy.shouldWake(night, now: Date()) else { return }
        smartScheduling = true
        Task { await advanceSmartAlarm(night); smartScheduling = false }
    }

    private func advanceSmartAlarm(_ original: SleepSession) async {
        guard !busy, archive.active?.id == original.id else { return }
        busy = true; defer { busy = false }
        let id = UUID(), date = Date().addingTimeInterval(10)
        do {
            // The original latest-time alarm stays scheduled until the replacement is durable.
            if !testMode { try await scheduler.schedule(id:id,date:date,filename:ToneLibrary.filename(original.soundID,imported:archive.tones),words:words) }
            guard archive.active?.id == original.id, archive.active?.alarmID == original.alarmID else {
                if !testMode { try? scheduler.cancel(id:id) }; return
            }
            let saved = await commit { value in
                value.active?.backupAlarmID = original.alarmID
                value.active?.alarmID = id; value.active?.wake = date; value.active?.smartTriggered = true
            }.value
            guard saved else {
                if !testMode { try? scheduler.cancel(id:id) }
                // Preserve new observations made while saving; restore only scheduling fields.
                archive.active?.alarmID = original.alarmID; archive.active?.wake = original.wake
                archive.active?.backupAlarmID = nil; archive.active?.smartTriggered = false
                return
            }
            await pauseCapture(reason:"recordAlarm")
            if !testMode { try scheduler.cancel(id:original.alarmID) }
        } catch {
            // A cancellation failure leaves a tracked backup; finish/snooze will retry it.
            self.error = words("smartFallback") + " " + error.localizedDescription
        }
    }
}
