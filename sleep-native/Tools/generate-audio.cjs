// Original synthesized audio. No third-party music or samples.
const fs = require('node:fs');
const path = require('node:path');
const rate = 22050;
function wav(name, duration, sample) {
  const count = rate * duration;
  const data = Buffer.alloc(44 + count * 2);
  data.write('RIFF'); data.writeUInt32LE(data.length - 8, 4); data.write('WAVEfmt ', 8);
  data.writeUInt32LE(16, 16); data.writeUInt16LE(1, 20); data.writeUInt16LE(1, 22);
  data.writeUInt32LE(rate, 24); data.writeUInt32LE(rate * 2, 28); data.writeUInt16LE(2, 32); data.writeUInt16LE(16, 34);
  data.write('data', 36); data.writeUInt32LE(count * 2, 40);
  let peak = 0;
  for (let i = 0; i < count; i++) {
    const t = i / rate;
    const edge = Math.min(1, t / 0.08, (duration - t) / 0.08);
    const v = sample(t) * edge;
    peak = Math.max(peak, Math.abs(v));
    data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, v)) * 32760), 44 + 2 * i);
  }
  if (peak >= 0.95) throw new Error('Audio exceeds headroom');
  fs.writeFileSync(path.join(__dirname, '../Resources', name + '.wav'), data);
  console.log(`${name}: ${duration}s, peak=${peak.toFixed(3)}, ${data.length} bytes`);
}
function melody(notes, spacing, softness) {
  return t => {
    let total = 0;
    for(let n=0;n<notes.length;n++) {
      const dt = t - n * spacing;
      if(dt < 0) continue;
      const env = (1-Math.exp(-dt * 5)) * Math.exp(-dt / softness);
      total += 0.17 * env * (Math.sin(2*Math.PI*notes[n]*dt) + 0.2*Math.sin(4*Math.PI*notes[n]*dt));
    }
    return total;
  };
}
wav('dawn', 24, melody([261.63,329.63,392,523.25,392,329.63,293.66,261.63], 2.6, 2.1));
wav('drift', 24, melody([220,261.63,329.63,293.66,261.63,220,196,220], 2.6, 2.8));
wav('chimes', 24, melody([523.25,659.25,783.99,659.25,587.33,523.25,440,523.25], 2.6, 1.8));
// Seamless, low-level harmonic soundscape with periodic modulation.
wav('ambient', 30, t => 0.12*(0.8+0.2*Math.sin(2*Math.PI*t/30))*(Math.sin(2*Math.PI*110*t)*0.6+Math.sin(2*Math.PI*165*t)*0.25+Math.sin(2*Math.PI*220*t)*0.15));
