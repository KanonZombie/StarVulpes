"""Bounded boss geometry fixtures: commercial model bytes and executed GSU matrix.

Poses are arithmetic test inputs, not reconstructed game trajectories.
The visibility/projection oracle is the documented destination visual contract.
"""
import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
rom = (ROOT / 'ref/Star Fox (USA).sfc').read_bytes()
recover = runpy.run_path(str(ROOT / 'tools/recover-intro-model.py'))['recover']
original = runpy.run_path(str(ROOT / 'tools/recover-intro-matrix.py'))['original']

def signed(v):
    return ((v + 32768) & 65535) - 32768

def trunc(a, b):
    return (-1 if a < 0 else 1) * (abs(a) // b)

cases = []
lines = ['; Model bytes from selected ROM; matrix from execution of original GSU.',
         '; Test poses are numeric fixtures, not original scene states.',
         'M4_BOSS_GEO_CASES equ 9', 'M4BossGeometryCases:']
for model_id, address in enumerate((0x6644, 0x6628, 0x48a0), 5):
    model = recover(rom, address)
    for translation, angles in [((0, -800, 2000), (0, 0, 0)),
                                ((-400, -300, 6000), (16, 32, 64)),
                                ((400, -800, -6000), (255, 128, 250))]:
        matrix = original(rom, angles)
        vertices = [[signed((sum(v[j] * signed(matrix[j*3+a]) for j in range(3)) >> 15)
                            + translation[a]) for a in range(3)] for v in model['vertices']]
        assert all(-16384 <= value < 16384 for v in vertices for value in v)
        records = []
        for x, y, z in vertices:
            projected = [128 + trunc(x*256, z), 112 + trunc(y*256, z)] if z >= 32 else [0, 0]
            assert all(-32768 <= p <= 32767 for p in projected)
            records += [x, y, z, *projected]
        visibility, normals, dots = [], [], []
        for indices in model['visibility']:
            p, q, r = [vertices[i] for i in indices]
            u, v = [[signed(b-a) for a, b in zip(p, other)] for other in (q, r)]
            n = [u[(a+1)%3]*v[(a+2)%3] - u[(a+2)%3]*v[(a+1)%3] for a in range(3)]
            dot = sum(a*b for a, b in zip(n, p))
            assert all(-(1 << 30) <= value < (1 << 30) for value in n)
            assert -(1 << 47) <= dot < (1 << 47)
            normals += n
            dots.append(dot)
            visibility.append(int(dot < 0))
        header = matrix + [len(vertices), len(visibility), int(any(v[2] >= 32 for v in vertices))] + [0]*4
        case = dict(model_id=model_id, header_offset=address, translation=translation, angles=angles,
                    vertex_count=len(vertices), visibility_count=len(visibility),
                    max_abs_normal=max(map(abs, normals)), max_abs_dot=max(map(abs, dots)))
        cases.append(case)
        # Input9WORDs, expected header16, records5*N, flagsV; no unused-padding oracle.
        for values in ([model_id, 0, 0, *translation, *angles], header, records, visibility):
            for start in range(0, len(values), 12):
                lines.append('        dc.w ' + ','.join(f'${v & 65535:04x}' for v in values[start:start+12]))
(ROOT / 'build/intro-boss-geometry-cases.inc').write_text('\n'.join(lines)+'\n', encoding='ascii')
(ROOT / 'build/intro-boss-geometry-origin.json').write_text(json.dumps(dict(
    rom_sha256=hashlib.sha256(rom).hexdigest(), matrix_unit_offset=0x829f, cases=cases,
    contract='WORD translation and Q15 floor; signed32 normals, signed48 dot; projection truncates toward zero. Destination geometry oracle, not proof of original GSU visibility equivalence.'), indent=2)+'\n', encoding='utf-8')
print('Generated9 boss geometry fixtures:64/28/35 vertices and signed48 visibility')
