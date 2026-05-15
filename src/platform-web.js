import { normalizeAlarm } from "./alarm-core.js";

const STORAGE_KEY = "alarma.pwa.alarms.v1";
const LAST_SOUND_KEY = "alarma.pwa.lastSound.v1";

export const platform = {
  name: "web-pwa",
  capabilities: {
    canRunWhenClosed: false,
    canOverrideSilentMode: false,
    canUseMotionOnHttp: false,
    futureNativeTarget: "capacitor-ios-alarmkit",
  },

  createId() {
    return crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}-${Math.random()}`;
  },

  loadAlarms() {
    try {
      const stored = JSON.parse(localStorage.getItem(STORAGE_KEY) || "[]");
      return Array.isArray(stored)
        ? stored.map((alarm) => normalizeAlarm(alarm, () => this.createId()))
        : [];
    } catch {
      return [];
    }
  },

  saveAlarms(alarms) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(alarms));
  },

  getLastSoundId() {
    return localStorage.getItem(LAST_SOUND_KEY);
  },

  setLastSoundId(soundId) {
    localStorage.setItem(LAST_SOUND_KEY, soundId);
  },

  async scheduleAlarm(alarm) {
    const native = nativeAlarmKit();
    if (native) {
      const result = await native.scheduleAlarm({
        id: alarm.id,
        label: alarm.label || "Alarma",
        time: alarm.time,
        days: alarm.days || [],
        snoozeMinutes: alarm.snoozeMinutes || 5,
      });
      return { ok: !!result.scheduled, mode: "alarmkit", alarmId: alarm.id, nativeId: result.nativeId };
    }

    // Web cannot schedule a reliable OS-level alarm.
    return { ok: true, mode: "foreground-only", alarmId: alarm.id };
  },

  async cancelAlarm(alarmId) {
    const native = nativeAlarmKit();
    if (native) {
      const result = await native.cancelAlarm({ id: alarmId });
      return { ok: !!result.cancelled, alarmId };
    }

    return { ok: true, alarmId };
  },

  async requestNativeAlarmAuthorization() {
    const native = nativeAlarmKit();
    if (!native) return { authorized: false, mode: "web" };
    const availability = await native.isAvailable();
    if (!availability.available) {
      return { authorized: false, mode: "alarmkit", reason: availability.reason };
    }
    const result = await native.requestAuthorization();
    return { authorized: !!result.authorized, mode: "alarmkit" };
  },
};

function nativeAlarmKit() {
  return globalThis.Capacitor?.Plugins?.AlarmKitNative || null;
}
