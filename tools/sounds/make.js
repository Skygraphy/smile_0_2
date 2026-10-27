// Synthesized UI pops (own sounds, nothing copied): 44.1 kHz mono 16-bit WAV.
const fs=require('fs'),path=require('path');const SR=44100;
function wav(samples){const b=Buffer.alloc(44+samples.length*2);b.write('RIFF',0);b.writeUInt32LE(36+samples.length*2,4);b.write('WAVE',8);b.write('fmt ',12);b.writeUInt32LE(16,16);b.writeUInt16LE(1,20);b.writeUInt16LE(1,22);b.writeUInt32LE(SR,24);b.writeUInt32LE(SR*2,28);b.writeUInt16LE(2,32);b.writeUInt16LE(16,34);b.write('data',36);b.writeUInt32LE(samples.length*2,40);samples.forEach((s,i)=>b.writeInt16LE(Math.max(-1,Math.min(1,s))*32767|0,44+i*2));return b;}
// One pop: pitch glides f0->f1 over `glide` s, amp: attack then exp decay.
function pop({f0,f1,dur,glide,attack=0.004,decay,gain=0.8,harm=0.18,at=0},out){
  let ph=0;const start=Math.round(at*SR),n=Math.round(dur*SR);
  for(let i=0;i<n;i++){const t=i/SR;const k=Math.min(1,t/glide);const f=f0*Math.pow(f1/f0,1-Math.pow(1-k,2));ph+=2*Math.PI*f/SR;
    const env=(t<attack?t/attack:Math.exp(-(t-attack)/decay));const s=(Math.sin(ph)+harm*Math.sin(2*ph))*env*gain/(1+harm);
    out[start+i]=(out[start+i]||0)+s;}
}
function make(name,fn,len){const out=new Array(Math.round(len*SR)).fill(0);fn(out);
  // soft fade-out at the very end
  for(let i=0;i<200;i++)out[out.length-1-i]*=i/200;fs.writeFileSync(path.join(__dirname,name+'.wav'),wav(out));}
make('plopp',o=>pop({f0:380,f1:900,dur:0.16,glide:0.05,decay:0.035},o),0.17);
make('tropfen',o=>pop({f0:1500,f1:520,dur:0.20,glide:0.06,decay:0.05,harm:0.08},o),0.21);
make('doppel',o=>{pop({f0:420,f1:820,dur:0.11,glide:0.035,decay:0.025,gain:0.7},o);pop({f0:560,f1:1150,dur:0.14,glide:0.04,decay:0.03,gain:0.8,at:0.085},o);},0.23);
make('blubb',o=>pop({f0:260,f1:620,dur:0.18,glide:0.08,decay:0.05,harm:0.3},o),0.19);
make('eingang',o=>pop({f0:900,f1:480,dur:0.15,glide:0.05,decay:0.035,gain:0.55,harm:0.1},o),0.16);
