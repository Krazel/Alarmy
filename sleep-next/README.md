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

Las correcciones locales de octubre incorporan una cola de borrado persistente:
se guarda la intención, se eliminan WAV y auxiliares y se confirma la retirada
del índice. Recuperación, borrado e inicio de captura ordenan el acceso a archivos.
Posponer espera al cierre de captura y solo recupera el micrófono que detuvo la
alarma; conserva pausas voluntarias. Detener desde AlarmKit se reconoce después
de guardar la noche. [Entrega y verificaciones pendientes](Evidence/october-2026/README.md).

Las notas y el ánimo pertenecen a un día civil. Las noches se agrupan por la fecha de finalización. El tiempo en cama mide el intervalo de la sesión iniciada por la persona; no equivale a tiempo dormido. Los clips se activan por cambios sobre el nivel de fondo y reciben sugerencias locales de SoundAnalysis al abrir el diario. El modelo debe puntuar al menos 0,65 para sugerir una categoría: esa puntuación no es un porcentaje de exactitud. Los intervalos son aproximados y corregibles; el fallo de análisis es visible y permite reintentar. No existe clasificación médica automática.

## Recursos nuevos

Ver `Design/ASSETS.md`: ilustración generada para esta aplicación, paisaje nocturno y cinco caras dibujados como vectores en SwiftUI, icono creado geométricamente y tres composiciones sintetizadas sin muestras externas.

## Validación y límites

La automatización `.github/workflows/sleep-next.yml` compila para simulador e iPhone con Xcode 26, ejecuta pruebas de dominio/persistencia e interfaz y exporta capturas de la app real y un IPA sin firma. Los XCTest acústicos ejercitan la misma cola, segmentador y escritor con PCM sintético y comprueban los WAV producidos. Una prueba de interfaz independiente usa la petición real de micrófono y la deniega. Las pruebas visuales de diseño usan un modo exclusivo de Debug que omite permisos y, en la captura del diario, incorpora datos de ejemplo explícitos. El modo Release no contiene esos datos de ejemplo ni omite permisos.

Antes de una distribución final se necesita una prueba nocturna en iPhones físicos: iOS 16–25 y iOS 26, pantalla bloqueada, Silencio/Concentración, permisos denegados, interrupción del micrófono, cambio de ruta de audio, reinicio, volumen y consumo de batería. El simulador no demuestra la fiabilidad acústica en esas condiciones.

La candidata **1.1.1 (1)** reúne las correcciones de octubre posteriores a la
entrega 1.1 (1). [Corpus anterior, procedencia y método](Tests/Corpus/README.md).
Se conserva la línea heredada 1.x; candidata no implica publicación comercial.
El estado de compilación y paquete se registran en [ESTADO.md](../ESTADO.md).

La entrega **1.1 (1)** fue aceptada por Apple el 02/10/2026 y está en TestFlight
interno para el titular; el flujo separado está en
`.github/workflows/sleep-next-testflight.yml`. No hay entrega externa ni publicación
en App Store. El usuario autorizó el 12/10 subir los cambios como 1.1.1 (1) y
mantener este repositorio público para Actions estándar gratuitas, usando API
y sin gastos. La validación es manual; firma/subida exigen un run nuevo correcto
con el mismo árbol del proyecto. [Entrega actual](../QA-2026-10-12/README.md).
La noche física sigue pendiente. La firma ad hoc y
la [corrección 1.0.1](Evidence/recording-2026-09-21/README.md) quedan como historial.
