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

Validación final correcta: **9 pruebas, cero fallos/omitidas**, compilación Debug
para simulador y Release para iPhone. Fuente `271e448edae68103eff1535e4cb66a991b9abce6`.
[Ejecución final](https://github.com/Krazel/Alarmy/actions/runs/38325929640).
Cubre continuidad de captura y escrituras concurrentes, rollback ante errores,
recuperación de respaldo, edición tras posponer, guardar/cancelar en ES/EN y gesto.
La edición de una alarma pospuesta parte de la hora visible y conserva su carácter
exacto, sin reactivar la ventana inteligente anterior.
Seis capturas nativas, con manifiesto SHA-256 en `validation.json`; revisión visual
de pantalla y editor en ambos idiomas. Simulador iPhone 17 Pro / iOS26.4.1.

- [Pantalla nocturna ES](runtime/50-es-onda-night.png)
- [Panel de hora ES](runtime/51-es-edit-active-alarm.png)
- [Pantalla nocturna EN](runtime/53-en-onda-night.png)
- [Panel de hora EN](runtime/54-en-edit-active-alarm.png)

Biblioteca PR-019 actualizada por API y releída: **revisión 18**, historial y
tracking conservados. Recibo `library-receipt.json`.

Las capturas de onda usan una señal de prueba marcada por argumento DEBUG;
no acreditan micrófono físico ni pruebas nocturnas/batería.
Candidata 1.3 (1). TestFlight interno vigente 1.2 (1), sin nueva subida.
