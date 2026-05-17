# Build Android

Alarma tiene version Android nativa en:

```text
android-native/
```

ID fijo:

```text
com.dmkr.alarma
```

Generar APK debug:

```powershell
npm run android:debug
```

APK resultante:

```text
android-native/app/build/outputs/apk/debug/app-debug.apk
```

Objetivo para releases:

```text
artifact/Alarma-Android-v1.0-build-N.apk
artifact/old/
```

Debe mantenerse la misma regla que iOS: una sola build visible por plataforma en `artifact/` y builds antiguas en `artifact/old/`.
