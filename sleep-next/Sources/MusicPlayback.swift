import SwiftUI
import UIKit

extension SleepStore {
    var musicSummary: String {
        guard let music = archive.plan.music else {return "\(archive.plan.sounds.count) " + words("selected")}
        return music.mode == .shuffle ? (music.playlistName ?? words("musicShuffle")) : (music.tracks.first?.title ?? words("music"))
    }
    func disconnectSpotify() async {
        await stopConnectedMusic()
        spotify.disconnect()
        _ = await commit { value in
            if value.plan.music?.provider == .spotify {value.plan.music = nil}
            if value.active?.alarmMusic?.provider == .spotify {value.active?.alarmMusic = nil}
            for i in value.sessions.indices where value.sessions[i].alarmMusic?.provider == .spotify {value.sessions[i].alarmMusic = nil}
            value.lastMusicTrack = nil
        }.value
    }
    func beginConnectedMusic(_ night:SleepSession) {
        guard !testMode, let choice = night.alarmMusic, let track = choice.tracks.first else {return}
        let ticket = UUID(); musicGeneration = ticket
        musicTask = Task { [weak self] in
            guard let self else {return}
            if let cleanup = self.musicCleanup {await cleanup.value}
            guard self.canPlayMusic(ticket,night:night) else {return}
            if choice.provider == .apple {
                let prepared = await self.appleMusic.prepare(track)
                guard self.canPlayMusic(ticket,night:night) else {return}
                guard prepared else {self.musicFallback = true; return}
                self.audio.stopPlayback(); self.appleMusic.play()
                do {try await Task.sleep(nanoseconds:700_000_000)} catch {return}
                if self.appleMusic.isPlaying {self.playingMusic = choice}
                else {self.appleMusic.stop(); self.restoreLocalAlarm()}
            } else {
                guard let device = choice.deviceID, self.spotify.connected else {self.musicFallback = true; return}
                // Spotify content must not overlap another audio source.
                self.audio.stopPlayback()
                self.spotifyAttempt = choice
                do {
                    try await self.spotify.play(track,device:device)
                    guard self.canPlayMusic(ticket,night:night) else {
                        await self.spotify.pauseIfOwned(track,device:device); return
                    }
                    try await Task.sleep(nanoseconds:700_000_000)
                    guard try await self.spotify.isPlaying(track,device:device) else {throw MusicProblem.playback}
                    guard self.canPlayMusic(ticket,night:night) else {
                        await self.spotify.pauseIfOwned(track,device:device); return
                    }
                    self.playingMusic = choice
                } catch {
                    await self.spotify.pauseIfOwned(track,device:device)
                    if self.canPlayMusic(ticket,night:night) {self.restoreLocalAlarm()}
                    return
                }
            }
            // If the selected song stops, the local tone resumes; no silent alarm.
            while self.canPlayMusic(ticket,night:night), self.playingMusic != nil {
                do {try await Task.sleep(nanoseconds:5_000_000_000)} catch {return}
                let playing: Bool
                if choice.provider == .apple {playing = self.appleMusic.isPlaying}
                else if let device = choice.deviceID {playing = (try? await self.spotify.isPlaying(track,device:device)) == true}
                else {playing = false}
                guard self.canPlayMusic(ticket,night:night) else {return}
                if !playing {
                    self.appleMusic.stop()
                    if choice.provider == .spotify, let device = choice.deviceID {await self.spotify.pauseIfOwned(track,device:device)}
                    self.playingMusic = nil; self.restoreLocalAlarm(); return
                }
            }
        }
    }
    private func canPlayMusic(_ ticket:UUID,night:SleepSession) -> Bool {
        !Task.isCancelled && musicGeneration == ticket && ringing && archive.active?.id == night.id && UIApplication.shared.applicationState == .active
    }
    func cancelConnectedMusic() {
        musicGeneration = UUID(); appleMusic.stop()
        let previous = musicTask; musicTask = nil; previous?.cancel()
        let choice = playingMusic ?? spotifyAttempt
        spotifyAttempt = nil
        playingMusic = nil
        let earlier = musicCleanup
        musicCleanup = Task { [weak self] in
            if let earlier {await earlier.value}
            if let previous {await previous.value}
            if let choice, choice.provider == .spotify, let track = choice.tracks.first, let device = choice.deviceID {
                await self?.spotify.pauseIfOwned(track,device:device)
            }
        }
    }
    func stopConnectedMusic() async {
        cancelConnectedMusic(); await musicCleanup?.value
    }
    func musicEnteredBackground() {
        guard musicTask != nil || playingMusic != nil else {return}
        cancelConnectedMusic()
        Task { [weak self] in
            guard let self else {return}
            await self.musicCleanup?.value
            if self.ringing {self.restoreLocalAlarm()}
        }
    }
    func restoreLocalAlarm() {
        guard ringing, !audioInterrupted, let night = archive.active else {return}
        musicFallback = true
        guard let url = ToneLibrary.url(night.soundID,imported:archive.tones) ?? ToneLibrary.url("aurora",imported:[]) else {return}
        do {try audio.play(url:url,id:"wake",loop:true,gradual:archive.plan.gradual)} catch {self.error = error.localizedDescription}
        if archive.plan.motionSnooze {audio.watchMovement { [weak self] in Task {await self?.snooze()} }}
    }
}
