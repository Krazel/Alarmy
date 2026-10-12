# Noche y análisis — candidata 1.3 (1)

Petición del 12 de octubre: noche con onda real, finalizar deslizando hacia arriba,
análisis nocturno, estadísticas y modos sin alarma / exacta / ventana inteligente.
`01-noche-gesto.png` es una propuesta generada con Imágenes; prompt y hash adjuntos.
El fondo conserva el NightBackground aprobado. La propuesta no es evidencia nativa.

## Datos y límites
- Épocas acústicas de 30 s derivadas de todos los cuadros PCM de 20 ms.
- Reposo estimado: tramos observados tranquilos de al menos 10 min, no sueño clínico.
- Vigilia, ligero, profundo y REM solo de Salud. Calidad: valoración del usuario.
- Sin audio conservado: clasificación local temporal, eliminación tras clasificar y
  recuperación de la limpieza al abrir. Resúmenes sin audio conservados al caducar.
- Ventana de 15/30/45/60 min antes de la hora elegida. Regla acústica experimental:
  10 min tranquilos continuos seguidos de actividad. No determina fase ni mejora clínica.
  Alarma límite programada primero; se sustituye solo después de guardar la anticipada.
- Los tres botones inferiores se conservan. Estadísticas se abre desde Diario.
- Horarios se calculan en círculo alrededor de medianoche; datos ausentes no son ceros.

Validación enfocada correcta: **23 pruebas pasadas, 0 fallos y 0 omitidas**, más
compilación Release iPhone. Fuente `b02b7d4bea6a4b3d449d11849d50f9e4dc961b84`.
[Run nativo](https://github.com/Krazel/Alarmy/actions/runs/38315535656) ·
[Recibo](validation.json). Simulador iPhone 17 Pro, iOS 26.4.1.

Prueba nocturna física, consumo y despertar
con pantalla bloqueada pendientes. No se ha subido esta candidata a TestFlight;
la entrega interna vigente continúa siendo 1.2 (1).

## Referencias
- [AASM: Consumer Sleep Technology](https://aasm.org/advocacy/position-statements/consumer-sleep-technology/): no atribuir validación clínica a estimaciones de consumo.
- [Apple AlarmKit](https://developer.apple.com/documentation/alarmkit): alarma del sistema cuando está disponible; se conserva la vía iOS16–25 documentada en la app.
- [GitHub Actions](https://docs.github.com/en/billing/concepts/product-billing/github-actions): runner estándar en el repositorio público existente, sin planes ni runners de pago.

El botón principal de análisis controla el micrófono. Guardar grabaciones es una
opción subordinada, deshabilitada al apagar el análisis. El consentimiento del
micrófono se solicita al empezar la primera noche con análisis habilitado.

## Capturas nativas revisadas

- [30-es-analysis-mode](runtime/30-es-analysis-mode.png)
- [31-es-analysis-night](runtime/31-es-analysis-night.png)
- [32-es-statistics](runtime/32-es-statistics.png)
- [33-es-smart-mode](runtime/33-es-smart-mode.png)
- [34-es-smart-night](runtime/34-es-smart-night.png)
- [35-en-exact-night](runtime/35-en-exact-night.png)
- [36-en-diary](runtime/36-en-diary.png)
- [37-en-night-analysis](runtime/37-en-night-analysis.png)

El gesto parcial mantiene la sesión y el completo la termina, comprobado por UI.
Los tests de UI desactivan el hardware: estas capturas no prueban la onda con
micrófono real ni una alarma del sistema bloqueada. Las pruebas deterministas
verifican la acumulación de épocas, huecos, intervalos sin duplicados, ventana y archivo antiguo.
La primera ejecución falló por cierre de Xcode; se normalizó UTF-8 y se corrigió
un sombreado de variable encontrado al compilar. Una ejecución intermedia fue
cancelada al sustituirla por la candidata final. No se ocultan como pruebas pasadas.
