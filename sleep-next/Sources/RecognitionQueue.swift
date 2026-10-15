import Foundation

extension AppArchive {
    // Persist intent before deleting files. Pending/failed analysis is not an unknown sound.
    mutating func queueUnrecognizedClips() {
        func clean(_ night: inout SleepSession) -> [String] {
            let unknown = night.clips.filter {$0.analysisDone && $0.analysisFailed != true && $0.kind == .other && !($0.events ?? []).contains(where:{$0.kind != .other})}
            let ids = Set(unknown.map(\.id))
            night.soundSummaries?.removeAll { ids.contains($0.id) || ($0.completed && !$0.events.contains(where:{$0.kind != .other})) }
            return unknown.map(\.filename)
        }
        var files: [String] = []
        if active != nil {files += clean(&active!)}
        for i in sessions.indices {files += clean(&sessions[i])}
        if !files.isEmpty {queueClipDeletion(files)}
    }
}

extension SleepStore {
    // One worker belongs to the store, not to the visible day/view. Retry each failed
    // clip once per activation; a persistent error must not cause an endless loop.
    func scheduleClipAnalysis() {
        guard loaded, !journalPreview, analysisWorker == nil else {return}
        analysisWorker = Task { [weak self] in
            guard let self else {return}
            defer {self.analysisWorker = nil}
            var attempted = Set<UUID>()
            while !Task.isCancelled {
                let clips = (self.archive.sessions + (self.archive.active.map {[$0]} ?? [])).flatMap(\.clips)
                guard let clip = clips.first(where:{$0.needsAnalysis && !attempted.contains($0.id) && self.archive.pendingClipDeletions?.contains($0.filename) != true}) else {break}
                attempted.insert(clip.id)
                await self.analyze(clip)
            }
            await self.discardUnrecognizedClips()
        }
    }
    func discardUnrecognizedClips() async {
        var next = archive; next.queueUnrecognizedClips()
        guard next != archive else {return}
        guard await commit({$0.queueUnrecognizedClips()}).value else {return}
        await completePendingClipDeletions()
    }
}
