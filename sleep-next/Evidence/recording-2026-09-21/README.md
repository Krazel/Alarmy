# Seguimiento y grabación nocturna — candidata 1.0.1 (1)

Encargo del 21-09-2026, PR-019. Implementación: `sleep-next`, rama `codex/native-sleep-rebuild`. La versión fuente anterior era 1.0(1), sin prueba física. Se conserva esa línea heredada y se prepara una corrección 1.0.1, candidata local sin publicación; no se deduce una versión pública de ese número.

## Fallos encontrados en el código anterior

- Un umbral fijo de −35 dBFS descartaba eventos suaves (por ejemplo el tono de prueba de amplitud 0,003, muy por debajo de ese umbral).
- Bloques AAC de 30 segundos, muestreados por un Timer de 0,5 s: cortes arbitrarios, silencios largos y eventos de menos de 2 s descartados al terminar la sesión. No había segmentación acústica con contexto.
- La pantalla consultaba una propiedad no publicada del grabador; no observaba sus cambios.
- Los archivos abiertos o finalizados antes de actualizar el JSON podían quedar sin índice después de un cierre del proceso.
- Una vuelta a la app intentaba grabar automáticamente. No se distinguían pausa, interrupción, ruta cambiada y reinicio de los servicios de audio.
- La clasificación ocultaba errores como si fueran una clasificación correcta «Sin etiquetar».
- Las pruebas visuales previas omitían los permisos y la captura del micrófono.

## Recorrido nuevo

1. Activación explícita del micrófono desde Alarma y permiso real del sistema. Selector de sensibilidad en Ajustes.
2. AVAudioEngine captura PCM mediante un tap de entrada. Sesión `.record`, modo `.measurement`, `UIBackgroundModes=audio`. Sin reproducción silenciosa ni keepalive.
3. Un trabajador en cola separada procesa ventanas de 20 ms. Calibra durante 1 s, estima un percentil bajo del fondo y aplica margen 6/10/14 dB según sensibilidad, con suelo de −65 dBFS. Requiere 60 ms de actividad: no pretende detectar todos los impulsos ni sonidos inaudibles.
4. Hasta 2 s de memoria previa, cierre tras 2 s de calma y partes contiguas de hasta 30 s. No se vuelve a guardar el mismo contexto al partir un evento largo. No se guardan periodos de silencio por sí solos.
5. PCM temporal y metadatos escritos antes del índice; WAV final atómico y recibo persistente hasta que el archivo principal confirma el guardado. La recuperación es idempotente y utiliza el ID de la noche, incluso si el fragmento llega después de terminarla. Los archivos dañados no impiden recuperar los demás.
6. Periodos de captura basados en muestras recibidas, separados del tiempo en cama. Los huecos de captura no son tiempo dormido ni fases estimadas.
7. Escucha, sugerencia local de SoundAnalysis, corrección manual y eliminación desde el diario. Un error de clasificación queda pendiente de reintento, no se marca como éxito.
8. Cuotas de 256 MiB por noche y 512 MiB en la carpeta de clips; parada visible ante errores o límite. Retención respeta notas y ánimo. No se envía audio a servidores; los clips quedan excluidos de copias de seguridad automáticas.

## Interrupciones y límites

- Bloqueo y segundo plano: el mecanismo de captura está autorizado por el modelo de audio de iOS. Su fiabilidad nocturna y batería aún deben medirse en dispositivo físico.
- Cierre forzado: la captura se detiene. Al volver se recuperan archivos y se requiere Reanudar. Los segundos de contexto que solo existían en RAM antes de abrir un evento no se pueden recuperar.
- Llamadas/otros audios: pausa y cierre del fragmento. Solo se intenta retomar si el sistema recomienda reanudar y el micrófono estaba activo; una pausa manual se respeta.
- Cambio de dispositivo de entrada, configuración incompatible o reinicio de los servicios de audio: estado de pausa/reinicio y acción explícita para volver a capturar. Un flujo sin muestras durante 5 s se muestra como detenido.
- Alarma: la cola de captura corta en la fecha de despertar. La reproducción propia exige que la captura esté detenida. Tras posponer se puede reanudar el micrófono explícitamente.
- La detección identifica cambios acústicos, no garantiza distinguir ronquidos de respiración, habla, ventiladores o ruido externo. Las etiquetas son sugerencias corregibles; el audio sintético no valida precisión clínica ni personal.

## Documentación oficial consultada el 21-09-2026

- [Categoría record: captura y pantalla bloqueada](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/record).
- [Interrupciones y recomendación de reanudar](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions).
- [Nodo de entrada y tap de grabación](https://developer.apple.com/documentation/avfaudio/avaudioengine/inputnode).
- [Reinicio de los servicios: esperar acción del usuario](https://developer.apple.com/documentation/avfaudio/avaudiosession/mediaserviceswereresetnotification).
- [Análisis síncrono de archivos fuera del hilo de interfaz](https://developer.apple.com/documentation/soundanalysis/snaudiofileanalyzer/analyze()).

## Prueba física breve pendiente

Usar una build firmada en un iPhone con iOS 16–25 y otro con iOS 26 si están disponibles. No compartir grabaciones personales.

1. Activar micrófono, permitirlo y empezar una noche con alarma cercana. Esperar la calibración: debe verse «Escuchando» y movimiento del nivel al hablar o dar una palmada suave.
2. Hacer dos sonidos de 0,2–1 s, separados 5 s; esperar 3 s. Deben aparecer eventos que contengan el inicio y la cola, sin 30 s de silencio innecesario. Escucharlos, corregir etiqueta y borrar uno.
3. Repetir con pantalla bloqueada 5 minutos y en segundo plano. Anotar modelo/iOS, hora, clips, audibilidad y huecos. No dar por válido a partir del simulador.
4. Provocar una llamada y conectar/desconectar auriculares. Comprobar pausa visible, cierre válido, ruta correcta y reanudación según la acción del sistema/usuario. Una pausa manual no debe revertirse sola.
5. Cerrar a la fuerza durante un evento y reabrir. Recuperar una sola copia válida; ver el hueco y la acción Reanudar, sin micrófono activado por el relanzamiento.
6. Dejar sonar la alarma: debe sonar según la vía del sistema y sus permisos, sin grabar su propio sonido. Posponer y reanudar el micrófono si se desea. En iOS 16–25, comprobar sonidos de notificaciones y Silencio/Concentración.
7. Revocar micrófono y comprobar el error al intentar reanudar. Usar la cuota/error de almacenamiento controlado en pruebas, sin llenar el teléfono personal. Borrar clips y verificar que la retención no elimina notas.
8. Realizar una noche completa y anotar batería inicial/final, cargador sí/no, periodos de captura, número/duración de eventos y cualquier interrupción. Revisar sensibilidad con la habitación real.

## Evidencias

Los XCTest acústicos inyectan PCM controlado en la misma cola, detector y escritor usados por el tap. Exportan el archivo de entrada, WAV de eventos y JSON de tiempos como adjuntos de XCTest. No activan un micrófono personal ni usan voces grabadas. La prueba de permiso nativo deniega la petición del simulador.

Resultado de CI y hash de la candidata: se incorporan tras finalizar la validación. La evidencia automatizada no sustituye la prueba nocturna física ni una evaluación de exactitud de clasificación.
