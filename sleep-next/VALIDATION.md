# Validación de AlarmaNext 1.0 (build 1)

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
