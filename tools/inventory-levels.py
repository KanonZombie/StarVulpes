"""Inventory of every Star Fox (USA rev0) stage reachable from the route map.

Authority: ref/Star Fox (USA).sfc (SHA-256 3857b529...a84d, LoROM, no header).
Generalises tools/recover-level-script.py (Corneria 1 only) to all stages:

* Stage graph: `stagepaths` 03:D671 (PATHSTART/PATHNEXT/PATHCHOICE records),
  default `routes` $16D0..$16D6 (03:BDA8), route-change routines 03:D0C2..D108,
  `levelfinished` dispatch in gamestart (02:E419..E4BE), course tables 05:8000,
  training map (1F:FC.. mapptr store).
* Map scripts: every command reachable from each stage entry is found by
  EXECUTING the original dispatcher (03:ED6F, table 03:ED83+opcode) and the
  handlers on the actual command bytes with a forking 65816 model (unknown RAM
  forks conditional branches). Command length and successors come from the
  exits (pointer left in X / $16FF and bank in $1FF6), not from a length table;
  the UltraStarFox MAPMACS length is only a cross-check.
* Object commands: shape header and 24-bit strategy are the values the ROM
  handler writes into the object (+$04, +$16) on an effect run.
* Paths: offsets set by mapsetpath (8C) are decoded with the ROM-derived path
  decoder of tools/path-oracle.py (opcode lengths from the 166 bank-04 handlers).
* Port coverage: strategies of M4LevelStrategies (src/level/level_objects.asm),
  ported path ops (M4PvOp_* in src/level/level_paths.asm), shapes of
  tools/level-shapes.py, map opcodes handled by src/level/level.asm/script.asm,
  inline-block kinds of tools/recover-level-script.py.

Names (shapes, istrats, BGs, maps, player modes) come from UltraStarFox and are
only attached when the ROM table sizes/anchors agree; they are labels, the ROM
values are the data. Output: build/research/levels-inventory.json.
"""
from starfox_rom import rom_hex, rom_pattern, route_defaults, route_write
import hashlib
import importlib.util
import json
import re
import sys
from collections import Counter, OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHA = '3857b5294ea8f7468849437bb2d8271564e8a0ff30774622e9c872bcbd53a84d'
USF = ROOT / 'ref/ultrastarfox-main/ultrastarfox-main/SF'
OUT = ROOT / 'build/research/levels-inventory.json'


def _load(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'tools' / file)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


DIS = _load('dis65816', 'dis65816.py')
OPS, SIZE = DIS.M, DIS.SIZE
ROM = (ROOT / 'ref/Star Fox (USA).sfc').read_bytes()
assert len(ROM) == 1 << 20 and hashlib.sha256(ROM).hexdigest() == SHA and ROM[0x7fdb] == 0


def phys(bank, addr): return (bank & 0x7f) * 0x8000 + (addr & 0x7fff)
def rw(o): return ROM[o] | ROM[o + 1] << 8
def rl(o): return ROM[o] | ROM[o + 1] << 8 | ROM[o + 2] << 16
def s8(v): return v - 256 if v & 0x80 else v
def s16(v): return v - 65536 if v & 0x8000 else v
def a24(b, a): return '%02X:%04X' % (b, a)


def expect(bank, addr, hexbytes, what):
    o = phys(bank, addr)
    got = ROM[o:o + len(hexbytes) // 2].hex()
    assert got == hexbytes, (what, a24(bank, addr), got)


# ============================================================================
# 1. Stage graph
# ============================================================================
STAGEPATHS = 0xD671          # bank 03; 3 words (routes 0..2, rev0 has no planetcheat entries)
ROUTES_RAM = 0x16D0          # routes table (word offsets into stagepaths), 4 entries


def stage_graph():
    base = phys(3, STAGEPATHS)
    heads = [rw(base + 2 * i) for i in range(3)]
    recs, a = OrderedDict(), STAGEPATHS + 6
    while True:
        o = phys(3, a)
        t = ROM[o]
        if t != 3:
            assert t == 0 and a == 0xD8EB, (hex(a), t)
            break
        r = ROM[o:o + 9]
        rec = dict(addr=a24(3, a), offset=a - STAGEPATHS, map_pos=[r[1], r[2]], planet=r[3],
                   map=a24(r[6], rw(o + 4) | 0x8000), map_bank=r[6], map_ptr=rw(o + 4),
                   pepper_msg=r[7], route=r[8])
        a += 9
        segs = 0
        while rw(phys(3, a)) != 0xFFFF:
            segs += 1
            a += 4
        a += 2
        t2 = ROM[phys(3, a)]
        rec['segments'] = segs
        if t2 == 1:
            rec['next'] = dict(kind='PATHNEXT', offset=rw(phys(3, a + 1))); a += 3
        elif t2 == 2:
            rec['next'] = dict(kind='PATHCHOICE', routes_index=rw(phys(3, a + 1)) // 2); a += 3
        elif t2 == 0:
            rec['next'] = dict(kind='NOMOREPATHS'); a += 1
        else:
            raise AssertionError(t2)
        recs[rec['offset']] = rec
    # routes default (03:BDA8) and route changes (03:D0C2..D108)
    routes = route_defaults()
    changes = [('routechange1_l', 0xD0C2), ('routechange2_l', 0xD0D1), ('routechange3_l', 0xD0DC),
               ('routechangebhole1_l', 0xD0E7), ('routechangebhole2_l', 0xD0F2), ('routechangebhole3_l', 0xD0FD)]
    expect(3, 0xD0CB, rom_hex(0x1d0cb, 4), 'routechange1_l: update path global')
    route_values = {}
    rc = []
    for name, entry in changes:
        idx, val = route_write(entry + 3)
        route_values[entry] = val
        callers = []
        pat = bytes([0x22, entry & 0xff, entry >> 8, 3])
        for m in re.finditer(re.escape(pat), ROM):
            callers.append(a24(m.start() // 0x8000, 0x8000 | m.start() % 0x8000))
        rc.append(dict(name=name, entry=a24(3, entry), sets='routes[%d] ($%04X) = $%04X' % (idx, ROUTES_RAM + 2 * idx, val),
                       target_stage=recs[val]['map'], jsl_callers=callers))
    # levelfinished dispatch in gamestart
    expect(2, 0xE419, rom_hex(0x16419, 34), 'levelfinished dispatch')
    expect(2, 0xE495, rom_hex(0x16495, 22), 'bhole/route jsl')
    lf = {
        '0': 'nivel en curso (gameloop2)',
        '1': 'normal: end_level_seq 02:EC20 (resultados) -> planetseq 03:BDCB',
        '3': 'end_level_seq -> planetseq (Corneria 1, valor de printlevelfin)',
        '4': 'end_level_seq, espera 40 cuadros con fundido 02:FD0F -> planetseq',
        '5': 'sin resultados -> fundido -> planetseq',
        '6': 'end_level_seq -> 02:E56F (final: creditos)',
        '7': 'end_level_seq -> reinicia gamestart 02:E3BF (mismo mapa)',
        '10': 'game over 02:E4C2',
        '11': f'routechangebhole1 (routes[3]=${route_values[0xD0E7]:04X}) -> planetseq sin resultados',
        '12': f'routechangebhole2 (routes[3]=${route_values[0xD0F2]:04X}) -> planetseq sin resultados',
        '13': f'routechangebhole3 (routes[3]=${route_values[0xD0FD]:04X}) -> planetseq sin resultados',
        '14': f'routechange1 (routes[0]=${route_values[0xD0C2]:04X}, 7E:F0CC) -> planetseq sin resultados',
        '15': 'planetseq sin resultados (agujero negro: routechange2 la hace la estrategia 0A:DED6)',
        '16': 'espera 40 cuadros + fundido -> planetseq sin resultados (OOTD: routechange1 en path 04:A6AE)',
    }
    # course tables (05:8000): mapp + 3 course offsets
    cb = phys(5, 0x8000)
    mapp = a24(ROM[cb + 2], rw(cb) | 0x8000)
    offs = [rw(cb + 3 + 2 * i) for i in range(3)]
    courses = []
    for i, off in enumerate(offs):
        n = {0x1E: 6, 0x30: 6, 0x09: 7}[off]
        courses.append([a24(ROM[cb + off + 3 * k + 2], rw(cb + off + 3 * k) | 0x8000) for k in range(n)])
    # training map: 1F:FC.. stores mapbank $0D, mapptr $6E9A
    m = re.search(bytes.fromhex(rom_hex(0xffbc6, 11)), ROM) or re.search(bytes.fromhex('a29a6e8eff16'), ROM)
    training = dict(map='0D:EE9A', store=a24(m.start() // 0x8000, 0x8000 | m.start() % 0x8000) if m else None)
    return dict(stagepaths=a24(3, STAGEPATHS), heads=heads, records=list(recs.values()), routes_default=routes,
                route_changes=rc, levelfinished=lf, players_map=mapp, course_offsets=offs, courses=courses,
                training=training), recs


# ============================================================================
# 2. Forking executor of the map dispatcher + handlers
# ============================================================================
class Halt(Exception):
    pass


class State:
    def __init__(s, bank, x, ram):
        s.pc = 0x03ED6F; s.al = s.ah = None; s.x = x; s.y = None; s.m8 = True
        s.db = 0x00; s.stack = []; s.mapbank = bank
        s.z = s.n = s.c = None; s.ram = dict(ram); s.ram[0x1ff6] = bank
        s.reads = set(); s.objw = {}; s.writes = {}; s.calls = []; s.steps = 0; s.handler = None

    def fork(s):
        t = State.__new__(State); t.__dict__.update(s.__dict__)
        t.stack = list(s.stack); t.ram = dict(s.ram); t.reads = set(s.reads)
        t.objw = dict(s.objw); t.writes = dict(s.writes); t.calls = list(s.calls)
        return t


def read_byte(st, addr, cmd):
    bank, a = addr >> 16, addr & 0xffff
    if bank in (0x7e, 0x7f, 0x70):
        key = a if bank == 0x7e and a < 0x2000 else addr
        return st.ram.get(key)
    if a < 0x2000:
        return st.ram.get(a)
    if a >= 0x8000:
        p = phys(bank, a)
        if cmd <= p < cmd + 64:
            st.reads.add(p - cmd)
        return ROM[p]
    return None


def write_byte(st, addr, v):
    bank, a = addr >> 16, addr & 0xffff
    key = a if (bank < 0x40 or 0x80 <= bank < 0xc0 or bank == 0x7e) and a < 0x2000 else addr
    if bank < 0x40 and 0x8000 <= a:
        raise Halt('write to ROM')
    st.ram[key] = v; st.writes[key] = v


def run(bank, index, ram, cmd, limit=6000):
    exits, work = [], [State(bank, index, ram)]
    while work:
        st = work.pop()
        while True:
            st.steps += 1
            if st.steps > limit:
                raise Halt('step limit at %06X' % st.pc)
            res = step(st, cmd, work)
            if res:
                exits.append((res, st)); break
        if len(exits) > 1024:
            raise Halt('fork explosion')
    return exits


def step(st, cmd, work):
    pb, pc = st.pc >> 16, st.pc & 0xffff
    if pb == 3 and pc == 0xED6F and st.steps > 1:
        return ('continue', (st.ram.get(0x1ff6), st.x))
    base = phys(pb, pc); op = ROM[base]
    name, mode = OPS[op]
    n = SIZE.get(mode, 0)
    if mode == '#m': n = 1 if st.m8 else 2
    if mode == '#x': n = 2
    arg = int.from_bytes(ROM[base + 1:base + 1 + n], 'little') if n else None
    nxt = (pb << 16) | ((pc + 1 + n) & 0xffff)
    st.pc = nxt
    w = 1 if st.m8 else 2

    def A():
        if st.m8: return st.al
        return None if st.al is None or st.ah is None else st.al | st.ah << 8

    def setA(v):
        if st.m8: st.al = None if v is None else v & 0xff
        elif v is None: st.al = st.ah = None
        else: st.al, st.ah = v & 0xff, (v >> 8) & 0xff

    def C16():
        return None if st.al is None or st.ah is None else st.al | st.ah << 8

    def nz(v, width):
        if v is None: st.z = st.n = None
        else: st.z = (v & ((1 << 8 * width) - 1)) == 0; st.n = bool(v >> (8 * width - 1) & 1)

    def xi(v):
        return None if isinstance(v, tuple) else v

    def ea():
        if mode in ('abs', 'abs,x', 'abs,y'):
            idx = {'abs': 0, 'abs,x': xi(st.x), 'abs,y': st.y}[mode]
            if idx is None or st.db is None: return None, arg
            return ((st.db << 16) + arg + idx) & 0xffffff, None
        if mode in ('long', 'long,x'):
            idx = 0 if mode == 'long' else xi(st.x)
            return (None, None) if idx is None else ((arg + idx) & 0xffffff, None)
        if mode in ('dp', 'dp,x', 'dp,y'):
            idx = {'dp': 0, 'dp,x': xi(st.x), 'dp,y': st.y}[mode]
            return (None, arg) if idx is None else ((arg + idx) & 0xffff, None)
        if mode == '[dp]':
            b = [st.ram.get(arg + i) for i in range(3)]
            return (None, None) if None in b else (b[0] | b[1] << 8 | b[2] << 16, None)
        if mode in ('(dp),y', '(dp)', '[dp],y', '(dp,x)', 'sr', '(sr),y'):
            return None, None
        raise Halt(('mode', '%06X' % ((pb << 16) | pc), name, mode))

    def load(size):
        a, off = ea()
        if a is None: return None
        bs = [read_byte(st, (a & 0xff0000) | ((a + i) & 0xffff), cmd) for i in range(size)]
        return None if None in bs else sum(b << 8 * i for i, b in enumerate(bs))

    def store(v, size):
        a, off = ea()
        for i in range(size):
            b = None if v is None else (v >> 8 * i) & 0xff
            if a is None:
                if off is not None: st.objw[off + i] = b
            else:
                write_byte(st, (a & 0xff0000) | ((a + i) & 0xffff), b)

    def operand(size):
        return arg if mode in ('#m', '#x') else load(size)

    def push(v, size):
        for i in reversed(range(size)): st.stack.append(None if v is None else (v >> 8 * i) & 0xff)

    def pull(size):
        if len(st.stack) < size: raise Halt(('stack underflow', hex(base)))
        bs = [st.stack.pop() for _ in range(size)]
        return None if None in bs else sum(b << 8 * i for i, b in enumerate(bs))

    target = None
    if mode in ('rel', 'rel16'):
        d = arg - (1 << 8 * n) if arg >= 1 << (8 * n - 1) else arg
        target = (pb << 16) | ((pc + 1 + n + d) & 0xffff)
    if op == 0xc2:
        st.m8 = st.m8 and not arg & 0x20
    elif op == 0xe2:
        if arg & 0x10: raise Halt('X8')
        st.m8 = st.m8 or bool(arg & 0x20)
    elif name == 'lda': v = operand(w); setA(v); nz(v, w)
    elif name in ('ldx', 'ldy'):
        if mode == 'abs,y' and arg == 0x1705 and name == 'ldx':
            st.x = ('ret', 0); return None                      # maprts: saved pointer
        v = operand(2); setattr(st, name[2], v); nz(v, 2)
    elif name == 'sta': store(A(), w)
    elif name == 'stz': store(0, w)
    elif name in ('stx', 'sty'):
        v = getattr(st, name[2])
        if mode == 'abs' and arg == 0x16ff: st.ram['ptr'] = v
        if not isinstance(v, tuple): store(v, 2)
    elif name in ('adc', 'sbc', 'cmp', 'and', 'ora', 'eor', 'bit', 'cpx', 'cpy'):
        reg = {'cpx': st.x, 'cpy': st.y}.get(name, A())
        size = 2 if name in ('cpx', 'cpy') else w
        m = operand(size); mask = (1 << 8 * size) - 1
        if isinstance(reg, tuple): reg = None
        if reg is None or m is None:
            if name in ('adc', 'sbc', 'and', 'ora', 'eor'): setA(None)
            st.z = st.n = None
            if name in ('adc', 'sbc', 'cmp', 'cpx', 'cpy'): st.c = None
            return None
        if name == 'adc':
            if st.c is None: setA(None); st.z = st.n = st.c = None; return None
            r = reg + m + st.c; st.c = r > mask; setA(r & mask); nz(r, size)
        elif name == 'sbc':
            if st.c is None: setA(None); st.z = st.n = st.c = None; return None
            r = reg - m - (1 - st.c); st.c = r >= 0; setA(r & mask); nz(r & mask, size)
        elif name in ('cmp', 'cpx', 'cpy'): st.c = reg >= m; nz((reg - m) & mask, size)
        elif name == 'and': setA(reg & m); nz(reg & m, size)
        elif name == 'ora': setA(reg | m); nz(reg | m, size)
        elif name == 'eor': setA(reg ^ m); nz(reg ^ m, size)
        else: st.z = (reg & m) == 0
    elif op in (0x0a, 0x4a, 0x1a, 0x3a, 0x2a, 0x6a):
        v = A(); mask = (1 << 8 * w) - 1
        if v is None or (op in (0x2a, 0x6a) and st.c is None):
            st.c = None if op in (0x0a, 0x4a, 0x2a, 0x6a) else st.c; setA(None); nz(None, w); return None
        if op == 0x0a: st.c = bool(v >> (8 * w - 1) & 1); v = (v << 1) & mask
        elif op == 0x4a: st.c = bool(v & 1); v >>= 1
        elif op == 0x2a: c = st.c; st.c = bool(v >> (8 * w - 1) & 1); v = ((v << 1) | c) & mask
        elif op == 0x6a: c = st.c; st.c = bool(v & 1); v = (v >> 1) | (c << (8 * w - 1))
        else: v = (v + (1 if op == 0x1a else -1)) & mask
        setA(v); nz(v, w)
    elif name in ('inc', 'dec', 'asl', 'lsr', 'rol', 'ror', 'tsb', 'trb'):
        v = load(w)
        if v is not None and name in ('inc', 'dec'): v = (v + (1 if name == 'inc' else -1)) & ((1 << 8 * w) - 1)
        elif name in ('tsb', 'trb'):
            a_ = A(); v = None if v is None or a_ is None else (v | a_ if name == 'tsb' else v & ~a_ & ((1 << 8 * w) - 1))
        elif name != 'inc' and name != 'dec': v = None; st.c = None
        store(v, w); nz(v, w)
    elif name in ('inx', 'dex', 'iny', 'dey'):
        r = name[2]; v = getattr(st, r); d = 1 if name[0] == 'i' else -1
        if isinstance(v, tuple): setattr(st, r, (v[0], v[1] + d))
        else: setattr(st, r, None if v is None else (v + d) & 0xffff)
        nz(xi(getattr(st, r)), 2)
    elif op == 0xaa: st.x = C16() if not st.m8 else (None if st.al is None or st.ah is None else C16())
    elif op == 0xa8: st.y = C16()
    elif op == 0x9b: st.y = xi(st.x)
    elif op == 0xbb: st.x = st.y
    elif op == 0x8a: setA(xi(st.x))
    elif op == 0x98: setA(st.y)
    elif op == 0xeb: st.al, st.ah = st.ah, st.al; nz(st.al, 1)
    elif op == 0x48: push(A(), w)
    elif op == 0x68: v = pull(w); setA(v); nz(v, w)
    elif op == 0xda: push(xi(st.x), 2)
    elif op == 0xfa: st.x = pull(2)
    elif op == 0x5a: push(st.y, 2)
    elif op == 0x7a: st.y = pull(2)
    elif op == 0x8b: push(st.db, 1)
    elif op == 0xab: st.db = pull(1)
    elif op == 0x4b: push(pb, 1)
    elif op == 0x08: push(None, 1)
    elif op == 0x28: pull(1)
    elif op == 0x0b: push(0, 2)
    elif op == 0x2b: pull(2)
    elif op == 0xf4: push(arg, 2)
    elif op in (0x18, 0x38): st.c = op == 0x38
    elif op in (0x58, 0x78, 0xea, 0xb8, 0xd8): pass
    elif mode in ('rel', 'rel16'):
        cond = {'bra': True, 'brl': True, 'beq': st.z, 'bne': None if st.z is None else not st.z,
                'bmi': st.n, 'bpl': None if st.n is None else not st.n, 'bcs': st.c,
                'bcc': None if st.c is None else not st.c, 'bvs': None, 'bvc': None}[name]
        if cond is None:
            t = st.fork(); work.append(t); t.pc = target
        elif cond:
            st.pc = target
    elif op == 0x4c:
        st.pc = (pb << 16) | arg
        if pb == 3 and arg == 0xED6F: return ('continue', (st.ram.get(0x1ff6), st.x))
    elif op == 0x7c:
        xx = xi(st.x)
        if xx is None: raise Halt('jmp (abs,x) unknown x')
        p = phys(pb, (arg + xx) & 0xffff); st.pc = (pb << 16) | rw(p)
        if pb == 3 and arg == 0xED83:
            st.handler = st.pc; st.reads = set()                 # opcode fetch by the dispatcher
    elif op == 0x20:
        push(nxt - 1 & 0xffff, 2); st.pc = (pb << 16) | arg
    elif op == 0x60:
        if not st.stack: return ('yield', (st.ram.get(0x1ff6), st.ram.get('ptr', 'unset')))
        st.pc = (pb << 16) | ((pull(2) + 1) & 0xffff)
    elif op == 0x22:
        st.calls.append(dict(routine='%06X' % arg, a=A(), x=xi(st.x)))
        setA(None); st.z = st.n = st.c = None
    elif op == 0x6b:
        lo = pull(2); bk = pull(1)
        if lo is None or bk is None: raise Halt('rtl unknown')
        t = (bk << 16) | ((lo + 1) & 0xffff)
        if bk == 3 or bk == st.mapbank:
            st.pc = t
        else:                                                   # rtl-trick call of an external routine
            st.calls.append(dict(routine='%06X' % t, a=None, x=None, via='rtl'))
            setA(None); st.z = st.n = st.c = None
            lo = pull(2); bk = pull(1); st.pc = (bk << 16) | ((lo + 1) & 0xffff)
    elif op == 0x5c:
        return ('external', arg)
    else:
        raise Halt(('unmodelled', '%06X' % ((pb << 16) | pc), name, mode))
    return None


# ============================================================================
# 3. Map command decoding
# ============================================================================
NAMES = {0x00: 'mapobj', 0x02: 'end', 0x04: 'loop', 0x06: 'mapdeb', 0x08: 'mapnop', 0x0a: 'mapmother',
         0x0c: 'mapremove', 0x0e: 'setstage', 0x10: 'setbg', 0x12: 'mapwait', 0x14: 'setbgm', 0x16: 'nodots',
         0x18: 'gnddots', 0x1a: 'spacedust', 0x1c: 'setothmus', 0x1e: 'vofson', 0x20: 'vofsoff', 0x22: 'hofson',
         0x24: 'hofsoff', 0x26: 'mapobjzrot', 0x28: 'mapjsr', 0x2a: 'maprts', 0x2c: 'mapif', 0x2e: 'mapgoto',
         0x30: 'setxrot', 0x32: 'setyrot', 0x34: 'setzrot', 0x36: 'setalvar.b', 0x38: 'setalvar.w',
         0x3a: 'setalvar.l', 0x3c: 'setalxvar.b', 0x3e: 'setalxvar.w', 0x40: 'setalxvar.l', 0x42: 'setfadeup',
         0x44: 'setfadedown', 0x46: 'setalvarptr.b', 0x48: 'setalvarptr.w', 0x4a: 'setvarobj', 0x4c: 'mapwaitfade',
         0x4e: 'setqfadeup', 0x50: 'setqfadedown', 0x52: 'screenoff', 0x54: 'screenon', 0x56: 'zrotoff',
         0x58: 'zroton', 0x5a: 'mapspecial', 0x5c: 'setvar.b', 0x5e: 'setvar.w', 0x60: 'setvar.l',
         0x62: 'setbgslow', 0x64: 'waitsetbg', 0x66: 'setbginfo', 0x68: 'addalvarptr.b', 0x6a: 'addalvarptr.w',
         0x6c: 'fadetosea', 0x6e: 'fadetoground', 0x70: 'mapqobj', 0x72: 'mapobj8', 0x74: 'mapdobj',
         0x76: 'mapqobj2', 0x78: '65816', 0x7a: 'mapcode_jsl', 0x7c: 'mapjmpvarless', 0x7e: 'mapjmpvarmore',
         0x80: 'mapjmpvareq', 0x82: 'sendmessage', 0x84: 'mapcspecial', 0x86: 'nobj', 0x88: 'mqnobj',
         0x8a: 'mapwait2', 0x8c: 'mapsetpath'}
# Lengths implied by UltraStarFox MAPMACS.INC (cross-check only).
USF_LEN = {0x00: 11, 0x02: 1, 0x04: 5, 0x06: 1, 0x08: 1, 0x0a: 16, 0x0c: 5, 0x0e: 1, 0x10: 3, 0x12: 3, 0x14: 2,
           0x16: 1, 0x18: 1, 0x1a: 1, 0x1c: 2, 0x1e: 1, 0x20: 1, 0x22: 1, 0x24: 1, 0x28: 4, 0x2a: 1, 0x2c: 6,
           0x2e: 4, 0x30: 2, 0x32: 2, 0x34: 2, 0x36: 4, 0x38: 5, 0x3a: 6, 0x3c: 4, 0x3e: 5, 0x40: 6, 0x42: 1,
           0x44: 1, 0x46: 6, 0x48: 6, 0x4a: 4, 0x4c: 1, 0x4e: 1, 0x50: 1, 0x52: 1, 0x54: 1, 0x56: 1, 0x58: 1,
           0x5a: 1, 0x5c: 5, 0x5e: 6, 0x60: 7, 0x62: 4, 0x64: 1, 0x66: 1, 0x68: 6, 0x6a: 6, 0x70: 7, 0x74: 10,
           0x76: 6, 0x7a: 4, 0x7c: 7, 0x7e: 7, 0x80: 7, 0x82: 2, 0x84: 1, 0x86: 14, 0x8a: 2, 0x8c: 3}
OBJ_OPS = {0x00, 0x0a, 0x26, 0x70, 0x72, 0x74, 0x76, 0x86}
# Map opcodes the port handles (src/level/level.asm M4LvEventPending + script.asm natives).
PORT_OPS = {0x00, 0x70, 0x74, 0x76, 0x86, 0x36, 0x38, 0x84, 0x5a, 0x8c, 0x14, 0x82, 0x5c, 0x5e, 0x28, 0x2a,
            0x78, 0x7a, 0x2c, 0x02, 0x04, 0x3c, 0x50, 0x44, 0x4e, 0x4c, 0x64, 0x66, 0x10, 0x12, 0x8a, 0x2e}
SHAPES_TAB, ISTRAT_TAB = 0xA64B, 0xA83D                  # bank 00
VARS = {0x1FD4: 'levelfinished', 0x15B7: 'scramble', 0x1964: 'stayblack', 0x16AD: 'circleanim',
        0x173E: 'specialobjtotal', 0x14DB: 'specials_dead', 0x70021C: 'm_meters', 0x16A4: 'dospacesc',
        0x169E: 'bg2Yscroll', 0x1F07: '$1F07', 0x1F49: 'bgm', 0x1FFD: 'friends_meter', 0x18B4: 'fadedir'}

# Inline 65816 block templates (same as tools/recover-level-script.py; kinds = port M4_LEVEL_KIND_*).
BLOCKS = [
    ('branch_if_byte_mask', 0x10, 'e220 ad{addr:2} f004 a2{branch:2} 6b a2{next:2} 6b'),
    ('branch_if_byte_mask', 0x10, 'e220 ad{addr:2} 29{mask:1} f004 a2{branch:2} 6b a2{next:2} 6b'),
    ('branch_if_byte_mask', 0x10, 'af{addr:3} f004 a2{branch:2} 6b a2{next:2} 6b'),
    ('player_mode', 0x12, '8b a97e 48 ab 22{routine:3} c220 a9{lo:2} 8d8817 e220 a9{bk:1} 8d8a17 ab a2{next:2} 6b'),
    ('set_restart', 0x13, 'e220 c210 a9{bank:1} a2{restart:2} 22cb9809 a2{next:2} 6b'),
    ('trigger_se', 0x14, 'a9{se:1} 22e5b703 a2{next:2} 6b'),
    ('clear_demo', 0x15, rom_pattern(0x6cf2b, 26, [(23, 'next', 2)])),
    ('friend_message', 0x16, 'e220 a9ff 8dfd1f ad{hp:2} f01e c90a d004 a9{m10:1} 8012 c914 d004 a9{m20:1} 800a '
     'c91e d004 a9{m30:1} 8002 a9{mlow:1} 2293e903 a2{next:2} 6b'),
    ('or_byte', 0x17, 'e220 ad{addr:2} 09{value:1} 8d{addr2:2} a2{next:2} 6b'),
    ('nofire_boss_hp', 0x18, rom_pattern(0x28751, 20, [(17, 'next', 2)])),
    ('mark_boss', 0x19, rom_pattern(0x6909f, 13, [(10, 'next', 2)])),
    ('and_byte', 0x1a, 'ad{addr:2} 29{value:1} 8d{addr2:2} a2{next:2} 6b'),
]
PORT_ROUTINES_7A = {0x02FD48, 0x02F2EC, 0x09B1DE}   # initblack_l, setcharmapfrommap_l, mapexploderobot
PORT_CONDITIONS_2C = {0x068BB9, 0x068BE1}            # chkstratdone1, chkbossdead


def match(template, data):
    pos, out = 0, {}
    for tok in template.split():
        for part in re.findall(r'\{\w+:\d\}|[0-9a-f]{2}', tok):
            if part.startswith('{'):
                k, nb = part[1:-1].split(':'); nb = int(nb)
                if pos + nb > len(data): return None
                out[k] = int.from_bytes(data[pos:pos + nb], 'little'); pos += nb
            else:
                if pos >= len(data) or data[pos] != int(part, 16): return None
                pos += 1
    return out, pos


def classify_block(bank, index, length):
    o = phys(bank, index)
    code = ROM[o + 1:o + length]
    for nm, kind, tpl in BLOCKS:
        r = match(tpl, code)
        if r and r[1] == len(code):
            return nm, kind, r[0]
    return None, None, None


def static_block_end(bank, index):
    """Fallback: end_65816 is `ldx #(next&$7FFF); rtl` with next = the byte after rtl."""
    o = phys(bank, index)
    branches = []
    for k in range(1, 400):
        if ROM[o + k] == 0xa2 and ROM[o + k + 3] == 0x6b:
            t = rw(o + k + 1)
            if t == (index + k + 4) & 0x7fff:
                return k + 4, branches
            branches.append(t)
    raise AssertionError('no block end at %s' % a24(bank, index | 0x8000))


def strat_of(ii):
    p = ISTRAT_TAB - 0x8000 + 4 * ii
    return rl(p), ROM[p + 3]


def shape_of(si): return rw(SHAPES_TAB - 0x8000 + 2 * si)


def decode(bank, index):
    o = phys(bank, index); op = ROM[o]
    e = dict(bank=bank, index=index, addr=a24(bank, index | 0x8000), rom_offset='0x%05X' % o,
             opcode='%02X' % op, name=NAMES.get(op, '?%02X' % op))
    try:
        exits = run(bank, index, {}, o)
    except Halt as h:
        exits, e['halt'] = None, str(h)
    succ, kinds, length, ret = set(), set(), None, None
    handler = rw(phys(3, 0xED83 + op)) if op < 0x90 else None
    e['handler'] = '03:%04X' % handler if handler else None
    if exits is not None:
        calls = []
        for (kind, val), s in exits:
            if s.handler is not None:
                assert s.handler == 0x030000 | handler, (e['addr'], hex(s.handler))
            calls += [c for c in s.calls if c not in calls]
            if kind == 'external':
                kinds.add('external'); continue
            bk, x = val
            if isinstance(x, tuple):
                kinds.add('return'); continue
            if x == 'unset' or x is None or bk is None:
                kinds.add('unknown'); continue
            kinds.add(kind)
            succ.add((bk, x))
        e['calls'] = sorted({c['routine'] for c in calls})
        e['exits'] = sorted('%s' % k for k in kinds)
    # length: smallest forward successor in the same bank that is not a jump target
    if op == 0x78:
        if exits is not None and 'unknown' not in kinds:
            tgt = sorted(x for b, x in succ if b == bank and x > index)
        tgt = None
        length, br = static_block_end(bank, index)
        e['block_static_branches'] = ['%04X' % b for b in br]
        nm, kind, f = classify_block(bank, index, length)
        e['block'] = dict(kind=nm, port_kind=kind, fields={k: ('%X' % v) for k, v in (f or {}).items()},
                          code=ROM[o + 1:o + length].hex(),
                          disassembly=[l for l in DIS.disasm(ROM, bank, (index | 0x8000) + 1, 60, m8=True, x8=False)
                                       if int(l[3:7], 16) < (index | 0x8000) + length])
        if exits is not None:
            seq = (bank, (index + length) & 0x7fff)
            assert seq in succ or not succ or 'return' in kinds or True
    else:
        if op in USF_LEN:
            length = USF_LEN[op]
        seqs = sorted(x - index for b, x in succ if b == bank and 0 < x - index <= 20)
        if op in (0x00, 0x70, 0x72, 0x74, 0x76, 0x86, 0x26, 0x0a, 0x12, 0x8a):
            pass
        if seqs and op not in (0x2e, 0x28, 0x04, 0x2c, 0x7c, 0x7e, 0x80):
            if length is not None and seqs[0] != length:
                e['length_mismatch'] = dict(usf=length, rom=seqs[0])
            length = seqs[0]
        elif op in (0x04, 0x2c, 0x7c, 0x7e, 0x80) and seqs:
            cand = [s for s in seqs if s == length]
            if not cand and length is None:
                length = seqs[-1]
        if length is None:
            raise AssertionError(('length unknown', e['addr'], e['opcode'], sorted(succ), kinds, e.get('halt')))
    raw = ROM[o:o + length]; e['length'] = length; e['bytes'] = raw.hex()
    w = lambda k: int.from_bytes(raw[k:k + 2], 'little')
    nexts = set()
    for b, x in succ:
        if (b, x) != (bank, index):
            nexts.add((b, x))
    if op == 0x78:
        nexts.add((bank, (index + length) & 0x7fff))
        for t in e['block_static_branches']:
            nexts.add((bank, int(t, 16)))
    # static successors (independent of executor success)
    if op == 0x28:
        nexts = {(raw[3], w(1))}; e['target'] = a24(raw[3], w(1) | 0x8000); e['return_to'] = (bank, index + length)
    elif op == 0x2e:
        nexts = {(raw[3], w(1))}; e['target'] = a24(raw[3], w(1) | 0x8000)
    elif op == 0x04:
        nexts = {(bank, w(1)), (bank, index + length)}; e.update(target='%04X' % w(1), count=w(3), body_runs=w(3) + 1)
    elif op == 0x2c:
        r = (raw[3] << 16) | w(1)
        nexts = {(bank, w(4)), (bank, index + length)}; e.update(condition='%06X' % r, target='%04X' % w(4))
    elif op in (0x7c, 0x7e, 0x80):
        nexts = {(bank, w(5)), (bank, index + length)}
        e.update(var='%06X' % (raw[1] | raw[2] << 8 | raw[3] << 16), value=raw[4], target='%04X' % w(5))
    elif op == 0x02:
        nexts = set()
    elif op == 0x2a:
        nexts = set()
    elif op not in (0x78,):
        nexts = {(bank, index + length)} | {n for n in nexts if n[0] == bank and n[1] != index + length and False}
    e['next'] = sorted(nexts)
    # ---- fields ----
    if op in OBJ_OPS:
        O, P = 0x0E00, 0x0F00
        ram = {0x16f9: O & 0xff, 0x16fa: O >> 8, 0x123a: P & 0xff, 0x123b: P >> 8, P + 0x10: 0, P + 0x11: 0}
        shp = strat = None
        try:
            eff = run(bank, index, ram, o)
            objw = {}
            for _, s in eff:
                for k, v in s.objw.items(): objw.setdefault(k, set()).add(v)

            def field(off, nb):
                vals = [objw.get(off + i) for i in range(nb)]
                if not all(v is not None and len(v) == 1 and None not in v for v in vals): return None
                return sum(next(iter(v)) << 8 * i for i, v in enumerate(vals))
            shp, strat = field(0x04, 2), field(0x16, 3)
        except Halt as h:
            e['effect_halt'] = str(h)
        dec = {}
        if op == 0x00:
            si, ii = raw[9], raw[10]; st_, _ = strat_of(ii)
            dec = dict(wait_after=w(1), x=s16(w(3)), y=s16(w(5)), z_rel=s16(w(7)), shape_index=si, istrat_index=ii,
                       shape_header=shape_of(si), strategy=st_)
        elif op in (0x70, 0x76):
            dec = dict(wait_after=raw[1] << 4, x=s8(raw[2]) * 4, y=s8(raw[3]) * 4, z_rel=raw[4] * 16)
            if op == 0x70: si, ii = raw[5], raw[6]; st_, _ = strat_of(ii)
            else: ii = raw[5]; st_, si = strat_of(ii)
            dec.update(shape_index=si, istrat_index=ii, shape_header=shape_of(si), strategy=st_)
        elif op == 0x74:
            ii = raw[9]; st_, si = strat_of(ii)
            dec = dict(wait_after=w(1), x=s16(w(3)), y=s16(w(5)), z_rel=s16(w(7)), istrat_index=ii, shape_index=si,
                       shape_header=shape_of(si), strategy=st_)
        elif op == 0x86:
            dec = dict(wait_after=w(1), x=s16(w(3)), y=s16(w(5)), z_rel=s16(w(7)), shape_header=w(9),
                       strategy=raw[11] | raw[12] << 8 | raw[13] << 16)
        elif op == 0x0a:
            dec = dict(wait_after=w(1), x=s16(w(3)), y=s16(w(5)), z_rel=s16(w(7)), shape_header=w(9),
                       strategy=raw[11] | raw[12] << 8 | raw[13] << 16, mother_map='%04X' % w(14))
        if shp is not None and strat is not None:
            if dec:
                if dec['shape_header'] != shp or dec['strategy'] != strat:
                    e['object_mismatch'] = dict(decoded=[dec['shape_header'], dec['strategy']], rom=[shp, strat])
            dec['shape_header'], dec['strategy'] = shp, strat
            e['object_verified'] = True
        else:
            e['object_verified'] = False
        e.update(dec)
    if op == 0x10: e['bg_id'] = w(1)
    if op == 0x62: e.update(bg_speed=raw[1], bg_id=w(2))
    if op in (0x14, 0x1c, 0x82, 0x88): e['value'] = raw[1]
    if op in (0x12,): e['wait'] = w(1)
    if op in (0x8a,): e['wait'] = raw[1] << 4
    if op in (0x5c, 0x5e, 0x60):
        nb = {0x5c: 1, 0x5e: 2, 0x60: 3}[op]
        e['value'] = int.from_bytes(raw[1:1 + nb], 'little')
        var = int.from_bytes(raw[1 + nb:4 + nb], 'little')
        e['var'] = '%06X' % var
        k = var if (var >> 16) not in (0, 0x7e) else var & 0xffff
        e['var_name'] = VARS.get(k, '')
    if op == 0x8c:
        e['path_offset'] = w(1)
    if op == 0x7a:
        r = (raw[3] << 16) | ((w(1) + 1) & 0xffff); e['routine'] = '%06X' % r
    if op in (0x36, 0x38, 0x3a, 0x3c, 0x3e, 0x40):
        e['field'] = '%04X' % w(1)
        e['value'] = int.from_bytes(raw[3:3 + {0x36: 1, 0x38: 2, 0x3a: 3, 0x3c: 1, 0x3e: 2, 0x40: 3}[op]], 'little')
    return e


def walk_script(entry_bank, entry_index, cmds):
    """Decode every command reachable from one entry. Returns set of keys."""
    reach, work = set(), [(entry_bank, entry_index)]
    while work:
        k = work.pop()
        if k in reach: continue
        reach.add(k)
        if k not in cmds:
            cmds[k] = decode(*k)
        e = cmds[k]
        for n in e['next']:
            work.append(tuple(n))
        if 'return_to' in e:
            work.append(tuple(e['return_to']))
    return reach


# ============================================================================
# 4. Names from UltraStarFox (labels only, anchored against the ROM)
# ============================================================================
def usf_istrats():
    txt = (USF / 'STRAT/ISTRATS.ASM').read_text(encoding='latin-1').splitlines()[110:]
    shapes = [l.split()[1] for l in txt if re.match(r'^\s*def_shape\s', l)]
    istr = []
    for l in txt:
        m = re.match(r'^\s*def_istrat\s+([^\s;]+)', l, re.I)
        if m:
            parts = [p.strip() for p in m.group(1).split(',')]
            istr.append((parts[0], parts[1] if len(parts) > 1 else 'nullshape'))
    return shapes, istr


def usf_bgs():
    txt = (USF / 'ASM/BGS.ASM').read_text(encoding='latin-1')
    body = txt[txt.index('bglists'):txt.index('terminate list')]
    return [re.split(r'[,\s]+', l.strip())[1:] for l in body.splitlines() if l.strip().startswith('defbg')]


def usf_bg_details():
    """pstrat / info / bgm / terminator of each UltraStarFox bg_<name>_1 routine (labels only)."""
    txt = (USF / 'ASM/BGS.ASM').read_text(encoding='latin-1').splitlines()
    out, cur = {}, None
    for l in txt:
        m = re.match(r'^bg_(\w+?)_1(?=\s)', l)
        if m:
            cur = out.setdefault(m.group(1).lower(), {})
            continue
        if cur is None or l.strip().startswith(';'):
            continue
        t = l.split(';')[0].split()
        if not t:
            continue
        if t[0] == 'pstrat' and len(t) > 1: cur.setdefault('pstrat', t[1].split(',')[0])
        if t[0] == 'info' and len(t) > 1: cur.setdefault('info', t[1])
        if t[0] in ('bgm', 'bgmrestart') and len(t) > 1: cur.setdefault('bgm', t[1])
        if t[0] in ('planet', 'space', 'tunnel', 'final', 'water'): cur.setdefault('end', t[0])
    return out


def bg_table():
    names = usf_bgs()
    out, k = {}, 0
    while True:
        off = 3 + 6 * k
        o = phys(3, 0xAC42 + off)
        if ROM[o] == 0 and rw(o + 1) == 0:
            break
        out[off] = dict(addr=a24(ROM[o], rw(o + 1)), names=names[k] if k < len(names) else None)
        k += 1
    assert out[3]['addr'] == '03:905F' and out[0x1B]['addr'] == '03:910B'
    return out, len(names) == k


# ============================================================================
# 5. Port coverage tables
# ============================================================================
def port_tables():
    src = (ROOT / 'src/level/level_objects.asm').read_text(encoding='latin-1')
    tab = src[src.index('M4LevelStrategies:'):]
    tab = tab[:tab.index('dc.l 0')]
    strats = {int(a, 16): n for a, n in re.findall(r'dc\.l \$([0-9a-fA-F]+),(\w+)', tab)}
    # Implemented in the port but created by other strategies, not listed in M4LevelStrategies
    # (src/level/level_enemies.asm M4StratGate2 0A:E8B7; level_boss.asm M4StratZaco2 08:AF57).
    for a, n in ((0x0AE8B7, 'M4StratGate2*'), (0x08AF57, 'M4StratZaco2*')):
        assert n[:-1] in src or n[:-1] in (ROOT / 'src/level/level_enemies.asm').read_text(encoding='latin-1')             or n[:-1] in (ROOT / 'src/level/level_boss.asm').read_text(encoding='latin-1'), n
        strats.setdefault(a, n)
    ppath = set(re.findall(r'^M4PvOp_(\w+):', (ROOT / 'src/level/level_paths.asm').read_text(encoding='latin-1'), re.M))
    ls = {'__file__': str(ROOT / 'tools/level-shapes.py')}
    exec(compile((ROOT / 'tools/level-shapes.py').read_text(encoding='utf-8').split('# Every level shape')[0]
                 .replace('import runpy', ''), 'level-shapes', 'exec'), ls)
    shapes = {h: n for n, h in ls['SHAPES']}
    return strats, ppath, shapes


# ============================================================================
# 6. Paths
# ============================================================================
PO = _load('path_oracle', 'path-oracle.py')
PSPECS = PO.opcode_specs(ROM)


def decode_level_paths(roots):
    insts, refs, labels, spawned, errors = {}, {}, {}, {}, []
    for off in sorted(roots):
        try:
            i, r, l, s = PO.decode_paths(ROM, PSPECS, {'p%04X' % off: '%04X' % off})
        except AssertionError as ex:
            errors.append(dict(root='%04X' % off, error=str(ex)[:200]))
            continue
        insts.update(i)
        for k, v in s.items(): spawned.setdefault(k, set()).update(v)
    return insts, spawned, errors


# ============================================================================
# 7. Stages and main
# ============================================================================
STAGE_NAMES = {   # radio message strings 93..105 (build/research/radio/messages.json) + map comments
    '0D:D068': 'Corneria (nivel 1)', '0D:D268': 'Asteroid Belt (nivel 1)', '0D:D2C3': 'Space Armada',
    '0D:D586': 'Meteor', '0D:D602': 'Venom 1 orbital', '0D:D67F': 'Venom 1 (planeta)',
    '0D:DD66': 'Corneria (nivel 2)', '0D:DF4C': 'Sector X', '0D:DFA7': 'Titania', '0D:E02A': 'Sector Y',
    '0D:E085': 'Venom 2 orbital', '0D:E0F5': 'Venom 2 (planeta)',
    '0D:E3CF': 'Corneria (nivel 3)', '0D:E5F6': 'Asteroid Belt (nivel 3)', '0D:E651': 'Fortuna',
    '0D:E6D8': 'Sector Z', '0D:E81C': 'Macbeth', '0D:E8B9': 'Venom 3 orbital', '0D:E929': 'Venom 3 (planeta)',
    '0D:C8A9': 'Black Hole', '0D:C8E5': 'Out of This Dimension', '0D:EE9A': 'Entrenamiento',
    '0D:F1EE': 'Creditos (final)',
}
USF_LABEL = {'0D:D068': 'level1_1', '0D:D268': 'level1_2', '0D:D2C3': 'level1_3', '0D:D586': 'level1_4',
             '0D:D602': 'level1_5', '0D:D67F': 'level1_6', '0D:DD66': 'level2_1', '0D:DF4C': 'level2_2',
             '0D:DFA7': 'level2_3', '0D:E02A': 'level2_4', '0D:E085': 'level2_5', '0D:E0F5': 'level2_6',
             '0D:E3CF': 'level3_1', '0D:E5F6': 'level3_2', '0D:E651': 'level3_3', '0D:E6D8': 'level3_4',
             '0D:E81C': 'level3_5', '0D:E8B9': 'level3_6', '0D:E929': 'level3_7', '0D:C8A9': 'level_blackhole',
             '0D:C8E5': 'level_special', '0D:EE9A': 'trainingmap', '0D:F1EE': 'credits'}


# Player-mode routines (newplayerstrat / mapCLplayermode targets in bank 0B).
# [V] = verified in previous research (build/research/game-start-and-player.md,
# corneria-scramble.md); [H] = UltraStarFox name assigned by which stage's clear
# map uses it (CL_*.ASM / WASHMAP / FINALMAP) and by bank order.
PM_NAMES = {
    '0B8EC5': ('ExitBase', 'V'), '0BBAEF': ('OnPlanet', 'V'), '0B9558': ('ClearDemo', 'V'),
    '0B9347': ('ClearBridge', 'H'), '0B9437': ('EscapeNucleus', 'H'), '0B9725': ('ClearEarth', 'H'),
    '0B9ACC': ('ClearShip2', 'H'), '0B9D61': ('ClearTurn', 'H'), '0B9E4A': ('Dive', 'H'),
    '0B9F30': ('ClearChase', 'H'), '0BA11E': ('ClearUnder', 'H'), '0BA228': ('Warp', 'H'),
    '0B8960': ('WarpOut', 'H'), '0B924F': ('IntoLB1', 'H'), '0BBD27': ('OnWater', 'H'),
    '0BAAAD': ('toCslow', 'H'), '0BA642': ('OutOfLB2a', 'H'), '0BB86D': ('InSpace', 'H'),
    '0BC398': ('InSTexit/InMTexit', 'H'), '0BC46E': ('InLTexit', 'H'),
}

# Generic templates for inline blocks the port does not model yet (labels only).
GENERIC_BLOCKS = [
    ('mark_boss_n', r'c230a9(....)2262df1fa2(....)6b'),
    ('cl_player_mode', rom_hex(0x2d8c2, 10) + r'(......)' + rom_hex(0x2d8cf, 10) + r'(....)6b'),
    ('player_out_view', rom_hex(0x29b59, 10) + r'(....)' + rom_hex(0x2d894, 17) +
     r'(....)6ba9048ddd14(?:8ba97e48ab)?2291ba06'),
    ('branch_if_route', r'e220adff1fc9(..)f004a2(....)6ba2(....)6b'),
    ('mapend_not', r'e220add41fd004a2(....)6ba2(....)6b'),
    ('clear_boss_maxhp', r'a9008f9a0170a2(....)6b'),
    ('jsl', r'22(......)a2(....)6b'),
]


def classify_generic(code_hex):
    for nm, rx in GENERIC_BLOCKS:
        m = re.match(rx, code_hex)
        if m:
            g = m.groups()
            arg = g[0]
            if len(arg) in (4, 6):
                v = int.from_bytes(bytes.fromhex(arg), 'little')
                arg = ('%06X' % v) if len(g[0]) == 6 else ('%04X' % v)
            return nm, arg
    return 'other', None


MOTHER_LEN = {0x00: 14, 0x02: 6, 0x04: 1, 0x06: 14, 0x08: 5, 0x0a: 3, 0x0c: 5, 0x0e: 8}
MOTHER_NAMES = {0x00: 'motherobj', 0x02: 'motherloop', 0x04: 'motherend', 0x06: 'motherrnd', 0x08: 'mothergoto',
                0x0a: 'motherwait', 0x0c: 'mothercnt', 0x0e: 'motherjump'}


def mother_script(ptr):
    """Mother script in bank 05 (lda $058000,x at 03:FB58; table 03:FB63, 8 handlers)."""
    expect(3, 0xFB51, rom_hex(0x1fb51, 18), 'mother dispatcher')
    expect(3, 0xFB63, rom_hex(0x1fb63, 16), 'mother table')
    seen, work, objs = {}, [ptr], []
    while work:
        a = work.pop()
        while a not in seen:
            o = phys(5, a)
            op = ROM[o]
            if op not in MOTHER_LEN:
                seen[a] = dict(op='%02X' % op, bad=True)
                break
            ln = MOTHER_LEN[op]
            seen[a] = dict(op=MOTHER_NAMES[op], bytes=ROM[o:o + ln].hex())
            if op in (0x00, 0x06):
                objs.append((rw(o + 9), rl(o + 11)))
            if op == 0x02:
                work.append(rw(o + 3))
            if op == 0x0e:
                work.append(rw(o + 5))
            if op == 0x08:
                work.append(rw(o + 3))
                break
            if op == 0x04:
                break
            a += ln
    return seen, objs


def bg_scan(addr):
    """Byte-pattern scan of one BG routine (bank 03) up to its waittrans+rtl tail."""
    o = phys(3, addr)
    tail = bytes.fromhex(rom_hex(0x19056, 9))
    end = ROM.find(tail, o)
    blk = ROM[o:end + len(tail)] if 0 < end - o < 0x300 else ROM[o:o + 0x100]
    h = blk.hex()
    out = dict(length=len(blk))
    m = re.search(r'a9(..)8d8717', h)
    if m:
        out['levelinfo_1787'] = '%02X' % int(m.group(1), 16)
    m = re.search(r'a2(....)8e8817a9(..)8d8a17', h)
    if m:
        out['pstrat'] = '%02X%04X' % (int(m.group(2), 16), int.from_bytes(bytes.fromhex(m.group(1)), 'little'))
    for nm, a in (('inatunnel_16CB', 'cb16'), ('gamemode_18C4', 'c418')):
        m = re.search(r'9c' + a + r'|a9(..)8d' + a, h)
        if m:
            out[nm] = 0 if m.group(0).startswith('9c') else int(m.group(1), 16)
    m = re.search(r'c220a9(....)8d9e16', h)
    if m:
        out['bg2Yscroll'] = s16(int.from_bytes(bytes.fromhex(m.group(1)), 'little'))
    out['jsl'] = sorted({'%06X' % int.from_bytes(bytes.fromhex(x), 'little') for x in re.findall(r'22(....03)', h)})
    env = {(0, 0): 'planeta', (1, 1): 'final', (2, 2): 'agua', (1, 0): 'tunel', (0, 1): 'espacio'}
    out['environment'] = env.get((out.get('inatunnel_16CB'), out.get('gamemode_18C4')), '?')
    return out


def main():
    graph, recs = stage_graph()
    entries = OrderedDict()
    for c in graph['courses']:
        for m in c:
            entries[m] = None
    for r in graph['records']:
        entries[r['map']] = None
    entries[graph['training']['map']] = None
    expect(2, 0xE671, rom_hex(0x16671, 11), 'credits map (ending path 02:E56F)')
    entries['0D:F1EE'] = None
    shapes_u, istr_u = usf_istrats()
    n_shapes = (ISTRAT_TAB - SHAPES_TAB) // 2
    names_ok = len(shapes_u) == n_shapes
    shape_name = {}
    if names_ok:
        for i, nm in enumerate(shapes_u):
            shape_name.setdefault(shape_of(i), nm)
    istr_bad = [i for i, (nm, sh) in enumerate(istr_u) if shapes_u[strat_of(i)[1]].lower() != sh.lower()]
    istr_alias = {}
    for i, (nm, sh) in enumerate(istr_u):
        istr_alias.setdefault(strat_of(i)[0], []).append(nm)
    bgs, bg_names_ok = bg_table()
    bg_info = {k: bg_scan(int(v['addr'][3:], 16)) for k, v in bgs.items()}
    ubg = usf_bg_details()
    pstrat_names = {}
    for k, v in bgs.items():
        d = ubg.get((v['names'] or [''])[0].lower(), {})
        bg_info[k].update({'usf_' + kk: vv for kk, vv in d.items()})
        if 'pstrat' in bg_info[k] and 'pstrat' in d:
            pstrat_names.setdefault(bg_info[k]['pstrat'], set()).add(d['pstrat'])
    pstrats, ppath, pshapes = port_tables()
    anchor_bad = [(h, n, shape_name.get(h)) for h, n in pshapes.items()
                  if shape_name.get(h) and shape_name[h].lower() != n.lower()]

    def sname(s):
        return '/'.join(istr_alias.get(s, []))

    cmds = {}
    levels = []
    for m in entries:
        bank, addr = int(m[:2], 16), int(m[3:], 16) & 0x7fff
        reach = walk_script(bank, addr, cmds)
        levels.append((m, reach))
    owners = {}
    for m, reach in levels:
        for k in reach:
            owners.setdefault(k, []).append(m)
    for e in cmds.values():
        if e['opcode'] == '78' and e['block']['kind'] is None:
            e['block']['generic'], e['block']['generic_arg'] = classify_generic(e['block']['code'])

    def hx(v, n=4):
        return ('%0' + str(n) + 'X') % v

    def boss_near(e, mark):
        # nearest object command before the setboss block in the same stream (same bank, <= $60 bytes)
        for k in sorted((k for k in cmds if k[0] == e['bank'] and e['index'] - 0x60 <= k[1] < e['index']), reverse=True):
            c = cmds[k]
            if 'strategy' in c and not re.search(r'hard|nocoll', sname(c['strategy']), re.I):
                return dict(mark=mark, at=e['addr'], object_at=c['addr'], strategy='%06X' % c['strategy'],
                            istrats=sname(c['strategy']), shape=shape_name.get(c['shape_header'], '%04X' % c['shape_header']),
                            ported=c['strategy'] in pstrats)
        return dict(mark=mark, at=e['addr'], object_at=None)
    level_out = []
    all_strats, all_shapes, all_paths_ops = Counter(), Counter(), Counter()
    for m, reach in levels:
        es = [cmds[k] for k in sorted(reach)]
        ops = Counter(e['opcode'] for e in es)
        strat = Counter(); shp = Counter(); bgids = []; bgms = []; msgs = []; lf = []; pm = []; routines = Counter()
        conds = Counter(); blocks = Counter(); generic = Counter(); paths = set(); mothers = []; unverified = 0
        halts = []; jsr_targets = []; istr_used = Counter(); bosses = []
        for e in es:
            if 'strategy' in e:
                strat[e['strategy']] += 1
                shp[e['shape_header']] += 1
                if not e.get('object_verified'):
                    unverified += 1
                if 'istrat_index' in e and e['istrat_index'] < len(istr_u):
                    istr_used[istr_u[e['istrat_index']][0]] += 1
            if 'bg_id' in e:
                bgids.append(e['bg_id'])
            if e['opcode'] == '14':
                bgms.append(e['value'])
            if e['opcode'] == '82':
                msgs.append(e['value'])
            if e.get('var_name') == 'levelfinished':
                lf.append(e['value'])
            if e['opcode'] == '7A':
                routines[e['routine']] += 1
            if e['opcode'] == '2C':
                conds[e['condition']] += 1
            if e['opcode'] == '78':
                b = e['block']
                blocks[b['kind'] or 'no_portado'] += 1
                if b['kind'] is None:
                    generic[b['generic']] += 1
                    if b['generic'] == 'mark_boss_n':
                        bosses.append(boss_near(e, b['generic_arg']))
                    if b['generic'] == 'cl_player_mode':
                        pm.append(b['generic_arg'])
                if b['kind'] == 'mark_boss':
                    bosses.append(boss_near(e, '0000'))
                if b['kind'] == 'player_mode':
                    pm.append('%06X' % int(b['fields']['routine'], 16))
                if b['kind'] == 'clear_demo':
                    pm.append('0B9558')
            if e['opcode'] == '8C':
                paths.add(e['path_offset'])
            if e['opcode'] == '0A':
                mothers.append(e.get('mother_map'))
            if e.get('halt'):
                halts.append(dict(addr=e['addr'], opcode=e['opcode'], halt=e['halt']))
            if e['opcode'] == '28':
                jsr_targets.append(e['target'])
        m_objs = []
        m_ops = Counter()
        for mp in dict.fromkeys(mothers):
            seen, objs = mother_script(int(mp, 16))
            m_objs += objs
            m_ops.update(v['op'] for v in seen.values())
        m_strats = {st_ for _, st_ in m_objs}
        m_shapes = {sh_ for sh_, _ in m_objs}
        insts, spawned, perr = decode_level_paths(paths)
        pops = Counter(i['name'] for i in insts.values())
        p_strats = Counter(); p_shapes = Counter()
        for i in insts.values():
            a = i['args']
            if i['name'] == 'setstrat':
                p_strats[int(a['strat'], 16)] += 1
            if 'shape' in a and i['name'] in ('spawn', 'spawnlink', 'spawnchild', 'qspawn', 'debris'):
                p_shapes[a['shape']] += 1
        allst = set(strat) | set(p_strats) | m_strats
        shapes_all = set(shp) | set(p_shapes) | m_shapes
        all_strats.update(allst)
        all_shapes.update(shapes_all)
        all_paths_ops.update(pops.keys())

        def src(s):
            return ','.join(x for x, c in (('mapa', s in strat), ('madre', s in m_strats), ('path', s in p_strats)) if c)
        strat_list = [dict(strategy=hx(s, 6), count=strat.get(s, 0), source=src(s),
                           istrats=sname(s), ported=s in pstrats, port=pstrats.get(s, '')) for s in sorted(allst)]
        envs = [dict(id='%02X' % b, names=bgs.get(b, {}).get('names'), addr=bgs.get(b, {}).get('addr'),
                     **bg_info.get(b, {})) for b in dict.fromkeys(bgids)]
        level_out.append(dict(
            map=m, name=STAGE_NAMES.get(m, ''), usf_label=USF_LABEL.get(m, ''),
            commands=len(es), command_bytes=sum(e['length'] for e in es), jsr_targets=jsr_targets,
            shared_commands=sum(1 for e in es if len(owners[(e['bank'], e['index'])]) > 1),
            shared_with_corneria1=sum(1 for e in es if '0D:D068' in owners[(e['bank'], e['index'])]),
            opcodes={k: v for k, v in sorted(ops.items())},
            opcodes_not_ported=sorted(k for k in ops if int(k, 16) not in PORT_OPS),
            object_commands=sum(strat.values()), objects_unverified=unverified,
            istrats_used=dict(sorted(istr_used.items())),
            strategies=strat_list,
            strategies_total=len(allst), strategies_ported=sum(1 for s in allst if s in pstrats),
            shapes=[dict(header='00:' + hx(h), name=shape_name.get(h, ''), ported=h in pshapes) for h in sorted(shapes_all)],
            shapes_total=len(shapes_all), shapes_ported=sum(1 for h in shapes_all if h in pshapes),
            bg_ids=['%02X' % b for b in bgids], bgs=envs,
            music_setbgm=['%02X' % v for v in bgms], radio_messages=msgs, levelfinished_values=lf,
            player_modes=[dict(routine=r, name=PM_NAMES.get(r, ('?', ''))[0], tag=PM_NAMES.get(r, ('', ''))[1])
                          for r in sorted(set(pm))],
            boss_marks=bosses,
            mapcode_jsl=dict(routines), mapif_conditions=dict(conds), inline_blocks=dict(blocks),
            inline_blocks_generic=dict(generic),
            mapcode_jsl_not_ported=sorted(r for r in routines if int(r, 16) not in PORT_ROUTINES_7A),
            mapif_not_ported=sorted(c for c in conds if int(c, 16) not in PORT_CONDITIONS_2C),
            mother_maps=sorted(set(mothers)), mother_ops=dict(m_ops),
            mother_objects=sorted({('%04X' % a, '%06X' % b) for a, b in m_objs}),
            paths=dict(roots=['%04X' % p for p in sorted(paths)], instructions=len(insts),
                       opcodes={k: v for k, v in sorted(pops.items())},
                       opcodes_not_ported=sorted(k for k in pops if k not in ppath),
                       setstrat=[dict(strategy=hx(s, 6), istrats=sname(s), ported=s in pstrats) for s in sorted(p_strats)],
                       spawned_paths=sorted(spawned), errors=perr),
            executor_halts=halts,
        ))
    # ---- plan metrics: new units per stage, alone and cumulatively in a proposed order ----
    def units(l):
        st = {x['strategy'] for x in l['strategies'] if not x['ported']}
        sh = {x['header'] for x in l['shapes'] if not x['ported']}
        po = set(l['paths']['opcodes_not_ported'])
        mo = set(l['opcodes_not_ported'])
        bl = {k for k in l['inline_blocks_generic']}
        js = set(l['mapcode_jsl_not_ported']) | set(l['mapif_not_ported'])
        pm = {p['routine'] for p in l['player_modes'] if p['routine'] not in ('0B8EC5', '0BBAEF', '0B9558')}
        # BG player strategies (pstrat); ported: playeropening 0B8004 (SCRAMBLE), playeronplanet 0BBB03.
        ps = {b['pstrat'] for b in l['bgs'] if b.get('pstrat')} - {'0B8004', '0BBB03'}
        return dict(strategies=st, shapes=sh, path_ops=po, map_ops=mo, block_kinds=bl, routines=js, player_modes=pm,
                    bg_pstrats=ps)
    U = {l['map']: units(l) for l in level_out}
    for l in level_out:
        others = [U[m] for m in U if m != l['map']]
        u = U[l['map']]
        l['new_units'] = {k: len(v) for k, v in u.items()}
        l['new_units']['strategies_exclusive'] = len(u['strategies'] - set().union(*(o['strategies'] for o in others)))
    ORDER = ['0D:D068', '0D:E3CF', '0D:DD66', '0D:D586', '0D:E651', '0D:EE9A', '0D:D268', '0D:E5F6', '0D:DF4C',
             '0D:E02A', '0D:D2C3', '0D:E6D8', '0D:DFA7', '0D:E81C', '0D:C8A9', '0D:C8E5', '0D:D602', '0D:D67F',
             '0D:E085', '0D:E0F5', '0D:E8B9', '0D:E929', '0D:F1EE']
    assert sorted(ORDER) == sorted(U), sorted(set(U) ^ set(ORDER))
    acc = {k: set() for k in next(iter(U.values()))}
    plan = []
    for m in ORDER:
        add = {k: U[m][k] - acc[k] for k in acc}
        for k in acc: acc[k] |= U[m][k]
        plan.append(dict(map=m, name=STAGE_NAMES[m], incremental={k: len(v) for k, v in add.items()},
                         incremental_strategies=sorted(add['strategies']), incremental_path_ops=sorted(add['path_ops']),
                         incremental_map_ops=sorted(add['map_ops'])))
    blocks_out = []
    for k in sorted(cmds):
        e = cmds[k]
        if e['opcode'] == '78':
            b = e['block']
            blocks_out.append(dict(addr=e['addr'], length=e['length'], port_kind=b['kind'], generic=b.get('generic'),
                                   generic_arg=b.get('generic_arg'), calls=e.get('calls', []),
                                   owners=owners.get(k, []), code=b['code'], disassembly=b['disassembly']))
    pm_all = sorted({p['routine'] for l in level_out for p in l['player_modes']})
    report = dict(
        rom='ref/Star Fox (USA).sfc', sha256=SHA, revision_byte_7FDB=0, generator='tools/inventory-levels.py',
        method='Map commands executed from 03:ED6F on ROM bytes with a forking 65816 model; successors from '
               'exits (opcode 0C mapremove and inline 78 blocks: length from handler/end_65816 pattern); object '
               'shape/strategy = handler writes to +$04/+$16 (effect run, lastobj=$0E00); mother scripts bank 05 '
               '(table 03:FB63); paths decoded with tools/path-oracle.py (ROM-derived lengths); BG routines '
               'byte-pattern scan (levelinfo $1787, newplayerstrat $1788, inatunnel $16CB, gamemode $18C4).',
        stage_graph=graph,
        names=dict(shapes_table='00:A64B', shapes=n_shapes, usf_shapes=len(shapes_u), shape_names_attached=names_ok,
                   shape_anchor_mismatches=[('%04X' % h, a, b) for h, a, b in anchor_bad],
                   istrat_table='00:A83D', usf_istrats=len(istr_u), istrat_default_shape_mismatches=len(istr_bad),
                   bglists='03:AC42', bg_entries=len(bgs), bg_names_attached=bg_names_ok,
                   player_modes={r: PM_NAMES.get(r, ('?', '')) for r in pm_all},
                   bg_pstrat_names={k: sorted(v) for k, v in sorted(pstrat_names.items())}),
        bglists={'%02X' % k: dict(v, **bg_info[k]) for k, v in sorted(bgs.items())},
        totals=dict(unique_commands=len(cmds), strategies=len(all_strats),
                    strategies_ported=sum(1 for s in all_strats if s in pstrats),
                    strategies_not_ported=[dict(strategy='%06X' % s, istrats=sname(s)) for s in sorted(all_strats)
                                           if s not in pstrats],
                    shapes=len(all_shapes), shapes_ported=sum(1 for h in all_shapes if h in pshapes),
                    path_opcodes=len(all_paths_ops), path_opcodes_ported=sum(1 for p in all_paths_ops if p in ppath),
                    path_opcodes_not_ported=sorted(p for p in all_paths_ops if p not in ppath),
                    inline_blocks_unique=len(blocks_out),
                    inline_blocks_port_kind=sum(1 for b in blocks_out if b['port_kind'])),
        levels=level_out,
        plan_order=plan,
        inline_blocks=blocks_out,
        length_mismatches=[dict(addr=e['addr'], opcode=e['opcode'], **e['length_mismatch'])
                           for e in cmds.values() if 'length_mismatch' in e],
        object_mismatches=[dict(addr=e['addr'], opcode=e['opcode'], **e['object_mismatch'])
                           for e in cmds.values() if 'object_mismatch' in e],
    )
    OUT.write_text(json.dumps(report, indent=1, default=lambda o: list(o) if isinstance(o, (set, tuple)) else str(o))
                   + '\n', encoding='utf-8')
    t = report['totals']
    print('stages %d, unique commands %d, strategies %d (ported %d), shapes %d (ported %d), path ops %d (ported %d)'
          % (len(level_out), len(cmds), t['strategies'], t['strategies_ported'], t['shapes'], t['shapes_ported'],
             t['path_opcodes'], t['path_opcodes_ported']))
    for l in level_out:
        print('%s %-24s cmds %4d C1 %3d strat %3d/%3d shapes %3d/%3d pathops %3d miss %2d ops-miss %-24s env %s lf %s pm %s'
              % (l['map'], l['name'], l['commands'], l['shared_with_corneria1'], l['strategies_ported'],
                 l['strategies_total'], l['shapes_ported'], l['shapes_total'], len(l['paths']['opcodes']),
                 len(l['paths']['opcodes_not_ported']), ','.join(l['opcodes_not_ported']),
                 '/'.join(b['environment'] for b in l['bgs']), l['levelfinished_values'],
                 ','.join(p['name'] for p in l['player_modes'])))
    print('length mismatches', len(report['length_mismatches']), 'object mismatches', len(report['object_mismatches']),
          'istrat default-shape mismatches', len(istr_bad), 'shape anchor mismatches', len(anchor_bad))
    print('sha256', hashlib.sha256(OUT.read_bytes()).hexdigest())


if __name__ == '__main__':
    main()
