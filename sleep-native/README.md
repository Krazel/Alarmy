# Alarma — native sleep rebuild

Fresh SwiftUI iPhone implementation, version 0.1 (build 1), minimum iOS 16.

## Start here

The new app lives entirely in `sleep-native/`. Open `AlarmaSleep.xcodeproj` after running `xcodegen generate` in this directory on macOS. Choose the `AlarmaSleep` scheme. Set your signing team to install on an iPhone.

This worktree is isolated on `codex/native-sleep-rebuild`; the original `Alarma` checkout and its existing `native-ios` implementation remain untouched. Older directories in this worktree are inherited repository history and are not included in the new target.

## Product recovered from the existing app

Reviewed `native-ios/Sources/AlarmaApp.swift`, `src/alarm-core.js`, `IOS_READY.md` and the existing build workflow. The original concept includes gentle alarms, sound rotation, progressive volume, an active night session, snooze, optional night recordings, a dream journal and wake-up mood.

The rebuild implements that core with separate models, persistence, notification scheduling, audio/session lifecycle and SwiftUI screens. No web view or Capacitor code is included. The first interface is English.

## Implemented

- First-run welcome; Tonight, Journal and Settings tabs.
- Up to eight alarms, names, time, individual repeat days, enable/disable and deletion.
- Three original generated WAV melodies, previews, multi-selection, shuffle without immediate repeats, fade-in and snooze settings.
- An explicit night preparation flow with audio test; continuous audible ambient playback, wake-up audio, snooze, optional shake-to-snooze and end-night confirmation.
- Backup local notifications, permission state and direct iPhone settings link.
- Local atomic JSON persistence and interrupted-night recovery using the last checkpoint.
- Journal with recorded session duration, recent-night chart, morning mood, notes and deletion.
- Opt-in microphone clips with a loudness threshold, 12-second chunks, 120-clip limit per session, playback, deletion and 1/7/30-day retention.
- Local storage only: no backend, accounts, tracking, ads or purchase placeholders.
- Original app icon; imagegen night landscape integrated in the app.

## Honest limits

On iOS 16, ordinary scheduled reminders use local notifications and follow Silent mode and Focus. Continuous alarm audio requires starting a night with an audible soundscape. Force-quit, audio interruptions, exhausted battery and system termination can stop that session. The app cannot guarantee wake-up delivery. Test this on a physical iPhone before relying on it. No silent keep-alive audio, volume-slider manipulation or critical-alert entitlement is used.

The journal reports time in the session, not measured sleep. Loud sounds are not classified as snoring, cough, breathing or speech. Sleep-stage inference, smart-wake claims, HealthKit and AlarmKit are outside this first build. Existing recordings and diary data are not imported automatically into the separate bundle ID.

Recordings can include nearby sounds and the app's ambient audio. The threshold is only a simple loudness filter, not a validated sound detector. Clip cleanup happens when the app is used, not while it is terminated.

## Build and verify

The workflow `.github/workflows/sleep-native.yml` runs only on the isolated rebuild branch, only for a public repository, and uploads validation artifacts. It does not publish a release or submit to Apple.

On macOS:

```
xcodegen generate
xcodebuild -project AlarmaSleep.xcodeproj -scheme AlarmaSleep -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO test
```

Tests cover repeat schedules, exact-time rollover, daylight-saving gaps and repeats in Europe/Madrid, disabled/invalid schedules, shuffle, safe duration, persistence, corrupt-file preservation, interrupted-night recovery and bundled resources.

Physical-device QA still required: locked screen overnight, volume and route behavior, incoming calls, denied permissions, force-quit, repeated snooze, recording playback, low-storage failures, clock/time-zone change during a session and iOS 16 layout/Dynamic Type/VoiceOver.

## Assets and sources

`Tools/generate-audio.cjs` creates all four original synthesized audio files. No third-party music is copied.

`Resources/Assets.xcassets/NightLandscape.imageset/night-landscape.png` was created with the built-in imagegen tool on 2026-09-05. Prompt: original premium portrait illustration for an iPhone sleep app; midnight navy negative space, sparse dim stars, warm crescent, layered indigo/teal mountains, still lake and tiny distant cabin; no UI or typography. It is a background asset, not an approved screen reference or a screenshot.

Apple references checked for implementation:
- https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/SchedulingandHandlingLocalNotifications.html
- https://developer.apple.com/documentation/avfaudio/avaudiosession
- https://developer.apple.com/videos/play/wwdc2025/230/ (AlarmKit is iOS 26+, not used by the iOS 16 target.)
