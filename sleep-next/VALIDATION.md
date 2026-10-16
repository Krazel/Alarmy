# Validación de AlarmaNext

## Candidata 1.5.1 (1) — verificada el 16/10/2026

Corrección tras reporte físico de duración de sueño escasa y clips sin etiqueta.
Fuente `3cc7ab2`: **26/26 pruebas**, cero fallos/omitidas, Debug y Release iPhone
sin firma correctos. [CI 38894811965](https://github.com/Krazel/Alarmy/actions/runs/38894811965).
Cola serial independiente de la vista, reintentos limitados, borrado persistente
de desconocidos, categorías reconocidas y estimador v2 con cobertura mínima.
[QA y capturas](../QA-2026-10-15-recognition/README.md) · [Método v2](../research/local-estimator-v2.json).
Banco repetido de 22 fuentes/66 variantes: 22/22 limpio, 20/22 bajo volumen,
20/22 con ventilador. No acredita precisión nocturna ni fisiológica.
Sin nueva subida: TestFlight interno vigente 1.5 (1).

## Candidata 1.5 (build 1) — 14 de octubre de 2026

Fuente de aplicación `132d279`; ajuste de prueba `d6700fc`. Análisis acústico propio y local, con hipótesis
experimentales de sueño y fases; retirados permisos y dependencia de Salud.
Incluye continuidad, hábitos, siestas, corrección de horarios, comparación,
objetivo personal, métricas de alarmas y exportación. Contrato y limitaciones:
[método v1](../research/local-estimator-v1.json).

Validación nativa correcta: Debug, 25/25 pruebas (cero fallos/omitidas),
Release iPhone sin firma y capturas de simulador revisadas:
[38480354936](https://github.com/Krazel/Alarmy/actions/runs/38480354936).
El historial con los fallos corregidos y la evidencia final se conserva en
[QA de análisis](../QA-2026-10-14-insights/README.md).
Entrega posterior autorizada y verificada el 14/10: TestFlight interno 1.5 (1),
`VALID` / `IN_BETA_TESTING`. Recibos en
[QA de entrega](../QA-2026-10-14-TestFlight/README.md).

Las pruebas sintéticas comprueban funcionamiento del software, no precisión
fisiológica. Pendiente una noche real con iPhone bloqueado, consumo y captura
continua. Los apartados inferiores son evidencia histórica; sus referencias a
Salud ya no describen la arquitectura de la candidata 1.5.

## Historial: candidata 1.1 (build 1) — 1 de octubre de 2026

El resultado vigente de CI, fuente, paquete, firma y biblioteca está en [ESTADO.md](../ESTADO.md). La versión pública sigue sin confirmarse. Se conserva la línea heredada 1.x; esta candidata no está aprobada para publicar.

Se amplía el diario con detalle y navegación de clips, reproducción desplazable, sugerencias por intervalos, corrección y reintento. Se estabilizan el ruido sostenido, pausas y recuperación, el inicio y posponer ante errores de guardado, la eliminación de audio y los solapamientos de Salud.

Además de los PCM sintéticos del detector, [22 fuentes reales CC0](Tests/Corpus/README.md) ejercitan captura y clasificación, con 66 casos de volumen y fondo. Los recortes y variantes no son personas independientes ni pruebas clínicas. El informe registra aciertos, abstenciones y confusiones; no deduce exactitud de una prueba que solo comprueba que el modelo termina.

La firma para Local QA usa un perfil ad hoc propio de Alarma y los dispositivos ya registrados. El IPA se cifra antes de subirlo como artefacto público de GitHub. La compilación y firma se separan de una instalación física; no hay subida a TestFlight ni publicación por este encargo.

Pendiente de verificar en iPhone: noche completa, batería, bloqueo/segundo plano, llamadas y rutas, calidad de captura en una habitación y alarmas tanto en iOS anterior a 26 como en iOS 26. El mínimo incorporado debe mantenerse en iOS 16 con AlarmKit opcional. Véase el protocolo del estado vigente.

## Historial: candidata 1.0.1 (build 1) — 21 de septiembre de 2026

Fuente validada: `0efac28e6a3621b47df75265c00ac70232793b09`. [CI completa](https://github.com/Krazel/Alarmy/actions/runs/35635101317): compilación de simulador e iPhone, **38 pruebas unitarias/integración y 3 de interfaz, cero fallos**.

Corrección de seguimiento y clips: detector adaptativo con contexto, WAV recuperables por noche, pausa explícita, interrupciones, errores de almacenamiento y retención, sin reactivar el micrófono al relanzar. Se preservan castellano, inglés y el diseño.

[Diagnóstico, WAV de prueba, capturas reales e inspección del paquete](Evidence/recording-2026-09-21/README.md). El IPA 1.0.1 (1) está sin firma; conserva iOS 16 como mínimo y AlarmKit opcional. Firma, prueba nocturna en iPhone físico y consumo de batería pendientes. No se ha distribuido por TestFlight ni publicado en este encargo.

## Historial: AlarmaNext 1.0 (build 1)

Código validado: `60352911c2361618b7d4234a70d08815ddf09f88`.

[Pase completo de Xcode, 5 de septiembre de 2026](https://github.com/Krazel/Alarmy/actions/runs/33962027629).

- Compilación de aplicación y pruebas para simulador: correcta.
- Pruebas de dominio, recursos, importación y persistencia: 18.
- Pruebas de interfaz en castellano e inglés: 2.
- Compilación Release para iPhone y empaquetado del IPA sin firma: correctos.
- Capturas: exportadas desde XCTest en un iPhone 17 Pro simulado con iOS 26.4.1.

Se comprobaron el cálculo de la próxima alarma y un cambio de horario de verano, la selección de sonidos, el rechazo de rutas no válidas, los recursos incluidos, la preparación de audio importado dentro del límite de las notificaciones, las sugerencias de clasificación, el guardado concurrente, archivos corruptos, recuperación de sesiones, retención de clips y notas con caracteres Unicode. El recorrido de interfaz inicia y termina una sesión, edita una nota, cierra y relanza la app y comprueba que se conserva; también cambia de idioma y apariencia.

Las pruebas de interfaz usan permisos omitidos únicamente en Debug. La noche de 8 h 5 min y la nota que comienza «Ejemplo de diseño» son datos sintéticos para enseñar el diario. No son grabaciones ni mediciones de una persona. Las capturas son pantallas SwiftUI reales, no maquetas de una web.

## Compatibilidad y límites de la evidencia

El proyecto compila con despliegue mínimo iOS 16. El uso de AlarmKit está limitado a bloques disponibles desde iOS 26. En iOS 16–25 se programan notificaciones con sonido, sujetas a Silencio, Concentración y los ajustes del sistema. Las fases de Salud solo se muestran si existen registros accesibles.

La prueba automatizada se ha realizado en iOS 26.4.1, no en un dispositivo físico con iOS 16. Antes de distribuir se necesita firma de Apple y una prueba nocturna en iPhone físico, tanto de la ruta AlarmKit como de las notificaciones en un iOS anterior: pantalla bloqueada, app cerrada, permisos y revocación, interrupciones de audio, reinicio, rutas de audio, volumen y consumo de batería. El IPA sin firma no es instalable directamente.

## Inspección del paquete Release

Se inspeccionó también el ejecutable Mach-O del IPA generado:

- Versión mínima incorporada: **16.0.0**; SDK: **26.5.0**.
- AlarmKit se enlaza de forma opcional (`LC_LOAD_WEAK_DYLIB`), de modo que su ausencia en sistemas anteriores no impida cargar la aplicación.
- El ejecutable Release no contiene el argumento para omitir permisos de las pruebas ni la nota de ejemplo del diseño.
- SHA-256 del IPA: `6D96DABAEEAA2AA4526E5859AB5C6C2ABEB60833A592E4445342B090096E59A6`.

Las fuentes Swift, PNG y WAV/CAF del nuevo proyecto se compararon por SHA-256 con las de `sleep-native`: ningún archivo es idéntico. Los controles y símbolos nativos de Apple se utilizan como recursos de plataforma.
