# Alarma — decisiones vigentes

Leer ESTADO.md y el encargo humano más reciente antes de continuar.

Excepción confirmada por el usuario el 12/10/2026: **Krazel/Alarmy debe ser público**
para usar Actions estándar gratuitas, mediante API y sin gastar dinero. No aplicar
la regla general de privado a este repositorio mientras esta decisión siga vigente.
No extender la excepción a otros productos ni habilitar runners/planes de pago.

App nativa SwiftUI, solo iPhone iOS16+, castellano/inglés, diseños aprobados y
audio personal local. Mantener sleep-next como implementación vigente.
TestFlight interno para el titular: nueva entrega UI 1.2(1) autorizada el 12/10,
después de la entrega previa 1.1.1(1) del mismo día.
El 13/10 el usuario autoriza subir la candidata 1.3 (1) con todos los cambios
aprobados a ese mismo TestFlight interno.
No iniciar App Review externo ni publicación comercial por esa autorización.

Firma en el entorno existente alarma-local-qa, limitado a codex/native-sleep-rebuild.
Reutilizar credenciales/perfil autorizados; secretos temporales por stdin, sin
valores en logs/código, y eliminarlos al terminar. Validación y subida separadas;
subir únicamente el árbol de app que pasó la validación, sin repetir una combinación
de versión/build ya aceptada. Registrar y verificar la entrega por API Apple.

Prueba nocturna física/batería pendiente: no acreditarla con XCTest o simulador.
Biblioteca PR-019: leer revisión fresca, conservar tracking/historial, guardar por
API admitida y releer. No modificar ni desplegar el repositorio de la biblioteca.
