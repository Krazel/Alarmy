import Foundation
import AVFoundation

extension SleepStore {
    func beginRecordingIfNeeded() async throws {
        guard await acquireClipFiles() else { throw CancellationError() }
        defer { clipFilesBusy = false }
        guard let night = archive.active, archive.preferences.analysisEnabled, night.capturePaused != true,
              !audio.isRecording, !ringing, !audioInterrupted, !writeFailed, !failed, !testMode else { return }
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
            Task { await self.pauseCapture(reason: "recordError") }
        }
        audio.onDeadline = { [weak self] in Task { await self?.pauseCapture(reason: "recordAlarm") } }
        try audio.startRecording(nightID: night.id, wake: night.wake, margin: archive.preferences.sensitivity ?? 10, byteLimit: remaining,
            epoch: { [weak self] epoch in self?.observe(epoch, nightID: night.id) },
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
        guard archive.pendingClipDeletions?.contains(receipt.clip.filename) != true else { return }
        guard let file = DiskLocation.child(receipt.clip.filename, of: DiskLocation.clips), FileManager.default.fileExists(atPath: file.path) else { return }
        guard archive.active?.id == receipt.nightID || archive.sessions.contains(where: { $0.id == receipt.nightID }) else { return }
        let write = commit { value in
            if value.active?.id == receipt.nightID {
                if value.active?.clips.contains(where: { $0.id == receipt.clip.id }) == false { value.active?.clips.append(receipt.clip) }
            } else if let i = value.sessions.firstIndex(where: { $0.id == receipt.nightID }), !value.sessions[i].clips.contains(where: { $0.id == receipt.clip.id }) {
                value.sessions[i].clips.append(receipt.clip)
            }
        }
        Task { if await write.value { do { try ClipSpool.acknowledge(receipt, directory: DiskLocation.clips); let owner = self.archive.active?.id == receipt.nightID ? self.archive.active : self.archive.sessions.first { $0.id == receipt.nightID }
                    if owner?.retainAudio != nil { await self.analyze(receipt.clip) } } catch { self.error = error.localizedDescription } } }
    }
    func recoverClips() async {
        guard !audio.hasCapture, await acquireClipFiles() else { return }
        defer { clipFilesBusy = false }
        guard !audio.hasCapture else { return }
        do {
            let recovery = try await Task.detached { let spool = try ClipSpool(directory: DiskLocation.clips); let clips = try spool.recover(); return (clips, spool.recoveryFailures) }.value
            if recovery.1 > 0 { error = words("damagedClips") }
            for receipt in recovery.0 { index(receipt) }
            if let writeTail { _ = await writeTail.value }
        } catch { self.error = words("recordFailure") + " " + error.localizedDescription }
    }
    func acquireClipFiles() async -> Bool {
        // Recovery must not recreate a WAV while a deliberate deletion removes its sidecars.
        while clipFilesBusy {
            do { try await Task.sleep(nanoseconds: 20_000_000) } catch { return false }
        }
        guard !Task.isCancelled else { return false }
        clipFilesBusy = true; return true
    }
    func pauseCapture(reason: String = "recordPaused") async {
        guard await acquireCapture() else { return }; defer { captureBusy = false }
        await pauseCaptureLocked(reason: reason)
    }
    private func acquireCapture() async -> Bool {
        while captureBusy {
            do { try await Task.sleep(nanoseconds: 20_000_000) } catch { return false }
        }
        guard !Task.isCancelled else { return false }
        captureBusy = true; return true
    }
    private func pauseCaptureLocked(reason: String) async {
        if reason != "recordInterrupted" { resumeAfterInterruption = false }
        let end = await audio.stopRecording(reason: reason) ?? audio.lastCaptureEnd
        commit { value in
            if reason == "recordAlarm", value.active?.resumeCaptureAfterAlarm == nil {
                let shouldResume = value.preferences.analysisEnabled && value.active?.capturePaused != true
                value.active?.resumeCaptureAfterAlarm = shouldResume
            }
            if reason != "recordAlarm", reason != "recordInterrupted" { value.active?.resumeCaptureAfterAlarm = false }
            value.active?.capturePaused = true
            if let count = value.active?.captureSpans?.count, count > 0,
               value.active?.captureSpans?[count-1].reason == "recordListening" {
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
        guard await commit({ $0.preferences.analyze = true; $0.active?.capturePaused = false; $0.active?.resumeCaptureAfterAlarm = nil }).value else { return }
        do { try await beginRecordingIfNeeded() } catch { audio.captureState = "recordError"; self.error = words("recordFailure") + " " + error.localizedDescription }
    }
    func interruption(began: Bool, shouldResume: Bool = false) async {
        // Ended notifications must wait for the begun notification to flush its final clip.
        guard await acquireCapture() else { return }; defer { captureBusy = false }
        if began {
            if !audioInterrupted { resumeAfterInterruption = audio.hasCapture && archive.active?.capturePaused != true }
            audioInterrupted = true
            await pauseCaptureLocked(reason: "recordInterrupted"); audio.stopPlayback(); audio.restoreScreen(); ringing = false
        } else {
            audioInterrupted = false
            defer { resumeAfterInterruption = false }
            if shouldResume && resumeAfterInterruption && archive.preferences.analysisEnabled && archive.active != nil {
                guard await commit({ $0.active?.capturePaused = false }).value else { return }
                do { try await beginRecordingIfNeeded() } catch { audio.captureState = "recordError"; self.error = error.localizedDescription }
            }
        }
    }
}
