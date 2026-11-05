"""Real ROM execution supplies the expected values for native68000 units."""
from pathlib import Path
import runpy
import json

ROOT = Path(__file__).resolve().parents[1]
rom, origin = runpy.run_path(str(ROOT / 'tools/recover-intro-later.py'))['recover']()
cases = origin['cases']
lines = ['; Generated from execution of selected original ROM fragments.']
for name, records in [('Boss', [c['input'] + c['expected'] for c in cases['boss']]),
                      ('Exit', cases['exit']), ('Title', cases['title'])]:
    lines += [f'M4_LATE_{name.upper()}_CASES equ {len(records)}', f'M4Late{name}Cases:']
    lines += ['        dc.w ' + ','.join(f'${v & 65535:04x}' for v in record) for record in records]
lines += [f'M4_LATE_PHASE_CASES equ {len(cases["phases01"])}', 'M4LatePhaseCases:']
lines += ['        dc.b ' + ','.join(str(v) for v in c['input'] + c['expected']) for c in cases['phases01']]
lines += ['M4LateAnimationCases:']
animation = runpy.run_path(str(ROOT / 'tools/recover-intro-later.py'))['animation']
for i in range(0, 256, 16):
    lines += ['        dc.b ' + ','.join(str(animation(v)) for v in range(i, i + 16))]
lines += ['        even']
(ROOT / 'build/intro-later-cases.inc').write_text('\n'.join(lines) + '\n', encoding='ascii')
print('Generated352 boss,72 exit,18 phase,16 title and256 animation target cases')

recover_model = runpy.run_path(str(ROOT / 'tools/recover-intro-model.py'))['recover']
models = [recover_model(rom, address) for address in (0x6644, 0x6628, 0x48a0,0x660c,0x6388,0x422c,0x3cd0)]
(ROOT / 'build/intro-boss-models.json').write_text(json.dumps(models, indent=2) + '\n', encoding='utf-8')

# Bounded visual frontend records: preserve commercial BSP/group/face order.
# Eight index fields permit the original six-vertex child face without splitting it on CPU.
lines = ['; Selected-ROM boss models; WORD indices and pointers adapted for68000.']
colours = {10:1, 12:10, 14:11, 16:12, 18:13, 20:14,
           0:10,21:11, 23:12, 25:13, 27:14, 28:10,30:3, 32:12,34:3, 43:4}
for index, model in enumerate(models):
    prefix = f'M4BossModel{index}'
    lines += [prefix+'BSP:']
    for node in model['bsp']:
        lines += ['        dc.w '+','.join(str(node.get(key, -1)) for key in ('op','visibility','group','left','right'))]
    lines += [prefix+'Groups:']
    lines += [f'        dc.l {prefix}Group{i}' for i in range(len(model['groups']))]
    for i, group in enumerate(model['groups']):
        lines += [f'{prefix}Group{i}:', f'        dc.w {len(group["faces"])}']
        for face in group['faces']:
            values = [face['count'],face['visibility'],face['material'],
                      *(v*6 for v in face['vertices']), *([0]*(8-face['count'])), *face['normal']]
            lines += ['        dc.w '+','.join(map(str,values))]
lines += ['M4BossModelDescriptors:']
for index, model in enumerate(models):
    lines += [f'        dc.l M4BossModel{index}BSP,M4BossModel{index}Groups',
              f'        dc.w {len(model["bsp"])}']
lines += ['M4BossMaterialColours:', '        dc.b '+','.join(str(colours.get(i,0)) for i in range(44)), '        even']
(ROOT / 'build/intro-boss-models.inc').write_text('\n'.join(lines)+'\n',encoding='ascii')
