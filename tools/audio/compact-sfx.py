"""Retain voices/short PCM; convert remaining effects to compact PSG envelopes.

This is a destination timbre adaptation, not a claim of waveform identity.
Pitch/envelope/duration come from the existing original-driver captures.
All continuous engine windows remain signed PCM, at the established rate.
"""
import hashlib
import json
import math
import struct
import wave
from pathlib import Path
import numpy as np
from catalog import ROOT

OUT=ROOT/'build/audio-native'


def frequency(hz):
    return max(1,min(1023,round(3579545/(32*hz))))


def sequence(path):
    with wave.open(str(path)) as wav:
        assert wav.getsampwidth()==2 and wav.getnchannels()==1
        rate=wav.getframerate();data=np.frombuffer(wav.readframes(wav.getnframes()),dtype='<i2').astype(float)/32768
    # Remove DC for analysis only. Original PCM retained below is unchanged.
    data-=data.mean() if len(data) else 0
    spectral=[];frames=[]
    for frame in range(math.ceil(len(data)*60/rate)):
        first=round(frame*rate/60);window=data[first:first+256]
        rms=float(np.sqrt(np.mean(window**2))) if len(window) else 0
        spectrum=abs(np.fft.rfft(window*np.hanning(len(window)),512))
        spectrum[:4]=0
        peak=int(np.argmax(spectrum));concentration=float(spectrum[max(0,peak-1):peak+2].sum()/max(1e-9,spectrum.sum()))
        spectral.append(concentration)
        hz=max(32,min(2400,peak*rate/512))
        tl=max(0,min(15,round(-20*math.log10(max(1e-6,rms)*2)/2)))
        frames.append((hz,tl))
    noise=np.median(spectral)<.22 if spectral else False
    # Variable-rate white noise uses tone2 as its clock. Both music voices
    # are temporarily borrowed, like the original SFX voices 6/7. PCM
    # engines and voices keep running, so no effect depends on FM6/DAC.
    frames=[(frequency(max(1800,hz*4) if noise else hz),tl) for hz,tl in frames]
    result=bytearray([int(noise),0]);at=0
    while at<len(frames):
        f,tl=frames[at];count=1
        while at+count<len(frames) and frames[at+count]==(f,tl) and count<255:count+=1
        result+=bytes([count,tl])+struct.pack('>H',f);at+=count
    result+=bytes(4)
    return result,dict(frames=len(frames),noise=bool(noise),bytes=len(result),
        source_sha256=hashlib.sha256(path.read_bytes()).hexdigest())


def main():
    source=ROOT/'build/sf-sfx';manifest=json.loads((source/'manifest.json').read_text())
    output=OUT/'effects';output.mkdir(parents=True,exist_ok=True)
    # 128 KiB total PCM budget, including all engine loops. Voice chains
    # retain their original source captures and priority/ownership records.
    pcm={};rows=[];remaining=128*1024
    for row in manifest['continuous']:
        path=source/(row['tag']+'.pcm');data=path.read_bytes();identity=hashlib.sha256(data).hexdigest()
        if identity not in pcm: pcm[identity]=data;remaining-=len(data)
        rows.append(dict(kind='loop',tag=row['tag'],pcm=identity,bytes=len(data)))
    sounds=manifest['integrated'];voices={0x0d,0x13,0x2a,0x67,0xae}
    # Preserve voices first; then the shortest effects maximise the number
    # of original waveforms kept within the real mapper's ROM aperture.
    for row in sorted(sounds,key=lambda s:(s['id'] not in voices,s['bytes'],s['id'])):
        sid=row['id'];data=(source/f'{sid:02x}.pcm').read_bytes();identity=hashlib.sha256(data).hexdigest()
        item=dict(id=sid,priority=row['priority'],voice=row['voice'],source_bytes=len(data))
        if not data:item.update(kind='silent')
        elif identity in pcm or len(data)<=remaining or sid in voices:
            if identity not in pcm:pcm[identity]=data;remaining-=len(data)
            item.update(kind='pcm',pcm=identity,bytes=len(data))
        else:
            converted,info=sequence(source/f'{sid:02x}.wav');file=output/f'{sid:02x}.psg'
            file.write_bytes(converted);item.update(kind='psg',file=file.relative_to(ROOT).as_posix(),**info)
        rows.append(item)
    for identity,data in pcm.items():(output/(identity+'.pcm')).write_bytes(data)
    result=dict(pcm_bytes=sum(map(len,pcm.values())),native_bytes=sum(r.get('bytes',0) for r in rows if r['kind']=='psg'),
        original_rate=manifest['rate'],effects=rows,adaptation='PSG tone2/noise resynthesis for effects exceeding PCM budget; original PCM voices/engines retained')
    (OUT/'compact-sfx.json').write_text(json.dumps(result,indent=2)+'\n')
    print(result['pcm_bytes'],'PCM bytes;',result['native_bytes'],'PSG bytes;',collections_count(rows))


def collections_count(rows):
    return {kind:sum(r['kind']==kind for r in rows) for kind in ('pcm','psg','silent','loop')}


if __name__=='__main__': main()
