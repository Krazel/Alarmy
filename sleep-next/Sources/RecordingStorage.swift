import Foundation

enum RecordingStorageError: Error { case lowSpace, capacityUnavailable, recordingLimit }

struct RecordingUsage: Equatable {
    let bytes: Int64
    let count: Int
    let filenames: [String]
}

enum RecordingStorage {
    // Leave room for the current WAV, its recovery receipt and atomic diary writes.
    static let reserveBytes: Int64 = 64 * 1024 * 1024
    static func ensureAvailable(_ bytes: Int64?) throws {
        guard let bytes else { throw RecordingStorageError.capacityUnavailable }
        guard bytes > reserveBytes else { throw RecordingStorageError.lowSpace }
    }
    static func available(at directory: URL) throws -> Int64? {
        let values = try directory.resourceValues(forKeys: [.volumeAvailableCapacityKey])
        return values.volumeAvailableCapacity.map(Int64.init)
    }
    static func inventory(at directory: URL) throws -> RecordingUsage {
        guard FileManager.default.fileExists(atPath: directory.path) else { return RecordingUsage(bytes:0,count:0,filenames:[]) }
        let keys: Set<URLResourceKey> = [.isRegularFileKey,.isSymbolicLinkKey,.totalFileAllocatedSizeKey,.fileSizeKey]
        let urls = try FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:Array(keys))
        var bytes: Int64 = 0, count = 0, names: [String] = []
        for url in urls {
            let v = try url.resourceValues(forKeys:keys)
            guard v.isRegularFile == true, v.isSymbolicLink != true else { continue }
            bytes += Int64(v.totalFileAllocatedSize ?? v.fileSize ?? 0)
            names.append(url.lastPathComponent)
            if ["wav","m4a","caf"].contains(url.pathExtension.lowercased()) { count += 1 }
        }
        return RecordingUsage(bytes:bytes,count:count,filenames:names.sorted())
    }
}

extension AppArchive {
    mutating func queueAllRecordingsForDeletion(files: [String]) {
        // Keep the diary and aggregate sound statistics after erasing playable audio.
        for i in sessions.indices {
            var summaries = sessions[i].soundSummaries ?? []
            for clip in sessions[i].clips where !summaries.contains(where: { $0.id == clip.id }) {
                summaries.append(NightSoundSummary(clip:clip))
            }
            sessions[i].soundSummaries = summaries
        }
        queueClipDeletion(files + sessions.flatMap(\.clips).map(\.filename))
    }
}

extension SleepStore {
    func refreshRecordingUsage() async {
        guard !journalPreview else { return }
        do {
            recordingUsage = try await Task.detached { try RecordingStorage.inventory(at:DiskLocation.clips) }.value
        } catch { self.error = error.localizedDescription }
    }
    func deleteAllRecordings() async {
        guard !journalPreview, archive.active == nil, !audio.hasCapture, !deletingRecordings else { return }
        deletingRecordings = true; defer { deletingRecordings = false }
        audio.stopPlayback()
        guard await acquireClipFiles() else { return }
        // Recovery/indexing and capture start cannot race with the deletion inventory.
        do {
            let usage = try await Task.detached { try RecordingStorage.inventory(at:DiskLocation.clips) }.value
            let saved = await commit { $0.queueAllRecordingsForDeletion(files:usage.filenames) }.value
            clipFilesBusy = false
            if saved { await completePendingClipDeletions() }
        } catch { clipFilesBusy = false; self.error = error.localizedDescription }
        await refreshRecordingUsage()
    }
    func captureFailureMessage(_ error: Error) -> String {
        if let issue = error as? RecordingStorageError {
            switch issue {
            case .lowSpace: return words("recordStorageLow")
            case .capacityUnavailable: return words("recordStorageUnknown")
            case .recordingLimit: return words("recordLimit")
            }
        }
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain && ns.code == NSFileWriteOutOfSpaceError { return words("recordStorageLow") }
        return words("recordFailure") + " " + error.localizedDescription
    }
}
