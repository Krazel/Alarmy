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
    // Web cannot schedule a reliable OS-level alarm. Native iOS adapter will implement this.
    return { ok: true, mode: "foreground-only", alarmId: alarm.id };
  },

  async cancelAlarm(alarmId) {
    return { ok: true, alarmId };
  },
};
