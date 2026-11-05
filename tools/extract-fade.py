"""Recover/execute the selected ROM's byte-width INIDISP fade unit."""
from starfox_rom import rom_hex
import hashlib
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OFFSET=0x10c12
CODE=bytes.fromhex(
    rom_hex(0x10c12, 138))

def recover(rom):
    assert rom[OFFSET:OFFSET+len(CODE)]==CODE and len(CODE)==138
    assert rom[0x10000:0x10005]==bytes.fromhex(rom_hex(0x10000, 5))
    assert rom[0x1000b:0x1000d]==bytes.fromhex(rom_hex(0x1000b, 2))
    assert rom[0x10a11:0x10a17]==bytes.fromhex(rom_hex(0x10a11, 6))
    assert rom[0x10b8f:0x10b9d]==bytes.fromhex(rom_hex(0x10b8f, 14))
    return dict(offset=OFFSET,bytes=CODE.hex(),sha256=hashlib.sha256(CODE).hexdigest(),
                runtime_address='7E:3DA5',
                source='bank02.asm: CODE_7E3DAB / UltraStarFox SF/ASM/IRQ.ASM: setinidisp',
                fields=dict(mode=0x18b4,timer=0x18b5,frame=0x15bd,hdma=[0x7e45ee,0x7e45f0,0x7e45f2]),
                task06=dict(entry_offset=0x10a11,ready_flag=0x1f12,fade_call_offset=0x10b8f,
                            commit_order='ready gate; DMA/presentation and controller sampling; fade call; swap word handles 4A/4C; clear task to 0; RTL'),
                timing='Task06 calls after its ready gate/presentation; tasks00/02/04 do not call this fade. Other NMI paths also have calls. Do not schedule once per VBlank or per logical update; full NMI scheduling remains a separate unit.')

def execute(rom,state):
    """Byte accumulator interpreter; actual original branches/writes are authoritative."""
    mode,timer,frame,b0,b1,b2=state
    memory={0x18b4:mode,0x18b5:timer,0x15bd:frame&255,
            0x7e45ee:b0,0x7e45f0:b1,0x7e45f2:b2}
    pc=OFFSET; a=0; zero=False; negative=False
    for _ in range(50):
        assert OFFSET<=pc<OFFSET+138,hex(pc)
        op=rom[pc]; pc+=1
        if op==0x60:
            return (memory[0x18b4],memory[0x18b5],frame,memory[0x7e45ee],memory[0x7e45f0],memory[0x7e45f2])
        if op in (0xad,0x8d,0x9c,0x8f):
            size=3 if op==0x8f else 2
            address=int.from_bytes(rom[pc:pc+size],'little'); pc+=size
            assert address in memory,hex(address)
            if op==0xad: a=memory[address]; zero=a==0; negative=bool(a&128)
            else: memory[address]=0 if op==0x9c else a
        elif op in (0xc9,0xa9,0x29):
            value=rom[pc]; pc+=1
            if op==0xc9: zero=a==value; negative=bool(((a-value)&255)&128)
            else:
                a=value if op==0xa9 else a&value
                zero=a==0; negative=bool(a&128)
        elif op in (0x3a,0x1a):
            a=(a+(-1 if op==0x3a else 1))&255
            zero=a==0; negative=bool(a&128)
        elif op==0x82:
            delta=int.from_bytes(rom[pc:pc+2],'little',signed=True); pc+=2; pc+=delta
        elif op in (0xd0,0xf0,0x10,0x80):
            delta=int.from_bytes(rom[pc:pc+1],'little',signed=True); pc+=1
            if op==0x80 or (op==0xd0 and not zero) or (op==0xf0 and zero) or (op==0x10 and not negative): pc+=delta
        else: raise AssertionError((hex(pc-1),hex(op)))
    raise AssertionError('Fade did not return')

def generate_cases(rom):
    lines=['; Original ROM fade outputs, executed independently of destination code.']
    cases=[]
    for mode in (0,1,2,3,127,128,253,254,255):
        for timer in (0,1,2,3,14,15,16,255):
            for frame in (254,255):
                state=(mode,timer,frame,3,4,5)
                result=execute(rom,state)
                def pack(values):
                    mode,timer,frame,*brightness=values
                    return bytes((mode,timer))+frame.to_bytes(2,'big')+bytes(brightness)+b'\xa5'
                lines.append('        dc.b '+','.join(f'${v:02x}' for v in pack(state)+pack(result)))
                cases.append(dict(input=state,expected=result))
    lines.insert(1,f'M4_FADE_CASES equ {len(cases)}')
    (ROOT/'build/m4-fade-cases.inc').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    return cases
