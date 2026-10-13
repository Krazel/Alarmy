# Alarma 1.3 (1) — TestFlight interno

Subida autorizada expresamente por el usuario el 13-10-2026.
Árbol de app idéntico a `271e448edae68103eff1535e4cb66a991b9abce6`.
Validación reutilizada: https://github.com/Krazel/Alarmy/actions/runs/38325929640
9 pruebas correctas y Release iPhone; pruebas anteriores de análisis y categorías
en sus carpetas de Design. No se repiten pruebas por actualizar el workflow de subida.

Incluye A Onda con edición de hora durante la sesión, gesto Parar/Stop,
análisis acústico estimado, estadísticas, tres modos de alarma y grabaciones
agrupadas por categoría. ES/EN; iPhone iOS16+. Fases solo de Salud.
Firma existente reutilizada, secretos temporales en `alarma-local-qa`,
limitados a `codex/native-sleep-rebuild`, eliminación obligatoria tras la subida.
Repositorio público por excepción humana vigente; Actions estándar sin gasto.

**Disponible en TestFlight interno: 1.3 (1).** API Apple confirma `VALID` /
`IN_BETA_TESTING`, build `b5ab76cb-98c3-4d71-8779-2f07eab709f5`.
Mismo grupo interno del titular, un tester; notas ES/EN guardadas y releídas.
Subida: https://github.com/Krazel/Alarmy/actions/runs/38327591454
Fuente de subida `a200f5eee4fb4ff128c0f41da44f149dbd9b0764`; el workflow verificó
que el árbol de app coincide con la fuente de validación indicada arriba.
SHA-256 IPA `f0b5d36151e227515a4bfd79bc98ba0de6b9e829cf3e9a0c4d9d71841e590e11`.
Siete secretos temporales eliminados; entorno releído sin secretos. Credenciales
locales originales conservadas. Recibos JSON en esta carpeta.
No se publica en App Store ni se invita a testers externos.
Prueba nocturna física, batería y despertar bloqueado pendientes.

Biblioteca PR-019 actualizada por API y releída: revisión 19, versión 1.3,
build 1 y TestFlight Interno. Historial source conservado íntegro; nueva entrega
resumida en detail/next y enlazada a estos recibos.
