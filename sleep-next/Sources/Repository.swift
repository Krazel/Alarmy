import Foundation

// Single writer: an update becomes visible only after the atomic disk write succeeds.
actor ArchiveRepository {
    private let file: URL
    private var current: AppArchive?
    private let clipsDirectory: URL
    init(file: URL = DiskLocation.root.appendingPathComponent("archive.json"), clipsDirectory: URL = DiskLocation.clips) { self.file = file; self.clipsDirectory = clipsDirectory }
    func load() throws -> AppArchive {
        if let current { return current }
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let value: AppArchive
        if FileManager.default.fileExists(atPath: file.path) {
            value = try JSONDecoder().decode(AppArchive.self, from: Data(contentsOf: file))
            guard value.schema == 1 else { throw CocoaError(.fileReadCorruptFile) }
        } else { value = AppArchive() }
        current = value
        return value
    }
    @discardableResult
    func update(_ mutation: @Sendable (inout AppArchive) throws -> Void) throws -> AppArchive {
        var next = try load()
        try mutation(&next)
        next.revision += 1
        try JSONEncoder().encode(next).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        current = next
        return next
    }
    func recover() throws -> AppArchive {
        let archive = try load()
        guard var night = archive.active else { return archive }
        night.end = night.checkpoint; night.interrupted = true
        let recovered = night
        return try update { $0.sessions.insert(recovered, at: 0); $0.active = nil }
    }
    func prune(now: Date = Date()) throws -> AppArchive {
        let archive = try load()
        let expired: [NightClip]
        if archive.preferences.keepDays > 0 {
            let cutoff = now.addingTimeInterval(-Double(archive.preferences.keepDays) * 86400)
            expired = (archive.sessions.flatMap(\.clips) + (archive.active?.clips ?? [])).filter { $0.created < cutoff }
        } else { expired = [] }
        var staged = archive
        if !expired.isEmpty { staged = try update { $0.queueClipDeletion(expired.map(\.filename)) } }
        guard let pending = staged.pendingClipDeletions, !pending.isEmpty else { return staged }
        let removal = ClipDeletionQueue.remove(pending, directory: clipsDirectory)
        var result = staged
        if !removal.completed.isEmpty {
            result = try update { $0.completeClipDeletion(removal.completed) }
        }
        if let error = removal.error { throw error }
        return result
    }
}
