# Prueba en iPhone — Alarma 1.1 (1)

La candidata está diseñada para iOS 16 o posterior. La prueba automática usa
un simulador de iOS 26; no acredita una noche física ni la ruta de alarmas de
un iOS anterior. Conservar este protocolo junto al resultado del teléfono.

## Instalación local

En este Windows está preparado `Instalar-Alarma.cmd`, con PyMobileDevice3
11.20.2 aislado en `artifact/completion-20261001/installer`. El servicio Apple
Mobile Device está instalado y activo. El lanzador verifica el SHA-256 del IPA
firmado antes de instalar por USB. Su comprobación `Install-Alarma.ps1 -CheckOnly`
solo muestra ayuda y se ha ejecutado sin conectarse al teléfono.

Conecta uno de los dos iPhone ya registrados por USB, desbloquéalo, acepta
«Confiar» si lo solicita y ejecuta `Instalar-Alarma.cmd`. No vuelve a firmar
el paquete ni cambia su identificador. Si iOS solicita Modo de desarrollador,
actívalo en sus ajustes y sigue sus pasos de reinicio. Verifica «Alarma · 1.1»
en Ajustes al abrirla. La instalación real aún necesita comprobarse con el
teléfono conectado. En macOS también puede instalarse el IPA con Xcode o
Apple Configurator siguiendo [el procedimiento de Apple](https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices).

La herramienta USB es externa a la app y no forma parte del IPA.
[Procedencia y soporte Windows](https://github.com/doronz88/pymobiledevice3/blob/master/docs/installation.md).

## Comprobaciones breves antes de dormir

1. Anota modelo, versión exacta de iOS, fecha, versión/build de la app y espacio
   libre. Cambia ES/EN y comprueba alarma, diario, ajustes y detalle de un clip.
2. Con la grabación apagada, programa una alarma cercana y bloquea el iPhone.
   En iOS 16–25 activa sonidos de notificaciones y desactiva Silencio y
   Concentración. En iOS 26 prueba también esos modos con AlarmKit autorizado.
   Anota hora programada/real, sonido y respuesta al abrir, posponer y terminar.
3. Activa el micrófono con permiso y sensibilidad normal. Comprueba el indicador
   activo. Bloquea durante varios minutos; habla brevemente, deja silencio y
   prueba un sonido suave. Termina y escucha los clips: inicio/contexto,
   duración, hora, pausas, etiqueta y ausencia de la propia alarma.
4. Pausa y reanuda. Comprueba una interrupción del sistema y un cambio de entrada
   de audio si dispones de ellos: debe mostrar los huecos y detenerse cuando
   no pueda capturar. No debe reanudar una pausa voluntaria por sí sola.
5. Cierra la app a la fuerza durante una noche breve y vuelve a abrir. Debe
   recuperar archivos y sesión, mostrar micrófono detenido y ofrecer reanudar;
   no afirmar que ha grabado durante el cierre. Termina una noche antigua
   recuperada sin una alarma que suene días después.
6. En el diario escucha, desplaza, cambia de clip, corrige etiqueta y elimina
   uno. Cierra/reabre y comprueba el guardado. Prueba calendario, notas, ánimo
   y retención. Salud muestra solo fases disponibles, sin rellenar huecos.

## Noche completa y batería

7. Registra una noche de duración normal, con luz de amanecer desactivada y
   condiciones anotadas: teléfono bloqueado, cargador sí/no, modo de bajo
   consumo, batería inicial/final, sensibilidad, distancia y ruido de fondo.
   No deducir consumo sin medición real. Registra horas de captura, huecos,
   reinicios/interrupciones y si sonó el despertar.
8. Revisa una muestra de clips al despertar, anotando «correcto», «incorrecto»
   o «sin identificar». Distingue errores del detector, pérdida de captura y
   errores de etiqueta. Mantén el audio personal en el iPhone: basta compartir
   el resultado resumido. El banco CC0 no sustituye este resultado nocturno.

La captura tiene límites de 256 MiB por noche y 512 MiB de archivos totales.
Con muchos eventos largos puede detenerse antes de acabar; el estado y los
huecos deben quedar visibles. La retención elimina audio, conservando notas
y ánimo. Este límite y la sensibilidad necesitan revisarse con la prueba real.

## Resultado físico (pendiente)

Modelo / iOS: —  ·  Fecha / horas: —  ·  Instalación: —

Alarma / posponer: —  ·  Bloqueo / segundo plano: —  ·  Recuperación: —

Clips revisados / errores: —  ·  Batería inicial/final / cargador: —

La aprobación física y la publicación son estados diferentes. Este encargo
no autoriza subir a TestFlight ni publicar en App Store.
