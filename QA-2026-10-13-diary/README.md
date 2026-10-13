# Alarma 1.4 (1) — diario y estadísticas

Encargo: «Pero implementalo y subelo a testflight», 13/10/2026.
Mismo grupo interno del titular, sin distribución externa ni App Review.

Referencias y aprobación: ../sleep-next/Design/diary-statistics-2026-10-13.
Capturas en runtime son de la app nativa en iPhone 17 Pro / iOS 26.4.1,
con datos ficticios exclusivos de DEBUG. No son noches reales ni evidencia
fisiológica. Objetivo de despliegue conservado: iPhone iOS16+, ES/EN.

Validación inicial: 38418974331, fuente 189c89d, 13/13 + Release iPhone.
Tras revisión visual: duración de clips mm:ss, barras de horario legibles y
ocultar gráfica vacía cuando faltan datos de Salud. Validación final enfocada:
38421555665, fuente 4cc0b89: 4/4, Debug y Release iPhone correctos.
Todas las etapas, incluido artefacto y limpieza, terminaron con success; GitHub
marcó el job cancelled al cerrar el runner por el límite de 20 minutos. El guard
acepta exclusivamente este ID/SHA con todas las etapas exitosas, y verifica de
nuevo resumen nativo, source.txt y marcadores de compilación/pruebas/Release.
No se repiten pruebas ni se permite subir código distinto del validado.
Capturas finales en runtime; anteriores (ES/EN) en initial-runtime.

El resumen precede a sonidos/caritas/nota. Una sola fila de sonidos abre
categorías y un reproductor. Estadísticas incluye periodos, gráficas de sueño
y horarios, regularidad, fases de Salud, latencia, despertares observados,
valoraciones y sonido. El detalle acústico/historial sigue desplegable.
La calidad es la valoración humana, no /100 inventado. Vigilia queda fuera
del anillo; huecos de Salud o acústicos nunca se convierten en sueño.

Entrega, limpieza de firma temporal y biblioteca se registran en sus recibos.
Prueba nocturna física y batería pendientes; no acreditadas por el simulador.

Procedimiento vigente consultado:
- https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/
- https://docs.github.com/en/billing/concepts/product-billing/github-actions
Repo público por excepción expresa de Alarma, runner estándar macos-26;
no se activan gastos, runners ampliados ni servicios nuevos.
