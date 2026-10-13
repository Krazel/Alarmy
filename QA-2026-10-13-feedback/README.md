# Alarma 1.3.1 (1) — TestFlight interno

El usuario pide «subelo a test» tras recibir las correcciones validadas.
Mismo destino y grupo interno del titular, sin distribución externa ni App Review.
Se reutilizan certificado y perfil autorizados, mediante secretos temporales en
alarma-local-qa, limitado a codex/native-sleep-rebuild. No se cambian visibilidad,
plan ni runners; Krazel/Alarmy sigue público por excepción expresa del producto.

Fuente de validación: fc561181644e32f306849e4686cf41e5c6446962.
Run 38387418695: 11/11, Debug y Release iPhone sin firma correctos, capturas ES/EN.
Fuente de entrega: 06344eb; árbol de app idéntico, comprobado localmente y por CI.
Subida: https://github.com/Krazel/Alarmy/actions/runs/38389891412

Incluye espacio libre real para grabación, almacenamiento/borrado en Ajustes,
onda suavizada y acotada, nota bajo estado al despertar, contador de sonidos
pulsable y ajuste único Grabar y analizar. Conservación de 90 días por defecto.
Prueba nocturna, batería y FPS en dispositivo físico siguen pendientes.

Referencias oficiales consultadas para esta entrega:
- https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/
- https://docs.github.com/en/billing/concepts/product-billing/github-actions

Entrega completada: API Apple VALID / IN_BETA_TESTING, build
c3d57c3f-fc0e-4f02-a37e-c0945a1de6f4, mismo grupo interno de un tester.
Notas ES/EN guardadas y releídas. Sin testers externos ni App Review.
upload.json acredita la subida; testflight-verified.json acredita estado Apple y
asignación; credentials-cleanup.json confirma siete secretos eliminados y entorno
vacío. Originales privados conservados; no se publican claves ni certificados.
