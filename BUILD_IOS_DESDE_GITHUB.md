# Compilar iOS desde GitHub Actions

Este proyecto no se compila localmente en Windows. El flujo correcto es subir los cambios a GitHub, dejar que GitHub Actions compile la app nativa iOS en macOS y descargar la IPA generada.

## Resumen del flujo

1. Hacer cambios en la app nativa iOS.
2. Confirmar que los cambios importantes estan en Git.
3. Subir `main` a GitHub.
4. GitHub Actions ejecuta `Build unsigned iOS IPA`.
5. El workflow genera `Alarma-unsigned.ipa`.
6. El workflow publica tambien la release `latest-ipa`.
7. Descargar la IPA a `artifact/`.
8. Instalar la IPA en el iPhone con Sideloadly.

## Archivos importantes

- `.github/workflows/build-ios-unsigned.yml`: workflow que compila la app iOS en GitHub.
- `native-ios/project.yml`: definicion de XcodeGen para crear el proyecto Xcode.
- `native-ios/Sources/AlarmaApp.swift`: app nativa SwiftUI.
- `scripts/watch-latest-ipa.ps1`: espera la build de GitHub y descarga la IPA.
- `watch-ipa.bat`: acceso rapido al watcher desde Windows.
- `artifact/`: carpeta local donde queda la IPA descargada.

## Procedimiento normal despues de cambiar codigo

Desde `C:\Users\dmkra\Documents\Codex\Alarma`:

```powershell
git status --short
git add native-ios/Sources/AlarmaApp.swift
git commit -m "Actualiza UI iOS"
git push origin main
```

Si tambien se han cambiado workflows, scripts o documentacion, anadir esos archivos al `git add` de forma explicita.

El workflow se lanza automaticamente con cada push a `main`:

```yaml
on:
  push:
    branches:
      - main
  workflow_dispatch:
```

## Descargar la IPA

Opcion recomendada desde Windows:

```powershell
.\scripts\watch-latest-ipa.ps1
```

Tambien se puede abrir:

```powershell
.\watch-ipa.bat
```

El script busca el run de GitHub Actions correspondiente al commit actual. Cuando termina correctamente, descarga:

- `artifact/Alarma-iPhone-latest.ipa`
- `artifact/Alarma-iPhone-v1.0-build-N.ipa`

Si no encuentra la release `latest-ipa`, intenta descargar el artifact `Alarma-unsigned-ipa` directamente desde la API de GitHub. Para repos privados o limites de API puede hacer falta `GITHUB_TOKEN`.

## Descargar manualmente desde GitHub

1. Abrir el repo `https://github.com/Krazel/Alarmy`.
2. Entrar en `Actions`.
3. Abrir el workflow `Build unsigned iOS IPA`.
4. Abrir el run del commit subido.
5. Descargar el artifact `Alarma-unsigned-ipa`.
6. Descomprimirlo si GitHub lo descarga como `.zip`.
7. Usar `Alarma-unsigned.ipa`.

Tambien se puede ir a la release:

```text
https://github.com/Krazel/Alarmy/releases/tag/latest-ipa
```

y descargar `Alarma-iPhone-latest.ipa`.

## Instalar en iPhone

1. Abrir Sideloadly en Windows.
2. Conectar el iPhone por USB.
3. Seleccionar la IPA descargada desde `artifact/`.
4. Instalar con tu Apple ID.
5. En el iPhone, confiar en el perfil si iOS lo pide.

Con Apple ID gratuito, normalmente hay que refrescar o reinstalar la app cada 7 dias.

## Si falla la build

1. Abrir `Actions` en GitHub.
2. Entrar en el run fallido de `Build unsigned iOS IPA`.
3. Revisar el paso que falla:
   - `Generate native Xcode project`: problema en `native-ios/project.yml`.
   - `Build unsigned iOS app`: error de Swift/Xcode.
   - `Package unsigned IPA`: no se genero el `.app`.
   - `Publish latest IPA release`: fallo al subir la release, aunque puede existir el artifact.
4. Corregir el codigo localmente.
5. Commit y push otra vez.

## Regla practica

Para iterar la UI nativa iOS, no usar `npm run build` como validacion principal. Ese comando prepara la parte web/Capacitor, pero la validacion real de SwiftUI ocurre en GitHub Actions con macOS y Xcode.
