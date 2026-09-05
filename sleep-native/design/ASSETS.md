# Restored assets — version 0.2

At the user's request, runtime backgrounds now use the **unchanged original** SunsetBackground and NightBackground assets from `native-ios/Resources/Assets.xcassets`. The five mood faces and five sound icons are unchanged images from `native-ios/Resources/DiaryAssets`. SHA-256 equality was checked against the original checkout.

The four original MP3 resources are copied unchanged from the existing app: bosque-al-amanecer, despertar-suave, funny-alarm and lo-fi-alarm-clock. No new music was downloaded. Their original rights/provenance remain those of the existing repository; this rebuild does not claim newly obtained music licenses.

The following text records historical version 0.1 art generation. Its NightLandscape background is retained for history but is **not used by the restored interface**. The new app icon and ambient WAV remain in use; fallback synthesized alarm WAV files remain available.

---
# Original visual assets

## Night landscape

Tool: built-in imagegen, 2026-09-05. Used as a background in SwiftUI's `NightLandscape` view through the native asset catalog. This is original project artwork, not a mock screenshot.

Canonical asset: `Resources/Assets.xcassets/NightLandscape.imageset/night-landscape.png`.

Exact generation prompt:

> Create one original premium digital illustration background asset for a native iPhone sleep app. Portrait 2:3 aspect ratio. Edge to edge art, no phone frame, no UI, no typography, no letters, no logos. Restrained sophisticated editorial paper-grain illustration, deep midnight navy sky occupies top 65 percent with extremely sparse tiny dim stars, tiny warm ivory crescent moon at upper right around x75 y25. Lower 35 percent serene layered rolling mountain silhouettes in muted slate indigo and desaturated teal, still lake with extremely subtle warm moon reflection, a tiny warm light cabin far away near lower right. Very calm, dark enough for white text overlay, flat soft organic shapes, beautiful rich tonal subtlety, no purple neon, no photorealism, no harsh bright areas. Top and center mostly empty dark negative space. Output highest quality finished background for actual app use.

## Icon

Original deterministic vector-style drawing, rasterized using System.Drawing. Navy `#081422` canvas; gold `#E9C585` crescent with two short horizontal reflections; no copied icon or third-party artwork.

## Audio

All four WAV files are original synthesized audio, generated reproducibly by `Tools/generate-audio.cjs`. No samples or third-party tracks.
