# Alarma — native iPhone app

The application is in [`sleep-native/`](sleep-native/README.md), SwiftUI for iOS 16+, **0.2 (build 1)**. It restores the original Alarma designs and interactions and adds complete **Castellano / English** language selection.

This checkout is the isolated `codex/native-sleep-rebuild` branch. The original `Alarma` working directory is preserved. Legacy folders are references and are not compiled into the new target.

- [Product and build instructions](sleep-native/README.md)
- [XcodeGen project](sleep-native/project.yml)
- [Validation](sleep-native/VALIDATION.md)
- [CI workflow](.github/workflows/sleep-native.yml)

Use the `AlarmaSleep` Xcode scheme. Downloaded unsigned iPhone builds are under the Git-ignored `artifact/` directory.
