"""Map-script programs for the whole bank 0D (and the bank-05 map subroutines).

Authority: ref/Star Fox (USA).sfc (USA rev0, SHA-256 3857b529...a84d, LoROM, no header).

Entries (every one checked against the ROM):
* 23 stages: course tables 05:8000 and `stagepaths` 03:D671 (tools/inventory-levels.py
  stage_graph), Black Hole / Out of This Dimension included;
* training 0D:EE9A (1F:FBCE), credits 0D:F1EE (02:E679);
* screens: intro 0D:F870 (1F:F5A5), title 0D:F9F2 (1F:F4DB), contmap 0D:FA3C (1F:FA07),
  game over 0D:FA71 (06:BBE7).
  The set of immediate `lda #$0D / ldx #ptr / sta $1FF6 / stx $16FF` stores in the ROM must
  equal training + credits + screens (other pointer stores are table/RAM driven: courses,
  restart $173F, saved $1FF9, and the dispatcher's own successors).

Reachability, command lengths and successors come from the forking executor of the original
dispatcher 03:ED6F of tools/inventory-levels.py (imported, not copied). Inline 65816 blocks
(78), mapcode_jsl (7A) and mapif (2C) are classified first with the templates of
tools/recover-level-script.py (imported: decode_block / BLOCKS / ROUTINES / CONDITIONS), so
the kinds already consumed by the port keep their numbers and fields; blocks they do not
match use the EXTRA_* templates below (new kinds, semantics read from the ROM code).

Outputs:
  build/map0d.bin            0D:8000..FFFF (32 KiB)
  build/map05.bin            05:8000..FFFF (32 KiB; map subroutines reached by mapjsr)
  build/map0d.inc            map boundaries, blocks, kinds and spawn lookup tables
  build/map-programs.json    inventory per entry, kinds, hashes, correspondence tests
"""
from starfox_rom import rom_pattern
import hashlib
import json
import re
import runpy
from collections import Counter, OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
I = runpy.run_path(str(ROOT / 'tools/inventory-levels.py'), run_name='inventory_levels')
R = runpy.run_path(str(ROOT / 'tools/recover-level-script.py'), run_name='recover_level_script')
ROM, SHA, phys, rw = I['ROM'], I['SHA'], I['phys'], I['rw']
assert R['ROM'] == ROM and R['SHA'] == SHA
BANKS = (0x0D, 0x05)

# ----------------------------------------------------------------------------
# New inline-block kinds (78). {name:n} captures n little-endian bytes. Every block
# starts with M8/X16 (03:ED6F sep #$20, handler 03:EE6B), DB=0, X=lastobj and ends with
# `ldx #target / rtl` back to 03:ED6F. Fields of the 16-byte consumer record:
#   next = ldx of the fall-through (= index+length), branch = alternative target,
#   arg.l / arg2.l per kind (documented in the 4th element).
# ----------------------------------------------------------------------------
EXTRA_BLOCKS = [
    ('branch_if_byte_mask', 0x10,
     rom_pattern(0x2c25b, 21, [(3, 'addr', 2), (6, 'mask', 1), (10, 'next1', 2), (14, 'branch', 2), (18, 'next', 2)]),
     'if (byte 00:addr & mask) != 0 -> branch else next (05:C25A: bne form with a dead third ldx = next)',
     lambda f: (f['addr'], f['mask'])),
    ('set_restart', 0x13, rom_pattern(0x28775, 17, [(5, 'bank', 1), (7, 'restart', 2), (14, 'next', 2)]),
     'jsl 09:98CB (A=bank, X=restart): checkpoint; restart may differ from next (bank 05); the restart bank is '
     'the bank of the table holding the block (checked); arg=0998CB, arg2=restart',
     lambda f: (0x0998CB, f['restart'])),
    ('mark_boss', 0x19, rom_pattern(0x28766, 13, [(3, 'value', 2), (10, 'next', 2)]),
     'jsl 1F:DF62 with A=value (M16): append to list $1F6B/$1F6D; arg=1FDF62, arg2=value (0 in Corneria 1)',
     lambda f: (0x1FDF62, f['value'])),
    ('branch_if_byte_zero', 0x1B, rom_pattern(0x6d66a, 15, [(3, 'addr', 2), (8, 'branch', 2), (12, 'next', 2)]),
     'if byte 00:addr == 0 -> branch else next; arg=addr, arg2=mask $FF', lambda f: (f['addr'], 0xFF)),
    ('branch_if_byte_zero', 0x1B, rom_pattern(0x2839a, 14, [(1, 'addr', 3), (7, 'branch', 2), (11, 'next', 2)]),
     'if byte addr (long) == 0 -> branch else next; arg=addr, arg2=mask $FF', lambda f: (f['addr'], 0xFF)),
    ('branch_if_byte_ne', 0x1C, rom_pattern(0x6d83a, 17, [(3, 'addr', 2), (6, 'value', 1), (10, 'branch', 2), (14, 'next', 2)]),
     'if byte 00:addr != value -> branch else next; arg=addr, arg2=value ($1FFF route 0/1/2 in Venom orbital)',
     lambda f: (f['addr'], f['value'])),
    ('cl_player_mode', 0x1D, rom_pattern(0x2d8c2, 26, [(10, 'routine', 3), (23, 'next', 2)]),
     'DB=$7E; jsl 06:BB22 (calcteamdamage); jsl routine (player mode of the clear sequence); $14DC&=$EF; '
     'arg=routine, arg2=06BB22 (routine 0B:9558 is kind clear_demo)', lambda f: (f['routine'], 0x06BB22)),
    ('clear_boss_maxhp', 0x1E, rom_pattern(0x29958, 10, [(7, 'next', 2)]),
     'byte 70:019A (m_bossmaxHP) = 0; arg=70019A', lambda f: (0x70019A, 0)),
    ('player_out_view', 0x1F, rom_pattern(0x2d888, 51, [(10, 'branch', 2), (29, 'skip', 2), (48, 'next', 2)]),
     'if $14D9&$80 (player dead) -> branch (previous command: retry); $14DF|=8; if $14DD!=3 -> arg2 '
     '(target skipping the next command); else $14DD=4, DB=$7E, jsl 06:BA91, -> next; arg=06BA91, arg2=skip target',
     lambda f: (0x06BA91, f['skip'])),
    ('reset_view_z', 0x31, rom_pattern(0x6f1ff, 19, [(16, 'next', 2)]),
     'lastplayz $1701=0, pviewposz $14FC=0, player worldZ (obj $123A +$10)=0 (words); intro kind 1',
     lambda f: (0, 0)),
    ('player_out_view_short', 0x32, rom_pattern(0x2c273, 37, [(10, 'branch', 2), (21, 'skip', 2), (34, 'next', 2)]),
     'as player_out_view without $14DF|=8 and without DB=$7E around jsl 06:BA91; arg=06BA91, arg2=skip target',
     lambda f: (0x06BA91, f['skip'])),
    ('set_dotsflag', 0x33, rom_pattern(0x283d0, 24, [(21, 'next', 2)]),
     'byte $16FB (dotsflag)=1, byte $16FC=0, bytes 70:1A26/70:1A27=0; arg=0016FB, arg2=701A26',
     lambda f: (0x0016FB, 0x701A26)),
    ('flags176f_wait', 0x34, rom_pattern(0x28696, 30, [(10, 'branch', 2), (18, 'wait', 2), (27, 'next', 2)]),
     'b=$176F; if b&2 -> branch; elif !(b&1) -> arg2 (previous command: wait); else $176F=b&$FE -> next; '
     'arg=00176F, arg2=wait target', lambda f: (0x00176F, f['wait'])),
    ('flags176f_switch', 0x35, rom_pattern(0x298f9, 26, [(11, 'branch', 2), (19, 'alt', 2), (23, 'next', 2)]),
     'b=$176F; $176F=0; if b&1 -> branch; elif b&2 -> arg2; else next; arg=00176F, arg2=bit-1 target',
     lambda f: (0x00176F, f['alt'])),
    ('branch_if_shape_absent', 0x36, rom_pattern(0x298bf, 20, [(1, 'shape', 2), (13, 'branch', 2), (17, 'next', 2)]),
     'jsl 09:B1FF (Y=shape header: first object of list $121F with +$04==Y, else $156D); '
     'not found (Y==$156D) -> branch else next; arg=shape header (bank 00), arg2=09B1FF',
     lambda f: (f['shape'], 0x09B1FF)),
    ('and_bytes2', 0x37,
     rom_pattern(0x6cb8a, 22, [(3, 'addr', 2), (6, 'm1', 1), (8, 'addr2', 2), (11, 'addrb', 2),
                              (14, 'm2', 1), (16, 'addrb2', 2), (19, 'next', 2)]),
     'byte 00:addr &= m1; byte 00:addrb &= m2; arg=addr, arg2=addrb<<16|m1<<8|m2',
     lambda f: (f['addr'], f['addrb'] << 16 | f['m1'] << 8 | f['m2'])),
    ('clear_byte', 0x38, rom_pattern(0x6cc14, 7, [(1, 'addr', 2), (4, 'next', 2)]), 'byte 00:addr = 0 (stz, M8); arg=addr',
     lambda f: (f['addr'], 0)),
    ('store_byte_word', 0x39,
     rom_pattern(0x6d746, 17, [(1, 'value', 1), (3, 'addr', 2), (8, 'valuew', 2), (11, 'addrw', 2), (14, 'next', 2)]),
     'byte 00:addr = value; word 00:addrw = valuew; arg=value<<24|addr, arg2=addrw<<16|valuew',
     lambda f: (f['value'] << 24 | f['addr'], f['addrw'] << 16 | f['valuew'])),
    ('branch_if_word_lt', 0x3A, rom_pattern(0x6f120, 19, [(3, 'addr', 3), (7, 'value', 2), (12, 'branch', 2), (16, 'next', 2)]),
     'if word addr (long) < value (unsigned) -> branch else next; arg=addr, arg2=value',
     lambda f: (f['addr'], f['value'])),
    ('and_or_bytes', 0x3B,
     rom_pattern(0x6f230, 22, [(3, 'addr', 2), (6, 'm1', 1), (8, 'addr2', 2), (11, 'addrb', 2),
                              (14, 'm2', 1), (16, 'addrb2', 2), (19, 'next', 2)]),
     'byte 00:addr &= m1; byte 00:addrb |= m2; arg=addr, arg2=addrb<<16|m1<<8|m2 (intro kind 2)',
     lambda f: (f['addr'], f['addrb'] << 16 | f['m1'] << 8 | f['m2'])),
    ('ctl_reset', 0x30, rom_pattern(0x6fa44, 27, [(24, 'next', 2)]),
     'reset_view_z + playerflymode $14DC&=$EF (contmap 0D:FA43; same number as src/screens/controls.asm)',
     lambda f: (0, 0)),
]
# Blocks that only call one routine use the kind of that routine (same consumer as 7A).
JSL_BLOCK = '22{routine:3} a2{next:2} 6b'
# New mapcode_jsl routines (handler 03:EE84 jsl b3:(w1+1)); names from UltraStarFox, effects from the ROM.
EXTRA_ROUTINES = {
    0x1FD3E0: (0x23, 'clearmap_l', 'every object of list $121F with (obj+$20)&1==0 (not player) -> jsl 1F:BFDC (removedeadal)'),
    0x1FD3FD: (0x24, 'clearrealobjmap_l', 'every object of list $121F with (obj+$1F)&8 (realobj) -> jsl 1F:BFDC (removedeadal)'),
    0x039877: (0x25, 'bg_1_4b_1', '70:0050=$8FAA; $1899=2; jsl 02:F484; $1961=0 (shadowheight); 70:004E=$8A, 70:004F=$8D'),
    0x02FEC1: (0x26, 'initfadewhite2norm_l', '$14C3|=4; $149A=$1F (window whitefade value 31); jsr 02:FEE8 (fadewhite2norm step)'),
}
# New mapif conditions (handler 03:F3A1; carry set -> goto w4, else pointer+6, counter 1).
EXTRA_CONDITIONS = {
    0x068BA1: (0x2A, 'chkstagedone', 'if $14D2&$80: $14D2&=$7F, carry=1 else carry=0'),
    0x068BD1: (0x2B, 'chkstratdone2', 'carry = ($14D2&$10)!=0 (flag NOT cleared)'),
    0x0A9821: (0x2C, 'theenddead', 'carry = (byte $1FE2 (numendok) == $FF)'),
}
ROUTINES = {**R["ROUTINES"], **EXTRA_ROUTINES}
CONDITIONS = {**R["CONDITIONS"], **EXTRA_CONDITIONS}
assert len(ROUTINES) == len(R['ROUTINES']) + len(EXTRA_ROUTINES)

# Opcodes without a consumer in the port: semantics (handler 03:ED83+op; USF MAPMACS name).
NEW_OPCODE_NOTES = {
    0x0A: 'mapmother (03:FA6E): object as 00/86 plus a mother script pointer w14 (bank 05, interpreter 03:FB51)',
    0x0C: 'mapremove (03:FB0D): remove every object of list $121F whose shape header == w3 (jsl 1F:BFDC)',
    0x0E: 'setstage (03:F555)', 0x26: 'mapobjzrot (03:F8C6): object with initial z rotation (USF MAPMACS)',
    0x3E: 'setalxvar.w (03:F2D9): word 7E:2000+lastobj+w1 = w3 (USF)', 0x42: 'setfadeup (03:F213)',
    0x48: 'setalvarptr.w (03:F1E5) (USF)', 0x4A: 'setvarobj (03:F195): long pointer var = lastobj (USF)',
    0x6A: 'addalvarptr.w (03:EF9F) (USF)', 0x6C: 'fadetosea (03:EF20)', 0x6E: 'fadetoground (03:EF3A)',
}


# ----------------------------------------------------------------------------
# Entries
# ----------------------------------------------------------------------------
SCREENS = OrderedDict([('0D:EE9A', ('Entrenamiento', '1F:FBCE')), ('0D:F1EE', ('Creditos (final)', '02:E679')),
                       ('0D:F870', ('Intro', '1F:F5A5')), ('0D:F9F2', ('Titulo', '1F:F4DB')),
                       ('0D:FA3C', ('contmap (controles)', '1F:FA07')), ('0D:FA71', ('Game over', '06:BBE7'))])


def entries():
    graph, _ = I['stage_graph']()
    out = OrderedDict()
    for ci, c in enumerate(graph['courses']):
        for k, m in enumerate(c):
            out.setdefault(m, 'course%d[%d] (05:8000)' % (ci + 1, k))
    for r in graph['records']:
        out.setdefault(m := r['map'], 'stagepaths %s' % r['addr'])
    # Immediate map pointer stores: lda #$0D (a9 0d) / ldx #ptr / sta $1FF6 / stx $16FF in any order.
    found = {}
    for m in re.finditer(rb'\x8e\xff\x16', ROM):
        s = m.start(); win = ROM[s - 12:s]
        x = re.search(rb'\xa2(..)', win, re.S); b = re.search(rb'\xa9(.)\x8d\xf6\x1f|\xa9(.)\xa2..\x8d\xf6\x1f', win, re.S)
        if x and b:
            bank = (b.group(1) or b.group(2))[0]
            found['%02X:%04X' % (bank, 0x8000 | x.group(1)[0] | x.group(1)[1] << 8)] = \
                '%02X:%04X' % (s // 0x8000, 0x8000 | s % 0x8000)
    assert {k: v[1] for k, v in SCREENS.items()} == found, found
    for m, (name, store) in SCREENS.items():
        out.setdefault(m, 'stx $16FF at %s' % store)
    return graph, out


# ----------------------------------------------------------------------------
# Verification of one command (length, successors, operand reads)
# ----------------------------------------------------------------------------
def execute(e):
    bank, index = e['bank'], e['index']
    o = phys(bank, index)
    # 0C walks the object list: head $0E00 -> one object $0F00 (shape unknown: both compare results) -> end.
    ram = {0x121f: 0x00, 0x1220: 0x0E, 0xE00: 0x00, 0xE01: 0x0F, 0xF00: 0, 0xF01: 0} if e['opcode'] == '0C' else {}
    exits = I['run'](bank, index, ram, o)
    succ, kinds, reads = set(), set(), set()
    for (kind, val), s in exits:
        reads |= s.reads
        if kind == 'external':
            raise AssertionError((e['addr'], 'external exit'))
        bk, x = val
        if isinstance(x, tuple):
            kinds.add('return'); continue
        assert x not in ('unset', None) and bk is not None, (e['addr'], kind, val)
        kinds.add(kind); succ.add((bk, x))
    return succ, kinds, reads


def block_decode(bank, index):
    """Known kinds via recover-level-script.decode_block (its BANK set to `bank`), else EXTRA_BLOCKS."""
    G = R['decode_block'].__globals__        # runpy returns a copy; patch the functions' own globals
    G['BANK'] = bank
    try:
        b = R['decode_block'](index)
        known = dict(name=b['name'], kind=b['kind'], length=b['length'], next=b['next'], branch=b['branch'],
                     arg=b['arg'], arg2=b['arg2'], semantics=b['semantics'], fields=b['fields'], source='recover')
    except AssertionError:
        known = None
    finally:
        G['BANK'] = 0x0D
    o = phys(bank, index)
    hits = []
    for name, kind, tpl, sem, args in EXTRA_BLOCKS:
        r = R['match'](tpl, ROM[o + 1:o + 120])
        if r and r[0]['next'] == (index + 1 + r[1]) & 0x7fff:
            f = r[0]
            if name == 'branch_if_byte_mask': assert f['next1'] == f['next']
            if name == 'cl_player_mode' and f['routine'] == 0x0B9558: continue   # = clear_demo
            if name == 'set_restart': assert f['bank'] == bank, ('restart in another bank', hex(index))
            a1, a2 = args(f)
            hits.append(dict(name=name, kind=kind, length=1 + r[1], next=f['next'], branch=f.get('branch'),
                             arg=a1, arg2=a2, semantics=sem, fields=f, source='extra'))
    r = R['match'](JSL_BLOCK, ROM[o + 1:o + 10])
    if r and r[0]['next'] == (index + 1 + r[1]) & 0x7fff and r[0]['routine'] in ROUTINES:
        k, nm, sem = ROUTINES[r[0]['routine']]
        hits.append(dict(name=nm, kind=k, length=1 + r[1], next=r[0]['next'], branch=None, arg=r[0]['routine'],
                         arg2=0, semantics='jsl %06X: ' % r[0]['routine'] + sem, fields=r[0], source='jsl'))
    if known:
        assert all(h['kind'] == known['kind'] and h['length'] == known['length'] for h in hits), (hex(index), hits)
        return known
    assert len({(h['kind'], h['length']) for h in hits}) == 1, ('unclassified block', '%02X:%04X' % (bank, index | 0x8000), hits)
    return hits[0]


def static_targets(bank, index, length):
    """Every `ldx #imm / rtl` target inside the block (the end_65816 pattern of the ROM)."""
    o = phys(bank, index)
    return {rw(o + k + 1) for k in range(1, length - 3) if ROM[o + k] == 0xa2 and ROM[o + k + 3] == 0x6b}


def verify(e):
    """Returns (kind, block record or None, verification note). Asserts on any inconsistency."""
    bank, index, op, length = e['bank'], e['index'], int(e['opcode'], 16), e['length']
    assert 0 < length and index + length <= 0x8000, ('outside bank', e['addr'], length)
    succ, kinds, reads = execute(e)
    seq = (bank, index + length)
    rec, kind, how = None, 0, ''
    if op == 0x78:
        b = block_decode(bank, index)
        assert b['length'] == length, (e['addr'], b['length'], length)
        tg = {b['next']} | ({b['branch']} if b['branch'] is not None else set())
        extra = {b['arg2']} if b['name'] in ('player_out_view', 'player_out_view_short', 'flags176f_wait',
                                             'flags176f_switch') else set()
        assert static_targets(bank, index, length) == tg | extra, (e['addr'], static_targets(bank, index, length), tg, extra)
        assert {x for _, x in succ} == tg | extra and all(bk == bank for bk, _ in succ), (e['addr'], succ, tg, extra)
        assert b['next'] == index + length
        kind = b['kind']; how = 'bloque: plantilla exacta + salidas del ejecutor'
        rec = (index, kind, b['next'], 0xffff if b['branch'] is None else b['branch'], b['arg'], b['arg2'])
        e['block_decoded'] = b
    else:
        assert reads <= set(range(length + 1)), (e['addr'], sorted(reads), length)
        if length > 1:
            assert reads and max(reads) >= length - 1, (e["addr"], e["opcode"], sorted(reads), length)
        if op in (0x02,):
            assert succ == {(bank, index)} and kinds == {'yield'}; how = 'end: yield en el mismo indice'
        elif op == 0x2a:
            assert kinds == {'return'}; how = 'maprts: retorno'
        elif op in (0x28, 0x2e):
            t = (ROM[phys(bank, index) + 3], rw(phys(bank, index) + 1))
            assert succ == {t}, (e['addr'], succ, t); how = 'salto: destino del ejecutor + lecturas de operandos'
        else:
            assert seq in succ, (e['addr'], succ, seq)
            how = 'salida del ejecutor en indice+longitud + lecturas de operandos'
            if op == 0x04: assert succ == {seq, (bank, rw(phys(bank, index) + 1))}
            if op == 0x2c: assert succ == {seq, (bank, rw(phys(bank, index) + 4))}
        if op == 0x7a:
            o = phys(bank, index)
            r = (ROM[o + 3] << 16) | ((rw(o + 1) + 1) & 0xffff)
            kind = ROUTINES[r][0]; rec = (index, kind, index + 4, 0xffff, r, 0)
            assert (bank, index + 4) == seq
        if op == 0x2c:
            o = phys(bank, index)
            r = (ROM[o + 3] << 16) | rw(o + 1)
            kind = CONDITIONS[r][0]; rec = (index, kind, index + 6, rw(o + 4), r, 0)
    e['verified_by'] = how
    return kind, rec


# ----------------------------------------------------------------------------
# Current port consumer (parsed from src/, read-only)
# ----------------------------------------------------------------------------
def port_consumer():
    lv = (ROOT / 'src/level/level.asm').read_text(encoding='latin-1')
    sc = (ROOT / 'src/level/script.asm').read_text(encoding='latin-1')
    cut = lambda t, a, b: t[t.index(a):t.index(b, t.index(a))]
    ops = {int(x, 16) for x in re.findall(r'cmpi\.w #\$([0-9a-f]{2}),d0', cut(lv, 'M4LvEventPending:', 'M4LvUnsupported:'))}
    ops |= {int(x, 16) for x in re.findall(r'cmpi\.w #\$([0-9a-f]{2}),d0', cut(sc, 'M4ScriptFound:', 'M4ScriptDown:'))}
    kinds = set(re.findall(r'cmpi\.w #M4_LEVEL_KIND_(\w+),d0', cut(lv, 'M4LvBlock:', 'M4LvCtlReset:')))
    kinds |= set(re.findall(r'cmpi\.w #M4_LEVEL_KIND_(\w+),2\(a2\)', cut(lv, 'M4LvMapIf:', 'M4LvBossAlive:')))
    block = re.search(r'M4LvAlvarMap:[^\n]*\n((?:\s*dc\.w [^\n]+\n)+)', lv).group(1)
    items = ','.join(re.findall(r'dc\.w ([^\n;]+)', block)).replace(' ', '').split(',')
    alvar = {int(x[1:], 16) for x in items[0::2] if x.startswith('$')}          # (ROM offset, port offset) pairs
    setvar = {int(x, 16) for x in re.findall(r'dc\.w \$([0-9a-f]{4})', cut(lv, 'M4LvSetVarTable:', 'M4LvSetVarW:'))}
    setvar |= {0xF0B7, 0x1FD4, 0x15BA}          # M4LvSetVar / M4LvSetVarNotTable / M4LvSetVarClear
    reads = {0x7EF0B7, 0x0018A2, 0x0018A3, 0x0018A4, 0x0018B4, 0x0014D9}       # M4LvReadByte
    # Generic original-address map of src/level/level_mapvars.asm (setvar.b/.w,
    # and/or_byte, branch reads, store/clear/and_or blocks) and its extra kinds.
    mv = (ROOT / 'src/level/level_mapvars.asm').read_text(encoding='latin-1')
    table = {int(x, 16) for x in re.findall(r'dc\.l \$([0-9a-f]{6}),', cut(mv, 'M4LvVarTable:', '\n        dc.l 0'))}
    table |= set(range(0x18A1, 0x18A5))
    mv_kinds = set(re.findall(r'cmpi\.w #M4_LEVEL_KIND_(\w+),(?:d0|2\(a2\))', mv))
    kinds |= mv_kinds
    lo16 = {a & 0xFFFF for a in table if a >> 16 in (0, 0x7E) and (a & 0xFFFF) < 0x2000} | {a & 0xFFFF for a in table}
    setvar |= lo16
    reads |= table
    setvar_w = {0x16AD} | {a for a in lo16 if a + 1 in lo16}
    return dict(opcodes=ops, kinds=kinds, alvar=alvar, setvar_b=setvar, setvar_w=setvar_w, alx={0xFCDF, 0xFCF4},
                or_byte=table, and_byte=table, player_mode={0x0B8EC5, 0x0BBAEF}, read_byte=reads)


def unsupported(e, port, kname):
    """Reasons the current consumer would stop on this command (M4LvUnsupported / M4LvMapBad)."""
    op = int(e['opcode'], 16); raw = bytes.fromhex(e['bytes'])
    w = lambda k: raw[k] | raw[k + 1] << 8
    if op not in port['opcodes']:
        return 'opcode %02X' % op
    if op in (0x28, 0x2e) and raw[3] not in (0x0D, 0x05):
        return '%02X a banco %02X' % (op, raw[3])
    if op in (0x36, 0x38) and w(1) not in port['alvar']:
        return 'setalvar offset %04X' % w(1)
    if op == 0x3c and w(1) not in port['alx']:
        return 'setalxvar.b offset %04X' % w(1)
    if op == 0x5c and w(2) not in port['setvar_b']:
        return 'setvar.b %06X' % (raw[2] | raw[3] << 8 | raw[4] << 16)
    if op == 0x5e and w(3) not in port['setvar_w']:
        return 'setvar.w %06X' % (raw[3] | raw[4] << 8 | raw[5] << 16)
    if op in (0x78, 0x7a, 0x2c):
        b = e.get('block_decoded'); kn = kname[e['kind']]
        if kn.upper() not in port['kinds']:
            return 'kind %s' % kn
        if b:
            if b['name'] in ('branch_if_byte_mask', 'friend_message') and b['arg'] not in port['read_byte'] \
                    and not (b['name'] == 'friend_message' and b['arg'] in port['read_byte']):
                return '%s lee %06X' % (b['name'], b['arg'])
            if b['name'] == 'or_byte' and b['arg'] not in port['or_byte']: return 'or_byte %06X' % b['arg']
            if b['name'] == 'and_byte' and b['arg'] not in port['and_byte']: return 'and_byte %06X' % b['arg']
            if b['name'] == 'player_mode' and b['arg'] not in port['player_mode']: return 'player_mode %06X' % b['arg']
            if b['name'] == 'set_restart' and e['bank'] not in (0x0D, 0x05): return 'set_restart en banco %02X' % e['bank']
    return None


# ----------------------------------------------------------------------------
# Correspondence with the existing port tables
# ----------------------------------------------------------------------------
# Former hand-written contmap tables of src/screens/controls.asm (verified in the emulator), kept
# as the correspondence reference after the port moved to the generated tables.
CONTMAP_REFERENCE = '''M4CtlBoundaries:
        dc.w $7a3c,1,0
        dc.w $7a3d,1,0
        dc.w $7a3e,3,0
        dc.w $7a41,1,0
        dc.w $7a42,1,0
        dc.w $7a43,28,$30
        dc.w $7a5f,2,0
        dc.w $7a61,4,$20
        dc.w $7a65,5,0
        dc.w $7a6a,1,0
        dc.w $7a6b,2,0
        dc.w $7a6d,4,0
        dc.w $ffff
M4CtlBlocks:
        dc.w $7a43,$30,$7a5f,$ffff
        dc.l 0,0
        dc.w $7a61,$20,$7a65,$ffff
        dc.l $0002fd48,0
        dc.w $ffff
'''
EV_OPS = (0x00, 0x26, 0x70, 0x74, 0x76, 0x86, 0x36, 0x38, 0x3c, 0x8c, 0x5a, 0x84)


def event_record(bank, index, length):
    """24-byte object event of M4LevelScriptEvents (field formulas of recover-level-script.decode,
    whose handler cross-checks hold for Corneria 1): index,opcode,x,y,zrel,shape,strategy.l,istrat,
    wait_after,extra,value."""
    o = phys(bank, index); raw = ROM[o:o + length]; op = raw[0]
    w = lambda k: int.from_bytes(raw[k:k + 2], 'little')
    s8 = lambda v: v - 256 if v & 128 else v
    tab = lambda base, i, n: int.from_bytes(ROM[phys(0, base) + n * i:phys(0, base) + n * i + n], 'little')
    def strat(ii): return tab(R['ISTRAT_TAB'], ii, 4) & 0xffffff, ROM[phys(0, R['ISTRAT_TAB']) + 4 * ii + 3]
    def shape(si):
        assert 2 * si < R['ISTRAT_TAB'] - R['SHAPES_TAB'], ('shape index', bank, index, si)
        return tab(R['SHAPES_TAB'], si, 2)
    x = y = z = sh = st = wait = extra = value = 0; ii = 0xffff
    if op in (0x00, 0x26, 0x74, 0x86):
        wait, x, y, z = w(1), w(3), w(5), w(7)
        if op in (0x00, 0x26):
            si, ii = raw[9], raw[10]; st = strat(ii)[0]; sh = shape(si)
            if op == 0x26: value = raw[11]  # mapobjzrot 03:F8C6: mapobj + initial rotz ($14)
        elif op == 0x74: ii = raw[9]; st, si = strat(ii); sh = shape(si)
        else: sh, st = w(9), raw[11] | raw[12] << 8 | raw[13] << 16
    elif op in (0x70, 0x76):
        wait, x, y, z = raw[1] << 4, s8(raw[2]) * 4, s8(raw[3]) * 4, raw[4] * 16
        if op == 0x70: si, ii = raw[5], raw[6]; st = strat(ii)[0]
        else: ii = raw[5]; st, si = strat(ii)
        sh = shape(si)
    elif op in (0x36, 0x38, 0x3c): extra, value = w(1), (w(3) if op == 0x38 else raw[3])
    elif op in (0x5a, 0x84): extra, value = (0x1d, 1) if op == 0x5a else (0x20, 0x80)
    elif op == 0x8c: extra = value = w(1)
    return (index, op, x & 0xffff, y & 0xffff, z & 0xffff, sh, st, ii, wait, extra, value & 0xffff)


def parse_table(text, label, width):
    body = text[text.index(label + ':'):]
    vals = []
    for line in body.splitlines()[1:]:
        m = re.match(r'\s*dc\.([wl])\s+([^;]+)', line)
        if not m:
            if line.strip() and not line.strip().startswith(';'): break
            continue
        for v in m.group(2).split(','):
            v = v.strip()
            vals.append((m.group(1), int(v[1:], 16) if v.startswith('$') else (int(v) if v.isdigit() else v)))
    out, i = [], 0
    while i < len(vals) and vals[i][1] != 0xffff:
        out.append(tuple(v for _, v in vals[i:i + width])); i += width
    return out


def main():
    graph, ents = entries()
    cmds, reach = {}, OrderedDict()
    for m in ents:
        reach[m] = I['walk_script'](int(m[:2], 16), int(m[3:], 16) & 0x7fff, cmds)
    # Restart points (set_restart 09:98CB -> $173F/$1FF7, resumed by restart_l 09:992A after a death) are
    # entries too: walk them and add them to every entry that reaches the checkpoint block.
    restarts, changed = {}, True
    while changed:
        changed = False
        for m in reach:
            for k in sorted(reach[m]):
                if cmds[k]['opcode'] != '78': continue
                b = block_decode(*k)
                if b['name'] == 'set_restart' and (k[0], b['arg2']) not in reach[m]:
                    t = (k[0], b['arg2'])
                    restarts.setdefault('%02X:%04X' % (t[0], t[1] | 0x8000), cmds[k]['addr'])
                    reach[m] |= I['walk_script'](t[0], t[1], cmds); changed = True
    assert {k[0] for k in cmds} <= set(BANKS), Counter(k[0] for k in cmds)
    kinds_of, recs = {}, {}
    for k in sorted(cmds):
        kinds_of[k], r = verify(cmds[k])
        cmds[k]['kind'] = kinds_of[k]
        if r: recs[k] = r
    # overlap / successors on boundaries
    for bank in BANKS:
        order = sorted(i for b, i in cmds if b == bank)
        for a, b in zip(order, order[1:]):
            assert a + cmds[(bank, a)]['length'] <= b, ('overlap', hex(bank), hex(a), hex(b))
    for k, e in cmds.items():
        for n in e['next'] + ([e['return_to']] if 'return_to' in e else []):
            assert tuple(n) in cmds, ('successor not on boundary', e['addr'], n)
    for k, r in recs.items():
        for t in r[2:4]:
            assert t == 0xffff or (k[0], t) in cmds, ('block target not on boundary', cmds[k]['addr'], hex(t))
        b = cmds[k].get('block_decoded')
        if b and b['name'] == 'set_restart':
            assert (k[0], b['arg2']) in cmds, ('restart not on boundary', cmds[k]['addr'])
        if b and b['name'] in ('player_out_view', 'player_out_view_short', 'flags176f_wait', 'flags176f_switch'):
            assert (k[0], b['arg2']) in cmds

    # kinds
    names = {}
    for nm, k, _, _ in R['BLOCKS']: names.setdefault(k, nm)
    for nm, k, _, _, _ in EXTRA_BLOCKS: names.setdefault(k, nm)
    for r_, (k, nm, _) in list(ROUTINES.items()) + list(CONDITIONS.items()): names.setdefault(k, nm)
    assert len(set(names.values())) == len(names)
    kname = dict(names); kname[0] = ''
    sem = {}
    for nm, k, _, s in R['BLOCKS']: sem.setdefault(k, s)
    for nm, k, _, s, _ in EXTRA_BLOCKS:
        if k in sem and s not in sem[k] and k in {kk for _, kk, _, _ in R['BLOCKS']}:
            sem[k] += ' | generalizado: ' + s
        sem.setdefault(k, s)
    for r_, (k, nm, s) in list(ROUTINES.items()) + list(CONDITIONS.items()): sem.setdefault(k, '%06X: %s' % (r_, s))
    known = {k for _, k, _, _ in R['BLOCKS']} | {v[0] for v in R['ROUTINES'].values()} | {v[0] for v in R['CONDITIONS'].values()}
    known.add(0x30)   # src/screens/controls.asm M4_LEVEL_KIND_CTL_RESET

    # ---- binaries ---------------------------------------------------------------
    bins = {}
    for bank, fn in ((0x0D, 'map0d.bin'), (0x05, 'map05.bin')):
        data = ROM[phys(bank, 0x8000):phys(bank, 0x8000) + 0x8000]
        (ROOT / 'build' / fn).write_bytes(data)
        bins[fn] = dict(bank='%02X' % bank, rom_offset='0x%05X' % phys(bank, 0x8000), size=len(data),
                        sha256=hashlib.sha256(data).hexdigest())

    # Bytes the port reads in each raw bank copy: the reachable map commands and, in bank 05, the mother
    # scripts (M4MotherOp). The tail after USED_END is never read: tools/audio/mdsdrv-bank.py packs audio there.
    used_end = {b: max(i + c['length'] for (bb, i), c in cmds.items() if bb == b) for b in (0x0D, 0x05)}
    for p in sorted({rw(phys(e['bank'], e['index']) + 14) for e in cmds.values() if e['opcode'] == '0A'}):
        seen, _ = I['mother_script'](p)
        for a, v in seen.items():
            assert 'bytes' in v, ('mother script', hex(p), hex(a))
            used_end[0x05] = max(used_end[0x05], (a & 0x7FFF) + len(v['bytes']) // 2)

    # ---- include ----------------------------------------------------------------
    L = ['; Map-script programs of bank 0D (+ bank-05 map subroutines): tools/generate-map-programs.py.',
         '; ROM ref/Star Fox (USA).sfc %s. index = map pointer (CPU address & $7FFF);' % SHA[:16],
         '; bytes of index i: M4Map0DBytes+i (build/map0d.bin = 0D:8000..FFFF, sha256 %s).' % bins['map0d.bin']['sha256'][:16],
         '; Kinds: 78 block kind, 7A routine kind, 2C condition kind, else 0 (numbers of',
         '; tools/recover-level-script.py kept; new ones documented below and in build/map-programs.json).']
    for k in sorted(names):
        L.append('M4_LEVEL_KIND_%s equ $%02x ;%s %s' % (names[k].upper(), k, '' if k in known else '[nuevo]', sem[k][:150]))
    events = {}
    for bank, tag in ((0x0D, '0D'), (0x05, '05')):
        order = sorted(i for b, i in cmds if b == bank)
        L += ['', '; first byte of the raw bank copy after every command (and mother script) the port reads',
              'M4_MAP%s_USED_END equ $%04x' % (tag, used_end[bank]),
              'M4_MAP%s_COMMANDS equ %d' % (tag, len(order)),
              '; index.w,length.b,kind.b per reachable command, sorted by index (binary search).',
              'M4Map%sBoundaries:' % tag]
        for i in order:
            length, kind = cmds[(bank, i)]['length'], kinds_of[(bank, i)]
            assert 0 < length <= 255 and 0 <= kind <= 255, (tag, i, length, kind)
            L.append(f'        dc.w ${i:04x},${length:02x}{kind:02x}')
        L += ['        dc.w $ffff', 'M4Map%sBoundariesEnd:' % tag]
        brs = sorted(r for k, r in recs.items() if k[0] == bank)
        L += ['M4_MAP%s_BLOCKS equ %d' % (tag, len(brs)),
              '; 16 bytes: index.w,kind.w,next.w,branch.w ($ffff none),arg.l,arg2.l (format of M4LevelScriptBlocks).',
              'M4Map%sBlocks:' % tag]
        for r in brs:
            L.append('        dc.w %s\n        dc.l $%08x,$%08x' % (','.join('$%04x' % v for v in r[:4]), r[4], r[5]))
        L += ['        dc.w $ffff', 'M4Map%sBlocksEnd:' % tag]
        evs = [event_record(bank, i, cmds[(bank, i)]['length']) for i in order
               if int(cmds[(bank, i)]['opcode'], 16) in EV_OPS]
        events[bank] = evs

    # M4LvDecodeSpawn reads positions/timing from the original command and
    # resolves only the original table indirections, in 68000 byte order.
    shapes_at, istrats_at = (phys(0, R[name]) for name in ('SHAPES_TAB', 'ISTRAT_TAB'))
    istrats = 1 + max(e[7] for rows in events.values() for e in rows if e[7] != 0xffff)
    L += ['', '; 00:A64B..A83C: original shape header pointers.', 'M4MapSpawnShapes:']
    L += [f'        dc.w ${rw(p):04x}' for p in range(shapes_at, istrats_at, 2)]
    L += ['', '; 00:A83D: Istrat entries up to the highest index used by a map spawn.',
          '; Packed LONG: default shape index in the high byte, then the 24-bit strategy.',
          'M4MapSpawnStrategies:']
    for p in range(istrats_at, istrats_at + 4 * istrats, 4):
        L.append(f'        dc.l ${int.from_bytes(ROM[p:p+4], "little"):08x}')
    (ROOT / 'build/map0d.inc').write_text('\n'.join(L) + '\n', encoding='utf-8')

    # ---- correspondence: Corneria 1 vs build/level1-script.inc ------------------
    lv1 = (ROOT / 'build/level1-script.inc').read_text(encoding='utf-8')
    old_b = parse_table(lv1, 'M4LevelScriptBoundaries', 3)
    old_k = parse_table(lv1, 'M4LevelScriptBlocks', 6)
    c1 = sorted(i for b, i in reach['0D:D068'])
    assert all(b == 0x0D for b, _ in reach['0D:D068'])
    new_b = [(i, cmds[(0x0D, i)]['length'], kinds_of[(0x0D, i)]) for i in c1]
    new_k = [recs[(0x0D, i)] for i in c1 if (0x0D, i) in recs]
    diff_b = sorted(set(old_b) ^ set(new_b)); diff_k = sorted(set(old_k) ^ set(new_k))
    corr = dict(corneria1=dict(entry='0D:D068', reference='build/level1-script.inc',
                               reference_sha256=hashlib.sha256(lv1.encode()).hexdigest(),
                               boundaries=len(new_b), reference_boundaries=len(old_b),
                               blocks=len(new_k), reference_blocks=len(old_k),
                               boundary_differences=[list(d) for d in diff_b],
                               block_differences=[list(d) for d in diff_k],
                               exact=not diff_b and not diff_k and new_b == old_b and new_k == old_k))
    old_e = parse_table(lv1, 'M4LevelScriptEvents', 11)
    new_e = [e for e in events[0x0D] if e[0] in set(c1)]
    corr['corneria1']['events'] = len(new_e)
    corr['corneria1']['reference_events'] = len(old_e)
    corr['corneria1']['event_differences'] = [list(map(hex, d)) for d in sorted(set(old_e) ^ set(new_e))]
    assert new_e == old_e, corr['corneria1']['event_differences'][:6]
    # contmap vs src/screens/controls.asm (M4CtlBoundaries / M4CtlBlocks)
    ctl = (ROOT / 'src/screens/controls.asm').read_text(encoding='latin-1').replace('M4_LEVEL_KIND_CTL_RESET', '$30') \
        .replace('M4_LEVEL_KIND_INITBLACK_L', '$20')
    cm = sorted(i for b, i in reach['0D:FA3C'])
    if 'M4CtlBoundaries:' not in ctl:  # the port now runs contmap from M4Map0D* (frozen reference below)
        ctl = CONTMAP_REFERENCE
    cb = parse_table(ctl, 'M4CtlBoundaries', 3); ck = parse_table(ctl, 'M4CtlBlocks', 6)
    nb = [(i, cmds[(0x0D, i)]['length'], kinds_of[(0x0D, i)]) for i in cm]
    nk = [recs[(0x0D, i)] for i in cm if (0x0D, i) in recs]
    corr['contmap'] = dict(reference='src/screens/controls.asm M4CtlBoundaries/M4CtlBlocks', exact=nb == cb and nk == ck,
                           boundary_differences=[list(d) for d in sorted(set(nb) ^ set(cb))],
                           block_differences=[list(d) for d in sorted(set(nk) ^ set(ck))])
    # intro + title vs build/m4-script-boundaries.inc (index,length; kinds use the intro numbering)
    ib = parse_table((ROOT / 'build/m4-script-boundaries.inc').read_text(encoding='utf-8'), 'M4ScriptBoundaries', 3)
    it = sorted({i for m in ('0D:F870', '0D:F9F2') for b, i in reach[m]})
    ni = [(i, cmds[(0x0D, i)]['length']) for i in it]
    kmap = sorted({(k, kinds_of[(0x0D, i)]) for i, _, k in ib if k})
    corr['intro_title'] = dict(reference='build/m4-script-boundaries.inc', exact_index_length=ni == [(i, l) for i, l, _ in ib],
                               differences=[list(d) for d in sorted(set(ni) ^ {(i, l) for i, l, _ in ib})],
                               intro_kind_to_map_kind=[['%d' % a, names[b]] for a, b in kmap])
    # Every known-kind 0D block also agrees with recover-level-script.decode_block on its own bank.
    corr['recover_decode_block_agreement'] = sum(1 for k in recs if cmds[k].get('block_decoded', {}).get('source') == 'recover')

    # ---- per-entry inventory ----------------------------------------------------
    port = port_consumer()
    unsup_all = {}
    for k, e in cmds.items():
        u = unsupported(e, port, kname)
        if u: unsup_all[k] = u
    stage_names = dict(I['STAGE_NAMES']); stage_names.update({m: v[0] for m, v in SCREENS.items()})
    out_entries = []
    for m, rset in reach.items():
        es = [cmds[k] for k in sorted(rset)]
        ks = Counter(kname[e['kind']] for e in es if e['kind'])
        us = Counter(unsup_all[k] for k in rset if k in unsup_all)
        out_entries.append(dict(
            map=m, name=stage_names.get(m, ''), usf_label=I['USF_LABEL'].get(m, ''), provenance=ents[m],
            commands=len(es), bytes=sum(e['length'] for e in es),
            banks={'%02X' % b: n for b, n in sorted(Counter(k[0] for k in rset).items())},
            shared_with_corneria1=len(rset & reach['0D:D068']),
            opcodes={k: v for k, v in sorted(Counter(e['opcode'] for e in es).items())},
            kinds_used=dict(sorted(ks.items())),
            kinds_new=sorted({kname[e['kind']] for e in es if e['kind'] and e['kind'] not in known}),
            kinds_not_supported=sorted({kname[e['kind']] for e in es if e['kind'] and kname[e['kind']].upper() not in port['kinds']}),
            opcodes_not_supported=sorted({e['opcode'] for e in es if int(e['opcode'], 16) not in port['opcodes']}),
            unsupported_commands=sum(us.values()), unsupported_reasons=dict(us.most_common()),
            unsupported_examples={r: next(cmds[k]['addr'] for k in sorted(rset, key=lambda k: (-k[0], k[1]))
                                          if unsup_all.get(k) == r) for r in us},
            # object events reachable from this entry: strategy (24-bit) -> first event address
            event_strategies={'%06X' % st: '%02X:%04X' % (k[0], k[1] | 0x8000) for k in sorted(rset, reverse=True)
                              if int(cmds[k]['opcode'], 16) in EV_OPS
                              for st in [event_record(k[0], k[1], cmds[k]['length'])[6]] if st}))
    kinds_json = []
    for k in sorted(names):
        used = Counter(c['addr'][:2] for c in cmds.values() if c['kind'] == k)
        kinds_json.append(dict(kind='%02X' % k, name=names[k], new=k not in known, semantics=sem[k],
                               supported_by_port=names[k].upper() in port['kinds'],
                               count=sum(used.values()), banks=dict(used)))
    blocks_json = []
    for k in sorted(recs, key=lambda k: (-k[0], k[1])):
        e, r = cmds[k], recs[k]
        b = e.get('block_decoded')
        blocks_json.append(dict(addr=e['addr'], opcode=e['opcode'], length=e['length'], kind=names[r[1]],
                                next='%04X' % r[2], branch=None if r[3] == 0xffff else '%04X' % r[3],
                                arg='%06X' % r[4], arg2='%08X' % r[5], source=b['source'] if b else 'table',
                                owners=[m for m, s in reach.items() if k in s], code=e['bytes']))
    # mother scripts (bank 05, separate interpreter 03:FB51): only located, not part of the map tables
    mothers = sorted({rw(phys(e['bank'], e['index']) + 14) for e in cmds.values() if e['opcode'] == '0A'})
    m_rng = []
    for p in mothers:
        seen, _ = I['mother_script'](p)
        for a, v in seen.items():
            if 'bytes' in v: m_rng.append((a, a + len(v['bytes']) // 2))
    map05 = sorted((i, i + cmds[(5, i)]['length']) for b, i in cmds if b == 5)
    clash = [(hex(a), hex(c)) for a, b_ in m_rng for c, d in map05 if a < d and c < b_]
    report = dict(
        rom='ref/Star Fox (USA).sfc', sha256=SHA, generator='tools/generate-map-programs.py',
        method='Reachability, lengths and successors from the forking executor of the dispatcher 03:ED6F '
               '(tools/inventory-levels.py run/walk_script); every command re-executed: index+length must be an '
               'exit (except 02/28/2A/2E), operand reads inside [0,length] reaching length-1; 0C run with a '
               'one-object list ($121F=$0E00->$0F00). 78 blocks: exact template (recover-level-script.decode_block first, '
               'then EXTRA_BLOCKS), template targets == every ldx #imm/rtl in the block == executor exits.',
        binaries=bins, include='build/map0d.inc',
        include_sha256=hashlib.sha256((ROOT / 'build/map0d.inc').read_bytes()).hexdigest(),
        totals=dict(commands=len(cmds), bank_0D=sum(1 for k in cmds if k[0] == 0x0D),
                    bank_05=sum(1 for k in cmds if k[0] == 0x05), blocks=len(recs),
                    blocks_0D=sum(1 for k in recs if k[0] == 0x0D), blocks_05=sum(1 for k in recs if k[0] == 0x05),
                    range_0D=['%04X' % min(i for b, i in cmds if b == 0x0D),
                              '%04X' % max(i + cmds[(b, i)]['length'] for b, i in cmds if b == 0x0D)],
                    range_05=['%04X' % min(i for b, i in cmds if b == 0x05),
                              '%04X' % max(i + cmds[(b, i)]['length'] for b, i in cmds if b == 0x05)],
                    unsupported_commands=len(unsup_all),
                    unsupported_reasons=dict(Counter(unsup_all.values()).most_common())),
        restart_points=restarts,
        checks=dict(inside_bank=True, no_overlap=True, successors_on_boundaries=True, block_targets_on_boundaries=True,
                    immediate_map_pointer_stores={m: v[1] for m, v in SCREENS.items()}),
        correspondence=corr,
        port_consumer=dict(opcodes=sorted('%02X' % o for o in port['opcodes']), kinds=sorted(port['kinds']),
                           alvar_offsets=sorted('%04X' % a for a in port['alvar']),
                           setvar_b=sorted('%04X' % a for a in port['setvar_b'])),
        new_opcode_notes={'%02X' % k: v for k, v in NEW_OPCODE_NOTES.items()},
        opcodes={'%02X' % op: dict(name=I['NAMES'].get(op, '?'), handler='03:%04X' % rw(phys(3, 0xED83 + op)),
                                  lengths=sorted({c['length'] for c in cmds.values() if int(c['opcode'], 16) == op}),
                                  count=sum(1 for c in cmds.values() if int(c['opcode'], 16) == op),
                                  supported_by_port=op in port['opcodes'])
                 for op in sorted({int(c['opcode'], 16) for c in cmds.values()})},
        kinds=kinds_json, entries=out_entries, blocks=blocks_json,
        mother_scripts=dict(note='interpreter 03:FB51 (table 03:FB63), bank 05; not map commands: not in the '
                                 'M4Map05 tables (lengths of inventory-levels MOTHER_LEN, not executor-verified)',
                            pointers=['05:%04X' % (p | 0x8000) for p in mothers], commands=len(m_rng),
                            overlap_with_map05_commands=clash))
    (ROOT / 'build/map-programs.json').write_text(json.dumps(report, indent=1) + '\n', encoding='utf-8')

    # ---- summary ----------------------------------------------------------------
    t = report['totals']
    print('commands %d (0D %d, 05 %d), blocks %d (0D %d, 05 %d), range 0D %s..%s, 05 %s..%s'
          % (t['commands'], t['bank_0D'], t['bank_05'], t['blocks'], t['blocks_0D'], t['blocks_05'],
             *t['range_0D'], *t['range_05']))
    c = corr['corneria1']
    print('Corneria 1 vs level1-script.inc: boundaries %d/%d, blocks %d/%d, exact %s, diffs %s %s'
          % (c['boundaries'], c['reference_boundaries'], c['blocks'], c['reference_blocks'], c['exact'],
             c['boundary_differences'][:5], c['block_differences'][:5]))
    print('contmap vs controls.asm exact %s %s %s' % (corr['contmap']['exact'], corr['contmap']['boundary_differences'],
                                                     corr['contmap']['block_differences']))
    print('intro/title vs m4-script-boundaries (index,length) exact %s %s kinds %s'
          % (corr['intro_title']['exact_index_length'], corr['intro_title']['differences'][:4],
             corr['intro_title']['intro_kind_to_map_kind']))
    print('mother scripts %d pointers, %d commands, overlap with map05 %s' % (len(mothers), len(m_rng), clash[:3]))
    print('new kinds:', ', '.join('%s=%s(%d)' % (x['kind'], x['name'], x['count']) for x in kinds_json if x['new']))
    for x in out_entries:
        print('%s %-24s cmds %4d C1 %3d unsup %4d kinds-miss %-60s ops-miss %s'
              % (x['map'], x['name'], x['commands'], x['shared_with_corneria1'], x['unsupported_commands'],
                 ','.join(x['kinds_not_supported']), ','.join(x['opcodes_not_supported'])))
    for f in ('map0d.bin', 'map05.bin', 'map0d.inc', 'map-programs.json'):
        print('  %s %s' % (f, hashlib.sha256((ROOT / 'build' / f).read_bytes()).hexdigest()))


if __name__ == '__main__':
    main()
