"""Commercial FASTdebris factory execution and exact old_typP resource.

Allocator and RNG are explicit semantic consumers already recovered in this
project. Audio request is recorded without emulating SPC playback. The factory
object state is not a substitute for subsequent child strategy/draw traversal.
"""
import hashlib
import json
from pathlib import Path
import runpy

ROOT=Path(__file__).resolve().parents[1]
WEAPON=runpy.run_path(str(ROOT/'tools/recover-intro-weapons.py'))
EFFECT=runpy.run_path(str(ROOT/'tools/recover-intro-effects.py'))
MODEL=runpy.run_path(str(ROOT/'tools/recover-intro-model.py'))

def factory(rom,primary,extra,seed,player_z=7623,allocated_ids=None):
    allocated=[];events=[];seed=seed[:]
    def alloc(cpu,x,y,a,width,carry):
        address=allocated_ids[len(allocated)] if allocated_ids else 0x900+54*len(allocated)
        allocated.append(address)
        return address,y,a,width,True
    def random(cpu,x,y,a,width,carry):
        nonlocal seed
        seed,a=EFFECT['original_random'](rom,seed)
        return x,y,a,8,carry
    def sound(cpu,x,y,a,width,carry):
        events.append(dict(unit=0x1b7e5,argument=a & ((1<<width)-1)))
        return x,y,a,width,carry
    cpu=WEAPON['Math65816'](rom,extra_ranges=((0x37157,0x3784d),(0xfc000,0xfe000)),
        hooks={0xfd3a9:alloc,0x17c4a:random,0x1b7e5:sound})
    x=0x47a
    for i,v in enumerate(primary):cpu.put(x+i,v,1)
    for i,v in enumerate(extra):cpu.put(x+0x1cda+i,v,1)
    cpu.put(0x123a,0x336);cpu.put(0x346,player_z);cpu.put(0x14f6,63)
    cpu.run(0x37157,x=x)
    objects=[]
    for p in (x,*allocated):
        objects.append(dict(pointer=p,shape=cpu.get(p+4,2),xyz=[cpu.get(p+i,2) for i in (12,14,16)],
            velocity=[cpu.get(p+i,2) for i in (47,49,51)],angles=[cpu.get(p+i,1) for i in (18,19,20)],
            strategy=cpu.get(p+22,3),exp_strategy=cpu.get(p+0x1cd0,3),
            primary=bytes(cpu.get(p+i,1) for i in range(54)).hex(),
            extra=bytes(cpu.get(p+0x1cda+i,1) for i in range(32)).hex()))
    return dict(objects=objects,rng=seed,sound_events=events,executed_pcs=sorted(cpu.visited))

def main():
    rom=(ROOT/'ref/Star Fox (USA).sfc').read_bytes()
    assert hashlib.sha256(rom).hexdigest()==EFFECT['SHA']
    observation=ROOT/'evidence/starfox-intro-effects.json'
    result=None
    if observation.is_file():
        observed=json.loads(observation.read_text())
        sample=[s for s in observed['samples'] if s['frame']==121][-1]
        parent=next(o for o in sample['objects'] if o['pointer']==0x47a)
        seed,_=EFFECT['original_random'](rom,sample['rng'])
        result=factory(rom,bytes.fromhex(parent['raw']),bytes.fromhex(parent['extra']),seed)
        assert [o['shape'] for o in result['objects']]==[0xbe20,0xaca1,0xe60c,0xe60c,0xb139]
        assert [o['velocity'] for o in result['objects'][2:4]]==[[65506,13,0],[27,20,0]]
        sample122=[s for s in observed['samples'] if s['frame']==122][-1]
        native_parent=next(o for o in sample122['objects'] if o['pointer']==0x47a)
        assert all(native_parent[k]==result['objects'][0][k] for k in ('shape','xyz','velocity','angles'))
    model=MODEL['recover'](rom,0x660c)
    velocity_cases=[]
    for angle in range(256):
        cpu=WEAPON['Math65816'](rom,extra_ranges=((0xfdab8,0xfdad9),))
        cpu.put(2,angle,1);cpu.put(0x90,35,1)
        cpu.run(0xfdab8)
        velocity_cases.append([angle,35,*[cpu.get(0x336+at,2) for at in (47,49,51)]])
    lines=['; Original1F:DAB8 invokes original1F:C41E; all BYTE angles at speed35.',
           'M4_DEBRIS_VECTOR_CASES equ 256','M4DebrisVectorCases:']
    lines+=['        dc.w '+','.join(f'${v&65535:04x}' for v in c) for c in velocity_cases]
    (ROOT/'build/intro-debris-vector-cases.inc').write_text('\n'.join(lines)+'\n',encoding='ascii')
    report=dict(rom_sha256=EFFECT['SHA'],factory_entry=0x37157,result=result,model=model,
        velocity_unit=dict(offset=0xfdab8,bytes=rom[0xfdab8:0xfdad9].hex(),cases=velocity_cases),
        evidence_sha256=hashlib.sha256(observation.read_bytes()).hexdigest() if observation.is_file() else None,
        scope='Original121 reference is a research input to execution of the ROM factory, not target game/build pose data. Parent matches122; child initializers and particles/draw traversal remain separate. Source factory changes parent toBE20, allocates particle object, twoE60C fragments and B139 sprite.')
    (ROOT/'build/intro-debris-research.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('Recovered FASTdebris: model and 256 executed vector cases')

if __name__=='__main__':main()
