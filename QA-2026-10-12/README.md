# Alarma 1.1.1 (1) — entrega TestFlight autorizada

Encargo humano del 12/10/2026: subir los nuevos cambios a TestFlight. Aclaración
posterior expresa: usar API, mantener **Krazel/Alarmy público** para Actions
estándar gratuitas; no gastar dinero. Esta excepción afecta a Alarma y prevalece
sobre la regla general de código privado. No modifica otros productos.

La API confirmó PUBLIC después de revertir el cambio a PRIVATE realizado al
comenzar por la regla general. El entorno `alarma-local-qa` conserva su única
rama `codex/native-sleep-rebuild`; no se añaden testers ni permisos nuevos.
La API Apple confirma que la única build de Alarma era 1.1(1), VALID. Se prepara
1.1.1(1), incremento de corrección de la línea existente, sin duplicar binarios.

Fuente entregada: `dcbdddc8ec1a3540fdc8e8c577ba47c88cbb74bc`.
[Validación correcta](https://github.com/Krazel/Alarmy/actions/runs/38295534654):
49 pruebas pasadas, cero fallos y cero omitidas, incluidas las 15 regresiones
nuevas. Release para iPhone compilado. Simulador iPhone 17 Pro, iOS 26.4.1;
estas pruebas no acreditan noche física, batería ni ejecución en iOS 16–25.

[Subida correcta](https://github.com/Krazel/Alarmy/actions/runs/38297166526):
archivo firmado/exportado y aceptado por Apple, misma fuente validada.
[Recibo](upload.json) y [flujo completo](upload-run.json). API Apple verificada:
**VALID / IN_BETA_TESTING**, build `8839b3ba-7189-45b9-9cf9-26802835cf5d`,
disponible en el grupo interno existente «Alarma — Titular», un único tester,
sin enlace público. Notas castellano/inglés guardadas y releídas. Caduca el
10/01/2027. [Recibo Apple](testflight-verified.json) ·
[Abrir TestFlight en App Store Connect](https://appstoreconnect.apple.com/apps/6818287946/testflight).

Los siete secretos temporales del entorno se eliminaron y se releyó vacío:
[recibo](credentials-cleanup.json). El runner también completó su limpieza.
Las credenciales originales locales se conservan; no se publicó IPA ni credencial.

Biblioteca PR-019 actualizada por API admitida, lectura completa fresca y PUT
con revisión de concurrencia: **revisión 11**, guardado verificado. Versión,
distribución, resumen, siguiente paso y evidencia conciliados; tracking y el
historial de 1.1 (1) conservados. [Recibo](library-receipt.json).
El pendiente anterior de octubre queda resuelto por esta entrega.

Validación manual en runner estándar `macos-26`, máximo 20 minutos: 15 regresiones
nuevas y pruebas relacionadas de persistencia/captura/segmentación más un flujo UI
de clips; Release iPhone. Sin nueva batería de capturas, corpus ni noche física.
Firma/subida separadas y condicionadas al éxito y al árbol exacto de esa validación.
Perfil, certificado y API existentes se reutilizan en el destino temporal que el
usuario ya autorizó. Los secretos temporales se eliminan al terminar.

No se cambian plan, presupuestos, límites de gasto ni runners de pago. Referencia
actual consultada: [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions).
El runner estándar en un repositorio público no requiere cuota privada. La
consulta de cuota por API falló por falta de scope `user`; se cancela el acceso
de navegador tras la aclaración del usuario.

Se conserva iPhone iOS16+, SwiftUI, ES/EN, diseño y audio local. La prueba nocturna
física y batería siguen pendientes; [protocolo](../sleep-next/Evidence/october-2026/PHYSICAL-NIGHT.md).
TestFlight interno del titular; sin App Review externo ni publicación comercial.
