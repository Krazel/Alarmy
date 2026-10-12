# Alarma 1.2 (1) — entrega UI a TestFlight

Encargo humano del 12/10/2026: subir los nuevos cambios a TestFlight.
Solo iPhone iOS 16+, SwiftUI, castellano e inglés. Mismo grupo interno del
titular, sin App Review ni publicación comercial. Repositorio público por
excepción explícita para usar Actions estándar gratuitas, sin gastos.

## Cambios incluidos

- Diario A: cuaderno actual con colores adaptativos claro/nocturno.
- Fondo nocturno original aprobado, recuperado sin regeneración.
- Cinco caras de despertar en la semana y en el calendario mensual.
- Modo desarrollador con seis escenarios de noches en un store de memoria.
  Los ejemplos no modifican los registros ni reproducen o borran audio real.
- Grabaciones con retención predeterminada 90 días para configuraciones nuevas;
  elecciones anteriores conservadas. Textos nuevos ES/EN.

[Diseños aprobados, láminas y capturas](../sleep-next/Design/proposals-2026-10-12/README.md).

## Fuente y entrega

Candidata 1.2 (build 1), fuente `ebf86c537bc3c55b6c9a70a42c55b59c600356a4`.
La nueva versión agrupa los cambios de diario y ejemplos. No reutilizar una
combinación versión/build que Apple ya haya aceptado.
[Validación de la candidata](https://github.com/Krazel/Alarmy/actions/runs/38307811714).
Validación correcta: cinco pruebas pasadas, cero fallos/omitidas y Release iPhone.
[Subida firmada](https://github.com/Krazel/Alarmy/actions/runs/38309075753)
completada y aceptada por Apple. **1.2 (1) disponible en TestFlight interno**
para el mismo titular, API confirma VALID / IN_BETA_TESTING. Build
`77b4588d-6a9a-404c-b55f-7453391ea508`, caduca el 10/01/2027. Notas ES/EN
guardadas y releídas, mismo grupo interno con un tester y sin enlace público.
Recibos `upload.json` y `testflight-verified.json`. Entrega anterior 1.1.1 (1)
conservada; no se ha enviado App Review ni publicado en App Store.

Firma/perfil y API existentes reutilizados en Krazel/Alarmy → alarma-local-qa,
limitado a codex/native-sleep-rebuild. Solo recibos sin valores de credenciales
en esta carpeta. Los siete secretos temporales ya se han eliminado y el entorno
se ha releído vacío (`credentials-cleanup.json`); originales locales conservados.

Biblioteca PR-019 guardada y releída por API en **revisión 13**, versión 1.2,
build 1 y TestFlight Interno. Resto de tracking, URLs e historial conservados;
recibo `library-receipt.json`. No ficha nueva ni cambios al sitio de biblioteca.

La noche física, consumo de batería y ejecución de alarmas/captura en iOS 16–25
siguen pendientes. Una compilación o simulador no acreditan esas pruebas.
