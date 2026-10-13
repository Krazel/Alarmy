# Diario y estadísticas — referencias aprobadas, 13/10/2026

El usuario corrige el orden de la entrega 1.3.1 y pide imágenes de UI antes de
continuar. Las láminas son conceptos generados con image_gen. Después, el usuario
autoriza implementarlos y subirlos a TestFlight (véase aprobación al final).
Las capturas de la implementación nativa se conservan por separado.

## Propuesta de diario

01-diario-sonidos.png: resumen primero (calidad, sueño y cama, gráfico de fases
y duraciones), una sola fila Sonidos pulsable, cinco caras visibles en el primer
vistazo y nota inmediatamente debajo. Icono de estadísticas a la izquierda del
calendario; se elimina la fila de texto independiente de acceso a estadísticas.
La segunda pantalla abre los sonidos aparte: categorías con cantidades y un
solo reproductor con anterior/siguiente. No se apilan clips debajo del resumen.

## Propuesta de estadísticas

02-estadisticas.png: misma pantalla en vista inicial y tras desplazarse, con
selector 7/30/90 días/todo, duración media, calidad, horarios, regularidad, fases,
latencia, despertares, sentimientos y sonidos resumidos con acceso al detalle.
Vigilia se muestra separada y no se suma al anillo de tiempo dormido.

## Datos, continuidad y futura implementación

- Datos ficticios señalados en ambas láminas. Duraciones y fases tienen Salud
  como fuente; no presentar fases médicas inferidas del micrófono. Si no hay
  datos de fases, ofrecer el estado sin datos, sin inventar una gráfica.
- Conservar los idiomas ES/EN, los cinco estados y la representación del estado
  en semana/calendario del producto. La tira semanal de la maqueta simplifica
  esas miniaturas; no autoriza su retirada de la app.
- Mantener estilo cuaderno, paleta, caras y navegación aprobadas. La composición
  compacta deberá verificarse en UI nativa si el usuario encarga implementarla.
- No se inicia una build ni se modifica la app instalada por crear estas imágenes.

Prompts completos y corrección del anillo en prompts.json. Referencias: diario
nativo 60-es-journal-note.png y estadísticas 32-es-statistics.png ya conservados.

SHA-256:
- 01-diario-sonidos.png: fef7d1d52ff81e272c53939e07ef99e622237e6cf03afd5922b46fdbfc8606dd
- 02-estadisticas.png: 29c89a5824b86f46e119dbde1abc157f83dea957d349a1b66aa4b9a4ea044761


## Aprobación e implementación — 13/10/2026

El usuario pide «Pero implementalo y subelo a testflight»: ambas referencias
se aplican a la candidata 1.4 (1), iPhone iOS16+, ES/EN. Se conservan las
mini caras de semana/calendario y el tema nocturno. La calidad es la valoración
humana, no la puntuación ficticia /100 de la lámina. Estadísticas muestra la
valoración más habitual y su distribución, y separa vigilia de tiempo dormido.
Fases, latencia y despertares proceden exclusivamente de Salud; faltantes en —.
Sonidos abre un modal propio con categorías y un solo reproductor navegable.
El control de progreso reproduce/recorre el audio real, sin dibujar una onda
ficticia del archivo. Detalles, corrección de etiqueta y borrado siguen accesibles.

Capturas nativas y validación se registran en QA-2026-10-13-diary.
