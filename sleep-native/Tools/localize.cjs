const fs=require('fs');
const entries=fs.readFileSync('sleep-native/Tools/translations.txt','utf8').replace(/^\uFEFF/,'').trim().split(/\r?\n/).map(x=>x.split('|'));
const keys=new Set(entries.map(x=>x[0]));
function format(s){let out='',args=[];for(let i=0;i<s.length;){if(s.slice(i,i+2)==='\\('){let start=i+2,j=start,d=1;while(j<s.length&&d){if(s[j]==='(')d++;if(s[j]===')')d--;j++}args.push(s.slice(start,j-1));out+='%@';i=j}else{out+=s[i++];}}return {out,args}}
for(const file of fs.readdirSync('sleep-native/Sources').filter(x=>x.endsWith('.swift')&&x!=='Localization.swift')){
 let src=fs.readFileSync('sleep-native/Sources/'+file,'utf8');
 src=src.replace(/"(?:\\.|[^"\\])*"/g,(token,offset)=>{
 const {out,args}=format(token.slice(1,-1));if(!keys.has(out))return token;
 if(/\bL[F]?\($/.test(src.slice(Math.max(0,offset-3),offset)))return token;
 return args.length?'LF("'+out+'", '+args.map(a=>'String(describing: '+a+')').join(', ')+')':'L('+token+')';
 });
 // Recreate formatters when the app language changes, including named months.
 src=src.replace(/private static (?:let|var) (\w+): DateFormatter = \{([\s\S]*?)\}\(\)/g,(_,name,body)=>'private static var '+name+': DateFormatter {'+body+'}');
 src=src.replace('static let all: [AlarmSound] = [','static var all: [AlarmSound] { [').replace('color: .purple)\n    ]','color: .purple)\n    ] }').replace('color: .purple)\r\n    ]','color: .purple)\r\n    ] }');
 fs.writeFileSync('sleep-native/Sources/'+file,src);
}
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
