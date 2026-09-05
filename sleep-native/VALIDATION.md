# Native rebuild validation — 2026-09-05

Application: AlarmaSleep 0.1 (build 1)

App source commit: `5aae2ccbf5bc2152f77e0df0e271a062cfd10472`

Validation run: https://github.com/Krazel/Alarmy/actions/runs/33955315749

## Verified in Xcode

- Simulator app and both test targets compile.
- 10 model tests cover local schedules, once-only expiry, weekday recurrence, daylight-saving transitions, sound choice and duration handling.
- 4 persistence/resource tests cover save/reload, interrupted-session recovery, corrupt-data preservation, all WAV resources and decoded artwork from the asset catalog.
- 1 UI test exercises welcome, Tonight, the alarm editor, empty Journal, Settings and preparation; grants notification permission; starts an actual audio session; ends it; saves a mood and notes; relaunches the app and verifies the note remains.
- Screenshots are captured from the running SwiftUI app, not HTML mockups. Journal content in test screenshots is synthetic XCTest input and does not represent a person's sleep.

## Device package

Release iPhone build succeeded. The downloaded IPA archive contains the native executable, compiled asset catalog, four WAV files, privacy manifest and Info.plist.

Local delivery: `artifact/AlarmaSleep-0.1-build-1-unsigned.ipa`.

IPA SHA-256: `80B8C8E82E967767D55B9D5CCEF77B08258B9E2141F787BD00FD50C523B85B71`.

All 15 tests passed with zero failures. Eight simulator screenshots are archived in `design/runtime/`; the background is visible and the saved note survives relaunch. Screenshots were visually reviewed on the iPhone 16 Pro simulator dimensions.

## Remaining physical-device checks

The automated run is on an iPhone simulator. Minimum deployment target is iOS 16; an iOS 16 phone has not been exercised here.

Before relying on alarms, verify a real overnight locked-screen session, speaker volume, fade-in, repeated snooze, calls/audio interruptions, force-quit behavior, microphone clips and retention, motion snooze, time-zone changes, low storage, Dynamic Type and VoiceOver on the intended iPhone.

The app measures session duration and stores user notes. It does not measure sleep stages or diagnose sleep conditions. The unsigned IPA requires signing before installation; no App Store or TestFlight submission was made.
