"""Selected-ROM GSU matrix unit -> exact WORD semantics -> 68000 fixtures.

Original MOBJ negates the object's BYTE angles, shifts8, calls this unit and
transposes. No generated floating point sine, Euler replacement or pose table.
"""
from starfox_rom import rom_hex
import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
G = runpy.run_path(str(ROOT/'tools/recover-intro-font.py'))
signed = G['signed']


def original(rom, angles):
    g = G['TextGSU'](rom, allowed=((0x829f, 0x83c5),))
    g.r[9] = 0x2000
    for address, angle in zip((0x20, 0x22, 0x24), angles):
        g.word(address, (-angle << 8) & 65535)
    g.run(0x829f, 2000)
    raw = [g.word(0x2000+i*2) for i in range(9)]
    return [raw[i] for i in (0, 3, 6, 1, 4, 7, 2, 5, 8)]


def matrix(rom, angles):
    def trig(angle, cosine=False):
        index = (-angle + (64 if cosine else 0)) & 255
        return signed(int.from_bytes(rom[0x19e5+index*2:0x19e7+index*2], 'little'))
    def q(a, b):
        return signed(signed(a)*signed(b) >> 15)
    sx, sy, sz = [trig(a) for a in angles]
    cx, cy, cz = [trig(a, True) for a in angles]
    t1, t2, t3, t4 = q(cz, sy), q(cz, cy), q(sz, sy), q(sz, cy)
    raw = [q(t3, sx)+t2, q(t1, sx)-t4, q(cx, sy),
           q(cx, sz), q(cx, cz), -sx,
           q(t4, sx)-t1, q(t2, sx)+t3, q(cx, cy)]
    return [raw[i] & 65535 for i in (0, 3, 6, 1, 4, 7, 2, 5, 8)]


def recover():
    rom = (ROOT/'ref/Star Fox (USA).sfc').read_bytes()
    assert hashlib.sha256(rom).hexdigest() == G['ROM_SHA256']
    assert rom[0x829f:0x82ab].hex() == rom_hex(0x0829f, 12)
    ships = json.loads((ROOT/'build/intro-ships-origin.json').read_text())
    angles = sorted({tuple(s['angles']) for t in ships['trajectories'] for s in t['records']})
    angles += [(a, b, c) for a in (0, 16, 64, 128, 239, 255)
                         for b in (0, 64, 96, 128, 192, 255) for c in (0, 32, 128, 224)]
    angles = sorted(set(angles))
    cases = []
    for pose in angles:
        result = original(rom, pose)
        assert result == matrix(rom, pose), (pose, result, matrix(rom, pose))
        cases.append(dict(angles=list(pose), matrix=result))
    report = dict(rom_sha256=G['ROM_SHA256'], unit_offset=0x829f,
                  unit_hex=rom[0x829f:0x83b6].hex(), sine_offset=0x19e5,
                  sine_sha256=hashlib.sha256(rom[0x19e5:0x1be7]).hexdigest(),
                  cases=cases, source='SF/MARIO/MWCROT.MC mcrotmatzxy16; MOBJ.MC shape negate/transposition; MMACS.MC mgetsin16',
                  contract='Angles BYTE, original negative angle<<8. Native Q15 FMULT+ROL floor, WORD wrap. Result transposed. This is the shape rotation unit; world/view multiplication and projection are separate.')
    (ROOT/'build/intro-matrix-origin.json').write_text(json.dumps(report, indent=2)+'\n')
    table = [int.from_bytes(rom[0x19e5+i*2:0x19e7+i*2], 'little') for i in range(256)]
    (ROOT/'build/intro-matrix-sine.bin').write_bytes(b''.join(v.to_bytes(2, 'big') for v in table))
    lines = [f'M4_MATRIX_CASES equ {len(cases)}', 'M4IntroMatrixCases:']
    for case in cases:
        lines += ['        dc.w '+','.join(f'${v:04x}' for v in case['angles']+case['matrix'])]
    (ROOT/'build/intro-matrix-cases.inc').write_text('\n'.join(lines)+'\n', encoding='ascii')
    print(f'PASS original GSU matrix: {len(cases)} poses including actual intro ship angles')
    return report


if __name__ == '__main__':
    recover()
