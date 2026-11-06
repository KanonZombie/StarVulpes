"""Integrate the audio engine into the freshly assembled official ROM.

Graphics117 (sampler bypass, profiling marks off) is already assembled from
src/release/. No old ROM is a build dependency.
"""
import argparse
import hashlib
import json
import os
import struct
import subprocess
import sys
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from m68k_sim import load_listing


# graphics117 is assembled from src/release/ (M4_GRAPHICS117 in
# src/main_release.asm); the Nomad-measured reference it reproduces exactly.
GRAPHICS117_REFERENCE = 'd9f2a352e07de5c2792d03448955cff25d824c0657771ffcb129a7b0693e9711'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('rom', type=Path)
    parser.add_argument('listing', type=Path)
    parser.add_argument('--audio-engine', choices=('native','mdsdrv'), default='native')
    args = parser.parse_args()
    mds = args.audio_engine == 'mdsdrv'
    if not mds:
        subprocess.run([sys.executable, str(ROOT/'tools/audio/native-inputs.py')], check=True)
    symbols = load_listing(args.listing)
    assert 'G117Report' in symbols, 'graphics117 sources missing (M4_GRAPHICS117)'
    rom = bytearray(args.rom.read_bytes())
    out = ROOT / ('build/mdsdrv/release' if mds else 'build/audio-release')
    out.mkdir(parents=True, exist_ok=True)
    sys.path.insert(0,str(ROOT/'tools/audio'))
    spec=importlib.util.spec_from_file_location('pack_native',ROOT/('tools/audio/mdsdrv-bank.py' if mds else 'tools/audio/pack-native.py'))
    native=importlib.util.module_from_spec(spec);spec.loader.exec_module(native)
    extra,audio_metadata=native.pack(rom,symbols)
    spec=importlib.util.spec_from_file_location('music_events',ROOT/'tools/audio/music-events.py')
    events=importlib.util.module_from_spec(spec);spec.loader.exec_module(events)
    event_source,event_specs=events.prepare()
    # Match a unique instruction in the freshly linked, original intro
    # startup. Keep video initialisation; bypass only its fixture tests.
    start=symbols['M4IntroStart'];end=symbols['M4IntroClearCamera']
    marker=bytes.fromhex('33fc810400c00004')
    assert rom[start:end].count(marker)==1
    extra['ReleaseIntroAfterTests']=rom.index(marker,start,end)
    # Two more startup fixture tests sit after SceneInit. Keep the actual
    # SceneInit and ParticlesReset calls; remove only each call/result test.
    skipped=[]
    if mds:
        # MDS packing reuses only the numeric fixture payloads of these
        # two boot tests. Keep CPU/SVP checks, text initialisation and sound
        # initialisation. Do not write synthetic PASS results.
        a,b=symbols['CPU_DrawResults'],symbols['CPU_Stop']
        sites=[]
        for name in ('M4LogicTest','M4TextPathTest'):
            matches=[p for p in range(a,b,2) if rom[p:p+2]==b'\x61\x00'
                     and p+2+struct.unpack_from('>h',rom,p+2)[0]==symbols[name]]
            assert len(matches)==1,name
            sites.append(matches[0])
        first,last=sites
        assert first<last and (last-first)%2==0
        rom[first:last]=b'\x4e\x71'*((last-first)//2)
        skipped.append(dict(test='M4LogicTest/M4ScriptTest',site=first,bytes=last-first,
                            status='not run; fixture data reused; no PASS status written'))
    for name in ('M4IntroBossGeometryTest','M4IntroParticleTest'):
        a,b=extra['ReleaseIntroAfterTests'],symbols['M4IntroLoop']
        sites=[p for p in range(a,b,2) if rom[p:p+2]==b'\x61\x00'
               and p+2+struct.unpack_from('>h',rom,p+2)[0]==symbols[name]]
        assert len(sites)==1,name
        p=sites[0];assert rom[p+4:p+6]==bytes.fromhex('4a40')
        branch=p+6;assert rom[branch]==0x66
        length=4 if rom[branch+1]==0 else 2
        delta=struct.unpack_from('>h',rom,branch+2)[0] if length==4 else struct.unpack_from('b',rom,branch+1)[0]
        assert branch+2+delta==symbols['M4IntroFailed']
        size=6+length;rom[p:p+size]=b'\x4e\x71'*(size//2)
        skipped.append(dict(test=name,site=p,bytes=size,status='not run; no PASS status written'))
    if not mds:
        driver=(ROOT/'build/audio-native/driver/native-driver.bin').read_bytes()
        assert len(driver)==8192
        at=symbols['XGM2_Driver']
        assert rom[at:at+8192]==(ROOT/'src/audio/drv_xgm2.bin').read_bytes()
        rom[at:at+8192]=driver
        at=symbols['XGM2_Play_LoadSid']-2
        assert rom[at:at+2]==bytes.fromhex('7a7b')
        rom[at:at+2]=bytes.fromhex('7a00') #native music: no PCM; reserve SID page for Z80 helper
    # Level initialization stops the previous BGM while clearing objects.
    # Start the new screen's cue after that reset.
    scene_hooks=[];wrappers=[]
    for entry,original,bank,label in (
        ('M4TitleInit','M4SoundStopLoops','title','ReleaseTitleMusic'),
        ('M4CtlOk2','M4LevelInit','ops','ReleaseControlsMusic'),
        ('M4GameOverStart','M4LevelInit','gameover','ReleaseGameoverMusic'),
        ('M4CnOk2','M4LevelInit','continue','ReleaseContinueMusic'),
        ('M4RmOk2','M4LevelInit','map','ReleaseMapMusic'),
        ('M4TrainingStart','M4LevelInit','training','ReleaseTrainingMusic')):
        at=symbols[entry];expected=b'\x4e\xb9'+struct.pack('>I',symbols[original])
        end=at+(128 if original=='M4LevelInit' else 6)
        assert rom[at:end].count(expected)==1, (entry,original)
        at=rom.index(expected,at,end)
        wrappers.append(f'''{label}:
        jsr {original}
        move.w sr,-(sp)
        move.l d0,-(sp)
        moveq #ReleaseBank_{bank},d0
        bsr ReleaseSetBank
        move.l (sp)+,d0
        move.w (sp)+,sr
        rts
''')
        scene_hooks.append((at,6,label,True))
    at=symbols['M4LvStartInit']
    expected=b'\x4e\xb9'+struct.pack('>I',symbols['M4LevelInit'])
    expected+=b'\x4e\xb9'+struct.pack('>I',symbols['M4MusicLevel'])
    assert rom[at:at+12]==expected
    wrappers.append('''ReleaseCreditsMusic:
        move.w sr,-(sp)
        cmpi.b #END_PH_CREDITS,M4_END_ON
        bne.s ReleaseCreditsMusicDone
        cmpi.b #$0d,M4_GS_NEWBANK
        bne.s ReleaseCreditsMusicDone
        cmpi.w #$71ee,M4_GS_NEWMAP
        bne.s ReleaseCreditsMusicDone
        move.l d0,-(sp)
        moveq #ReleaseBank_staff,d0
        bsr ReleaseSetBank
        move.l (sp)+,d0
ReleaseCreditsMusicDone:
        move.w (sp)+,sr
        rts
''')
    scene_hooks.append((at+6,6,'ReleaseCreditsMusic',True))
    restart=b'\x4e\xb9'+struct.pack('>I',symbols['M4MusicLevel'])
    a,b=symbols['M4LevelRestartTick'],symbols['M4LvRestartReq']
    assert rom[a:b].count(restart)==1
    scene_hooks.append((rom.index(restart,a,b),6,'ReleaseRestartMusic',True))
    wrappers.append('''ReleaseRestartMusic:
        move.w sr,-(sp)
        bset #0,TEXT_MAP_CONTEXT+11
        move.w (sp)+,sr
        rts
''')
    at=symbols['M4VRDisplayOn']
    assert rom[at:at+12]==bytes.fromhex('3abc8174337900c000080002')
    scene_hooks.append((at,12,'ReleaseMapDisplay',False))
    radius_load=b'\x30\x39'+struct.pack('>I',symbols['M4_RM_RADIUS'])
    a,b=symbols['M4RmZoomPlanet'],symbols['M4RmZoomSprite']
    assert rom[a:b].count(radius_load)==1
    scene_hooks.append((rom.index(radius_load,a,b),6,'ReleaseMapRadius',True))
    wrappers=[w.replace('ReleaseMapMusic:\n','ReleaseMapMusic:\n        clr.b ReleaseMapHold\n') for w in wrappers]
    # A separate link keeps the hardware-proven SSP program/data locations
    # stable. Every displaced instruction is checked before installing JMP.
    definitions = '\n'.join(f'{name} equ ${value:x}' for name, value in (symbols|extra).items())
    source = out / 'release.asm'
    host_source = ROOT/('src/audio/mdsdrv-release.asm' if mds else 'src/audio/native-release.asm')
    source.write_text(definitions + '\n' + host_source.read_text()+'\n'+(ROOT/'src/release/routemap.asm').read_text()+'\n'+'\n'.join(wrappers)+'\n'+event_source)
    binary, listing = out / 'release.raw', out / 'release.lst'
    assembler = os.environ.get('MEGASVP_ASM68K') or str(ROOT.parent / 'asmTools/asm68k.exe')
    for path in (binary, listing):
        path.unlink(missing_ok=True)
    result = subprocess.run([assembler, '/p', f'{source},{binary},,{listing}'], capture_output=True)
    (out / 'release.log').write_bytes(result.stdout + result.stderr)
    # Exit code and output, not the '0 error(s)' text: asm68k rewrites its
    # progress line with carriage returns and long paths can overwrite it.
    ok = result.returncode == 0 and binary.exists() and listing.exists()
    assert ok, f'asm68k failed on {source}; see {out / "release.log"}'
    audio = bytearray(binary.read_bytes()); labels = load_listing(listing)
    at = extra.get('ReleaseHostBase', 0x1af100)
    assert at + len(audio) <= extra.get('ReleaseHostLimit', 0x1b0000) and not any(rom[at:at + len(audio)])
    event_specs=events.install(rom,audio,at,labels,symbols,event_specs)
    rom[at:at + len(audio)] = audio
    for hook, expected, destination in (
        ('M4RmPlanetAlone','48e7c0e07000','ReleaseMapAlone'),
        ('M4RmPepperVideo','48e7e0c040e7','ReleaseMapPepper'),
        ('M4ScTransSwap', '41f9'+struct.pack('>I',symbols['TEXT_MAP_CONTEXT']).hex(),'ReleaseMusicBg'),
        ('M4ScriptCommit','0c680001001a','ReleaseMusicCommit'),
        ('M4SoundInit','41f9'+struct.pack('>I',symbols['M4_SFX_DIAG']).hex(),'ReleaseAudioInit'),
        ('M4Sfx','40e748e7ffe0','ReleaseSfx'),
        ('XGM2_PlayPCM', '48e77fe040e7', 'ReleasePCMGuard')):
        at = symbols[hook]
        assert rom[at:at + 6] == bytes.fromhex(expected), (hook, rom[at:at + 6].hex())
        rom[at:at + 6] = bytes.fromhex('4ef9') + struct.pack('>I', labels[destination])
    for entry,destination in (('M4IntroStart','ReleaseIntroStart'),('M4MusicStop','ReleaseMusicStop'),
            ('M4MusicCorneria','ReleaseCorneria')):
        at=symbols[entry]
        rom[at:at+6]=b'\x4e\xf9'+struct.pack('>I',labels[destination])
    for at,length,destination,call in scene_hooks:
        rom[at:at+length]=(b'\x4e\xb9' if call else b'\x4e\xf9')+struct.pack('>I',labels[destination])+b'\x4e\x71'*((length-6)//2)
    assert struct.unpack_from('>I',rom,0x78)[0]==symbols['M4IntroVBlankIRQ']
    struct.pack_into('>I',rom,0x78,labels['ReleaseAudioIRQ'])
    if mds:
        # Never mix driver ABIs or let an old loop access MDSDRV Z80 state.
        for entry in ('XGM2_StopPCM',):
            rom[symbols[entry]:symbols[entry]+2] = bytes.fromhex('4e75')
        for entry,destination in (('M4SoundDmaBegin','ReleaseDmaBegin'),('M4SoundDmaEnd','ReleaseDmaEnd'),('M4SoundLoop','ReleaseSoundLoop')):
            at=symbols[entry]
            rom[at:at+6]=bytes.fromhex('4ef9')+struct.pack('>I',labels[destination])
        assert struct.unpack_from('>I',rom,0x70)[0]==symbols['M4VRHBlankIRQ']
        struct.pack_into('>I',rom,0x70,labels['ReleaseHBlankIRQ'])
        # Graphics117 uses one interrupt at207. Arm the PCM refill gate
        # before that deadline, using lightweight H-INTs every16 lines.
        # The original DMA handler still runs only at its207 window.
        hint=bytes.fromhex('33fc8acf00c00004')
        a,b=symbols['M4VRVideoInit'],symbols['M4VRHBlankIRQ']
        assert rom[a:b].count(hint)==1
        at=rom.index(hint,a,b);rom[at+2:at+4]=bytes.fromhex('8a0f')
    # No unconditional level-entry theme. The background/map command owns
    # the change, including the checkpoint background on a restart.
    rom[symbols['M4MusicLevel']:symbols['M4MusicLevel'] + 2] = bytes.fromhex('4e75')
    if mds:
        # The SVP cartridge maps 2 MiB of ROM (16 Mbit, as Virtua Racing): from $200000 the 68000 sees the
        # SVP's DRAM and registers. Everything lives below it: publish the chip image, header ROM end $1FFFFF.
        assert not any(rom[0x200000:]), 'Official ROM data above 2 MiB'
        del rom[0x200000:]
        struct.pack_into('>I', rom, 0x1a4, 0x1fffff)
    struct.pack_into('>H', rom, 0x18e, sum(struct.unpack(f'>{(len(rom)-512)//2}H', rom[512:])) & 65535)
    args.rom.write_bytes(rom)
    report = ROOT/('build/mdsdrv/release-integration.json' if mds else 'build/release-integration.json')
    report.write_text(json.dumps(dict(
        sha256=hashlib.sha256(rom).hexdigest(), graphics_reference=GRAPHICS117_REFERENCE,
        automatic_report=False, runtime_profiling=False, audio_labels={k:v for k,v in labels.items() if k.startswith('Release')},
        audio_engine=args.audio_engine, audio_complete=True,audio_catalog_complete=not mds, hardware_listening_verified=False,
        pcm_aperture_limit=0x200000,native_audio=audio_metadata,music_events=event_specs,skipped_startup_tests=skipped,
        limitations=(['Music cues come from the extracted score and optional local MML. See build/mdsdrv/manifest.json for the active catalog.',
                      'Complete supplied percussion groups, filtered to4375/6562Hz; no attack substitution or tail cuts. Long SFX use PSG; nearest-object PCM precedes engine; finite PCM preempts that voice.',
                      'F1 uses160 original musical ticks and quadratic amplitude. F4/F5 retain143-tick ramps and original targets; transpose applies to destination FM/PSG melody rather than the original SPC voice subset.',
                      'DMA gate uses lightweight16-line H-INTs; actual transfers retain the207 window. Nomad listening and performance are unverified.'] if mds else
                     ['Native FM/PSG timbre and effect adaptations require listening review on Nomad.',
                      'Music events are connected for translated scenes; unported original scenes remain unported.'])), indent=2) + '\n')
    print(f'Graphics 117 integrated; continuous presentation; audio engine: {args.audio_engine}.')


if __name__ == '__main__':
    main()
