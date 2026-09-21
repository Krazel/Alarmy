# Estado de Alarma — 21-09-2026

- Producto: PR-019. Tarea propietaria: `01a0708e-0558-78b1-866c-801b9cf35996`.
- Implementación vigente: `sleep-next`, SwiftUI, iPhone iOS 16+, castellano e inglés. `Alarma`, `sleep-native` y `native-ios` se conservan como antecedentes.
- Candidata: **1.0.1 (build 1)**, IPA sin firma. Versión pública: por confirmar.
- Fuente validada: `0efac28e6a3621b47df75265c00ac70232793b09`, rama `codex/native-sleep-rebuild`.
- [Xcode CI correcta](https://github.com/Krazel/Alarmy/actions/runs/35635101317): 38 pruebas unitarias/integración y 3 UI, cero fallos; compilación Release iPhone correcta.
- [Diagnóstico, WAV sintéticos, capturas y protocolo físico](sleep-next/Evidence/recording-2026-09-21/README.md). Los clips exportados conservan exactamente el audio correspondiente del original. El ejecutable declara mínimo iOS 16 y enlace opcional de AlarmKit; los mecanismos de pruebas están excluidos de Release.
- Paquete local: `artifact/recording-qa/run-0efac28/AlarmaNext-1.0.1-build-1-0efac28-unsigned-Local-QA.ipa`. Requiere firma para instalarlo.
- Pendiente: prueba nocturna en iPhone físico, pantalla bloqueada/segundo plano, llamadas/rutas, alarmas en iOS anterior, batería y ajuste de sensibilidad con una habitación real. No se ha probado la exactitud de las etiquetas sobre el sueño de una persona.
- Biblioteca D1: PR-019 actualizada y releída por API, revisión **3**, `2026-09-21T18:16:59.460Z`. Estado En producción; candidata y evidencia registradas. TestFlight y App Store: Por confirmar; anuncios: No. Esta corrección no ha subido builds a TestFlight ni publicado en la tienda.
