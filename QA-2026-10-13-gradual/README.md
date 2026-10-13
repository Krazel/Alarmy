# Despertar progresivo — 13/10/2026

Reporte humano: volumen y luz sin progresión, con el iPhone **bloqueado**.

## Causa y corrección

- El volumen progresivo solo modificaba el AVAudioPlayer de primer plano. El
  planificador de AlarmKit/notificaciones recibía el archivo original a volumen
  completo. Ahora recibe un CAF PCM 16-bit de 29 s con envolvente incorporada de
  -40 dB a 0 dB en 25 s. Los tonos cortos se repiten dentro del archivo; originales
  e importados se conservan. Nombre de caché versionado, generación previa al
  registro de la alarma, archivo temporal cerrado antes de moverlo y protección
  disponible tras el primer desbloqueo. Sin fallback silencioso a un tono pleno
  si falla la preparación. Inicio, posponer, edición y ventana inteligente usan
  la misma selección del sonido.
- Esto controla la amplitud del archivo, no el volumen del sistema. Si iOS
  vuelve a reproducir el archivo, vuelve a reproducir su envolvente. No promete
  una subida continua entre repeticiones que controla iOS.
- En primer plano, AVAudioPlayer usa su interpolación nativa durante 25 s,
  sustituyendo incrementos de volumen una vez por segundo.
- El brillo anterior usaba `max(brilloOriginal, progreso)`, sin aumento visible
  cuando el brillo original era máximo. La luz abierta parte de un nivel nocturno
  <=8% y sube hasta el máximo en el intervalo elegido. Conserva/restaura brillo
  y reposo originales al salir. Con luz desactivada no interrumpe el sensor de
  movimiento de posponer.
- iOS no permite que esta app encienda o ilumine progresivamente la pantalla
  bloqueada. Nombre y ayuda del ajuste ES/EN ahora lo explican expresamente.

## Validación

Primera CI: https://github.com/Krazel/Alarmy/actions/runs/38450915451
Fuente 5c6e6c0: Debug compilado; 8/10 pruebas correctas, 2 fallos. El contenido
PCM, duración/formato, original y selección fueron correctos. Los fallos fueron
la lectura de brillo (el simulador devuelve 0.5 pese a escribir otro valor) y
el atributo de Data Protection ausente. Release no se ejecutó por esos fallos.
Se conserva el resultado original en initial-native-test-summary.json.

Se introduce un adaptador de pantalla para probar los valores ordenados por
NightAudio, el reposo, la restauración y la desactivación sin atribuir capacidades
físicas al simulador. La protección sigue comprobándose en pruebas de dispositivo;
no se acredita en simulador. Segunda CI enfocada correcta: 10/10, cero fallos/omitidas, Debug y Release iPhone
compilados. https://github.com/Krazel/Alarmy/actions/runs/38453395483 , fuente
3f6031d33e01966aad4f53e9d4711d3577245099. Duración 25m13s en runner estándar macos-26.
No hay nueva captura de UI ni QA físico; el scope comprueba comportamiento.

Pruebas inspeccionan PCM realmente escrito (dos canales, 29 s, principio/mitad/
final y conservación del original), selección con/sin crescendo,
caché, fallback de importación ausente, brillo y restauración. Regresiones de
cambio de hora y traducciones. Compilación Debug y Release iPhone.

Prueba física pendiente: iniciar una noche nueva, alarma exacta próxima con
volumen progresivo activo, bloquear, escuchar el inicio y la subida de 25 s;
comprobar también posponer y la variante desactivada. Para luz, dejar Alarma
abierta/cargando y comprobar subida durante 3 min y restauración al terminar.
La prueba del PCM no demuestra por sí sola la entrega de AlarmKit en un iPhone.

Distribución vigente: TestFlight interno 1.4 (1). Candidata 1.4.1 (1) no subida.

## Fuentes primarias consultadas

- Apple AlarmKit: sonidos en bundle o Library/Sounds:
  https://developer.apple.com/videos/play/wwdc2025/230/
- Notificaciones: formatos PCM y duración inferior a 30 segundos:
  https://developer.apple.com/documentation/usernotifications/unnotificationsound
- Brillo: comportamiento al bloquear y desbloquear:
  https://developer.apple.com/documentation/uikit/uiscreen/brightness
- Interpolación nativa del reproductor:
  https://developer.apple.com/documentation/avfaudio/avaudioplayer/setvolume(_:fadeduration:)
