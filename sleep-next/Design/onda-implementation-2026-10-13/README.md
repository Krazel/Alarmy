# A · Onda — implementación aprobada

13-10-2026. El usuario aprueba `../night-variants-2026-10-13/onda-r2-es-en.png`
y pide implementarla sin puntos bajo la flecha ni icono de alarma, todo centrado.
Añade edición de hora desde la noche con un panel inferior, sin finalizar sesión.

Hora actual grande, hora de alarma subrayada con chevron desplegable, onda suave
local cuyo tamaño responde a la amplitud del micrófono y flecha visual pequeña
«Parar»/«Stop» con región gestual más amplia. No hay puntos ni control de mute.
Las interrupciones reales conservan aviso y reanudación de grabación; la
normalidad no muestra controles adicionales. Sin alarma permanece sin alarma.

El editor modifica solo esta noche, muestra fecha/hora resultante y conserva
modo y duración de ventana inteligente. Cancelar descarta el borrador. La nueva
hora reprograma el sistema y el límite del capturador sin reiniciar su audio.
Registra el ID de reemplazo antes de programarlo, guarda la nueva hora antes de
cancelar la anterior y conserva los respaldos para limpieza al reanudar. La
persistencia de clips/épocas continúa tras una barrera breve para impedir que
una instantánea anterior revierta el cambio. Un error conserva la alarma previa.
La app usa [AlarmManager](https://developer.apple.com/documentation/alarmkit/alarmmanager)
en iOS26 y la vía de notificaciones existente en iOS16–25.

Validación nativa enfocada pendiente: continuidad/cambios concurrentes, errores,
recuperación de respaldo, límite de captura y UI ES/EN con cancelar/guardar/gesto.
Las capturas de onda usan una señal de prueba marcada por argumento DEBUG;
no acreditan micrófono físico ni pruebas nocturnas/batería.
Candidata 1.3 (1). TestFlight interno vigente 1.2 (1), sin nueva subida.
