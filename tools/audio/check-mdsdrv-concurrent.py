"""Run the real host+MDS driver together for overlapping radio/player sounds."""
import hashlib
import importlib.util
import json
import re
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from m68k_sim import load_listing
spec=importlib.util.spec_from_file_location('host',Path(__file__).with_name('check-native-release.py'))
host=importlib.util.module_from_spec(spec);spec.loader.exec_module(host)


class CPU(host.AudioCPU):
    def __init__(self,rom):
        super().__init__(rom);self.mode_writes=[];self.psg=[15]*4;self.psg_noise=[];self.pcm_starts=[];self.frame=-1
    def rb(self,address):
        if address&0xffffff in (0xa11100,0xa00e00,0xa04000):return 0
        return super().rb(address)
    def wb(self,address,value):
        address&=0xffffff
        if address==0xa00e02 and value:self.mode_writes.append(self.frame)
        if address==0xc00011 and value&0x90==0x90:self.psg[(value>>5)&3]=value&15
        if address==0xc00011 and value&0xf0==0xe0:self.psg_noise.append(value&7)
        if address==0xa00e08 and value:self.pcm_starts.append(self.frame)
        super().wb(address,value)


def main():
    folder=ROOT/'build/mdsdrv';rom=host.read_built_rom()
    manifest=json.loads((folder/'manifest.json').read_text());packed=json.loads((folder/'packed.json').read_text())
    labels=load_listing(folder/'release/release.lst');driver=packed['assets']['driver']['address']
    listing=(folder/'driver/out/mdsdrv.lst').read_text()
    z80=int(re.search(r'^([0-9A-F]{8})\s+mds_z80_init\s*$',listing,re.M)[1],16)
    continuous=next(n for n in manifest['effects']['continuous_pairs'].values() if n)
    rows=[]
    for radio in (122,124,126):
        cpu=CPU(rom);cpu.hooks[driver+z80]=lambda c:c.rts()
        cpu.call(driver,a0=0xff0400,a1=packed['assets']['sequences']['address'],a2=0)
        cpu.ww(0xff0084,1)
        cpu.call(driver+12,a0=0xff0400,d0=17,d1=3,d2=192)
        cpu.call(driver+8,a0=0xff0400,d0=6,d1=3)
        cpu.call(driver+8,a0=0xff0400,d0=continuous,d1=2)
        cpu.call(driver+4,a0=0xff0400)
        accepted=cpu.rw(0xff0088);rejected=cpu.rw(0xff008c);starts=len(cpu.pcm_starts)
        cpu.call(labels['ReleaseSfx'],d0=33)  # enemy explosion on PSG
        cpu.call(labels['ReleaseSfx'],d0=radio)  # higher priority radio wins PSG
        cpu.call(labels['ReleaseSfx'],d0=53)  # laser independently owns PCM
        assert cpu.rw(0xff0088)==accepted+3 and cpu.rw(0xff008c)==rejected,(radio,accepted,rejected,cpu.rw(0xff0088),cpu.rw(0xff008c),cpu.rw(0xff0120),cpu.rw(0xff0122))
        text=(folder/f'sfx-{radio:02x}.mml').read_text()
        channel=2 if re.search(r'^I\s',text,re.M) else 3
        channel_id=8 if channel==2 else 9
        audible=0;simultaneous=0;foreground=0
        for frame in range(20):
            cpu.frame=frame;cpu.call(driver+4,a0=0xff0400)
            audible+=cpu.psg[channel]<15
            simultaneous+=cpu.psg[channel]<15 and cpu.rb(0xa00e09)==15
            for index in range(16):
                track=0xff0400+0x4c+58*index
                if cpu.rb(track+12)==channel_id and cpu.rb(track+13)==2:
                    foreground+=bool(cpu.rw(track)&0x8000) and not bool(cpu.rw(track)&0x20)
            # Simulate consumption of the public Z80 request flags, not
            # audio: the dedicated Z80 checker tests actual sample output.
            for address in (0xa00e02,0xa00e03,0xa00e08,0xa00e10,0xa00e18):cpu.wb(address,0)
            if frame==8:cpu.call(driver+8,a0=0xff0400,d0=continuous,d1=2)
        assert audible>10 and simultaneous>10 and foreground>=19 and len(cpu.pcm_starts)>starts,(radio,audible,simultaneous,foreground)
        rows.append(dict(radio=radio,accepted_together=True,psg_audible_frames=audible,pcm_and_psg_active_frames=simultaneous,radio_foreground_frames=foreground))
    assert cpu.mode_writes==[-1],cpu.mode_writes
    report=dict(result='PASS',rom_sha256=hashlib.sha256(rom).hexdigest(),cases=rows,
                pcm_mode_reset_frames=cpu.mode_writes,
                scope='Compiled host and MDS together, BGM+engine+radio+laser requests and PSG output. Z80 consumption flags simulated here; not an auditory check.')
    path=ROOT/'evidence/m4-mdsdrv-concurrent.json'
    previous=json.loads(path.read_text()) if path.exists() else {}
    if previous.get('rom_sha256')==report['rom_sha256']:
        for key in ('runtime_observation','runtime_radio_ids','runtime_scope','runtime_trace_sha256','rejected_candidate_reproduction'):
            if key in previous:report[key]=previous[key]
    path.write_text(json.dumps(report,indent=2)+'\n')
    # Addresses/IDs for the live observer must come from this exact build.
    zlisting=(folder/'driver/out/mdssub.lst').read_text()
    enable=int(re.search(r'^\d+\s+([0-9A-Fa-f]+)\s+m3_pcm1_enable\s+equ',zlisting,re.M)[1],16)
    radios=(95,96,97,98,99,122,123,124,125,126,127,140)
    lookup=','.join(f'[{manifest["effects"]["effects"][str(sid)]["song"]}]={sid}' for sid in radios)
    capture=folder/'overlap-playback';capture.mkdir(exist_ok=True)
    (capture/'watch.lua').write_text('return {sha1="'+hashlib.sha1(rom).hexdigest()+'",laser='+str(manifest['effects']['effects']['53']['song'])+',pcm_active='+str(enable)+',radio={'+lookup+'}}\n')
    print('PASS: radio/laser coexist; radio preempts PSG explosion; unchanged PCM mode never restarts active voices.')


if __name__=='__main__':main()
