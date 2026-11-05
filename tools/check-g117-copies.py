"""graphics117 fork guard for the SSP code in src/release/.

The release keeps SSP code that was derived from the generated program
(tools/generate-*.py): relocated copies in the IRAM images and the stub
block, and in-place overrides of generated routines (g117_svp.asm). A
generator change there would silently stop matching, so build.ps1 checks,
against the same sources assembled without M4_GRAPHICS117:

1. every copied run (src/release/g117_copies.json) still matches its source
   instruction by instruction: same opcode (or the exact short-immediate
   form) and non-branch operands; branch operands may differ (relocated);
2. the source of every fork is unchanged: the generated code under each
   override G117Ovr<n>, the SSP ranges the rounds derived IRAM code from
   (manifests of make-round35..54) and the 68000 routines replaced or
   short-cut by src/release/ (FORKS below). The SHA-256 covers the source
   text the base listing shows for the range, so moving code does not
   matter but editing it does.

On failure apply the generator change to src/release/ by hand, then refresh:
  check-g117-copies.py ROM LST BASE_ROM BASE_LST          verify (build.ps1)
  check-g117-copies.py ROM LST BASE_ROM BASE_LST --scan   rewrite the table
"""
import bisect, hashlib, json, struct, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from m68k_sim import load_listing
from ssp_dis import two_words, is_branch, mnemonic

ROOT = Path(__file__).resolve().parents[1]
TABLE = ROOT / 'src/release/g117_copies.json'
SHORT = {0x2800: 0x3800, 0x6800: 0x7800, 0x8800: 0x9800, 0xa800: 0xb800, 0xc800: 0xd800, 0xe800: 0xf800}
MIN_RUN, MIN_DISTINCT = 8, 6
IMAGES = ('G117ImgFaces', 'G117ImgRaster', 'G117ImgRaster2', 'G117ImgGeometry', 'G117ImgBsp')


def decode(rom, start, end):
    out, pc = [], start
    while pc < end:
        op = struct.unpack_from('>H', rom, pc)[0]
        n = 2 if two_words(op) else 1
        out.append((pc, list(struct.unpack_from(f'>{n}H', rom, pc))))
        pc += 2 * n
    return out


def text(w):
    return mnemonic(w[0], w[1] if len(w) > 1 else None)


def same(copy, src):
    if is_branch(src[0]) and len(copy) == 2:
        return copy[0] == src[0]
    if copy == src:
        return True
    return len(copy) == 1 and len(src) == 2 and src[0] in SHORT and src[1] < 256 and copy[0] == SHORT[src[0]] | src[1]


def program(rom, sym):
    """Generated SSP program, decoded label by label (labels are instruction starts)."""
    cuts = sorted({v for k, v in sym.items() if k.startswith('SVP_') and sym['SVP_Start'] <= v < sym['SVP_End']}
                  | {sym['SVP_End']})
    ins = {}
    for a, b in zip(cuts, cuts[1:]):
        for pc, w in decode(rom, a, b):
            ins.setdefault(pc, w)
    return ins


def copies(sym):
    """Copy regions: the stub block (without the packed-radio LUT) and the images."""
    regions = [(sym['SVP_End'], sym['G117RadioPackedLUT'], 'SVP_End'),
               (sym['G117RadioLutEnd'], sym['G117SvpTail'], 'G117RadioLutEnd')]
    return regions + [(sym[n], sym[n + 'End'], n) for n in IMAGES]


# (name, start, end): label or (label, byte offset); end exclusive.
FORKS = [
    # SSP derivation ranges of the IRAM copies (manifest blocks/hot/phases).
    ('ssp 91 clear tile', 'SVP_IntroClearTile', 'SVP_IntroPrimitive'),
    ('ssp 107 primitive dispatch', 'SVP_IntroPrimitive', 'SVP_IntroValid65'),
    ('ssp 93 line', 'SVP_IntroLine', 'SVP_IntroNextPrimitive'),
    ('ssp 93 checksum', 'SVP_IntroParticlesUpdated', 'SVP_IntroInvalid'),
    ('ssp 111 view shortcut', 'SVP_GeoModelReady', 'SVP_GeoViewCompose'),
    ('ssp 112 view compose', 'SVP_GeoViewCompose', 'SVP_GeoVertex'),
    ('ssp 102 vertices', 'SVP_GeoVertex', 'SVP_GeoFinishObject'),
    ('ssp 99 divider', 'SVP_GeoDivide', 'SVP_GeoSine'),
    ('ssp 98 face count', 'SVP_FaceCountValid', 'SVP_Face'),
    ('ssp 98 face', 'SVP_Face', 'SVP_FaceExplosion'),
    ('ssp 98 face normal', 'SVP_FaceNormalReady', 'SVP_FaceReadPoint'),
    ('ssp 98 face bounds', 'SVP_FaceScreenBounds', 'SVP_FaceTextured'),
    ('ssp 98 face next', 'SVP_FaceNext', 'SVP_FaceClip'),
    ('ssp 99 clip append', 'SVP_FaceClipAppend', 'SVP_GeoIndexOffsets'),
    ('ssp 103 radio face', 'SVP_RadioFace', 'SVP_RadSpan'),
    ('ssp 103 radio span', 'SVP_RadSpan', 'SVP_RadioGlyph'),
    ('ssp 107 radio glyph', 'SVP_RadioGlyph', 'SVP_RadioRect'),
    ('ssp 102 bsp object', 'SVP_BspObject', 'SVP_BspLightIntro'),
    ('ssp 102 bsp cvt', 'SVP_BspCvt', 'SVP_BspAdvC'),
    ('ssp 102 bsp group', 'SVP_BspGroup', 'SVP_BspF10Loop'),
    ('ssp 102 bsp colour', 'SVP_BspColour', 'SVP_BspBadJobs'),
    ('ssp 114 chain', 'SVP_ChainGeometry', 'SVP_End'),
    ('ssp boot', 'SVP_Start', 'SVP_Wait'),
    # 68000 routines replaced, copied or short-cut by src/release/.
    ('68k level loop entry', 'M4LevelLoop', 'M4LevelLoopResume'),
    ('68k collisions entry', 'M4LevelCollisions', 'M4LevelCollisionsBody'),
    ('68k collision build', 'M4LcBuildDone', 'M4LcBuildDoneBody'),
    ('68k collision sweep', 'M4LcSweep', 'M4LcAabb'),
    ('68k collision aabb', 'M4LcAabb', 'M4LcFrameList'),
    ('68k sin16', 'M4LvwSin16', 'M4LvwRotation'),
    ('68k rotation', 'M4LvwRotation', 'M4LvwRowTimes'),
    ('68k draw end', 'M4LvwDrawEnd', 'M4LvwDrawEndBody'),
    ('68k view xz', 'M4LvViewXZ', 'M4LvSetRestart'),
    ('68k radio record', 'M4RadioRecord', 'M4RadioMeterBox'),
    ('68k tilt build', 'M4VRTiltBuild', 'M4VRTiltEnd'),
    ('68k geometry prepare entry', 'M4IntroGeometryPrepare', 'M4IntroGeometryPrepareBody'),
    ('68k geometry jobs store', ('M4GeometryNoJobsStored', -6), 'M4GeometryNoJobsStored'),
    ('68k geometry faces store', ('M4GeometryClipRunStored', -6), 'M4GeometryClipRunStored'),
    ('68k geometry return', 'M4GeometryReturn', 'M4IntroGeometryLoad'),
    ('68k geometry no hook entry', 'M4GeometryNoHook', 'M4GeometryNoHookBody'),
    ('68k chain select', 'M4ChainSelect', 'M4ChainRequest'),
    ('68k chain request', 'M4ChainRequest', 'M4IntroBossGeometryTest'),
    ('68k scene error return', 'M4IntroSceneDrawErrorReturn', 'M4IntroSceneDrawError'),
    ('68k chain flush poll', 'M4PipeFlushChain', 'M4BlockPrepareMap'),
    ('68k intro failed entry', 'M4IntroFailed', 'M4IntroBackdrop'),
]


def listing_text(path):
    """(address, source text) of every listed line; text starts at column 35."""
    out = []
    for line in Path(path).read_text(errors='replace').splitlines():
        if len(line) > 8 and all(c in '0123456789ABCDEF' for c in line[:8]):
            src = line[35:].rstrip()
            if ' equ ' not in src.lower():
                out.append((int(line[:8], 16), src))
    return out


def text_hash(lines, lo, hi):
    return hashlib.sha256(chr(10).join(s for a, s in lines if lo <= a < hi).encode()).hexdigest()


def address(sym, ref):
    return sym[ref[0]] + ref[1] if isinstance(ref, (list, tuple)) else sym[ref]


def fork_ranges(sym, bsym):
    out = [(name, lo, hi) for name, lo, hi in overrides(sym)]
    return out + [(name, address(bsym, a), address(bsym, b)) for name, a, b in FORKS]


def overrides(sym):
    n, out = 0, []
    while f'G117Ovr{n}' in sym:
        out.append((f'G117Ovr{n}', sym[f'G117Ovr{n}'], sym[f'G117Ovr{n}End']))
        n += 1
    return out


def scan(rom, sym, base, bsym, blines):
    prog = program(base, bsym)
    order = sorted(prog)
    index = {}
    for i in range(len(order) - MIN_RUN + 1):
        index.setdefault(tuple(prog[order[i + k]][0] for k in range(MIN_RUN)), []).append(i)
    names = {}
    for k, v in bsym.items():
        if k.startswith('SVP_') and bsym['SVP_Start'] <= v < bsym['SVP_End']:
            names.setdefault(v, k)
    addrs = sorted(names)
    runs = []
    for lo, hi, region in copies(sym):
        ins = decode(rom, lo, hi)
        i = 0
        while i < len(ins):
            best = (0, -1)
            for j in index.get(tuple(w[0] for _, w in ins[i:i + MIN_RUN]), []):
                n = 0
                while i + n < len(ins) and j + n < len(order) and same(ins[i + n][1], prog[order[j + n]]):
                    n += 1
                best = max(best, (n, j))
            n, j = best
            # Repetitive copy loops (ld a,pm4 / ld pm4,a ...) match by accident.
            if n >= MIN_RUN and len({tuple(w) for _, w in ins[i:i + n]}) >= MIN_DISTINCT:
                a = addrs[bisect.bisect_right(addrs, order[j]) - 1]
                runs.append(dict(copy=region, copy_word=(ins[i][0] - lo) // 2, source=names[a],
                                 source_word=(order[j] - a) // 2, instructions=n))
                i += n
            else:
                i += 1
    forks = [dict(fork=name, at=hex(lo), bytes=hi - lo, sha256=text_hash(blines, lo, hi))
             for name, lo, hi in fork_ranges(sym, bsym)]
    return runs, forks


def verify(rom, sym, base, bsym, blines, table):
    bad = []
    if sym['SVP_End'] != bsym['SVP_End']:
        return ['SVP_End differs between the release and its base build']
    prog = program(base, bsym)
    regions = {name: (lo, hi) for lo, hi, name in copies(sym)}
    for r in table['runs']:
        lo, hi = regions[r['copy']]
        copy = decode(rom, lo + 2 * r['copy_word'], hi)[:r['instructions']]
        pc = bsym[r['source']] + 2 * r['source_word']
        for k in range(r['instructions']):
            if pc not in prog or not same(copy[k][1], prog[pc]):
                bad.append(f"{r['copy']}+${2*r['copy_word']+2*k:x} copies {r['source']}+${pc-bsym[r['source']]:x}: "
                           f"copy '{text(copy[k][1])}', source now '{text(prog.get(pc, [0]))}'")
                break
            pc += 2 * len(prog[pc])
    current = {name: (lo, hi) for name, lo, hi in fork_ranges(sym, bsym)}
    if set(current) != {f['fork'] for f in table['forks']}:
        bad.append('the set of guarded forks changed; refresh with --scan')
    for f in table['forks']:
        lo, hi = current.get(f['fork'], (0, 0))
        if text_hash(blines, lo, hi) != f['sha256']:
            bad.append(f"source of {f['fork']} (${lo:x}, {hi-lo} bytes) changed; "
                       'src/release/ keeps its own version of this code')
    return bad


def main():
    rom, base = Path(sys.argv[1]).read_bytes(), Path(sys.argv[3]).read_bytes()
    sym, bsym = load_listing(Path(sys.argv[2])), load_listing(Path(sys.argv[4]))
    blines = listing_text(sys.argv[4])
    if '--scan' in sys.argv:
        runs, forks = scan(rom, sym, base, bsym, blines)
        TABLE.write_text(json.dumps(dict(
            note='graphics117 SSP copy runs and fork source hashes; tools/check-g117-copies.py.',
            runs=runs, forks=forks), indent=1) + '\n')
        print(f'{len(runs)} runs ({sum(r["instructions"] for r in runs)} instructions), {len(forks)} forks')
        return
    table = json.loads(TABLE.read_text())
    bad = verify(rom, sym, base, bsym, blines, table)
    if bad:
        print('graphics117: SSP code in src/release/ no longer matches the generated program:')
        print('\n'.join('  ' + b for b in bad))
        print('Port the generator change to src/release/, then refresh with --scan (see tools/check-g117-copies.py).')
        sys.exit(1)
    print(f"graphics117: {len(table['runs'])} SSP copy runs match and {len(table['forks'])} forked sources are unchanged")


if __name__ == '__main__':
    main()
