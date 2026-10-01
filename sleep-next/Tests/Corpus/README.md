# Grabaciones reales para QA — 1 de octubre de 2026

22 fuentes públicas CC0 de Freesound: 5 ronquidos, 4 tos, 5 respiración,
3 voz y 5 fondos (ventilador, habitación, aire acondicionado y lluvia).
Cada entrada de `manifest.json` conserva autor, enlace de origen, licencia,
URL del preview HQ, SHA-256 y selección reproducible. Se verificó CC0 en
la página original antes de descargar; las páginas de licencia se conservan
localmente como evidencia. No son grabaciones privadas de usuarios.

Se evalúan los primeros 12 segundos o la duración completa si es menor,
con dos segundos de contexto vacío antes y después. Las etiquetas de origen
proceden de las descripciones de sus autores. Incluyen respiración suave,
regular, contenida e intensa; no todos los sonidos se grabaron durante sueño
natural. Hay actuaciones humanas y voz hablada. No son etiquetas clínicas
ni una medida de apnea.

La división inicial tiene 9 fuentes de desarrollo y 13 de validación, sin
compartir autores entre ambas. Los resultados preliminares de validación
se inspeccionaron durante el desarrollo: el informe final es una evaluación
repetida, no un ensayo ciego. No se entrenó un modelo con estos archivos.

`RecognitionTests` ejecuta el modelo real `.version1` de Apple: entrada
limpia, atenuación de 18 dB y mezcla con el ventilador real `other-96913`
a una relación RMS nominal de 10 dB. Son 66 casos derivados de 22 fuentes,
no 66 personas independientes. El ventilador también es una fuente del
conjunto de desarrollo; la mezcla prueba robustez, no un fondo independiente.
La entrada limpia pasa además por la misma cola, segmentador y escritor WAV
que el micrófono; se analizan los clips realmente producidos.

Se exportan puntuaciones del modelo por ventana de 3 segundos de referencia,
predicción principal, intervalos sugeridos y resultado de la captura. El
análisis de la app combina ventanas compatibles de aproximadamente 1 segundo
para eventos breves y 3 segundos para respiración suave, solapamiento 50 % y
umbral conservado 0,65. Respiración y ronquido compiten dentro de cada ventana.
Se publican aciertos, abstenciones, confusiones y etiquetas secundarias: una
predicción principal correcta no prueba que cada intervalo sea correcto.

Los MP3 y el manifiesto se incluyen únicamente en el bundle de XCTest.
El IPA Release debe verificarse sin corpus, fixtures ni omisión de permisos.
La exactitud en una habitación y el consumo nocturno requieren iPhone físico.

Referencia técnica: [SoundAnalysis, WWDC21](https://developer.apple.com/videos/play/wwdc2021/10036/)
y [duración de ventana](https://developer.apple.com/documentation/soundanalysis/snclassifysoundrequest/windowduration).
