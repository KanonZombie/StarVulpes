"""Execute the commercial vertex consumer, not just its matrix generator."""
from starfox_rom import rom_hex
import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
M = runpy.run_path(str(ROOT / 'tools/recover-intro-matrix.py'))
G = M['G']
ENTRY, END = 0x873f, 0x8782


def native_vertex(rom, matrix, vertex):
    # MOBJ msh_rotpoints16: columns11/21/31,12/22/32,13/23/33.
    assert rom[0x8717:0x8729].hex() == rom_hex(0x08717, 18)
    assert rom[ENTRY:ENTRY+7].hex() == rom_hex(0x0873f, 7)
    assert rom[END-2:END].hex() == rom_hex(0x08780, 2)
    g = G['TextGSU'](rom, allowed=((ENTRY, END),))
    for i, value in enumerate(matrix):
        g.word(0x120+i*2, value)
    for reg, index in ((10,0),(11,3),(13,6),(4,1),(7,4),(8,7)):
        g.r[reg] = matrix[index]
    g.r[1:4] = [v & 65535 for v in vertex]
    g.r[9] = 0x2000
    g.run(ENTRY, 100, stop_pc=END)
    return [G['signed'](g.word(0x2000+i*2)) for i in range(3)]


def check():
    rom = (ROOT / 'ref/Star Fox (USA).sfc').read_bytes()
    assert hashlib.sha256(rom).hexdigest() == G['ROM_SHA256']
    cases = json.loads((ROOT / 'build/intro-matrix-origin.json').read_text())['cases']
    tested = 0
    rejected_old = 0
    for case in cases:
        matrix = M['original'](rom, case['angles'])
        signed = list(map(G['signed'], matrix))
        for vertex in ((64,0,0),(0,64,0),(0,0,64)):
            native = native_vertex(rom, matrix, vertex)
            column = [sum(vertex[j]*signed[j*3+i] for j in range(3)) >> 15 for i in range(3)]
            old = [sum(vertex[j]*signed[i*3+j] for j in range(3)) >> 15 for i in range(3)]
            assert column == native, (case['angles'], vertex, column, native)
            rejected_old += old != native
            tested += 1
    assert rejected_old > 0
    report = dict(check='PASS', original_rom_sha256=G['ROM_SHA256'],
                  consumer_start=ENTRY, consumer_end=END,
                  consumer_hex=rom[ENTRY:END].hex(),
                  matrix_load_start=0x8717, matrix_load_hex=rom[0x8717:0x8729].hex(),
                  poses=len(cases), native_basis_vectors=tested,
                  rejected_previous_row_consumption=rejected_old,
                  contract='Native matrix stays transposed; vertices consume columns. Basis vectors isolate orientation from per-product rounding. MD accumulated Q15 precision policy unchanged.')
    (ROOT / 'evidence/m4-orientation-origin.json').write_text(json.dumps(report, indent=2)+'\n')
    print(f'PASS native vertex consumer: {tested} vectors; old row use fails {rejected_old}')
    return report


if __name__ == '__main__':
    check()

