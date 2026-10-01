# Alarma — nueva aplicación nativa

Proyecto independiente escrito desde cero en `sleep-next`. Los diseños anteriores sirven de referencia visual; este proyecto no compila, importa ni enlaza código o recursos de `sleep-native` ni de la aplicación original.

[Ver el diseño del diario](Design/README.md) · [Pruebas y paquete para iPhone](VALIDATION.md) · [Estado vigente](../ESTADO.md)

## Abrir y compilar

Requiere macOS, Xcode 26 o posterior y XcodeGen:

```sh
cd sleep-next
xcodegen generate
open AlarmaNext.xcodeproj
```

Seleccionar el equipo de desarrollo para instalar en un iPhone. Identificador independiente: `com.krazel.alarmanext`. Despliegue mínimo: **iOS 16**. El SDK de Xcode 26 permite compilar el uso condicionado de AlarmKit. La compilación sin firma no se puede instalar directamente como una app de App Store.

## Lo que incluye

- Alarma de la próxima noche, selección de sonidos sin repetir el anterior cuando hay alternativas, importación de audio, volumen progresivo en primer plano, posponer y movimiento para posponer con la app abierta.
- AlarmKit a partir de iOS 26; notificaciones con sonido de hasta 29 segundos en iOS 16–25. En versiones anteriores hay que activar sonidos y desactivar Silencio/Concentración. La app explica estos límites. No se usa audio silencioso para mantenerla artificialmente activa.
- Sesión nocturna persistente, inicio y final explícitos, luz gradual con la pantalla abierta, micrófono opcional y detector adaptativo con clips locales, pausa visible, sensibilidad configurable y recuperación tras cierres. El diario muestra los periodos de captura separados del tiempo en cama.
- Diario con calendario, tiempo en cama, cinco estados de ánimo originales y notas guardadas automáticamente. Detalle de clips con navegación, reproducción desplazable, sugerencias por intervalos, reintento de análisis, etiquetas corregibles y eliminación confirmada después del guardado.
- Lectura opcional de las fases existentes en Salud. Sin fases o puntuaciones inventadas. Se elige una sola fuente de Salud por noche para evitar duplicar registros de diferentes aplicaciones.
- Castellano e inglés, apariencia automática/amanecer/noche, retención de grabaciones y controles de privacidad.
- Sin cuenta, servidor de grabaciones, anuncios, compras ni dependencias externas de la aplicación.

## Arquitectura

`Domain.swift` contiene los datos serializables. `ArchiveRepository` es el único escritor del archivo JSON: valida el esquema y publica cada cambio después de escribir atómicamente. `SleepStore` coordina transacciones ordenadas, alarma y sesión; conserva el estado ante un relanzamiento. Los servicios de alarmas, audio y Salud están separados de SwiftUI.

Las notas y el ánimo pertenecen a un día civil. Las noches se agrupan por la fecha de finalización. El tiempo en cama mide el intervalo de la sesión iniciada por la persona; no equivale a tiempo dormido. Los clips se activan por cambios sobre el nivel de fondo y reciben sugerencias locales de SoundAnalysis al abrir el diario. El modelo debe puntuar al menos 0,65 para sugerir una categoría: esa puntuación no es un porcentaje de exactitud. Los intervalos son aproximados y corregibles; el fallo de análisis es visible y permite reintentar. No existe clasificación médica automática.

## Recursos nuevos

Ver `Design/ASSETS.md`: ilustración generada para esta aplicación, paisaje nocturno y cinco caras dibujados como vectores en SwiftUI, icono creado geométricamente y tres composiciones sintetizadas sin muestras externas.

## Validación y límites

La automatización `.github/workflows/sleep-next.yml` compila para simulador e iPhone con Xcode 26, ejecuta pruebas de dominio/persistencia e interfaz y exporta capturas de la app real y un IPA sin firma. Los XCTest acústicos ejercitan la misma cola, segmentador y escritor con PCM sintético y comprueban los WAV producidos. Una prueba de interfaz independiente usa la petición real de micrófono y la deniega. Las pruebas visuales de diseño usan un modo exclusivo de Debug que omite permisos y, en la captura del diario, incorpora datos de ejemplo explícitos. El modo Release no contiene esos datos de ejemplo ni omite permisos.

Antes de una distribución final se necesita una prueba nocturna en iPhones físicos: iOS 16–25 y iOS 26, pantalla bloqueada, Silencio/Concentración, permisos denegados, interrupción del micrófono, cambio de ruta de audio, reinicio, volumen y consumo de batería. El simulador no demuestra la fiabilidad acústica en esas condiciones.

La candidata **1.1 (1)** añade revisión por intervalos y completa la estabilización de captura y flujos. [Corpus real, procedencia y método](Tests/Corpus/README.md). Se conserva la línea heredada 1.x; «candidata» no implica aprobación para publicación. El estado de compilación y el paquete concreto se registran en [ESTADO.md](../ESTADO.md).

La firma local está separada de la validación y exige árboles idénticos del proyecto y del flujo de pruebas. Usa un perfil ad hoc propio para dispositivos registrados, secretos restringidos a la rama autorizada y un IPA cifrado en el artefacto de CI. No hay pasos de TestFlight ni App Store. La [corrección 1.0.1](Evidence/recording-2026-09-21/README.md) se conserva como historial.
