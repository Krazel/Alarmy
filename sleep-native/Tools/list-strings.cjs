const fs=require('fs');
const files=fs.readdirSync('sleep-native/Sources').filter(x=>x.endsWith('.swift'));
const strings=new Set();
for(const file of files){const src=fs.readFileSync('sleep-native/Sources/'+file,'utf8');for(const m of src.matchAll(/"(?:\\.|[^"\\])*"/g)){const s=m[0].slice(1,-1);if(/[ A-Záéíóúñ¿]/.test(s)&&!s.includes('com.')&&!s.includes('HH:')&&!s.startsWith('Alarma.')&&!s.includes('%.')&&!s.includes('%0')&&!s.includes('yyyy')&&!s.startsWith('sound-')&&!s.includes('CFBundle')&&!s.includes('NS'))strings.add(s)}}
fs.writeFileSync('sleep-native/Tools/strings-review.json',JSON.stringify([...strings],null,2));
