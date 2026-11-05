"""Recover the bounded original boss traversal107..233; no captured poses as inputs."""
from starfox_rom import rom_hex
import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
rom = (ROOT/'ref/Star Fox (USA).sfc').read_bytes()
late = runpy.run_path(str(ROOT/'tools/recover-intro-later.py'))
assert hashlib.sha256(rom).hexdigest() == late['SHA256']
camera = {s['frame']:s for s in runpy.run_path(str(ROOT/'tools/recover-intro-camera.py'))['trajectory'](rom,234)}
assert rom[0x6f924:0x6f932].hex() == rom_hex(0x6f924, 14)
assert rom[0x6f932:0x6f935].hex() == rom_hex(0x6f932, 3)
assert rom[0xfd36e:0xfd3a9].hex() == rom_hex(0xfd36e, 59)
assert rom[0xfd56f:0xfd5bb].hex().startswith(rom_hex(0xfd56f, 11))
assert rom[0x1a92d:0x1a935].hex() == rom_hex(0x1a397, 8)
state = [0, (-800)&65535, (camera[107]['cached_z']-400)&65535, 0,5,15]
scroll = 24
records=[]
for frame in range(107,234):
    ram={0x15bd:frame & 255}
    for at,value in zip((12,14,16,47,49,51),state):late['put'](ram,late['OBJ']+at,value)
    late['put'](ram,0x169e,scroll)
    late['put'](ram,0x14f6,camera[frame-1]['velocity'])
    late['execute'](rom,0x38d4e,ram)
    state=[late['get'](ram,late['OBJ']+at) for at in (12,14,16,47,49,51)]
    scroll=late['get'](ram,0x169e)
    records.append(dict(frame=frame,xyz=state[:3],velocity=state[3:],scroll=scroll,camera=camera[frame],
                        map_pointer=0x7935,map_counter=8000-(frame-107)*63))
observation=ROOT/'evidence/starfox-intro-effects.json'
matched=[]
if observation.is_file():
    observed=json.loads(observation.read_text())
    matched=[]
    for record in records:
        matches=[]
        for sample in observed['samples']:
            if sample['frame'] != record['frame'] or sample['scroll'] != record['scroll']:continue
            actors={o['shape']:o for o in sample['objects'] if o['shape'] in (0xe644,0xe628,0xc8a0)}
            if len(actors)==3 and all(o['xyz']==record['xyz'] and o['angles']==[0,0,0] for o in actors.values()):
                assert actors[0xe644]['velocity']==record['velocity']
                assert all(bytes.fromhex(o['extra'])[7:10]==bytes(3) for o in actors.values())
                matches.append(sample['vblank'])
        if matches:matched.append(dict(frame=record['frame'],vblanks=matches))
    assert [m['frame'] for m in matched] == list(range(107,141))
report=dict(rom_sha256=late['SHA256'],records=records,matched_original=matched,
            units=dict(initializer='07:8CA3..8D4D',motion='07:8D4E..8DFA',children='07:8DFB..8EC4',
                       zero_extended_vars='1F:D36E..D3A8',child_link='1F:D56F',background='03:A92D',script='13:F924..F934'),
            fragments={f'{a:06X}':rom[a:b].hex() for a,b in ((0x38ca3,0x38ec5),(0xfd36e,0xfd3a9),(0xfd54b,0xfd5bb),(0x1a92d,0x1a935),(0x6f924,0x6f935))},
            scope='Boss body motion executed from commercial ROM; zero-offset children follow parent in same traversal, observed107..140. Later records depend on unchanged playercred camera. First zaco event234 remains a separate consumer.')
(ROOT/'build/intro-boss-scene-origin.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(f'PASS boss recovery: 127 original motion updates; {len(matched)} runtime observations compared')
