# Primer intento — corrección antes de distribuir

Run 38294548741, fuente c64c28a, runner estándar macos-26/Xcode 26.6.
La compilación se detuvo antes de ejecutar XCTest por exclusividad Swift:
`Overlapping accesses to 'value.active'` en CaptureCoordinator.swift.
Se calcula la decisión en una variable local antes de asignarla a la sesión.
No se firmó ni subió una build a Apple desde este intento.

El nuevo script solapa el arranque del simulador con build-for-testing y después
ejecuta los mismos casos con test-without-building. No se amplían las pruebas.
