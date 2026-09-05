import Foundation

// Single writer: an update becomes visible only after the atomic disk write succeeds.
actor ArchiveRepository {
    private let file: URL
    private var current: AppArchive?
    init(file: URL = DiskLocation.root.appendingPathComponent("archive.json")) { self.file = file }
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
        guard archive.preferences.keepDays > 0 else { return archive }
        let cutoff = now.addingTimeInterval(-Double(archive.preferences.keepDays) * 86400)
        let expired = archive.sessions.flatMap(\.clips).filter { $0.created < cutoff }
        guard !expired.isEmpty else { return archive }
        let result = try update { value in
            for i in value.sessions.indices { value.sessions[i].clips.removeAll { $0.created < cutoff } }
        }
        for clip in expired {
            if let url = DiskLocation.child(clip.filename, of: DiskLocation.clips) { try? FileManager.default.removeItem(at: url) }
        }
        return result
    }
}
