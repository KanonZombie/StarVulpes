"""Own SVP textured polygons: port of the GSU textured face path (cmd8 TexPoly).

Specification: build/research/textured-polygons.md (USA rev0), model
render_textured of tools/textured-poly-oracle.py (equal to the ROM's GSU bytes
01:8E3B..8EAD in 800/800 and 2500/2500 cases). Units ported:
  * face dispatch 01:8E3B: outcodes 01:8ABB (x >= 223 / y >= 191 already out),
    near-plane skip 01:8E47, trivial reject 01:8E73, 2D clip, raster;
  * mtxclippoly2d 01:988B: Sutherland-Hodgman, planes x>=0, x<=223, y>=0,
    y<=191, x/y/u/v words, lmult + divs3216 01:814D emulated bit by bit
    (16 restoring steps, 16-bit remainder);
  * mtscanstart 01:A3B2: affine 8.8 edge/span walk, recip 00:9647, rounding
    restart (x+127)>>8 / u,v floor, top-left with bottom row excluded and
    right column included, temp-hack clamp 01:A506, texel loop 01:A4D2
    (MERGE, AND mask, + base, nibble, index 0 transparent).

Contract (cmd8 record type TEXPOLY_TYPE, RAM0 0x40..0x47 as the dispatcher
reads it): +1 n (3..8), +2 texel(0,0) WORD address in the atlas page (low 16
bits), +3 GSU mask (m_sprmask: hi = v mask, lo = u mask), +4/+5 texture scroll
words m_sprxscroll/m_spryscroll (byte << 8), +6 bit0 = some vertex behind the
near plane (face skipped, 01:8E47), +7 0. Then ceil(n/2) continuation records
in the same cmd8 stream, two vertices each: x, y (GSU screen WORDs, window
0..223 x 0..191, centre already added), u, v (WORDs 0..255, texturexytab
bytes in face order). The routine consumes them (RAM0 1 += 8*k, RAM0 2 -= k).
Output: VR packed bitmap at A[F6] (as SVP_GridPlot): x+16, row y; nibble
writes in DRAM overwrite mode $4418 (index 0 never written = transparent).
Texels: atlas of WORDs t*$1111 with rows of 256 WORDs (the GSU's own 256-byte
row stride), so address = base + (v & mhh) + ((u & mlh) >> 8), the last term
from the SSP multiplier (P = 2*X*$80). The atlas lives in the SVP ROM data
area (PM4 ROM read, mode $0800|page), extracted from the selected ROM.

Outputs (build/agent-texpoly/):
  svp-texpoly.inc             production SSP code (uses SVP_SprRecip,
                              SVP_TriRowBase, SVP_TriCol of the VR build)
  svp-texpoly-standalone.inc  same code with own copies of those tables,
                              for tools/check-svp-texpoly.py
  svp-texpoly-rom.inc         atlas + material table (SVP ROM data block)
  svp-texpoly.json            provenance, atlas layout, hashes
Usage: generate-svp-texpoly.py [--test-textures] [--out DIR]
"""
from starfox_rom import rom_hex
import argparse
import hashlib
import json
import runpy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHA = '3857b5294ea8f7468849437bb2d8271564e8a0ff30774622e9c872bcbd53a84d'
TEXPOLY_TYPE = 11  # 9/10: route map planets (generate-svp-sphere.py)
WINDOW = (0, 223, 0, 191)          # 02:F3F2..F40F game window (m_xleft/xright/ytop/ybot)
MAX_VERTS = 16                     # m_polybuf 0982..0A01 = 16 vertices of 4 WORDs
# Colour words of the use cases (textured-polygons.md section 4): GAME OVER gamesh/oversh,
# mybase_0/bu_7 material 102, wing spark B289 frames, + level textured words found by
# the scan in level shapes (generate time).
CASE_WORDS = [0x44D4, 0x44D5, 0x45D4, 0x45D5, 0x4006, 0x400A, 0x400B, 0x400F,
              0x4001, 0x4002,  # cockpit canopy 00:D748 (space-player-cockpit.md 1.4)
              0x46D3, 0x40DF, 0x40AC]  # Asteroid 1: big_meteor AFCD (03:857D, t53) and escapee B26D (03:854E, t5F)
for _m in runpy.run_path(str(ROOT / 'tools/level-shapes.py'))['stage_modules']():  # tools/stages/*.py
    CASE_WORDS += [w for w in _m.get('TEX_WORDS', []) if w not in CASE_WORDS]
CASE_WORDS += [w for w in (0x400d, 0x4004, 0x40a8) if w not in CASE_WORDS]  # route-1 walls/bars
# Extra combinations for the offline check only (all texturexytab masks, both nibbles).
TEST_WORDS = [0x4100 | 0x12, 0x4200 | 0x80 | 0x20, 0x4300 | 0x31, 0x4700 | 0x80 | 0x40, 0x4600 | 0x07,
              0x4800 | 0x80 | 0x5F, 0x4500 | 0x02]

lines = []


def emit(*words):
    lines.append('        dc.w ' + ','.join(f'${w & 0xffff:04x}' if isinstance(w, int) else w for w in words))


def label(name):
    lines.append(name + ':')


# ---- SSP1601 instruction helpers (encodings as tools/ssp_sim.py / svpdev ssp16asm)
def clr(): emit(0xe003)                       # eor A,A (32 bits; Z=1)
def ldA(s): emit(0x0600 | s)                  # A_hi = RAM[s] (A_lo kept, no flags)
def lda(s): emit(0xe003, 0x0600 | s)          # A = RAM[s] << 16
def st(s): emit(0x0e00 | s)                   # RAM[s] = A_hi
def tst(s): emit(0xe003, 0x8600 | s)          # A = RAM[s] << 16 with flags
def ldi(v): emit(0x0830, v)                   # A_hi = v
def m(kind, s): emit({'sub': 0x2600, 'cmp': 0x6600, 'add': 0x8600, 'and': 0xa600, 'or': 0xc600, 'xor': 0xe600}[kind] | s)
def i(kind, v):
    if isinstance(v, int) and 0 <= v < 256:
        emit({'sub': 0x3800, 'cmp': 0x7800, 'add': 0x9800, 'and': 0xb800, 'or': 0xd800, 'xor': 0xf800}[kind] | v)
    else:
        emit({'sub': 0x2800, 'cmp': 0x6800, 'add': 0x8800, 'and': 0xa800, 'or': 0xc800, 'xor': 0xe800}[kind], v)
def shl(n=1): emit(*([0x9003] * n))
def sar(n=1): emit(*([0x9002] * n))
def neg(): emit(0x9006)
def absa(): emit(0x9007)
def x_a(): emit(0x0013)                       # X = A_hi
def y_a(): emit(0x0023)                       # Y = A_hi
def y_imm(v): emit(0x0820, v)
def a_p(): emit(0x0037)                       # A = P = 2*X*Y
def a_al(): emit(0x003f)                      # A_hi = A_lo
def al_a(): emit(0x00f3)                      # A_lo = A_hi
def a_prog(): emit(0x4a30)                    # A_hi = program[A_hi]
def br(name, c='al'): emit({'al': 0x4c00, 'z1': 0x4d50, 'z0': 0x4c50, 'n1': 0x4d70, 'n0': 0x4c70}[c], name + '/2')
def call(name): emit(0x4800, name + '/2')
def ret(): emit(0x0065)
def ld_r(ri): emit(0x1430 | (ri & 3) | (0x100 if ri >= 4 else 0))   # ld ri,A
def a_ind(ri, inc=False): emit((0x0230 if ri < 4 else 0x0330) | (ri & 3) | (4 if inc else 0))  # A=(ri[+])
def ind_a(ri): emit((0x0434 if ri < 4 else 0x0534) | (ri & 3))     # (ri+)=A


# ---- work slots. RAM0 80..D1 (pointer-addressed blocks first), then RAM1 1A0.. (cmd8 per-primitive
# scratch; RAM0 0..2, 13, 40..47, D2/D3, F6 and RAM1 1E0.. are not touched).
names = ('X1 Y1 U1 V1 X2 Y2 U2 V2 '
         'RX1 XP1 YP1 X1I XP1I YP1I DY1 I1 RX2 XP2 YP2 X2I XP2I YP2I DY2 I2 '
         'WRX WXP WYP WXI WXPI WYPI WDY WI '
         'U V DU DV W CNTW MLH MHH TB RMASK '
         'NV SXS SYS ANY ALL K T0 T1 T2 CIN COUT NIN NOUT LEFT AXIS CVAL MODE IN1 IN2 LT LD LA1 LA2 '
         'DH DSIGN DR6 DR0 DCNT OVF Q0 Q1 Q2 Q3 VB YMIN YMAX TOP I YR REM1 REM2 CNT DX DXP DYP EY R '
         'XA XB L XE SIDE PL').split()
S = {n: (0x80 + k if k < 0x52 else 0x1a0 + k - 0x52) for k, n in enumerate(names)}
assert S['WI'] < 0x100 and max(S.values()) < 0x1e0, hex(max(S.values()))
globals().update(S)
FB = 0xf6
BUF0, BUF1 = 0x00, 0x40              # RAM1 vertex buffers (r4/r5 offsets): 16 x (x, y, u, v)
MUTATIONS = ('restart_trunc', 'xa_round', 'no_clamp', 'div_signed', 'uv_order')


def gen_code(tables, invalid, mutate=None):
    """tables: dict(recip, rowbase, col) label names; invalid: branch target for bad records;
    mutate: one of MUTATIONS, a deliberately wrong variant used by the checker's negative controls.
    ldA (no clear) is used where neither A_lo nor a Z flag of the loaded value matters."""
    lines.clear()
    lines.append('; Generated by tools/generate-svp-texpoly.py: own SVP port of the GSU textured face path')
    lines.append('; (01:8E3B dispatch, 01:988B clip, 01:A3B2 raster). Do not edit.')
    rec, rowb, col = tables['recip'], tables['rowbase'], tables['col']
    page = "$0800|((SVP_TexAtlas/2)>>16)"

    def cp(src, dst):
        ldA(src); st(dst)

    label('SVP_TexPoly')
    # -- header and validation
    ldA(0x41); st(NV); i('sub', 3); br(invalid, 'n1')
    ldA(NV); i('sub', 9); br('SVP_TexNOk', 'n1'); br(invalid)
    label('SVP_TexNOk')
    lda(NV); i('add', 1); sar(); st(K)                       # continuation records
    ldA(2); i('sub', 1); m('sub', K); br(invalid, 'n1')       # enough records left in the job
    cp(0x42, TB); cp(0x44, SXS); cp(0x45, SYS)
    ldA(0x43); i('and', 0xff00); st(MHH)
    ldA(0x43); i('and', 0xff); x_a(); y_imm(0x80); a_p(); a_al(); st(MLH)
    # -- vertices from the DRAM stream (RAM0 1) into RAM1 buffer 0; consume k records
    ldA(1); emit(0x00e3, 0x08e0, 0x0818, 0x000c)
    emit(0x1d00 | BUF0)                                        # r5 = buffer 0
    lda(NV); shl(2); st(T0)
    label('SVP_TexRead')
    emit(0x003c); ind_a(5)
    lda(T0); i('sub', 1); st(T0); br('SVP_TexRead', 'z0')
    lda(K); shl(3); m('add', 1); st(1)
    ldA(2); m('sub', K); st(2)
    # -- outcodes 01:8ABB: c = 4*(x<0 | 2*(x>=223)) + (y<0 | 2*(y>=191)); ANY = OR, ALL = AND
    clr(); st(ANY); ldi(15); st(ALL)
    emit(0x1c00 | BUF0); cp(NV, T2)
    label('SVP_TexOut')
    clr(); st(T1)
    for axis, lo_bit, hi_bit, bound in ((0, 4, 8, WINDOW[1]), (1, 1, 2, WINDOW[3])):
        clr(); a_ind(4, True); i('or', 0); br(f'SVP_TexOutLo{axis}', 'n1')
        i('sub', bound); br(f'SVP_TexOutDone{axis}', 'n1')
        ldA(T1); i('or', hi_bit); st(T1); br(f'SVP_TexOutDone{axis}')
        label(f'SVP_TexOutLo{axis}'); ldA(T1); i('or', lo_bit); st(T1)
        label(f'SVP_TexOutDone{axis}')
    a_ind(4, True); a_ind(4, True)                              # skip u, v
    ldA(ANY); m('or', T1); st(ANY); ldA(ALL); m('and', T1); st(ALL)
    lda(T2); i('sub', 1); st(T2); br('SVP_TexOut', 'z0')
    ldA(0x46); i('and', 1); br('SVP_TexRet', 'z0')              # near plane: textured face skipped
    clr(); ldi(BUF0); st(VB)
    tst(ANY); br('SVP_TexRaster', 'z1')                         # all inside: direct
    tst(ALL); br('SVP_TexRet', 'z0')                            # trivial reject
    # -- 2D clip, planes x>=0, x<=223, y>=0, y<=191 (table: axis, C, max-plane)
    clr(); ldi(BUF0); st(CIN); ldi(BUF1); st(COUT); cp(NV, NIN)
    ldi('SVP_TexPlanes/2'); st(PL)
    label('SVP_TexPlane')
    for k, dst in enumerate((AXIS, CVAL, MODE)):
        ldA(PL); i('add', k); a_prog(); st(dst)
    call('SVP_TexClipPass')
    tst(NOUT); br('SVP_TexRet', 'z1')
    cp(NOUT, NIN); cp(CIN, T0); cp(COUT, CIN); cp(T0, COUT)
    ldA(PL); i('add', 3); st(PL); i('sub', 'SVP_TexPlanes/2+12'); br('SVP_TexPlane', 'n1')
    cp(CIN, VB); cp(NIN, NV)
    br('SVP_TexRaster')
    label('SVP_TexRet'); ret()
    label('SVP_TexPlanes')
    emit(0, WINDOW[0], 0, 0, WINDOW[1], 1, 1, WINDOW[2], 0, 1, WINDOW[3], 1)

    # ------------------------------------------------------------------ clip pass (01:988B, one plane)
    label('SVP_TexClipPass')
    clr(); st(NOUT); st(OVF)
    ldA(COUT); ld_r(5); ldA(CIN); ld_r(4)
    call('SVP_TexLoadP2')
    cp(NIN, LEFT)
    label('SVP_TexEdge')
    for k in range(4):
        cp(X2 + k, X1 + k)
    cp(IN2, IN1)
    lda(LEFT); i('sub', 1); st(LEFT); br('SVP_TexNoWrap', 'z0')
    ldA(CIN); ld_r(4)                                           # closing edge: back to vertex 0
    label('SVP_TexNoWrap')
    call('SVP_TexLoadP2')
    tst(IN1); br('SVP_TexSkip1', 'z1')
    for k in range(4):
        cp(X1 + k, Q0 + k)
    call('SVP_TexEmit')
    label('SVP_TexSkip1')
    tst(IN1); m('xor', IN2); br('SVP_TexSkip2', 'z1')
    call('SVP_TexIntersect')
    label('SVP_TexSkip2')
    tst(LEFT); br('SVP_TexEdge', 'z0')
    tst(OVF); br('SVP_TexEmpty', 'z0')
    ldA(NOUT); i('sub', 3); br('SVP_TexEmpty', 'n1')
    ret()
    label('SVP_TexEmpty'); clr(); st(NOUT); ret()

    label('SVP_TexLoadP2')                                       # P2 = (r4+) x4, IN2 = inside(P2)
    for k in range(4):
        a_ind(4, True); st(X2 + k)
    ldA(AXIS); i('add', X2); ld_r(0); clr(); a_ind(0); st(T0)
    tst(MODE); br('SVP_TexInMax', 'z0')
    tst(T0); br('SVP_TexInNo', 'n1'); br('SVP_TexInYes')        # 98E2: not BLT(p - 0)
    label('SVP_TexInMax')
    lda(T0); m('sub', CVAL); br('SVP_TexInYes', 'n1'); br('SVP_TexInYes', 'z1')   # 9A00: (p-C)-1 < 0
    label('SVP_TexInNo'); clr(); st(IN2); ret()
    label('SVP_TexInYes'); clr(); ldi(1); st(IN2); ret()

    label('SVP_TexEmit')                                         # Q0..Q3 -> (r5+), at most 16
    ldA(NOUT); i('sub', MAX_VERTS); br('SVP_TexEmitOk', 'n1')
    clr(); ldi(1); st(OVF); ret()
    label('SVP_TexEmitOk')
    ldA(NOUT); i('add', 1); st(NOUT)
    for k in range(4):
        ldA(Q0 + k); ind_a(5)
    ret()

    # intersection 9928 / 9B6A: t = C - a1, d = a2 - a1 on the clipped axis; others lerped from p1
    label('SVP_TexIntersect')
    ldA(AXIS); i('add', X1); ld_r(0); ldA(AXIS); i('add', X2); ld_r(1)
    a_ind(0); st(T1)
    ldA(CVAL); m('sub', T1); st(LT)
    a_ind(1); m('sub', T1); st(LD)
    for k in range(4):
        lbl = f'SVP_TexIsect{k}'
        if k < 2:                                                  # the clipped coordinate is exactly C
            lda(AXIS); i('xor', k); br(lbl + 'L', 'z0')
            cp(CVAL, Q0 + k); br(lbl)
            label(lbl + 'L')
        cp(X1 + k, LA1); cp(X2 + k, LA2); call('SVP_TexLerp'); st(Q0 + k)
        label(lbl)
    br('SVP_TexEmit')

    # lerp = divs3216(lmult(t, a2-a1), d) + a1 (01:814D bit exact) -> A_hi
    label('SVP_TexLerp')
    ldA(LA2); m('sub', LA1); x_a(); ldA(LT); y_a(); a_p(); sar()          # A = s16(t)*s16(delta)
    i('cmp', 0xc000); br('SVP_TexLerpProd', 'z0'); ldi(0x4000)           # 2*$8000*$8000 wrapped
    label('SVP_TexLerpProd')
    st(DH); a_al(); st(T2)
    ldA(DH); m('xor', LD); st(DSIGN)
    lda(LD); absa(); st(DR6)
    ldA(T2); al_a(); ldA(DH); absa(); shl()                          # (r0:r4) = |p| << 1
    st(DR0); a_al(); st(T2); ldi(4); st(DCNT)
    label('SVP_TexDivBlock')
    ldA(T2); al_a(); ldA(DR0)
    for k in range(4):                                                # restoring step, 16-bit remainder
        q1, q1s, nxt = f'SVP_TexDivA{k}', f'SVP_TexDivB{k}', f'SVP_TexDivN{k}'
        if mutate != 'div_signed':
            i('cmp', 0); br(q1, 'n1')                                 # r0 >= $8000: >= divisor (<= $8000)
        m('sub', DR6); br(q1s, 'n0')
        m('add', DR6); shl(); br(nxt)
        label(q1); m('sub', DR6)
        label(q1s); shl(); st(DR0); a_al(); i('or', 1); al_a(); ldA(DR0)
        label(nxt)
    st(DR0); a_al(); st(T2)
    lda(DCNT); i('sub', 1); st(DCNT); br('SVP_TexDivBlock', 'z0')
    tst(DSIGN); br('SVP_TexLerpPos', 'n0')
    lda(T2); neg(); m('add', LA1); ret()
    label('SVP_TexLerpPos'); ldA(T2); m('add', LA1); ret()

    # ------------------------------------------------------------------ raster (01:A3B2)
    def vertex_addr(slot):
        lda(slot); shl(2); m('add', VB); ld_r(4)

    def byte_next(dst):
        a_ind(4, True); i('and', 0xff); st(dst)

    def shl8(src, dst):          # dst = src << 8 for src 0..255 (P = src*256; needs Y = $80)
        ldA(src); x_a(); a_p(); a_al(); st(dst)

    def shr8(src, dst, plus=None):   # dst = (src [+plus]) >> 8, 16-bit logical (needs Y = $80)
        ldA(src)
        if plus is not None:
            i('add', plus)
        x_a(); a_p(); i('and', 0xff); st(dst)

    label('SVP_TexRaster')
    clr(); ldi(0x3ff); st(YMIN); clr(); st(YMAX); st(TOP); st(I)
    label('SVP_TexTop')
    vertex_addr(I); a_ind(4, True); a_ind(4, True); i('and', 0xff); st(T0)
    m('sub', YMIN); br('SVP_TexNotMin', 'n0')
    cp(T0, YMIN); cp(I, TOP)
    label('SVP_TexNotMin')
    ldA(T0); m('sub', YMAX); br('SVP_TexNotMax', 'n1')
    cp(T0, YMAX)
    label('SVP_TexNotMax')
    ldA(I); i('add', 1); st(I); m('sub', NV); br('SVP_TexTop', 'n1')
    lda(YMIN); m('sub', YMAX); br('SVP_TexRet', 'z1')              # A402: no height
    y_imm(0x80)
    vertex_addr(TOP); byte_next(T0); byte_next(T1); byte_next(T2); byte_next(EY)
    shl8(T0, RX1); cp(RX1, RX2)
    shl8(T2, XP1); cp(XP1, XP2)
    shl8(EY, YP1); cp(YP1, YP2)
    ldA(TOP); st(I2); i('add', 1); st(I1); m('sub', NV); br('SVP_TexI1Ok', 'n1'); clr(); st(I1)
    label('SVP_TexI1Ok')
    cp(YMIN, YR); clr(); st(DY1); st(DY2)

    label('SVP_TexTrap')                                             # A443: new edges when exhausted
    for side, blk in ((0, RX1), (1, RX2)):
        tst(blk + 6); br(f'SVP_TexSkipN{side}', 'z0')
        emit(0x1800 | blk, 0x1900 | WRX); call('SVP_TexCopy8')
        clr(); ldi(side); st(SIDE); br('SVP_TexNewX')
        label(f'SVP_TexNewXDone{side}')
        emit(0x1800 | WRX, 0x1900 | blk); call('SVP_TexCopy8')
        label(f'SVP_TexSkipN{side}')
    lda(DY1); m('sub', DY2); br('SVP_TexTrapB', 'n1')
    st(REM1); cp(DY2, CNT); clr(); st(REM2); br('SVP_TexLine')
    label('SVP_TexTrapB'); neg(); st(REM2); cp(DY1, CNT); clr(); st(REM1)

    # one line (A46E): span, u/v steps, packed nibble writes
    label('SVP_TexLine')
    shr8(RX1, XA, 0x80 if mutate == 'xa_round' else None); shr8(RX2, XB)
    ldA(XB); m('sub', XA); br('SVP_TexL1', 'n1'); i('add', 1); br('SVP_TexLSet')
    label('SVP_TexL1'); ldi(1)
    label('SVP_TexLSet'); st(L)
    i('add', rec + '/2'); a_prog(); y_a()                              # Y = recip[L]
    for d, cur, other, scroll, inc_o, inc_c, out in ((DU, XP1, XP2, SXS, XP2I, XP1I, U),
                                                     (DV, YP1, YP2, SYS, YP2I, YP1I, V)):
        ldA(other); m('sub', cur); x_a(); a_p(); st(d)                  # fq(p2 - p1, recip[L])
        ldA(cur); m('add', scroll); st(out)
        ldA(other); m('add', inc_o); st(other)
        ldA(cur); m('add', inc_c); st(cur)
    y_imm(0x80)
    ldA(XA); m('add', L); i('sub', 1); st(XE)
    i('sub', 240); br('SVP_TexLineEnd', 'n0')                          # port guard: never reached by the GSU
    ldA(YR); i('add', rowb + '/2+16'); a_prog(); m('add', FB); st(T0)
    ldA(XA); i('add', col + '/2+16'); a_prog(); m('add', T0)
    emit(0x00e3, 0x08e0, 0x4418, 0x00c0)                                 # PM4 write: cell steps, overwrite
    ldA(XE); i('and', 3); i('add', 'SVP_TexRightMasks/2'); a_prog(); st(RMASK)
    ldA(XE); sar(2); st(T1); ldA(XA); sar(2); st(T2); ldA(T1); m('sub', T2); st(CNTW)
    clr(); st(W)
    ldA(XA); i('and', 3); i('add', 'SVP_TexEntry/2'); a_prog(); emit(0x0063)
    for k in range(4):                                                  # texel loop A4D2, nibble k
        label(f'SVP_TexP{k}')
        ldA(U); m('and', MLH); x_a()                                    # X = u & (ml << 8)
        ldA(U); m('add', DU); st(U)
        ldA(V)
        if mutate == 'uv_order':                                        # wrong: address from the stepped v
            m('add', DV)
        m('and', MHH); emit(0x8007); m('add', TB)                      # (v & mhh) + ((u >> 8) & ml) + base
        emit(0x00e3, 0x08e0, page, 0x000c, 0x003c)                      # texel WORD t*$1111 (ROM)
        i('and', 0xf000 >> (4 * k))
        if k:
            m('or', W)
        if k < 3:
            st(W)
        else:
            x_a()
        ldA(V); m('add', DV); st(V)                                     # v += dv after the fetch
    ldA(CNTW); i('sub', 1); st(CNTW); br('SVP_TexLast', 'n1')
    emit(0x00c1); br('SVP_TexP0')                                       # ld PM4,X
    label('SVP_TexLast')
    emit(0x0031); m('and', RMASK); emit(0x00c3)
    label('SVP_TexLineEnd')
    for rx, inc in ((RX1, X1I), (RX2, X2I)):                            # A506 temp hack
        ldA(rx); m('add', inc); st(rx); br(f'SVP_TexClamp{rx}', 'n0' if mutate != 'no_clamp' else 'al')
        i('add', 0x800); br(f'SVP_TexClamp{rx}', 'n1'); clr(); st(rx)
        label(f'SVP_TexClamp{rx}')
    ldA(YR); i('add', 1); st(YR)
    lda(CNT); i('sub', 1); st(CNT); br('SVP_TexLine', 'z0')
    cp(REM1, DY1); cp(REM2, DY2); br('SVP_TexTrap')

    # mtnewx1 A537 / mtnewx2 A5CE on the work block (SIDE 0 = forward/left, 1 = backward/right)
    label('SVP_TexNewX')
    shr8(WRX, WRX, None if mutate == 'restart_trunc' else 127); shr8(WXP, WXP); shr8(WYP, WYP)
    label('SVP_TexNewXLoop')
    cp(WRX, DX); cp(WXP, DXP); cp(WYP, DYP)
    tst(SIDE); br('SVP_TexNewXFwd', 'z1')
    ldA(WI); i('sub', 1); br('SVP_TexNewXDec', 'n0'); m('add', NV)    # pre-decrement (wraps to n-1)
    label('SVP_TexNewXDec'); st(WI)
    label('SVP_TexNewXFwd')
    vertex_addr(WI); byte_next(WRX); byte_next(EY); byte_next(WXP); byte_next(WYP)
    tst(SIDE); br('SVP_TexNewXRead', 'z0')
    ldA(WI); i('add', 1); st(WI); m('sub', NV); br('SVP_TexNewXRead', 'n1'); clr(); st(WI)
    label('SVP_TexNewXRead')
    lda(EY); m('sub', YR); st(WDY); br('SVP_TexNewXLoop', 'z1'); br('SVP_TexRet', 'n1')
    i('add', rec + '/2'); a_prog(); st(R)                               # r = recip[dy]
    ldA(WRX); m('sub', DX); x_a(); ldA(R); y_a(); a_p(); shl(8); st(WXI)   # bits 8..23 of 2*d*r
    y_imm(0x80); shl8(DX, WRX)
    for cur, start, inc in ((WXP, DXP, WXPI), (WYP, DYP, WYPI)):        # fq((delta & $FF) << 8, r)
        ldA(cur); m('sub', start); i('and', 0xff); x_a(); a_p(); a_al(); x_a()
        ldA(R); y_a(); a_p(); st(inc)
        y_imm(0x80); shl8(start, cur)
    tst(SIDE); br('SVP_TexNewXDone1', 'z0'); br('SVP_TexNewXDone0')
    label('SVP_TexCopy8')                                               # (r1+) = (r0+) x 8, RAM0
    for _ in range(8):
        a_ind(0, True); ind_a(1)
    ret()
    label('SVP_TexEntry'); emit(*[f'SVP_TexP{k}/2' for k in range(4)])
    label('SVP_TexRightMasks'); emit(0xf000, 0xff00, 0xfff0, 0xffff)
    return '\n'.join(lines) + '\n'


def standalone_tables(rom_bytes):
    """Copies of the VR build tables the production code uses (same values)."""
    T = runpy.run_path(str(ROOT / 'tools/extract-sprite-textures.py'), run_name='sprite_textures')
    rom = T['Rom'](rom_bytes)
    recip = [rom.w(0, (0x9647 + 2 * n) & 0xFFFF) for n in range(241)]
    assert all(recip[n] == min(32767, 32768 // n) for n in range(1, 241))
    out = []

    def table(name, values):
        out.append(name + ':')
        for k in range(0, len(values), 16):
            out.append('        dc.w ' + ','.join(f'${v & 0xffff:04x}' for v in values[k:k + 16]))
    table('SVP_TexTestRecip', recip)          # = SVP_SprRecip (generate-svp-sprites.py)
    table('SVP_TexTestRowBase', [((y - 16) & 0xf0) * 64 + ((y - 16) & 15) * 2 if 16 <= y < 208 else 0
                                 for y in range(224)])   # = SVP_TriRowBase (generate-intro-raster.py)
    table('SVP_TexTestCol', [(x >> 3) * 32 + ((x >> 2) & 1) for x in range(256)])   # = SVP_TriCol
    out.append('SVP_TexTestInvalid:')
    out.append('        dc.w $4c00,SVP_TexTestInvalid/2')
    return '\n'.join(out) + '\n'


# ---------------------------------------------------------------------------- textures
def build_atlas(rom_bytes, words):
    """Texel grids t*$1111 (row stride 256 WORDs) for every (texture, nibble) used, sized by the
    largest mask; packed into 256-WORD atlas rows. Values are exactly what the GSU reads:
    nibble of ROM[bank:(addr + (r<<8 | c)) & $FFFF] (CMODE 4 = high, 0 = low)."""
    T = runpy.run_path(str(ROOT / 'tools/extract-sprite-textures.py'), run_name='sprite_textures')
    rom = T['Rom'](rom_bytes)
    need = {}
    descs = {}
    for w in words:
        t = T['texture_from_word'](rom, w)
        mask = int(t['mask'], 16)
        key = (t['texture_index'], t['nibble'])
        mh, ml = mask >> 8, mask & 0xff
        assert (mh & (mh + 1)) == 0 and (ml & (ml + 1)) == 0, hex(mask)   # 2^k-1 (all 9 entries)
        h, wdt = need.get(key, (0, 0))
        need[key] = (max(h, mh + 1), max(wdt, ml + 1))
        descs[w] = dict(t=t, key=key, mask=mask)
    items = sorted(need.items(), key=lambda kv: (-kv[1][0], -kv[1][1], kv[0]))
    place, heights = {}, [0] * 256
    for key, (h, wdt) in items:
        # Stack short textures beside tall ones instead of reserving the
        # whole shelf height. The row stride and every source texel stay
        # unchanged; this fits the original Andross core without eating
        # the adjacent audio bank.
        y, x = min((max(heights[x:x+wdt]), x) for x in range(257-wdt))
        place[key] = (y, x)
        heights[x:x+wdt] = [y+h] * wdt
    rows_total = max(heights)
    grid = [[0] * 256 for _ in range(rows_total)]
    tex_report = {}
    for key, (h, wdt) in need.items():
        r0, c0 = place[key]
        any_t = next(d['t'] for d in descs.values() if d['key'] == key)
        bank, addr, high = any_t['bank'], any_t['addr'], key[1] == 'high'
        raw = bytearray()
        for r in range(h):
            for c in range(wdt):
                b = rom.data[T['phys'](bank, (addr + ((r << 8) | c)) & 0xFFFF)]
                raw.append(b)
                grid[r0 + r][c0 + c] = ((b >> 4) if high else (b & 15)) * 0x1111
        tex_report['%02X%s' % (key[0], 'H' if high else 'L')] = dict(
            source='%02X:%04X' % (bank, addr), nibble=key[1], rows=h, cols=wdt, atlas_row=r0, atlas_col=c0,
            sha256_source_bytes=hashlib.sha256(bytes(raw)).hexdigest())
    return grid, place, descs, tex_report


def rom_data(rom_bytes, words):
    """SVP ROM data include: atlas (must not cross a 64K-WORD page) + material table."""
    grid, place, descs, tex_report = build_atlas(rom_bytes, words)
    r = ['; Generated by tools/generate-svp-texpoly.py: texel atlas (WORD t*$1111, rows of 256 WORDs)',
         '; and textured materials, read by SVP_TexPoly through PM4 (ROM mode $0800|page).',
         # the atlas must stay inside one 64K-WORD page: pad to the next page when it would cross
         f'        if ((*/2)&$ffff)+{len(grid) * 256}>$10000',
         '        dcb.b $20000-(*&$1ffff),0',
         '        endif',
         'SVP_TexAtlas:']
    for row in grid:
        for k in range(0, 256, 16):
            r.append('        dc.w ' + ','.join(f'${v:04x}' for v in row[k:k + 16]))
    r.append('SVP_TexAtlasEnd:')
    r.append('        if ((SVP_TexAtlas/2)>>16)<>(((SVP_TexAtlasEnd-2)/2)>>16)')
    r.append('        inform 3,"SVP_TexAtlas crosses a 64K-word page"')
    r.append('        endif')
    r.append('; Materials (11 WORDs): colour word, texel(0,0) WORD address (low 16), GSU mask,')
    r.append('; u0 v0 u1 v1 u2 v2 u3 v3 (texturexytab bytes; vertex k of the face takes pair k, 01:8E17).')
    r.append('SVP_TexMaterials:')
    mats = []
    for w in words:
        d = descs[w]
        r0, c0 = place[d['key']]
        uv = d['t']['uv']
        r.append(f'        dc.w ${w:04x},((SVP_TexAtlas/2)+{r0 * 256 + c0})&$ffff,${d["mask"]:04x},' +
                 ','.join(str(v) for v in uv))
        mats.append(dict(word='%04X' % w, texture='%02X%s' % (d['key'][0], 'H' if d['key'][1] == 'high' else 'L'),
                         atlas_offset=r0 * 256 + c0, mask='%04X' % d['mask'], uv=uv, xy_index=d['t']['xy_index']))
    r.append('SVP_TexMaterialsEnd:')
    return '\n'.join(r) + '\n', dict(atlas_rows=len(grid), atlas_bytes=512 * len(grid), textures=tex_report,
                                      materials=mats)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--test-textures', action='store_true',
                    help='also write svp-texpoly-rom-test.inc with TEST_WORDS (offline check build)')
    ap.add_argument('--out', default=str(ROOT / 'build/agent-texpoly'))
    ap.add_argument('--level-words', default='', help='comma-separated extra textured colour words (hex)')
    ap.add_argument('--mutate', choices=MUTATIONS, help='negative control: deliberately wrong variant (checker only)')
    args, _unused = ap.parse_known_args()  # extract_sf.ps1 passes layout arguments
    rom_bytes = (ROOT / 'ref/Star Fox (USA).sfc').read_bytes()
    assert len(rom_bytes) == 1048576 and hashlib.sha256(rom_bytes).hexdigest() == SHA and rom_bytes[0x7fdb] == 0
    # anchors of the units ported (same bytes the oracle checks)
    for off, hexbytes in ((0xA3B2, rom_hex(0x0a3b2, 4)), (0xA4D2, rom_hex(0x0a4d2, 11)), (0xA506, rom_hex(0x0a506, 8)),
                          (0x988B, rom_hex(0x0988b, 4)), (0x814D, rom_hex(0x0814d, 6)), (0x8E3B, rom_hex(0x08e3b, 4)), (0x1647, rom_hex(0x01647, 6))):
        assert rom_bytes[off:off + len(hexbytes) // 2].hex() == hexbytes, hex(off)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    words = list(dict.fromkeys(list(CASE_WORDS) + [int(w, 16) for w in args.level_words.split(',') if w]))
    prod = gen_code(dict(recip='SVP_SprRecip', rowbase='SVP_TriRowBase', col='SVP_TriCol'), 'SVP_IntroInvalid')
    (out / 'svp-texpoly.inc').write_text(prod, encoding='ascii')
    test = gen_code(dict(recip='SVP_TexTestRecip', rowbase='SVP_TexTestRowBase', col='SVP_TexTestCol'),
                    'SVP_TexTestInvalid', args.mutate)
    (out / 'svp-texpoly-standalone.inc').write_text(test + standalone_tables(rom_bytes), encoding='ascii')
    code_words = sum(len(l.split('dc.w ')[1].split(',')) for l in prod.splitlines() if 'dc.w ' in l)
    text, info = rom_data(rom_bytes, words)
    (out / 'svp-texpoly-rom.inc').write_text(text, encoding='ascii')
    if args.test_textures:
        ttext, tinfo = rom_data(rom_bytes, list(dict.fromkeys(words + TEST_WORDS)))
        (out / 'svp-texpoly-rom-test.inc').write_text(ttext, encoding='ascii')
    (out / 'svp-texpoly.json').write_text(json.dumps(dict(
        rom='ref/Star Fox (USA).sfc', rom_sha256=SHA, cmd8_type=TEXPOLY_TYPE, window=WINDOW,
        units=dict(dispatch='01:8E3B', clip='01:988B', divide='01:814D', raster='01:A3B2', texel_loop='01:A4D2',
                   recip='00:9647'),
        program_words=code_words, ram_slots={n: hex(v) for n, v in S.items()}, **info), indent=1) + '\n')
    print(f'SVP_TexPoly: {code_words} program WORDs; production atlas {info["atlas_rows"]} rows '
          f'({info["atlas_bytes"]} bytes), {len(info["textures"])} textures, {len(info["materials"])} materials')


if __name__ == '__main__':
    main()
