import Foundation
import AVFoundation

extension SleepStore {
    func beginRecordingIfNeeded() throws {
        guard let night = archive.active, archive.preferences.record, night.capturePaused != true, !audio.isRecording, !ringing, !testMode else { return }
        guard Date() < night.wake else { audio.captureState = "recordAlarm"; return }
        let spanID = UUID(), now = Date()
        var lastPersist = now
        let directory = DiskLocation.clips
        let existing = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        let total = existing.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        let nightBytes = night.clips.reduce(0) { value, clip in value + ((try? directory.appendingPathComponent(clip.filename).resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        let remaining = min(256*1024*1024 - nightBytes, 512*1024*1024 - total)
        guard remaining > 1_000_000 else { audio.captureState = "recordError"; throw CocoaError(.fileWriteOutOfSpace) }
        audio.onFailure = { [weak self] error in
            guard let self else { return }
            self.error = self.words("recordFailure") + " " + error.localizedDescription
            self.commit { $0.active?.capturePaused = true }
        }
        try audio.startRecording(nightID: night.id, wake: night.wake, margin: archive.preferences.sensitivity ?? 10, byteLimit: remaining,
            receive: { [weak self] receipt in self?.index(receipt) },
            progress: { [weak self] end in
                guard let self else { return }
                guard end.timeIntervalSince(lastPersist) >= 10 || !self.audio.isRecording else { return }
                lastPersist = end
                self.commit { value in
                    if value.active?.id == night.id, let i = value.active?.captureSpans?.firstIndex(where: { $0.id == spanID }) {
                        value.active?.captureSpans?[i].end = end; value.active?.checkpoint = end
                    }
                }
            })
        commit { value in
            if value.active?.id == night.id {
                if value.active?.captureSpans == nil { value.active?.captureSpans = [] }
                value.active?.captureSpans?.append(CaptureSpan(id: spanID, start: now, end: now, reason: "recordListening"))
            }
        }
    }
    func index(_ receipt: ClipReceipt) {
        guard let file = DiskLocation.child(receipt.clip.filename, of: DiskLocation.clips), FileManager.default.fileExists(atPath: file.path) else { return }
        guard archive.active?.id == receipt.nightID || archive.sessions.contains(where: { $0.id == receipt.nightID }) else { return }
        let write = commit { value in
            if value.active?.id == receipt.nightID {
                if value.active?.clips.contains(where: { $0.id == receipt.clip.id }) == false { value.active?.clips.append(receipt.clip) }
            } else if let i = value.sessions.firstIndex(where: { $0.id == receipt.nightID }), !value.sessions[i].clips.contains(where: { $0.id == receipt.clip.id }) {
                value.sessions[i].clips.append(receipt.clip)
            }
        }
        Task { if await write.value { do { try ClipSpool.acknowledge(receipt, directory: DiskLocation.clips) } catch { self.error = error.localizedDescription } } }
    }
    func recoverClips() async {
        guard !audio.isRecording else { return }
        do {
            let recovery = try await Task.detached { let spool = try ClipSpool(directory: DiskLocation.clips); let clips = try spool.recover(); return (clips, spool.recoveryFailures) }.value
            if recovery.1 > 0 { error = words("damagedClips") }
            for receipt in recovery.0 { index(receipt) }
            if let writeTail { _ = await writeTail.value }
        } catch { error = words("recordFailure") + " " + error.localizedDescription }
    }
    func pauseCapture(reason: String = "recordPaused") async {
        while captureBusy { try? await Task.sleep(nanoseconds: 20_000_000) }; captureBusy = true; defer { captureBusy = false }
        if reason != "recordInterrupted" { resumeAfterInterruption = false }
        let end = await audio.stopRecording(reason: reason)
        commit { value in
            value.active?.capturePaused = true
            if let count = value.active?.captureSpans?.count, count > 0 {
                value.active?.captureSpans?[count-1].reason = reason
                if let end { value.active?.captureSpans?[count-1].end = end }
            }
        }
        await recoverClips()
    }
    func resumeCapture() async {
        guard !captureBusy, archive.active != nil, !ringing, !audioInterrupted, !failed else { return }
        captureBusy = true; defer { captureBusy = false }
        guard await audio.microphoneAllowed() else { audio.captureState = "recordDenied"; error = words("micError"); return }
        guard await commit({ $0.preferences.record = true; $0.active?.capturePaused = false }).value else { return }
        do { try beginRecordingIfNeeded() } catch { audio.captureState = "recordError"; self.error = words("recordFailure") + " " + error.localizedDescription }
    }
    func interruption(began: Bool, shouldResume: Bool = false) async {
        if began {
            resumeAfterInterruption = audio.isRecording && archive.active?.capturePaused != true
            audioInterrupted = true
            await pauseCapture(reason: "recordInterrupted"); audio.stopPlayback(); audio.restoreScreen(); ringing = false
        } else {
            audioInterrupted = false
            defer { resumeAfterInterruption = false }
            if shouldResume && resumeAfterInterruption && archive.preferences.record && archive.active != nil {
                commit { $0.active?.capturePaused = false }
                do { try beginRecordingIfNeeded() } catch { audio.captureState = "recordError"; self.error = error.localizedDescription }
            }
        }
    }
}
