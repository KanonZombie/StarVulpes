"""Bounded commercial zacointro initializer/tick and its two exact models."""
import hashlib
import json
from pathlib import Path
import runpy
ROOT=Path(__file__).resolve().parents[1]
W=runpy.run_path(str(ROOT/'tools/recover-intro-weapons.py'))
E=runpy.run_path(str(ROOT/'tools/recover-intro-effects.py'))
M=runpy.run_path(str(ROOT/'tools/recover-intro-model.py'))
rom=(ROOT/'ref/Star Fox (USA).sfc').read_bytes()
assert hashlib.sha256(rom).hexdigest()==W['SHA']
OBJ=0x336
class Removed(Exception):pass

def context(cpu,alive=True):
    b=bytearray(32)
    for dest,src in ((0,12),(2,14),(4,16),(6,47),(8,49),(10,51)):
        b[dest:dest+2]=cpu.get(OBJ+src,2).to_bytes(2,'big')
    for dest,src in ((12,18),(13,19),(14,20),(15,21),(16,0x1ce7),(18,34),(19,10)):
        b[dest]=cpu.get(OBJ+src,1)
    b[21]=14;b[22:24]=int(alive).to_bytes(2,'big')
    return b

def run(mode,seed,xyz,angles=(62,15,14),speed=60,life=60,counter=10,anim=0,player=63):
    rng=list(seed)
    def random(c,x,y,a,width,carry):
        nonlocal rng
        rng,a=E['original_random'](rom,rng)
        return x,y,a,8,carry
    def sound(c,x,y,a,width,carry):return x,y,a,width,carry
    def remove(*args):raise Removed()
    cpu=W['Math65816'](rom,extra_ranges=((0x38ec5,0x38f91),(0xfc000,0xfe000)),
        hooks={0x17c4a:random,0x1b7e5:sound,0xfd501:remove})
    for at,v in zip((12,14,16),xyz):cpu.put(OBJ+at,v)
    for at,v in zip((18,19,20),angles):cpu.put(OBJ+at,v,1)
    for at,v in ((21,speed),(10,life),(34,counter),(0x1ce7,anim)):cpu.put(OBJ+at,v,1)
    cpu.put(0x14f6,player)
    before=context(cpu);alive=True
    try:cpu.run(0x38ec5 if mode==0 else 0x38f0c)
    except Removed:alive=False
    after=context(cpu,alive)
    return dict(mode=mode,input=before.hex(),player_velocity=player,seed=list(seed),
                expected=after.hex(),expected_seed=rng,removed=int(not alive),pcs=sorted(cpu.visited))

cases=[]
for i in range(16):
    cases.append(run(0,[(i*37+j*61)&255 for j in range(4)],[(0xfe70+i*61)&65535,0xfce0,16000+i*40]))
for counter in (0,1,2,9,10):
    for life in (0,1,2,60):
        for anim in (0,139):
            cases.append(run(1,[1,2,3,4],[32760,65530,32760],angles=(62,255,127),
                             counter=counter,life=life,anim=anim,speed=60))
models=[M['recover'](rom,a) for a in (0x6388,0x422c)]
(ROOT/'build/intro-zaco-models.json').write_text(json.dumps(models,indent=2)+'\n')
report=dict(rom_sha256=W['SHA'],initializer='07:8EC5..8F0B',tick='07:8F0C..8F90',
            bytes=rom[0x38ec5:0x38f91].hex(),cases=cases,
            scope='Original ROM initializer and full zacointro tick with original RNG/vector/chase/speed helpers. Removal traps the original nonlocal removal call. Sound request is acknowledged without SPC playback; zaco2 aiming/firing is separate.')
(ROOT/'build/intro-zaco-origin.json').write_text(json.dumps(report,indent=2)+'\n')
lines=['; Goldens executed from selected commercial ROM; no captured poses.',
       f'M4_ZACO_CASES equ {len(cases)}','M4ZacoCases:']
for c in cases:
    data=(bytes.fromhex(c['input'])+c['player_velocity'].to_bytes(2,'big')+bytes(c['seed'])+
          c['mode'].to_bytes(2,'big')+bytes.fromhex(c['expected'])+bytes(c['expected_seed'])+c['removed'].to_bytes(2,'big'))
    assert len(data)==78
    lines.append('        dc.b '+','.join(f'${v:02x}' for v in data))
(ROOT/'build/intro-zaco-cases.inc').write_text('\n'.join(lines)+'\n',encoding='ascii')
print(f'PASS original zacointro: {len(cases)} initializer/tick cases and exact static/12-frame models')
