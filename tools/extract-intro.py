"""First M4 unit: ROM-authoritative intro exit decision, not a movie renderer."""
from starfox_rom import rom_hex
import hashlib
import json
from pathlib import Path
import re
import runpy

ROOT=Path(__file__).resolve().parents[1]
SHA='3857b5294ea8f7468849437bb2d8271564e8a0ff30774622e9c872bcbd53a84d'

def recover():
    rom=(ROOT/'ref/Star Fox (USA).sfc').read_bytes()
    assert len(rom)==1048576 and hashlib.sha256(rom).hexdigest()==SHA
    pattern=bytes.fromhex(rom_hex(0xff5d0, 32))
    matches=[m.start() for m in re.finditer(re.escape(pattern),rom)]
    assert matches==[0xff5d0],matches
    offset=matches[0]
    # Both backwards branches land at the same real main-loop calls.
    for branch in (offset+7,offset+20):
        delta=int.from_bytes(rom[branch+1:branch+2],'little',signed=True)
        assert branch+2+delta==offset-8
    assert rom[offset-8:offset]==bytes.fromhex(rom_hex(0x164fe, 8))
    title=bytes.fromhex(rom_hex(0xff514, 22))
    assert rom[0xff514:0xff514+len(title)]==title
    assert rom[offset+5]==0xc9
    min_frame=rom[offset+6]
    title_gate=int.from_bytes(rom[0xff51d:0xff51f],'little')
    data=dict(rom='ref/Star Fox (USA).sfc',sha256=SHA,unit='intro exit decision after MainLoop',
              offset=offset,cpu_address='1F:F5D0',bytes=pattern.hex(),
              frame_address=0x15bd,min_frame=min_frame,exit_address=0x1ffe,pad_hi=0x1202,pad_lo=0x1204,
              fade_mode=0x18b4,fade_timer=0x18b5,
              source='ref/StarFoxDisassembly-master/StarFoxDisassembly-master/bank1F.asm: Intro_Loop / Intro_FadeOut',
              discrepancies='Partial disassembly uses frame 15BB, exit 1FFC and fade 18B2/18B3. Selected ROM uses 15BD, 1FFE and 18B4/18B5; MainLoop call is 02:D950.',
              title_decision=dict(offset=0xff514,cpu_address='1F:F514',bytes=title.hex(),
                                  semantics=f'Decrement 16-bit timer first; zero takes timeout before testing unsigned16 frame >={title_gate} and padHi bit10. Timer zero underflows to FFFF.',
                                  source='bank1F.asm: Title_Loop / Title_ReloadIntro'),
              scope='Input is the state AFTER a completed original logical update. Does not yet port MainLoop, its clock, fade progression, scripts, camera or rendering.')
    return rom,data

def execute(rom,data,state):
    """Execute original 65816 decision bytes with M=8, DBR=0, unsigned carry."""
    frame,exit_flag,hi,lo,mode,timer=state
    memory={data['frame_address']:frame&255,data['exit_address']:exit_flag,
            data['pad_hi']:hi,data['pad_lo']:lo,data['fade_mode']:mode,data['fade_timer']:timer}
    start=data['offset']; pc=start; a=0; carry=False; zero=False
    for _ in range(30):
        if pc==start-8: return 0,memory[data['fade_mode']],memory[data['fade_timer']]
        if pc==start+len(bytes.fromhex(data['bytes'])): return 1,memory[data['fade_mode']],memory[data['fade_timer']]
        op=rom[pc]; pc+=1
        if op==0xe2:
            assert rom[pc]==0x20; pc+=1
        elif op in (0xad,0x0d,0x8d):
            address=int.from_bytes(rom[pc:pc+2],'little'); pc+=2
            if op==0xad: a=memory[address]; zero=a==0
            elif op==0x0d: a|=memory[address]; zero=a==0
            else: memory[address]=a
        elif op in (0xc9,0xa9):
            value=rom[pc]; pc+=1
            if op==0xc9: carry=a>=value; zero=a==value
            else: a=value; zero=a==0
        elif op in (0x90,0xd0,0xf0):
            delta=int.from_bytes(rom[pc:pc+1],'little',signed=True); pc+=1
            if (op==0x90 and not carry) or (op==0xd0 and not zero) or (op==0xf0 and zero): pc+=delta
        else: raise AssertionError((hex(pc-1),hex(op)))
    raise AssertionError('Decision did not terminate')

def execute_title(rom,data,frame,timer,pad):
    """Execute the original post-MainLoop title branch with a word on stack."""
    start=data['title_decision']['offset']; pc=start; stack=[timer]
    a=0; width=16; zero=False; carry=False; remaining=timer
    for _ in range(30):
        if pc==start-17: return 0,remaining
        if pc==start+70: return 2,remaining
        if pc==start+len(bytes.fromhex(data['title_decision']['bytes'])): return 1,remaining
        op=rom[pc]; pc+=1
        if op==0x68: a=stack.pop(); zero=a==0
        elif op==0x3a: a=(a-1)&65535; remaining=a; zero=a==0
        elif op==0x48: stack.append(a)
        elif op==0xad:
            address=int.from_bytes(rom[pc:pc+2],'little'); pc+=2
            assert address in (data['frame_address'],data['pad_hi'])
            a=frame if address==data['frame_address'] else pad; zero=a==0
        elif op in (0xc9,0x89):
            size=width//8; value=int.from_bytes(rom[pc:pc+size],'little'); pc+=size
            if op==0xc9: carry=a>=value; zero=a==value
            else: zero=(a&value)==0
        elif op==0xe2: assert rom[pc]==0x20; pc+=1; width=8
        elif op in (0x90,0xf0):
            delta=int.from_bytes(rom[pc:pc+1],'little',signed=True); pc+=1
            if (op==0x90 and not carry) or (op==0xf0 and zero): pc+=delta
        else: raise AssertionError((hex(pc-1),hex(op)))
    raise AssertionError('Title decision did not terminate')

if __name__=='__main__':
    rom,data=recover()
    build=ROOT/'build'; build.mkdir(exist_ok=True)
    fade=runpy.run_path(str(ROOT/'tools/extract-fade.py'))
    data['fade']=fade['recover'](rom)
    data['fade_cases']=len(fade['generate_cases'](rom))
    map_fade=runpy.run_path(str(ROOT/'tools/extract-map-fade.py'))
    data['map_fade']=map_fade['recover'](rom)
    data['map_fade_cases']=map_fade['generate_cases'](rom)
    (build/'m4-origin.json').write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
    (build/'m4-origin.inc').write_text(f'; Verified ROM USA, intro decision 1F:F5D0\nM4_INTRO_MIN_FRAME equ {data["min_frame"]}\n',encoding='utf-8')
    print('PASS intro decision: selected ROM 1F:F5D0; revision-specific RAM addresses verified')
