# Estado de Alarma — 01-10-2026

- Producto: PR-019. Tarea propietaria: `01a0708e-0558-78b1-866c-801b9cf35996`.
- Implementación vigente: `sleep-next`, SwiftUI, iPhone iOS 16+, castellano e inglés. `Alarma`, `sleep-native` y `native-ios` se conservan como antecedentes.
- Candidata: **1.1 (build 1)**. Versión pública: por confirmar; sin autorización de publicación en App Store.
- Fuente validada: `f9bfe70d0b6a3e5bf33a6136fe619765ed50fc44`, rama `codex/native-sleep-rebuild`.
- [CI completa correcta](https://github.com/Krazel/Alarmy/actions/runs/36894350167): 50 pruebas unitarias/integración + 6 UI; el flujo nocturno se repite en iPhone SE. 57 ejecuciones, 56 pruebas únicas, cero fallos; Release iPhone correcto. No se repiten pruebas para la subida solicitada.
- Diario: detalle y navegación de clips, reproducción desplazable, sugerencias por intervalos, corrección manual, reintento y borrado. Se corrigen pausas, ruido sostenido, recuperación, fallos de guardado de alarmas/posponer y solapamientos de Salud.
- [Informe, métricas y capturas nativas](QA-2026-10-01/README.md). Banco de 22 fuentes reales CC0/66 variantes: 22/22 etiquetas principales en limpio, 20/22 atenuadas y 20/22 con ventilador. Conjunto pequeño y evaluación repetida; no certifica una noche real ni todos los intervalos.
- IPA sin firma comprobado: `artifact/completion-20261001/run-f9bfe70/AlarmaNext-1.1-build-1-f9bfe70-unsigned-Local-QA.ipa`. Mínimo iOS 16, AlarmKit opcional, ES/EN y mecanismos de Debug excluidos. No se instala directamente.
- **Nuevo encargo: subir a TestFlight directamente.** Automatización preparada en `.github/workflows/sleep-next-testflight.yml`. Pendientes: sesión de Apple para crear la ficha inicial (operación no soportada por API) y autorización explícita del perfil App Store y secretos temporales de CI exigida por la revisión automática. La build aún no está subida.
- Firma previa: certificado existente verificado, Bundle ID propio con HealthKit y perfil ad hoc para dos iPhone preparados. No se ha ejecutado la firma local ni la instalación por USB; ese itinerario queda como antecedente.
- Instalación, noche física, batería y alarmas en iOS anterior a 26: pendientes; no bloquean el nuevo encargo de subida. Audio personal en el teléfono.
- Biblioteca D1: conciliación del resultado y nuevo encargo en curso. Se anotará el guardado tras verificarlo por API.
