import Foundation

enum MusicProvider: String, Codable, CaseIterable { case apple, spotify }
enum MusicChoiceMode: String, Codable, CaseIterable { case fixed, shuffle }
struct MusicTrack: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let artist: String
    var artwork: String?
    var link: String?
}
struct MusicPlaylist: Equatable, Identifiable {
    let id: String
    let title: String
    let tracks: [MusicTrack]
}
struct AlarmMusic: Codable, Equatable {
    var provider: MusicProvider
    var mode: MusicChoiceMode = .fixed
    var tracks: [MusicTrack]
    var playlistName: String?
    var deviceID: String?
    func selected(excluding previous: String?, index: (Int) -> Int = {Int.random(in:0..<$0)}) -> MusicTrack? {
        var seen = Set<String>()
        let available = tracks.filter {!$0.id.isEmpty && seen.insert($0.id).inserted}
        guard !available.isEmpty else {return nil}
        if mode == .fixed {return available.first}
        let different = available.filter {$0.id != previous}
        let pool = different.isEmpty ? available : different
        return pool[max(0,min(pool.count-1,index(pool.count)))]
    }
    func resolved(excluding previous: String?) -> AlarmMusic? {
        guard let track = selected(excluding:previous) else {return nil}
        var value = self; value.tracks = [track]; return value
    }
}

enum MusicProblem: Error {case permission, unavailable, empty, notConfigured, cancelled, network, device, playback}
