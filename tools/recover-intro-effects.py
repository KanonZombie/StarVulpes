"""Selected-ROM RNG and bounded first explosion/smoke consumers/resources.

No captured poses are build inputs. Observations independently check recovered
states; billboard textures remain a documented visual adaptation for this batch.
"""
from starfox_rom import rom_hex
from pathlib import Path
import hashlib
import json
import runpy
ROOT=Path(__file__).resolve().parents[1]
SHIP=runpy.run_path(str(ROOT/'tools/recover-intro-ships.py'))
SHA=SHIP['SHA']

def original_random(rom,seed):
    # Execute exactly the selected-ROM routine; only its four DP bytes exist.
    pc=0x17c4e;a=0;carry=False;ram=dict(zip(range(0xef,0xf3),seed))
    for _ in range(20):
        op=rom[pc];pc+=1
        if op==0x60:return [ram[i] for i in range(0xef,0xf3)],a
        if op==0x18:carry=False;continue
        at=rom[pc];pc+=1
        if op==0xa5:a=ram[at]
        elif op==0x85:ram[at]=a
        elif op==0xe5:
            value=a-ram[at]-(not carry);carry=value>=0;a=value&255
        else:raise AssertionError((hex(pc-2),hex(op)))
    raise AssertionError('RNG exceeded bound')

def random(seed):
    seed=seed[:];a=seed[0];borrow=1
    for i in [1,2,3,0]:
        value=a-seed[i]-borrow;borrow=int(value<0);a=value&255;seed[i]=a
    return seed,a

def model(rom,header):
    h=rom[header:header+28];bank=h[2]&127
    p=bank*32768+(int.from_bytes(h[:2],'little')&32767)
    f=bank*32768+(int.from_bytes(h[3:5],'little')&32767)
    assert rom[p]==4
    vertices=[[SHIP['signed'](b)<<h[7] for b in rom[p+2+i*3:p+5+i*3]] for i in range(rom[p+1])]
    assert rom[p+2+len(vertices)*3]==12
    assert rom[f]==48
    vis=[list(rom[f+2+i*3:f+5+i*3]) for i in range(rom[f+1])]
    q=f+2+len(vis)*3
    faces=[]
    if header in (0x3e04,0x3e20,0x3587):
        assert rom[q]==20;q+=1
        for i in range(len(vis)):
            n,v,m=rom[q:q+3];assert n in [3,4]
            faces.append(dict(count=n,visibility=255,material=m,normal=[SHIP['signed'](b) for b in rom[q+3:q+6]],vertices=list(rom[q+6:q+6+n])))
            q+=6+n
    else:
        # Sprite ADD5 uses Sprite4 opcode50, B11D uses textured Face4.
        # Muzzle flashes B075/B091/B0AD share the smoke billboard at shifts4/3/2.
        # Level: explosion B101/explosion4 B155 (same points, shifts 3/6),
        # bouncyball AEED, spark B2A5 and nova bomb AF41 (Sprite opcode50).
        assert header in [0x2dd5,0x311d,0x3139,0x3075,0x3091,0x30ad,0x3101,0x3155,0x2eed,0x32a5,0x2f41]
        faces=[dict(count=4,visibility=255,material=0,vertices=[2,3,0,1],normal=[0,0,127])]
    return dict(header_offset=header,header=h.hex(),points_offset=p,faces_offset=f,
        vertices=vertices,visibility=vis,groups=[dict(faces=faces)],bsp=[],effect=True,
        colour=4 if header in (0x3e04,0x3e20,0x3587) else 8 if header in (0x311d,0x3139,0x3101,0x3155) else 11,
        polygon_explosion=header in (0x3e04,0x3e20,0x3587))

class Effects:
    def __init__(self,rom,pool):
        self.rom,self.pool=rom,pool;self.seed=[0x3a,0xa7,0x55,0x7f]
        for _ in range(4):self.rng()
        self.actors=[];self.medium=False
    def rng(self):self.seed,a=original_random(self.rom,self.seed);return a
    def make(self,xyz,kind,frame,native=True):
        return dict(xyz=xyz[:],velocity=[0,0,0],angles=[0,0,0],anim=0,life=0,kind=kind,
            alive=True,native=self.pool.allocate() if native else 0,birth=frame,limit=0,timer=0,growth=0)
    def birth(self,ship,frame):
        a=self.make(ship.state()['xyz'],4,frame);a['limit']=12
        self.actors=[a,self.make(a['xyz'],5,frame,native=False)];self.medium=True
    def smoke(self,ship,frame,offsets=True):
        a=self.make(ship.state()['xyz'],6,frame);a['velocity']=[40,0,0];a['angles']=[0,128,0]
        a['timer']=20;a['growth']=6
        if offsets:a['xyz']=[(p+(self.rng()&127)-63)&65535 for p in a['xyz']]
        self.actors.append(a)
    def callback(self,ship,pc,frame):
        if pc==0x36eee:
            self.birth(ship,frame);ship.y=self.actors[0]['native']
        elif pc==0x30ea8:
            self.smoke(ship,frame,offsets=False);ship.y=self.actors[-1]['native']
            for i,v in enumerate(self.actors[-1]['xyz']):ship.put(ship.y+12+i*2,v,2)
        else:raise AssertionError(hex(pc))
    def step(self,frame,delta):
        # Ship's original routine already wrote masked offsets to the last
        # smoke through native Y. Callback handles only allocation, not RNG.
        for a in reversed(self.actors[2:]):
            if not a['alive']:continue
            a['anim']=(a['anim']+1)&7
            if not a['anim']:self.remove(a);continue
            a['xyz'][0]=(a['xyz'][0]-1)&65535
            a['xyz'][1]=(a['xyz'][1]-a['growth'])&65535
            a['timer']=(a['timer']-1)&255
            if not a['timer']:
                a['timer']=20;a['growth']=(a['growth']-1)&65535
                if not a['growth']:self.remove(a);continue
            a['xyz']=[(p+v)&65535 for p,v in zip(a['xyz'],a['velocity'])]
        if not self.actors:return
        if self.medium:
            a,b=self.actors[:2];a['angles']=[self.rng(),self.rng(),0]
            b.update(xyz=a['xyz'][:],angles=[0,128,0],native=self.pool.allocate(),limit=6)
            self.medium=False
        else:self.explosion(self.actors[0],delta)
        self.explosion(self.actors[1],delta)
    def explosion(self,a,delta):
        if not a['alive']:return
        a['anim']=(a['anim']+1)&7;a['life']=(a['life']+1)&255
        a['xyz']=[(p+v+(delta if i==2 else 0))&65535 for i,(p,v) in enumerate(zip(a['xyz'],a['velocity']))]
        if a['life']>=a['limit']:self.remove(a)
    def remove(self,a):a['alive']=False;self.pool.remove(a['native'])

def pack(a):
    data=bytearray(32)
    for i,v in enumerate(a['xyz']+a['velocity']):data[i*2:i*2+2]=v.to_bytes(2,'big')
    data[12:15]=bytes(a['angles']);data[18]=a['anim'];data[19]=a['life'];data[21]=a['kind']
    for at,key in [(22,'alive'),(24,'native'),(26,'birth'),(30,'growth')]:data[at:at+2]=int(a[key]).to_bytes(2,'big')
    data[28]=a['limit'];data[29]=a['timer'];return bytes(data)

def check_observed(rom,states):
    source=ROOT/'evidence/starfox-intro-effects.json'
    observed=json.loads(source.read_text());assert observed['rom_sha256']==SHA
    checks=[]
    for frame in range(102,107):
        state=states[frame];matches=[]
        for sample in observed['samples']:
            if sample['frame']==frame:
                if bytes(sample['rng'])!=state['rng']:continue
            elif sample['frame']==frame+1:
                if sample['rng']!=original_random(rom,list(state['rng']))[0]:continue
            else:continue
            byid={o['pointer']:o for o in sample['objects']}
            okay=True
            for a in state['effects']:
                if not a['alive']:continue
                o=byid.get(a['native'])
                if o is None or any(o[k]!=a[k] for k in ['xyz','velocity','angles','life']):okay=False;break
                if o['shape']!={4:0xbe04,5:0xb11d,6:0xadd5}[a['kind']]:okay=False;break
                raw=bytes.fromhex(o['extra'])
                if (raw[12]&127)!=a['anim']:okay=False;break
                if a['kind']==6:
                    primary=bytes.fromhex(o['raw'])
                    if primary[34]!=a['timer'] or int.from_bytes(primary[38:40],'little')!=a['growth']:okay=False;break
            third=byid.get(0x47a)
            if third is None or third['xyz']!=state['ships'][2]['xyz']:okay=False
            elif bytes.fromhex(third['raw'])[30]&32:okay=False
            if okay and sample['free_head']==state['native']['free_head']:matches.append(sample['vblank'])
        assert matches,('No complete selected-ROM effect correspondence',frame)
        checks.append(dict(frame=frame,matching_vblanks=matches,rng=list(state['rng']),effects=len(state['effects'])))
    report=dict(rom_sha256=SHA,observation_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),checks=checks,
        evidence=source.relative_to(ROOT).as_posix(),limitation='Match recovered effect/third-ship fields and free head; source VBlank samples may be after next global RNG and before third traversal. That phase requires exactly one original RNG step, never an arbitrary seed.')
    (ROOT/'evidence/m4-intro-effects-observed.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    return report

def main():
    rom=(ROOT/'ref/Star Fox (USA).sfc').read_bytes();assert hashlib.sha256(rom).hexdigest()==SHA
    assert rom[0x1b819:0x1b829].hex()==rom_hex(0x1b819, 16)
    assert rom[0x3058e:0x30593].hex()==rom_hex(0x3058e, 5)
    cases=[]
    for n in range(512):
        seed=[(n*37+i*91)&255 for i in range(4)] if n<256 else [n&255]*4
        native=original_random(rom,seed);assert random(seed)==native
        cases.append(seed+native[0])
    lines=['M4_EFFECT_RNG_CASES equ 512','M4EffectRandomCases:']
    lines+=['        dc.b '+','.join(map(str,c)) for c in cases]
    for header,name in [(0x3e04,'Explosion'),(0x311d,'ExplosionSprite'),(0x2dd5,'Smoke'),(0x3e20,'Explosion8'),(0x3139,'ExplosionSprite8'),
                        (0x3587,'Explosion4'),(0x3101,'ExplosionSprite4'),(0x3155,'ExplosionSprite16'),(0x2eed,'Ball'),(0x32a5,'Spark')]:
        m=model(rom,header)
        lines+=[f'M4Effect{name}Vertices:']+['        dc.w '+','.join(map(str,v)) for v in m['vertices']]
        lines+=[f'M4Effect{name}Faces:']
        for f in m['groups'][0]['faces']:
            vals=[f['count'],255,f['material'],*[i*6 for i in f['vertices']],*([0]*(4-f['count'])),*f['normal']]
            lines+=['        dc.w '+','.join(map(str,vals))]
    (ROOT/'build/intro-effects.inc').write_text('\n'.join(lines)+'\n',encoding='ascii')
    fragments={name:dict(offset=a,size=b-a,sha256=hashlib.sha256(rom[a:b]).hexdigest()) for name,a,b in [
        ('rng',0x17c4e,0x17c4e+20),('global_rng',0x3058e,0x30593),('ship_smoke',0x38933,0x38a52),
        ('smoke_factory_init',0x30ea8,0x31011),('medium_factory',0x36eee,0x36f48),('explosion_sprite_tick',0x377ad,0x377eb)]}
    (ROOT/'build/intro-effects-origin.json').write_text(json.dumps(dict(rom_sha256=SHA,fragments=fragments,rng_cases=512,
        models=[model(rom,h) for h in [0x3e04,0x311d,0x2dd5]],source='GSTRATS init_strats_l/smokeP; GISTRATS playerdownintro; EXPSTRAT delayexplode/explode; MOBJ mexpfacesinit',
        scope='Original first medium explosion/smoke102..106; source motion and RNG. Flat billboard material adaptation; texture masks and palette cycles pending.'),indent=2)+'\n',encoding='utf-8')
    print('PASS original RNG512; extracted three bounded original effect shapes')
if __name__=='__main__':main()
