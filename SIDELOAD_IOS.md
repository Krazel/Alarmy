# Probar en iPhone sin Mac propio

Esta ruta genera una IPA sin firmar usando GitHub Actions macOS y luego la instalas desde Windows con Sideloadly.

## Seguridad del workflow

El workflow está en `.github/workflows/build-ios-unsigned.yml`.

- Solo se ejecuta manualmente con `workflow_dispatch`.
- No corre en `push`.
- No corre en `pull_request`.
- El job tiene esta condición:

```yaml
if: github.actor == github.repository_owner
```

En un repositorio personal, eso significa que solo el dueño del repo puede ejecutar el build. Si el repo pertenece a una organización, habría que cambiarlo por tu usuario exacto.

No subas Apple ID, contraseñas, certificados, `.p12`, perfiles de provisioning ni tokens privados al repo.

## Pasos

1. Sube este proyecto a un repositorio público de GitHub.
2. Ve a `Actions`.
3. Abre `Build unsigned iOS IPA`.
4. Pulsa `Run workflow`.
5. Cuando termine, descarga el artifact `Alarma-unsigned-ipa`.
6. Descomprime el artifact si GitHub lo baja como `.zip`.
7. Instala `Alarma-unsigned.ipa` con Sideloadly desde Windows.

## Limitaciones

Con Apple ID gratis, lo habitual es que la app instalada caduque a los 7 días y tengas que refrescarla o reinstalarla.

Esta IPA es para sideload y pruebas personales. No sirve para App Store ni TestFlight sin firma de Apple Developer Program.

## Importante para alarmas reales

Esto convierte la PWA en una app iOS empaquetada, pero todavía no implementa AlarmKit ni alarmas nativas. El siguiente paso técnico sería crear un plugin Capacitor/iOS que implemente el adaptador descrito en `IOS_READY.md`.
