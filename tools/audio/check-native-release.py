"""Compiled host audio checks and complete packed-data bounds; no FPS run."""
import hashlib
import json
import struct
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from m68k_sim import M68K,load_listing


def read_built_rom():
    manifest = ROOT / 'build/m4-intro-build.json'
    if not manifest.is_file():
        raise FileNotFoundError('Para esta comprobación, ejecuta ./rebuild.ps1 -KeepIntermediates.')
    return (ROOT / json.loads(manifest.read_text(encoding='utf-8-sig'))['rom']).read_bytes()


class AudioCPU(M68K):
    def __init__(self,rom):
        super().__init__(rom);self.io=bytearray(0x20000);self.vdp=bytearray(32);self.io[0x11100]=1
    def _loc(self,address):
        address &=0xffffff
        if 0xa00000<=address<0xa20000:return self.io,address-0xa00000
        if 0xc00000<=address<0xc00020:return self.vdp,address-0xc00000
        return super()._loc(address)


def main():
    rom=read_built_rom()
    s=load_listing(ROOT/'build/m4-intro.lst');r=load_listing(ROOT/'build/audio-release/release.lst')
    metadata=json.loads((ROOT/'build/release-integration.json').read_text())
    packed=json.loads((ROOT/'build/audio-native/packed.json').read_text())
    cases=[]
    assert len(rom)==0x400000
    assert struct.unpack_from('>H',rom,0x18e)[0]==sum(struct.unpack('>'+str((len(rom)-512)//2)+'H',rom[512:]))&65535
    for name,row in packed['assets'].items():
        at,size=row['address'],row['bytes'];assert at+size<=0x200000
        assert hashlib.sha256(rom[at:at+size]).hexdigest()==row['sha256'],name
    scores=json.loads((ROOT/'build/audio-native/native-score.json').read_text())
    assert len(scores['banks'])==34 and len(scores['scores'])==60 and scores['music_pcm_bytes']==0
    assert all(score['dropped_notes']==0 for score in scores['scores'].values())
    for number in range(176):
        at,size=struct.unpack_from('>II',rom,s['M4SfxTable']+number*12)
        assert (not at and not size) or 0<at<at+size<=0x200000
    for address,size,valid in ((0x16000,256,True),(0x1fff00,256,True),(0x1fff00,512,False),
            (0x200000,256,False),(0x241000,256,False),(0x320000,512,False),(0x3b0000,256,False),(0x1b0000,0xffffffff,False)):
        c=AudioCPU(rom);c.a[7]=0xffff00;c.d=[size,2,9,1,0x1234,0x5678,0x9012,0xabcd]
        c.a[:7]=[address,0x1111,0x2222,0x3333,0x4444,0x5555,0x6666];before=(c.d[:],c.a[:]);c.ccr=31;seen=[]
        def accepted(cpu):seen.append(True);cpu.d[0]=1;cpu.pc=s['XGM2_PlayPCM_Exit']
        c.hooks[s['XGM2_PlayPCM']+6]=accepted;c.call(s['XGM2_PlayPCM'])
        assert bool(seen)==valid and c.d[0]==int(valid) and c.d[1:]==before[0][1:] and c.a==before[1] and c.ccr==31
        cases.append(dict(kind='aperture',address=address,size=size,accepted=valid))

    banks={b['name']:(b['helper']-0x03ad5d)//11 for b in scores['banks']}
    for bg,flags,bank in ((3,4,'10'),(27,4,'11'),(21,4,'11'),(33,4,'12'),(3,0,None),(45,4,None),(45,5,'13b')):
        c=AudioCPU(rom);c.a[7]=0xffff00;c.ccr=31;seen=[]
        c.ww(s['TEXT_MAP_CONTEXT']+10,flags);c.ww(s['TEXT_MAP_CONTEXT']+12,bg)
        def selected(cpu):seen.append(cpu.d[0]&65535);cpu.rts()
        c.hooks[r['ReleaseSetBank']]=selected;c.hooks[s['M4ScTransSwap']+6]=lambda cpu:cpu.rts()
        c.call(s['M4ScTransSwap'],d0=0x12345678)
        assert seen==([] if bank is None else [banks[bank]]) and c.d[0]==0x12345678 and c.ccr==31
        cases.append(dict(kind='real_background_consumer',background=bg,flags=flags,bank=bank))
    for command,dead,pending in ((3,0,1),(0xf0,0,1),(0xf1,0,1),(0xf4,0,1),(3,128,1),(3,0,0)):
        c=AudioCPU(rom);seen=[];ctx=s['TEXT_MAP_CONTEXT'];c.ww(ctx+20,0x14);c.ww(ctx+26,pending);c.wb(s['M4_LP_PSF2'],dead)
        c.rom[0x1000:0x1002]=bytes([0x14,command])
        def request(cpu):seen.append(cpu.d[0]);cpu.rts()
        c.hooks[r['ReleaseCommand']]=request;c.hooks[s['M4ScriptCommit']+6]=lambda cpu:cpu.rts()
        c.call(s['M4ScriptCommit'],a0=ctx,a1=0x1000)
        assert seen==([command] if pending and not dead else [])
        cases.append(dict(kind='script_command',command=command,dead=dead,pending=pending))

    def machine():
        c=AudioCPU(rom);c.wl(r['RA_MAGIC'],int.from_bytes(b'RAUD','big'));c.ww(s['M4_SFX_DIAG']+4,1)
        c.hooks[s['XGM2_RequestAccess']]=lambda cpu:(setattr(cpu,'d',[1]+cpu.d[1:]),cpu.rts())
        c.hooks[s['XGM2_RequestBus']]=lambda cpu:(cpu.wb(0xa11100,0),cpu.rts())
        c.hooks[s['XGM2_ReleaseBus']]=lambda cpu:(cpu.wb(0xa11100,1),cpu.rts())
        c.hooks[s['XGM2_Play']]=lambda cpu:(setattr(cpu,'d',[1]+cpu.d[1:]),cpu.rts())
        c.hooks[s['XGM2_Stop']]=lambda cpu:cpu.rts()
        return c
    for bank,command in (('10',16),('11',3),('title',18),('ops',18),('map',1),('training',3),('staff',18)):
        c=machine();c.a[7]=0xffff00;c.ccr=31;c.call(r['ReleaseSetBank'],d0=banks[bank])
        assert c.rw(r['RA_BANK'])==banks[bank] and c.rw(r['RA_COMMAND'])==command and c.rw(s['M4_MUSIC_ACTIVE'])==1
        at=c.rl(r['RA_SONG']);assert rom[at]==0x10 and rom[at+2:at+4]==b'\0\0'
        assert c.rb(0xa0010e)==0 and c.rb(0xa0010f)==1 and c.ccr==31
        cases.append(dict(kind='actual_bank_lookup',bank=bank,command=command,song=at))
    c=machine();c.call(r['ReleaseSetBank'],d0=banks['11']);c.call(r['ReleaseCommand'],d0=0xf1)
    assert c.rw(r['RA_FADE'])==160 and c.rw(s['M4_MUSIC_ACTIVE'])==1
    for frame in range(1,142):
        for i in range(3):c.wb(0xa00165+i,frame>>(8*i))
        c.wb(0xa0015c,0);c.call(r['ReleaseAudioTick'])
        if frame<141:assert c.rw(s['M4_MUSIC_ACTIVE'])==1
    assert c.rw(r['RA_FADE'])==0 and c.rw(s['M4_MUSIC_ACTIVE'])==0 and c.rb(0xa00100)&0x20
    cases.append(dict(kind='original_F1',music_ticks=160,source_tempo=35,consumed_frames=141,immediate_stop=False))
    c=machine();c.call(r['ReleaseSetBank'],d0=banks['11']);c.call(r['ReleaseCommand'],d0=0xf4)
    assert c.rw(r['RA_WCOUNT'])==143 and c.rb(r['RA_TRANSPOSE'])==254
    for frame in range(1,127):
        for i in range(3):c.wb(0xa00165+i,frame>>(8*i))
        c.wb(0xa0015c,0);c.call(r['ReleaseAudioTick'])
    assert c.rw(r['RA_WCOUNT'])==0 and c.rw(r['RA_WTEMPO'])==9<<8 and c.rw(r['RA_RATE'])==65
    cases.append(dict(kind='original_F4',fade_ticks=143,target_tempo=9,transpose=-2))
    c=machine();c.wb(0xa11100,0);before=bytes(c.io);c.call(r['ReleaseAudioTick']);assert bytes(c.io)==before
    cases.append(dict(kind='interrupted_bus_owner',lock_released=False))
    c=machine();c.call(r['ReleaseSetBank'],d0=banks['11']);song=c.rl(r['RA_SONG'])
    driver=(ROOT/'build/audio-native/driver/native-driver.bin').read_bytes();c.io[:8192]=driver
    before=bytes(c.io[0x1c10:0x1dc0]);del c.hooks[s['XGM2_Play']]
    c.call(s['XGM2_Play'],a0=song)
    assert c.d[0]&255==1 and bytes(c.io[0x1c10:0x1dc0])==before
    assert c.rb(0xa00100)&16
    cases.append(dict(kind='actual_XGM2_Play',reserved_Z80_code_preserved=True,music_pcm_bytes=0))
    # All declared strategy events must be installed with their compiled
    # replay and continuation, including conditional warp and briefing cues.
    for event in metadata['music_events']:
        at=event['host_site'];assert rom[at:at+6]==b'\x4e\xf9'+r[event['label']].to_bytes(4,'big')
        jump=r[event['label']+'Jump'];assert int.from_bytes(rom[jump+2:jump+6],'big')==at+len(bytes.fromhex(event['bytes']))
    report=dict(result='PASS',sha256=hashlib.sha256(rom).hexdigest(),cases=cases,
        packed_assets=len(packed['assets']),native_scores=60,strategy_events=len(metadata['music_events']),
        scope='Compiled 68000 execution and packed-data identity/bounds. Not a hardware listening or FPS test.')
    (ROOT/'evidence/m4-native-release.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'PASS {len(cases)} host cases; {len(packed["assets"])} assets inside 2 MiB; {len(metadata["music_events"])} original strategy events')

if __name__=='__main__':main()
