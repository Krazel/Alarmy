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
El 13/10, tras validar las correcciones, el usuario pide «subelo a test»:
autorizada 1.3.1 (1) al mismo TestFlight interno y con la firma temporal existente.

Firma en el entorno existente alarma-local-qa, limitado a codex/native-sleep-rebuild.
Reutilizar credenciales/perfil autorizados; secretos temporales por stdin, sin
valores en logs/código, y eliminarlos al terminar. Validación y subida separadas;
subir únicamente el árbol de app que pasó la validación, sin repetir una combinación
de versión/build ya aceptada. Registrar y verificar la entrega por API Apple.

Prueba nocturna física/batería pendiente: no acreditarla con XCTest o simulador.
Biblioteca PR-019: leer revisión fresca, conservar tracking/historial, guardar por
API admitida y releer. No modificar ni desplegar el repositorio de la biblioteca.

El 13/10 el usuario aprueba las láminas de diario/estadísticas y pide
«Pero implementalo y subelo a testflight»: autorizada 1.4 (1) al mismo grupo
interno del titular, reutilizando firma temporal y CI públicas sin gasto.

El 14/10 el usuario aprueba los nueve bloques de análisis y elige expresamente
un método propio a partir del audio, completamente local, aunque sea aproximado.
No exigir Salud ni usar procesamiento externo. Candidata 1.5: estimaciones
experimentales, no fases clínicamente validadas. Conservar el aviso de método,
la cobertura y los tramos desconocidos; no convertir silencio en sueño ni
crear ciclos prefijados. Esta elección no autoriza servicios de pago ni subida
de 1.5 a TestFlight. Los tests sintéticos no acreditan precisión fisiológica.

El 14/10, después de validar 1.5 (1), el usuario pide «subelo a test»: autorizada
la subida al mismo TestFlight interno, con el entorno y firma temporal existentes.
Mantener las notas ES/EN explícitas sobre estimación experimental local.

El 15/10 se solicita corregir estimación y reconocimiento, eliminar
los desconocidos y no conservarlos en noches nuevas. Analizar antes de descartar;
un fallo o análisis pendiente no equivale a un sonido desconocido. Mantener todo
local. Candidata 1.5.1 (1); este encargo no incluye una nueva subida a TestFlight.

El 16/10 el usuario pide «sube»: autorizada la candidata validada 1.5.1 (1)
al mismo TestFlight interno, con la firma temporal y el entorno existentes.
Conservar recibos privados solo en almacenamiento local excluido de Git.
