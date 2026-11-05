"""Pack locally converted score, effects and voices for SVP."""
import hashlib
import json
import os
import re
import shutil
import struct
import subprocess
import importlib.util
from pathlib import Path
from catalog import ROOT, inventory

OUT = ROOT/'build/mdsdrv'
DRIVER = Path(os.environ.get('MEGASVP_MDSDRV', ROOT.parent/'MDSDRV')).resolve()
spec=importlib.util.spec_from_file_location('mds_content',Path(__file__).with_name('mdsdrv-content.py'))
content=importlib.util.module_from_spec(spec);spec.loader.exec_module(content)


def run(command, log, **kwargs):
    result = subprocess.run(list(map(str, command)), capture_output=True, **kwargs)
    log.write_bytes(result.stdout+result.stderr)
    if result.returncode:
        raise RuntimeError(f'Command failed: {command[0]}; see {log}')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def share_sequences(data):
    """Alias only byte-identical linked songs; preserve every external ID.

    ctrmml mdsdrv.cpp:get_seq_data: song offsets are relative to sdtop+8;
    each song's internal track offsets are relative to its own data base.
    Instrument/PCM headers precede songs and therefore stay at fixed offsets.
    """
    count=struct.unpack_from('>H',data,6)[0]
    starts=[8+struct.unpack_from('>I',data,8+i*4)[0] for i in range(1,count+1)]
    end=8+struct.unpack_from('>I',data,8)[0]
    assert starts==sorted(starts) and starts[-1]<end<=len(data)
    out=bytearray(data[:starts[0]]);seen={}
    for index,(a,b) in enumerate(zip(starts,starts[1:]+[end]),1):
        song=data[a:b]
        if song not in seen:seen[song]=len(out);out.extend(song)
        at=seen[song];struct.pack_into('>I',out,8+index*4,at-8)
        assert out[at:at+len(song)]==data[a:b]
    struct.pack_into('>I',out,8,len(out)-8)
    out.extend(data[end:])
    return out,dict(songs=count,unique_songs=len(seen),saved_bytes=len(data)-len(out))


def prepare():
    for tool in ('mdslink.exe', 'sjasmplus.exe', 'salvador.exe'):
        if not (DRIVER/'tools'/tool).is_file():
            raise FileNotFoundError(f'Falta {tool}. Configure MEGASVP_MDSDRV con MDSDRV 0.6 y sus herramientas.')
    OUT.mkdir(exist_ok=True)
    source_hashes = {}
    if content.MUSIC_ENABLED:
        inputs,song_ids,music=content.prepare_music(OUT,source_hashes)
    else:
        inputs,song_ids,music=[],{},dict(songs=[],waves=[],omitted=sorted(content.OMITTED))
    effects=content.prepare_effects(OUT,inputs,source_hashes)
    commands=content.routing(song_ids,source_hashes)
    for path in inputs:
        text=path.read_text()
        text=re.sub(r'^([A-L])\s+(.+)$',lambda m:m[1]+' '+content.compact_track(m[2]),text,flags=re.M)
        path.write_text(text)
    run([DRIVER/'tools/mdslink.exe','-o','seq.bin','pcm.bin','-i','songs.inc',*[p.name for p in inputs]], OUT/'link.log',cwd=OUT)
    sequence=OUT/'seq.bin'
    shared,sequence_sharing=share_sequences(sequence.read_bytes());sequence.write_bytes(shared)
    # Assemble a workspace copy; never write into the user's external driver.
    work = OUT/'driver';(work/'src').mkdir(parents=True, exist_ok=True);(work/'out').mkdir(exist_ok=True)
    driver_sources = {}
    for name in ('blob.68k','mddef.inc','mdsdrv.inc','mdsseq.inc','mdssub.inc','mdsdrv.68k','mdssub.z80'):
        path = DRIVER/'src'/name
        shutil.copyfile(path, work/'src'/name)
        driver_sources['src/'+name] = digest(path)
    spec=importlib.util.spec_from_file_location('driver_patch',Path(__file__).with_name('mdsdrv-driver.py'))
    patcher=importlib.util.module_from_spec(spec);spec.loader.exec_module(patcher);patcher.patch(work,ROOT)
    run([DRIVER/'tools/sjasmplus.exe','src/mdssub.z80','--raw=out/mdssub.bin','--lst=out/mdssub.lst'],OUT/'z80.log',cwd=work)
    assert (work/'out/mdssub.bin').stat().st_size<0xe00
    compressed=work/'out/mdssub.zx0'
    if compressed.exists():compressed.unlink()
    run([DRIVER/'tools/salvador.exe','out/mdssub.bin','out/mdssub.zx0'],OUT/'z80-pack.log',cwd=work)
    assembler = os.environ.get('MEGASVP_ASM68K', str(ROOT.parent/'asmTools/asm68k.exe'))
    run([assembler,'/p','src/blob.68k,out/mdsdrv.bin,,out/mdsdrv.lst'], OUT/'driver.log', cwd=work)
    driver = work/'out/mdsdrv.bin'
    assert driver.stat().st_size < 16384 and b'MDSDRV0.6' in driver.read_bytes()
    sequence = OUT/'seq.bin'
    assert sequence.read_bytes()[:6] == bytes.fromhex('10011f000006')
    assert int.from_bytes(sequence.read_bytes()[6:8],'big')==len(inputs)
    for name in ('tools/audio/mdsdrv-bank.py','tools/audio/mdsdrv-content.py','tools/audio/spc_score.py','tools/audio/mdsdrv-driver.py','tools/audio/render-sfx.py','src/audio/mdsdrv-dmagate.z80'):
        source_hashes[name]=digest(ROOT/name)
    result = dict(engine='MDSDRV0.6', driver_sources=driver_sources, source_hashes=source_hashes,
                  music_rates=content.MUSIC_RATES, songs=len(song_ids), sequences=len(inputs), generated_mml=[p.name for p in inputs],song_ids=song_ids,commands=commands,
                  effects=effects, music=music,
                  files={str(p.relative_to(ROOT).as_posix()):digest(p) for p in (sequence,OUT/'pcm.bin',driver)},
                  music_enabled=content.MUSIC_ENABLED,
                  music_pcm=content.MUSIC_PCM,sequence_sharing=sequence_sharing,
                  scope='Intro, title, Corneria, its boss and clear cue recovered from SPC traces. FM/PSG synthesis and ROM percussion on background L. Effects retain priority on F/L.')
    (OUT/'manifest.json').write_text(json.dumps(result, indent=2)+'\n')
    print(f'MDSDRV ready: {sequence.stat().st_size} sequence bytes; {(OUT/"pcm.bin").stat().st_size} PCM bytes')


def compact_event_metadata(rom, symbols):
    """Keep only creation records consumed by M4LvFindEvent in the release.

    level.asm calls this lookup only from M4LvCreate (twice). Commands
    36/38/3C/8C/5A/84 read script bytes or constants directly in their own
    handlers; their generated 24-byte event copies have no consumers.
    Preserve original script bytes, boundaries, blocks and every creation
    record byte for byte. Only the two immediate search counts change.
    Diagnostic source tables and the linked layout remain unchanged.
    """
    creation = {0x00, 0x26, 0x70, 0x74, 0x76, 0x86}
    direct = {0x36, 0x38, 0x3c, 0x8c, 0x5a, 0x84}
    regions = []; report = []
    start, end = symbols['M4LvFindEvent'], symbols['M4LvCreate']
    for bank in ('0D', '05'):
        base = symbols[f'M4Map{bank}Events']
        count = symbols[f'M4_MAP{bank}_EVENTS']
        stop = symbols[f'M4Map{bank}EventsEnd']
        assert stop == base + count*24 + 2 and rom[stop-2:stop] == b'\xff\xff'
        rows = [bytes(rom[base+i*24:base+(i+1)*24]) for i in range(count)]
        keys = [int.from_bytes(row[:2], 'big') for row in rows]
        assert keys == sorted(set(keys))
        assert all(int.from_bytes(row[2:4], 'big') in creation | direct for row in rows)
        kept = [row for row in rows if int.from_bytes(row[2:4], 'big') in creation]
        # lea table,a2 / move.w #count,d1, exactly the existing consumer.
        marker = b'\x45\xf9' + struct.pack('>IHH', base, 0x323c, count)
        assert rom[start:end].count(marker) == 1, bank
        at = rom.index(marker, start, end) + 8
        struct.pack_into('>H', rom, at, len(kept))
        packed = b''.join(kept) + b'\xff\xff'
        rom[base:base+len(packed)] = packed
        regions.append((base+len(packed), stop))
        report.append(dict(bank=bank,original_records=count,creation_records=len(kept),
                           reclaimed_bytes=stop-base-len(packed),count_operand=at,
                           retained_sha256=hashlib.sha256(b''.join(kept)).hexdigest()))
    return regions, report


def pack(rom, symbols):
    manifest = json.loads((OUT/'manifest.json').read_text())
    for name, sha in (manifest['files'] | manifest['source_hashes']).items():
        assert digest(ROOT/name) == sha, f'Stale MDSDRV input/output: {name}'
    pairs = [('M4IntroShipVectorsCases','M4IntroModelVertices'),('M4IntroFireCases','M4IntroLaserFrames'),
             ('M4EffectRandomCases','M4EffectExplosionVertices'),('M4LateBossCases','M4BossModel0BSP'),
             ('M4ParticleCases','M4SoundInit')]
    # The program-window tail after the SSP tables (and the release text raster).
    tail = max(symbols.get('SVP_STextEnd', symbols['SVP_SphFastEnd']), symbols['SVP_GuardEnd'])
    # Page-alignment tails after the SVP geometry page 0 and the sphere ROM
    # tables (formerly the literals 0x17cb0e / 0x19bfb8: they follow layout).
    page_tails = [(symbols['SVP_GeoRom0End'],symbols['SVP_GeoRom1']),
                  (symbols['SVP_SphRomEnd'],symbols['SVP_TexAtlas'])]
    # The final geometry block need not abut the sphere's single-page
    # tables. Recover its alignment tail as geometry grows across stages.
    geo_end = max(v for k,v in symbols.items() if re.fullmatch(r'SVP_GeoRom\d+End', k))
    if geo_end < symbols['SVP_SphRom']:
        page_tails.append((geo_end, symbols['SVP_SphRom']))
    for a,b in page_tails:
        assert a < b and not any(rom[a:b]), 'Page-alignment tail is no longer empty'
    host_base = max(0x1af100, (symbols['SVP_BspPoolEnd'] + 15) & ~15)
    host_limit = host_base + 0xf00
    assert host_limit < 0x200000
    assert not any(rom[host_base:min(host_limit,0x1b0000)])
    # Beyond $1B0000 the base contains retired legacy samples. Reserve the
    # host before allocating MDSDRV assets; never overwrite live geometry.
    rom[host_base:host_limit] = bytes(host_limit-host_base)
    regions = [(tail,0x20000),(max(0x1b0000,host_limit),0x200000)] + page_tails
    # Raw SNES bank copies the port reads only in part: map banks 0D / 05
    # after M4_MAP*_USED_END (tools/generate-map-programs.py: every reachable
    # command and mother script ends before it), and the $FF padding of the
    # path bank (opcode $FF is no path command).
    for bank in ('0D','05'):
        base,used = symbols[f'M4Map{bank}Bytes'],symbols[f'M4_MAP{bank}_USED_END']
        commands = [struct.unpack_from('>HH', rom, symbols[f'M4Map{bank}Boundaries'] + 6*i)
                    for i in range(symbols[f'M4_MAP{bank}_COMMANDS'])]
        assert max(i+n for i,n in commands) <= used < 0x8000, f'Map bank {bank} commands past USED_END'
        regions.append((base+used, base+0x8000))
    at = symbols['M4PathBytes'] + symbols['M4_PATH_SIZE']
    while rom[at-1] == 0xff:
        at -= 1
    if symbols['M4PathBytes'] + symbols['M4_PATH_SIZE'] - at >= 256:
        regions.append((at, symbols['M4PathBytes'] + symbols['M4_PATH_SIZE']))
    # Direct program-space sphere reads replace these PM4-only copies.
    regions += [(symbols['SVP_SphUV'], symbols['SVP_SphSprTex0'])]
    regions += [(symbols[a],symbols[b]) for a,b in pairs]
    regions += [(symbols['XGM2_Driver'], symbols['XGM2_Driver']+8192)]
    # Extra diagnostic fixtures are never consumed after the intro test
    # bypass. Old SFX/engine pointer tables have no readers in this music-only
    # target (Sfx, SoundTick and SoundLoop are replaced at their entries).
    # Boot Logic/Script tests are already bypassed explicitly by build-release.
    # Reuse their code as well as fixtures; retain active fade/script routines.
    regions += [(symbols['M4LogicTest'],symbols['M4FadeStep']),
                (symbols['M4TextProjectVectors'],symbols['M4IntroCameraBeginTick']),
                (symbols['M4SfxTable'],symbols['M4SoundBgTable']),
                (symbols['M4FadeTest'],symbols['M4MapFadeCommand']),
                (symbols['M4MapFadeTest'],symbols['M4BackgroundStart']),
                (symbols['M4ScriptTest'],symbols['M4TextPathTick']),
                (symbols['M4IntroCameraVectors'],symbols['M4IntroShipInit'])]
    reclaimed,event_metadata = compact_event_metadata(rom, symbols)
    regions += reclaimed
    # Standalone diagnostic functions. Their only callers are the intro
    # startup checks bypassed by build-release.py; retain runtime helpers.
    retired_tests = [('M4IntroShipTest','M4IntroMatrix'),
                     ('M4IntroPolyTest','M4IntroMesh'),
                     # The particle test file ends with a LIVE game reset.
                     ('M4IntroBossGeometryTest','M4IntroParticlesReset'),
                     ('M4IntroLaterTest','M4IntroFastInit'),
                     ('M4TextProjectTest','M4TextProjectVectors'),
                     ('M4IntroCameraTest','M4IntroCameraVectors'),
                     ('M4IntroMatrixTest','M4IntroPolyTest'),
                     ('M4IntroFireTest','M4IntroWeaponsInit'),
                     ('M4IntroWeaponTest','M4IntroWeaponAtanTable'),
                     ('M4IntroEffectsTest','M4IntroVBlankIRQ'),
                     ('M4IntroDebrisVectorTest','M4IntroZacosInit'),
                     ('M4IntroZacoTest','M4IntroSceneInit')]
    recovered = [(symbols[a],symbols[b]) for a,b in retired_tests]
    # Alignment tails after the graphics117 SSP stub block and the last IRAM
    # image (src/release/): generated padding before fast tables / geometry.
    alignment = [(symbols['G117SvpTail'],symbols['SVP_SphFastUV']),
                 (symbols.get('SVP_STextDataEnd',symbols['G117ImgBspEnd']),symbols['SVP_GeoRom0'])]
    for a,b in alignment:
        assert a <= b and not any(rom[a:b]), 'Alignment tail is no longer empty'
    alignment = [(a,b) for a,b in alignment if a < b]
    recovered += alignment
    graphics117 = [(symbols['G117Probe'],symbols['G117ProbeEnd']),
                   (symbols['G117Report'],symbols['G117ImgBspEnd']),
                   (symbols['SVP_End'],symbols['G117SvpTail'])]
    if 'SVP_STextDispatch' in symbols:
        graphics117.append((symbols['SVP_STextDispatch'],symbols['SVP_STextEnd']))
        graphics117.append((symbols['SVP_STextData'],symbols['SVP_STextDataEnd']))
    n = 0
    while f'G117Ovr{n}' in symbols:
        graphics117.append((symbols[f'G117Ovr{n}'],symbols[f'G117Ovr{n}End'])); n += 1
    for a,b in recovered:
        assert a < b
        assert all(b <= s or a >= e for s,e in graphics117), 'Diagnostic range contains release code'
    regions += recovered
    regions.sort()
    assert all(regions[i][1] <= regions[i+1][0] for i in range(len(regions)-1))
    merged = []
    for a,b in regions:
        if merged and merged[-1][1] == a:
            merged[-1] = (merged[-1][0],b)
        else:
            merged.append((a,b))
    regions = merged
    # These ranges have no remaining base-ROM consumers. Clear before packing
    # so unallocated tails cannot retain obsolete fixtures or legacy samples.
    for a,b in regions:
        rom[a:b] = bytes(b-a)
    # The official MDSDRV path reads exclusively below its 2 MiB aperture.
    # Upper-half legacy XGM samples are not part of the active sound bank.
    rom[0x200000:0x400000] = bytes(0x200000)
    free = regions[:];assets={}
    def allocate(name, data, align=2, pcm=False):
        choices=[]
        for index,(a,b) in enumerate(free):
            # PCM cannot cross32KiB. Rank the usable bank remainder, not
            # the entire multi-bank region; that fragmented the last kit
            # samples despite several KiB of total free space.
            starts=range(a//32768*32768,b,32768) if pcm else (a,)
            for start in starts:
                at=(max(a,start)+align-1)//align*align
                end=min(b,start+32768) if pcm else b
                # Fill PCM from the bank end, preferring the smallest lost
                # alignment suffix. Keep the prefix contiguous for later
                # samples instead of stranding many near-fitting tails.
                if pcm:at=(end-len(data))//align*align
                if at>=max(a,start) and at+len(data)<=end:
                    # Best fit within one bank first. Alignment-only ranking
                    # strands near-fitting holes when host code moves a bank
                    # boundary, even with several KiB of total free space.
                    score=(end-max(a,start)-len(data),end-at-len(data)) if pcm else (end-at-len(data),0)
                    choices.append((score,index,at))
        if not choices:  # the free map, with the largest piece inside one 32 KiB bank (the PCM limit)
            for a,b in sorted(free):
                bank=max(min(b,s+32768)-max(a,s) for s in range(a//32768*32768,b,32768))
                print(f'free {a:06x}-{b:06x} {b-a:6d} bytes, in one bank {bank}')
        assert choices, (name,len(data),'MDSDRV audio exceeds physical ROM aperture',
                         sum(b-a for a,b in free),'bytes free',max((b-a for a,b in free),default=0),'largest hole')
        _,index,at=min(choices);a,b=free.pop(index)
        if a<at:free.append((a,at))
        if at+len(data)<b:free.append((at+len(data),b))
        rom[at:at+len(data)]=data
        assets[name]=dict(address=at,bytes=len(data),sha256=hashlib.sha256(data).hexdigest())
        return at
    seq=bytearray((OUT/'seq.bin').read_bytes());pcm=(OUT/'pcm.bin').read_bytes()
    labels={'ReleaseMDSDriver':allocate('driver',(OUT/'driver/out/mdsdrv.bin').read_bytes()),
            'ReleaseHostBase':host_base, 'ReleaseHostLimit':host_limit}
    # Reserve the largest CPU blob before sample placement fragments holes.
    sequence_address=allocate('sequences',bytes(len(seq)))
    # Reserve shared control tables before small PCM assets fragment holes.
    control_capacity=5120  # Current complete effects tables + Corneria clocks; fail closed on growth.
    controls_address=allocate('control_tables',bytes(control_capacity))
    controls=bytearray();control_cursor=controls_address
    def control(name,data):
        nonlocal control_cursor
        assert len(controls)+len(data)<=control_capacity
        at=control_cursor;controls.extend(data);control_cursor+=len(data)
        return at
    table=8+struct.unpack_from('>I',seq,8)[0]
    count=struct.unpack_from('>H',seq,table)[0]
    headers={8+struct.unpack_from('>H',seq,table+2+2*i)[0] for i in range(count)}
    samples={}
    for header in headers:
        pos=int.from_bytes(seq[header+1:header+4],'big');size=struct.unpack_from('>I',seq,header+4)[0]
        assert pos+size<=len(pcm) and seq[header] in (1,2,3,4), (header,pos,size,seq[header])
        # Pad enough unsigned silence for the final partially consumed block.
        data=pcm[pos:pos+size]+bytes([128])*32
        key=hashlib.sha256(data).hexdigest()
        samples.setdefault(key,dict(data=data,headers=[],quantum=seq[header]*5))['headers'].append(header)
        assert samples[key]['quantum']==seq[header]*5
    for sample in samples.values():
        data=sample['data'];original_size=len(data)-32;quantum=sample['quantum']
        # Drop only exact unsigned zero-amplitude samples. Keep the last
        # nonzero sample inside a complete mixer quantum, plus the existing
        # guard. MML note duration/resource ownership is unchanged.
        audible_size=len(data.rstrip(bytes([128])))
        size=min(original_size,max(quantum,(audible_size+quantum-1)//quantum*quantum))
        stored=data[:size]+bytes([128])*32
        assert stored+bytes([128])*(len(data)-len(stored))==data
        sample.update(stored=stored,size=size)
    ordered=sorted(samples.items(),key=lambda item:len(item[1]['stored']),reverse=True)
    for n,(key,sample) in enumerate(ordered):
        try:
            at=allocate('pcm_'+key,sample['stored'],16,True)
        except AssertionError:
            print('unplaced PCM: %d of %d, sizes %s' % (len(ordered)-n, len(ordered), [len(s['stored']) for _,s in ordered[n:]]))
            raise
        assets['pcm_'+key].update(logical_bytes=len(sample['data']),logical_sha256=key)
        for header in sample['headers']:
            seq[header+1:header+4]=at.to_bytes(3,'big')
            struct.pack_into('>I',seq,header+4,sample['size'])
    labels['ReleaseMDSSeq']=sequence_address
    rom[sequence_address:sequence_address+len(seq)]=seq
    assets['sequences']['sha256']=hashlib.sha256(seq).hexdigest()
    catalog=inventory(include_arrangements=False);initial=bytearray();banks=bytearray(35*40)
    commands=manifest['commands']
    for i,bank in enumerate(catalog['original_banks']):
        labels['ReleaseBank_'+bank['name']]=i
        initial+=struct.pack('>H',bank['initial_command'])
        for command,song in commands.get(bank['name'],{}).items():struct.pack_into('>H',banks,i*40+int(command)*2,song)
    labels['ReleaseInitialTable']=control('initial_commands',initial)
    labels['ReleaseBankTable']=control('bank_commands',banks)
    bgs=bytearray(268*2);conditional=bytearray(268)
    for bg in json.loads((ROOT/'build/level-backgrounds.json').read_text())['backgrounds']:
        music=bg['params'].get('music',[])
        if music:
            assert len(music)==1
            helper=int(music[0]['target'].replace(':',''),16)
            struct.pack_into('>H',bgs,bg['number']*2,(helper-0x03ad5d)//11+1)
            conditional[bg['number']]=bool(music[0]['cond'])
    labels['ReleaseBgBanks']=control('background_banks',bgs)
    labels['ReleaseBgConditional']=control('background_conditions',conditional)
    fxtable=bytearray(176*4)
    for sid,row in manifest['effects']['effects'].items():
        struct.pack_into('>HBB',fxtable,int(sid)*4,row['song'],row['priority'],row['slot'])
    labels['ReleaseFxTable']=control('effects_table',fxtable)
    labels['ReleaseIntroLaserSong']=manifest['effects']['intro_laser_song']
    pair_rows=[[0]*16 for _ in range(256)]
    for key,song in manifest['effects']['continuous_pairs'].items():
        engine,obj=map(int,key.split(':'));pair_rows[engine][obj]=song
    unique_rows=[];indices=bytearray();pairs=bytearray()
    for row in pair_rows:
        row=tuple(row)
        if row not in unique_rows:unique_rows.append(row);pairs+=struct.pack('>16H',*row)
        indices+=struct.pack('>H',unique_rows.index(row)*32)
    labels['ReleaseEngineIndex']=control('engine_indices',indices)
    labels['ReleaseContinuousTable']=control('continuous_pairs',pairs)
    # Original musical clock and playlist bounds drive fades/warp controls.
    clock_table=bytearray((manifest['songs']+1)*8)
    trace_data=json.loads((ROOT/'build/audio-native/score-traces.json').read_text())
    source_banks={b['name']:b for b in trace_data['banks']}
    _,source_origins=content.origins();tempo_assets={}
    for row in manifest['music']['songs']:
        number=row['source'];bank,command=source_origins[number-1]
        trace=trace_data['traces'][source_banks[bank]['slots'][str(command)]]
        origin=trace['orders'][0][0]
        end=row['loop_end_frame'] if row['loop_frame'] is not None else max(1,round((trace['song_end']-origin)*60/1024000)-1)
        tempos={max(0,round((clock-origin)*60/1024000)-1):value for clock,value in trace['tempos'] if value}
        data=b''.join(struct.pack('>HH',frame,value) for frame,value in sorted(tempos.items()) if frame<end)+bytes.fromhex('ffff0000')
        if data not in tempo_assets:tempo_assets[data]=control('tempo_'+str(number),data)
        struct.pack_into('>IHH',clock_table,row['song']*8,tempo_assets[data],end,row['loop_frame'] if row['loop_frame'] is not None else 0xffff)
    labels['ReleaseClockTable']=control('music_clocks',clock_table)
    import math
    fade=bytes(min(127,max(0,round(-40*math.log10(max(1,n)/160)/.75))) if n else 127 for n in range(161))
    labels['ReleaseFadeAtt']=control('fade_attenuation',fade+bytes(1))
    rom[controls_address:controls_address+len(controls)]=controls
    assets['control_tables']['sha256']=hashlib.sha256(rom[controls_address:controls_address+control_capacity]).hexdigest()
    assets['control_tables']['used_bytes']=len(controls)
    report=dict(assets=assets,free_bytes=sum(b-a for a,b in free),pcm_samples=len(samples),songs=manifest['songs'],
                storage_regions=regions,free_regions=sorted(free),
                cleanup=dict(retired_tests=retired_tests,recovered_audio_bytes=sum(b-a for a,b in recovered),
                             retired_upper_half_bytes=0x200000),
                event_metadata=event_metadata,
                engine='MDSDRV0.6',music_rates=manifest['music_rates'],pcm_aperture_limit=0x200000,
                sequences=manifest['sequences'],omitted_music=manifest['music']['omitted'],
                scope=manifest['scope'],sfx_enabled=True,loops='Recovered original playlist loop frames.')
    (OUT/'packed.json').write_text(json.dumps(report,indent=2)+'\n')
    return labels,report


if __name__=='__main__': prepare()
