# Diario y estadísticas — propuestas, 13/10/2026

El usuario corrige el orden de la entrega 1.3.1 y pide imágenes de UI antes de
continuar. Estas láminas son conceptos generados con image_gen, no capturas de
una implementación ni diseños aprobados. TestFlight sigue en 1.3.1 (1).

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
