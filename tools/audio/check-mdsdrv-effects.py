"""Verify quality effects with optional PCM-free Corneria and normal playback."""
import hashlib
import importlib.util
import json
import re
import sys
import wave
from pathlib import Path

import numpy as np

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from m68k_sim import load_listing
from catalog import inventory
spec=importlib.util.spec_from_file_location('concurrent',Path(__file__).with_name('check-mdsdrv-concurrent.py'))
runtime=importlib.util.module_from_spec(spec);spec.loader.exec_module(runtime)


def main():
    out=ROOT/'build/mdsdrv'
    rom=runtime.host.read_built_rom()
    manifest=json.loads((out/'manifest.json').read_text());packed=json.loads((out/'packed.json').read_text())
    music=manifest['music_enabled']
    music_pcm=manifest.get('music_pcm',False)
    assert len(rom)==0x200000 and int.from_bytes(rom[0x1a4:0x1a8],'big')==0x1fffff  # 16 Mbit SVP cartridge image
    assert manifest['songs']==len(manifest['song_ids'])
    music_hashes=set();music_bytes=0
    for row in manifest['music']['waves']:
        with wave.open(str(ROOT/row['destination'])) as wav:data=wav.readframes(wav.getnframes())
        assert max(abs(int(v)-128) for v in data)<=64
        music_hashes.add(hashlib.sha256(data+bytes([128])*32).hexdigest());music_bytes+=len(data)
    if music:
        assert {int(number) for number in manifest['song_ids']}==set(range(1,54))-{47}
        assert all('local' not in row for row in manifest['music']['songs'])
        assert manifest['commands']['16']['18']==manifest['song_ids']['44']
        corneria=next(row for row in manifest['music']['songs'] if row['source']==6)
        mml=(out/corneria['mml']).read_text()
        assert not re.search(r'^[FK]\s',mml,re.M)
        channels=set(re.findall(r'^([A-L])\s',mml,re.M))
        assert channels & set('ABCDEGHI') == set('ABCDEG')
        assert ('L' in channels)==music_pcm
        # Baseline8891d1ee (effects confirmed improved by the user): all113
        # unique packed PCM chunks, including their silence padding.
        hashes=sorted(v.get('logical_sha256',v['sha256']) for k,v in packed['assets'].items()
                      if k.startswith('pcm_') and v.get('logical_sha256',v['sha256']) not in music_hashes)
        assert len(hashes)==113
        assert hashlib.sha256('\n'.join(hashes).encode()).hexdigest()=='b4da01bf6d610538b924429bfc4f24f81b70145a0198538d6a42620486d1c4a0', 'Music must not change any packed effect sample'
    assert len(manifest['effects']['restored_pcm_ids'])==50
    for asset in packed['assets'].values():
        at,size=asset['address'],asset['bytes']
        assert 0<=at<at+size<=0x200000
        assert hashlib.sha256(rom[at:at+size]).hexdigest()==asset['sha256']
        if 'logical_bytes' in asset:
            expanded=rom[at:at+size]+bytes([128])*(asset['logical_bytes']-size)
            assert hashlib.sha256(expanded).hexdigest()==asset['logical_sha256'], 'Only exact trailing silence may be removed'
    # Check actual compiled resource arbitration, not just generated MML.
    labels=load_listing(out/'release/release.lst');driver=packed['assets']['driver']['address']
    listing=(out/'driver/out/mdsdrv.lst').read_text()
    z80=int(re.search(r'^([0-9A-F]{8})\s+mds_z80_init\s*$',listing,re.M)[1],16)
    cpu=runtime.CPU(rom);cpu.hooks[driver+z80]=lambda c:c.rts()
    cpu.call(driver,a0=0xff0400,a1=packed['assets']['sequences']['address'],a2=0)
    cpu.ww(0xff0084,1);cpu.call(driver+12,a0=0xff0400,d0=17,d1=3,d2=192)
    for bank,row in enumerate(inventory(include_arrangements=False)['original_banks']):
        cpu.call(labels['ReleaseSetBank'],d0=bank)
        expected=manifest['commands'].get(row['name'],{}).get(str(row['initial_command']),0)
        assert cpu.rw(0xff0108)==expected and cpu.rw(0xff040a)&0x3fff==expected
    for row in manifest['music']['songs']:
        cpu.call(labels['ReleaseSetBank'],d0=labels['ReleaseBank_'+row['bank']])
        cpu.call(labels['ReleaseCommand'],d0=row['command'])
        assert cpu.rw(labels['RA_SONG'])==row['song']==cpu.rw(0xff040a)&0x3fff
        assert cpu.rw(labels['RA_END'])==row['frames']
        assert cpu.rw(labels['RA_LOOP'])==(0xffff if row['loop_frame'] is None else row['loop_frame'])
    cpu.call(labels['ReleaseSetBank'],d0=6)  # Concurrency with Corneria running.
    continuous=next(n for n in manifest['effects']['continuous_pairs'].values() if n)
    cpu.call(driver+8,a0=0xff0400,d0=continuous,d1=2)
    cpu.call(driver+4,a0=0xff0400)
    for sid in (0x21,0x7c,0x35):cpu.call(labels['ReleaseSfx'],d0=sid)
    assert cpu.rw(0xff0088)==3 and cpu.rw(0xff008c)==0
    both=0;noise_frames=0;cpu.psg_noise.clear();bg_blocked=0
    for frame in range(20):
        cpu.frame=frame;cpu.call(driver+4,a0=0xff0400)
        both+=cpu.rb(0xa00e09)==15 and cpu.rb(0xa00e19)==15
        noise_frames+=cpu.psg[3]<15
        for index in range(16):
            track=0xff044c+58*index
            if cpu.rb(track+12)==11 and cpu.rb(track+13)==6:
                bg_blocked+=bool(cpu.rw(track)&0x20)
        assert cpu.rb(0xa00e10)==0, 'PCM2 must never start'
        for a in (0xa00e02,0xa00e03,0xa00e08,0xa00e10,0xa00e18):cpu.wb(a,0)
    assert both>=16 and cpu.mode_writes==[-1],(both,cpu.mode_writes)
    if music and not music_pcm:
        assert noise_frames>0 and set(cpu.psg_noise)=={2,6}, (noise_frames,cpu.psg_noise)
    if music_pcm:assert bg_blocked>=19, ('Radio must own L throughout the active overlap',bg_blocked)
    resumed=[]
    if music_pcm:
        def music_starts(interrupt, command=3):
            c=runtime.CPU(rom);c.hooks[driver+z80]=lambda c:c.rts()
            c.call(driver,a0=0xff0400,a1=packed['assets']['sequences']['address'],a2=0)
            c.ww(0xff0084,1);c.call(driver+12,a0=0xff0400,d0=17,d1=3,d2=192)
            c.call(labels['ReleaseSetBank'],d0=6)
            c.call(labels['ReleaseCommand'],d0=command);starts=[]
            assert c.rw(0xff0154)==8
            for frame in range(240):
                if interrupt and frame==3:c.call(labels['ReleaseSfx'],d0=0x7c)
                if interrupt and frame==5:c.call(labels['ReleaseSfx'],d0=0x35)
                c.frame=frame;c.call(driver+4,a0=0xff0400)
                c.call(driver+12,a0=0xff0400,d0=12,d1=3)
                assert c.d[0]==8, 'Queued music must retain its initial attenuation'
                owners=[]
                for index in range(16):
                    track=0xff044c+58*index;flags=c.rw(track)
                    if c.rb(track+12)==11 and flags&0x8000 and not flags&0x20:
                        owners.append(c.rb(track+13))
                assert len(owners)<=1 and c.rb(0xa00e10)==0
                if owners==[6] and c.rb(0xa00e18):starts.append(frame)
                for a in (0xa00e02,0xa00e03,0xa00e08,0xa00e10,0xa00e18):c.wb(a,0)
            return starts
        reference=music_starts(False);resumed=music_starts(True)
        assert resumed and set(resumed)<=set(reference), (reference,resumed,'Late PCM retrigger')
        assert any(frame>100 for frame in resumed) and len(resumed)<len(reference)
        boss_reference=music_starts(False,5);boss_resumed=music_starts(True,5)
        assert boss_resumed and set(boss_resumed)<=set(boss_reference)
        assert any(frame>100 for frame in boss_resumed)
    intro=runtime.CPU(rom);intro.hooks[driver+z80]=lambda c:c.rts()
    intro.call(driver,a0=0xff0400,a1=packed['assets']['sequences']['address'],a2=0)
    intro.ww(0xff0084,1);intro.call(driver+12,a0=0xff0400,d0=17,d1=3,d2=192)
    intro.call(labels['ReleaseSetBank'],d0=30)
    assert intro.rw(0xff0154)==12
    intro.call(labels['ReleaseMusicVolume'])
    assert intro.rw(0xff0154)==12
    intro.call(driver+4,a0=0xff0400)
    intro.call(driver+12,a0=0xff0400,d0=12,d1=3)
    assert intro.d[0]==12
    for sid in (0x45,0x23):intro.call(labels['ReleaseSfx'],d0=sid)
    assert intro.rw(0xff0088)==2
    assert intro.rw(0xff0404)&0x3fff==manifest['effects']['intro_laser_song']
    assert intro.rw(0xff0406)&0x3fff==manifest['effects']['effects']['35']['song']
    samples=[]
    for sid in manifest['effects']['restored_pcm_ids']:
        text=(out/f'sfx-{sid:02x}.mml').read_text()
        row=manifest['effects']['effects'][str(sid)]
        channel='F' if row['voice']==5 else 'L'
        assert re.findall(r'^([A-L])\s',text,re.M)==[channel]
        assert row['slot']==(0 if channel=='F' else 1)
        for path in re.findall(r'pcm "([^"]+)"',text):
            with wave.open(str(out/path)) as wav:
                rate=wav.getframerate();data=np.frombuffer(wav.readframes(wav.getnframes()),np.uint8).astype(int)-128
            assert rate in (6562,8750) and abs(data).max()<=(48 if channel=='F' else 76)
            samples.append(dict(id=sid,channel=channel,rate=rate,frames=len(data)))
    radio={int(row['song']):int(sid) for sid,row in manifest['effects']['effects'].items()
           if int(sid) in {*range(0x5f,0x65),*range(0x7a,0x80),0x8c,0x0d}}
    (out/'effects-watch.lua').write_text('return {music='+str(manifest['song_ids'].get('6',0))+',laser='+str(manifest['effects']['effects']['53']['song'])+',radio={'+','.join(f'[{song}]={sid}' for song,sid in radio.items())+'}}\n')
    report=dict(result='PASS',rom_sha256=hashlib.sha256(rom).hexdigest(),music_enabled=music,
                restored_effects=50,sample_chunks=samples,independent_player_radio_frames=both,
                bank_routes_checked=35,music_cues_checked=manifest['songs'],
                pcm_inputs_maximum=2,pcm_peak_sum_bound=124,
                music_pcm_bytes=music_bytes,effects_pcm_identical_to_baseline=music,
                music_background_frames_during_radio=bg_blocked,
                music_resumed_on_authored_frames=resumed,
                percussion_psg_audible_frames=noise_frames,percussion_fixed_noise_modes=sorted(set(cpu.psg_noise)),
                intro_laser_explosion_independent=True,
                boss_pcm_resumed_on_authored_frames=boss_resumed,
                music_attenuation_steps=dict(intro=12,other=8),
                scope='Compiled host/MDS and actual packed samples. Z80 bus consumption flags simulated here; separate Z80 execution checks sample output. Hardware listening remains required.')
    captures=[]
    for name in (('corneria-flight',) if music else ('effects-intro','effects-flight')):
        folder=out/name
        if not (folder/'state.txt').exists():continue
        state=dict(line.split('=',1) for line in (folder/'state.txt').read_text().splitlines() if '=' in line)
        if state.get('rom_hash','').lower()!=hashlib.sha1(rom).hexdigest():continue
        assert (int(state['music_active_frames'])>0)==music
        assert state['music_requested']==str(music).lower()
        if music:assert int(state['scramble_music_frames'])>0 and int(state['corneria_music_frames'])>0
        if music_pcm:
            assert int(state['music_pcm_frames'])>0 and int(state['music_player_pcm_frames'])>0
            assert state['pcm2_frames']=='0' and state['music_radio_conflicts']=='0'
        assert state['video_error']=='0' and state['sound_ready']=='1' and int(state['sfx_played'])>0
        if name.endswith('flight'):
            assert state['scramble']==state['corneria']==state['laser_requested']=='true'
            assert int(state['simultaneous_pcm_frames'])>0 and int(state['radio_pcm_frames'])>0
        with wave.open(str(folder/'audio.wav')) as wav:
            audio=np.frombuffer(wav.readframes(wav.getnframes()),'<i2').astype(float)/32768
            rms=float(np.sqrt(np.mean(audio*audio)));clipped=int((abs(audio)>=32767/32768).sum())
        assert rms>.001 and clipped==0
        captures.append(dict(name=name,state=state,rms=rms,clipped=clipped))
    report['captures']=captures
    (ROOT/'evidence/m4-mdsdrv-effects.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f"PASS: 35 banks, {manifest['songs']} music cues, 50 recovered effects unchanged, two PCM resources, music PCM={music_bytes}; {len(captures)} current playback captures.")


if __name__=='__main__':main()
