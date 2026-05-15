# iOS-ready architecture

The product target is now closer to Sleep Cycle/Alarmy on iOS 16: the app must not be force-closed, but it should be able to run a prepared night/alarm session while the phone is locked.

## Reusable layer

- `src/alarm-core.js`
  - Alarm data model.
  - Default alarm creation.
  - Repeat-day calculation.
  - Random sound selection.
  - Formatting helpers.

This file has no DOM, browser audio, localStorage, or PWA-specific behavior. It is the part to reuse from Capacitor/Swift later.

## Platform adapter

- `src/platform-web.js`
  - Stores alarms in `localStorage`.
  - Tracks last random sound.
  - Exposes capability flags for web limitations.
  - Provides `startNightSession(alarm)` / `endNightSession()` hooks.
  - Provides placeholder scheduling methods.

The future iOS 16 adapter should expose the same shape, but call native code:

```js
export const platform = {
  name: "ios-native",
  capabilities: {
    canRunWhenClosed: false,
    canRunLockedDuringSession: true,
    canOverrideSilentMode: "best-effort",
    canUseMotionOnHttp: true,
    futureNativeTarget: "capacitor-ios-background-audio-notifications",
  },
  createId() {},
  loadAlarms() {},
  saveAlarms(alarms) {},
  getLastSoundId() {},
  setLastSoundId(soundId) {},
  scheduleAlarm(alarm) {},
  cancelAlarm(alarmId) {},
  startNightSession(alarm) {},
  endNightSession() {},
};
```

## iOS 16 native direction

For this user's phone, AlarmKit is not the main path because AlarmKit requires iOS 26+. The realistic iOS 16 path is:

- keep the app alive as a prepared night session;
- use native background audio so iOS allows the app to keep an audio session alive;
- use local notifications as a backup reminder;
- keep motion detection inside the active session;
- clearly tell the user not to force-close the app.

The app UI is therefore built around repeated alarms plus an "Empezar noche" session. Normal repeated alarms remain available, but the highest-reliability path before sleeping is starting the night session.

## Existing AlarmKit draft

The project still contains `packages/capacitor-alarmkit` as an experimental future path for iOS 26+ devices. It is not the primary implementation for iOS 16.
