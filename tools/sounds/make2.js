// The send tone is 'tupf' (J, Ernst 2026-10-27); the receive tone 'eingang' is in make.js.
// Round 2: full ("satt"), short, simple -- low/mid pitch, soft attack, quick decay.
const fs=require('fs'),path=require('path');const SR=44100;
function wav(s){const b=Buffer.alloc(44+s.length*2);b.write('RIFF',0);b.writeUInt32LE(36+s.length*2,4);b.write('WAVE',8);b.write('fmt ',12);b.writeUInt32LE(16,16);b.writeUInt16LE(1,20);b.writeUInt16LE(1,22);b.writeUInt32LE(SR,24);b.writeUInt32LE(SR*2,28);b.writeUInt16LE(2,32);b.writeUInt16LE(16,34);b.write('data',36);b.writeUInt32LE(s.length*2,40);s.forEach((v,i)=>b.writeInt16LE(Math.max(-1,Math.min(1,v))*32767|0,44+i*2));return b;}
// Partials: [ratio, gain, decay]; f glides from f0*(1-glide) up to f0 in glideT.
function tone({f0,partials,attack=0.006,len,glide=0,glideT=0.03,gain=0.85,click=0},name){
  const n=Math.round(len*SR),out=new Array(n).fill(0);const ph=partials.map(()=>0);
  for(let i=0;i<n;i++){const t=i/SR;const g=glide?1-glide*Math.max(0,1-t/glideT):1;
    const a=t<attack?Math.sin(Math.PI/2*t/attack):1;let v=0;
    partials.forEach(([r,pg,d],k)=>{ph[k]+=2*Math.PI*f0*g*r/SR;v+=Math.sin(ph[k])*pg*Math.exp(-t/d);});
    if(click&&t<0.004)v+=click*(Math.random()*2-1)*(1-t/0.004);
    out[i]=v*a*gain;}
  const peak=Math.max(...out.map(Math.abs));for(let i=0;i<n;i++)out[i]=out[i]/peak*gain;
  for(let i=0;i<300;i++)out[n-1-i]*=i/300;
  fs.writeFileSync(path.join(__dirname,name+'.wav'),wav(out));}
tone({f0:300,partials:[[1,1,0.045],[2.01,0.25,0.025],[3.0,0.08,0.015]],len:0.12,glide:0.25,glideT:0.025},'satt');      // F
tone({f0:520,partials:[[1,1,0.035],[2.76,0.35,0.012],[5.4,0.1,0.006]],len:0.10,attack:0.002},'tock');                  // G
tone({f0:200,partials:[[1,1,0.06],[2,0.35,0.03],[3,0.12,0.02]],len:0.14,glide:0.35,glideT:0.03,click:0.15},'knopf');   // H
tone({f0:392,partials:[[1,1,0.08],[4,0.22,0.02],[10,0.05,0.006]],len:0.16,attack:0.003},'marimba');                    // I
tone({f0:260,partials:[[1,1,0.04],[1.5,0.2,0.02]],len:0.09,glide:0.15,glideT:0.02},'tupf');                            // J
tone({f0:340,partials:[[1,1,0.05],[2,0.4,0.03],[3,0.15,0.018],[4,0.06,0.01]],len:0.11,glide:0.4,glideT:0.035},'blopp'); // K
