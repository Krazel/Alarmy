# iOS-ready architecture

The current app is still a PWA, but the alarm model is now separated from the web runtime so it can be moved to a real iOS app later.

## Reusable layer

- `src/alarm-core.js`
  - Alarm data model.
  - Default alarm creation.
  - Repeat-day calculation.
  - Random sound selection.
  - Formatting helpers.

This file has no DOM, browser audio, localStorage, or PWA-specific behavior. It is the part to reuse from Capacitor/Swift later.

## Web adapter

- `src/platform-web.js`
  - Stores alarms in `localStorage`.
  - Tracks last random sound.
  - Exposes capability flags for web limitations.
  - Provides placeholder scheduling methods.

The future iOS adapter should expose the same shape, but call native code:

```js
export const platform = {
  name: "ios-native",
  capabilities: {
    canRunWhenClosed: true,
    canOverrideSilentMode: true,
    canUseMotionOnHttp: true,
    futureNativeTarget: "capacitor-ios-alarmkit",
  },
  createId() {},
  loadAlarms() {},
  saveAlarms(alarms) {},
  getLastSoundId() {},
  setLastSoundId(soundId) {},
  scheduleAlarm(alarm) {},
  cancelAlarm(alarmId) {},
};
```

## Native iOS target

The project now includes a first local Capacitor plugin draft in `packages/capacitor-alarmkit`.

When running inside Capacitor, `src/platform-web.js` checks for `window.Capacitor.Plugins.AlarmKitNative` and delegates alarm scheduling/cancellation to native Swift. In a normal browser/PWA it keeps the foreground-only fallback.

The native layer owns or should own:

- scheduling alarms while the app is closed;
- critical/priority alarm behavior where Apple permits it;
- alarm sound playback integration;
- motion detection permissions and events;
- persistence bridge if localStorage is replaced by native storage.

The web layer should remain a prototype/runtime fallback, not the source of OS-level alarm reliability.

## Current native status

Implemented draft:

- `AlarmKitNative.isAvailable()`
- `AlarmKitNative.requestAuthorization()`
- `AlarmKitNative.scheduleAlarm(alarm)`
- `AlarmKitNative.cancelAlarm({ id })`

The GitHub Actions workflow adds `NSAlarmKitUsageDescription` to the generated iOS `Info.plist`.

This still needs validation on a real iPhone running iOS 26+ because AlarmKit behavior, signing, and Sideloadly installation cannot be fully verified from Windows.
