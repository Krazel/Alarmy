# Una noche de prueba en iPhone

**Pendiente:** no hay mediciones ni aceptación física. Clips y audio permanecen
en el teléfono; compartir solo el formulario de resultados, sin grabaciones.

## Antes de dormir — diez minutos

1. Anotar modelo, iOS y versión/build. Para validar los cambios de octubre hace
   falta una candidata compilada desde el SHA de esta entrega. TestFlight 1.1 (1)
   permite observar la base anterior, pero no valida estas correcciones.
2. Empezar una sesión con grabación: producir voz y un sonido breve, bloquear
   dos minutos y terminar. Revisar clips, reproducir, cambiar una etiqueta y
   borrar un clip. Cerrar/abrir: diario, etiquetas y borrado deben conservarse.
3. Otra sesión con pausa manual del micrófono: al sonar la alarma, posponer debe
   mantener esa pausa. Repetir sin pausa manual: posponer debe permitir capturar
   de nuevo y mostrar un periodo de captura nuevo.
4. Probar una llamada u otra app que use el micrófono y volver. Revisar el estado
   visible y los clips. Cerrar durante una sesión y reabrir: debe recuperar lo
   guardado y pedir reactivar captura, sin fingir continuidad durante el cierre.

Anotar fallos con hora, acción y estado visible. No borrar datos personales ni
llenar el teléfono: el fallo de almacenamiento se simula en XCTest.

## Esa noche

1. Elegir alarma y grabación. Anotar hora, batería inicial, carga, bajo consumo,
   Silencio/Concentración, Bluetooth y auriculares.
2. Empezar noche y comprobar el indicador de micrófono/captura. Dejar el iPhone
   en su posición habitual, sin tapar el micrófono y con pantalla bloqueada.
3. Al despertar, anotar si sonó y cuándo; posponer una vez y terminar. Anotar
   batería final antes de cargar. Revisar diario, periodos de captura y clips.
4. Cerrar/abrir y comprobar persistencia. El tiempo en cama no es tiempo dormido.

En iOS 16–25 la alarma es una notificación con sonido de hasta 29 segundos y
depende de permisos, Silencio y Concentración. Hacer primero una alarma breve
con esos modos desactivados y registrar por separado qué pasa con cada modo
activado. En iOS 26 comprobar AlarmKit, detener desde el sistema y volver al
diario. Un resultado en una versión no valida las demás.

Si estaba cargando, no calcular consumo. Sin carga, registrar caída en puntos
porcentuales y horas: es una observación de ese teléfono, no autonomía general
ni precisión del clasificador.

## Formulario

| Dato | Resultado |
| --- | --- |
| Fecha / iPhone / iOS | Pendiente |
| Versión (build) / SHA | Pendiente |
| Inicio / final / horas | Pendiente |
| Batería inicial / final / carga | Pendiente |
| Bajo consumo / Silencio / Concentración / audio | Pendiente |
| Alarma prevista / real / posponer / detener | Pendiente |
| Pausa manual conservada al posponer | Pendiente |
| Captura retomada al posponer sin pausa manual | Pendiente |
| Interrupción/cierre: estado y recuperación | Pendiente |
| Clips: cantidad / reproducibles / etiquetas discrepantes | Pendiente |
| Diario, etiquetas y borrado guardados al reabrir | Pendiente |
| Incidencias con hora y acción | Pendiente |

Aceptación: alarmas dentro de los límites del iOS probado, clips reproducibles,
pausas visibles, diario conservado y batería medida. Ante un fallo, corregir y
repetir el caso afectado. Las sugerencias requieren más noches y no detectan
problemas médicos.
