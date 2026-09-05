# Alarma — new native iPhone app

The **new application** is in [`sleep-native/`](sleep-native/README.md). It is a fresh SwiftUI implementation for iOS 16+, version **0.1 (build 1)**, with its own bundle ID `com.krazel.alarmasleep`.

This checkout is the isolated `codex/native-sleep-rebuild` branch. The original `Alarma` working directory was preserved. Legacy folders here are historical reference and are not compiled into the new app.

- Product, build instructions and limits: [`sleep-native/README.md`](sleep-native/README.md)
- XcodeGen project: [`sleep-native/project.yml`](sleep-native/project.yml)
- New Swift code: [`sleep-native/Sources/`](sleep-native/Sources/)
- Validation workflow: [`.github/workflows/sleep-native.yml`](.github/workflows/sleep-native.yml)
- Local downloaded builds and simulator screenshots: `artifact/` (ignored by Git)

Use the `AlarmaSleep` Xcode scheme. The older root `run.bat` and web scripts belong to the legacy prototype; they do not run the new iPhone application.
