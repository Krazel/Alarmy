# Primer intento nativo — 38300052406

Fuente `df687be`, [run](https://github.com/Krazel/Alarmy/actions/runs/38300052406).
Compilación para pruebas correcta; cuatro pruebas de retención, calendario,
escenarios e aislamiento pasadas. El recorrido UI falló al buscar
`journal-examples` en Diario después de activar el modo desarrollador en Ajustes.
No se realizó build Release, firma ni subida tras ese fallo.

Se centraliza el estado del modo desarrollador en el `SleepStore` compartido,
manteniendo la preferencia local existente, y se añade verificación explícita
del interruptor antes de abrir Diario. Fuente corregida `455197e`.
Se repite únicamente el alcance `design`; no se repiten las regresiones de audio
ni se sube otra build. Se exportan los adjuntos nativos del recorrido UI para
comparar la implementación con las propuestas.

Segundo intento [38301326942](https://github.com/Krazel/Alarmy/actions/runs/38301326942):
compila y vuelve a pasar las cuatro pruebas de datos. La nueva aserción confirma
que el interruptor sigue en 0 después del toque. La grabación nativa exportada
muestra el control a la derecha de una fila completa: XCTest exponía la fila
como Switch y pulsaba su centro, sobre el texto. Se dirige el toque al control
derecho observado; no se elimina ni debilita la aserción de estado.

Fuente del tercer intento `30e85fc`: incluye además el guard de navegación
entre clips para no tocar AVAudioSession en muestras y evita mostrar «Guardado
en este iPhone» en las notas de ejemplo. Tercer intento enfocado en
[38303132505](https://github.com/Krazel/Alarmy/actions/runs/38303132505).

El tercer intento activa correctamente el interruptor y abre las muestras.
Falla porque XCTest encuentra dos botones con identificador `calendar`: uno
en la muestra y otro en el diario que permanece detrás de la hoja. Se añaden
identificadores específicos para el calendario de ejemplo y su cierre, sin
alterar el diseño ni debilitar las aserciones. Compilación y cuatro pruebas
de datos correctas; Release no ejecutado por el fallo del recorrido.

Fuente `2edfbcd`, comprobación corregida
[38305125429](https://github.com/Krazel/Alarmy/actions/runs/38305125429).

**Resultado final correcto**: cinco pruebas pasadas, cero fallos/omitidas y
compilación Release para iPhone. Las capturas y el resumen original están
en esta carpeta. No se realizaron firma ni subida de estos cambios.
