# Reference parity — Alarma 0.2

Reference: original `native-ios/Sources/AlarmaApp.swift` at `f420f66`. This document records the user's requested design and interaction restoration, not a new design proposal.

| Original surface | Restored behavior |
| --- | --- |
| Sunset/night home | Same source backgrounds, palette, serif Alarma heading, main clock card, theme button and Start the night button. A native tab-bar background improves contrast. |
| Clock | Independent vertical drags for hours/minutes; wheel editor; VoiceOver adjustable actions. |
| Edit alarm | Same structure: time, possible songs, gradual/full volume, iPhone volume control, movement snooze, light, snooze presets and Save. |
| Music | Same four original MP3 files, multi-selection and random rotation, previews, Files import and deletion of custom songs. |
| Active night | Same clock/status/hint/End layout. Automatic opening of the journal after ending is configurable. |
| Ringing/snooze | Same screens and actions. Rebuilt audio ramp, backup reminders, motion snooze and display restoration. |
| Journal | Same weekly/month calendar, sleep-chart card, five illustrated moods, sound summary and notes card. Notes save automatically, including days without a recorded night. |
| Sleep graph | Same card and stage legend. Actual HealthKit intervals replace old movement/noise heuristics. No compatible Health records means No data; no invented sleep score. |
| Night sounds | Local clips, category filtering/counts and playback. Apple's local classifier replaces amplitude-only labels; uncertain clips stay unclassified/Other sound. |
| Settings | Appearance, night tracking, retention, alarm controls and support layout. Added System/Castellano/English selection and explicit Health connection. |
| Support | Still pending, as in the reference. Coming-soon text and no charges; no fake subscription activation or ad integration. |
| Languages | Complete app strings in ES/EN, localized calendar formatting and notifications, native permission descriptions. In-app language changes rebuild cached controls without changing saved data. |

The exact background, mood/sound image and MP3 bytes match the original checkout. The original checkout's tracked files remain unchanged. Tests and real simulator captures are documented in `VALIDATION.md`.
