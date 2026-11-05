"""Prepare native music, effects and command routing from the local ROM."""
import hashlib
import importlib.util
import json
import math
import re
import struct
import wave
from pathlib import Path

import numpy as np
from catalog import ROOT
import spc_score

OMITTED = {28, 37, 38, 45, 47, 48, 50}
MUSIC_RATES = {6: 4375, 17: 2187, 34: 4375}
FX_RATE = 4375
VOICE_RATE = 6562
RESTORED_SFX = {4, 53, 0x45}
MUSIC_ENABLED = True
MUSIC_TRACKS = {1, 2, 6, 17, 34}
MUSIC_PCM = True
RADIO_SFX = {0x0d,0x13,0x2a,0x67,0xae,*range(0x5f,0x65),*range(0x7a,0x80),0x8c}
# Full-band effect captures rendered during the extraction (render-sfx.py).
_spec=importlib.util.spec_from_file_location('sfx_render',Path(__file__).with_name('render-sfx.py'))
RENDERER=importlib.util.module_from_spec(_spec);_spec.loader.exec_module(RENDERER)
QUALITY_SFX = RENDERER.QUALITY_SFX


def origins():
    result=list(spc_score.ORIGINS)
    # Full original trace: command5 includes the20-second warning; command6
    # starts the124-note boss cue. The previous native index conflated them.
    result[22]=('13',6)   # supplied23:124 notes,566 frames
    result[43]=('13',5)   # supplied44:316 notes,1637 frames
    return spc_score,result


def sha(data):
    return hashlib.sha256(data).hexdigest()


def wav_read(path):
    with wave.open(str(path)) as w:
        assert w.getnchannels() == 1 and w.getsampwidth() == 1
        return np.frombuffer(w.readframes(w.getnframes()), np.uint8).astype(float)-128, w.getframerate()


def wav_write(path, data, rate):
    with wave.open(str(path), 'wb') as w:
        w.setparams((1, 1, rate, 0, 'NONE', 'not compressed'))
        w.writeframes(np.clip(np.rint(data)+128, 0, 255).astype(np.uint8).tobytes())


def resample(data, rate, target):
    if rate>target and len(data)>64:
        # Remove frequencies above the destination Nyquist before reducing
        # the rate. Linear interpolation alone aliases cymbals into whistles.
        index=np.arange(-32,33);cutoff=.45*target/rate
        taps=2*cutoff*np.sinc(2*cutoff*index)*np.hamming(len(index));taps/=taps.sum()
        data=np.convolve(data,taps,mode='same')
    return np.interp(np.arange(round(len(data)*target/rate))/target,np.arange(len(data))/rate,data)


def tokens(text):
    """Expand counted MML loops, retaining all other command tokens."""
    stack = []; result = []
    for t in re.findall(r"'[^']*'|\[|\]\d+|[^\s\[\]]+", text):
        if t == '[':
            stack.append(result); result = []
        elif t.startswith(']'):
            result = stack.pop()+result*int(t[1:])
        else:
            result.append(t)
    assert not stack
    return result


def pcm_events(text):
    result=[]; ends=[]
    for channel, line in re.findall(r'^([FKL])\s+(.+)$', text, re.M):
        # F is FM6 on one short jingle. Do not reinterpret it as PCM.
        if not re.search(r"'pcmmode", line):
            continue
        at=0; patch=None; volume=0
        for token in tokens(line):
            if token.startswith('@'): patch=int(token[1:])
            elif token.startswith('V'): volume=int(token[1:])
            elif re.fullmatch(r'[a-gr][+-]?:\d+', token):
                note, length=token.split(':'); length=int(length)
                if note != 'r':
                    assert patch is not None
                    result.append((at, length, patch, volume))
                at+=length
            else:
                assert token in ("'pcmmode 2'", "'pcmmode 3'", 'K0', 'o1', 'T127'), token
        ends.append(at)
    return sorted(result), max(ends, default=0)


def compact_track(line):
    """Factor exact token repetitions into counted loops; never cross segno."""
    # Absolute controls assigning the current value have no audible effect.
    # Reset knowledge at instrument changes, segno and unfamiliar commands;
    # never suppress an attack, tie, relative control or loop-entry restore.
    source=[];state={}
    for token in tokens(line):
        key=None
        if re.fullmatch(r'[vV]\d+',token):key='volume'
        elif re.fullmatch(r'[Kop]-?\d+',token):key=token[0]
        elif not (token=='&' or re.fullmatch(r'[a-gr][+-]?:\d+',token)):state={}
        if key:
            if state.get(key)==token:continue
            state[key]=token
        source.append(token)
    result=[];at=0
    while at<len(source):
        best=None
        for length in range(1,min(64,(len(source)-at)//2)+1):
            block=source[at:at+length]
            if 'L' in block:break
            count=1
            while count<255 and block==source[at+count*length:at+(count+1)*length]:count+=1
            saving=(count-1)*length-4
            if saving>0 and (best is None or saving>best[0]):best=(saving,length,count)
        if best:
            _,length,count=best
            result+=['[',*source[at:at+length],']'+str(count)];at+=length*count
        else:result.append(source[at]);at+=1
    packed=' '.join(result)
    assert tokens(packed)==source
    return packed


def loop_track(line, start, end):
    """Insert the verified original playlist loop without retiming notes.

    The supplied exports are finite. Restore octave/instrument/controller
    state at the segno, since the final bar may leave different values.
    Split rests or tie a sustained note when the boundary is inside it.
    """
    at=0;result=[];state={};inserted=False
    for token in tokens(line):
        if at>=end:break
        if not inserted and at==start:
            result+=['L',*state.values()];inserted=True
        note=re.fullmatch(r'([a-gr][+-]?):(\d+)',token)
        if note:
            duration=min(int(note[2]),end-at)
            if not inserted and at<start<at+duration:
                result.append(f'{note[1]}:{start-at}')
                result+=['L',*state.values()]
                if note[1]!='r':result.append('&')
                result.append(f'{note[1]}:{at+duration-start}');inserted=True
            else:result.append(f'{note[1]}:{duration}')
            at+=duration
        else:
            result.append(token)
            key=re.match(r'(@|V|v|p|K|o|E|M|P|G|k|_)',token)
            if key:state[key[1]]=token
    if not inserted:
        if at<start:result.append(f'r:{start-at}');at=start
        result+=['L',*state.values()]
    if at<end:result.append(f'r:{end-at}')
    return ' '.join(result)


# Local two-operator voices. The SPC supplies the score, not a YM patch.
NOTE_NAMES = ('c', 'c+', 'd', 'd+', 'e', 'f', 'f+', 'g', 'g+', 'a', 'a+', 'b')


def fm_patch(number, modulator_level, multiplier):
    return f"""@{number} fm
    4 0
    31 0 0 15 0 127 0 1 0 0
    31 0 0 15 0 127 0 1 0 0
    31 8 0 10 5 {modulator_level} 0 {multiplier} 0 0
    31 4 0 9 3 8 0 1 0 0
    0"""


def melodic_tracks(notes, end, loop):
    # Rank the original voices by use. The first five get YM2612 and
    # the remaining three get PSG. Keep each voice's order and rests.
    voices = {}
    for note in notes:
        if note['instrument'] < 0xca and note['frame'] < end:
            voices.setdefault(note['voice'], {})[note['frame']] = note
    lines = []
    for index, voice in enumerate(sorted(voices, key=lambda voice: (-len(voices[voice]), voice))):
        channel = 'ABCDEGHI'[index]
        fm = index < 5
        track = ['T127', 'K0', f'@{1 + index % 3 if fm else 16}']
        at = 0
        starts = sorted(voices[voice])
        for start, following in zip(starts, starts[1:] + [end]):
            note = voices[voice][start]
            if start > at:
                track.append(f'r:{start-at}')
            finish = min(following, max(start + 1, note['end']))
            pitch = max(12, min(107, note['pitch']))
            volume = max(1, note['volume'])
            attenuation = round(-20 * math.log10(volume / 127) / 0.75) + 6
            level = f'V{min(63, attenuation)}' if fm else f'v{max(1, 13 - attenuation // 3)}'
            track.extend((level, f'o{pitch//12-1}', f'{NOTE_NAMES[pitch%12]}:{finish-start}'))
            at = finish
        if at < end:
            track.append(f'r:{end-at}')
        body = ' '.join(track)
        lines.append(f'{channel} ' + (loop_track(body, loop, end) if loop is not None else body))
    return lines


def decode_brr(ram, src):
    """Decode one pass through a source sample from the uploaded ARAM."""
    pointer = struct.unpack_from('<H', ram, 0x3c00 + 4 * src)[0]
    output = []
    previous = older = 0
    while pointer + 9 <= len(ram):
        header = ram[pointer]
        shift, mode = header >> 4, (header >> 2) & 3
        for packed in ram[pointer+1:pointer+9]:
            for nibble in (packed >> 4, packed & 15):
                signed = nibble - 16 if nibble >= 8 else nibble
                value = (signed << shift) >> 1 if shift <= 12 else (-2048 if signed < 0 else 0)
                half = older >> 1
                correction = (0, (previous >> 1) + (-previous >> 5),
                              previous - half + (half >> 4) + (-3 * previous >> 6),
                              previous - half + (-13 * previous >> 7) + (3 * half >> 4))
                value = max(-32768, min(32767, value + correction[mode]))
                sample = ((value * 2 + 32768) & 65535) - 32768
                output.append(sample)
                older, previous = previous, sample
        if header & 1:
            return np.asarray(output, dtype=float)
        pointer += 9
    raise ValueError(f'BRR source {src} has no end block')


def drum_track(notes, ram, out, number, end, loop):
    groups = {}
    for note in notes:
        if note['instrument'] >= 0xca and note['frame'] < end:
            groups.setdefault(note['frame'], []).append(note)
    if not groups:
        return [], 0, []
    rate = MUSIC_RATES[number]
    decoded, patches, definitions, waves = {}, {}, [], []
    track = ["'pcmmode 3'", 'T127', 'K0', 'o1', 'V0']
    at = 0
    starts = sorted(groups)
    for start, following in zip(starts, starts[1:] + [end]):
        hits = groups[start]
        # Keep every simultaneous onset. A single PCM channel gets the mix.
        # Quantize gain to share samples and leave headroom for the SFX mixer.
        key = tuple(sorted((n['src'], round(n['spc_pitch'] / 32) * 32,
                            max(1, round(n['volume'] / 16))) for n in hits))
        if key not in patches:
            parts = []
            for src, pitch, volume in key:
                if src not in decoded:
                    decoded[src] = decode_brr(ram, src)
                data = resample(decoded[src], 32000 * max(32, pitch) / 4096, rate)
                parts.append(data * volume / 4096)
            waveform = np.zeros(max(map(len, parts)))
            for data in parts:
                waveform[:len(data)] += data
            patch = 32 + len(patches)
            assert patch <= 255, (number, 'PCM instrument capacity')
            target = out / 'music-pcm' / f'{number:02}-{patch:03}.wav'
            wav_write(target, np.clip(waveform, -48, 48), rate)
            waves.append(dict(destination=target.relative_to(ROOT).as_posix(),
                              frames=len(waveform), rate=rate, sha256=sha(target.read_bytes())))
            definitions.append(f'@{patch} pcm "music-pcm/{target.name}" rate={rate}')
            patches[key] = patch, max(1, math.ceil(len(waveform) * 60 / rate))
        patch, duration = patches[key]
        if start > at:
            track.append(f'r:{start-at}')
        finish = min(following, start + duration)
        if loop is not None and start < loop < finish:
            finish = loop
        track.extend((f'@{patch}', f'c:{finish-start}'))
        at = finish
    if at < end:
        track.append(f'r:{end-at}')
    body = ' '.join(track)
    definitions.append('L ' + (loop_track(body, loop, end) if loop is not None else body))
    return definitions, sum(map(len, groups.values())), waves


def prepare_music(out, source_hashes):
    original, source_origins = origins()
    trace_dir = ROOT / 'build/audio-native'
    data = json.loads((trace_dir / 'score-traces.json').read_text())
    banks = {bank['name']: bank for bank in data['banks']}
    (out / 'music-pcm').mkdir(exist_ok=True)
    inputs, song_ids, rows, waves = [], {}, [], []
    for number in sorted(MUSIC_TRACKS):
        bank, command = source_origins[number-1]
        trace = data['traces'][banks[bank]['slots'][str(command)]]
        ram_path = trace_dir / trace['ram']
        ram = ram_path.read_bytes()
        assert sha(ram) == banks[bank]['ram_sha256']
        source_hashes[ram_path.relative_to(ROOT).as_posix()] = sha(ram)
        notes, end, loop = original.read_notes(trace)
        assert notes and (trace['loop_end'] >= 0 or trace['song_end'] >= 0), (bank, command)
        lines = ['#platform mdsdrv', fm_patch(1, 29, 1), fm_patch(2, 39, 2),
                 fm_patch(3, 51, 1), '@16 psg\n    15 / 0']
        lines.extend(melodic_tracks(notes, end, loop))
        drums, hits, samples = drum_track(notes, ram, out, number, end, loop)
        lines.extend(drums)
        waves.extend(samples)
        path = out / f'{number:02}-spc.mml'
        path.write_text('\n'.join(lines) + '\n', encoding='ascii')
        inputs.append(path)
        song_ids[number] = len(inputs)
        rows.append(dict(source=number, song=len(inputs), bank=bank, command=command,
                         notes=len(notes), percussion_hits=hits, mml=path.name, loop_frame=loop,
                         loop_end_frame=end if loop is not None else None))
    report = dict(songs=rows, waves=waves, omitted=sorted(OMITTED),
                  deferred=sorted(set(range(1, 52)) - OMITTED - set(song_ids)),
                  adaptation='SPC note onsets and playlist bounds; local FM/PSG timbres and BRR percussion mixed on L. Pitch bends, pan and per-note volume automation are approximated by the onset.')
    (out / 'content.json').write_text(json.dumps(report, indent=2) + '\n')
    return inputs, song_ids, report


def prepare_effects(out, inputs, source_hashes):
    """MDSDRV sequences for every original SFX ID and both continuous ports.

    The existing compact SFX conversion retains spoken PCM and short
    effects; its long-effect PSG envelopes now run through MDSDRV too.
    """
    manifest_path=ROOT/'build/audio-native/compact-sfx.json'
    source_hashes[manifest_path.relative_to(ROOT).as_posix()]=sha(manifest_path.read_bytes())
    compact=json.loads(manifest_path.read_text());folder=out/'fx';folder.mkdir(exist_ok=True)
    captures=ROOT/'build/sf-sfx/manifest.json'
    source_hashes[captures.relative_to(ROOT).as_posix()]=sha(captures.read_bytes())
    voice_ids={13,19,42,103,174}
    voice_pcm={row['pcm'] for row in compact['effects'] if row.get('id') in voice_ids}
    player_ids={row['id'] for row in compact['effects'] if row.get('voice')==5}
    # Quality effects are independent of whether music is enabled.
    quality=RENDERER.load(QUALITY_SFX)
    source_hashes['build/audio-sfx-quality/manifest.json']=sha((quality/'manifest.json').read_bytes())
    pcm={};effects={};loops={1:{0:None},2:{0:None}};rows=[];intro_laser_song=0
    def sample(identity, looping=False, source=None, sid=None):
        key=(identity,looping)
        if key in pcm:return pcm[key]
        original=source or ROOT/'build/audio-native/effects'/(identity+'.pcm')
        source_hashes[original.relative_to(ROOT).as_posix()]=sha(original.read_bytes())
        if original.suffix=='.wav':
            with wave.open(str(original)) as wav:
                assert wav.getsampwidth()==2 and wav.getnchannels()==1
                raw=np.frombuffer(wav.readframes(wav.getnframes()),'<i2').astype(float)/256
                source_rate=wav.getframerate()
            rate=8750 if sid in voice_ids or sid in (0x34,0x35) else 6562
        else:
            raw=np.frombuffer(original.read_bytes(),np.int8).astype(float)
            source_rate=compact['original_rate']
            rate=VOICE_RATE if identity in voice_pcm else FX_RATE
        data=resample(raw,source_rate,rate)
        if not looping:
            # Two finite PCM resources: combat48 + radio76 <=124, even
            # for worst-case aligned peaks. Constant gain preserves envelopes.
            peak=float(abs(data).max())
            if peak:data*= (76 if sid in RADIO_SFX and sid not in player_ids else 48)/peak
        chunks=[]
        if looping:
            frames=max(1,round(len(data)*60/rate))
            data=np.interp(np.linspace(0,len(data),round(frames*rate/60),endpoint=False),np.arange(len(data)),data)
            # Blend the join of the retained steady-state window.
            fade=min(24,len(data)//8)
            if fade:data[:fade]=np.linspace(0,1,fade)*data[:fade]+np.linspace(1,0,fade)*data[-fade:]
        # Intermediate chunks end on whole video ticks; arbitrary16000-byte
        # cuts introduced rounded rests/retriggers inside long spoken phrases.
        quantum=rate//math.gcd(rate,60)
        chunk_size=(16000//quantum)*quantum
        assert chunk_size>0
        for offset in range(0,len(data),chunk_size):
            piece=data[offset:offset+chunk_size];path=folder/(identity+('-loop' if looping else '')+f'-{offset}.wav')
            wav_write(path,piece,rate)
            chunks.append((path, len(piece)))
        pcm[key]=chunks
        return chunks
    def add(name, body):
        file=out/(name+'.mml');file.write_text('#platform mdsdrv\n'+body+'\n');inputs.append(file);return len(inputs)
    def pcm_track(channel, chunks, looping=False, volume=8):
        body=[];track=["'pcmmode 3'",'T127','K0','o1',f'V{volume}'];at=0
        if looping:track.append('L')
        with wave.open(str(chunks[0][0])) as wav:rate=wav.getframerate()
        for index,(path,size) in enumerate(chunks,32):
            body.append(f'@{index} pcm "fx/{path.name}" rate={rate}')
            end=round((at+size)*60/rate);start=round(at*60/rate)
            track.append(f'@{index} c:{max(1,end-start)}');at+=size
        return '\n'.join(body)+'\n'+channel+' '+' '.join(track)
    for row in compact['effects']:
        if row['kind']=='loop':
            port,value=row['tag'].split('-');loops[int(port[1])][int(value,16)]=row['pcm'];continue
        sid=row['id'];kind=row['kind']
        # Keep player shots on F even during world explosions/dialogue on L.
        # A third PCM input exhausts the DMA reserve; original voice5 is the
        # player's resource, original voices2/3/4 share the other input here.
        channel='F' if row.get('voice')==5 else 'L'
        if kind=='silent':song=0
        elif quality and sid in QUALITY_SFX:
            original=quality/f'{sid:02x}.wav'
            song=add(f'sfx-{sid:02x}',pcm_track(channel,sample(sha(original.read_bytes()),source=original,sid=sid),volume=4))
            if sid==0x45:
                # The intro controller's enemy shots coexist with its world
                # explosion on L. No player shots run in this scene.
                intro_laser_song=add('intro-laser',pcm_track('F',sample(sha(original.read_bytes()),source=original,sid=sid),volume=0))
            kind='pcm'
        elif sid in RESTORED_SFX:
            original=ROOT/f'build/sf-sfx/{sid:02x}.pcm'
            song=add(f'sfx-{sid:02x}',pcm_track(channel,sample(sha(original.read_bytes()),source=original,sid=sid),volume=4))
            kind='pcm'
        elif kind=='pcm':song=add(f'sfx-{sid:02x}',pcm_track(channel,sample(row['pcm'],sid=sid),volume=4))
        else:
            original=ROOT/row['file'];data=original.read_bytes()
            source_hashes[original.relative_to(ROOT).as_posix()]=sha(data)
            noise=bool(data[0]);track=['T127','K0','@16',"'mode 0'"]
            for at in range(2,len(data),4):
                count,atten,high,low=data[at:at+4]
                if not count:break
                period=high*256+low;hz=3579545/(32*max(1,period))
                pitch=max(12,min(107,round(69+12*math.log2(hz/440))))
                if noise:
                    # Fixed white-noise clocks use J alone. Variable noise
                    # steals PSG3's tone register even if an I track is
                    # reserved/muted: that erased a musical channel.
                    clock=min(range(3),key=lambda n:abs(math.log2(hz/(3579545/(32*16*2**n)))))
                    track.append(f'v{15-atten} o0 '+('e','f','f+')[clock]+f':{count}')
                else:
                    note=('c','c+','d','d+','e','f','f+','g','g+','a','a+','b')[pitch%12]
                    track.append(f'v{15-atten} o{pitch//12-1} {note}:{count}')
            # Hold the supplied level until note-off. A bare "15" emits
            # 10 00: one frame followed by silence, truncating long events.
            body='@16 psg\n    15 / 0\n'+('J' if noise else 'I')+' '+' '.join(track)
            song=add(f'sfx-{sid:02x}',body)
        # Requests own physical resources, not original-voice parity:
        # original radio voice3 and player voice5 otherwise collide in
        # slot1 despite using PSG and PCM independently. One finite PCM
        # request and one finite PSG request may coexist with BGM/engine.
        slot=(0 if channel=='F' else 1) if kind=='pcm' else 1
        effects[sid]=dict(song=song,priority=row.get('priority',0),voice=row.get('voice',6),slot=slot,kind=kind)
    # One request owns the two continuous ports. Two higher-priority
    # requests remain available for the original finite-effect voices.
    pairs={};pair_table={}
    for engine,engine_pcm in sorted(loops[1].items()):
        for obj,obj_pcm in sorted(loops[2].items()):
            # One continuous PCM voice: the nearest audible object takes
            # precedence over the player's engine. Finite PCM requests can
            # preempt it; MDSDRV restores the underlying voice afterwards.
            chosen=obj_pcm or engine_pcm;volume=18 if obj_pcm else 25
            key=(chosen,volume) if chosen else (None,0)
            if key not in pairs:
                if chosen is None:pairs[key]=0
                else:
                    chunks=sample(chosen,True);assert len(chunks)==1
                    path,size=chunks[0];frames=max(1,round(size*60/FX_RATE))
                    body=f'@32 pcm "fx/{path.name}" rate={FX_RATE}\nF \'pcmmode 3\' T127 o1 V{volume} L @32 c:{frames}'
                    pairs[key]=add(f'continuous-{len(pairs):03}', body)
            pair_table[f'{engine}:{obj&15}']=pairs[key]
    report=dict(effects=effects,continuous_pairs=pair_table,unique_pairs=len(pairs),
                pcm_waveforms=len(pcm),pcm_rate=FX_RATE,voice_rate=VOICE_RATE,
                restored_pcm_ids=sorted(QUALITY_SFX if quality else RESTORED_SFX),psg_envelope='15 / 0: sustain until note-off',
                music_enabled=MUSIC_ENABLED,combat_peak=48 if quality else None,radio_peak=76 if quality else None,
                intro_laser_song=intro_laser_song,
                adaptation='50 current-scene effects recovered from native32000Hz SPC render, no envelope cuts. Player voice5 -> F/slot0; world/radio -> L/slot1. Spoken phrases and player shots8750Hz; other recovered effects6562Hz. Finite F preempts continuous engine F. Maximum two PCM inputs, peaks48+76 <=124.',voices=[13,19,42,103,174])
    (out/'effects.json').write_text(json.dumps(report,indent=2)+'\n')
    return report


def routing(song_ids, source_hashes):
    # Match aliases by original SPC note and loop signatures.
    original,source_origins=origins()
    path=ROOT/'build/audio-native/score-traces.json'
    source_hashes[path.relative_to(ROOT).as_posix()]=sha(path.read_bytes())
    traces=json.loads(path.read_text())
    banks={b['name']:b for b in traces['banks']};keys={};signatures={}
    def signature(key):
        if key not in signatures:
            row=traces['traces'][key];file=ROOT/'build/audio-native'/row['trace']
            source_hashes[file.relative_to(ROOT).as_posix()]=sha(file.read_bytes())
            assert source_hashes[file.relative_to(ROOT).as_posix()]==row['trace_sha256']
            notes,end,loop=original.read_notes(row)
            events=[(n['frame'],n['voice'],n['pitch'],n['spc_pitch'],n['instrument'],n['volume'],n['bends'],n['volumes']) for n in notes]
            signatures[key]=sha(json.dumps([end,loop,events],separators=(',',':')).encode())
        return signatures[key]
    for number,(bank,command) in enumerate(source_origins,1):
        if number in song_ids:
            keys.setdefault(signature(banks[bank]['slots'][str(command)]),song_ids[number])
    result={}
    for bank in traces['banks']:
        result[bank['name']]={int(command):keys.get(signature(key),0) for command,key in bank['slots'].items()}
    return result
