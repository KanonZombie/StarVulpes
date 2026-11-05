"""Own SVP12: original BSP walk, face visibility, face colour and 32-byte face packets.

Moves from the 68000 (src/render/intro_mesh.asm M4FastFacesBegin/M4FastNode/M4FastGroup/M4FastFace,
M4MeshColourSetup light/level, M4FaceColour) to the SVP. cmd12 = this job, then the unchanged cmd10
(SVP_Faces) on the packets it produced:

  input   MAILBOX word 10 = N job slots, in DRAM at the END of the face array: job j at
          M4_FACE_INPUT + (511 - j) * 32 (16 WORDs), in draw order; words 13/14 as cmd10.
  job     WORD0 >= $8000: object job   $8001 BSP walk, $8002 face list (see below)
          WORD0 bit 14 ($4000 | object): packet emitted only when the object is near (particles)
          otherwise: a ready 32-byte packet, copied verbatim (sprites, radio/text records, kind 34)
  object job words (written by the 68000, src/render/intro_mesh.asm M4BspJob):
          1 object index in this tick's SVP9 output / pose list
          2 colframe (bits 0..6) | $100 explosion packet | $200 shadow colour 9
          3,4 colour table (68000 byte address, long)       5,6 the four depth-table bytes
          7,8 BSP nodes / face list (byte address)           9,10 BSP group table
          11 node count / face count   12 record stride in WORDs
          13 explosion scale (object byte 19)   14 WORD offset of the normal inside a record
  output  packets at M4_FACE_INPUT from slot 0, in order; MAILBOX word 15 = packet count (0xE2xx
          error code instead when the answer is 0xFFFF); then cmd10 runs as always (word 10 =
          polygons). The echo (word 2) is N, what the 68000 asked for.

Per-object light, depth level, matrix and visibility flags come from SVP9's output block
(DRAM base+0..8 matrix, +10 visibility count, +11 near flag, +436 flags) and the pose list, exactly
as the 68000 reference read them (M4IntroGeometryLoad, M4MeshColourSetup). Colour pool: SVP_BspPool,
one WORD per byte of M4ColourPool (descriptor offsets unchanged).

Usage: generate-svp-bsp.py [--out DIR] [--inc-dir DIR]; writes svp-bsp.inc and svp-bsp-rom.inc.
"""
import argparse
import re
from pathlib import Path

# ----------------------------------------------------------------------------- SSP1601 assembler (own, minimal)
# Encodings follow tools/ssp_sim.py (the Genesis Plus GX decoder) and the other generators. One call = one instruction;
# the same item list is written as asm68k text (labels and expressions resolved by the 68000 assembler) and can be
# assembled in-process (tests). Genesis Plus GX idle-loop hack (ssp16.c read_PM4): an instruction that reads PM4 at byte
# $0854 or $4F12 would park the SSP when the read returns 0; before every PM4-reading instruction a NOP assembles only
# when it would land on one of those addresses (same guard as tools/generate-intro-geometry.py).
HAZARD_PCS = (0x0854, 0x4f12)

KIND_SHORT = dict(sub=0x3800, cmp=0x7800, add=0x9800, and_=0xb800, or_=0xd800, xor=0xf800)
KIND_LONG = dict(sub=0x2800, cmp=0x6800, add=0x8800, and_=0xa800, or_=0xc800, xor=0xe800)
KIND_SLOT = dict(sub=0x2600, cmp=0x6600, add=0x8600, and_=0xa600, or_=0xc600, xor=0xe600)
COND = dict(al=0x4c00, z=0x4d50, nz=0x4c50, n=0x4d70, nn=0x4c70)


def two_words(op):
    hi = op >> 9
    return hi in (0x04, 0x06, 0x24, 0x26) or ((hi & 0x0f) == 4 and (hi & 0x70) in (0x10, 0x30, 0x40, 0x50, 0x60, 0x70))


def reads_pm4(op):
    hi = op >> 9
    if hi == 0x00:
        return op not in (0, 0x37) and (op & 0x0f) == 12
    if hi in (0x02, 0x0a):
        return ((op >> 4) & 0x0f) == 12
    if (hi & 0x0f) == 0 and (hi & 0x70) in (0x10, 0x30, 0x40, 0x50, 0x60, 0x70):
        return (op & 0x0f) == 12
    return False


def ptr_code(reg, mod=''):
    """reg 0..2 (RAM A) or 4..6 (RAM B); mod '', '+' (post-increment), '-' (post-decrement)."""
    assert reg in (0, 1, 2, 4, 5, 6), reg
    code = (reg & 3) | (0x100 if reg >= 4 else 0)
    return code | {'': 0, '+': 0x04, '-': 0x08}[mod]


class Asm:
    def __init__(self, guard=True):
        self.items = []  # ('label', name) | ('ins', [words], reads_pm4)
        self.guard = guard
        self.n = 0

    # ---- structure
    def label(self, name):
        self.items.append(('label', name))

    def ins(self, *words):
        op = words[0]
        assert isinstance(op, int), words
        n = 2 if two_words(op) else 1
        assert len(words) == n, (hex(op), words)
        self.items.append(('ins', list(words), self.guard and reads_pm4(op)))

    # ---- accumulator / RAM
    def clr(self): self.ins(0xe003)
    def lda(self, s): self.ins(0xe003); self.ins(0x0600 | s)        # A = RAM[s] << 16 (low half cleared)
    def LD(self, s): self.ins(0x0600 | s)                           # A_hi = RAM[s], A_lo kept
    def st(self, s): self.ins(0x0e00 | s)                           # RAM[s] = A_hi
    def tst(self): self.ins(0xa800, 0xffff)                         # flags from A_hi, A_lo cleared

    def _imm(self, kind, v):
        if isinstance(v, int) and 0 <= v < 256:
            self.ins(KIND_SHORT[kind] | v)
        else:
            self.ins(KIND_LONG[kind], v)

    def cmpi(self, v): self._imm('cmp', v)
    def subi(self, v): self._imm('sub', v)
    def addi(self, v): self._imm('add', v)
    def andi(self, v): self._imm('and_', v)
    def ori(self, v): self._imm('or_', v)
    def xori(self, v): self._imm('xor', v)

    def _slot(self, kind, s): self.ins(KIND_SLOT[kind] | s)
    def cmp(self, s): self._slot('cmp', s)
    def sub(self, s): self._slot('sub', s)
    def add(self, s): self._slot('add', s)
    def and_(self, s): self._slot('and_', s)
    def or_(self, s): self._slot('or_', s)
    def xor(self, s): self._slot('xor', s)

    def shl(self, n=1):
        for _ in range(n): self.ins(0x9003)
    def sar(self, n=1):
        for _ in range(n): self.ins(0x9002)
    def neg(self): self.ins(0x9006)
    def abs(self): self.ins(0x9007)

    def ldi(self, v): self.ins(0x0830, v)                           # A_hi = imm
    def lda_i(self, v): self.ins(0xe003); self.ins(0x0830, v)       # A = imm << 16

    # ---- registers
    def x_a(self): self.ins(0x0013)
    def y_a(self): self.ins(0x0023)
    def a_x(self): self.ins(0x0031)
    def a_y(self): self.ins(0x0032)
    def x_i(self, v): self.ins(0x0810, v)
    def y_i(self, v): self.ins(0x0820, v)
    def a_p(self): self.ins(0x0037)                                 # A = P (32 bits) = 2*X*Y
    def a_al(self): self.ins(0x003f)                                # A_hi = A_lo
    def al_a(self): self.ins(0x00f3)                                # A_lo = A_hi
    def add_p(self): self.ins(0x8007)                               # A += P
    def sub_p(self): self.ins(0x2007)

    # ---- pointer registers
    def r_i(self, r, v): self.ins(0x1800 | (r << 8) | v)            # r(0..7) = imm8
    def r_a(self, r): self.ins(0x1430 | (r & 3) | (0x100 if r >= 4 else 0))   # r = A_hi & 255
    def a_r(self, r): self.ins(0x1230 | (r & 3) | (0x100 if r >= 4 else 0))   # A_hi = r
    def a_ptr(self, r, mod=''): self.ins(0x0230 | ptr_code(r, mod))
    def ptr_a(self, r, mod=''): self.ins(0x0430 | ptr_code(r, mod))
    def x_ptr(self, r, mod=''): self.ins(0x0210 | ptr_code(r, mod))
    def y_ptr(self, r, mod=''): self.ins(0x0220 | ptr_code(r, mod))
    def ptr_pm4(self, r, mod='+'): self.ins(0x04c0 | ptr_code(r, mod))   # (r) = PM4 read
    def pm4_ptr(self, r, mod='+'): self.ins(0x02c0 | ptr_code(r, mod))   # PM4 write = (r)
    def ptr_i(self, r, mod, v): self.ins(0x0c00 | ptr_code(r, mod), v)

    def mld(self, ra, moda, rb, modb):
        self.ins(0xb700 | (ra & 3) | {'': 0, '+': 4, '-': 8}[moda] | (((rb - 4) & 3) << 4) | {'': 0, '+': 0x40, '-': 0x80}[modb])

    def mpya(self, ra, moda, rb, modb):
        self.ins(0x9700 | (ra & 3) | {'': 0, '+': 4, '-': 8}[moda] | (((rb - 4) & 3) << 4) | {'': 0, '+': 0x40, '-': 0x80}[modb])

    # ---- PM4
    def pm_addr(self): self.ins(0x00e3)                              # PMC = A_hi
    def pmc_i(self, v): self.ins(0x08e0, v)
    def pm_read_prog(self): self.ins(0x000c)
    def pm_write_prog(self): self.ins(0x00c0)
    def pm_get(self): self.ins(0x003c)                               # A_hi = PM4 (read stream)
    def pm_put(self): self.ins(0x00c3)                               # PM4 write stream = A_hi
    def pm_copy(self):
        # ED Pro: separate external read/write strobes. 00CC corrupts raw
        # packets on Nomad; hw82 passes with these two transfers (round26).
        self.pm_get()
        self.pm_put()

    def read_dram_i(self, expr):
        """Read stream over DRAM word `expr`, post-increment (3 PMC steps)."""
        self.ldi(expr); self.pm_addr(); self.pmc_i(0x0818); self.pm_read_prog()

    def read_dram_a(self):
        """A_hi = DRAM word address."""
        self.pm_addr(); self.pmc_i(0x0818); self.pm_read_prog()

    # ---- control flow
    def br(self, label, cond='al'): self.ins(COND[cond], label + '/2')
    def call(self, label): self.ins(0x4800, label + '/2')
    def ret(self): self.ins(0x0065)

    # ---- output
    def words_text(self):
        lines = []
        cur = []

        def flush():
            nonlocal cur
            if cur:
                lines.append('        dc.w ' + ','.join(cur))
                cur = []
        for it in self.items:
            if it[0] == 'label':
                flush(); lines.append(it[1] + ':')
                continue
            _, words, rd = it
            if rd:
                flush()
                lines += ['        if (*=$%04x)|(*=$%04x)' % HAZARD_PCS, '        dc.w 0', '        endif']
            for w in words:
                s = '$%04x' % (w & 0xffff) if isinstance(w, int) else w
                if cur and (len(cur) >= 12 or len(','.join(cur + [s])) > 200):
                    flush()
                cur.append(s)
        flush()
        return lines

    def assemble(self, base_word, symbols):
        """-> (list of words, labels dict name -> word address). symbols: name -> value (68000 view)."""
        labels, out, addr = {}, [], base_word
        # pass 1: addresses (guard NOPs depend on them)
        pending = []
        for it in self.items:
            if it[0] == 'label':
                labels[it[1]] = addr
                continue
            _, words, rd = it
            if rd and addr * 2 in HAZARD_PCS:
                pending.append(0)
                addr += 1
            pending.extend(words)
            addr += len(words)
        env = dict(symbols)
        env.update({k: v * 2 for k, v in labels.items()})  # byte addresses, as the 68000 assembler sees them
        for w in pending:
            out.append(w & 0xffff if isinstance(w, int) else evaluate(w, env) & 0xffff)
        return out, labels


def evaluate(expr, env):
    e = re.sub(r'\$([0-9a-fA-F]+)', r'0x\1', expr)
    e = e.replace('/', '//')
    return eval(e, {'__builtins__': {}}, env)


# ----------------------------------------------------------------------------- the SVP12 program
ROOT = Path(__file__).resolve().parents[1]

# ----------------------------------------------------------------------------- RAM slots
_names = {}


def slots(base, names):
    for i, n in enumerate(names.split()):
        _names[n] = base + i


slots(0x00, 'SEQ N JOB OUT ERR ITA LIM AT T0 T1 T2 T3 T4 T5 T6 T7')
slots(0x10, 'IT0 IT1 IT2 IT3 IT4 IT5 IT6 IT7 IT8 IT9 IT10 IT11 IT12 IT13 IT14 IT15')
slots(0x20, 'GEOW POSEW NEAR VC KIND LEVEL LV10 COLFR MODE EXP STR NRM CTP CTL BSPP BSPL GRPP GRPL NODES NRMPTR')
slots(0x34, 'WPG WLO NN GG FC FN FV FM COL BIGZ VIEW CPG CLO KEY CLIT FSYNC BCR OBJN OBJT')
MX, POSE, LA = 0x48, 0x58, 0x70
# RAM A arrays: matrix, pose, light << 8
STACK_TOP = 0xbf                         # BSP stack, RAM A 0x80..0xbf, grows down through r2
BCACHE = 0x80                            # RAM B r6 index of the colour cache: 32 entries (key, colour)
BVIS = 0x00                              # RAM B r4 index of the visibility flags (B 0x100..0x13f)
BREC = 0x40                              # RAM B r4/r5 index of the face record words (B 0x140..)
S = type('S', (), _names)
assert S.FSYNC < MX

FACE_WORD = '((M4_FACE_INPUT-$300000)/2)'
GEO_WORD = '((M4_GEO_OUTPUT-$300000)/2)'
POSE_WORD = '((M4_GEO_INPUT-$300000)/2)'
VIEW_WORD = '((M4_GEO_VIEW-$300000)/2)'
POOL_LO = '((SVP_BspPool/2)&$ffff)'
POOL_MODE = '($0800|((SVP_BspPool/2)>>16))'
ERR_VIS, ERR_NODE, ERR_FACE, ERR_JOBS, ERR_STACK = 0xe101, 0xe203, 0xe204, 0xe210, 0xe211


def faces_variant(a, SW):
    """Face loop for records of SW WORDs: n, vis, material, SL index slots, then the normal (3 WORDs, none for 7)."""
    SL = 8 if SW == 14 else 4
    TL = SW - 3 - SL
    X = lambda name: f'SVP_BspF{SW}{name}'
    L = a.label

    def zeros(cnt):
        for _ in range(cnt):
            a.pm_put()
    L(f'SVP_BspF{SW}')
    L(X('Loop'))
    a.r_i(1, S.FN)
    for _ in range(3):
        a.ptr_pm4(1, '+')                                         # n, vis, material -> FN FV FM
    a.lda(S.FV); a.cmpi(255); a.br(X('Vis'), 'z')
    a.r_a(4); a.a_ptr(4); a.tst(); a.br(X('Cull'), 'z')
    L(X('Vis'))
    a.lda(S.OUT); a.cmp(S.LIM); a.br('SVP_BspFailFace', 'nn')
    a.lda(S.FN); a.subi(2); a.br('SVP_BspFailFace', 'n')
    a.cmpi(SL - 1); a.br('SVP_BspFailFace', 'nn')                 # n in 2..SL (the 68000 allows 2..8; the data never exceeds SL)
    # colour cache (this object, direct mapped on the material): key = material | object number << 8
    a.lda(S.FM); a.add(S.OBJT); a.st(S.KEY)
    a.lda(S.FM); a.andi(31); a.shl(1); a.addi(BCACHE); a.r_a(6)
    a.clr(); a.a_ptr(6, '+'); a.cmp(S.KEY); a.br(X('Miss'), 'nz')
    # ---- cached colour: stream straight into the packet
    a.LD(S.FN); a.pm_put(); a.a_ptr(6); a.pm_put(); a.LD(S.GEOW); a.pm_put(); a.LD(S.KIND); a.pm_put()
    a.clr(); zeros(4)
    a.lda(S.FN); a.cmpi(2); a.br(X('H2'), 'z'); a.cmpi(3); a.br(X('H3'), 'z'); a.cmpi(4); a.br(X('H4'), 'z')
    if SL == 8:
        # n >= 5: generic loops
        a.st(S.T0)
        L(X('HGenIdx'))
        a.pm_get(); a.sar(1); a.pm_put(); a.lda(S.T0); a.subi(1); a.st(S.T0); a.br(X('HGenIdx'), 'nz')
        a.lda(S.FN); a.neg(); a.addi(SL); a.st(S.T0); a.br(X('HGenSkipped'), 'z')
        L(X('HGenSkip'))
        a.pm_read_prog(); a.lda(S.T0); a.subi(1); a.st(S.T0); a.br(X('HGenSkip'), 'nz')
        L(X('HGenSkipped'))
        a.lda(S.FN); a.neg(); a.addi(8); a.st(S.T0); a.br(X('HTail'), 'z')
        L(X('HGenPad'))
        a.clr(); a.pm_put(); a.lda(S.T0); a.subi(1); a.st(S.T0); a.br(X('HGenPad'), 'nz')
        a.br(X('HTail'))
    else:
        a.br('SVP_BspFailFace')
    for n in (2, 3, 4):
        L(X(f'H{n}'))
        for _ in range(n):
            a.pm_get(); a.sar(1); a.pm_put()
        for _ in range(SL - n):
            a.pm_read_prog()
        a.clr(); zeros(8 - n)
        a.br(X('HTail'))
    L(X('HTail'))
    for _ in range(TL):
        a.pm_read_prog()
    a.lda(S.OUT); a.addi(1); a.st(S.OUT)
    a.br(X('Next'))
    # ---- culled: skip the record
    L(X('Cull'))
    for _ in range(SW - 3):
        a.pm_read_prog()
    L(X('Next'))
    a.lda(S.FC); a.subi(1); a.st(S.FC); a.br(X('Loop'), 'nz')
    a.ret()
    # ---- colour lookup: the face goes to RAM, the lookup moves the stream (r6 = cache entry + 1)
    L(X('Miss'))
    a.r_i(5, BREC)
    for _ in range(SW - 3):
        a.ptr_pm4(5, '+')
    a.lda(S.MODE); a.andi(0x200); a.br(X('MColour'), 'z')
    a.ldi(9); a.st(S.COL); a.br(X('MColDone'))
    L(X('MColour'))
    a.call('SVP_BspColour')
    a.lda(S.MODE); a.andi(0x100); a.br(X('MColDone'), 'nz')        # explosion faces: not cached
    a.lda(S.CLIT); a.tst(); a.br(X('MColDone'), 'nz')              # lit colours depend on the normal: not cached
    # Fusion 3.64 decrements r6 but does not store into B[r6] for (r6-).
    # The cached colour stays zero (boot microprobe in evidence/).
    # Use an unmodified store and move the pointer explicitly (same on SSP).
    a.LD(S.COL); a.ptr_a(6)
    a.a_r(6); a.subi(1); a.r_a(6)
    a.LD(S.KEY); a.ptr_a(6)
    L(X('MColDone'))
    a.LD(S.FN); a.pm_put(); a.LD(S.COL); a.pm_put(); a.LD(S.GEOW); a.pm_put(); a.LD(S.KIND); a.pm_put()
    a.lda(S.MODE); a.andi(0x100); a.br(X('MNoExp'), 'z')
    a.LD(S.EXP); a.pm_put(); a.r_i(5, BREC + 4)
    for _ in range(3):
        a.a_ptr(5, '+'); a.pm_put()
    a.br(X('MIdx'))
    L(X('MNoExp'))
    a.clr(); zeros(4)
    L(X('MIdx'))
    a.r_i(5, BREC)
    a.lda(S.FN); a.cmpi(2); a.br(X('M2'), 'z'); a.cmpi(3); a.br(X('M3'), 'z'); a.cmpi(4); a.br(X('M4'), 'z')
    a.st(S.T0)
    L(X('MGenIdx'))
    a.a_ptr(5, '+'); a.sar(1); a.pm_put(); a.lda(S.T0); a.subi(1); a.st(S.T0); a.br(X('MGenIdx'), 'nz')
    a.lda(S.FN); a.neg(); a.addi(8); a.st(S.T0); a.br(X('MDone'), 'z')
    L(X('MGenPad'))
    a.clr(); a.pm_put(); a.lda(S.T0); a.subi(1); a.st(S.T0); a.br(X('MGenPad'), 'nz')
    a.br(X('MDone'))
    for n in (2, 3, 4):
        L(X(f'M{n}'))
        for _ in range(n):
            a.a_ptr(5, '+'); a.sar(1); a.pm_put()
        a.clr(); zeros(8 - n)
        a.br(X('MDone'))
    L(X('MDone'))
    a.lda(S.OUT); a.addi(1); a.st(S.OUT)
    # re-seat the stream at the next face: sync point + (faces read since + 1) * SW
    a.lda(S.FSYNC); a.sub(S.FC); a.addi(1); a.x_a(); a.y_i(SW); a.a_p(); a.a_al(); a.sar(1)
    a.call('SVP_BspAdv')
    a.LD(S.WLO); a.pm_addr(); a.LD(S.WPG); a.pm_addr(); a.pm_read_prog()
    a.lda(S.FC); a.subi(1); a.st(S.FSYNC)
    a.br(X('Next'))


def build():
    a = Asm()
    L = a.label

    def prog():
        """Read stream over ROM at WPG:WLO (WPG = $0800|page, WLO = word address & $ffff)."""
        a.LD(S.WLO); a.pm_addr(); a.LD(S.WPG); a.pm_addr(); a.pm_read_prog()

    def rd(slot):
        """slot = next PM4 word (A = clean)."""
        a.clr(); a.pm_get(); a.st(slot)

    def copy_ptr(dst_pg, dst_lo, src_hi, src_lo):
        a.LD(src_hi); a.st(S.T0); a.LD(src_lo); a.st(S.T1); a.call('SVP_BspCvt')
        a.LD(S.T2); a.st(dst_pg); a.LD(S.T3); a.st(dst_lo)

    # ------------------------------------------------------------------ entry
    L('SVP_Bsp')
    a.a_y(); a.st(S.SEQ)
    a.pmc_i(10); a.pmc_i(0x0018); a.pm_read_prog(); a.clr(); a.pm_get(); a.st(S.N)
    a.tst(); a.br('SVP_BspBadJobs', 'z'); a.br('SVP_BspBadJobs', 'n')
    a.cmpi(513); a.br('SVP_BspBadJobs', 'nn')
    a.lda(S.N); a.st(S.JOB)
    a.neg(); a.addi(512); a.st(S.LIM)
    a.clr(); a.st(S.OUT); a.st(S.ERR)
    a.ldi(FACE_WORD + '+8176'); a.st(S.ITA)
    a.r_i(6, BCACHE)
    for _ in range(64):
        a.ptr_i(6, '+', 0)                                        # colour cache: keys 0 never match (object numbers start at 1)
    a.clr(); a.st(S.OBJN)
    a.ldi(FACE_WORD); a.pm_addr(); a.pmc_i(0x0818); a.pm_write_prog()

    # ------------------------------------------------------------------ job loop
    L('SVP_BspItem')
    a.lda(S.JOB); a.cmpi(1); a.br('SVP_BspNotLast', 'nz')
    a.ldi(512); a.st(S.LIM)                                  # the last job: every earlier slot is free
    L('SVP_BspNotLast')
    a.LD(S.ITA); a.pm_addr(); a.pmc_i(0x0818); a.pm_read_prog()
    a.lda(S.ITA); a.subi(16); a.st(S.ITA)
    a.clr(); a.pm_get(); a.st(S.IT0)
    a.cmpi(0x8001); a.br('SVP_BspObject', 'z')
    a.cmpi(0x8002); a.br('SVP_BspObject', 'z')
    a.lda(S.IT0); a.andi(0x4000); a.br('SVP_BspRawCond', 'nz')
    # raw packet: copy 16 WORDs
    L('SVP_BspRaw')
    a.lda(S.OUT); a.cmp(S.LIM); a.br('SVP_BspFailFace', 'nn')
    a.LD(S.IT0); a.pm_put()
    for _ in range(15):
        a.pm_copy()
    a.lda(S.OUT); a.addi(1); a.st(S.OUT)
    L('SVP_BspNext')
    a.lda(S.JOB); a.subi(1); a.st(S.JOB); a.br('SVP_BspItem', 'nz')
    L('SVP_BspDone')
    a.pmc_i(15); a.pmc_i(0x0018); a.pm_write_prog(); a.lda(S.OUT); a.pm_put()
    a.lda(S.OUT); a.st(2); a.lda(S.N); a.st(3)               # hand over to cmd10: slot 2 = faces, slot 3 = echo
    a.br('SVP_FaceCountValid')

    # particles: only when the object is near (the 68000 reference skips far/behind objects)
    L('SVP_BspRawCond')
    a.lda(S.IT0); a.andi(0x3fff); a.x_a(); a.y_i(256); a.a_p(); a.a_al(); a.addi(GEO_WORD + '+11')
    a.pm_addr(); a.pmc_i(0x0818); a.pm_read_prog(); a.clr(); a.pm_get(); a.tst(); a.br('SVP_BspNext', 'z')
    a.lda(S.ITA); a.addi(17); a.pm_addr(); a.pmc_i(0x0818); a.pm_read_prog()     # job word 1
    a.lda(S.OUT); a.cmp(S.LIM); a.br('SVP_BspFailFace', 'nn')
    a.clr(); a.pm_put()
    for _ in range(15):
        a.pm_copy()
    a.lda(S.OUT); a.addi(1); a.st(S.OUT)
    a.br('SVP_BspNext')

    # ------------------------------------------------------------------ object job
    L('SVP_BspObject')
    a.r_i(0, 0x11)
    for _ in range(15):
        a.ptr_pm4(0, '+')
    # geometry block, pose record
    a.lda(S.IT1); a.x_a(); a.y_i(256); a.a_p(); a.a_al(); a.addi(GEO_WORD); a.st(S.GEOW)
    a.lda(S.IT1); a.shl(3); a.st(S.T0); a.lda(S.IT1); a.add(S.T0); a.addi(POSE_WORD); a.st(S.POSEW)
    a.lda(S.GEOW); a.addi(10); a.read_dram_a()
    rd(S.VC); rd(S.NEAR)
    a.lda(S.VC); a.tst(); a.br('SVP_BspFailVis', 'n')
    a.cmpi(65); a.br('SVP_BspFailVis', 'nn')
    a.lda(S.NEAR); a.tst(); a.br('SVP_BspNext', 'z')            # behind the near plane: nothing (M4MeshStart)
    a.lda(S.OBJN); a.addi(1); a.st(S.OBJN); a.shl(8); a.st(S.OBJT)
    # visibility flags -> RAM B 0x100..
    a.lda(S.VC); a.tst(); a.br('SVP_BspVisDone', 'z')
    a.st(S.T0)
    a.lda(S.GEOW); a.addi(436); a.read_dram_a(); a.r_i(4, BVIS)
    L('SVP_BspVisLoop')
    a.ptr_pm4(4, '+'); a.lda(S.T0); a.subi(1); a.st(S.T0); a.br('SVP_BspVisLoop', 'nz')
    L('SVP_BspVisDone')
    # pose (9 WORDs) and object matrix (9 WORDs)
    a.lda(S.POSEW); a.read_dram_a(); a.r_i(0, POSE)
    for _ in range(9):
        a.ptr_pm4(0, '+')
    a.lda(S.GEOW); a.read_dram_a(); a.r_i(0, MX)
    for _ in range(9):
        a.ptr_pm4(0, '+')
    # Match the full geometry id; only bit 15 marks a shadow. Truncating
    # model 265 to 9 would turn an ordinary face into a particle emitter.
    # AND clears AL too, so LD needs no preceding accumulator clear.
    a.LD(POSE); a.andi(0x7fff); a.st(S.KIND)
    a.read_dram_i(VIEW_WORD); rd(S.VIEW)
    # depth level: bigz = pose z (view) or fq(z, $7FFE) (intro)
    a.lda(S.VIEW); a.tst(); a.br('SVP_BspBigzView', 'nz')
    a.lda(POSE + 5); a.x_a(); a.y_i(0x7ffe); a.a_p(); a.st(S.BIGZ); a.br('SVP_BspBigzDone')
    L('SVP_BspBigzView')
    a.lda(POSE + 5); a.st(S.BIGZ)
    L('SVP_BspBigzDone')
    a.lda(S.IT5); a.andi(0xff00); a.add(S.BIGZ); a.br('SVP_BspLevel0', 'n')
    a.lda(S.IT5); a.shl(8); a.add(S.BIGZ); a.br('SVP_BspLevel1', 'n')
    a.lda(S.IT6); a.andi(0xff00); a.add(S.BIGZ); a.br('SVP_BspLevel2', 'n')
    a.ldi(3); a.br('SVP_BspLevelSet')
    L('SVP_BspLevel0'); a.ldi(0); a.br('SVP_BspLevelSet')
    L('SVP_BspLevel1'); a.ldi(1); a.br('SVP_BspLevelSet')
    L('SVP_BspLevel2'); a.ldi(2)
    L('SVP_BspLevelSet')
    a.st(S.LEVEL); a.shl(1); a.st(S.T0); a.shl(2); a.add(S.T0); a.st(S.LV10)      # level * 10 (2l, 8l + 2l)
    # light vector << 8 (HIB of the three row sums), RAM A LA..LA+2
    a.lda(S.VIEW); a.tst(); a.br('SVP_BspLightView', 'nz')
    a.lda(POSE + 6); a.tst(); a.br('SVP_BspLightIntro', 'nz')
    a.lda(POSE + 8); a.tst(); a.br('SVP_BspLightIntro', 'nz')
    a.lda(POSE + 7); a.tst(); a.br('SVP_BspLightId', 'z')
    a.cmpi(0x80); a.br('SVP_BspLightIntro', 'nz')
    a.ldi(0xb600); a.st(LA); a.st(LA + 2); a.ldi(0x4900); a.st(LA + 1); a.br('SVP_BspLightDone')     # (-74, 73, -74)
    L('SVP_BspLightId')
    a.ldi(0x4900); a.st(LA); a.st(LA + 1); a.st(LA + 2); a.br('SVP_BspLightDone')                    # (73, 73, 73)
    L('SVP_BspLightView')
    a.y_i(0x49e5); a.r_i(0, MX)
    for row in range(3):
        a.clr(); a.st(S.T0)
        for _ in range(3):
            a.x_ptr(0, '+'); a.a_p(); a.add(S.T0); a.st(S.T0)
        a.lda(S.T0); a.andi(0xff00); a.st(LA + row)
    a.br('SVP_BspLightDone')
    L('SVP_BspLightIntro')
    a.r_i(0, MX)
    for row in range(3):
        a.clr(); a.st(S.T0)
        for _ in range(3):
            a.y_i(0x7ffe); a.x_ptr(0, '+'); a.a_p(); a.x_a(); a.y_i(0x49e5); a.a_p(); a.add(S.T0); a.st(S.T0)
        a.lda(S.T0); a.andi(0xff00); a.st(LA + row)
    L('SVP_BspLightDone')
    # job parameters
    a.lda(S.IT2); a.andi(0x7f); a.st(S.COLFR); a.lda(S.IT2); a.andi(0x300); a.st(S.MODE)
    a.LD(S.IT13); a.st(S.EXP); a.LD(S.IT12); a.st(S.STR)
    a.lda(S.IT14); a.st(S.NRM); a.addi(BREC - 3); a.st(S.NRMPTR)
    copy_ptr(S.CTP, S.CTL, S.IT3, S.IT4)
    a.lda(S.IT0); a.cmpi(0x8002); a.br('SVP_BspList', 'z')
    copy_ptr(S.BSPP, S.BSPL, S.IT7, S.IT8)
    copy_ptr(S.GRPP, S.GRPL, S.IT9, S.IT10)
    a.LD(S.IT11); a.st(S.NODES)
    a.LD(S.BSPP); a.st(S.WPG); a.LD(S.BSPL); a.st(S.WLO)
    a.lda(S.NODES); a.shl(2); a.add(S.NODES); a.call('SVP_BspAdv')
    a.lda(S.WPG); a.sub(S.BSPP); a.st(S.BCR)                       # 0: the nodes stay in one page
    a.call('SVP_BspWalk')
    a.br('SVP_BspNext')
    L('SVP_BspList')
    copy_ptr(S.WPG, S.WLO, S.IT7, S.IT8)
    a.LD(S.IT11); a.st(S.FC); a.st(S.FSYNC)
    prog()
    a.call('SVP_BspFaces')
    a.br('SVP_BspNext')


    # ------------------------------------------------------------------ helpers
    # T0 = high WORD, T1 = low WORD of a 68000 byte address -> T2 = $0800|page, T3 = word address & $ffff
    L('SVP_BspCvt')
    a.lda(S.T1); a.sar(1); a.andi(0x7fff); a.st(S.T3)
    a.lda(S.T0); a.andi(1); a.br('SVP_BspCvtLow', 'z')
    a.lda(S.T3); a.ori(0x8000); a.st(S.T3)
    L('SVP_BspCvtLow')
    a.lda(S.T0); a.sar(1); a.andi(0x0f); a.ori(0x0800); a.st(S.T2)
    a.ret()
    # (WPG,WLO) += A (0..32767), carrying into the page: a table may cross a 64K-WORD page
    for name, lo, pg in (('SVP_BspAdv', S.WLO, S.WPG), ('SVP_BspAdvC', S.CLO, S.CPG)):
        L(name)
        a.st(S.AT); a.add(lo); a.st(lo); a.tst(); a.br(name + 'Done', 'n')
        a.sub(S.AT); a.br(name + 'Done', 'nn')
        a.lda(pg); a.addi(1); a.st(pg)
        L(name + 'Done')
        a.ret()

    # ------------------------------------------------------------------ BSP walk (M4FastNode)
    L('SVP_BspWalk')
    a.r_i(2, STACK_TOP); a.ldi(0xffff); a.ptr_a(2, '-')       # sentinel
    a.clr(); a.st(S.NN)
    L('SVP_BspNode')
    a.lda(S.NN); a.tst(); a.br('SVP_BspFailNode', 'n')
    a.cmp(S.NODES); a.br('SVP_BspFailNode', 'nn')
    a.lda(S.BCR); a.tst(); a.br('SVP_BspNodeCross', 'nz')
    a.lda(S.NN); a.shl(2); a.add(S.NN); a.add(S.BSPL)           # 5 WORDs per node
    a.pm_addr(); a.LD(S.BSPP); a.pm_addr(); a.pm_read_prog()
    a.br('SVP_BspNodeRead')
    L('SVP_BspNodeCross')
    a.lda(S.NN); a.shl(2); a.add(S.NN); a.st(S.T7)
    a.LD(S.BSPP); a.st(S.WPG); a.LD(S.BSPL); a.st(S.WLO)
    a.LD(S.T7); a.call('SVP_BspAdv'); prog()
    L('SVP_BspNodeRead')
    a.r_i(1, S.T0)
    for _ in range(5):
        a.ptr_pm4(1, '+')
    a.lda(S.T0); a.cmpi(40); a.br('SVP_BspSplit', 'z')
    a.cmpi(64); a.br('SVP_BspPop', 'z')
    a.cmpi(68); a.br('SVP_BspLeaf', 'z')
    a.br('SVP_BspFailNode')
    L('SVP_BspLeaf')
    a.LD(S.T2); a.st(S.GG); a.call('SVP_BspGroup'); a.br('SVP_BspPop')
    L('SVP_BspSplit')
    a.lda(S.T1); a.r_a(4); a.a_ptr(4); a.tst(); a.br('SVP_BspInvisible', 'z')
    # visible: first child (T3) now, then the group, then the second child when >= 0
    a.lda(S.T4); a.tst(); a.br('SVP_BspVisNoSecond', 'n')
    a.ptr_a(2, '-')
    L('SVP_BspVisNoSecond')
    a.lda(S.T2); a.ori(0x8000); a.ptr_a(2, '-')
    a.LD(S.T3); a.st(S.NN); a.br('SVP_BspNode')
    # invisible: the second child first when >= 0, then the first child; the group is not drawn
    L('SVP_BspInvisible')
    a.lda(S.T4); a.tst(); a.br('SVP_BspInvFirst', 'n')
    a.lda(S.T3); a.ptr_a(2, '-')
    a.LD(S.T4); a.st(S.NN); a.br('SVP_BspNode')
    L('SVP_BspInvFirst')
    a.LD(S.T3); a.st(S.NN); a.br('SVP_BspNode')
    L('SVP_BspPop')
    a.a_ptr(2, '+'); a.clr(); a.a_ptr(2)                       # r2 + 1, then the entry
    a.tst(); a.br('SVP_BspPopNode', 'nn')
    a.cmpi(0xffff); a.br('SVP_BspWalkEnd', 'z')
    a.st(S.T0); a.lda(S.T0); a.andi(0x7fff); a.st(S.GG); a.call('SVP_BspGroup'); a.br('SVP_BspPop')
    L('SVP_BspPopNode')
    a.st(S.NN); a.br('SVP_BspNode')
    L('SVP_BspWalkEnd')
    a.ret()

    # ------------------------------------------------------------------ group (M4FastGroup)
    L('SVP_BspGroup')
    a.lda(S.GG); a.shl(1); a.st(S.T7)
    a.LD(S.GRPP); a.st(S.WPG); a.LD(S.GRPL); a.st(S.WLO)
    a.LD(S.T7); a.call('SVP_BspAdv'); prog()
    rd(S.T0); rd(S.T1)
    a.call('SVP_BspCvt')
    a.LD(S.T2); a.st(S.WPG); a.LD(S.T3); a.st(S.WLO)
    prog(); rd(S.FC)
    a.tst(); a.br('SVP_BspGroupEmpty', 'z'); a.br('SVP_BspGroupEmpty', 'n')
    a.st(S.FSYNC)
    a.ldi(1); a.call('SVP_BspAdv')                               # sync point = face 0; the stream is already there
    a.br('SVP_BspFaces')
    L('SVP_BspGroupEmpty')
    a.ret()

    # ------------------------------------------------------------------ faces (M4FastFace, packet)
    # Entered with the ROM stream at face 0 and (WPG,WLO) = the sync point (face FSYNC-th from the end), FC = faces left.
    # The stream stays in step while faces are culled or reuse the cached colour (read WORD by WORD straight into the
    # packet); a colour lookup moves it, so that face is read into RAM first and the stream is re-seated after it.
    L('SVP_BspFaces')
    a.lda(S.STR); a.cmpi(14); a.br('SVP_BspF14', 'z')
    a.cmpi(10); a.br('SVP_BspF10', 'z')
    a.cmpi(7); a.br('SVP_BspF7', 'z')
    a.br('SVP_BspFailFace')
    for SW in (14, 10, 7):
        faces_variant(a, SW)

    # ------------------------------------------------------------------ colour (M4FaceColour)
    # in: FM material, LEVEL, LV10, COLFR, CTP/CTL, LA (light << 8), normal at RAM B NRMPTR; out: COL
    L('SVP_BspColour')
    a.clr(); a.st(S.CLIT)
    a.LD(S.CTP); a.st(S.CPG); a.LD(S.CTL); a.st(S.CLO); a.LD(S.FM); a.call('SVP_BspAdvC')
    a.LD(S.CLO); a.pm_addr(); a.LD(S.CPG); a.pm_addr(); a.pm_read_prog()
    rd(S.T5)                                                     # pool offset of the descriptor
    a.LD(S.T5); a.addi(POOL_LO); a.pm_addr(); a.pmc_i(POOL_MODE); a.pm_read_prog()
    rd(S.T6); rd(S.T7)                                           # type, second byte
    a.lda(S.T6); a.tst(); a.br('SVP_BspColFixed', 'z')
    a.cmpi(1); a.br('SVP_BspColDepth', 'z')
    a.cmpi(2); a.br('SVP_BspColLit', 'z')
    a.cmpi(4); a.br('SVP_BspColTex', 'z')
    a.cmpi(5); a.br('SVP_BspColTexAnim', 'z')
    a.cmpi(6); a.br('SVP_BspColAnimDepth', 'z')
    # animated: frame (n - 1) & colframe
    a.lda(S.T7); a.subi(1); a.and_(S.COLFR); a.andi(0xff); a.addi(2); a.br('SVP_BspColRead')
    L('SVP_BspColFixed')
    a.lda(S.T7); a.st(S.COL); a.ret()
    L('SVP_BspColTex')
    a.lda(S.T7); a.ori(0x8000); a.st(S.COL); a.ret()
    L('SVP_BspColDepth')
    a.lda(S.LEVEL); a.addi(2); a.br('SVP_BspColRead')
    L('SVP_BspColTexAnim')
    a.lda(S.T7); a.subi(1); a.and_(S.COLFR); a.andi(0xff); a.addi(2)
    a.call('SVP_BspColReadRaw'); a.ori(0x8000); a.st(S.COL); a.ret()
    L('SVP_BspColAnimDepth')
    # n, n HL, n rows L0..L3: row (colframe & (n - 1)) * 4 + n + level
    a.lda(S.T7); a.subi(1); a.and_(S.COLFR); a.andi(0xff); a.shl(2); a.add(S.T7); a.add(S.LEVEL); a.addi(2)
    L('SVP_BspColRead')
    a.call('SVP_BspColReadRaw'); a.st(S.COL); a.ret()
    # A = index inside the descriptor -> A = that pool byte
    L('SVP_BspColReadRaw')
    a.add(S.T5); a.addi(POOL_LO); a.pm_addr(); a.pmc_i(POOL_MODE); a.pm_read_prog(); a.clr(); a.pm_get(); a.ret()
    L('SVP_BspColLit')
    a.ldi(1); a.st(S.CLIT)
    # S = sum(n_i * L_i) mod 2^16 as the 68000 (muls.w + add.w per term); s = S >> 10 clamped 6..15
    a.r_i(0, LA); a.LD(S.NRMPTR); a.r_a(4)
    a.mld(0, '+', 4, '+'); a.mpya(0, '+', 4, '+'); a.mpya(0, '+', 4, '+'); a.add_p()   # S << 9 (L_i << 8)
    a.shl(7)                                                     # S << 16
    a.x_a(); a.y_i(32); a.a_p()                                  # hi = S >> 10
    a.subi(6); a.br('SVP_BspColLitLow', 'n'); a.cmpi(10); a.br('SVP_BspColLitOk', 'n'); a.ldi(9)
    L('SVP_BspColLitOk')
    a.add(S.LV10); a.addi(2); a.br('SVP_BspColRead')
    L('SVP_BspColLitLow')
    a.ldi(0); a.br('SVP_BspColLitOk')

    # ------------------------------------------------------------------ errors
    for name, code in (('SVP_BspBadJobs', ERR_JOBS), ('SVP_BspFailVis', ERR_VIS), ('SVP_BspFailNode', ERR_NODE),
                       ('SVP_BspFailFace', ERR_FACE)):
        L(name); a.ldi(code); a.br('SVP_BspFail')
    L('SVP_BspFail')
    a.st(S.ERR); a.pmc_i(15); a.pmc_i(0x0018); a.pm_write_prog(); a.pm_put(); a.br('SVP_GeoInvalid')
    L('SVP_BspEnd')
    return a


def pool_bytes(inc_dir):
    text = (Path(inc_dir) / 'intro-colours.inc').read_text(encoding='ascii').splitlines()
    out, on = [], False
    for line in text:
        s = line.strip()
        if s == 'M4ColourPool:':
            on = True
            continue
        if on:
            if s.startswith('dc.b'):
                out += [int(x.strip().lstrip('$'), 16) for x in s[4:].split(',')]
            elif s == 'even':
                break
    return out


def write_outputs(a, inc_dir, out_dir):
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    pool = pool_bytes(inc_dir)
    assert pool and len(pool) < 0x8000, len(pool)
    lines = ['; Generated by tools/generate-svp-bsp.py: SVP12 (BSP walk, face visibility/colour, packets). Do not edit.']
    lines += a.words_text()
    (out_dir / 'svp-bsp.inc').write_text('\n'.join(lines) + '\n', encoding='ascii')
    rom = ['; Generated by tools/generate-svp-bsp.py: M4ColourPool as one WORD per byte (read with PM4, one 64K-WORD page).',
           '        even', f'        if ((*+{2 * len(pool)}-1)>>17)<>(*>>17)', '        dcb.b ((*+$1ffff)&$fe0000)-*,0', '        endif',
           'SVP_BspPool:']
    for i in range(0, len(pool), 12):
        rom.append('        dc.w ' + ','.join('$%04x' % v for v in pool[i:i + 12]))
    rom += ['SVP_BspPoolEnd:']
    (out_dir / 'svp-bsp-rom.inc').write_text('\n'.join(rom) + '\n', encoding='ascii')
    return pool


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default=str(ROOT / 'build'))
    ap.add_argument('--inc-dir', default=str(ROOT / 'build'))
    args, _ = ap.parse_known_args()  # extract_sf.ps1 passes --vr-layout to every generator
    asm = build()
    pool = write_outputs(asm, args.inc_dir, args.out)
    words = sum(len(i[1]) for i in asm.items if i[0] == 'ins')
    print(f'Generated own SVP12: BSP walk and face packets ({words} instruction words, pool {len(pool)} bytes)')
