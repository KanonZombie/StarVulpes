"""Recover the complete Corneria 1 map script (route 1) from the selected ROM.

Authority: ref/Star Fox (USA).sfc (USA rev0, LoROM, no copier header).
Entry: course1[0] = level1_1 = 0D:D068 (map pointer $5068). Every command
reachable from it (map1_1a 0D:8000, map1_1b 0D:8920, cl_ground 0D:CF1D and
every branch/loop/subroutine/65816-switch target) is found by EXECUTING the
original dispatcher (03:ED6F, table 03:ED83+opcode) and handlers on the actual
command bytes. Unknown RAM makes conditional branches fork, so every possible
exit (continue at ED6F, yield via rts, return via maprts) is enumerated.

Outputs (same interpreter design as build/m4-script-boundaries.inc):
  build/level1-script.bin   ROM bytes for map pointers [BASE, END)
  build/level1-script.inc   M4_LEVEL_SCRIPT_BASE, boundaries, events, blocks
  build/level1-script.json  machine-readable inventory with ROM offsets
"""
from starfox_rom import rom_hex, rom_pattern
import hashlib
import json
import re
import runpy
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHA = '3857b5294ea8f7468849437bb2d8271564e8a0ff30774622e9c872bcbd53a84d'
BANK = 0x0D
ENTRY = 0x5068                 # 0D:D068 level1_1 (course1 in 05:8030)
NATIVE = {0x50, 0x4E, 0x4C, 0x64, 0x66, 0x10, 0x12, 0x8A, 0x2E}   # src/level/script.asm
SHAPES_TAB, ISTRAT_TAB = 0xA64B, 0xA83D                           # bank 00
DIS = runpy.run_path(str(ROOT/'tools/dis65816.py'))
OPS, SIZE = DIS['M'], DIS['SIZE']

# Lengths claimed per opcode; each is CHECKED against handler execution below.
LEN = {0x00: 11, 0x02: 1, 0x04: 5, 0x10: 3, 0x12: 3, 0x14: 2, 0x28: 4, 0x2a: 1,
       0x2c: 6, 0x2e: 4, 0x36: 4, 0x38: 5, 0x3c: 4, 0x44: 1, 0x4c: 1, 0x4e: 1,
       0x50: 1, 0x5a: 1, 0x5c: 5, 0x5e: 6, 0x64: 1, 0x66: 1, 0x70: 7, 0x74: 10,
       0x76: 6, 0x7a: 4, 0x82: 2, 0x84: 1, 0x86: 14, 0x8a: 2, 0x8c: 3}
NAMES = {0x00: 'mapobj', 0x02: 'end', 0x04: 'loop', 0x10: 'setbg', 0x12: 'mapwait',
         0x14: 'setbgm', 0x28: 'mapjsr', 0x2a: 'maprts', 0x2c: 'mapif', 0x2e: 'mapgoto',
         0x36: 'setalvar.b', 0x38: 'setalvar.w', 0x3c: 'setalxvar.b', 0x44: 'setfadedown',
         0x4c: 'mapwaitfade', 0x4e: 'setqfadeup', 0x50: 'setqfadedown', 0x5a: 'mapspecial',
         0x5c: 'setvar.b', 0x5e: 'setvar.w', 0x64: 'waitsetbg', 0x66: 'setbginfo',
         0x70: 'mapqobj', 0x74: 'mapdobj', 0x76: 'mapqobj2', 0x78: '65816', 0x7a: 'mapcode_jsl',
         0x82: 'sendmessage', 0x84: 'mapcspecial', 0x86: 'nobj', 0x8a: 'mapwait2',
         0x8c: 'mapsetpath'}
# Semantics of every opcode used here, read from its handler (cited address).
SEMANTICS = {
    0x00: 'counter=w1; alloc obj (fail: lastobj=0); x=w3,y=w5,z=playerZ+w7; shape=shapes[b9]; strat=istrats[b10]; lastobj=obj; continue if counter==0 else yield',
    0x02: 'store pointer (unchanged) and rts; counter untouched: interpreter stays here forever',
    0x04: 'loop table $174D/$1745 keyed by pointer: first visit stores count=w3 and jumps w1; later visits count-1, jump while !=0, else free slot and advance 5 (body runs count+1 times)',
    0x10: 'bg request: $1743=w1, $1F15|=4 (03:F514)',
    0x14: 'if !($14D9&$80): $1F49=b1, $1F48=0 (music)',
    0x28: 'push (pointer,bank) to $1705+$1732 (3 bytes), $1732+=3, $1734++, bank=b3, pointer=w1',
    0x2a: '$1732-=3, restore bank and pointer, pointer+=4 (skips the mapjsr), $1734--',
    0x2c: 'call bank b3:w1 (rtl trick); carry set: pointer=w4 (same bank), continue; carry clear: pointer+=6, counter=1, yield',
    0x36: 'if lastobj: byte [lastobj+w1]=b3',
    0x38: 'if lastobj: word [lastobj+w1]=w3',
    0x3c: 'if lastobj: byte 7E:2000+lastobj+w1 = b3',
    0x44: 'fade dir $18B4=$FF',
    0x5a: 'if lastobj: obj+$1D=1, specialobjtotal($173E)++',
    0x5c: 'byte [long b2..b4]=b1',
    0x5e: 'word [long b3..b5]=w1',
    0x70: 'counter=b1<<4; alloc; x=s8(b2)*4, y=s8(b3)*4, z=playerZ+b4*16; shape=shapes[b5]; strat=istrats[b6]; continue if counter==0 else yield',
    0x74: 'counter=w1; alloc; x=w3,y=w5,z=playerZ+w7; strat=istrats[b9], shape=shapes[istrat default]; continue/yield as 00',
    0x76: 'as 70 but strat=istrats[b5], shape=shapes[istrat default]',
    0x78: 'jsl inline 65816 after opcode (M8,X16,DB=0,X=lastobj); code ends ldx #next / rtl to 03:ED6F',
    0x7a: 'jsl b3:(w1+1) (M8,X16,DB=0,X=lastobj), then pointer+=4, continue',
    0x82: 'jsl 03:E993 with A=b1 (radio message)',
    0x84: 'if lastobj: obj+$20=$80, specialobjtotal($173E)++',
    0x86: 'counter=w1; alloc; x=w3,y=w5,z=playerZ+w7; shape header=w9 (bank 00), strat=long b11..b13; continue/yield as 00',
    0x8c: 'if lastobj: word obj+$28 = w1 (path offset, data 04:A3FE+w1)',
    0x12: 'counter=w1, yield (0 continues)', 0x8a: 'counter=b1<<4, yield',
    0x2e: 'bank=b3, pointer=w1', 0x4c: 'wait fade: blocked unless $18B5==0 and INIDISP==$80',
    0x4e: '$18B4=2', 0x50: '$18B4=$FE', 0x64: 'wait bg list empty', 0x66: '$1F15|=8',
}


class Halt(Exception):
    pass


def load_rom():
    rom = (ROOT/'ref/Star Fox (USA).sfc').read_bytes()
    assert len(rom) == 1 << 20 and hashlib.sha256(rom).hexdigest() == SHA and rom[0x7fdb] == 0
    return rom


ROM = load_rom()


def rom_word(o): return int.from_bytes(ROM[o:o+2], 'little')
def phys(bank, addr): return (bank & 0x7f)*0x8000 + (addr & 0x7fff)
def mphys(index): return phys(BANK, index)             # map pointer -> file offset
def s8(v): return v-256 if v & 0x80 else v
def s16(v): return v-65536 if v & 0x8000 else v


# ----------------------------------------------------------------------------
# Forking 65816 executor (M/X widths, byte stack, RAM dict; unknown = None).
# Opaque JSL/RTL-called routines preserve X/Y and clobber A and flags.
# ----------------------------------------------------------------------------
class State:
    def __init__(s, x, ram):
        s.pc = 0x03ED6F; s.al = s.ah = None; s.x = x; s.y = None; s.m8 = True
        s.db = 0x00; s.stack = []   # $1FF6 < $2000 is WRAM in any game bank
        s.z = s.n = s.c = None; s.ram = dict(ram)
        s.reads = set(); s.objw = {}; s.writes = {}; s.calls = []; s.steps = 0

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
        if cmd <= p < cmd+64:
            st.reads.add(p-cmd)
        return ROM[p]
    return None                                     # registers / expansion


def write_byte(st, addr, v):
    bank, a = addr >> 16, addr & 0xffff
    key = a if (bank < 0x40 or 0x80 <= bank < 0xc0 or bank == 0x7e) and a < 0x2000 else addr
    assert not (bank < 0x40 and 0x8000 <= a), 'write to ROM'
    st.ram[key] = v; st.writes[key] = v


def run(index, ram, cmd):
    """All exits of one dispatch of the command at map pointer `index`."""
    exits, work = [], [State(index, ram)]
    while work:
        st = work.pop()
        while True:
            st.steps += 1
            assert st.steps < 4000, hex(st.pc)
            res = step(st, cmd, work)
            if res:
                exits.append((res, st)); break
    assert len(exits) < 512
    return exits


def step(st, cmd, work):
    pb, pc = st.pc >> 16, st.pc & 0xffff
    if pb == 3 and pc == 0xED6F and st.steps > 1:
        return ('continue', st.x)
    base = phys(pb, pc); op = ROM[base]
    name, mode = OPS[op]
    n = SIZE.get(mode, 0)
    if mode == '#m': n = 1 if st.m8 else 2
    if mode == '#x': n = 2
    arg = int.from_bytes(ROM[base+1:base+1+n], 'little') if n else None
    nxt = (pb << 16) | ((pc+1+n) & 0xffff)
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
        else: st.z = (v & ((1 << 8*width)-1)) == 0; st.n = bool(v >> (8*width-1) & 1)

    def ea():
        """Effective 24-bit address (None if unknown), and object field offset."""
        if mode in ('abs', 'abs,x', 'abs,y'):
            idx = {'abs': 0, 'abs,x': st.x, 'abs,y': st.y}[mode]
            if idx is None or st.db is None: return None, arg
            return ((st.db << 16) + arg + idx) & 0xffffff, None
        if mode in ('long', 'long,x'):
            idx = 0 if mode == 'long' else st.x
            return (None, None) if idx is None else ((arg+idx) & 0xffffff, None)
        if mode in ('dp', 'dp,x', 'dp,y'):
            idx = {'dp': 0, 'dp,x': st.x, 'dp,y': st.y}[mode]
            return (None, arg) if idx is None else ((arg+idx) & 0xffff, None)
        if mode == '[dp]':
            b = [st.ram.get(arg+i) for i in range(3)]
            return (None, None) if None in b else (b[0] | b[1] << 8 | b[2] << 16, None)
        raise Halt((hex(st.pc), name, mode))

    def load(size):
        a, off = ea()
        if a is None: return None
        bs = [read_byte(st, (a & 0xff0000) | ((a+i) & 0xffff), cmd) for i in range(size)]
        return None if None in bs else sum(b << 8*i for i, b in enumerate(bs))

    def store(v, size):
        a, off = ea()
        for i in range(size):
            b = None if v is None else (v >> 8*i) & 0xff
            if a is None:
                if off is not None: st.objw[off+i] = b
            else:
                write_byte(st, (a & 0xff0000) | ((a+i) & 0xffff), b)

    def operand(size):
        return arg if mode in ('#m', '#x') else load(size)

    def push(v, size):
        for i in reversed(range(size)): st.stack.append(None if v is None else (v >> 8*i) & 0xff)

    def pull(size):
        assert len(st.stack) >= size, ('stack underflow', hex(base))
        bs = [st.stack.pop() for _ in range(size)]
        return None if None in bs else sum(b << 8*i for i, b in enumerate(bs))

    def branch(cond):
        if cond is None:
            t = st.fork(); work.append(t); t.pc = target
        elif cond:
            st.pc = target

    if mode in ('rel', 'rel16'):
        d = arg - (1 << 8*n) if arg >= 1 << (8*n-1) else arg
        target = (pb << 16) | ((pc+1+n+d) & 0xffff)
    if op == 0xc2:
        st.m8 = st.m8 and not arg & 0x20
    elif op == 0xe2:
        assert not arg & 0x10, 'X8 not modelled'; st.m8 = st.m8 or bool(arg & 0x20)
    elif name == 'lda': v = operand(w); setA(v); nz(v, w)
    elif name in ('ldx', 'ldy'):
        if mode == 'abs,y' and arg == 0x1705 and name == 'ldx':
            st.x = ('ret', 0); return None                 # maprts: saved pointer
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
        m = operand(size); mask = (1 << 8*size)-1
        if isinstance(reg, tuple): reg = None
        if reg is None or m is None:
            if name in ('adc', 'sbc', 'and', 'ora', 'eor'): setA(None)
            st.z = st.n = None
            if name in ('adc', 'sbc', 'cmp', 'cpx', 'cpy'): st.c = None
            return None
        if name == 'adc':
            if st.c is None: setA(None); st.z = st.n = st.c = None; return None
            r = reg+m+st.c; st.c = r > mask; setA(r & mask); nz(r, size)
        elif name == 'sbc':
            if st.c is None: setA(None); st.z = st.n = st.c = None; return None
            r = reg-m-(1-st.c); st.c = r >= 0; setA(r & mask); nz(r & mask, size)
        elif name in ('cmp', 'cpx', 'cpy'): st.c = reg >= m; nz((reg-m) & mask, size)
        elif name == 'and': setA(reg & m); nz(reg & m, size)
        elif name == 'ora': setA(reg | m); nz(reg | m, size)
        elif name == 'eor': setA(reg ^ m); nz(reg ^ m, size)
        else: st.z = (reg & m) == 0
    elif op in (0x0a, 0x4a, 0x1a, 0x3a):
        v = A(); mask = (1 << 8*w)-1
        if v is None: st.c = None if op in (0x0a, 0x4a) else st.c; nz(None, w); return None
        if op == 0x0a: st.c = bool(v >> (8*w-1) & 1); v = (v << 1) & mask
        elif op == 0x4a: st.c = bool(v & 1); v >>= 1
        else: v = (v + (1 if op == 0x1a else -1)) & mask
        setA(v); nz(v, w)
    elif name in ('inc', 'dec'):
        v = load(w); v = None if v is None else (v + (1 if name == 'inc' else -1)) & ((1 << 8*w)-1)
        store(v, w); nz(v, w)
    elif name in ('inx', 'dex', 'iny', 'dey'):
        r = name[2]; v = getattr(st, r); d = 1 if name[0] == 'i' else -1
        if isinstance(v, tuple): setattr(st, r, (v[0], v[1]+d))
        else: setattr(st, r, None if v is None else (v+d) & 0xffff)
    elif op == 0xaa: st.x = C16()
    elif op == 0xa8: st.y = C16()
    elif op == 0x9b: st.y = st.x
    elif op == 0xbb: st.x = st.y
    elif op == 0x8a: setA(st.x if not isinstance(st.x, tuple) else None)
    elif op == 0x98: setA(st.y)
    elif op == 0x48: push(A(), w)
    elif op == 0x68: v = pull(w); setA(v); nz(v, w)
    elif op == 0xda: push(st.x, 2)
    elif op == 0xfa: st.x = pull(2)
    elif op == 0x5a: push(st.y, 2)
    elif op == 0x7a: st.y = pull(2)
    elif op == 0x8b: push(st.db, 1)
    elif op == 0xab: st.db = pull(1)
    elif op == 0x08: push(None, 1)
    elif op == 0x28: pull(1)
    elif op in (0x18, 0x38): st.c = op == 0x38
    elif op in (0x58, 0x78, 0xea): pass
    elif mode in ('rel', 'rel16'):
        cond = {'bra': True, 'brl': True, 'beq': st.z, 'bne': None if st.z is None else not st.z,
                'bmi': st.n, 'bpl': None if st.n is None else not st.n, 'bcs': st.c,
                'bcc': None if st.c is None else not st.c}[name]
        branch(cond)
    elif op == 0x4c:
        st.pc = (pb << 16) | arg
        if pb == 3 and arg == 0xED6F: return ('continue', st.x)
    elif op == 0x7c:
        p = phys(pb, (arg + st.x) & 0xffff); st.pc = (pb << 16) | rom_word(p)
        st.handler = st.pc; st.reads = set()       # opcode fetch by the dispatcher
    elif op == 0x20:
        push(nxt-1 & 0xffff, 2); st.pc = (pb << 16) | arg
    elif op == 0x60:
        if not st.stack: return ('yield', st.ram.get('ptr', 'unset'))
        st.pc = (pb << 16) | ((pull(2)+1) & 0xffff)
    elif op == 0x22:
        st.calls.append(dict(routine='%06X' % arg, a=A(), x=st.x if not isinstance(st.x, tuple) else None))
        setA(None); st.z = st.n = st.c = None
    elif op == 0x6b:
        lo = pull(2); bk = pull(1); t = (bk << 16) | ((lo+1) & 0xffff)
        if bk == 3 or bk == BANK:
            st.pc = t                                   # handler continuation / inline map code
        else:                                           # rtl-trick call of an external routine
            st.calls.append(dict(routine='%06X' % t, a=None, x=None, via='rtl'))
            setA(None); st.z = st.n = st.c = None
            lo = pull(2); bk = pull(1); st.pc = (bk << 16) | ((lo+1) & 0xffff)
    elif op == 0x5c:
        return ('external', arg)
    else:
        raise Halt(('unmodelled', '%06X' % ((pb << 16) | pc), name, mode))
    return None


# ----------------------------------------------------------------------------
# Inline 65816 block (opcode 78) semantic templates. Code is matched EXACTLY;
# {name:n} captures n little-endian bytes. Kinds are the boundary-table kind.
# ----------------------------------------------------------------------------
BLOCKS = [
    ('branch_if_byte_mask', 0x10, rom_pattern(0x28722, 15, [(3, 'addr', 2), (8, 'branch', 2), (12, 'next', 2)]),
     'if (byte 00:addr & mask) != 0 -> branch else next'),
    ('branch_if_byte_mask', 0x10, rom_pattern(0x29b59, 17, [(3, 'addr', 2), (6, 'mask', 1), (10, 'branch', 2), (14, 'next', 2)]),
     'if (byte 00:addr & mask) != 0 -> branch else next'),
    ('branch_if_byte_mask', 0x10, rom_pattern(0x28599, 14, [(1, 'addr', 3), (7, 'branch', 2), (11, 'next', 2)]),
     'if (byte addr & mask) != 0 -> branch else next'),
    ('player_mode', 0x12, rom_pattern(0x29b80, 29, [(6, 'routine', 3), (12, 'lo', 2), (20, 'bk', 1), (26, 'next', 2)]),
     'DB=$7E; jsl routine; newplayerstrat (00:1788 word + 00:178A bank) = routine'),
    ('set_restart', 0x13, rom_pattern(0x28775, 17, [(5, 'bank', 1), (7, 'restart', 2), (14, 'next', 2)]),
     'jsl 09:98CB (A=bank, X=restart): $173F=restart, $1FF7=bank, saves $1743/$1EED and the map call/loop stacks (checkpoint)'),
    ('trigger_se', 0x14, rom_pattern(0x2878d, 10, [(1, 'se', 1), (7, 'next', 2)]),
     'jsl 03:B7E5 with A=se (sound effect; skipped there if $1FD1!=0 or player dead)'),
    ('clear_demo', 0x15, rom_pattern(0x6cf2b, 26, [(23, 'next', 2)]),
     'DB=$7E; jsl 06:BB22 (calcteamdamage); jsl 0B:9558 (player mode ClearDemo); $14DC&=$EF'),
    ('friend_message', 0x16,
     rom_pattern(0x2d904, 46, [(8, 'hp', 2), (17, 'm10', 1), (25, 'm20', 1),
                              (33, 'm30', 1), (37, 'mlow', 1), (43, 'next', 2)]),
     '$1FFD=$FF; h=byte 00:hp; if h!=0: jsl 03:E993 with A = m10 if h==10, m20 if 20, m30 if 30, else mlow'),
    ('or_byte', 0x17, rom_pattern(0x28742, 14, [(3, 'addr', 2), (6, 'value', 1), (8, 'addr2', 2), (11, 'next', 2)]),
     'byte 00:addr |= value'),
    ('nofire_boss_hp', 0x18, rom_pattern(0x28751, 20, [(17, 'next', 2)]),
     'pshipflags $14D8|=$40 (no fire); byte 70:019A (m_bossmaxHP) = 0'),
    ('mark_boss', 0x19, rom_pattern(0x6909f, 13, [(10, 'next', 2)]), 'jsl 1F:DF62 with A=0 (M16): append to list at $1F6B/$1F6D'),
    ('and_byte', 0x1a, rom_pattern(0x2db99, 12, [(1, 'addr', 2), (4, 'value', 1), (6, 'addr2', 2), (9, 'next', 2)]),
     'byte 00:addr &= value (M8 on entry)'),
]
ROUTINES = {   # opcode 7A targets (handler 03:EE84 jumps to b3:w1+1)
    0x02FD48: (0x20, 'initblack_l', '$1964(stayblack)=$28; $14C3|=2; $1492=$1E; $148F=0; jsl 02:FD76 (fade step); $18B5=0'),
    0x02F2EC: (0x21, 'setcharmapfrommap_l', 'sei; rewrite BG tilemap VRAM $2C40.. (28x24 + meters digits if 70:021C!=0); cli'),
    0x09B1DE: (0x22, 'mapexploderobot', 'find object with shape header 00:BB9C (robot_0) in list $121F; if found: obj+$20|=$20'),
}
CONDITIONS = {  # opcode 2C routines (handler 03:F3A1, carry set -> goto w4)
    0x068BB9: (0x28, 'chkstratdone1', 'if $14D2&8: $14D2&=~8, carry=1 else carry=0'),
    0x068BE1: (0x29, 'chkbossdead', 'if $14D2&4: $14D2&=~4, 70:019A=0, 70:019C=0, carry=1 else carry=0'),
}


def match(template, data):
    pos, out = 0, {}
    for tok in template.split():
        for part in re.findall(r'\{\w+:\d\}|[0-9a-f]{2}', tok):
            if part.startswith('{'):
                k, nb = part[1:-1].split(':'); nb = int(nb)
                if pos+nb > len(data): return None
                out[k] = int.from_bytes(data[pos:pos+nb], 'little'); pos += nb
            else:
                if pos >= len(data) or data[pos] != int(part, 16): return None
                pos += 1
    return out, pos


def decode_block(index):
    o = mphys(index)
    hits = []
    for name, kind, tpl, sem in BLOCKS:
        r = match(tpl, ROM[o+1:o+100])
        if r and r[0]['next'] == (index+1+r[1]) & 0x7fff:
            hits.append((name, kind, r[0], 1+r[1], sem))
    assert len(hits) == 1, (hex(index), hits)
    name, kind, f, length, sem = hits[0]
    if 'addr' in f and 'mask' not in f: f['mask'] = 0xff
    if name == 'player_mode': assert f['routine'] == f['lo'] | f['bk'] << 16
    if 'addr2' in f: assert f['addr'] == f['addr2']
    if name == 'set_restart': assert f['restart'] == f['next'] and f['bank'] == BANK
    addr = f.get('addr', f.get('routine', f.get('hp', 0)))
    if 'addr' in f and addr < 0x10000: addr |= 0                     # DB=0 inside blocks
    arg2 = {'branch_if_byte_mask': f.get('mask', 0), 'or_byte': f.get('value', 0),
            'and_byte': f.get('value', 0), 'trigger_se': f.get('se', 0),
            'friend_message': (f.get('m10', 0) << 24 | f.get('m20', 0) << 16 | f.get('m30', 0) << 8 | f.get('mlow', 0)),
            'set_restart': f.get('restart', 0), 'nofire_boss_hp': 0x40}.get(name, 0)
    if name == 'set_restart': addr = 0x0998CB
    if name == 'trigger_se': addr = 0x03B7E5
    if name == 'clear_demo': addr = 0x06BB22
    if name == 'mark_boss': addr = 0x1FDF62
    if name == 'nofire_boss_hp': addr = 0x0014D8
    return dict(name=name, kind=kind, length=length, fields=f, semantics=sem,
                branch=f.get('branch'), next=f['next'], arg=addr, arg2=arg2,
                code=ROM[o+1:o+length].hex(),
                disassembly=[l for l in DIS['disasm'](ROM, BANK, (index | 0x8000)+1, 40, m8=True, x8=False)
                             if int(l[3:7], 16) < (index | 0x8000)+length])


# ----------------------------------------------------------------------------
def analyse(index):
    o = mphys(index); op = ROM[o]
    base_ram = {0x1ff6: BANK}
    exits = run(index, base_ram, o)
    handler = exits[0][1].__dict__.get('handler')
    assert all(s.__dict__.get('handler') == handler for _, s in exits)
    assert handler == 0x030000 | rom_word(0x1ED83+op), hex(index)
    reads = set().union(*(s.reads for _, s in exits))
    # Effects run: a concrete last object O and player at P with worldZ 0.
    O, P = 0x0E00, 0x0F00
    eff_ram = dict(base_ram)
    eff_ram.update({0x16f9: O & 0xff, 0x16fa: O >> 8, 0x123a: P & 0xff, 0x123b: P >> 8, P+0x10: 0, P+0x11: 0})
    eff = run(index, eff_ram, o)
    objw, writes, calls = {}, {}, []
    for _, s in eff:
        for k, v in s.objw.items(): objw.setdefault(k, set()).add(v)
        for k, v in s.writes.items():
            if isinstance(k, int): writes.setdefault(k, set()).add(v)
        calls += [c for c in s.calls if c not in calls]
    return op, handler, exits, reads, objw, writes, calls, O


def decode(index):
    o = mphys(index); op = ROM[o]
    op_h, handler, exits, reads, objw, writes, calls, O = analyse(index)
    e = dict(index=index, addr='%02X:%04X' % (BANK, index | 0x8000), rom_offset=o,
             opcode=op, name=NAMES.get(op, '?'), handler='03:%04X' % (handler & 0xffff))
    targets = []
    if op == 0x78:
        b = decode_block(index); length = b['length']; e['block'] = b
        targets = [b['next']] + ([b['branch']] if b['branch'] is not None else [])
    else:
        assert op in LEN, ('opcode without verified length', hex(o), hex(op))
        length = LEN[op]
        # Operand bytes read by the handler must lie inside, and reach, the claimed length.
        # A 16-bit load may touch one byte past the command; its high byte is then
        # discarded (and #$00FF, or 03:E993 for opcode 82).
        assert reads <= set(range(length+1)), (hex(index), sorted(reads), length)
        if length > 1: assert max(reads) >= length-1, (hex(index), sorted(reads))
        if op == 0x82: assert ROM[0x1E993:0x1E999].hex() == rom_hex(0x1e993, 6)
    raw = ROM[o:o+length]; e['length'] = length; e['bytes'] = raw.hex()
    w = lambda k: int.from_bytes(raw[k:k+2], 'little')
    if op in (0x04, 0x28, 0x2e):
        targets = [w(1)] + ([index+length] if op == 0x04 else [])
        if op != 0x04: assert raw[3] == BANK, 'cross-bank jump'
    if op == 0x2c: targets = [w(4)]
    if op == 0x28: e['return_to'] = index+length
    # Classify every exit of the real handler.
    seq = {index+length}
    allowed = set(targets) | seq
    kinds = set()
    for (kind, x), s in exits:
        if kind == 'yield':
            assert x in allowed | {index}, (hex(index), kind, x); kinds.add(('yield', x))
        elif kind == 'continue':
            if isinstance(x, tuple):
                assert op == 0x2a and x == ('ret', 0) or x[0] == 'ret'
                kinds.add(('return', x[1])); continue
            assert x in allowed, (hex(index), kind, x, allowed); kinds.add(('continue', x))
        else:
            raise AssertionError((hex(index), kind))
    e['exits'] = sorted(['%s:%s' % (k, ('%04X' % v) if isinstance(v, int) else v) for k, v in kinds])
    if op == 0x2a:
        assert kinds == {('return', LEN[0x28])}, kinds            # maprts skips the 4-byte mapjsr
    nexts = sorted({v for k, v in kinds if k != 'return' and v != index})
    if op not in (0x02, 0x2a, 0x2e, 0x28):
        assert index+length in nexts or op == 0x78 and b['next'] in nexts, (hex(index), nexts)
    e['next'] = nexts
    # ---- fields --------------------------------------------------------------
    def strat_of(ii):
        p = ISTRAT_TAB-0x8000+4*ii
        return ROM[p] | ROM[p+1] << 8 | ROM[p+2] << 16, ROM[p+3]

    def shape_of(si): return rom_word(SHAPES_TAB-0x8000+2*si)
    if op in (0x00, 0x74, 0x86):
        e.update(wait_after=w(1), x=s16(w(3)), y=s16(w(5)), z_rel=s16(w(7)))
        if op == 0x00:
            si, ii = raw[9], raw[10]; st, _ = strat_of(ii); e.update(shape_index=si, istrat_index=ii)
            e.update(shape_header=shape_of(si), strategy=st)
        elif op == 0x74:
            ii = raw[9]; st, si = strat_of(ii)
            e.update(istrat_index=ii, shape_index=si, shape_header=shape_of(si), strategy=st)
        else:
            e.update(shape_header=w(9), strategy=raw[11] | raw[12] << 8 | raw[13] << 16)
    if op in (0x70, 0x76):
        e.update(wait_after=raw[1] << 4, x=s8(raw[2])*4, y=s8(raw[3])*4, z_rel=raw[4]*16)
        if op == 0x70: si, ii = raw[5], raw[6]; st, _ = strat_of(ii)
        else: ii = raw[5]; st, si = strat_of(ii)
        e.update(shape_index=si, istrat_index=ii, shape_header=shape_of(si), strategy=st)
    if 'strategy' in e:
        # Cross-check against the object fields the ORIGINAL handler wrote.
        def field(off, n):
            vals = [objw.get(off+i) for i in range(n)]
            assert all(v is not None and len(v) == 1 for v in vals), (hex(index), off, vals)
            return sum(next(iter(v)) << 8*i for i, v in enumerate(vals))
        assert field(0x0c, 2) == e['x'] & 0xffff and field(0x0e, 2) == e['y'] & 0xffff
        assert field(0x10, 2) == e['z_rel'] & 0xffff                  # player worldZ = 0
        assert field(0x04, 2) == e['shape_header'] and field(0x16, 3) == e['strategy']
        assert writes.get(0x16fd) == {e['wait_after'] & 0xff} and writes.get(0x16fe) == {e['wait_after'] >> 8}
    if op == 0x8a: e['wait'] = raw[1] << 4
    if op == 0x12: e['wait'] = w(1)
    if op in (0x10,): e['bg_id'] = w(1)
    if op in (0x14, 0x82): e['value'] = raw[1]
    if op == 0x04: e.update(target=w(1), count=w(3), body_runs=w(3)+1)
    if op in (0x28, 0x2e): e['target'] = w(1)
    if op in (0x36, 0x38, 0x3c):
        e['offset'] = w(1); e['value'] = raw[3] if op != 0x38 else w(3)
        size = 2 if op == 0x38 else 1
        for i in range(size):
            k = (O + e['offset'] + i) & 0xffff                  # 16-bit index arithmetic
            if op == 0x3c: k += 0x7E2000                        # sta $7E2000,x
            assert writes.get(k) == {(e['value'] >> 8*i) & 0xff}, (hex(index), k, writes)
    if op in (0x5a, 0x84):
        e['offset'], e['value'] = (0x1d, 1) if op == 0x5a else (0x20, 0x80)
        assert writes.get(O+e['offset']) == {e['value']}
    if op == 0x8c:
        e['offset'] = 0x28; e['value'] = w(1); e['path_offset'] = w(1)
        e['path_rom_offset'] = phys(0x04, 0xA3FE + w(1))
        assert writes.get(O+0x28) == {raw[1]} and writes.get(O+0x29) == {raw[2]}
    if op in (0x5c, 0x5e):
        n = 1 if op == 0x5c else 2
        e['value'] = int.from_bytes(raw[1:1+n], 'little')
        e['var'] = int.from_bytes(raw[1+n:4+n], 'little')
        key = e['var'] if (e['var'] >> 16) not in (0, 0x7e) or (e['var'] & 0xffff) >= 0x2000 else e['var'] & 0xffff
        assert writes.get(key) == {e['value'] & 0xff}, (hex(index), writes)
    if op == 0x7a:
        r = (raw[3] << 16) | ((w(1)+1) & 0xffff)
        assert r in ROUTINES and any(c['routine'] == '%06X' % r for c in calls)
        k, nm, sem = ROUTINES[r]; e.update(routine=r, kind=k, routine_name=nm, routine_semantics=sem)
    if op == 0x2c:
        r = (raw[3] << 16) | w(1)
        assert r in CONDITIONS and any(c['routine'] == '%06X' % r for c in calls)
        k, nm, sem = CONDITIONS[r]; e.update(routine=r, kind=k, routine_name=nm, routine_semantics=sem,
                                             target=w(4), else_next=index+length, else_wait=1)
        assert writes.get(0x16fd) == {1}
    if op == 0x78:
        e['kind'] = b['kind']
        for c in calls: assert c['routine'] in ('0B8EC5', '0BBAEF', '0998CB', '03B7E5', '06BB22', '0B9558', '03E993', '1FDF62')
    e['calls'] = calls
    return e, targets


def main():
    cmds, work = {}, [ENTRY]
    while work:
        i = work.pop()
        if i in cmds: continue
        e, targets = decode(i)
        cmds[i] = e
        work += [t for t in e['next'] + targets + ([e['return_to']] if 'return_to' in e else []) if t not in cmds]
    order = sorted(cmds)
    for a, b in zip(order, order[1:]):
        assert a + cmds[a]['length'] <= b, ('overlap', hex(a), hex(b))
    for e in cmds.values():
        for t in e['next'] + [e.get('target', e['index'])] + ([e['block']['branch']] if e.get('block') and e['block']['branch'] is not None else []):
            assert t in cmds, ('target not on boundary', e['addr'], hex(t))
    ends = [e for e in cmds.values() if e['opcode'] == 0x02]
    assert len(ends) == 1 and ends[0]['handler'] == '03:F97F' and ends[0]['addr'] == '0D:D267'
    start, stop = order[0], max(i+cmds[i]['length'] for i in order)
    data = ROM[mphys(start):mphys(start)+(stop-start)]
    assert data == bytes(ROM[mphys(i)] for i in range(start, stop))     # one contiguous bank-0D range
    (ROOT/'build/level1-script.bin').write_bytes(data)

    # ---- research cross-check -------------------------------------------------
    research_path = ROOT/'evidence/research/corneria1-script.json'
    research = json.loads(research_path.read_text(encoding='utf-8')) if research_path.is_file() else {'streams': {}}
    rcmds = {c['addr']: c for s in research['streams'].values() for c in s['commands']}
    diffs = []
    mine = {e['addr']: e for e in cmds.values()}
    for a in sorted(set(rcmds) | set(mine)) if rcmds else ():
        r, m = rcmds.get(a), mine.get(a)
        if not r or not m: diffs.append((a, 'only in ' + ('mine' if m else 'research'))); continue
        if r['bytes'] != m['bytes'] or int(r['opcode'], 16) != m['opcode'] or r['length'] != m['length']:
            diffs.append((a, 'bytes/length')); continue
        if 'count' in r and r['count'] != m.get('body_runs'): diffs.append((a, 'count', r['count'], m.get('body_runs')))
        for k in ('wait_after', 'x', 'y', 'z_rel', 'istrat_index', 'value', 'wait', 'bg_id'):
            if k in r and k in m and r[k] != m[k]: diffs.append((a, k, r[k], m[k]))
        if 'shape_header' in r and int(r['shape_header'][3:], 16) != m['shape_header']: diffs.append((a, 'shape'))
        if 'strategy' in r and int(r['strategy'].replace(':', ''), 16) != m['strategy']: diffs.append((a, 'strategy'))
        if 'target' in r and int(r['target'][3:], 16) & 0x7fff != m.get('target', -1): diffs.append((a, 'target'))
        if 'path_offset' in r and int(r['path_offset'], 16) != m['path_offset']: diffs.append((a, 'path'))
        if m['opcode'] == 0x7a and r['routine'] != '%02X:%04X' % (m['routine'] >> 16, m['routine'] & 0xffff): diffs.append((a, 'routine'))
        if m['opcode'] == 0x78:
            rs = sorted(int(t[3:], 16) & 0x7fff for t in r['switch_targets'])
            ms = sorted(t for t in m['next'] if t != m['index']+m['length'])
            if rs != ms: diffs.append((a, 'switch targets', rs, ms))
    research_sem_notes = []
    for a, m in mine.items():
        if m['opcode'] == 0x78 and a in rcmds:
            research_sem_notes.append(dict(addr=a, research=rcmds[a].get('semantic', ''), rom=m['block']['semantics'],
                                           fields={k: v for k, v in m['block']['fields'].items()}))

    # ---- include --------------------------------------------------------------
    lines = ['; Corneria 1 (level1_1) map script recovered by tools/recover-level-script.py.',
             '; ROM ref/Star Fox (USA).sfc %s; bytes 0D:%04X..0D:%04X (file 0x%05X..0x%05X).'
             % (SHA[:16], start | 0x8000, (stop-1) | 0x8000, mphys(start), mphys(stop-1)),
             'M4_LEVEL_SCRIPT_BASE equ $%04x' % start,
             'M4_LEVEL_SCRIPT_END equ $%04x' % stop,
             'M4_LEVEL_SCRIPT_ENTRY equ $%04x' % ENTRY,
             'M4_LEVEL_SCRIPT_BANK equ $%02x' % BANK,
             'M4_LEVEL_COMMANDS equ %d' % len(order),
             '; index.w,length.w,kind.w per reachable command (sorted by index); kind: 78 block kind,',
             '; 7A routine kind, 2C condition kind, else 0.',
             'M4LevelScriptBoundaries:']
    for i in order:
        e = cmds[i]
        lines.append('        dc.w $%04x,%d,$%02x' % (i, e['length'], e.get('kind', 0)))
    lines += ['        dc.w $ffff,0,0', 'M4LevelScriptBoundariesEnd:', '']
    ev_ops = (0x00, 0x70, 0x74, 0x76, 0x86, 0x36, 0x38, 0x3c, 0x8c, 0x5a, 0x84)
    events = [cmds[i] for i in order if cmds[i]['opcode'] in ev_ops]
    lines += ['; Object create/modify events, 24 bytes: index.w,opcode.w,x.w,y.w,zrel.w,shape.w,',
              '; strategy.l (24-bit),istrat.w ($ffff none),wait_after.w (ROM units, <<4 applied),',
              '; extra.w (path offset / alvar offset / object field), value.w. z = playerZ + zrel.',
              'M4_LEVEL_EVENT_SIZE equ 24', 'M4_LEVEL_EVENTS equ %d' % len(events), 'M4LevelScriptEvents:']
    for e in events:
        vals = [e['index'], e['opcode'], e.get('x', 0) & 0xffff, e.get('y', 0) & 0xffff, e.get('z_rel', 0) & 0xffff,
                e.get('shape_header', 0)]
        extra = e.get('path_offset', e.get('offset', 0)); value = e.get('value', 0)
        lines.append('        dc.w %s\n        dc.l $%06x\n        dc.w $%04x,$%04x,$%04x,$%04x'
                     % (','.join('$%04x' % v for v in vals), e.get('strategy', 0), e.get('istrat_index', 0xffff),
                        e.get('wait_after', 0), extra, value & 0xffff))
    lines += ['        dc.w $ffff', 'M4LevelScriptEventsEnd:', '']
    blocks = [cmds[i] for i in order if cmds[i]['opcode'] in (0x78, 0x7a, 0x2c)]
    kinds = {}
    for _, k, _, sem in BLOCKS: kinds.setdefault(k, sem)
    lines += ['; Explicit-consumer table, 16 bytes: index.w,kind.w,next.w,branch.w ($ffff none),arg.l,arg2.l',
              '; 78: next = ldx #imm fall-through, branch = alternative ldx #imm; 2C: branch = goto if carry,',
              ';     next = pointer+6 with counter 1 (yield); 7A: arg = routine.']
    names = {}
    for nm, k, _, _ in BLOCKS: names[k] = nm
    for r, (k, nm, _) in list(ROUTINES.items()) + list(CONDITIONS.items()): names[k] = nm
    for k in sorted(names):
        lines.append('M4_LEVEL_KIND_%s equ $%02x' % (names[k].upper(), k))
    lines.append('M4LevelScriptBlocks:')
    for e in blocks:
        if e['opcode'] == 0x78:
            b = e['block']; vals = (e['index'], b['kind'], b['next'], 0xffff if b['branch'] is None else b['branch'])
            a1, a2 = b['arg'], b['arg2']
        elif e['opcode'] == 0x7a:
            vals = (e['index'], e['kind'], e['index']+4, 0xffff); a1, a2 = e['routine'], 0
        else:
            vals = (e['index'], e['kind'], e['index']+6, e['target']); a1, a2 = e['routine'], 0
        lines.append('        dc.w %s\n        dc.l $%08x,$%08x' % (','.join('$%04x' % v for v in vals), a1, a2))
    lines += ['        dc.w $ffff', 'M4LevelScriptBlocksEnd:']
    (ROOT/'build/level1-script.inc').write_text('\n'.join(lines)+'\n', encoding='utf-8')

    # ---- json -----------------------------------------------------------------
    used = Counter(cmds[i]['opcode'] for i in order)
    handlers = {'%02X' % op: '03:%04X' % rom_word(0x1ED83+op) for op in sorted(used)}
    non_native = [dict(opcode='%02X' % op, name=NAMES[op], count=used[op], handler=handlers['%02X' % op],
                       semantics=SEMANTICS[op]) for op in sorted(used) if op not in NATIVE]
    def jsonable(e):
        d = {k: v for k, v in e.items() if k != 'block'}
        d['rom_offset'] = '0x%05X' % e['rom_offset']; d['opcode'] = '%02X' % e['opcode']
        for k in ('strategy', 'shape_header', 'routine', 'var', 'path_rom_offset'):
            if k in d: d[k] = '%06X' % d[k] if k != 'path_rom_offset' else '0x%05X' % d[k]
        d['next'] = ['%04X' % v for v in e['next']]
        d['index'] = '%04X' % e['index']
        if 'block' in e:
            b = dict(e['block']); b['next'] = '%04X' % b['next']
            b['branch'] = None if b['branch'] is None else '%04X' % b['branch']
            b['arg'] = '%06X' % b['arg']; d['block'] = b
        return d
    disp = ROM[0x1ED6F:0x1ED83].hex()
    assert disp == rom_hex(0x1ed6f, 20)
    report = dict(
        rom='ref/Star Fox (USA).sfc', sha256=SHA, revision_byte_7FDB=0, generator='tools/recover-level-script.py',
        entry=dict(index='%04X' % ENTRY, addr='0D:D068', note='course1[0] at 05:8030'),
        range=dict(base='%04X' % start, end='%04X' % stop, rom_offset_start='0x%05X' % mphys(start),
                   rom_offset_end='0x%05X' % mphys(stop), sha256=hashlib.sha256(data).hexdigest(), size=len(data)),
        dispatcher=dict(addr='03:ED6F', bytes=disp, table='03:ED83+opcode (word, bank 03)',
                        advance='03:ED42 counter-=playerZ delta; dispatch only when negative (bmi)'),
        method='Each command executed from 03:ED6F on its ROM bytes; unknown RAM forks branches; '
               'jsl callees opaque (X/Y preserved, A/flags unknown). Object fields checked against '
               'handler writes with lastobj=$0E00 and player worldZ=0.',
        handlers=handlers, non_native=non_native, opcode_counts={'%02X' % k: v for k, v in sorted(used.items())},
        commands=[jsonable(cmds[i]) for i in order],
        blocks=[jsonable(e) for e in blocks],
        research_crosscheck=dict(compared=len(rcmds), differences=diffs, block_semantics=research_sem_notes),
        notes=['Script interpreter Commit in src/level/script.asm covers 74/76/86 only; 00 and 70 have the same '
               'counter=wait / yield-if-nonzero rule and must be added.',
               'Allocation failure sets lastobj=0; then 36/38/3C/5A/84/8C are skipped by the ROM.',
               '36/38/3C index arithmetic is 16-bit: 3C writes 7E:2000+((lastobj+w1)&$FFFF) (Corneria uses w1=$FCDF).',
               'Loop slots compare 16-bit pointers only; empty slot value 0 equals pointer $0000 (no loop there).',
               'mapif false: pointer+6 (the mapgoto back) with counter 1, i.e. retried next frame with any delta>1.'])
    (ROOT/'build/level1-script.json').write_text(json.dumps(report, indent=1)+'\n', encoding='utf-8')

    # ---- summary --------------------------------------------------------------
    print('Corneria 1: %d commands, range 0D:%04X..0D:%04X (%d bytes, sha256 %s)'
          % (len(order), start | 0x8000, (stop-1) | 0x8000, len(data), hashlib.sha256(data).hexdigest()[:16]))
    print('events %d, explicit blocks %d' % (len(events), len(blocks)))
    print('opcodes:', ' '.join('%02X:%s=%d' % (k, NAMES[k], v) for k, v in sorted(used.items())))
    print('research cross-check: %d research commands, %d differences' % (len(rcmds), len(diffs)))
    for d in diffs: print('  diff', d)
    print('non-native opcodes:')
    for n in non_native: print('  %s %-12s x%-3d %s  %s' % (n['opcode'], n['name'], n['count'], n['handler'], n['semantics']))
    for f in ('level1-script.bin', 'level1-script.inc', 'level1-script.json'):
        print('  %s %s' % (f, hashlib.sha256((ROOT/'build'/f).read_bytes()).hexdigest()))


if __name__ == '__main__':
    main()
