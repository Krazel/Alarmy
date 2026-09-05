const fs=require('fs');
const entries=fs.readFileSync('sleep-native/Tools/translations.txt','utf8').replace(/^\uFEFF/,'').trim().split(/\r?\n/).map(x=>x.split('|'));
for(const lang of ['es','en']){
 const folder='sleep-native/Resources/'+lang+'.lproj';fs.mkdirSync(folder,{recursive:true});
 const esc=s=>'"'+s.replaceAll('"','\\"')+'"';
 fs.writeFileSync(folder+'/Localizable.strings',entries.map(e=>esc(e[0])+' = '+esc(lang==='en'?e[1]:(e[2]||e[0]))+';').join('\n')+'\n');
 const perm=lang==='es'?{
 NSMicrophoneUsageDescription:'Graba clips de sonidos nocturnos opcionales en este iPhone. Las grabaciones nunca se suben a Internet.',
 NSMotionUsageDescription:'Detecta el movimiento del móvil para posponer cuando suena la alarma.',
 NSHealthShareUsageDescription:'Muestra en tu diario las fases de sueño que ya tienes registradas en Salud.'
 }:{NSMicrophoneUsageDescription:'Record optional night sound clips on this iPhone. Recordings are never uploaded.',NSMotionUsageDescription:'Detect phone movement to snooze while your alarm is ringing.',NSHealthShareUsageDescription:'Show sleep stages already recorded in Apple Health in your sleep journal.'};
 fs.writeFileSync(folder+'/InfoPlist.strings',Object.entries(perm).map(([k,v])=>esc(k)+' = '+esc(v)+';').join('\n'));
}
