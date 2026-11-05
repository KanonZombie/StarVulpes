"""Bounded original-ROM weapon math. No recorded poses drive the target ROM."""
from starfox_rom import rom_hex
from pathlib import Path
import hashlib
import json
import runpy

ROOT = Path(__file__).resolve().parents[1]
FONT = runpy.run_path(str(ROOT/'tools/recover-intro-font.py'))
SHA = FONT['ROM_SHA256']
CAMERA = runpy.run_path(str(ROOT/'tools/recover-intro-camera.py'))


def signed(v):
    return (v & 65535) - (65536 if v & 32768 else 0)


def original_atan(rom, x, y):
    cpu = FONT['TextGSU'](rom, allowed=((0x8183,0x824b),(0x9263,0x94ba)))
    cpu.word(0x62,x); cpu.word(0x2c,y)
    cpu.run(0x81aa)
    return cpu.word(0x40)


def atan(rom, x, y):
    """GSU81BE: unsigned ratio, original 256-WORD table, WORD quadrants."""
    x,y = signed(x),signed(y)
    ax,ay = abs(x),abs(y)
    assert ax < 32768 and ay < 32768
    if not ay:
        angle = 0x4000
    elif ax == ay:
        angle = 0x2000
    else:
        q = min(ax,ay)*16384//max(ax,ay)
        index = (q>>5)&~1
        angle = int.from_bytes(rom[0x244b+index:0x244d+index],'little')
        if ay < ax: angle = 0x4000-angle
    if (x < 0) != (y < 0): angle = -angle
    if y < 0: angle += 0x8000
    return angle&65535


class Math65816:
    """Only recovered gen_weapon/rotate/aim units and their math consumers.

    Does not emulate a console. CPU multiply uses original hardware registers;
    arctan's JSL executes the selected ROM's GSU unit, not Python atan.
    """
    def __init__(self,rom,extra_ranges=(),hooks=None):
        self.rom,self.ram = rom,{}
        self.visited=set()
        self.extra_ranges=extra_ranges
        self.hooks=hooks or {}
    def get(self,a,n):
        if a>>16==0x7e:a&=65535
        if a >= 0x8000:
            physical = (a>>16)*32768+(a&32767)
            return int.from_bytes(self.rom[physical:physical+n],'little')
        return sum(self.ram.get(a+i,0)<<(8*i) for i in range(n))
    def put(self,a,v,n=2):
        if a>>16==0x7e:a&=65535
        for i in range(n): self.ram[a+i]=(v>>(8*i))&255
        if a==0x4203:
            self.put(0x4216,self.get(0x4202,1)*self.get(0x4203,1))
    def run(self,pc,x=0x336,y=0x444,a=0):
        width,iw,carry,zero,negative = 8,16,False,False,False
        stack,calls=[],[]
        def flags(v,bits=None):
            nonlocal zero,negative
            bits=bits or width
            zero=(v&((1<<bits)-1))==0; negative=bool(v&(1<<(bits-1)))
        for _ in range(10000):
            if pc in self.hooks:
                x,y,a,width,carry=self.hooks[pc](self,x,y,a,width,carry)
                flags(a)
                if not calls:return a&((1<<width)-1)
                pc=calls.pop()
                continue
            if pc==0xfc41e:
                v=CAMERA['original_vector'](self.rom,self.get(0x7e,1),self.get(0x15a8,1),self.get(0x15a9,1))
                for addr,value in zip((2,8,0x90),v):self.put(addr,value)
                width=8;pc=calls.pop();continue
            if pc==0x17ce3:
                a=original_atan(self.rom,self.get(2,2),self.get(8,2))
                width=16; flags(a); pc=calls.pop(); continue
            assert (0x33552<=pc<0x33745 or 0x31e5c<=pc<0x31ef4 or 0x3101a<=pc<0x3110a or
                    0xfc900<=pc<0xfd000 or 0xfd05c<=pc<0xfd11e or 0xfd5bc<=pc<0xfd5d5 or
                    0xfc7bb<=pc<0xfc7e0 or 0xfdb01<=pc<0xfdb30 or 0xfdc69<=pc<0xfdcbb or
                    any(a<=pc<b for a,b in self.extra_ranges)),hex(pc)
            self.visited.add(pc)
            op=self.rom[pc];pc+=1
            n,mask=width//8,(1<<width)-1
            if op in (0xc2,0xe2):
                bits=self.rom[pc];pc+=1
                if bits&32: width=16 if op==0xc2 else 8
                if bits&16: iw=16 if op==0xc2 else 8
            elif op in (0xa9,0x29,0x09,0x49,0x89,0xc9,0x69,0xe9):
                v=int.from_bytes(self.rom[pc:pc+n],'little');pc+=n
                if op==0xa9: a=(a&~mask)|v
                elif op==0x29: a=(a&~mask)|(a&v&mask)
                elif op==0x09: a|=v
                elif op==0x49: a^=v
                elif op==0x89: zero=(a&v&mask)==0;continue
                elif op==0xc9: carry=(a&mask)>=v;flags(a-v);continue
                else:
                    v=(a&mask)+v+carry if op==0x69 else (a&mask)-v-(not carry)
                    carry=v>mask if op==0x69 else v>=0
                    a=(a&~mask)|(v&mask)
                flags(a)
            elif op in (0xa2,0xa0,0xc0):
                v=int.from_bytes(self.rom[pc:pc+iw//8],'little');pc+=iw//8
                if op==0xa2:x=v
                elif op==0xa0:y=v
                else:carry=y>=v;flags(y-v,iw);continue
                flags(v,iw)
            elif op in (0xb5,0xbd,0xb9,0xa5,0xad,0xbf,0x95,0x99,0x9d,0x9f,0x85,0x8d,0x64,0x74,0x9c,0x86,0x84,0x96,0x94,0xa6,0xae,0xac,0xbc,0xb4,0xa4,0x65,0x6d,0x75,0xe5,0xed,0xf5,0xc5,0xcd,0xd6,0x8c,0xd5,0xd9,0xdd):
                length=3 if op in (0xbf,0x9f) else 2 if op in (0xbd,0xb9,0xad,0x99,0x9d,0x8d,0x9c,0x6d,0xed,0xcd,0xae,0xac,0xbc,0x8c,0xd9,0xdd) else 1
                addr=int.from_bytes(self.rom[pc:pc+length],'little');pc+=length
                if op in (0xb5,0xbd,0xbf,0x95,0x9d,0x9f,0x75,0xf5,0x94,0xd6,0xbc,0x74,0xb4,0xd5,0xdd):addr+=x
                if op in (0xb9,0x99,0x96,0xd9):addr+=y
                if op in (0x95,0x99,0x9d,0x9f,0x85,0x8d):self.put(addr,a,n)
                elif op==0xd6:v=(self.get(addr,n)-1)&mask;self.put(addr,v,n);flags(v)
                elif op in (0x64,0x74,0x9c):self.put(addr,0,n)
                elif op in (0x86,0x84,0x96,0x94,0x8c):self.put(addr,x if op in (0x86,0x96) else y,iw//8)
                elif op in (0xa6,0xae,0xac,0xa4,0xbc,0xb4):
                    v=self.get(addr,iw//8)
                    if op in (0xa6,0xae):x=v
                    else:y=v
                    flags(v,iw)
                else:
                    v=self.get(addr,n)
                    if op in (0xc5,0xcd,0xd5,0xd9,0xdd):carry=(a&mask)>=v;flags(a-v);continue
                    if op in (0x65,0x6d,0x75,0xe5,0xed,0xf5):
                        add=op in (0x65,0x6d,0x75)
                        v=(a&mask)+v+carry if add else (a&mask)-v-(not carry)
                        carry=v>mask if add else v>=0
                    a=(a&~mask)|(v&mask);flags(a)
            elif op in (0x10,0x30,0xd0,0xf0,0x80,0x90,0xb0):
                v=int.from_bytes(self.rom[pc:pc+1],'little',signed=True);pc+=1
                if op==0x80 or {0x10:not negative,0x30:negative,0xd0:not zero,0xf0:zero,0x90:not carry,0xb0:carry}.get(op):pc+=v
            elif op in (0x22,0x20):
                size=3 if op==0x22 else 2
                v=int.from_bytes(self.rom[pc:pc+size],'little');pc+=size
                calls.append(pc)
                pc=(v>>16)*32768+(v&32767) if op==0x22 else (pc&~32767)|(v&32767)
            elif op==0x4c:
                pc=(pc&~32767)|(int.from_bytes(self.rom[pc:pc+2],'little')&32767)
            elif op==0x5c:
                v=int.from_bytes(self.rom[pc:pc+3],'little');pc=(v>>16)*32768+(v&32767)
            elif op==0x82:
                v=int.from_bytes(self.rom[pc:pc+2],'little',signed=True);pc+=2+v
            elif op in (0x60,0x6b):
                if not calls:return a&mask
                pc=calls.pop()
            elif op in (0xda,0x5a,0x48,0x08,0x8b):
                stack.append(x if op==0xda else y if op==0x5a else a&mask if op==0x48 else (width,iw,carry,zero,negative) if op==0x08 else 0)
            elif op in (0xfa,0x7a,0x68,0x28,0xab):
                v=stack.pop()
                if op==0xfa:x=v;flags(x,iw)
                elif op==0x7a:y=v;flags(y,iw)
                elif op==0x68:a=(a&~mask)|v;flags(a)
                elif op==0x28:width,iw,carry,zero,negative=v
            elif op in (0xaa,0xa8,0xbb,0x9b,0x8a,0x98):
                if op==0xaa:x=a&((1<<iw)-1);flags(x,iw)
                elif op==0xa8:y=a&((1<<iw)-1);flags(y,iw)
                elif op==0xbb:x=y;flags(x,iw)
                elif op==0x9b:y=x;flags(y,iw)
                else:a=(a&~mask)|((x if op==0x8a else y)&mask);flags(a)
            elif op in (0x18,0x38):carry=op==0x38
            elif op in (0x0a,0x4a,0x6a,0x1a,0x3a):
                v=a&mask
                if op==0x0a:carry=bool(v&(1<<(width-1)));v<<=1
                elif op==0x4a:carry=bool(v&1);v>>=1
                elif op==0x6a:v,carry=(v>>1)|(int(carry)<<(width-1)),bool(v&1)
                else:v+=1 if op==0x1a else -1
                a=(a&~mask)|(v&mask);flags(a)
            elif op==0xeb:a=((a&255)<<8)|((a>>8)&255);flags(a,8)
            elif op==0x46:
                address=self.rom[pc];pc+=1
                value=self.get(address,n);carry=bool(value&1);value>>=1
                self.put(address,value,n);flags(value)
            elif op in (0xe8,0xca,0xc8,0x88):
                if op in (0xe8,0xca):x=(x+(1 if op==0xe8 else -1))&((1<<iw)-1);flags(x,iw)
                else:y=(y+(1 if op==0xc8 else -1))&((1<<iw)-1);flags(y,iw)
            elif op==0xea:pass
            else:raise AssertionError((hex(pc-1),hex(op)))
        raise AssertionError('Weapon math exceeded bound')


def original_shot(rom,parent,target,offset):
    cpu=Math65816(rom)
    x,y,t=0x336,0x444,0x47a
    for p,xyz in ((x,parent),(t,target)):
        for i,v in enumerate(xyz):cpu.put(p+12+i*2,v)
    for a,v in ((0x1547,offset),(0x1549,0),(0x154b,20)):cpu.put(a,v,1)
    cpu.put(0x154f,t)
    cpu.run(0x33552,x,y)
    xyz=[cpu.get(y+12+i*2,2) for i in range(3)]
    angles=[cpu.get(y+18+i,1) for i in range(3)]
    return xyz,angles,cpu


def shot(rom,parent,target,offset):
    # Original three BYTE rotations with zero parent angles. Roll and yaw
    # truncate offsetX twice; pitch and yaw truncate offsetZ twice. Scale2.
    def mul(v):return (-1 if v<0 else 1)*(abs(v)*127//128)
    xyz=[(parent[0]+mul(mul(offset))*4)&65535,parent[1]&65535,(parent[2]+mul(mul(20))*4)&65535]
    dx,dy,dz=[signed(t-p) for t,p in zip(target,xyz)]
    assert abs(dx)+abs(dz)<32768 and abs(dy)<32768
    pitch=atan(rom,dy,abs(dx)+abs(dz))>>8
    yaw=(-(atan(rom,dx,dz)>>8))&255
    return xyz,[pitch,yaw,0]


def original_laser(rom,xyz,angles,updates=1,shooter_speed=0):
    cpu=Math65816(rom);x=0x336
    for i,v in enumerate(xyz):cpu.put(x+12+i*2,v)
    for i,v in enumerate(angles):cpu.put(x+18+i,v,1)
    cpu.put(x+34,angles[0],1);cpu.put(x+35,angles[1],1)
    cpu.put(x+21,90,1);cpu.put(x+10,60,1);cpu.put(x+36,shooter_speed,1)  # 06:B658 copies shooter $15
    cpu.put(0x14f6,63)
    states=[]
    for index in range(updates):
        cpu.run(0x31e5c if not index else 0x31eb6,x,0x444)
        states.append(dict(xyz=[cpu.get(x+12+i*2,2) for i in range(3)],
            velocity=[cpu.get(x+47+i*2,2) for i in range(3)],angles=angles[:],
            life=cpu.get(x+10,1),anim=cpu.get(x+0x1ce7,1)&127))
    return states,cpu


class OriginalLaser:
    def __init__(self,rom,xyz,angles,native,birth):
        states,self.cpu=original_laser(rom,xyz,angles)
        self.native,self.birth,self.angles=native,birth,angles[:]
    def state(self):
        x=0x336;c=self.cpu
        return dict(xyz=[c.get(x+12+i*2,2) for i in range(3)],
            velocity=[c.get(x+47+i*2,2) for i in range(3)],angles=self.angles[:],
            life=c.get(x+10,1),anim=c.get(x+0x1ce7,1)&127,native=self.native,birth=self.birth,alive=True)
    def tick(self):
        self.cpu.run(0x31eb6)
        return self.state()


def pack_laser(state):
    data=bytearray(32)
    for i,v in enumerate(state['xyz']+state['velocity']):data[i*2:i*2+2]=v.to_bytes(2,'big')
    data[12:15]=bytes(state['angles']);data[15]=90;data[18]=state['anim'];data[19]=state['life'];data[21]=3
    for at,v in ((22,1),(24,state['native']),(26,state['birth']),(28,0x660),(30,2)):data[at:at+2]=v.to_bytes(2,'big')
    return bytes(data)


def check_observed(rom,states):
    path=ROOT/'evidence/starfox-intro-fire.json'
    observed=json.loads(path.read_text(encoding='utf-8'))
    assert observed['rom_sha256']==hashlib.sha256(rom).hexdigest()
    matched=[]
    flash_births=[]
    for frame in range(76,102):
        expected={w['native']:w for w in states[frame]['weapons']}
        for sample in (s for s in observed['samples'] if s['frame']==frame):
            actual={o['pointer']:o for o in sample['objects'] if o['shape']==0xb34d}
            if actual.keys()!=expected.keys():continue
            if all(all(o[k]==expected[p][k] for k in ('xyz','velocity','angles','life')) and
                   (bytes.fromhex(o['extra'])[13]&127)==expected[p]['anim'] for p,o in actual.items()):
                matched.append(dict(frame=frame,vblank=sample['vblank'],lasers=len(actual)));break
        assert matched and matched[-1]['frame']==frame,('No original full laser-state observation',frame)
        if frame in range(76,101,4):
            expected_flashes={identity:states[frame]['flashes'][i*32:(i+1)*32] for i,identity in enumerate(states[frame]['flash_ids'])}
            for sample in (s for s in observed['samples'] if s['frame']==frame):
                actual={o['pointer']:o for o in sample['objects'] if o['shape']==0xb091}
                if actual.keys()!=expected_flashes.keys():continue
                if all(o['xyz']==[int.from_bytes(expected_flashes[p][i:i+2],'big') for i in (0,2,4)] and o['angles']==[0,128,0] for p,o in actual.items()):
                    flash_births.append(dict(frame=frame,vblank=sample['vblank'],identities=sorted(actual)));break
            assert flash_births and flash_births[-1]['frame']==frame,('No original flash-birth observation',frame)
    return dict(path=path.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
        emulator=observed['emulator'],matched=matched,flash_births=flash_births,
        scope='All active source laser IDs, XYZ, velocity, angles, life and model animation match native routine execution76..101. Samples selected by complete laser state, not gameframe alone.')


def laser_model(rom):
    header=rom[0x334d:0x3369]
    assert header.hex()==rom_hex(0x0334d, 28)
    p=0x8eeba
    assert rom[p:p+2]==bytes((28,9))
    frames=[]
    for i in range(9):
        field=p+2+i*2
        start=field+1+int.from_bytes(rom[field:field+2],'little',signed=True)
        assert rom[start:start+2]==bytes((4,6)) and rom[start+20]==12
        frames.append([[FONT['signed'](b,8)<<2 for b in rom[start+2+j*3:start+5+j*3]] for j in range(6)])
    p=0x8ef9a
    assert rom[p:p+2]==bytes((48,6))
    visibility=[list(rom[p+2+i*3:p+5+i*3]) for i in range(6)]
    p+=20
    assert rom[p]==20;p+=1
    faces=[]
    for i in range(6):
        assert rom[p:p+3]==bytes((4,i,0))
        faces.append(dict(count=4,visibility=i,material=0,vertices=list(rom[p+6:p+10])))
        p+=10
    assert rom[p:p+2]==bytes((254,0))
    assert rom[0x1853e:0x18540]==bytes.fromhex(rom_hex(0x1853e, 2))
    assert rom[0x18806:0x1880f]==bytes.fromhex(rom_hex(0x18806, 9))
    return dict(frames=frames,vertices=frames[0],visibility=visibility,groups=[dict(faces=faces)],
                bsp=[],header_offset=0x334d,points_offset=0x8eeba,faces_offset=0x8ef9a,
                material_offset=0x1853e,colour_animation_offset=0x18806,colour_indices=[14,3,14,4])


def main():
    rom=(ROOT/'ref/Star Fox (USA).sfc').read_bytes()
    assert hashlib.sha256(rom).hexdigest()==SHA
    dispatch=0xfd17c+14*3
    assert rom[dispatch:dispatch+3]==bytes.fromhex(rom_hex(0xfd1a6, 3))
    assert rom[0x32f61:0x32f6a]==bytes.fromhex(rom_hex(0x32e61, 9))
    for x,y in [(0,0),(0,800),(50,800),(-50,800),(800,50),(50,-800),(-50,-800),(300,720)]:
        native=original_atan(rom,x,y)
        assert atan(rom,x,y)==native,(x,y,hex(native),hex(atan(rom,x,y)))
    for offset in (-50,50):
        xyz,angles,cpu=original_shot(rom,[0,-400,3962],[50,-97,4722],offset)
        print('First shot math',offset,[signed(v) for v in xyz],angles,len(cpu.visited))
        assert (xyz,angles)==shot(rom,[0,-400,3962],[50,-97,4722],offset)
        xyz[0]=(xyz[0]+(-350 if offset<0 else 350))&65535
        states,cpu=original_laser(rom,xyz,angles,3)
        print('Laser native',states)
    import random
    randomizer=random.Random(0x38c18)
    atan_cases=[(x,y) for x in (-16000,-1024,-1,0,1,1024,16000) for y in (-16000,-1024,-1,0,1,1024,16000)]
    atan_cases += [(randomizer.randrange(-16000,16001),randomizer.randrange(-16000,16001)) for _ in range(79)]
    for x,y in atan_cases:assert atan(rom,x,y)==original_atan(rom,x,y),(x,y)
    shot_cases=[]
    for i in range(32):
        parent=[0,-400,3962+i*63]
        target=[randomizer.randrange(-900,901),randomizer.randrange(-1000,1201),parent[2]+randomizer.randrange(100,8001)]
        offset=-50 if i&1 else 50
        xyz,angles,_=original_shot(rom,parent,target,offset)
        assert (xyz,angles)==shot(rom,parent,target,offset)
        shot_cases.append([*parent,*target,offset,*map(signed,xyz),angles[0],angles[1]])
    model=laser_model(rom)
    build=ROOT/'build'
    (build/'intro-weapon-atan.bin').write_bytes(b''.join(int.from_bytes(rom[a:a+2],'little').to_bytes(2,'big') for a in range(0x244b,0x264b,2)))
    lines=[f'M4_WEAPON_ATAN_CASES equ {len(atan_cases)}','M4IntroWeaponAtanCases:']
    lines += ['        dc.w '+','.join(map(str,(x,y,original_atan(rom,x,y)))) for x,y in atan_cases]
    lines += [f'M4_WEAPON_SHOT_CASES equ {len(shot_cases)}','M4IntroWeaponShotCases:']
    lines += ['        dc.w '+','.join(map(str,case)) for case in shot_cases]
    lines += ['M4IntroLaserFrames:']+[f'        dc.l M4IntroLaserFrame{i}' for i in range(9)]
    for i,frame in enumerate(model['frames']):
        lines += [f'M4IntroLaserFrame{i}:']+['        dc.w '+','.join(map(str,v)) for v in frame]
    lines += ['M4IntroLaserVisibility:']+['        dc.w '+','.join(str(v*6) for v in triple) for triple in model['visibility']]
    lines += ['M4IntroLaserFaces:']+['        dc.w '+','.join(map(str,[f['count'],f['visibility'],0,*[v*6 for v in f['vertices']]])) for f in model['groups'][0]['faces']]
    (build/'intro-weapons.inc').write_text('\n'.join(lines)+'\n',encoding='ascii')
    blocks={'weapon14_factory':(0x32f61,0x32fe7),'gen_weapon':(0x33552,0x33662),'laser_init_tick':(0x31e5c,0x31ef4),'first_controller':(0x38be6,0x38ca3),
        'atan_gsu':(0x81aa,0x823e),'atan_table':(0x244b,0x264b),'absolute_pitch_yaw':(0xfd05c,0xfd0ab),
        'manhattan_distance':(0xfcf92,0xfcfc0),'behind_policy':(0x174fc,0x1758c),'flash_init_tick':(0x336e6,0x33745)}
    report=dict(rom_sha256=SHA,atan_cases=len(atan_cases),shot_cases=len(shot_cases),model=model,
        blocks={name:dict(offset=a,end=b,bytes=rom[a:b].hex()) for name,(a,b) in blocks.items()},
        scope='Intro controller has zero angles/speed. Native BYTE offset rotations, scale2, Manhattan aim, original GSU atan table. Laser scale1, animation0/2/4, life60. Flash birth behind view with zmax32 and no first-frame exemption: native alienflags discards it in the same completed update. Fixed MD material index14; colour cycling and audio pending.')
    (build/'intro-weapons-origin.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('PASS original GSU atan',len(atan_cases),'and original gen_weapon',len(shot_cases),'cases; laser model9 frames/6 faces')


if __name__=='__main__':main()
