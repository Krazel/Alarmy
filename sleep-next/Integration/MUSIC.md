# Music integration · candidate 1.6

The user confirmed written Spotify approval for alarm functionality. That approval
does not supply the OAuth application registration. No client secret belongs in
the iPhone app. No account credentials have been added to this repository.

## One-time activation for the developer

1. Use the Spotify application covered by that approval. Obtain its public Client
   ID and the exact registered HTTPS redirect URI. End users never enter these.
2. Host `spotify-callback.html` at that URI on an owned HTTPS site. This template
   has NOT been deployed. Use `Cache-Control: no-store`, `Referrer-Policy:
   no-referrer`, no analytics and no query-string access logging. The page only
   returns the authorization code and state to `alarma-spotify://callback`, which
   ASWebAuthenticationSession handles on supported iOS versions including iOS16.
3. Set `SpotifyClientID` and `SpotifyRedirectURI` in the app's Info.plist using the
   registered public values. Until both exist, the UI explains activation is
   pending and does not show a nonfunctional Connect button.
4. Verify login, cancellation, refresh, private/collaborative playlists, pagination,
   Premium restrictions, explicit target device, playback, snooze, stop and loss
   of network on a physical iPhone. Confirm the app's Spotify quota/access before
   making this available to additional users. No paid upgrade is authorized.

PKCE S256 and state protect login; tokens are stored only in device-only Keychain.
API pagination reads the whole list or fails without selecting a partial subset.
Unavailable tracks, episodes and local Spotify files are excluded. Spotify playback
uses an explicitly selected available device, never an arbitrary active default.
Disconnect clears tokens, cached library/device metadata and Spotify selections.

## Apple Music and local audio

Apple's MediaPlayer library queries use the user's existing Music library after
permission. This is not a full Apple Music catalogue search. The application queue
player prepares the selected song with a bounded timeout. Playback availability
depends on the user's library, account and connection. No subscription is sold.

Local tones/imports support fixed or random selection. Existing archives preserve
their random behavior. Random provider selection avoids the previous track when
possible and is frozen per night, including snoozes. Lists are snapshots of the
last selection: refresh/reselect to include later playlist edits.

## Alarm reliability and limits

The existing native alarm is always scheduled with a local tone. Connected music
starts only while Alarma is active. It is NOT promised to start on a locked iPhone.
When leaving the foreground or playback fails, the local tone is restored. The
normal snooze/finish flow cancels pending preparation and stops owned playback.
Remote Spotify stop is necessarily best-effort when connectivity is lost; an
unreachable remote device cannot be guaranteed to stop until it reconnects.
Local audio is stopped before Spotify playback is requested; content is not mixed.
Progressive volume applies to the local tone, not to the external music service.
No microphone audio, journal entries or sleep estimates are sent to either service.

## Official references checked for this implementation

- [Spotify policy](https://developer.spotify.com/policy): written approval for alarms.
- [PKCE](https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow).
- [Redirect requirements](https://developer.spotify.com/documentation/web-api/concepts/redirect_uri).
- [Start playback](https://developer.spotify.com/documentation/web-api/reference/start-a-users-playback).
- [Playlist items](https://developer.spotify.com/documentation/web-api/reference/get-playlists-items).
- [Apple application queue player](https://developer.apple.com/documentation/mediaplayer/mpmusicplayercontroller/applicationQueuePlayer).

Native compilation/tests do not validate real accounts or physical device audio.
Record the verified test run separately; do not treat the visual proposals as the
implemented redesign. TestFlight 1.5.1 (1) remains the distributed version.
