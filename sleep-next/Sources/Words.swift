import Foundation

struct Words {
    let language: String
    var spanish: Bool { language == "es" || (language == "system" && Locale.preferredLanguages.first?.hasPrefix("es") == true) }
    var locale: Locale { Locale(identifier: spanish ? "es_ES" : "en_GB") }
    func callAsFunction(_ key: String) -> String { Self.entries[key].map { $0[spanish ? 0 : 1] } ?? key }
    static let entries: [String: [String]] = [
        "alarm":["Alarma","Alarm"], "journal":["Diario","Journal"], "settings":["Ajustes","Settings"],
        "tonight":["TU PRÓXIMA NOCHE","YOUR NEXT NIGHT"], "rest":["Un buen día empieza\nla noche anterior.","A good day begins\nthe night before."],
        "wake":["Despertar","Wake up"], "start":["Empezar noche","Begin night"], "edit":["Editar alarma","Edit alarm"],
        "sounds":["Sonidos","Sounds"], "gentle":["Volumen progresivo","Gradual volume"], "selected":["seleccionados","selected"],
        "save":["Guardar","Save"], "done":["Listo","Done"], "cancel":["Cancelar","Cancel"], "close":["Cerrar","Close"],
        "soundHint":["Se elige uno distinto cada noche, cuando hay más de uno seleccionado.","A different sound is chosen each night when more than one is selected."],
        "import":["Importar audio","Import audio"], "importHint":["Se prepara un fragmento de hasta 29 segundos para la alarma.","A clip of up to 29 seconds is prepared for the alarm."],
        "snooze":["Posponer","Snooze"], "snoozeTime":["Tiempo para posponer","Snooze duration"],
        "motion":["Posponer al mover el iPhone","Snooze by moving iPhone"], "motionHint":["Disponible con la pantalla de alarma abierta.","Available while the alarm screen is open."],
        "light":["Luz de amanecer","Sunrise light"], "off":["Desactivado","Off"],
        "lightHint":["Ilumina gradualmente esta pantalla antes de despertar. Deja la app abierta y el iPhone cargando.","Gradually brightens this screen before wake-up. Leave the app open and the iPhone charging."],
        "goodnight":["Buenas noches","Sleep well"], "until":["DESPERTAR A LAS","WAKE UP AT"],
        "end":["Terminar noche","Finish night"], "endTitle":["¿Terminar esta noche?","Finish this night?"],
        "endHint":["Se guardará el tiempo en cama y se cancelará la alarma de esta noche.","Time in bed will be saved and tonight’s alarm will be cancelled."],
        "morning":["Buenos días","Good morning"], "dismiss":["Ya estoy despierto","I’m awake"],
        "recording":["Grabación de sonidos activa","Sound recording active"], "noRecording":["Sin grabación de sonidos","Sound recording off"],
        "today":["Hoy","Today"], "yourNight":["Tu noche, a tu ritmo.","Your night, in your words."],
        "overview":["RESUMEN DE LA NOCHE","NIGHT AT A GLANCE"], "inBed":["Tiempo en cama","Time in bed"],
        "noNight":["Tu próxima noche empieza aquí","Your next night starts here"],
        "noNightHint":["Pulsa «Empezar noche» en Alarma. Por la mañana encontrarás aquí tu registro.","Tap “Begin night” in Alarm. Your record will be here in the morning."],
        "feeling":["¿Cómo te has despertado?","How did you wake up?"], "feelingHint":["Un momento para escucharte.","A moment to check in with yourself."],
        "exhausted":["Agotado","Drained"], "tired":["Cansado","Tired"], "steady":["Normal","Okay"], "peaceful":["En calma","Calm"], "bright":["Renovado","Fresh"],
        "notes":["Lo que te llevas de la noche","What stays with you"], "notesHint":["Un sueño, una idea, cómo te sientes…","A dream, a thought, how you feel…"],
        "saved":["Guardado en este iPhone","Saved on this iPhone"], "saving":["Guardando…","Saving…"],
        "nightSounds":["Los sonidos de tu noche","The sounds of your night"],
        "noClips":["No hay fragmentos guardados.","No saved clips."], "clipHint":["Fragmentos activados por ruido. Escúchalos y elige una etiqueta; no son un diagnóstico.","Clips triggered by noise. Listen and choose a label; they are not a diagnosis."],
        "snore":["Ronquido","Snoring"], "breath":["Respiración","Breathing"], "voice":["Voz","Voice"], "cough":["Tos","Cough"], "other":["Sin etiquetar","Unlabelled"],
        "delete":["Eliminar","Delete"], "play":["Reproducir","Play"], "stop":["Parar","Stop"],
        "health":["Sueño en Salud","Sleep in Health"], "healthHint":["Fases registradas por tus dispositivos o apps de Salud. El tiempo en cama de Alarma se muestra por separado.","Stages recorded by your Health devices or apps. Alarma’s time in bed is shown separately."],
        "healthEmpty":["No hay fases disponibles en Salud para esta noche.","No Health sleep stages are available for this night."],
        "core":["Ligero","Core"], "deep":["Profundo","Deep"], "rem":["REM","REM"], "awake":["Despierto","Awake"], "asleep":["Dormido","Asleep"],
        "connectHealth":["Conectar con Salud","Connect Health"], "interrupted":["Registro recuperado hasta el último guardado","Record recovered to its last save"],
        "appearance":["Apariencia","Appearance"], "auto":["Automática","Automatic"], "dawn":["Amanecer","Dawn"], "night":["Noche","Night"],
        "language":["Idioma","Language"], "system":["Del sistema","System"], "privacy":["Privacidad y grabación","Privacy & recording"],
        "record":["Guardar sonidos nocturnos","Save night sounds"],
        "recordHint":["Con tu permiso, el micrófono guarda fragmentos de 30 segundos cuando detecta ruido. Solo se almacenan en este iPhone.","With your permission, the microphone saves 30-second clips when it detects noise. They stay on this iPhone."],
        "retention":["Conservar grabaciones","Keep recordings"], "forever":["Sin límite","Forever"], "days":["días","days"],
        "openJournal":["Abrir diario al despertar","Open journal on waking"], "permissions":["Permisos del iPhone","iPhone permissions"],
        "reliability":["Cómo sonará tu alarma","How your alarm will ring"],
        "nativeInfo":["Este iPhone admite alarmas del sistema, que pueden sonar con la app cerrada, en silencio y con modos de concentración. Autoriza Alarmas al empezar la primera noche.","This iPhone supports system alarms, which can ring with the app closed, in Silent mode and during Focus. Allow Alarms when starting your first night."],
        "fallbackInfo":["En iOS 16–25 se usan notificaciones con sonido de hasta 29 segundos. Activa sus sonidos y desactiva Silencio y Concentración para oírlas. Con la app abierta, el sonido se repite. El volumen progresivo solo se aplica con la app abierta.","On iOS 16–25, notifications play up to 29 seconds of sound. Enable notification sounds and turn off Silent mode and Focus to hear them. With the app open, audio repeats. Gradual volume applies only while the app is open."],
        "nativeExtra":["Para posponer, abre Alarma. El movimiento, la luz y el volumen progresivo funcionan con la app abierta.","To snooze, open Alarma. Motion, light and gradual volume work with the app open."],
        "local":["Tu noche se queda contigo","Your night stays with you"], "localHint":["Sin cuenta, sin anuncios y sin enviar grabaciones a un servidor.","No account, no ads, and no recordings sent to a server."],
        "error":["No se ha podido completar","Couldn’t complete that"], "permissionError":["Activa el permiso de alarmas o notificaciones en Ajustes para programar el despertar.","Enable alarm or notification permission in Settings to schedule your wake-up."],
        "micError":["No hay permiso de micrófono. Puedes desactivar la grabación o permitirla en Ajustes.","Microphone permission is off. Turn recording off or allow it in Settings."],
        "badAudio":["No se ha podido preparar ese audio. Prueba con un archivo de música sin protección.","Couldn’t prepare this audio. Try an unprotected music file."],
        "storageError":["No se pudo leer el archivo local. Se ha conservado para evitar perder datos.","The local archive could not be read. It has been preserved to avoid data loss."],
        "activeSettings":["Termina la noche para cambiar estos ajustes.","Finish the night to change these settings."],
        "calendar":["Elegir fecha","Choose date"], "minutes":["min","min"], "about":["Alarma · creada para descansar","Alarma · made for rest"]
    ]
}
