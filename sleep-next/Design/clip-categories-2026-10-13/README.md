# Grabaciones por categoría — 13-10-2026

Encargo humano: sustituir la lista de grabaciones por categorías con contador,
abrir una y recorrer sus fragmentos uno a uno con flechas.

Se conserva el diario A, papel claro/nocturno, terracota y barra inferior.
Hasta cinco filas: Ronquido, Respiración, Voz, Tos y Sin etiquetar. Solo aparecen
las que tienen clips conservados. El contador cuenta archivos reproducibles,
no eventos múltiples de un archivo ni estadísticas de audio ya caducado.

Cada categoría abre el reproductor existente: fecha/hora, reproducción,
posición, anterior/siguiente, contador, intervalos, corrección y borrado.
Orden cronológico y navegación limitada a la categoría y fecha seleccionadas.
Cambiar de fragmento detiene el audio. Corregir o borrar actualiza el grupo:
conserva el fragmento abierto si sigue disponible, elige su vecino si desaparece,
y vuelve al diario si la categoría queda vacía. Sin migraciones de datos.

Ejemplo del desarrollador «Sonidos»: 30 fragmentos simulados, 16 de tos,
7 ronquidos, 4 respiración, 2 voz y 1 sin etiquetar; permanece aislado del
archivo personal. Traducciones ES/EN. Retención de 90 días conservada.

Validación nativa correcta: 4 pruebas, 0 fallos/omitidas y Release iPhone.
Fuente `f2fa3b613e21b9e69e3bf0fb40805e9d97b82ace`,
[ejecución](https://github.com/Krazel/Alarmy/actions/runs/38317706859).
Verificados límites de navegación, parada al pasar de clip, corrección con
redistribución de contadores, borrado normal y del último clip, ejemplos y
su aislamiento del archivo personal. Capturas reales del simulador iPhone 17 Pro,
iOS26.4.1, revisadas: [categorías ES nocturno](runtime/42-es-night-categories.png),
[reproductor ES](runtime/43-es-night-category-player.png),
[categorías EN claro](runtime/40-en-sound-categories.png) y
[reproductor EN](runtime/41-en-category-player.png).
La captura EN conserva el punto de scroll de la prueba; la española muestra
las cinco categorías completas. Son datos de prueba, no grabaciones personales.

Candidata 1.3 (1) aún sin subir; TestFlight interno vigente 1.2 (1).
No sustituye las comprobaciones físicas nocturnas pendientes.
