// Original compositions and synthesis. Node standard library only; no samples.
const fs = require('fs'), path = require('path');
const out = path.resolve(__dirname, '../Resources');
const rate = 22050, seconds = 28, count = rate * seconds;
for (const [name, notes, speed] of [['aurora',[220,277.1826,329.6276,440,329.6276,277.1826],1.8],['lumen',[261.6256,329.6276,391.9954,523.2511],2.2],['brisa',[196,246.9417,293.6648,369.9944,293.6648],2.7]]) {
  const buf=Buffer.alloc(44+count*2); buf.write('RIFF');buf.writeUInt32LE(buf.length-8,4);buf.write('WAVEfmt ',8);buf.writeUInt32LE(16,16);buf.writeUInt16LE(1,20);buf.writeUInt16LE(1,22);buf.writeUInt32LE(rate,24);buf.writeUInt32LE(rate*2,28);buf.writeUInt16LE(2,32);buf.writeUInt16LE(16,34);buf.write('data',36);buf.writeUInt32LE(count*2,40);
  for(let i=0;i<count;i++) {
    const t=i/rate; let value=0;
    for(let n=0;n<Math.ceil(seconds/speed);n++) {
      const elapsed=t-n*speed;if(elapsed<0||elapsed>7)continue;
      const f=notes[n%notes.length], env=(1-Math.exp(-elapsed*8))*Math.exp(-elapsed/1.5);
      value+=env*(Math.sin(2*Math.PI*f*elapsed)+.22*Math.sin(2*Math.PI*f*2.001*elapsed)+.08*Math.sin(2*Math.PI*f*3*elapsed));
    }
    const fade=Math.min(1,t/1.2,(seconds-t)/2);buf.writeInt16LE(Math.round(Math.max(-.95,Math.min(.95,value*.32*fade))*32767),44+i*2);
  }
  fs.writeFileSync(path.join(out,name+'.wav'),buf);
}
fs.writeFileSync(path.join(out,'Assets.xcassets/Contents.json'),JSON.stringify({info:{author:'xcode',version:1}}));
fs.writeFileSync(path.join(out,'Assets.xcassets/DawnArtwork.imageset/Contents.json'),JSON.stringify({images:[{filename:'dawn.png',idiom:'universal'}],info:{author:'xcode',version:1}}));
