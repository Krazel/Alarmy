# Alarma — nueva aplicación nativa

Proyecto independiente escrito desde cero en `sleep-next`. Los diseños anteriores sirven de referencia visual; este proyecto no compila, importa ni enlaza código o recursos de `sleep-native` ni de la aplicación original.

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
- Sesión nocturna persistente, inicio y final explícitos, luz gradual con la pantalla abierta, micrófono opcional y clips locales activados por ruido.
- Diario con calendario, tiempo en cama, cinco estados de ánimo originales, notas guardadas automáticamente y escucha, clasificación manual y eliminación de clips.
- Lectura opcional de las fases existentes en Salud. Sin fases o puntuaciones inventadas. Se elige una sola fuente de Salud por noche para evitar duplicar registros de diferentes aplicaciones.
- Castellano e inglés, apariencia automática/amanecer/noche, retención de grabaciones y controles de privacidad.
- Sin cuenta, servidor de grabaciones, anuncios, compras ni dependencias externas de la aplicación.

## Arquitectura

`Domain.swift` contiene los datos serializables. `ArchiveRepository` es el único escritor del archivo JSON: valida el esquema y publica cada cambio después de escribir atómicamente. `SleepStore` coordina transacciones ordenadas, alarma y sesión; conserva el estado ante un relanzamiento. Los servicios de alarmas, audio y Salud están separados de SwiftUI.

Las notas y el ánimo pertenecen a un día civil. Las noches se agrupan por la fecha de finalización. El tiempo en cama mide el intervalo de la sesión iniciada por la persona; no equivale a tiempo dormido. Los clips se activan por nivel de sonido y se etiquetan manualmente; no existe clasificación médica automática.

## Recursos nuevos

Ver `Design/ASSETS.md`: ilustración generada para esta aplicación, paisaje nocturno y cinco caras dibujados como vectores en SwiftUI, icono creado geométricamente y tres composiciones sintetizadas sin muestras externas.

## Validación y límites

La automatización `.github/workflows/sleep-next.yml` compila para simulador e iPhone con Xcode 26, ejecuta pruebas de dominio/persistencia e interfaz y exporta capturas de la app real y un IPA sin firma. Las pruebas visuales usan un modo exclusivo de Debug que omite permisos y, en la captura del diario, incorpora datos de ejemplo explícitos. El modo Release no contiene esos datos de ejemplo ni omite permisos.

Antes de una distribución final se necesita una prueba nocturna en iPhones físicos: iOS 16–25 y iOS 26, pantalla bloqueada, Silencio/Concentración, permisos denegados, interrupción del micrófono, cambio de ruta de audio, reinicio, volumen y consumo de batería. El simulador no demuestra la fiabilidad acústica en esas condiciones.
