# Native Alarma 0.2 validation — 2026-09-05

Application: **AlarmaSleep 0.2 (build 1)**, native SwiftUI, minimum iOS 16.

Validated app source: `345c787c89c6e425e88d5e9bab0bcadf546c4439`

Successful Xcode run: https://github.com/Krazel/Alarmy/actions/runs/33959032585

## Verified

**23 tests passed**: 22 model/persistence/resource tests and one complete UI flow.

- Local schedules, exact-time rollover, once-only expiry and Europe/Madrid daylight-saving transitions.
- Sound rotation, duration clamping, atomic save/reload, corrupt-data preservation and interrupted-session recovery.
- Five-mood migration, notes on days without recordings, cleared moods, nightly alarm rearming and options, indefinite clip retention.
- Importing a playable song, choosing it for the alarm, deleting it and restoring safe default songs.
- Health stage mapping leaves unspecified sleep unclassified; low-confidence or unrelated sound labels are not called snoring.
- Both language bundles, original MP3 files, both background images and diary assets load from the app bundle.
- Real simulator flow: theme changes, original editor and music selector, permission grant, actual night audio start/end, automatic journal opening, mood and note entry, full language switch into Spanish, calendar opening, app relaunch and persistence of language and notes.
- Simulator compilation, tests and **Release iPhone build** all succeeded.

## Visual evidence

14 native screenshots from the iPhone 16 Pro simulator are in [design/restored-runtime](design/restored-runtime/README.md). Reviewed the English and Spanish screens, completed theme transition, long labels and tab-bar contrast. Notes and mood shown in the captures are synthetic XCTest input, not a person's sleep data.

All 12 restored background/mood/sound PNGs and all four original MP3 files were compared by SHA-256 to the original `Alarma` checkout and match exactly. That checkout's tracked files remain unchanged.

## iPhone package

Local package: `artifact/AlarmaSleep-0.2-build-1-unsigned.ipa` at the worktree root.

SHA-256:

```text
06000C99CBC0015DFDD46E57D5B5253AC4814B9E4A3D31061B4E1E300274BF42
```

The IPA is **unsigned**. Installing requires signing for the iPhone, with HealthKit enabled for the app ID. No App Store/TestFlight upload or release was performed.

## Physical checks pending

An overnight physical-iPhone test is still needed: locked-screen/background playback, real volume and brightness, movement snooze, calls/audio interruptions, microphone classifications, imported-song formats and actual Health authorization/data. The simulator does not expose the physical iPhone volume slider. These device behaviors have not been claimed as physically validated.

Sleep stages come from compatible Health records; without them, the graph intentionally stays empty. Support subscriptions remain explicitly unavailable and do not charge the user.
