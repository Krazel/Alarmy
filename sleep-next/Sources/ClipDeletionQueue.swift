import Foundation

enum ClipDeletionQueue {
    struct Result { var completed: [String] = []; var error: Error? }
    // Idempotent: a relaunch can finish a deletion whose final archive write failed.
    // Receipts are removed too, so recovery cannot resurrect deliberately deleted audio.
    static func remove(_ filenames: [String], directory: URL) -> Result {
        var result = Result()
        for filename in filenames {
            do {
                guard let audio = DiskLocation.child(filename, of: directory) else { throw CocoaError(.fileReadCorruptFile) }
                var files = [audio]
                let stem = audio.deletingPathExtension().lastPathComponent
                if audio.pathExtension == "wav", UUID(uuidString: stem) != nil {
                    files += [".receipt.json", ".open.json", ".pcm"].map { directory.appendingPathComponent(stem + $0) }
                }
                for file in files where FileManager.default.fileExists(atPath: file.path) {
                    do { try FileManager.default.removeItem(at: file) }
                    catch {
                        let missing = error as NSError
                        if missing.domain != NSCocoaErrorDomain || missing.code != NSFileNoSuchFileError { throw error }
                    }
                }
                result.completed.append(filename)
            } catch { result.error = error }
        }
        return result
    }
}
