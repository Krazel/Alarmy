# Análisis local experimental — Alarma 1.5 (1)

Autorización humana: «quiero todo local, que hagamos nuestra propia forma a
partir del audio, aunq no sea 100% buena». Implementación nativa en iOS 16+,
castellano e inglés. No servicios externos ni acceso a Salud.

El método y sus umbrales están en `../research/local-estimator-v1.json`.
Una envolvente de energía de 10 Hz se descarta cada 30 segundos después de
extraer características compactas. La inferencia exige patrones sostenidos;
silencio, huecos y noches antiguas sin características no se rellenan como sueño.
Las hipótesis ligero/profundo/REM se basan en estabilidad y variación acústica.
No se han entrenado ni contrastado con polisomnografía. Pueden confundir
respiración despierto, acompañantes o ruido repetitivo. No existe una cifra de
precisión demostrada.

Las pruebas sintéticas comprueban reglas, persistencia, cálculos e interfaz;
no prueban que una fase inferida coincida con la fase fisiológica de una persona.
Las capturas son pantallas SwiftUI del simulador con datos sintéticos, no
mediciones humanas. El historial de ejecuciones conserva también los fallos
corregidos, sin presentarlos como validaciones exitosas.

Pendiente en dispositivo físico: registrar una noche completa con el iPhone
bloqueado, revisar continuidad de captura, consumo, almacenamiento y ejemplos
de sonidos. Comparar horas estimadas con anotaciones de acostarse/despertarse;
esas anotaciones tampoco validan las fases. Probar el crescendo al sonar la
alarma bloqueada. La iluminación gradual solo actúa con la aplicación abierta.

La candidata no se ha firmado ni subido a TestFlight en este encargo.
La distribución interna conocida continúa en 1.4 (1).

Resultado final: fuente `d6700fc`, [CI 38480354936](https://github.com/Krazel/Alarmy/actions/runs/38480354936),
Debug y Release iPhone sin firma correctos; 25/25 pruebas, cero fallos u omitidas.
El código de aplicación es el de `132d279`; el último ajuste solo corrige el
gesto de la prueba sobre el interruptor nativo de Siesta y verifica su valor.
`receipt.json` conserva hashes de las nueve capturas nativas conservadas y el
dispositivo del simulador. No implica validación fisiológica.
