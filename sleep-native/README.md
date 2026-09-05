# Alarma — native iPhone app

SwiftUI for iOS 16+, version **0.2 (build 1)**. The original Alarma presentation is restored with its exact sunset/night background images, colors, typography, cards and navigation. The rebuilt persistence, audio lifecycle and notifications remain separate from the views.

## Restored product

- **Alarmas / Alarms**: one main nightly alarm; adjust hours and minutes independently by dragging the large clock, or open the wheel editor. Start and end the night from the original screens.
- Original four bundled songs, previews, selection and rotation without an immediate repeat. Import playable audio from Files (up to 50 MB), preview and remove it. Empty selections fall back to the original default songs when saved.
- Gradual volume (1–10 minutes), direct full app volume, native iPhone volume control, movement snooze, 1/3/5/10/15-minute snooze choices and gradual screen brightness over 3/5/10/15 minutes when the alarm rings. Previous brightness and idle-timer settings are restored on exit.
- **Diario / Journal**: weekly calendar, month selector and full calendar; five original illustrated wake-up moods; notes saved automatically for any past/present day; night sound categories, counts, filtering and playback.
- The original sleep-chart card reads awake/light/deep/REM intervals from **Apple Health**, with explicit opt-in. It preserves actual timestamps and gaps and selects a single data source per waking day to avoid combining overlapping device records. Unspecified sleep is never labelled as a measured phase. Without compatible records, it shows No data. It does not infer phases or sleep scores from phone movement/noise.
- Optional microphone recording: 12-second clips, 120-clip cap, local classification using Apple's SoundAnalysis model. Only recognized top predictions at confidence ≥0.65 receive snore/breathing/cough/voice labels; other clips remain Other sound. Counts describe saved clips, not clinical events.
- Delete recordings after 1/7/30/90 days, keep indefinitely, or delete all. Cleanup runs when the app is used. All data stays on the iPhone.
- **Ajustes / Settings**: original groups, automatic/light/dark theme, recording/retention, open journal after alarm, snooze/light settings and support panel. Support is explicitly marked coming soon; no transaction, ad SDK or subscription is active.
- **Castellano and English**: select System, Castellano or English in Settings. UI, dynamic messages, dates, notifications and permission explanations are localized. The app selection persists; iOS permission dialogs follow the device's app/system language.

## Build

The app lives entirely in this directory, in the isolated `codex/native-sleep-rebuild` worktree. Original `Alarma` checkout and legacy implementation are unchanged. On macOS, install XcodeGen and run:

```sh
xcodegen generate
xcodebuild -project AlarmaSleep.xcodeproj -scheme AlarmaSleep -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO test
```

For an iPhone, set a signing team and enable HealthKit on `com.krazel.alarmasleep`. The CI artifact is **unsigned**, so it is not a TestFlight/App Store install. CI publishes only build/test artifacts, not a release.

The separate bundle does not automatically import the old app's sandbox. Version 0.1 JSON can still be opened; optional new fields receive defaults, and its old mood values are migrated. Its historical nights remain in the journal; the main nightly alarm is restored with the original song defaults.

## Device validation still needed

Continuous alarm audio requires starting the night; an audible ambient track maintains its audio session. Ordinary local notification backups follow iOS Silent/Focus rules. A force-quit, call/audio interruption, depleted battery or OS termination can stop continuous audio. Interrupted nights are checkpointed and the backup reminder is preserved. No silent audio loop, programmatic system-volume slider manipulation or critical-alert entitlement is used.

The screen-light feature requires the screen to stay on; it cannot illuminate a locked display. Physical testing is still required for overnight locked-screen operation, movement snooze, volume/brightness, interruptions, imported songs, microphone classifications and real Health data. Sound labels are estimates and may include ambient playback; they are not medical findings.

## Sources and evidence

Presentation and legacy resources: `native-ios/Sources/AlarmaApp.swift` and `native-ios/Resources` at repository commit `f420f66`. The original designs were restored at the user's request.

- [Apple SoundAnalysis](https://developer.apple.com/documentation/soundanalysis/snclassifysoundrequest/)
- [Apple Health sleep categories](https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis)
- [Reference parity](PARITY.md)
- [Native screenshots in both languages](design/restored-runtime/README.md)
- [Validation](VALIDATION.md)
- [Asset provenance](design/ASSETS.md)
