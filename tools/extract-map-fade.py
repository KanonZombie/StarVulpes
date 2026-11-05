"""Selected intro script's first two commands and original handlers only."""
from starfox_rom import rom_hex
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
HANDLERS={0x50:(0x1f237,bytes.fromhex(rom_hex(0x1f237, 12))),
          0x4c:(0x1f175,bytes.fromhex(rom_hex(0x1f175, 32)))}

def recover(rom):
    assert rom[0x6f870:0x6f874]==bytes.fromhex(rom_hex(0x6f870, 4))
    pointer=bytes.fromhex(rom_hex(0xff59d, 11))
    assert rom.count(pointer)==1
    assert rom[0x1ed6f:0x1ed83]==bytes.fromhex(rom_hex(0x1ed6f, 20))
    for command,(offset,code) in HANDLERS.items():
        assert rom[offset:offset+len(code)]==code
        assert int.from_bytes(rom[0x1ed83+command:0x1ed85+command],'little')==((offset&0x7fff)|0x8000)
    return dict(script_offset=0x6f870,map_bank=13,map_index=0x7870,cpu_address='0D:F870',
                prefix=rom[0x6f870:0x6f874].hex(' ').upper(),
                script_setup_offset=rom.index(pointer),script_setup_bytes=pointer.hex(),
                dispatcher_offset=0x1ed6f,table_offset=0x1ed83,
                handlers={hex(command):dict(offset=offset,bytes=code.hex()) for command,(offset,code) in HANDLERS.items()},
                source='SF/MAPS/INTRO.ASM; SF/ASM/WORLD.ASM: setfadeqdowndo / mapwaitfadedo',
                scope='Only commands 50 and 4C. Next command 10/setbg is not yet integrated; fail without advancing on unsupported IDs.')

def execute(rom,command,state):
    """Execute original TYX handler with byte accumulator and word index."""
    pointer,counter,mode,timer,brightness=state
    pc=HANDLERS[command][0]; x=pointer; a=0; zero=False
    memory={0x18b4:mode,0x18b5:timer,0x7e45ee:brightness,
            0x16fd:counter&255,0x16fe:counter>>8,0x16ff:pointer&255,0x1700:pointer>>8}
    def result(continuation):
        return (x if continuation else memory[0x16ff]|memory[0x1700]<<8,
                memory[0x16fd]|memory[0x16fe]<<8,memory[0x18b4],memory[0x18b5],memory[0x7e45ee]),continuation
    for _ in range(25):
        op=rom[pc]; pc+=1
        if op==0xbb: x=pointer
        elif op==0xe2: assert rom[pc]==0x20; pc+=1
        elif op in (0xad,0xaf,0x8d,0x8e,0x9c):
            size=3 if op==0xaf else 2; address=int.from_bytes(rom[pc:pc+size],'little'); pc+=size
            if op in (0xad,0xaf): a=memory[address]; zero=a==0
            elif op==0x8e: memory[address]=x&255; memory[address+1]=x>>8
            else: memory[address]=a if op==0x8d else 0
        elif op in (0xa9,0xc9):
            value=rom[pc]; pc+=1
            if op==0xa9: a=value; zero=a==0
            else: zero=a==value
        elif op==0xd0:
            delta=int.from_bytes(rom[pc:pc+1],'little',signed=True); pc+=1
            if not zero: pc+=delta
        elif op==0xe8: x=(x+1)&65535
        elif op==0x4c:
            target=int.from_bytes(rom[pc:pc+2],'little'); assert target==0xed6f
            return result(1)
        elif op==0x60: return result(0)
        else: raise AssertionError((hex(pc-1),hex(op)))
    raise AssertionError('Map fade handler did not terminate')

def generate_cases(rom):
    def pack(state):
        pointer,counter,mode,timer,brightness=state
        return pointer.to_bytes(2,'big')+counter.to_bytes(2,'big')+bytes((mode,timer,brightness,0xa5))
    lines=[]; count=0
    for command in (0x50,0x4c):
        for pointer in (0x7870,0x7871,0xffff):
            for timer in (0,1):
                for brightness in (0,15,128,129):
                    state=(pointer,0x1234,7,timer,brightness)
                    expected,continuation=execute(rom,command,state)
                    data=command.to_bytes(2,'big')+pack(state)+pack(expected)+continuation.to_bytes(2,'big')
                    lines.append('        dc.b '+','.join(f'${v:02x}' for v in data)); count+=1
    lines.insert(0,f'M4_MAP_FADE_CASES equ {count}')
    (ROOT/'build/m4-map-fade-cases.inc').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    return count
