# Noche y análisis — candidata 1.3 (1)

Petición del 12 de octubre: noche con onda real, finalizar deslizando hacia arriba,
análisis nocturno, estadísticas y modos sin alarma / exacta / ventana inteligente.
`01-noche-gesto.png` es una propuesta generada con Imágenes; prompt y hash adjuntos.
El fondo conserva el NightBackground aprobado. La propuesta no es evidencia nativa.

## Datos y límites
- Épocas acústicas de 30 s derivadas de todos los cuadros PCM de 20 ms.
- Reposo estimado: tramos observados tranquilos de al menos 10 min, no sueño clínico.
- Vigilia, ligero, profundo y REM solo de Salud. Calidad: valoración del usuario.
- Sin audio conservado: clasificación local temporal, eliminación tras clasificar y
  recuperación de la limpieza al abrir. Resúmenes sin audio conservados al caducar.
- Ventana de 15/30/45/60 min antes de la hora elegida. Regla acústica experimental:
  10 min tranquilos continuos seguidos de actividad. No determina fase ni mejora clínica.
  Alarma límite programada primero; se sustituye solo después de guardar la anticipada.
- Los tres botones inferiores se conservan. Estadísticas se abre desde Diario.
- Horarios se calculan en círculo alrededor de medianoche; datos ausentes no son ceros.

Validación de simulador/Xcode pendiente. Prueba nocturna física, consumo y despertar
con pantalla bloqueada pendientes. No se ha subido esta candidata a TestFlight;
la entrega interna vigente continúa siendo 1.2 (1).
