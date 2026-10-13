# TestFlight interno — Alarma 1.5 (1)

Encargo humano del 14/10/2026: «subelo a test». Mismo grupo interno del titular,
sin testers externos ni envío a App Review.

Fuente de entrega: `f788b34`. Árbol de aplicación idéntico al validado en
`d6700fc`: [25/25 pruebas y Debug/Release correctos](https://github.com/Krazel/Alarmy/actions/runs/38480354936).
El cambio de entrega adapta únicamente el workflow a 1.5 y a la retirada de Salud.

[Firma y subida](https://github.com/Krazel/Alarmy/actions/runs/38484310553).
Reutiliza certificado y perfil App Store existentes. Credenciales temporales en
el entorno `alarma-local-qa`, limitado a `codex/native-sleep-rebuild`; originales
locales conservados. Sin datos de audio personales en los artefactos.

Los recibos de esta carpeta separan preparación, aceptación de subida,
disponibilidad interna por API, limpieza de secretos y actualización de la
biblioteca. Solo `testflight-verified.json` con `IN_BETA_TESTING` confirma que
la build está disponible al titular; el recibo de subida por sí solo no lo prueba.

Las notas ES/EN explican el método acústico experimental, local y sin Salud.
Precisión fisiológica no validada. Pendiente prueba nocturna en iPhone físico,
consumo y crescendo bloqueado; iluminación gradual con la app abierta.

Entrega confirmada por API: `VALID` / `IN_BETA_TESTING`, build
`00b99c93-8994-477c-981d-054f4c10bc79`, mismo grupo del titular con 1 tester.
Notas ES/EN verificadas. Siete secretos temporales eliminados; entorno vacío.
