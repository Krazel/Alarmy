# Corrección de reconocimiento y sueño — 15/10/2026

Candidata **1.5.1 (1)**; distribución vigente **TestFlight interno 1.5 (1)**.
No se ha subido una nueva build en este encargo.

## Motivo y cambios

Corrección de dos problemas de software: totales engañosos cuando hay pocos
intervalos clasificados y fragmentos desconocidos mezclados con pendientes.
El material de esta carpeta usa datos sintéticos y un corpus público licenciado.

- La cola de reconocimiento pertenece al almacén, continúa al navegar y procesa
  de uno en uno. Reintenta fallos una vez por activación, sin bucle por cada clip.
- Diferencia reconocido, pendiente, fallo y desconocido. Los completados sin
  categoría se borran mediante la cola persistente de eliminación. Los pendientes
  y fallidos no se descartan como si fueran desconocidos.
- Lista y recuento incluyen sonidos reconocidos; estados pendientes visibles
  aparte. Reanaliza etiquetas automáticas anteriores con la revisión 3 del flujo.
- Conserva el clasificador local Apple SoundAnalysis, sus ventanas y umbral 0,65;
  no se ha entrenado otro modelo ni relajado el umbral para fabricar etiquetas.
- Estimador experimental v2 tolera hasta 90 s de señal débil registrada entre
  evidencias respiratorias contiguas. No rellena huecos de captura ni periodos
  largos sin evidencia. Los intervalos puente no generan profundo/REM por sí solos.
- Diario, estadísticas y CSV no presentan un total nocturno cuando la cobertura
  clasificada es inferior al 90 %. Se conservan los intervalos parciales observados.

## Validación

Fuente de aplicación y pruebas: `3cc7ab2`.
Ejecución final (16/10): https://github.com/Krazel/Alarmy/actions/runs/38894811965 .
**26/26 pruebas correctas**, cero fallos y omitidas. Debug y Release iPhone
sin firma compilados correctamente. Capturas nativas revisadas: diario con
resumen compacto, categorías Ronquido/Respiración/Voz/Tos, sin «Sin etiquetar».
Datos de las capturas sintéticos, no proceden de la noche del usuario.

Banco repetido: 22/22 correctos en limpio, 20/22 a -18 dB y 20/22 con
ventilador. Dos respiraciones tenues quedan desconocidas; con ventilador hay
dos confusiones respiración/ronquido. Resultado idéntico al banco anterior,
sin afirmar que haya mejorado la precisión del modelo. La corrección mejora
la ejecución, recuperación y presentación del análisis. JSON completo y
resumen de errores conservados en esta carpeta.

Historial: 38663484684 se canceló para limitar reintentos; 38663548063 se
sustituyó antes de ejecutar la suite por la corrección del intervalo temporal
sintético de un clip de prueba. No contarlos como validaciones aprobadas.
38663884396 falló al compilar por una etiqueta `where:` ausente; corregida
en 3cc7ab2. No se ejecutaron pruebas en ese intento.

El banco de audio usa 22 grabaciones con licencia conservada en Tests/Corpus,
en 3 condiciones (66 variantes). Reutilizado, no es un conjunto ciego ni una
medición de precisión en la habitación del usuario. Los tests de sueño comprueban
reglas del algoritmo; no validan fases fisiológicas. La siguiente prueba física
debe contrastar captura continua, cobertura y categorías durante una noche real.

Registro privado del producto actualizado y verificado; recibo conservado
solo en almacenamiento local excluido de Git.
