# Alarma — native iPhone app, rebuilt from scratch

The current application is in **[`sleep-next/`](sleep-next/README.md)**: an independent SwiftUI project for **iOS 16+**, with **Castellano and English**, new domain models, persistence, alarm/audio/Health services, original assets and a redesigned sleep journal.

- [Project and build instructions](sleep-next/README.md)
- [Native XcodeGen project](sleep-next/project.yml)
- [Sleep journal screenshots](sleep-next/Design/README.md)
- [Asset provenance](sleep-next/Design/ASSETS.md)
- [20 passed tests and iPhone package validation](sleep-next/VALIDATION.md)
- [Validation workflow](.github/workflows/sleep-next.yml)

Use the **AlarmaNext** Xcode scheme and bundle identifier `com.krazel.alarmanext`. Xcode 26 builds the app with guarded AlarmKit support on iOS 26 and sound notifications on iOS 16–25. See the app and project notes for the older-system alarm limitations.

This is the authorized `codex/native-sleep-rebuild` branch. `sleep-native/` is the previous design restoration, kept as a reference; none of its app source or assets is compiled into AlarmaNext. Other legacy folders are also reference material. The separate original `Alarma` working directory is preserved.

Downloaded unsigned iPhone builds are in the Git-ignored `artifact/` directory. Installing on an iPhone requires an Apple development signature.
