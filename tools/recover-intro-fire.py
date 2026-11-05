"""Recover map links, native allocation identity and the fire-request boundary.

Run original 65816 until a weapon consumer is required; never replace it.
The native free list is retained because gameframe+al1pt changes fire timing.
"""
from starfox_rom import rom_hex
from pathlib import Path
import hashlib
import json
import runpy

ROOT = Path(__file__).resolve().parents[1]
SHA = '3857b5294ea8f7468849437bb2d8271564e8a0ff30774622e9c872bcbd53a84d'
TRAIL = runpy.run_path(str(ROOT/'tools/recover-intro-trails.py'))


class NativePool:
    def __init__(self):
        # Entry78AE: five retained boot/player objects, then the two texts.
        self.free = [0x336+i*54 for i in range(7,70)]
        self.parents = [0x444,0x47a]
        self.trails = [0]*16
        self.ships = []
        self.fire = 0
    def allocate(self):
        assert self.free
        return self.free.pop(0)
    def remove(self,p):
        assert p and p not in self.free
        self.free.insert(0,p)


def allocation_sequence(rom, return_pool=False):
    cameras = {s['frame']:s for s in TRAIL['CAMERA']['trajectory'](rom,75)}
    parents = TRAIL['initial_parents'](rom,cameras[4]['world_z'])
    pool = [bytearray(32) for _ in range(16)]
    native = NativePool()
    records = {}
    for frame in range(5,76):
        if frame in (37,53,69):
            native.ships.append(native.allocate())
        if frame == 75:
            native.fire = native.allocate()
        for owner in (1,0):
            p = parents[owner]
            was_alive = TRAIL['word'](p,16)
            p = bytearray(TRAIL['TEXT']['tick'](rom,p,cameras[frame-1]['view_z'],cameras[frame]['velocity']))
            parents[owner] = p
            if was_alive and not TRAIL['word'](p,16):
                native.remove(native.parents[owner])
                native.parents[owner] = 0
            if TRAIL['word'](p,22):
                slot = next(i for i,s in enumerate(pool) if not TRAIL['word'](s,16))
                native.trails[slot] = native.allocate()
            # Removed trails follow the actual linked traversal, not slot order.
            order,head = [],TRAIL['word'](p,30)
            while head != 65535:
                order.append(head)
                head = TRAIL['word'](pool[head],6)
            TRAIL['step_pool'](rom,p,pool,cameras[frame]['velocity'])
            for slot in order:
                if not TRAIL['word'](pool[slot],16):
                    native.remove(native.trails[slot])
                    native.trails[slot] = 0
        records[frame] = dict(free_head=native.free[0],parents=native.parents[:],
            trails=native.trails[:],ships=native.ships[:]+[0]*(3-len(native.ships)),fire=native.fire)
    assert records[75]['ships'] == [0x696,0x444,0x47a],records[75]
    assert records[75]['fire'] == 0x660,records[75]
    return (records,native) if return_pool else records


def original_prefix(rom, frame, pointer, life, z, velocity, initial=False):
    """Original fire initializer/tick, stopped BEFORE any weapon-side effect."""
    ram = {}
    def put(a,v,n):
        for i in range(n): ram[a+i]=(v>>(i*8))&255
    def get(a,n): return sum(ram.get(a+i,0)<<(i*8) for i in range(n))
    put(pointer+10,life,1);put(pointer+16,z,2);put(pointer+9,255,1)
    put(0x15bd,frame,1);put(0x123c,pointer,2);put(0x14f6,velocity,2)
    pc = 0x38be6 if initial else 0x38bfd
    a,width,carry,zero = 0,8,False,False
    for _ in range(100):
        if pc == 0xfd501:
            return dict(life=get(pointer+10,1),z=get(pointer+16,2),alive=0,request=0)
        if pc == 0x38c18:
            return dict(life=get(pointer+10,1),z=get(pointer+16,2),alive=1,request=1)
        op=rom[pc];pc+=1
        size,mask=width//8,(1<<width)-1
        if op in (0xc2,0xe2):
            assert rom[pc] == 32
            width=16 if op==0xc2 else 8;pc+=1
        elif op in (0xa9,0x29,0x09):
            v=int.from_bytes(rom[pc:pc+size],'little');pc+=size
            a = v if op==0xa9 else a&v if op==0x29 else a|v
            zero=(a&mask)==0
        elif op in (0xad,0xb5,0x95,0xd6,0x6d):
            n=2 if op in (0xad,0x6d) else 1
            addr=int.from_bytes(rom[pc:pc+n],'little');pc+=n
            if op in (0xb5,0x95,0xd6):addr+=pointer
            if op==0x95:put(addr,a,size)
            elif op==0xd6:
                v=(get(addr,size)-1)&mask;put(addr,v,size);zero=v==0
            elif op==0x6d:
                v=a+get(addr,size)+carry;carry=v>mask;a=v&mask;zero=a==0
            else:a=get(addr,size);zero=a==0
        elif op==0x18:carry=False
        elif op==0xf0:
            delta=int.from_bytes(rom[pc:pc+1],'little',signed=True);pc+=1
            if zero:pc+=delta
        elif op in (0x22,0x5c):
            target=int.from_bytes(rom[pc:pc+3],'little');pc+=3
            target=(target>>16)*32768+(target&32767)
            if target==0xfdc69:
                put(pointer+16,(get(pointer+16,2)+velocity)&65535,2)
            else:pc=target
        elif op==0x6b:
            return dict(life=get(pointer+10,1),z=get(pointer+16,2),alive=1,request=0)
        else:raise AssertionError((hex(pc-1),hex(op)))
    raise AssertionError('Fire prefix exceeded bound')


def recover():
    rom=(ROOT/'ref/Star Fox (USA).sfc').read_bytes()
    assert hashlib.sha256(rom).hexdigest()==SHA
    blocks={
        'map_save_last_object':(0x1f195,0x1f1b3),
        'map_link_word':(0x1f1e5,0x1f20f),
        'fire_initializer_and_tick':(0x38be6,0x38ca3),
        'weapon_dispatch':(0xfd146,0xfd185)}
    assert rom[0x6f90a:0x6f924].hex()==rom_hex(0x6f90a, 26)
    ids=allocation_sequence(rom)
    cases=[]
    for pointer in (0x336,0x36c,0x660,0x47a):
        for frame in range(256):
            for life,z,v,initial in ((35,0,63,True),(1,65530,63,False),(2,20,65535,False)):
                result=original_prefix(rom,frame,pointer,life,z,v,initial)
                expected_life=(35 if initial else life)-1
                alive=expected_life!=0
                request=int(alive and (frame+pointer)&3==0)
                expected=dict(life=expected_life,z=(z+(v if alive and not request else 0))&65535,alive=int(alive),request=request)
                assert result==expected,(frame,pointer,result,expected)
                cases.append([frame,pointer,life,z,v,int(initial),result['life'],result['z'],result['alive'],result['request']])
    onboard=[case for case in cases if case[1] in (0x336,0x660)
             and (0 if case[5] else 1 if case[2]==1 else 2)==case[0]%3]
    lines=[f'M4_FIRE_CASES equ {len(onboard)}','M4IntroFireCases:']
    lines+=['        dc.w '+','.join(str(v) for v in case) for case in onboard]
    (ROOT/'build/intro-fire-cases.inc').write_text('\n'.join(lines)+'\n',encoding='ascii')
    report=dict(rom_sha256=SHA,blocks={name:dict(offset=a,end=b,bytes=rom[a:b].hex()) for name,(a,b) in blocks.items()},
        native_pool=dict(base=0x336,stride=54,capacity=70,entry_allocated=7,records=ids),cases=len(cases),onboard_cases=len(onboard),
        scope='Map4A save/48 link and original fire initializer/tick until first weapon request. Weapon/flash/aim consumers required; no skipped firing event.')
    (ROOT/'build/intro-fire-origin.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('PASS original native identity and',len(cases),'fire-prefix cases; first request76, native0660')
    return rom,report


if __name__=='__main__':
    recover()
