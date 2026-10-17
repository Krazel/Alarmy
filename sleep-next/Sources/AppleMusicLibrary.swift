import MediaPlayer
import SwiftUI

@MainActor final class AppleMusicLibrary: ObservableObject {
    @Published var authorized = MPMediaLibrary.authorizationStatus() == .authorized
    @Published var songs: [MusicTrack] = []
    @Published var playlists: [MusicPlaylist] = []
    private var player: MPMusicPlayerApplicationController?
    private var generation = UUID()
    private var pending: CheckedContinuation<Bool,Never>?
    private var timeout: Task<Void,Never>?
    func connect() async {
        let status = await withCheckedContinuation { continuation in
            MPMediaLibrary.requestAuthorization {continuation.resume(returning:$0)}
        }
        authorized = status == .authorized
        if authorized {reload()} else {songs = []; playlists = []}
    }
    func reload() {
        authorized = MPMediaLibrary.authorizationStatus() == .authorized
        guard authorized else {songs = []; playlists = []; return}
        songs = (MPMediaQuery.songs().items ?? []).map(Self.track)
        playlists = (MPMediaQuery.playlists().collections ?? []).compactMap {collection in
            guard let playlist = collection as? MPMediaPlaylist else {return nil}
            return MusicPlaylist(id:String(playlist.persistentID),title:playlist.name ?? "—",tracks:playlist.items.map(Self.track))
        }
    }
    private static func track(_ item:MPMediaItem) -> MusicTrack {
        MusicTrack(id:String(item.persistentID),title:item.title ?? "—",artist:item.artist ?? "")
    }
    // Bounded preparation: denied permission, missing songs and cloud failures
    // must never suppress the independent local alarm.
    func prepare(_ track:MusicTrack) async -> Bool {
        stop()
        guard MPMediaLibrary.authorizationStatus() == .authorized, let id = UInt64(track.id) else {return false}
        let query = MPMediaQuery.songs()
        query.addFilterPredicate(MPMediaPropertyPredicate(value:id,forProperty:MPMediaItemPropertyPersistentID))
        guard let item = query.items?.first else {return false}
        let player = MPMusicPlayerController.applicationQueuePlayer
        self.player = player; player.setQueue(with:MPMediaItemCollection(items:[item]))
        player.repeatMode = .one; player.shuffleMode = .off
        let ticket = generation
        return await withTaskCancellationHandler(operation: {
            await withCheckedContinuation { continuation in
                pending = continuation
                timeout = Task { [weak self] in
                    do {try await Task.sleep(nanoseconds:8_000_000_000)} catch {return}
                    self?.complete(false,ticket:ticket)
                }
                player.prepareToPlay { [weak self] error in
                    Task { @MainActor in self?.complete(error == nil,ticket:ticket) }
                }
            }
        },onCancel:{Task { @MainActor [weak self] in self?.stop() }})
    }
    private func complete(_ success:Bool,ticket:UUID) {
        guard ticket == generation, let continuation = pending else {return}
        pending = nil; timeout?.cancel(); timeout = nil
        if !success {player?.stop()}
        continuation.resume(returning:success)
    }
    func play() {player?.play()}
    var isPlaying: Bool {player?.playbackState == .playing}
    func stop() {
        generation = UUID(); timeout?.cancel(); timeout = nil
        player?.stop(); player = nil
        let continuation = pending; pending = nil; continuation?.resume(returning:false)
    }
}
