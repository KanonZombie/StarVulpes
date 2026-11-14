"""Original polygon colours (GSU mdo_colour 01:904F) as resolved descriptors.

Authority: selected USA rev0 ROM. A face material index selects a WORD in the
model's colour table (header bytes18..19, bank3). The GSU decodes it:
  bit15&!bit14  animated: n=byte at p, frame WORD p+1+2*(colframe&(n-1))
  hi&$3F=$3F    fixed COLR = low byte
  hi&$3F=$3E    depth-cue: night table 03:8B8A + 32*level + low byte
  otherwise     lit: shade row WORD(03:8B2A + 24*level + 2*(hi&$3F)),
                COLR = row[s-6], s = clamp(floor(dot/1024), 6, 15)
COLR is a dither byte HL: (x^y)&1=0 uses L. Descriptors (bytes, even start):
  0,HL | 1,0,L0,L1,L2,L3 | 2,0,40 bytes (level*10+s-6) | 3,n,HL frames |
  6,n,n HL,n rows L0..L3 (animated with depth-cued frames: row colframe&(n-1)).
Textured polygon materials (bit14) use SVP texture descriptors 4/5.
Legacy billboard fallbacks retain documented approximate HL values.
"""
from starfox_rom import rom_hex
import hashlib
import json
import runpy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
rom = (ROOT / 'ref/Star Fox (USA).sfc').read_bytes()
assert hashlib.sha256(rom).hexdigest() == '3857b5294ea8f7468849437bb2d8271564e8a0ff30774622e9c872bcbd53a84d'
assert rom[0x7fdb] == 0  # rev0, as the colour research established
B3 = lambda a: 0x10000 + (a & 0x7fff) + 0x8000 - 0x8000 if a >= 0x8000 else None
word3 = lambda a: int.from_bytes(rom[0x10000 + a:0x10000 + a + 2], 'little')
byte3 = lambda a: rom[0x10000 + a]
NIGHT, SHADES = 0x8b8a, 0x8b2a
assert rom[0x18aca:0x18aea].hex() == rom_hex(0x18aca, 32)

APPROX = {'sprite': 0x34, 'smoke': 0xbc, 'flash': 0x4e}
# Textured colour words drawn by the SVP raster (tools/generate-svp-texpoly.py,
# GSU 01:A3B2): descriptor 4, index (fixed) or 5, n, indices (animated), the
# index being the material's position in SVP_TexMaterials. No level material
# substitution: bu_7/mybase_0 material 102 ($4006) must retain texture t06.
_TEX = json.loads((ROOT / 'build/agent-texpoly/svp-texpoly.json').read_text())
TEX_MATERIALS = {int(m['word'], 16): i for i, m in enumerate(_TEX['materials'])}
# Bounds shared with polygon texture discovery.
REACHABLE_FRAMES = runpy.run_path(str(ROOT / 'tools/extract-sprite-textures.py'))['REACHABLE_FRAMES']


def resolve(w, depth=0, night=NIGHT):
    if w & 0xc000 == 0x8000:
        p = w & 0x3fff | 0x8000 if (w & 0x3fff) < 0x8000 else w & 0x3fff
        p = 0x8000 | (w & 0x3fff) if (w & 0x3fff) < 0x8000 else w & 0x3fff
        n = byte3(p)
        assert n in (1, 2, 4, 8, 16, 32) and depth == 0, hex(w)
        reach = REACHABLE_FRAMES.get(w, n)
        frames = [resolve(word3(p + 1 + 2 * i), 1, night) for i in range(reach)]
        frames += [frames[-1]] * (n - reach)
        if all(f is not None and f[0] == 4 for f in frames):
            return [5, n] + [f[1] for f in frames]
        if all(f is not None and f[0] in (0, 1) for f in frames) and any(f[0] == 1 for f in frames):
            # 6, n, n HL (readers without type 6 take this as type 3: the
            # depth-cued frames give their level-1 value), then n rows L0..L3:
            # HL = row[colframe & (n-1)][depth level] (fixed frames repeat HL).
            rows = [[f[1]] * 4 if f[0] == 0 else f[2:6] for f in frames]
            return [6, n] + [r[1] for r in rows] + [v for r in rows for v in r]
        if any(f is None or f[0] != 0 for f in frames):
            return None
        return [3, n] + [f[1] for f in frames]
    if w & 0x4000:
        if w in TEX_MATERIALS:
            return [4, TEX_MATERIALS[w]]
        return None  # other textures / smooth: not reproduced
    hi, lo = (w >> 8) & 0x3f, w & 255
    if hi == 0x3f:
        return [0, lo]
    if hi == 0x3e:
        return [1, 0] + [rom[0x10000 + night + 32 * level + lo] for level in range(4)]
    out = [2, 0]
    for level in range(4):
        row = word3(SHADES + 24 * level + 2 * hi)
        out += [byte3(row + i) for i in range(10)]
    return out


MODEL = runpy.run_path(str(ROOT / 'tools/recover-intro-model.py'))['recover']
EFFECT = runpy.run_path(str(ROOT / 'tools/recover-intro-effects.py'))['model']


def used_materials(header):
    # Use the geometry producer's decoder, including non-contiguous streams.
    # A failed recovery must not silently reduce a level model to material 0.
    if header + 0x8000 in {h for _, h in LEVEL['SHAPES']}:
        m = LEVEL['_recover'](rom, header + 0x8000)
        return {f['material'] for g in m['groups'] for f in g['faces']}
    if header in (0x334d, 0x3369):
        return {0}
    for reader in (MODEL, EFFECT):
        try:
            m = reader(rom, header)
        except Exception:
            continue
        faces = [f for g in m.get('groups', []) for f in g['faces']] or m.get('faces', [])
        return {f['material'] for f in faces}
    return {0}


def table(name, header, approx=None):
    pointer = int.from_bytes(rom[header + 18:header + 20], 'little')
    used = used_materials(header)
    count = max(64, max(used) + 1)
    words = [word3(pointer + 2 * i) for i in range(count)]
    descs = []
    for i, w in enumerate(words):
        try:
            d = resolve(w)
        except AssertionError:
            d = None
        if i in used and approx is None:
            assert d is not None, (name, i, hex(w))
        if d is None:
            d = [0, approx] if approx else [0, 0x11]
        descs.append(d)
    return dict(name=name, header=header, table=pointer, words=words, descriptors=descs)


MODELS = [('OldType', 0x65f0, None), ('Debris', 0x660c, None), ('ZacoE388', 0x6388, None),
          ('ZacoC22C', 0x422c, None), ('Boss', 0x6644, None), ('Laser', 0x334d, None),
          ('Explosion', 0x3e04, None), ('MyDemo', 0x3cd0, None),
          ('Sprite', 0x311d, APPROX['sprite']), ('Smoke', 0x2dd5, APPROX['smoke']),
          ('Flash', 0x3091, APPROX['flash'])]
LEVEL = runpy.run_path(str(ROOT / 'tools/level-shapes.py'))
MODELS += [('Level_' + n, h - 0x8000, None) for n, h in LEVEL['SHAPES']]
# Boss body/children share 03:82ED; their headers must agree.
assert all(int.from_bytes(rom[h + 18:h + 20], 'little') == 0x82ed for h in (0x6644, 0x6628, 0x48a0))
tables = [table(*m) for m in MODELS]
# Object colour tables (alx+$20 coltab, used instead of the header table when
# nonzero, 01:AE0C): training trn_ring sets 03:8481 (id_5_c).
COLTABS = [0x8481, 0x82ED, 0x80FC]
for _m in LEVEL['stage_modules']():  # tools/stages/*.py: MESH_COLTABS [(coltab) ...]
    COLTABS += [c for c in _m.get('MESH_COLTABS', []) if c not in COLTABS]
# Entries per object table: enough for every material of the level shapes (BBF0 uses 105).
COLTAB_COUNT = max(64, 1 + max(max(used_materials(h - 0x8000)) for _, h in LEVEL['SHAPES']))
for ct in COLTABS:
    words = [word3(ct + 2 * i) for i in range(COLTAB_COUNT)]
    descs = []
    for w in words:
        try:
            d = resolve(w)
        except AssertionError:
            d = None
        descs.append(d or [0, 0x11])
    tables.append(dict(name=f'Ctab{ct:04X}', header=None, table=ct, words=words, descriptors=descs))
white = dict(name='White', header=None, table=0x800c,
             words=[word3(0x800c + 2 * i) for i in range(64)])
white['descriptors'] = [resolve(w) or [0, 0xee] for w in white['words']]
# Hit flash of a model with materials >= 64: same white entry.
white['descriptors'] += [[0, 0xee]] * (max(len(t['descriptors']) for t in tables) - 64)
tables.append(white)

# Keep material offsets as the common CPU/SVP interface. Alternate night
# tables select descriptors in the same pool, so the SSP consumer is unchanged.
NIGHTS = (0x8B8A, 0x8C0A, 0x8D0A, 0x8D8A)
base_tables = list(tables)
for night in NIGHTS[1:]:
    for original in base_tables:
        descriptors = []
        for word, default in zip(original['words'], original['descriptors']):
            try:
                descriptor = resolve(word, night=night)
            except AssertionError:
                descriptor = None
            descriptors.append(descriptor or default)
        descriptors += original['descriptors'][len(descriptors):]
        tables.append(dict(name=f"Night{night:04X}{original['name']}",
                           header=original['header'], table=original['table'],
                           words=original['words'], descriptors=descriptors))

pool, index = [], {}
lines = ['; Generated by tools/generate-intro-colours.py from the selected USA rev0 ROM.',
         '; Descriptors: 0,HL | 1,0,L0..L3 | 2,0,level*10+(s-6) | 3,n,frames | 6,n,n HL,n x L0..L3.', 'M4ColourPool:']
for t in tables:
    t['offsets'] = []
    for d in t['descriptors']:
        key = tuple(d)
        if key not in index:
            index[key] = len(pool)
            pool += d + ([0] if len(d) & 1 else [])
        t['offsets'].append(index[key])
for i in range(0, len(pool), 16):
    lines.append('        dc.b ' + ','.join(f'${v:02x}' for v in pool[i:i + 16]))
lines.append('        even')
shared_tables = {}
for t in tables:
    shared_tables.setdefault(tuple(t['offsets']), []).append(t['name'])
for offsets, names in shared_tables.items():
    # Headers often use the same original colour table. Keep every symbol,
    # but store byte-identical lookup arrays only once.
    lines.extend(f'M4Colours{name}:' for name in names)
    for i in range(0, len(offsets), 16):
        lines.append('        dc.w ' + ','.join(str(o) for o in offsets[i:i + 16]))
lines.append('M4NightTableMap: ;base table, variants 8C0A/8D0A/8D8A')
seen = set()
for t in base_tables:
    key = tuple(t['offsets'])
    if key in seen:
        continue
    seen.add(key)
    lines.append('        dc.l ' + ','.join(
        [f"M4Colours{t['name']}"] +
        [f"M4ColoursNight{night:04X}{t['name']}" for night in NIGHTS[1:]]))
lines.append('        dc.l 0')
lines.append('M4ColtabMap: ;coltab WORD, table (0 ends)')
for ct in COLTABS:
    lines.append(f'        dc.w ${ct:04x}')
    lines.append(f'        dc.l M4ColoursCtab{ct:04X}')
lines.append('        dc.w 0')
(ROOT / 'build/intro-colours.inc').write_text('\n'.join(lines) + '\n', encoding='ascii')
(ROOT / 'build/intro-colours.json').write_text(json.dumps(dict(
    rom_sha256=hashlib.sha256(rom).hexdigest(), palette='03:8ACA row1 (CGRAM $70..$7F)',
    depth_tables=dict(normal='03:8FAA F6 F3 F1', offset1='03:8F9A C0 B0 B0'), night='03:8B8A', shades='03:8B2A',
    approximations=dict(textured_billboards=APPROX, textured_level_materials={}, textured_materials={f'{w:04X}': i for w, i in TEX_MATERIALS.items()}),
    night_variants=[f'{night:04X}' for night in NIGHTS],
    tables=[dict(name=t['name'], header=t['header'], table=hex(t['table']),
                 words=[hex(w) for w in t['words']], descriptors=t['descriptors']) for t in tables]), indent=1) + '\n')
print('Generated original colour descriptors:', len(pool), 'bytes,', len(tables), 'tables')
