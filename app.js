import * as AlarmCore from "./src/alarm-core.js";
import { platform } from "./src/platform-web.js";

const DAYS = AlarmCore.DAYS;
const SOUNDS = AlarmCore.SOUNDS;

const els = {
  addAlarmButton: document.querySelector("#addAlarmButton"),
  prepareButton: document.querySelector("#prepareButton"),
  alarmList: document.querySelector("#alarmList"),
  heroTime: document.querySelector("#heroTime"),
  heroDetail: document.querySelector("#heroDetail"),
  startNightButton: document.querySelector("#startNightButton"),
  editNextButton: document.querySelector("#editNextButton"),
  nextAlarmText: document.querySelector("#nextAlarmText"),
  nextAlarmDetail: document.querySelector("#nextAlarmDetail"),
  alarmDialog: document.querySelector("#alarmDialog"),
  alarmForm: document.querySelector("#alarmForm"),
  dialogTitle: document.querySelector("#dialogTitle"),
  closeDialogButton: document.querySelector("#closeDialogButton"),
  deleteAlarmButton: document.querySelector("#deleteAlarmButton"),
  alarmLabel: document.querySelector("#alarmLabel"),
  alarmTime: document.querySelector("#alarmTime"),
  dayGrid: document.querySelector("#dayGrid"),
  soundGrid: document.querySelector("#soundGrid"),
  randomSound: document.querySelector("#randomSound"),
  fadeInEnabled: document.querySelector("#fadeInEnabled"),
  silentOverride: document.querySelector("#silentOverride"),
  fadeDuration: document.querySelector("#fadeDuration"),
  fadeDurationOutput: document.querySelector("#fadeDurationOutput"),
  motionSnooze: document.querySelector("#motionSnooze"),
  snoozeMinutes: document.querySelector("#snoozeMinutes"),
  ringScreen: document.querySelector("#ringScreen"),
  ringLabel: document.querySelector("#ringLabel"),
  ringTime: document.querySelector("#ringTime"),
  ringSound: document.querySelector("#ringSound"),
  motionHelp: document.querySelector("#motionHelp"),
  motionFill: document.querySelector("#motionFill"),
  snoozeButton: document.querySelector("#snoozeButton"),
  stopButton: document.querySelector("#stopButton"),
  nightScreen: document.querySelector("#nightScreen"),
  nightClock: document.querySelector("#nightClock"),
  nightWakeText: document.querySelector("#nightWakeText"),
  nightSoundText: document.querySelector("#nightSoundText"),
  nightMotionText: document.querySelector("#nightMotionText"),
  endNightButton: document.querySelector("#endNightButton"),
};

let alarms = platform.loadAlarms();
let editingId = null;
let selectedDays = new Set([1, 2, 3, 4, 5]);
let selectedSounds = new Set(["aurora", "piano", "rain"]);
let audio = null;
let activeAlarm = null;
let wakeLock = null;
let motionScore = 0;
let motionHandler = null;
let prepared = false;
let nightActive = false;
let nightAlarmId = null;
let nightClockTimer = null;

function loadAlarms() {
  return platform.loadAlarms();
}

function saveAlarms() {
  platform.saveAlarms(alarms);
}

function uid() {
  return platform.createId();
}

function formatDuration(seconds) {
  return AlarmCore.formatDuration(seconds);
}

function formatDateTime(date) {
  return AlarmCore.formatDateTime(date);
}

function minutesUntil(time) {
  const [hours, minutes] = time.split(":").map(Number);
  const now = new Date();
  const then = new Date(now);
  then.setHours(hours, minutes, 0, 0);
  if (then <= now) then.setDate(then.getDate() + 1);
  return Math.round((then - now) / 60000);
}

function nextOccurrence(alarm, from = new Date()) {
  return AlarmCore.nextOccurrence(alarm, from);
}

function renderDays() {
  if (!els.dayGrid) return;
  els.dayGrid.innerHTML = "";
  DAYS.forEach((day) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = `chip ${selectedDays.has(day.key) ? "active" : ""}`;
    button.textContent = day.short;
    button.addEventListener("click", () => {
      if (selectedDays.has(day.key)) selectedDays.delete(day.key);
      else selectedDays.add(day.key);
      renderDays();
    });
    els.dayGrid.append(button);
  });
}

function renderSounds() {
  els.soundGrid.innerHTML = "";
  SOUNDS.forEach((sound) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = `chip ${selectedSounds.has(sound.id) ? "active" : ""}`;
    button.innerHTML = `<span>${sound.name}</span><i class="wave" aria-hidden="true"></i>`;
    button.style.borderColor = selectedSounds.has(sound.id) ? sound.color : "";
    button.style.setProperty("--thumb", sound.thumb);
    button.style.setProperty("--thumb-tint", `${sound.color}22`);
    button.addEventListener("click", () => {
      if (selectedSounds.has(sound.id) && selectedSounds.size > 1) selectedSounds.delete(sound.id);
      else selectedSounds.add(sound.id);
      renderSounds();
    });
    els.soundGrid.append(button);
  });
}

function renderAlarms() {
  const sorted = [...alarms].sort((a, b) => a.time.localeCompare(b.time));
  els.alarmList.innerHTML = "";
  if (!sorted.length) {
    const empty = document.createElement("p");
    empty.className = "empty-state";
    empty.textContent = "Aún no hay alarmas.";
    els.alarmList.append(empty);
  }

  sorted.forEach((alarm) => {
    const card = document.createElement("article");
    card.className = "alarm-card";
    card.tabIndex = 0;
    card.innerHTML = `
      <div>
        <span class="alarm-time">${alarm.time}</span>
        <span class="alarm-title">${alarm.label || "Alarma"}</span>
        <div class="alarm-meta">
          <span class="pill">Aleatoria</span>
          <span class="pill">Subida ${formatDuration(alarm.fadeDuration)}</span>
          <span class="pill">${alarm.silentOverride ?? true ? "Modo silencio" : "Respeta silencio"}</span>
          <span class="pill">${alarm.motionSnooze ? "Mover pospone" : "Botón pospone"}</span>
        </div>
      </div>
      <label class="switch" aria-label="${alarm.enabled ? "Desactivar" : "Activar"} alarma">
        <input type="checkbox" ${alarm.enabled ? "checked" : ""} />
        <span></span>
      </label>
    `;
    const switchControl = card.querySelector(".switch");
    const toggle = card.querySelector("input");
    switchControl.addEventListener("click", (event) => {
      event.stopPropagation();
    });
    toggle.addEventListener("change", () => {
      alarm.enabled = toggle.checked;
      saveAlarms();
      if (alarm.enabled) void platform.scheduleAlarm(alarm);
      else void platform.cancelAlarm(alarm.id);
      render();
    });
    card.addEventListener("click", (event) => {
      if (event.target.closest(".switch")) return;
      openDialog(alarm.id);
    });
    card.addEventListener("keydown", (event) => {
      if (event.key === "Enter") openDialog(alarm.id);
    });
    els.alarmList.append(card);
  });

  renderNextAlarm();
}

function daySummary(days) {
  if (!days || days.length === 0) return "Una vez";
  if (days.length === 7) return "Todos los días";
  const weekday = [1, 2, 3, 4, 5];
  if (weekday.every((day) => days.includes(day)) && days.length === 5) return "Laborables";
  return DAYS.filter((day) => days.includes(day.key)).map((day) => day.short).join(" ");
}

function soundName(id) {
  return AlarmCore.soundName(id);
}

function renderNextAlarm() {
  const upcoming = alarms
    .filter((alarm) => alarm.enabled)
    .map((alarm) => ({ alarm, date: nextOccurrence(alarm) }))
    .filter((entry) => entry.date)
    .sort((a, b) => a.date - b.date)[0];

  if (!upcoming) {
    els.nextAlarmText.textContent = "Sin alarmas activas";
    els.nextAlarmDetail.textContent = "Activa o crea una alarma para empezar.";
    return;
  }

  els.nextAlarmText.textContent = `${upcoming.alarm.time} · ${upcoming.alarm.label || "Alarma"}`;
  els.nextAlarmDetail.textContent = `Sonará ${formatDateTime(upcoming.date)}.`;
}

function getNextUpcomingAlarm() {
  return alarms
    .filter((alarm) => alarm.enabled)
    .map((alarm) => ({ alarm, date: nextOccurrence(alarm) }))
    .filter((entry) => entry.date)
    .sort((a, b) => a.date - b.date)[0] || null;
}

function renderSleepHero() {
  const upcoming = getNextUpcomingAlarm();
  if (!upcoming) {
    els.heroTime.textContent = "--:--";
    els.heroDetail.textContent = "Activa una alarma para empezar la noche.";
    els.startNightButton.disabled = true;
    return;
  }

  const alarm = upcoming.alarm;
  const sounds = alarm.randomSound ? "música aleatoria" : soundName(alarm.soundIds?.[0]);
  els.heroTime.textContent = alarm.time;
  els.heroDetail.textContent = `${sounds} · subida ${formatDuration(alarm.fadeDuration)}`;
  els.startNightButton.disabled = false;
}

function renderFadeOutput() {
  const value = Number(els.fadeDuration.value);
  const min = Number(els.fadeDuration.min);
  const max = Number(els.fadeDuration.max);
  const progress = ((value - min) / (max - min)) * 100;
  els.fadeDurationOutput.value = formatDuration(value);
  els.fadeDuration.style.setProperty("--range-progress", `${progress}%`);
}

function defaultAlarm() {
  return AlarmCore.createDefaultAlarm(uid());
}

function openDialog(id = null) {
  editingId = id;
  const alarm = id ? alarms.find((item) => item.id === id) : defaultAlarm();
  els.dialogTitle.textContent = id ? "Editar alarma" : "Nueva alarma";
  els.deleteAlarmButton.hidden = !id;
  els.alarmLabel.value = alarm.label || "";
  els.alarmTime.value = alarm.time;
  selectedDays = new Set();
  selectedSounds = new Set(alarm.soundIds?.length ? alarm.soundIds : ["aurora"]);
  els.randomSound.checked = alarm.randomSound;
  els.fadeInEnabled.checked = alarm.fadeInEnabled;
  els.silentOverride.checked = alarm.silentOverride ?? true;
  els.fadeDuration.value = alarm.fadeDuration;
  els.motionSnooze.checked = alarm.motionSnooze;
  els.snoozeMinutes.value = alarm.snoozeMinutes;
  renderDays();
  renderSounds();
  renderFadeOutput();
  els.alarmDialog.showModal();
}

function closeDialog() {
  els.alarmDialog.close();
}

function saveForm() {
  const snoozeMinutes = Math.max(1, Math.min(60, Number(els.snoozeMinutes.value) || 5));
  const alarm = {
    id: editingId || uid(),
    label: els.alarmLabel.value.trim() || "Alarma",
    time: els.alarmTime.value,
    days: [],
    soundIds: [...selectedSounds],
    randomSound: els.randomSound.checked,
    fadeInEnabled: els.fadeInEnabled.checked,
    silentOverride: els.silentOverride.checked,
    fadeDuration: Number(els.fadeDuration.value),
    motionSnooze: els.motionSnooze.checked,
    snoozeMinutes,
    enabled: true,
  };

  if (editingId) alarms = alarms.map((item) => (item.id === editingId ? alarm : item));
  else alarms.push(alarm);
  saveAlarms();
  if (alarm.enabled) void platform.scheduleAlarm(alarm);
  else void platform.cancelAlarm(alarm.id);
  closeDialog();
  render();
}

function deleteCurrentAlarm() {
  if (!editingId) return;
  alarms = alarms.filter((alarm) => alarm.id !== editingId);
  void platform.cancelAlarm(editingId);
  saveAlarms();
  closeDialog();
  render();
}

function chooseSound(alarm) {
  const choice = AlarmCore.chooseSoundId(alarm, platform.getLastSoundId());
  platform.setLastSoundId(choice);
  return choice;
}

async function ensureAudio() {
  if (!audio) {
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    audio = { ctx: new AudioContext(), nodes: [], gain: null, interval: null };
  }
  if (audio.ctx.state === "suspended") await audio.ctx.resume();
}

async function prepareDevice() {
  try {
    await ensureAudio();
    await platform.requestNativeAlarmAuthorization?.();
    prepared = true;
    els.prepareButton.textContent = "Preparado";
    els.prepareButton.disabled = true;
  } catch {
    els.prepareButton.textContent = "Toca otra vez";
  }

  if (els.motionSnooze?.checked || activeAlarm?.motionSnooze) {
    try {
      await requestMotionPermission();
    } catch {
      // Motion permission is best-effort in browsers.
    }
  }
}

function updateNightClock() {
  const now = new Date();
  els.nightClock.textContent = `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`;
}

async function startNight() {
  const upcoming = getNextUpcomingAlarm();
  if (!upcoming) return;
  const alarm = upcoming.alarm;
  nightActive = true;
  nightAlarmId = alarm.id;
  els.nightWakeText.textContent = `Despertar a las ${alarm.time}`;
  els.nightSoundText.textContent = alarm.randomSound
    ? `Música aleatoria entre ${alarm.soundIds.length} sonidos`
    : soundName(alarm.soundIds?.[0]);
  els.nightMotionText.textContent = alarm.motionSnooze
    ? "Mover el móvil pospone"
    : "Posponer solo con botón";
  els.nightScreen.hidden = false;
  updateNightClock();
  window.clearInterval(nightClockTimer);
  nightClockTimer = window.setInterval(updateNightClock, 1000);
  await prepareDevice();
  await requestWakeLock();
  await platform.startNightSession?.(alarm);
}

async function endNight() {
  nightActive = false;
  nightAlarmId = null;
  window.clearInterval(nightClockTimer);
  nightClockTimer = null;
  els.nightScreen.hidden = true;
  await platform.endNightSession?.();
  await releaseWakeLock();
}

function stopAudio() {
  if (!audio) return;
  audio.nodes.forEach((node) => {
    try {
      node.stop?.();
      node.disconnect?.();
    } catch {
      // Node already stopped.
    }
  });
  if (audio.interval) window.clearInterval(audio.interval);
  audio.nodes = [];
  audio.gain = null;
  audio.interval = null;
}

async function playSound(soundId, alarm) {
  await ensureAudio();
  stopAudio();
  const sound = SOUNDS.find((item) => item.id === soundId) || SOUNDS[0];
  const ctx = audio.ctx;
  const master = ctx.createGain();
  const compressor = ctx.createDynamicsCompressor();
  master.gain.setValueAtTime(alarm.fadeInEnabled ? 0.04 : 0.85, ctx.currentTime);
  if (alarm.fadeInEnabled) {
    master.gain.exponentialRampToValueAtTime(0.9, ctx.currentTime + alarm.fadeDuration);
  }
  master.connect(compressor).connect(ctx.destination);
  audio.gain = master;

  if (sound.id === "rain" || sound.id === "waves") {
    makeNoisePad(ctx, master, sound.id);
  } else {
    makeTonePattern(ctx, master, sound);
  }

  if (navigator.vibrate) navigator.vibrate([250, 120, 250]);
}

function makeTonePattern(ctx, master, sound) {
  const notes = [0, 5, 9, 12].map((step) => sound.base * 2 ** (step / 12));
  const schedule = () => {
    notes.forEach((freq, index) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = sound.id === "bells" ? "sine" : "triangle";
      osc.frequency.value = freq;
      gain.gain.setValueAtTime(0.0001, ctx.currentTime + index * 0.45);
      gain.gain.exponentialRampToValueAtTime(0.28, ctx.currentTime + index * 0.45 + 0.04);
      gain.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + index * 0.45 + 1.35);
      osc.connect(gain).connect(master);
      osc.start(ctx.currentTime + index * 0.45);
      osc.stop(ctx.currentTime + index * 0.45 + 1.5);
      audio.nodes.push(osc, gain);
    });
  };
  schedule();
  audio.interval = window.setInterval(schedule, 2800);
}

function makeNoisePad(ctx, master, type) {
  const buffer = ctx.createBuffer(1, ctx.sampleRate * 2, ctx.sampleRate);
  const data = buffer.getChannelData(0);
  for (let i = 0; i < data.length; i += 1) data[i] = Math.random() * 2 - 1;

  const source = ctx.createBufferSource();
  const filter = ctx.createBiquadFilter();
  const gain = ctx.createGain();
  source.buffer = buffer;
  source.loop = true;
  filter.type = type === "waves" ? "lowpass" : "bandpass";
  filter.frequency.value = type === "waves" ? 420 : 900;
  gain.gain.value = type === "waves" ? 0.28 : 0.18;
  source.connect(filter).connect(gain).connect(master);
  source.start();
  audio.nodes.push(source, filter, gain);

  const lfo = ctx.createOscillator();
  const lfoGain = ctx.createGain();
  lfo.frequency.value = type === "waves" ? 0.16 : 0.5;
  lfoGain.gain.value = type === "waves" ? 220 : 90;
  lfo.connect(lfoGain).connect(filter.frequency);
  lfo.start();
  audio.nodes.push(lfo, lfoGain);
}

async function requestWakeLock() {
  try {
    if ("wakeLock" in navigator) wakeLock = await navigator.wakeLock.request("screen");
  } catch {
    wakeLock = null;
  }
}

async function releaseWakeLock() {
  try {
    await wakeLock?.release();
  } catch {
    // Ignore wake lock release failures.
  }
  wakeLock = null;
}

async function requestMotionPermission() {
  if (!window.isSecureContext) {
    return {
      ok: false,
      reason: "El movimiento en iPhone requiere HTTPS. Usa el botón de posponer.",
    };
  }
  const DeviceMotion = window.DeviceMotionEvent;
  if (DeviceMotion?.requestPermission) {
    const result = await DeviceMotion.requestPermission();
    return {
      ok: result === "granted",
      reason: result === "granted" ? "" : "Permiso de movimiento denegado. Actívalo en Safari.",
    };
  }
  return {
    ok: "DeviceMotionEvent" in window,
    reason: "Este navegador no expone el sensor de movimiento.",
  };
}

async function startMotionSnooze(alarm) {
  stopMotionSnooze();
  els.motionFill.style.width = "0%";
  motionScore = 0;
  if (!alarm.motionSnooze) {
    els.motionHelp.textContent = "Usa los botones para apagar o posponer.";
    return;
  }

  let permission = { ok: false, reason: "El sensor de movimiento no está disponible. Usa el botón." };
  try {
    permission = await requestMotionPermission();
  } catch {
    permission = { ok: false, reason: "No se pudo pedir permiso de movimiento. Usa el botón." };
  }

  if (!permission.ok) {
    els.motionHelp.textContent = permission.reason;
    return;
  }

  els.motionHelp.textContent = "Mueve el móvil para posponer";
  motionHandler = (event) => {
    const acc = event.accelerationIncludingGravity || event.acceleration;
    if (!acc) return;
    const magnitude = Math.sqrt((acc.x || 0) ** 2 + (acc.y || 0) ** 2 + (acc.z || 0) ** 2);
    const movement = Math.max(0, magnitude - 10);
    motionScore = Math.max(0, motionScore * 0.86 + movement * 7);
    els.motionFill.style.width = `${Math.min(100, motionScore)}%`;
    if (motionScore > 92) snoozeActiveAlarm();
  };
  window.addEventListener("devicemotion", motionHandler);
}

function stopMotionSnooze() {
  if (motionHandler) window.removeEventListener("devicemotion", motionHandler);
  motionHandler = null;
}

async function ringAlarm(alarm) {
  activeAlarm = alarm;
  const soundId = chooseSound(alarm);
  els.ringLabel.textContent = alarm.label || "Alarma";
  els.ringTime.textContent = alarm.time;
  els.ringSound.textContent = alarm.silentOverride
    ? "Modo alarma prioritaria"
    : "Mueve el móvil para posponer";
  els.nightScreen.hidden = true;
  els.ringScreen.hidden = false;
  if (!prepared) {
    els.motionHelp.textContent = "Si no suena, toca Posponer o Apagar y luego Preparar sonido.";
  }
  await requestWakeLock();
  await playSound(soundId, alarm);
  await startMotionSnooze(alarm);
}

function stopActiveAlarm() {
  stopAudio();
  stopMotionSnooze();
  releaseWakeLock();
  if (activeAlarm && (!activeAlarm.days || activeAlarm.days.length === 0)) {
    alarms = alarms.map((alarm) => (alarm.id === activeAlarm.id ? { ...alarm, enabled: false } : alarm));
    saveAlarms();
  }
  activeAlarm = null;
  nightActive = false;
  nightAlarmId = null;
  window.clearInterval(nightClockTimer);
  nightClockTimer = null;
  els.ringScreen.hidden = true;
  render();
}

function snoozeActiveAlarm() {
  if (!activeAlarm) return;
  const snoozed = {
    ...activeAlarm,
    id: uid(),
    label: `${activeAlarm.label || "Alarma"} · pospuesta`,
    time: timePlusMinutes(activeAlarm.snoozeMinutes),
    days: [],
    enabled: true,
  };
  stopActiveAlarm();
  alarms.push(snoozed);
  saveAlarms();
  render();
}

function timePlusMinutes(minutes) {
  return AlarmCore.timePlusMinutes(minutes);
}

function checkAlarms() {
  if (activeAlarm) return;
  const now = new Date();
  const current = `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`;
  const today = now.getDay();
  const due = alarms.find((alarm) => {
    if (!alarm.enabled || alarm.time !== current) return false;
    if (alarm.lastRingDate === now.toDateString()) return false;
    return !alarm.days?.length || alarm.days.includes(today);
  });
  if (!due) return;
  due.lastRingDate = now.toDateString();
  saveAlarms();
  ringAlarm(due);
}

function seedFirstAlarm() {
  if (alarms.length) return;
  const first = defaultAlarm();
  first.time = "07:30";
  first.label = "Mañana";

  const second = defaultAlarm();
  second.id = uid();
  second.time = "08:45";
  second.label = "Segunda alarma";
  second.soundIds = ["piano"];
  second.randomSound = false;
  second.enabled = false;

  const third = defaultAlarm();
  third.id = uid();
  third.time = "09:30";
  third.label = "Tercera alarma";
  third.soundIds = ["rain"];
  third.randomSound = false;
  third.enabled = false;

  alarms = [first, second, third];
  saveAlarms();
}

function render() {
  renderAlarms();
  renderSleepHero();
}

function registerServiceWorker() {
  if ("serviceWorker" in navigator) {
    navigator.serviceWorker.register("sw.js").catch(() => {});
  }
}

els.addAlarmButton.addEventListener("click", () => openDialog());
els.editNextButton.addEventListener("click", () => {
  const upcoming = getNextUpcomingAlarm();
  openDialog(upcoming?.alarm.id || null);
});
els.startNightButton.addEventListener("click", startNight);
els.endNightButton.addEventListener("click", endNight);
els.prepareButton.addEventListener("click", prepareDevice);
els.closeDialogButton.addEventListener("click", closeDialog);
els.deleteAlarmButton.addEventListener("click", deleteCurrentAlarm);
els.alarmForm.addEventListener("submit", (event) => {
  event.preventDefault();
  saveForm();
});
els.fadeDuration.addEventListener("input", renderFadeOutput);
els.snoozeButton.addEventListener("click", snoozeActiveAlarm);
els.stopButton.addEventListener("click", stopActiveAlarm);

document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "visible") requestWakeLock();
});

seedFirstAlarm();
renderDays();
renderSounds();
renderFadeOutput();
render();
registerServiceWorker();
window.setInterval(checkAlarms, 1000);
