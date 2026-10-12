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

Estado inicial: candidata preparada; compilación, regresiones y subida pendientes.
No declarar TestFlight disponible hasta verificar procesamiento/asignación por API.

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
