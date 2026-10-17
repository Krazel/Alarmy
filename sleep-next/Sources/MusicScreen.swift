import SwiftUI

struct MusicSourceScreen: View {
    @EnvironmentObject var store: SleepStore
    @ObservedObject var apple: AppleMusicLibrary
    @ObservedObject var spotify: SpotifyLibrary
    let provider: MusicProvider
    @State private var busy = false
    @State private var problem: String?
    private var connected: Bool {provider == .apple ? apple.authorized : spotify.connected}
    var body: some View {
        List {
            Section {
                Text(store.words(provider == .apple ? "appleLibraryHint" : "spotifyHint")).font(.subheadline)
                if let selection = store.archive.plan.music, selection.provider == provider {
                    Label(store.musicSummary,systemImage:"checkmark.circle.fill")
                }
                if provider == .spotify && !spotify.configured {
                    Text(store.words("spotifyPending")).accessibilityIdentifier("spotify-pending")
                } else if !connected {
                    Button(store.words("connect") + " " + title) {Task {await connect()}}
                        .accessibilityIdentifier("connect-music")
                } else {
                    Button(store.words("refreshMusic")) {Task {await reload()}}
                    if provider == .spotify {
                        Button(store.words("disconnect"),role:.destructive) {
                            Task {busy = true; await store.disconnectSpotify(); busy = false}
                        }
                    }
                }
                if busy {ProgressView()}
                if let problem {Text(problem).foregroundStyle(.secondary).accessibilityIdentifier("music-problem")}
            } footer: {Text(store.words("musicForegroundHint"))}
            if connected {
                if provider == .apple {
                    if !apple.songs.isEmpty {
                        NavigationLink(store.words("songs")) { MusicTracksScreen(provider:provider,playlist:MusicPlaylist(id:"library",title:store.words("songs"),tracks:apple.songs),spotify:spotify) }
                    }
                    Section(store.words("playlists")) {
                        ForEach(apple.playlists) {playlist in
                            NavigationLink(playlist.title) {MusicTracksScreen(provider:provider,playlist:playlist,spotify:spotify)}
                        }
                    }
                    if apple.songs.isEmpty && !busy {Text(store.words("emptyMusic"))}
                } else {
                    Section(store.words("playlists")) {
                        ForEach(spotify.playlists) {playlist in
                            NavigationLink(playlist.title) {MusicTracksScreen(provider:provider,playlist:playlist,spotify:spotify)}
                        }
                    }
                    if spotify.playlists.isEmpty && !busy {Text(store.words("emptyMusic"))}
                }
            }
        }.disabled(busy).scrollContentBackground(.hidden).background(Color.paper)
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .task {if connected {await reload()}}
    }
    private var title:String {provider == .apple ? "Apple Music" : "Spotify"}
    private func connect() async {
        busy = true; problem = nil; defer {busy = false}
        if provider == .apple {
            await apple.connect(); if !apple.authorized {problem = store.words("musicPermission")}
        } else {
            do {try await spotify.connect()} catch MusicProblem.cancelled {} catch {problem = store.words("musicConnectionError")}
        }
    }
    private func reload() async {
        busy = true; problem = nil; defer {busy = false}
        if provider == .apple {apple.reload()}
        else {do {try await spotify.reload()} catch {problem = store.words("musicConnectionError")}}
    }
}

struct MusicTracksScreen: View {
    @EnvironmentObject var store: SleepStore
    let provider: MusicProvider
    let playlist: MusicPlaylist
    @ObservedObject var spotify: SpotifyLibrary
    @State private var tracks:[MusicTrack] = []
    @State private var device = ""
    @State private var search = ""
    @State private var busy = false
    @State private var problem = false
    @State private var selected = false
    private var usable:Bool {provider == .apple || !device.isEmpty}
    private var matches:[MusicTrack] {search.isEmpty ? tracks : tracks.filter {($0.title+" "+$0.artist).localizedCaseInsensitiveContains(search)}}
    var body: some View {
        List {
            Section {
                if provider == .spotify {
                    Picker(store.words("playOnDevice"),selection:$device) {
                        Text(store.words("chooseDevice")).tag("")
                        ForEach(spotify.devices) {Text($0.name).tag($0.id)}
                    }
                    Text(store.words("spotifyDeviceHint")).font(.caption).foregroundStyle(.secondary)
                }
                Button {choose(tracks,mode:.shuffle)} label: {Label(store.words("randomFromPlaylist"),systemImage:"shuffle")}
                    .disabled(!usable || tracks.isEmpty || busy).accessibilityIdentifier("music-shuffle")
                if selected {Label(store.words("musicSaved"),systemImage:"checkmark.circle.fill").accessibilityIdentifier("music-saved")}
            } footer: {Text(store.words("musicForegroundHint"))}
            if busy {ProgressView()}
            if problem {Button(store.words("refreshMusic")) {Task {await load()}}}
            Section(store.words("chooseSong")) {
                ForEach(matches) {track in
                    Button {choose([track],mode:.fixed)} label: {
                        HStack {
                            if let artwork = track.artwork.flatMap(URL.init(string:)) {AsyncImage(url:artwork) {image in image.resizable().scaledToFit()} placeholder:{Color.clear}.frame(width:44,height:44)}
                            VStack(alignment:.leading,spacing:4) {Text(track.title).foregroundStyle(Color.ink); Text(track.artist).font(.caption).foregroundStyle(.secondary)}
                            Spacer()
                            if store.archive.plan.music?.provider == provider && store.archive.plan.music?.mode == .fixed && store.archive.plan.music?.tracks.first?.id == track.id {Image(systemName:"checkmark")}
                        }
                    }.disabled(!usable || busy)
                }
            }
            if tracks.isEmpty && !busy {Text(store.words(problem ? "musicConnectionError" : "emptyMusic"))}
        }.searchable(text:$search,prompt:store.words("searchMusic"))
            .scrollContentBackground(.hidden).background(Color.paper)
            .navigationTitle(playlist.title).navigationBarTitleDisplayMode(.inline)
            .task {device = store.archive.plan.music?.deviceID ?? ""; if !spotify.devices.contains(where:{$0.id == device}) {device = ""}; await load()}
            .onChange(of:device) {_ in selected = false}
    }
    private func load() async {
        busy = true; problem = false; defer {busy = false}
        do {
            let all = provider == .apple ? playlist.tracks : try await spotify.tracks(in:playlist)
            var seen = Set<String>(); tracks = all.filter {seen.insert($0.id).inserted}
        } catch {problem = true; tracks = []}
    }
    private func choose(_ values:[MusicTrack],mode:MusicChoiceMode) {
        guard !values.isEmpty, usable else {return}
        let choice = AlarmMusic(provider:provider,mode:mode,tracks:values,playlistName:playlist.title,deviceID:provider == .spotify ? device : nil)
        store.plan {$0.music = choice}; selected = true
    }
}

struct PlayingMusicView: View {
    @EnvironmentObject var store: SleepStore
    let music: AlarmMusic
    var body: some View {
        if let track = music.tracks.first {
            HStack(spacing:10) {
                if let artwork = track.artwork.flatMap(URL.init(string:)) {AsyncImage(url:artwork) {image in image.resizable().scaledToFit()} placeholder:{Color.clear}.frame(width:48,height:48)}
                VStack(alignment:.leading,spacing:4) {
                    Text(track.title).font(.subheadline).lineLimit(2)
                    Text(track.artist).font(.caption).lineLimit(1)
                    if music.provider == .spotify, let url = track.link.flatMap(URL.init(string:)), url.scheme == "https", url.host == "open.spotify.com" {Link("Spotify ↗",destination:url).font(.caption)}
                    else {Text("Apple Music").font(.caption)}
                }
            }.padding(12).background(.black.opacity(0.3),in:RoundedRectangle(cornerRadius:16)).padding(.top,12)
        }
    }
}
