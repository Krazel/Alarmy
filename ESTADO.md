# Estado de Alarma — 12-10-2026

## Encargo actual y correcciones locales

**Actualización del encargo, 12/10:** el usuario solicita subir los cambios nuevos
a TestFlight y ordena expresamente mantener **Krazel/Alarmy público**, usando API
y Actions estándar gratuitas, sin gastos. Excepción de Alarma a la regla general
de privado. Se revirtió por API el cambio a privado y se verificó PUBLIC.
Entrega **1.1.1 (1)** disponible en TestFlight interno para el titular;
API Apple confirma VALID / IN_BETA_TESTING y notas ES/EN. 49 pruebas pasadas,
incluidas las 15 regresiones nuevas, cero
fallos/omitidas y Release iPhone correcto. Fuente `dcbdddc8ec1a3540fdc8e8c577ba47c88cbb74bc`.
Los siete secretos temporales se eliminaron y el entorno se releyó vacío.
La 1.1(1) anterior se conserva. [Entrega y recibos](QA-2026-10-12/README.md).
Biblioteca PR-019 guardada y releída, revisión 11; tracking/historial conservados.
El pendiente anterior de octubre está conciliado. Siguiente paso: instalar la
build y realizar la noche física/batería y comprobar iOS 16–25; siguen pendientes.
Esta autorización posterior sustituye los bloqueos de privacidad y la prohibición
de nueva subida descritos abajo, que corresponden al encargo previo de cierre.

## Historial del encargo previo de cierre — sustituido donde se indica arriba

Propietario PR-019: `01a0708e-0558-78b1-866c-801b9cf35996`. Continúa el cierre
de octubre según `../.studio/coordination/cierre-octubre-20261012.md`; no repetir
TestFlight ni enviar App Review automáticamente. SwiftUI iPhone iOS 16+, ES/EN,
audio local y diseños aprobados conservados.

Correcciones posteriores a `7fc068e`: borrado/retención con intención persistente
y eliminación de auxiliares de recuperación; recuperación y acceso a archivos
ordenados; posponer espera al cierre de captura y respeta la pausa manual;
interrupciones ordenadas; recibo de detener alarma reconocido después de guardar
la noche; sesión de reproducción liberada al terminar/fallar. Se preparan
15 regresiones XCTest; **no compiladas ni ejecutadas con Xcode todavía**.

[Entrega revisable y límites](sleep-next/Evidence/october-2026/README.md) ·
[Prueba nocturna/batería y formulario](sleep-next/Evidence/october-2026/PHYSICAL-NIGHT.md).
Comprobación estática correcta: 140 textos ES/EN, 13 recursos conservados,
iPhone/iOS 16 y CI sin trigger de push. No acredita funcionamiento nativo.

La entrega interna **1.1 (1)** del 02/10 permanece como último binario entregado.
Los metadatos del borrador siguen en 1.1 (1); no usarlo para otra subida con esa
combinación. Antes de una nueva candidata, agrupar estas correcciones en la
decisión de versión (prevista 1.1.1, build 1) y comprobar App Store Connect.

Bloqueos: Windows sin Swift/Xcode; terminal sin conexión con GitHub. Conector
confirma repositorio público el 12/10; conciliar privacidad y comprobar cuota,
runners y acceso de CI sin gastos antes de subir estos cambios. Validación
GitHub manual y condicionada a privado/`IOS_CI_APPROVED`; no se habilita ni ejecuta.

Biblioteca PR-019 leída en **revisión 10**, `2026-10-12T12:29:40.832Z`.
Esta entrega **pendiente de guardado**: fallo de conexión del API y acceso de
navegador rechazado por permiso denegado. [Actualización pendiente](sleep-next/Evidence/october-2026/library-update-pending.json),
con lectura fresca/mezcla/verificación obligatorias y tracking conservado.

Siguiente paso: compilar/regresiones en Mac o CI privada con cuota comprobada;
después prueba nocturna física con el titular. No se promete fecha de finalización
ni se afirma autonomía o fiabilidad nocturna sin resultados reales.

## Historial de entrega — 02-10-2026

- Producto: PR-019. Tarea propietaria: `01a0708e-0558-78b1-866c-801b9cf35996`.
- Implementación vigente: `sleep-next`, SwiftUI, iPhone iOS 16+, castellano e inglés. `Alarma`, `sleep-native` y `native-ios` se conservan como antecedentes.
- Candidata entregada: **1.1 (build 1), TestFlight interno disponible para el titular**. Versión pública: por confirmar; sin publicación en App Store.
- Fuente validada: `f9bfe70d0b6a3e5bf33a6136fe619765ed50fc44`, rama `codex/native-sleep-rebuild`.
- [CI completa correcta](https://github.com/Krazel/Alarmy/actions/runs/36894350167): 50 pruebas unitarias/integración + 6 UI; el flujo nocturno se repite en iPhone SE. 57 ejecuciones, 56 pruebas únicas, cero fallos; Release iPhone correcto. No se repiten pruebas para la subida solicitada.
- Diario: detalle y navegación de clips, reproducción desplazable, sugerencias por intervalos, corrección manual, reintento y borrado. Se corrigen pausas, ruido sostenido, recuperación, fallos de guardado de alarmas/posponer y solapamientos de Salud.
- [Informe, métricas y capturas nativas](QA-2026-10-01/README.md). Banco de 22 fuentes reales CC0/66 variantes: 22/22 etiquetas principales en limpio, 20/22 atenuadas y 20/22 con ventilador. Conjunto pequeño y evaluación repetida; no certifica una noche real ni todos los intervalos.
- IPA sin firma comprobado: `artifact/completion-20261001/run-f9bfe70/AlarmaNext-1.1-build-1-f9bfe70-unsigned-Local-QA.ipa`. Mínimo iOS 16, AlarmKit opcional, ES/EN y mecanismos de Debug excluidos. No se instala directamente.
- **Entrega TestFlight completada.** Automatización `.github/workflows/sleep-next-testflight.yml`, workflow 372396597. La ficha [Alarma de Krazel](https://appstoreconnect.apple.com/apps/6818287946) está creada y releída por API: App ID 6818287946, Bundle ID `com.krazel.alarmanext`, SKU `krazel-alarmanext`, idioma principal es-ES. «Alarma» estaba ocupado en Apple; el iPhone conserva el nombre Alarma. El usuario autorizó perfil y clave API temporal en `Krazel/Alarmy → alarma-local-qa → codex/native-sleep-rebuild`. Apple aceptó 1.1(1) en el run 36932912801 y su API confirma `VALID` / `IN_BETA_TESTING`: build `d3c23444-ee71-45d7-b8bc-ad18eae072a1`, caducidad 30-12-2026, mínimo iOS 16. Grupo interno asignado con un único titular y notas ES/EN verificadas: `QA-2026-10-01/testflight-verified.json`. Sin pruebas externas ni App Review.
- Se esperó a que terminase `Krazel Studio — cerebro central` (`01a07129-c85d-7d23-9863-d20ed1ed02f8`) y se recibió el procedimiento Apple/GitHub el 01-10-2026. Confirma reutilizar certificado, API, entorno existente y fuente validada, sin ampliar pruebas. Consulta conservada en Studio: `.studio/alarma-testflight-procedure-20261001.md`.
- El 02-10-2026 el usuario autorizó expresamente perfil App Store y secretos privados temporales en el entorno existente. Perfil IOS_APP_STORE creado, releído con Bundle ID/certificado correctos; credenciales configuradas por stdin sin publicar valores. La primera firma/exportación funcionó, pero Apple rechazó la subida [36932439359](https://github.com/Krazel/Alarmy/actions/runs/36932439359) por familia iPad no deseada (90474) y texto NSHealthUpdateUsageDescription ausente (90683). Corregidos solo cuatro archivos de metadatos en `35a7c56`: familia iPhone en el target y texto Salud ES/EN que aclara que no se solicita escritura. Código, assets y pruebas permanecen iguales a la fuente validada. Nueva subida [36932912801](https://github.com/Krazel/Alarmy/actions/runs/36932912801) correcta, con firma, exportación y aceptación Apple verificadas; `QA-2026-10-01/upload.json` conserva SHA-256. Grupo interno «Alarma — Titular» creado y releído con un único titular y sin enlace público.
- Firma previa: certificado existente verificado, Bundle ID propio con HealthKit y perfil ad hoc para dos iPhone preparados. No se ha ejecutado la firma local ni la instalación por USB; ese itinerario queda como antecedente.
- Limpieza completada: ocho secretos temporales GitHub eliminados y entorno releído vacío; recibo `QA-2026-10-01/credentials-cleanup.json`. Las credenciales originales locales se conservan. El runner eliminó su keychain y archivos temporales; no se publicó IPA, perfil ni clave.
- Instalación, noche física, batería y alarmas en iOS anterior a 26: pendientes; no bloquean el nuevo encargo de subida. Audio personal en el teléfono.
- Biblioteca D1: PR-019 guardada y releída por API, revisión **9**, `2026-10-01T22:12:53.339Z` (02-10 en Madrid). Estado En producción; TestFlight Interno con enlace comprobado, App Store Creada en App Store Connect, anuncios No. Entrega, notas, evidencias y limpieza registradas en la misma ficha.
