"""Recover both complete M4 scripts from the selected ROM, not auxiliary maps.

Embedded 65816 blocks are matched exactly before giving them semantic names.
This inventory is input to the destination interpreter, not a scene recorder.
"""
from starfox_rom import rom_hex
import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
LENGTHS = {0x10:3,0x12:3,0x2e:4,0x3c:4,0x3e:5,0x44:1,0x48:6,0x4a:4,
           0x4c:1,0x4e:1,0x50:1,0x5c:5,0x64:1,0x66:1,
           0x74:10,0x76:6,0x7a:4,0x86:14,0x8a:2,0x8c:3}
BLOCKS = {
    'reset_z':bytes.fromhex(rom_hex(0x6f1ff, 15)),
    'disable_controls':bytes.fromhex(rom_hex(0x6f230, 18)),
}

def recover():
    rom, authority = runpy.run_path(str(ROOT/'tools/extract-intro.py'))['recover']()
    scripts=[]
    for name,start,end in [('intro',0x7870,0x79f2),('title',0x79f2,0x7a3c)]:
        cursor=start;commands=[]
        while cursor<end:
            offset=0x68000+cursor;op=rom[offset];entry=dict(index=cursor,offset=offset,opcode=op)
            if op==0x78:
                matched=[]
                for meaning,block in BLOCKS.items():
                    if rom[offset+1:offset+1+len(block)]==block: matched.append((meaning,block))
                assert len(matched)==1,hex(offset)
                meaning,block=matched[0];length=len(block)+5
                tail=rom[offset+1+len(block):offset+length]
                assert tail==b'\xa2'+(cursor+length).to_bytes(2,'little')+b'\x6b'
                entry['semantic']=meaning
            else:
                assert op in LENGTHS,(hex(offset),hex(op));length=LENGTHS[op]
            entry['bytes']=rom[offset:offset+length].hex()
            entry['next']=cursor+length
            if op==0x2e:
                entry['destination']=int.from_bytes(rom[offset+1:offset+3],'little')
                assert rom[offset+3]==13 and start<=entry['destination']<end
            if op in (0x74,0x86):
                entry.update(wait=int.from_bytes(rom[offset+1:offset+3],'little'),
                             position=[int.from_bytes(rom[offset+i:offset+i+2],'little',signed=True) for i in (3,5,7)])
                if op==0x86:
                    entry.update(shape=int.from_bytes(rom[offset+9:offset+11],'little'),
                                 strategy=int.from_bytes(rom[offset+11:offset+14],'little'))
                else: entry['strategy_table_index']=rom[offset+9]
            commands.append(entry);cursor+=length
        assert cursor==end
        destinations={c['index'] for c in commands}
        assert all(c['destination'] in destinations for c in commands if c['opcode']==0x2e)
        stream=rom[0x68000+start:0x68000+end]
        (ROOT/f'build/m4-{name}-script.bin').write_bytes(stream)
        scripts.append(dict(name=name,start=start,end=end,sha256=hashlib.sha256(stream).hexdigest(),commands=commands))
    # The dispatcher IDs are byte offsets. Verify each resolved handler.
    handlers={str(op):int.from_bytes(rom[0x1ed83+op:0x1ed85+op],'little') for op in LENGTHS|{0x78:0}}
    fragments={}
    for name,start,end in [('advance',0x1ed42,0x1ed6f),('wait_bg',0x1f4ca,0x1f4e8),
                           ('bg_info',0x1efd1,0x1efe6),('wait_word',0x1fb2d,0x1fb40),
                           ('goto',0x1f38f,0x1f3a1),('quick_up',0x1f22b,0x1f237)]:
        fragments[name]=dict(offset=start,bytes=rom[start:end].hex())
    assert fragments['advance']['bytes']==rom_hex(0x1ed42, 45)
    assert fragments['wait_bg']['bytes']==rom_hex(0x1f4ca, 30)
    assert fragments['bg_info']['bytes']==rom_hex(0x1efd1, 21)
    assert fragments['wait_word']['bytes']==rom_hex(0x1fb2d, 19)
    assert fragments['goto']['bytes']==rom_hex(0x1f38f, 18)
    order=bytes.fromhex(rom_hex(0x15aec, 31))
    assert rom[0x15aec:0x15aec+len(order)]==order
    assert bytes.fromhex(rom_hex(0x159ff, 3)) in rom[0x15950:0x15aec]
    # Keep the actual table for pending-list checks, including overlapping words.
    (ROOT/'build/m4-bg-lists.bin').write_bytes(rom[0x1ac42:0x1ae42])
    lines=['; Selected-ROM command boundaries; raw script bytes remain authoritative.',
           'M4ScriptBoundaries:']
    for script in scripts:
        for command in script['commands']:
            kind={'reset_z':1,'disable_controls':2}.get(command.get('semantic'),0)
            lines.append(f"        dc.w ${command['index']:04x},{command['next']-command['index']},{kind}")
    lines.extend(['        dc.w $ffff,0,0','M4ScriptBoundariesEnd:'])
    (ROOT/'build/m4-script-boundaries.inc').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    execute=runpy.run_path(str(ROOT/'tools/original-map-control.py'))['execute']
    cases=[]
    for counter in (0,1,32767,32768,65535):
        for last in (0,1,32767,32768,65535):
            for z in (0,1,32767,32768,65535):
                state=dict(pointer=0x7875,counter=counter,last_z=last,delta_z=0,z=last,
                           flags=0x1234,background=0,dma_list=0xf3,mode=0,timer=0,
                           brightness=128,bank=13)
                parsing=execute(rom,0x1ed42,state,z)
                if parsing:assert execute(rom,0x1f4ca,state)==0
                values=[counter,last,z,state['counter'],state['last_z'],state['delta_z'],state['pointer']]
                cases.append('        dc.w '+','.join(f'${v:04x}' for v in values))
    (ROOT/'build/m4-script-numeric.inc').write_text(f'M4_SCRIPT_NUMERIC_CASES equ {len(cases)}\n'+'\n'.join(cases)+'\n',encoding='utf-8')
    report=dict(rom=authority['rom'],sha256=authority['sha256'],scripts=scripts,handlers=handlers,
                fragments=fragments,update_order=dict(offset=0x15aec,bytes=order.hex(),
                    semantics='MainLoop 02:D950 calls 02:DAEC: increment gameframe, init strategies, update map from preceding player worldZ, then traverse object strategies.'),
                sources=['SF/MAPS/INTRO.ASM','SF/MAPS/TITLE.ASM','SF/ASM/WORLD.ASM','SF/ASM/TRANS.ASM','SF/INC/MAPSTRUC.INC'],
                scope='Whole scripts and embedded blocks recovered. Object strategies, loader completion and display scheduling are separate consumers; parsing is not complete intro playback.')
    (ROOT/'build/m4-scripts.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('Recovered complete ROM scripts:',[(s['name'],len(s['commands'])) for s in scripts])
    return rom,report

if __name__=='__main__':recover()
