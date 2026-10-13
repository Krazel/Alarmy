# Correcciones tras la noche de prueba — 13/10/2026

El usuario vio el aviso de falta de espacio al despertar; no se dispone del
texto exacto ni de un registro del dispositivo. Se identifica como causa probable
el límite artificial de 256 MB por noche y 512 MB totales que lanzaba el mismo
error del sistema. No afirmar que el iPhone realmente estuviera lleno.

Candidata 1.3.1 (1), ES/EN, iPhone iOS16+. No subida a TestFlight en este encargo.
- Capacidad libre real comprobada al iniciar y cada MiB escrito en la cola de audio.
  Reserva de 64 MiB para el WAV actual, su recibo y escrituras atómicas del diario.
  Sin límites acumulados de 256/512 MB; al faltar espacio conserva clips y alarma.
- Ajustes muestra bytes ocupados por grabaciones y temporales, contador y borrado
  total con confirmación. Cola persistida antes de borrar; reanudación idempotente.
  No borra notas, sentimientos, estadísticas, tonos importados ni alarmas.
- Una opción Grabar y analizar sonidos, solo en Ajustes. La grabación activa
  implica análisis local. Respeta opt-out anterior en cualquiera de las opciones.
- Onda solicitada a 60 FPS, interpolación de amplitud de 220 ms, doble armónico
  y amplitud acotada con margen para el trazo. Pausada en segundo plano y con
  Reducir movimiento. Conserva fondo, reloj, edición de alarma y gesto Parar.
- Orden diario: semana, estado al despertar, nota, resumen, análisis, Salud,
  categorías de sonidos. Resumen con contador agregado que desplaza a sonidos;
  sin lista de intervalos ni tipos repetida en el resumen/análisis de la noche.
  Las estadísticas conservan totales históricos tras borrar el audio.

Pruebas enfocadas: espacio real/bajo, audio recuperable tras agotamiento,
borrado y relanzamiento, conservación del diario, migración de preferencias,
continuidad y límites de onda; UI ES/EN para orden, acceso a categorías, ajuste
único, cancelar/borrar, tamaños y persistencia. Validación nativa completada:
**11/11**, Debug y Release iPhone sin firma correctos en
[38387418695](https://github.com/Krazel/Alarmy/actions/runs/38387418695), fuente
`fc561181644e32f306849e4686cf41e5c6446962`.
Nueve capturas del simulador iPhone 17 Pro, iOS26.4.1, con SHA-256 y procedencia
en `validation-receipt.json`. Revisadas nota, categorías, Ajustes ES/EN y onda;
conservan composición y fondo aprobados. El texto de la nota es un fixture DEBUG.
Biblioteca PR-019 guardada y releída, revisión 20: misma versión distribuida y
tracking; candidata diferenciada. Recibo en `library-receipt.json`.
No se ha medido todavía FPS/batería en el iPhone físico ni confirmado el origen
del aviso concreto en su dispositivo. La captura usa señal DEBUG de prueba.

API de capacidad local: https://developer.apple.com/documentation/foundation/urlresourcevalues/volumeavailablecapacity
Manifiesto de privacidad declara DiskSpace E174.1 para evitar escrituras sin espacio.

Iteraciones de la comprobación enfocada:
- 38381908363: Debug compiló; 7/11. Se eliminaron identificadores de contenedor
  que ocultaban los de sus botones y se corrigieron dos fixtures: tolerancia de
  duración y retención explícita de 30 días en la simulación de escritura fallida.
- 38383811748: Debug compiló; 9/11. Los ocho tests de datos/audio y el de noche
  pasaron. Los dos recorridos del diario pasaron orden y salto a categorías,
  pero tocaban el centro de la fila del Toggle, fuera del interruptor real.
  Corregido el toque al extremo del control y espera de su valor accesible.
- 38385631389: Debug compiló; 9/11. El ajuste único y almacenamiento pasaron.
  La confirmación se presentó en iOS26 como popover sin botón Cancelar (captura
  del vídeo nativo revisada). Se sustituye por alert nativo con ambas acciones
  explícitas, localizadas, y los tests buscan botones dentro del alert.
