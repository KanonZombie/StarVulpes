"""Commercial GSU type7 particle units, executed to supply target goldens.

Test poses and alternate seeds are numeric inputs, not game trajectories.
No captured RAM supplies target state or pixels.
"""
from starfox_rom import rom_hex
import hashlib
import json
from pathlib import Path
import runpy

ROOT=Path(__file__).resolve().parents[1]
rom=(ROOT/'ref/Star Fox (USA).sfc').read_bytes()
font=runpy.run_path(str(ROOT/'tools/recover-intro-font.py'))
raster=runpy.run_path(str(ROOT/'tools/generate-intro-raster-tests.py'))
assert hashlib.sha256(rom).hexdigest()==font['ROM_SHA256']
assert rom[0xd198:0xd1a4].hex()==rom_hex(0x0d198, 12)
assert rom[0xd624:0xd635].hex()==rom_hex(0x0d624, 17)
assert rom[0x16394:0x1639e].hex()==rom_hex(0x16394, 10)
assert rom[0x37870:0x3787c].hex()==rom_hex(0x37870, 12)

def words(values):
    return ['        dc.w '+','.join(f'${v&65535:04x}' for v in values[i:i+12]) for i in range(0,len(values),12)]

def expand(g,plot_count):
    result=[0x5054,1,g.word(0x1fe),plot_count,0,0,0,0]
    for i in range(300):
        at=0x1aac+i*14
        result+=list(g.ram[at:at+6])+[g.word(at+j) for j in (6,8,10,12)]
    return b''.join(v.to_bytes(2,'big') for v in result)

def native():
    cases=[]
    for seed,pose in [(0x1234,(-600,800,4096)),(0x5678,(300,-300,300)),(0xffff,(-100,-500,14000))]:
        g=font['TextGSU'](rom,allowed=((0xd198,0xd697),))
        g.word(0x1fe,seed);g.r[:4]=[7,40,0x800,60];g.r[10]=0x7000
        g.run(0xd198)
        def show_update():
            g.r[:]=[0]*16;g.r[2]=0x800;g.r[10]=0x7000;g.plots=[]
            for at,v in zip((0x26,0x28,0x2a),pose):g.word(at,v)
            g.run(0xd471)
            plots=g.plots[:]
            g.r[:]=[0]*16;g.run(0xd624)
            return plots
        previous=0
        for stage in (0,1,20,49):
            repeat=1 if not stage else stage-previous
            if stage:
                for _ in range(repeat):plots=show_update()
            else:plots=[]
            previous=stage
            pixels=bytearray(256*224)
            for x,y,colour in plots:
                assert 0<=x<224 and 0<=y<192
                if colour:pixels[(y+16)*256+x+16]=colour
            flags=28 if stage else 3
            cases.append(dict(flags=flags,seed=seed,pose=pose,stage=stage,repeat=repeat,plot_count=len(plots),
                params=[flags,7,60,40,0x800,*pose,seed,*([0]*7)],
                state=expand(g,len(plots)),plots=b''.join(v.to_bytes(2,'big') for x,y,c in plots for v in (x+16,y+16,c)),
                bitmap=raster['packed'](pixels) if stage else None))
        # Reset again, then omit the owner's show pass. Native global update
        # kills the orphaned particles and clears their unique object words.
        for flags in (3,8):
            if flags==3:
                g=font['TextGSU'](rom,allowed=((0xd198,0xd697),))
                g.word(0x1fe,seed);g.r[:4]=[7,40,0x800,60];g.r[10]=0x7000;g.run(0xd198)
            else:
                g.r=[0]*16;g.run(0xd624)
            cases.append(dict(flags=flags,seed=seed,pose=pose,stage='reset' if flags==3 else 'orphan',repeat=1,plot_count=0,
                params=[flags,7,60,40,0x800,*pose,seed,*([0]*7)],state=expand(g,0),plots=b'',bitmap=None))
    return cases

def main():
    cases=native()
    lines=['; Golden states and pixels from executed selected-ROM GSU units.',
           f'M4_PARTICLE_CASES equ {len(cases)}',f'M4_PARTICLE_JOBS equ {sum(c["repeat"] for c in cases)}','M4ParticleCases:']
    for i,c in enumerate(cases):
        lines += [f'        dc.w {c["flags"]},{c["plot_count"]}',
                  f'        dc.l M4ParticleParams{i},M4ParticleState{i},M4ParticlePlots{i}',
                  f'        dc.l '+(f'M4ParticleBitmap{i}' if c['bitmap'] is not None else '0'),
                  f'        dc.w {c["repeat"]},0']
    for i,c in enumerate(cases):
        lines += [f'M4ParticleParams{i}:']+words(c['params'])
        for name,data in [('State',c['state']),('Plots',c['plots']),('Bitmap',c['bitmap'])]:
            if data is None:continue
            lines += [f'M4Particle{name}{i}:']+words(raster['rle'](data))
    (ROOT/'build/intro-particle-cases.inc').write_text('\n'.join(lines)+'\n',encoding='ascii')
    report=dict(rom_sha256=font['ROM_SHA256'],units=dict(make=0xd198,show=0xd471,update=0xd624),
        source='SF/MARIO/MPART.MC, MDRAWLIS.MC; SF/ASM/MAIN.ASM initgame3d_l; EXPSTRAT.ASM fastparticleexplode',
        tables=dict(reciprocal_offset=0xa096c,reciprocal_words=6145,fade_offset=0xa3cbc,circle_offset=0xa3cdc),
        seed_initializer=dict(offset=0x16394,bytes=rom[0x16394:0x163a2].hex(),seed=0x1234),
        parameter_initializer=dict(offset=0x3784d,bytes=rom[0x3784d:0x37883].hex(),type=7,amount=60,life=40),
        fragments={f'{a:06x}':rom[a:b].hex() for a,b in ((0xd198,0xd471),(0xd471,0xd624),(0xd624,0xd697))},
        cases=[{k:v for k,v in c.items() if k not in ('state','plots','bitmap')} for c in cases],
        hashes=[dict(state=hashlib.sha256(c['state']).hexdigest(),plots=hashlib.sha256(c['plots']).hexdigest(),
                     bitmap=hashlib.sha256(c['bitmap']).hexdigest() if c['bitmap'] is not None else None) for c in cases],
        actual_job_count=sum(c['repeat'] for c in cases),
        scope='Three numeric seeds/poses,18 snapshots/156 jobs through49 updates plus orphan removal. Native GSU generation/projection/update; not game trajectory or scene integration proof.')
    (ROOT/'build/intro-particle-origin.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('Executed commercial GSU particles:18 cases/156 jobs, fade/expiry/orphan removal, native pixels')

if __name__=='__main__':main()
