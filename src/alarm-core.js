export const DAYS = [
  { key: 1, short: "L" },
  { key: 2, short: "M" },
  { key: 3, short: "X" },
  { key: 4, short: "J" },
  { key: 5, short: "V" },
  { key: 6, short: "S" },
  { key: 0, short: "D" },
];

export const SOUNDS = [
  {
    id: "aurora",
    name: "Amanecer",
    base: 220,
    color: "#e86b46",
    thumb: "linear-gradient(160deg, #ffe5ae 0%, #f78d58 46%, #7d4329 100%)",
  },
  {
    id: "piano",
    name: "Acustico Suave",
    base: 262,
    color: "#d8854c",
    thumb: "linear-gradient(135deg, #5a2d19 0%, #c1773e 52%, #f5c07a 100%)",
  },
  {
    id: "rain",
    name: "Piano Relajante",
    base: 168,
    color: "#b77c5a",
    thumb: "linear-gradient(90deg, #16120f 0 18%, #f7ead1 18% 28%, #16120f 28% 42%, #f7ead1 42% 54%, #16120f 54% 68%, #f7ead1 68% 80%, #16120f 80%)",
  },
  {
    id: "bells",
    name: "Brisa del Mar",
    base: 392,
    color: "#6ba8bd",
    thumb: "linear-gradient(180deg, #bfe8f4 0%, #6fa9bd 46%, #f2d5ad 48%, #557f8a 100%)",
  },
  {
    id: "forest",
    name: "Bosque Claro",
    base: 196,
    color: "#86a661",
    thumb: "linear-gradient(145deg, #f0d49a 0%, #91a85d 48%, #3e5a34 100%)",
  },
  {
    id: "waves",
    name: "Olas Lentas",
    base: 132,
    color: "#79b2c4",
    thumb: "linear-gradient(160deg, #d7f3f1 0%, #78b7c7 50%, #345c65 100%)",
  },
];

export function createDefaultAlarm(id) {
  return {
    id,
    label: "Manana",
    time: "07:30",
    days: [1, 2, 3, 4, 5],
    soundIds: ["aurora", "piano", "rain"],
    randomSound: true,
    fadeInEnabled: true,
    silentOverride: true,
    fadeDuration: 180,
    motionSnooze: true,
    snoozeMinutes: 5,
    enabled: true,
  };
}

export function normalizeAlarm(alarm, createId) {
  return {
    ...createDefaultAlarm(alarm.id || createId()),
    ...alarm,
    soundIds: alarm.soundIds?.length ? alarm.soundIds : ["aurora"],
    days: Array.isArray(alarm.days) ? alarm.days : [],
    silentOverride: alarm.silentOverride ?? true,
  };
}

export function formatDuration(seconds) {
  if (seconds < 60) return `${seconds} s`;
  return `${seconds / 60} min`;
}

export function formatDateTime(date) {
  return new Intl.DateTimeFormat("es-ES", {
    weekday: "short",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

export function nextOccurrence(alarm, from = new Date()) {
  const [hours, minutes] = alarm.time.split(":").map(Number);
  const repeatDays = alarm.days || [];
  for (let i = 0; i <= 7; i += 1) {
    const candidate = new Date(from);
    candidate.setDate(from.getDate() + i);
    candidate.setHours(hours, minutes, 0, 0);
    const dayMatches = repeatDays.length === 0 || repeatDays.includes(candidate.getDay());
    if (dayMatches && candidate > from) return candidate;
  }
  return null;
}

export function soundName(id) {
  return SOUNDS.find((sound) => sound.id === id)?.name || "Sonido";
}

export function chooseSoundId(alarm, lastSoundId) {
  const ids = alarm.soundIds?.length ? alarm.soundIds : ["aurora"];
  if (!alarm.randomSound || ids.length === 1) return ids[0];
  const pool = ids.filter((id) => id !== lastSoundId);
  return (pool.length ? pool : ids)[Math.floor(Math.random() * (pool.length || ids.length))];
}

export function timePlusMinutes(minutes, from = new Date()) {
  const date = new Date(from.getTime() + minutes * 60000);
  return `${String(date.getHours()).padStart(2, "0")}:${String(date.getMinutes()).padStart(2, "0")}`;
}
