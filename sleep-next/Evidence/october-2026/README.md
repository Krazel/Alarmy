# Alarma — correcciones de octubre

12/10/2026. Trabajo local posterior a `7fc068e`, sobre la entrega existente
**1.1 (1)**. Esta carpeta no acredita una nueva build ni una noche física.

## Cambios preparados

- Borrado y retención: se guarda la intención antes de tocar el audio. Un
  relanzamiento puede completar el borrado; se eliminan los archivos auxiliares
  de recuperación para que no reaparezcan clips borrados.
- Recuperación y borrado comparten un turno de acceso a archivos. Un PCM ausente
  se comunica como recuperación fallida y conserva el manifiesto.
- Posponer espera al cierre de captura antes de tomar la sesión. Recupera la
  captura detenida por la alarma, conservando una pausa voluntaria. Relanzamiento
  o fallo de escritura exigen volver a habilitar el micrófono explícitamente.
- Las interrupciones esperan al último clip; una notificación duplicada conserva
  la decisión original de reanudación.
- El recibo de detener la alarma de iOS 26 se conserva hasta guardar el final de
  la noche. La reproducción libera la sesión de audio al terminar o fallar.

Se conserva SwiftUI nativo, iPhone iOS 16+, ES/EN, diseños, assets y diario.
Las categorías siguen siendo sugerencias locales corregibles, sin diagnóstico.
No se envía audio personal a terceros.

## Evidencia de esta entrega

| Comprobación | Resultado actual |
| --- | --- |
| Metadatos, idiomas y recursos | Correcto: [scope-check.json](scope-check.json) |
| Espacios/errores de diff | `git diff --check` correcto |
| Nuevas regresiones XCTest | 15 preparadas; **sin ejecutar** |
| Compilación Swift y pruebas de interfaz | **Pendientes** de Xcode 26 en macOS |
| Script Bash | Sin validar: Git Bash no arranca por restricción de Windows |
| Noche física y batería | **Pendientes**: [protocolo](PHYSICAL-NIGHT.md) |
| TestFlight | Entrega interna 1.1 (1) del 02/10 conservada; **ninguna subida nueva** |

La comprobación estática no valida el comportamiento Swift. Comprueba 140 entradas
ES/EN, 13 recursos respecto a `7fc068e` (normalizando saltos de línea de textos de
Windows), iOS 16 y familia iPhone. Las pruebas nativas de la entrega anterior
no validan los cambios actuales.

En un Mac con Xcode 26, XcodeGen y simulador iPhone:

```sh
cd sleep-next
bash scripts/validate-october.sh
```

El script prepara pruebas de persistencia, recuperación, segmentación acústica,
interrupciones y un flujo de clips de interfaz, además de Release iPhone sin firma.
Guarda SHA, árbol de trabajo, logs y resultados en una carpeta fechada. No firma,
exporta ni sube a TestFlight. Ejecutarlo sobre un árbol limpio y conservar logs
y `.xcresult` fuera de Git. No declararlo correcto sin el resultado de Xcode.

## Bloqueos y siguiente paso

Windows no dispone de Swift/Xcode. El terminal no conecta con GitHub. El conector
confirmó el 12/10 que `Krazel/Alarmy` sigue **público**; las reglas vigentes requieren
código privado. Los cambios quedan locales. Antes de CI hay que conciliar
privacidad y comprobar plan, cuota y acceso de runners/automatizaciones sin gastos.

La validación GitHub queda manual, condicionada a repositorio privado y
`IOS_CI_APPROVED=true`. No se ha habilitado esa variable ni lanzado un run. El flujo
histórico TestFlight requiere fuente validada y decisión de versión nueva; no
utilizarlo para repetir 1.1 (1).

Biblioteca PR-019 leída en revisión 10. El API desde el terminal falló por conexión
y el navegador rechazó el acceso por permiso denegado. La actualización queda
[pendiente](library-update-pending.json); no está sincronizada.

Siguiente resultado: compilación/regresiones de este código y prueba física con
el titular. El borrador conserva 1.1 (1) en metadatos; no es un binario nuevo.
Al preparar la entrega de correcciones corresponde una decisión agrupada de
versión (prevista 1.1.1, build 1), comprobando versiones aceptadas por Apple.
No se cambia versión ni se inicia App Review/publicación comercial aquí.
