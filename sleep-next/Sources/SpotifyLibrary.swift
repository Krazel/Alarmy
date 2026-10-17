import AuthenticationServices
import CryptoKit
import Security
import SwiftUI

struct SpotifyDevice: Identifiable, Equatable {
    let id: String
    let name: String
}
struct SpotifyConfiguration {
    let clientID: String
    let redirect: String
    static var current: Self? {
        guard let id = Bundle.main.object(forInfoDictionaryKey:"SpotifyClientID") as? String,
              !id.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,
              let uri = Bundle.main.object(forInfoDictionaryKey:"SpotifyRedirectURI") as? String,
              let url = URL(string:uri), url.scheme == "https", url.host != nil else {return nil}
        return Self(clientID:id,redirect:uri)
    }
}
private struct SpotifyToken: Codable {
    let access: String
    let refresh: String
    let expires: Date
}
private enum SpotifyVault {
    static var query: [String:Any] { [kSecClass as String:kSecClassGenericPassword,
        kSecAttrService as String:"com.krazel.alarmanext.spotify",kSecAttrAccount as String:"oauth"] }
    static func read() -> Data? {
        var q = query; q[kSecReturnData as String] = true
        var value: CFTypeRef?
        return SecItemCopyMatching(q as CFDictionary,&value) == errSecSuccess ? value as? Data : nil
    }
    static func save(_ data:Data) throws {
        let status = SecItemUpdate(query as CFDictionary,[kSecValueData as String:data] as CFDictionary)
        if status == errSecItemNotFound {
            var q = query; q[kSecValueData as String] = data
            q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(q as CFDictionary,nil) == errSecSuccess else {throw MusicProblem.unavailable}
        } else if status != errSecSuccess {throw MusicProblem.unavailable}
    }
    static func clear() {SecItemDelete(query as CFDictionary)}
}

/// Account tokens stay in the device Keychain. No sleep data enters this API.
@MainActor final class SpotifyLibrary: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    @Published private(set) var connected = false
    @Published private(set) var playlists: [MusicPlaylist] = []
    @Published private(set) var devices: [SpotifyDevice] = []
    private var token: SpotifyToken?
    private var authentication: ASWebAuthenticationSession?
    private var connectionID = UUID()
    private let session: URLSession
    var configured: Bool {SpotifyConfiguration.current != nil}
    override init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12; config.timeoutIntervalForResource = 20
        session = URLSession(configuration:config)
        super.init()
        token = SpotifyVault.read().flatMap {try? JSONDecoder().decode(SpotifyToken.self,from:$0)}
        connected = token != nil
    }
    func presentationAnchor(for session:ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap {$0 as? UIWindowScene}.flatMap(\.windows).first(where:\.isKeyWindow) ?? ASPresentationAnchor()
    }
    static func challenge(_ verifier:String) -> String {
        Data(SHA256.hash(data:Data(verifier.utf8))).base64EncodedString()
            .replacingOccurrences(of:"+",with:"-").replacingOccurrences(of:"/",with:"_").replacingOccurrences(of:"=",with:"")
    }
    static func callbackCode(_ url:URL,state:String) throws -> String {
        guard url.scheme == "alarma-spotify", url.host == "callback",
              let parts = URLComponents(url:url,resolvingAgainstBaseURL:false) else {throw MusicProblem.permission}
        let items = parts.queryItems ?? []
        guard items.filter({$0.name == "state"}).count == 1,
              items.first(where:{$0.name == "state"})?.value == state,
              items.filter({$0.name == "code"}).count == 1,
              let code = items.first(where:{$0.name == "code"})?.value, !code.isEmpty,
              !items.contains(where:{$0.name == "error"}) else {throw MusicProblem.permission}
        return code
    }
    func connect() async throws {
        guard let config = SpotifyConfiguration.current else {throw MusicProblem.notConfigured}
        let ticket = connectionID
        let verifier = UUID().uuidString + UUID().uuidString
        let state = UUID().uuidString
        var url = URLComponents(string:"https://accounts.spotify.com/authorize")!
        url.queryItems = ["client_id":config.clientID,"response_type":"code","redirect_uri":config.redirect,
            "state":state,"code_challenge_method":"S256","code_challenge":Self.challenge(verifier),
            "scope":"playlist-read-private playlist-read-collaborative user-read-playback-state user-modify-playback-state"].map {URLQueryItem(name:$0.key,value:$0.value)}
        let callback: URL = try await withCheckedThrowingContinuation { continuation in
            let auth = ASWebAuthenticationSession(url:url.url!,callbackURLScheme:"alarma-spotify") { url,error in
                if let url {continuation.resume(returning:url)} else {continuation.resume(throwing:MusicProblem.cancelled)}
            }
            authentication = auth; auth.presentationContextProvider = self
            if !auth.start() {continuation.resume(throwing:MusicProblem.unavailable)}
        }
        authentication = nil
        let code = try Self.callbackCode(callback,state:state)
        let value = try await exchange(["grant_type":"authorization_code","code":code,"redirect_uri":config.redirect,"client_id":config.clientID,"code_verifier":verifier],previous:nil)
        guard connectionID == ticket else {throw MusicProblem.cancelled}
        try SpotifyVault.save(JSONEncoder().encode(value)); token = value; connected = true
        try await reload()
    }
    func disconnect() {
        connectionID = UUID(); authentication?.cancel(); authentication = nil
        token = nil; connected = false; playlists = []; devices = []; SpotifyVault.clear()
    }
    private func exchange(_ fields:[String:String],previous:String?) async throws -> SpotifyToken {
        var request = URLRequest(url:URL(string:"https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"; request.setValue("application/x-www-form-urlencoded",forHTTPHeaderField:"Content-Type")
        var body = URLComponents(); body.queryItems = fields.map {URLQueryItem(name:$0.key,value:$0.value)}
        request.httpBody = body.percentEncodedQuery?.replacingOccurrences(of:"+",with:"%2B").data(using:.utf8)
        let (data,response) = try await session.data(for:request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with:data) as? [String:Any],
              let access = json["access_token"] as? String,
              let refresh = json["refresh_token"] as? String ?? previous else {throw MusicProblem.permission}
        return SpotifyToken(access:access,refresh:refresh,expires:Date().addingTimeInterval(json["expires_in"] as? Double ?? 3600))
    }
    private func access() async throws -> String {
        guard let current = token, let config = SpotifyConfiguration.current else {throw MusicProblem.permission}
        if current.expires.timeIntervalSinceNow > 60 {return current.access}
        let ticket = connectionID
        let refreshed = try await exchange(["grant_type":"refresh_token","refresh_token":current.refresh,"client_id":config.clientID],previous:current.refresh)
        guard ticket == connectionID else {throw MusicProblem.cancelled}
        try SpotifyVault.save(JSONEncoder().encode(refreshed)); token = refreshed
        return refreshed.access
    }
    private func api(_ path:String,method:String = "GET",body:[String:Any]? = nil) async throws -> [String:Any] {
        guard let url = URL(string:path.hasPrefix("https://") ? path : "https://api.spotify.com/v1/"+path),
              url.scheme == "https", url.host == "api.spotify.com", url.path.hasPrefix("/v1/") else {throw MusicProblem.network}
        let ticket = connectionID
        var request = URLRequest(url:url); request.httpMethod = method
        if method == "PUT" {request.timeoutInterval = 5}
        request.setValue("Bearer " + (try await access()),forHTTPHeaderField:"Authorization")
        if let body {request.httpBody = try JSONSerialization.data(withJSONObject:body); request.setValue("application/json",forHTTPHeaderField:"Content-Type")}
        let (data,response) = try await session.data(for:request)
        guard ticket == connectionID else {throw MusicProblem.cancelled}
        guard let response = response as? HTTPURLResponse else {throw MusicProblem.network}
        guard (200..<300).contains(response.statusCode) else {
            if response.statusCode == 401 {disconnect(); throw MusicProblem.permission}
            if response.statusCode == 403 {throw MusicProblem.playback}
            throw MusicProblem.network
        }
        if data.isEmpty {return [:]}
        return (try JSONSerialization.jsonObject(with:data) as? [String:Any]) ?? [:]
    }
    private func allItems(_ path:String) async throws -> [[String:Any]] {
        var next:String? = path, items:[[String:Any]] = [], seen = Set<String>()
        while let page = next {
            guard seen.insert(page).inserted, seen.count <= 200 else {throw MusicProblem.unavailable}
            let json = try await api(page); items += json["items"] as? [[String:Any]] ?? []
            next = json["next"] as? String
            try Task.checkCancellation()
        }
        return items
    }
    func reload() async throws {
        let ticket = connectionID
        let values = try await allItems("me/playlists?limit=50")
        let result = try await api("me/player/devices")
        guard ticket == connectionID else {throw MusicProblem.cancelled}
        playlists = values.compactMap {value in
            guard let id = value["id"] as? String, let name = value["name"] as? String else {return nil}
            return MusicPlaylist(id:id,title:name,tracks:[])
        }
        // Explicit selection prevents an alarm unexpectedly playing on a desktop or speaker.
        devices = (result["devices"] as? [[String:Any]] ?? []).compactMap {value in
            guard let id = value["id"] as? String, let name = value["name"] as? String,
                  value["is_restricted"] as? Bool != true else {return nil}
            return SpotifyDevice(id:id,name:name)
        }
    }
    func tracks(in playlist:MusicPlaylist) async throws -> [MusicTrack] {
        guard playlist.id.allSatisfy({$0.isLetter || $0.isNumber}) else {throw MusicProblem.empty}
        return try await allItems("playlists/\(playlist.id)/items?limit=50").compactMap {value in
            guard let item = (value["item"] ?? value["track"]) as? [String:Any],
                  item["type"] as? String == "track", item["is_local"] as? Bool != true,
                  item["is_playable"] as? Bool != false,
                  let uri = item["uri"] as? String, uri.hasPrefix("spotify:track:"),
                  let title = item["name"] as? String else {return nil}
            let artists = (item["artists"] as? [[String:Any]] ?? []).compactMap {$0["name"] as? String}.joined(separator:", ")
            let album = item["album"] as? [String:Any]
            let artwork = (album?["images"] as? [[String:Any]])?.first?["url"] as? String
            let link = (item["external_urls"] as? [String:Any])?["spotify"] as? String
            return MusicTrack(id:uri,title:title,artist:artists,artwork:artwork,link:link)
        }
    }
    func play(_ track:MusicTrack,device:String) async throws {
        guard !device.isEmpty, device.allSatisfy({$0.isLetter || $0.isNumber}), track.id.hasPrefix("spotify:track:") else {throw MusicProblem.device}
        _ = try await api("me/player/play?device_id=\(device)",method:"PUT",body:["uris":[track.id]])
    }
    func isPlaying(_ track:MusicTrack,device:String) async throws -> Bool {
        let state = try await api("me/player")
        let playing = state["is_playing"] as? Bool == true
        let currentDevice = (state["device"] as? [String:Any])?["id"] as? String
        let currentTrack = (state["item"] as? [String:Any])?["uri"] as? String
        return playing && currentDevice == device && currentTrack == track.id
    }
    func pauseIfOwned(_ track:MusicTrack,device:String) async {
        guard (try? await isPlaying(track,device:device)) == true else {return}
        _ = try? await api("me/player/pause?device_id=\(device)",method:"PUT")
    }
}
