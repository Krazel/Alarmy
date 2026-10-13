# Estado de Alarma — 14-10-2026

## Entrega TestFlight interno 1.5 (1) — verificada por API

Autorización del 14/10: «subelo a test». Apple confirma `VALID` e
`IN_BETA_TESTING`, build `00b99c93-8994-477c-981d-054f4c10bc79`, iOS mínimo16.
Mismo grupo interno del titular (1 tester), sin enlace público ni pruebas externas.
Notas es-ES/en-US guardadas y releídas. Sin envío App Review ni publicación.
Fuente de entrega `f788b34aff1a208ea401c46063fb3932f6249ac1`; árbol de aplicación
idéntico al validado `d6700fc` (25/25, Debug/Release correctos).
Firma/subida correcta: https://github.com/Krazel/Alarmy/actions/runs/38484310553 .
SHA256 IPA `72958a4d37d5ab9f051312be64d32b61c58330d4f4c8401a617f32121a5bafa5`.
Siete secretos temporales eliminados; entorno releído vacío, originales locales
conservados. Recibos en QA-2026-10-14-TestFlight. La candidata incluye análisis
local experimental sin Salud y las correcciones de crescendo/luz. Precisión
fisiológica y noche física/consumo pendientes. Luz gradual solo con app abierta.
Biblioteca PR-019 guardada y releída por API, revisión 30; versión 1.5 (1),
TestFlight interno, ficha App Store creada y anuncios No; historial conservado.

## Implementación validada 1.5 (1) — análisis local y estadísticas ampliadas

Usuario aprueba los nueve bloques y confirma «quiero todo local, que hagamos
nuestra propia forma a partir del audio, aunq no sea 100% buena». Implementado
estimador heurístico v1: envolvente de energía a 10 Hz y observaciones de 30 s,
contraste, periodicidad y variación de intervalos; contexto sostenido compatible
con respiración sugiere sueño. Patrones estables/variables generan hipótesis de
profundo/REM; ligero es la hipótesis restante. No entrenado con PSG, precisión
no validada: puede confundir respiración despierto, acompañantes o ruido rítmico.
Aviso experimental visible, cobertura explícita y huecos desconocidos. No inventa
ciclos ni porcentajes. Noche antigua sin características necesarias queda sin
estimación. Permisos, consultas y capacidad de Salud retirados.

Incluye hábitos opcionales (sin registrar distinto de ninguno), asociaciones
con mínimo de días, comparación de sesiones, siestas separadas, objetivo personal,
edición/restauración de horarios conservando original, continuidad del sueño,
sonidos por categorías/duración/hora, calidad de captura y CSV sin notas/audio.
Alarmas: cuenta posposiciones futuras y hora observada solo cuando la app sabe
que reprodujo; hora programada separada y datos antiguos desconocidos.
Se conservan correcciones previas de crescendo/luz. Audio y análisis locales.

Fuente de aplicación 132d279; ajuste posterior de prueba d6700fc. CI inicial 38476297503 falló por expresión CSV demasiado compleja
para el compilador Swift; dividida en pasos tipados. El segundo pase compiló
Debug y pasó 23/24 pruebas; corregida propagación de identificadores de
accesibilidad en hábitos. El tercer pase pasó 24/25; corregido el toque del
interruptor de Siesta en la prueba. Validación final nativa 38480354936 correcta: 25/25 pruebas, cero fallos u
omitidas, Debug y Release iPhone sin firma correctos. Capturas nativas revisadas
en QA-2026-10-14-insights, con datos sintéticos.
No afirmar precisión fisiológica ni prueba en iPhone real.
La implementación se entregó después como TestFlight interno 1.5 (1); véase arriba.
Biblioteca PR-019 actualizada y releída por API, revisión 29; resultado final
y siguiente paso guardados, conservando distribución y tracking.


## Historial previo — investigación y selección de funciones

Estado anterior a la aprobación de la heurística experimental descrita arriba.
El usuario rechaza exigir Salud para tiempo dormido y fases. Este objetivo
sustituye la dependencia de Salud como decisión de producto; el motor autónomo
todavía no está implementado. El análisis acústico actual detecta actividad y
periodos tranquilos, no fases fisiológicas. Investigación y propuestas por pasos
en research/sleep-analysis-2026-10-13.json, pendientes de selección de extras.
No se ha encontrado todavía un modelo acústico gratuito integrable con licencia
y validación suficientes; no contratar servicios ni enviar audio a terceros.
Retirada del código la valoración subjetiva duplicada del resumen; se mantienen
las caras y la nota inferior. Diff revisado, sin repetir CI nativa para esta
eliminación mínima. La validación de 1.4.1 descrita debajo precede a este ajuste.
Distribución vigente: TestFlight interno 1.4 (1), sin nueva subida.
Biblioteca PR-019 guardada y releída por API, revisión 27; tracking conservado.

## Corrección validada — volumen y luz gradual, candidata 1.4.1 (1)

Usuario confirma que el fallo ocurre con el iPhone bloqueado. La alarma del
sistema recibía el tono original; el crescendo solo existía en AVAudioPlayer
con la app abierta. Se prepara un CAF PCM de 29 segundos en Library/Sounds,
con subida incorporada de -40 dB a 0 dB durante 25 segundos, para AlarmKit y
notificaciones antiguas. Se aplica al inicio, posponer, cambio de hora y ventana
inteligente; original conservado y escritura atómica. Si iOS repite el archivo,
repite la subida. No se modifica el volumen del sistema ni se promete controlar
la pantalla bloqueada. Luz abierta: nivel nocturno bajo antes de subir hasta
máximo en los minutos elegidos y restauración al salir. Textos ES/EN explícitos.
Validación 38450915451: Debug y PCM correctos, 8/10; dos aserciones de hardware
del simulador corregidas con adaptador de pantalla y límite de Data Protection.
Segunda validación 38453395483 correcta: 10/10 pruebas, cero fallos/omitidas,
Debug y Release iPhone correctos; fuente 3f6031d. Evidencias: QA-2026-10-13-gradual.
Prueba real con iPhone bloqueado pendiente.
Distribución vigente sigue 1.4 (1). Esta corrección aún no está en TestFlight.
Biblioteca PR-019 guardada y releída por API, revisión 26; conserva historial
y distribución vigente.


## Entrega completada — TestFlight interno 1.4 (1)

Implementación solicitada por «Pero implementalo y subelo a testflight».
API Apple confirma VALID / IN_BETA_TESTING, build
507e17fd-e366-4d8e-a84d-7408c755edd7, mismo grupo interno con un tester,
sin enlace público, sin App Review externo ni publicación en tienda.
Subida 38424950867 correcta; fuente af3ca04bd7bcab022cbbd02cad7f9c051edb1835,
árbol de app idéntico al validado 4cc0b89826a3ae1f398ec547df48d46d04d676b6.
Incluye diario compacto, sonidos separados por categorías/reproductor y estadísticas
visuales. ES/EN, iPhone iOS16+. Fases de Salud; calidad percibida sin /100 inventado.
Notas de TestFlight ES/EN guardadas y releídas. Siete secretos temporales eliminados
y entorno releído vacío. Comprobantes y capturas nativas en QA-2026-10-13-diary.
13 pruebas iniciales y 4 finales correctas; Debug y Release compilados. La segunda
CI agotó tiempo en el cierre del runner tras todas las etapas exitosas; el guard
verificó esos resultados y el SHA exacto, sin repetir pruebas ni omitir fallos.
Prueba nocturna física/FPS/batería pendiente.
Biblioteca PR-019 guardada y releída por API, revisión 24; historial
y tracking conservados. Ya figura la entrega 1.4 (1) en la web de proyectos.

## Diario y estadísticas — candidata 1.4 (1), implementación autorizada

El usuario pide «Pero implementalo y subelo a testflight». Referencias aprobadas:
01-diario-sonidos.png y 02-estadisticas.png de diary-statistics-2026-10-13.
Implementados resumen compacto antes de las caras, nota inmediatamente debajo,
sonidos en pantalla separada con categorías/reproductor y estadísticas visuales.
La calidad es la valoración humana; no inventar /100. Fases y despertares solo
con datos de Salud, con estados vacíos explícitos. Fixtures exclusivos de DEBUG.
Mantiene iOS16+, ES/EN. Candidata 1.4 (1), conserva la línea Apple existente.
Validación inicial 38418974331: 13/13, Debug simulador y Release iPhone correctos.
Capturas ES/EN y modo nocturno revisadas: caras visibles y orden solicitado.
Ajuste final: duración de clips mm:ss y barras de horarios más legibles; segunda
validación limitada a esos cambios en 38421555665: 4/4 y Debug/Release correctos.
La ejecución terminó cancelled por tiempo al cerrar el runner tras todas las
etapas exitosas. Guard explícito verifica etapas, artefacto, logs y SHA exacto;
no acepta otros runs cancelados ni cambios de app. Firma/subida 38424950867 en curso,
fuente af3ca04 con árbol nativo idéntico a 4cc0b89.
Biblioteca PR-019 guardada y releída, revisión 23; vigente 1.3.1 (1).

## Reordenación visual de diario/estadísticas — referencias aprobadas

Usuario corrige el orden: resumen y gráfico primero, sonidos en una única fila
que abre detalle, luego caras visibles desde el primer vistazo y nota debajo.
Acceso a estadísticas con icono junto al calendario. Pide imágenes de la UI.
Dos láminas creadas con image_gen en sleep-next/Design/diary-statistics-2026-10-13:
diario/detalle de sonidos y estadísticas/vista desplazada. Datos ficticios,
fases de Salud; pendientes de selección humana e implementación. TestFlight
vigente 1.3.1 (1) se conserva. Prompts, referencias y SHA guardados.
Biblioteca PR-019 actualizada y releída, revisión 22, sin cambiar distribución.

## Entrega completada — TestFlight interno 1.3.1 (1)

Autorizada por «subelo a test». Subida 38389891412 completada; fuente
06344eb4fbba3045a783d47abbaa99afcf4bacc1, mismo árbol de app que la validación
38387418695 (11/11 y Release iPhone). API Apple confirma VALID / IN_BETA_TESTING,
build c3d57c3f-fc0e-4f02-a37e-c0945a1de6f4, mismo grupo interno del titular
con un tester. Notas ES/EN guardadas y releídas. Sin App Review ni testers externos.
Siete secretos temporales eliminados y entorno releído vacío. Recibos en
QA-2026-10-13-feedback. Prueba nocturna física, FPS y batería siguen pendientes.
Biblioteca PR-019 actualizada y releída por API, revisión 21, versión 1.3.1,
build 1, distribución interna; historial y tracking conservados.

## Correcciones tras la primera noche — candidata 1.3.1 (1)

Usuario vio al despertar aviso de espacio; pide almacenamiento/borrado total,
onda fluida sin recorte, nota bajo el estado al despertar, resumen de sonidos
pulsable y unificar grabar/analizar en Ajustes.
Causa probable identificada: límites internos 256 MB/noche y 512 MB totales
reportaban Cocoa fileWriteOutOfSpace incluso con espacio libre en el iPhone.
Se sustituyen por capacidad real con reserva de seguridad, sin borrar grabaciones
automáticamente. Borrado explícito conserva diario/estadísticas y usa cola durable.
Onda a 60 FPS solicitados con interpolación y geometría acotada; pausa al ir al fondo
y respeta Reducir movimiento. Rendimiento físico pendiente.
Validación nativa enfocada completada: 11/11 y Release iPhone sin firma correctos,
run 38387418695, fuente fc561181644e32f306849e4686cf41e5c6446962.
Capturas nativas ES/EN revisadas y guardadas; vigente TestFlight 1.3 (1), sin nueva subida.
Evidencias: `sleep-next/Design/night-feedback-2026-10-13`.
Biblioteca PR-019 actualizada y releída por API, revisión 20; conserva historial,
versión distribuida 1.3 (1) y tracking (interno, ficha creada, sin anuncios).

## Entrega completada — TestFlight interno 1.3 (1)

El usuario autoriza la subida el 13/10. **1.3 (1) disponible en TestFlight interno
para el titular**; API Apple `VALID` / `IN_BETA_TESTING`, build
`b5ab76cb-98c3-4d71-8779-2f07eab709f5`. Notas ES/EN guardadas y releídas,
mismo grupo interno con un tester. Sin App Review ni testers externos.
Subida [38327591454](https://github.com/Krazel/Alarmy/actions/runs/38327591454),
fuente `a200f5eee4fb4ff128c0f41da44f149dbd9b0764`, árbol de app idéntico a
`271e448`, validación reutilizada 38325929640 (9/9 y Release iPhone).
Incluye noche A Onda/edición de hora, análisis, estadísticas y clips por categoría.
Siete secretos temporales eliminados y entorno releído vacío; originales conservados.
Recibos: `QA-2026-10-13`. Prueba nocturna física/batería pendiente.
Biblioteca PR-019 guardada y releída por API, **revisión 19**, versión 1.3,
build 1, TestFlight Interno; historial completo y tracking conservados.

## A Onda implementada y validada — candidata 1.3 (1)

El usuario aprueba el diseño y pide quitar puntos e icono de alarma, centrar
la pantalla y editar la hora en un panel inferior sin finalizar la noche.
Implementación en candidata 1.3 (1), con cambios de hora transaccionales y
actualización del límite del capturador. No cambia TestFlight 1.2 (1).
Evidencias: `sleep-next/Design/onda-implementation-2026-10-13`.
Fuente `271e448edae68103eff1535e4cb66a991b9abce6`, validación final
[38325929640](https://github.com/Krazel/Alarmy/actions/runs/38325929640):
**9 pruebas correctas, 0 fallos/omitidas**, Debug simulador y Release iPhone.
Capturas ES/EN revisadas: sin puntos ni icono, centrado, onda y panel inferior.
También conserva la hora pospuesta al editarla. No acredita prueba nocturna física.
Biblioteca PR-019 guardada y releída por API en **revisión 18**, tracking e historial
conservados. Estado de esa implementación antes del encargo de subida: candidata sin distribuir.
La entrega posterior 1.3 (1) queda registrada en la sección superior.

## Propuestas nocturnas minimalistas — 13/10

Última dirección humana: muy visual y con pocas cosas. ChatGPT Imágenes:
A Onda, B Halo y C Bruma, tras una primera exploración más densa. Hora,
onda, control del micrófono y gesto ascendente sobre el fondo aprobado.
Imágenes y prompts: `sleep-next/Design/night-variants-2026-10-13`.
Elegida A · Onda con ajustes: sin mute, hora actual grande, alarma separada,
flecha menor y «Parar»/«Stop». Propuesta actual `onda-r2-es-en.png`.
Historial: la exploración visual no cambió código ni distribución. La dirección
A fue aprobada después y su implementación se detalla en la sección superior.
Biblioteca PR-019 actualizada y releída: revisión 17.


## Ampliación de la candidata — grabaciones por categoría

Encargo 13/10: categorías con contador y escucha de un fragmento cada vez.
Implementado en la misma candidata 1.3 (1), sin cambio de distribución: cinco
categorías, flechas dentro del grupo, corrección/borrado con actualización de
contadores y ejemplo de 30 clips (16 tos). ES/EN y diario A claro/nocturno.
Fuente `f2fa3b6`; validación nativa enfocada correcta: **4 pruebas, 0 fallos/omitidas**,
Release iPhone y cuatro capturas de simulador revisadas:
https://github.com/Krazel/Alarmy/actions/runs/38317706859 .
Diseño y evidencias: `sleep-next/Design/clip-categories-2026-10-13`.
Biblioteca PR-019 guardada y releída por API, **revisión 15**; tracking,
versión distribuida e historial conservados. Recibo junto a las capturas.
TestFlight interno permanece en 1.2 (1); no se ha subido esta candidata.


## Candidata implementada y validada — noche y análisis 1.3 (1)

Nuevo encargo del usuario: diseño de noche con ChatGPT Imágenes, onda real,
terminar con gesto hacia arriba, tres modos de alarma y estadísticas completas.
Implementación en `sleep-next`, ES/EN e iOS16+. Se mantienen fondo aprobado,
diario A y barra inferior. Propuesta y decisiones en
`sleep-next/Design/night-analysis-2026-10-12/README.md`.

Análisis acústico local en épocas de 30 s, cobertura y reposo estimado; fases
solo de Salud, calidad percibida del usuario. No se infieren fases clínicas con
el micrófono. Clasificación de clips temporal aunque no se conserven; resúmenes
persisten después de borrar/caducar audio. Ventana acústica experimental con
alarma de hora límite como respaldo. Validación nativa enfocada correcta:
23 pruebas pasadas, 0 fallos/omitidas, Release iPhone y ocho capturas revisadas.
Fuente `b02b7d4bea6a4b3d449d11849d50f9e4dc961b84`, run
[38315535656](https://github.com/Krazel/Alarmy/actions/runs/38315535656).
Simulador iPhone 17 Pro/iOS26.4.1; gesto parcial/completo y UI ES/EN verificados.
No acredita micrófono físico, batería, Salud del dispositivo ni despertar bloqueado.

Biblioteca PR-019 actualizada y releída por API, **revisión 14**; conserva versión
1.2/build1, tracking e historial. Recibo junto al diseño.

La distribución interna vigente sigue siendo **1.2 (1)**. Esta candidata no se
ha enviado a TestFlight ni a App Review. Prueba nocturna física/batería pendiente.

## Entrega completada — UI 1.2 (1)

El usuario pide subir los nuevos cambios a TestFlight. Candidata **1.2 (1)**:
diario A cuaderno claro/nocturno, fondo nocturno original, caras en semana y
calendario, seis ejemplos aislados y retención nueva 90 días. iPhone iOS16+, ES/EN.
Fuente `ebf86c537bc3c55b6c9a70a42c55b59c600356a4`, compilación enfocada
[38307811714](https://github.com/Krazel/Alarmy/actions/runs/38307811714) correcta:
5 pruebas pasadas, 0 fallos/omitidas y Release iPhone. Subida firmada
[38309075753](https://github.com/Krazel/Alarmy/actions/runs/38309075753) correcta.
**1.2 (1) disponible en TestFlight interno para el titular**: API confirma
VALID / IN_BETA_TESTING, build `77b4588d-6a9a-404c-b55f-7453391ea508`.
Notas ES/EN guardadas y releídas; grupo interno existente con un único titular.
Se reutiliza firma/perfil existente y los siete secretos temporales en el mismo
entorno `alarma-local-qa`, rama `codex/native-sleep-rebuild`. Siete secretos
eliminados y entorno releído vacío. No se amplían testers ni se envía App Review.
Recibos nuevos separados en `QA-2026-10-12-UI`; no sobrescribir la entrega previa.
Biblioteca PR-019 guardada y releída por API, **revisión 13**, versión 1.2,
build 1, TestFlight Interno; tracking, URLs e historial conservados.

## Encargo posterior — UI y ejemplos del diario

Propuestas con ChatGPT Imágenes de principal día/noche, editor, sonidos, noche
activa, alarma sonando, diario, calendario, clips, ajustes y ejemplos, más opciones
del diario. Conservada la barra inferior Alarma / Diario / Ajustes. Se recupera
el fondo nocturno aprobado original (SHA idéntico); fondo de día conservado.
Preparados seis escenarios en modo desarrollador, aislados en memoria; semana y
calendario con caras de despertar y retención de 90 días por defecto, conservando
elecciones previas. [Propuestas y uso](sleep-next/Design/proposals-2026-10-12/README.md).
El usuario ha elegido **A · Cuaderno actual, con versión nocturna**; se conserva
su distribución y tema oscuro adaptativo. Verificación nativa enfocada correcta:
5 pruebas pasadas, 0 fallos/omitidas y Release iPhone, fuente `2edfbcd`.
[Resultado y capturas](sleep-next/Design/proposals-2026-10-12/validation.json).
La preparación del diseño se cerró antes de otra subida. Por instrucción posterior
se ha entregado 1.2 (1) con estos cambios: véase la entrega UI arriba.
Biblioteca PR-019 actualizada y releída en revisión 12; elección A, galería,
validación y próximo paso registrados, manteniendo versión y tracking.

## Historial — entrega de correcciones 1.1.1 (1)

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
