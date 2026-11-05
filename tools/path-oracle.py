"""Star Fox (USA rev0) path interpreter: ROM-verified opcode table, decoder of the
Corneria 1 paths and a tick-by-tick oracle that executes the ROM's own 65816.

Usage:
  path-oracle.py decode  -> build/research/corneria-paths.json: opcode table, decoded
        paths, ROM-vs-Python checks (rng_step, chase_step, gen_vecs), 30 isolated
        instances and a run of the real Corneria 1 script from 0D:D11D (asserts that
        every executed path command is in the static decode).
  path-oracle.py run NAME|OFFSET [--ticks N] -> JSON lines, one object state per tick
        (instance created by its own map command, player straight flight).
  path-oracle.py level [--ticks N] -> JSON lines for every path object of the level run.
Library: World (ROM RAM init, map_commands, tick, inject_collision, zremove_pass),
level_run(flight=...) for caller-provided player poses.

Authority: ref/Star Fox (USA).sfc, SHA-256 3857b529...a84d, LoROM, no header.
UltraStarFox PATH/PATHS.ASM and PATHMACS.ASM only supply names; every length,
branch target and handler address below is read from the ROM (static scan of
each handler in bank 04) and the oracle executes the ROM bytes (tools/cpu65816.py).
"""
from starfox_rom import rom_hex
from pathlib import Path
import hashlib
import importlib.util
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
SHA = '3857b5294ea8f7468849437bb2d8271564e8a0ff30774622e9c872bcbd53a84d'


def _load(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'tools' / file)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


DIS = _load('dis65816', 'dis65816.py')
CPU = _load('cpu65816', 'cpu65816.py')

PATHS = 0x04A3FE          # lda.l $04A3FE,x at 04:8063 (opcode fetch), getparamN = paths+N
TABLE = 0x04807C          # [bank][addr-1 lo][addr-1 hi][0] x 166, dispatched by 09:C027
NOPS = 166
STRAT_LOOP = 0x805F       # .strat: fetch opcode at paths+$28, store in alx stratstate ($1CDC,x)
MOVE = 0xA19A             # .move: accel, genvecs, playerz, vecs2pos, smoke, trail, triggers, rtl
END2 = 0xA2AB             # .end2: triggers + children, no movement
GETPARAM = 0xA34A         # getparamN = A34A + 12*(N-1) (N = 1..15)
ADDALVAR = 0xA083         # Y = X + off (off&$80 -> X + $1CCA + (off&$7F))
HELPERS = {}
for n, z, a in [(14, 0x8314, 0x8318), (13, 0x8329, 0x832D), (9, 0x833E, 0x8342), (8, 0x8353, 0x8357),
                (7, 0x8368, 0x836C), (6, 0x837D, 0x8381), (5, 0x8392, 0x8396), (4, 0x83A7, 0x83AB),
                (3, 0x83BC, 0x83C0), (2, 0x83D1, 0x83D5), (1, 0x83E6, 0x83EA)]:
    HELPERS[z] = ('zadd', n)
    HELPERS[a] = ('add', n)
for n in range(1, 8):
    HELPERS[0x83F5 + 12 * (n - 1)] = ('jump', n)

# UltraStarFox s_mode_entry order minus entries absent from rev0: the three
# commented-out (firelaser, firelasercanhit, firemissile), msg2 (USF language
# extension) and score (later revision). 166 names = 166 ROM table entries;
# alignment checked per handler signature in verify_names().
NAMES = '''reltoplayeron reltoplayeroff wait alwaysgenvecson alwaysgenvecsoff setvel loop addb addw faceplayer waitfaceplayer
achaseB achaseW waitachaseB waitachaseW end setb setw findshape findnextshape faceshape remove gotopos gotoshapepos explode
immune spaceshipon spaceshipoff zacoon zacooff distless shapedistless goto igoto accel hitground hitwall initanim addanim
debris friend link shapedead iflevel leftofplayer rightofplayer aboveplayer belowplayer notfriend msg damage almostdead
smokeon smokeoff randomgoto ifsameb ifsamew ifbetweenB ifbetweenW invincibleon invincibleoff playerdead spawn spawnlink
spawnchild zremoveon zremoveoff debug fire firecanhit fireatplayer fireatplayercanhit fireatshape fireatshapecanhit weapon
childdead linkchild flagshape flagchild flagmother ifflag text trail gosub return do next inext break breakc invisibleon
invisibleoff always alwaysoff force sprite setstrat setvBB setvBW setvWW setvWB addvBB addvBW addvWW addvWB negB negW
setrandomB setrandomW ifhitflag collisionson collisionsoff start65816 ifnot particle shadowon shadowoff sound sound2 qspawn
unlinkchild behindplayer importb importw exportb exportw div2b div2w indexb indexw pushb pushw pullb pullw withinrange
shapeinrange msgwithmeter doq doalvarb doalvarw gosubalvar unlinkself becomechild becomeshape becomemother unbecome become
removechild ifzerob ifzerow ifnotzerob ifnotzerow set0b set0w incb incw decb decw addrotx addroty addrotz addworldx
addworldy addworldz addws wait1'''.split()
assert len(NAMES) == NOPS

# Object fields (bank 7E, object X; alx = X+$1CCA). Offsets read from handlers.
FIELDS = {0x04: 'shape', 0x06: 'ptr', 0x08: 'flags', 0x09: 'type', 0x0A: 'count(accel target vel)', 0x0B: 'count1(accel rate)',
          0x0C: 'worldx', 0x0E: 'worldy', 0x10: 'worldz', 0x12: 'rotx', 0x13: 'roty', 0x14: 'rotz', 0x15: 'vel',
          0x16: 'stratptr', 0x19: 'immuneptr', 0x1B: 'collobjptr', 0x1D: 'sflags', 0x1E: 'sflags2', 0x1F: 'sflags3',
          0x20: 'sflags4', 0x22: 'sbyte1', 0x23: 'sbyte2(loop)', 0x24: 'sbyte3(wait)', 0x25: 'sbyte4(friend)',
          0x26: 'sword1', 0x28: 'sword2(path pc)', 0x2A: 'hp', 0x2B: 'ap', 0x2C: 'weapontype', 0x2E: 'collflags',
          0x2F: 'vx', 0x31: 'vy', 0x33: 'vz', 0x35: 'hitflags'}
ALX = {0x00: 'sWPx1', 0x02: 'sWPy1', 0x04: 'sWPz1', 0x06: 'expstratptr', 0x09: 'collstratptr', 0x0C: 'endcollstratptr',
       0x0F: 'tempstratptr', 0x12: 'stratstate(opcode)', 0x13: 'fireobjptr', 0x15: 'depthoffset', 0x1A: 'debrisshape',
       0x1C: 'colframe', 0x1D: 'animframe', 0x1E: 'snd1', 0x1F: 'snd2', 0x20: 'coltab', 0x22: 'childx', 0x23: 'childy',
       0x24: 'childz', 0x25: 'childrotx', 0x26: 'childroty', 0x27: 'childrotz', 0x28: 'childrotobj', 0x2A: 'tx',
       0x2B: 'ty(trail colour)', 0x2C: 'memptr', 0x2E: 'stackptr', 0x30: 'stratmem(trigger list)', 0x32: 'pbyte1',
       0x33: 'pbyte2', 0x34: 'pword1'}   # GILESALX.INC/STRUCTS.INC order; ROM-checked: 06,09,12,1D,1F,2B,2E,30,32,33,34


def alvar_name(b):
    if b & 0x80:
        return 'alx+%02X:%s' % (b & 0x7f, ALX.get(b & 0x7f, '?'))
    return '+%02X:%s' % (b, FIELDS.get(b, '?'))


def phys(addr24):
    return (addr24 >> 16) * 0x8000 + (addr24 & 0x7fff)


def load_rom():
    rom = (ROOT / 'ref/Star Fox (USA).sfc').read_bytes()
    assert hashlib.sha256(rom).hexdigest() == SHA
    assert rom[0x7fdb] == 0, 'expected USA rev0'
    return rom


def handler_table(rom):
    out = []
    for i in range(NOPS):
        e = rom[phys(TABLE) + 4 * i:phys(TABLE) + 4 * i + 4]
        assert e[0] == 4 and e[3] == 0, (i, e.hex())
        out.append(0x040000 | ((int.from_bytes(e[1:3], 'little') + 1) & 0xffff))
    nxt = rom[phys(TABLE) + 4 * NOPS:phys(TABLE) + 4 * NOPS + 4]
    assert nxt.hex() == rom_hex(0x20314, 4), 'table must end where zadd14 begins (04:8314)'
    return out


# ---------------------------------------------------------------- static scan
def scan_handler(rom, entry, m8=True, x8=False, depth=0):
    """Follow every path of a bank-04 handler (and its local subroutines).

    Records helper exits (addN/zaddN/jumpN), getparamN reads with their width,
    yields (.move), re-dispatch without advance (.strat), .end2, external JSLs,
    and the object fields touched with abs/dp,X addressing.
    """
    res = dict(exits=set(), params={}, ext=set(), yield_=False, strat=False, end2=False, rtl=False, alvar=False, fields=set())
    seen = set()
    work = [(entry & 0xffff, m8, x8, depth)]
    while work:
        pc, m8, x8, depth = work.pop()
        key = (pc, m8, x8)
        if key in seen or len(seen) > 4000:
            continue
        seen.add(key)
        while True:
            if (pc, m8, x8, 'i') in seen:
                break
            seen.add((pc, m8, x8, 'i'))
            p = phys(0x040000 | pc)
            op = rom[p]
            name, mode = DIS.M[op]
            n = DIS.SIZE.get(mode, 0)
            if mode == '#m': n = 1 if m8 else 2
            if mode == '#x': n = 1 if x8 else 2
            arg = int.from_bytes(rom[p + 1:p + 1 + n], 'little') if n else 0
            nxt = (pc + 1 + n) & 0xffff
            if op == 0xc2:
                m8 = m8 and not arg & 0x20; x8 = x8 and not arg & 0x10
            if op == 0xe2:
                m8 = m8 or bool(arg & 0x20); x8 = x8 or bool(arg & 0x10)
            if mode in ('dp,x', 'abs,x') and name in ('lda', 'sta', 'ora', 'and', 'adc', 'sbc', 'cmp', 'inc', 'dec', 'stz', 'ldy', 'bit', 'asl', 'lsr', 'rol', 'ror', 'eor') and arg < 0x40:
                res['fields'].add(arg)
            if mode == 'rel' or mode == 'rel16':
                d = arg - (1 << (8 * n)) if arg >= 1 << (8 * n - 1) else arg
                tgt = (nxt + d) & 0xffff
                if name in ('bra', 'brl'):
                    pc = tgt
                    if not _target(res, tgt, m8, x8, depth, work):
                        break
                    continue
                work.append((tgt, m8, x8, depth)) if _target(res, tgt, m8, x8, depth, None) else None
                pc = nxt
                continue
            if op in (0x4c, 0x5c):
                tgt = arg & 0xffff
                if op == 0x5c and arg >> 16 != 4:
                    res['ext'].add(arg)
                    break
                if _target(res, tgt, m8, x8, depth, None):
                    pc = tgt
                    continue
                break
            if op == 0x20:
                if GETPARAM <= arg < GETPARAM + 15 * 12 and (arg - GETPARAM) % 12 == 0:
                    k = (arg - GETPARAM) // 12 + 1
                    res['params'][k] = max(res['params'].get(k, 1), 1 if m8 else 2)
                elif arg == ADDALVAR:
                    res['alvar'] = True
                elif arg == 0xA099:
                    res['triggers'] = True
                else:
                    if depth < 4 and 0x8300 <= arg < 0xA3FE:
                        sub = scan_handler_sub(rom, arg, m8, x8, depth + 1)
                        _merge(res, sub)
                pc = nxt
                continue
            if op == 0x22:
                res['ext'].add(arg)
                pc = nxt
                continue
            if op in (0x60,):
                break
            if op == 0x6b:
                res['rtl'] = True
                break
            if op in (0x7c, 0x6c, 0xfc, 0x40, 0xdc):
                res['indirect'] = True
                break
            pc = nxt
    return res


def scan_handler_sub(rom, entry, m8, x8, depth):
    return scan_handler(rom, entry, m8, x8, depth)


def _merge(res, sub):
    res['exits'] |= sub['exits']
    for k, v in sub['params'].items():
        res['params'][k] = max(res['params'].get(k, 1), v)
    res['ext'] |= sub['ext']
    for k in ('yield_', 'strat', 'end2', 'alvar'):
        res[k] = res[k] or sub[k]
    res['fields'] |= sub['fields']


def _target(res, tgt, m8, x8, depth, work):
    """True if the scan should continue into tgt (a local continuation)."""
    if tgt in HELPERS:
        res['exits'].add(HELPERS[tgt])
        return False
    if tgt == STRAT_LOOP:
        res['strat'] = True
        return False
    if tgt == MOVE:
        res['yield_'] = True
        return False
    if tgt == END2:
        res['end2'] = True
        return False
    if work is not None:
        return True
    return True


def opcode_specs(rom):
    table = handler_table(rom)
    specs = []
    for i, h in enumerate(table):
        r = scan_handler(rom, h)
        adds = sorted({n for k, n in r['exits'] if k in ('add', 'zadd')})
        jumps = sorted({n for k, n in r['exits'] if k == 'jump'})
        pend = max([k + w - 1 for k, w in r['params'].items()] + [n + 1 for n in jumps] or [0])
        length = max(adds) if adds else 1 + pend
        if NAMES[i] == 'return':
            length = 1   # pc = pulled gosub address + 3 (skips the 3-byte gosub)
        specs.append(dict(op=i, name=NAMES[i], handler='04:%04X' % (h & 0xffff), length=length, adds=adds,
                          zadd=sorted({n for k, n in r['exits'] if k == 'zadd'}), jump_params=jumps,
                          params={str(k): w for k, w in sorted(r['params'].items())}, yields=r['yield_'],
                          redispatch=r['strat'], end2=r['end2'], alvar_operand=r['alvar'],
                          ext=['%02X:%04X' % (e >> 16, e & 0xffff) for e in sorted(r['ext'])],
                          fields=['+%02X' % f for f in sorted(r['fields'])]))
    return specs


# Handler signatures that pin each name to its ROM entry (bytes at handler).
SIGNATURES = {
    'reltoplayeron': rom_hex(0x2046d, 9), 'reltoplayeroff': rom_hex(0x20476, 9),
    'alwaysgenvecson': rom_hex(0x20498, 6), 'alwaysgenvecsoff': rom_hex(0x204a1, 6),
    'zacoon': rom_hex(0x20449, 6), 'zacooff': rom_hex(0x20452, 6),
    'spaceshipon': rom_hex(0x20464, 6), 'spaceshipoff': rom_hex(0x2045b, 6),
    'setvel': rom_hex(0x204aa, 5), 'end': rom_hex(0x2131c, 9),
    'zremoveon': rom_hex(0x21721, 9), 'return': rom_hex(0x21928, 6),
    'goto': rom_hex(0x2108e, 12), 'igoto': rom_hex(0x203f5, 12), 'wait1': rom_hex(0x2048f, 9),
    'smokeon': rom_hex(0x2130a, 6), 'smokeoff': rom_hex(0x21313, 6), 'shadowon': rom_hex(0x21e0e, 6), 'shadowoff': rom_hex(0x21e17, 6),
    'collisionson': rom_hex(0x21da2, 6), 'collisionsoff': rom_hex(0x21dab, 6), 'ifnot': rom_hex(0x21ddc, 5),
    'addrotx': rom_hex(0x20523, 11), 'addroty': rom_hex(0x2052e, 11), 'addrotz': rom_hex(0x20539, 11),
    'weapon': rom_hex(0x207b3, 8), 'trail': rom_hex(0x218d6, 9), 'msg': rom_hex(0x212b8, 12),
    'randomgoto': rom_hex(0x06bc9, 7), 'invisibleon': rom_hex(0x21b58, 5), 'invincibleon': rom_hex(0x2147a, 6),
}


def verify_names(rom, specs):
    bad = []
    for s in specs:
        sig = SIGNATURES.get(s['name'])
        if sig is None:
            continue
        p = phys(0x040000 | int(s['handler'][3:], 16))
        if not rom[p:p + len(sig) // 2].hex().startswith(sig[:len(sig) // 2 * 2]):
            bad.append((s['name'], s['handler'], rom[p:p + 12].hex()))
    return bad


# ---------------------------------------------------------------- decoding
# Operand layouts (from PATHMACS.ASM), checked against the ROM-derived length.
LAYOUT = {
    'wait': 'b:n', 'setvel': 'b:vel', 'loop': 'b:count,w:target', 'addb': 'a:alvar,b:value', 'addw': 'a:alvar,w:value',
    'achaseB': 'b:value,a:alvar', 'achaseW': 'w:value,a:alvar', 'waitachaseB': 'b:value,a:alvar', 'waitachaseW': 'w:value,a:alvar',
    'setb': 'b:value,a:alvar', 'setw': 'w:value,a:alvar', 'findshape': 'w:shape', 'findnextshape': 'w:shape',
    'gotopos': 'w:x,w:y,w:z,b:speed', 'gotoshapepos': 'w:x,w:y,w:z,b:speed', 'distless': 'w:dist,w:target',
    'shapedistless': 'w:dist,w:target', 'goto': 'w:target', 'igoto': 'w:target', 'accel': 'b:vel,b:rate',
    'hitground': 'w:height,w:target', 'hitwall': 'w:target', 'initanim': 'b:frame', 'addanim': 'b:rate,b:limit',
    'debris': 'w:shape', 'friend': 'b:friend', 'shapedead': 'w:target', 'iflevel': 'b:level,w:target',
    'leftofplayer': 'w:target', 'rightofplayer': 'w:target', 'aboveplayer': 'w:target', 'belowplayer': 'w:target',
    'behindplayer': 'w:target', 'notfriend': 'b:friend,w:target', 'msg': 'b:msg', 'msgwithmeter': 'b:msg',
    'almostdead': 'w:target', 'randomgoto': 'w:target', 'ifsameb': 'a:alvar,b:value,w:target',
    'ifsamew': 'a:alvar,w:value,w:target', 'ifbetweenB': 'a:alvar,b:low,b:high,w:target',
    'ifbetweenW': 'a:alvar,w:low,w:high,w:target', 'playerdead': 'w:target',
    'spawn': 'w:shape,p:path,b:rotx,b:roty,b:rotz,b:hp,b:ap,b:x/4,b:y/4,b:z/4',
    'spawnlink': 'w:shape,p:path,b:rotx,b:roty,b:rotz,b:hp,b:ap,b:x/4,b:y/4,b:z/4',
    'spawnchild': 'w:shape,p:path,b:rotx,b:roty,b:rotz,b:hp,b:ap,b:x/4,b:y/4,b:z/4,b:child',
    'qspawn': 'w:shape,p:path,b:hp,b:ap', 'childdead': 'b:child,w:target', 'linkchild': 'b:child', 'flagchild': 'b:child',
    'ifflag': 'w:target', 'text': 'w:text,b:colour,b:size', 'trail': 'b:colour', 'gosub': 'w:target',
    'do': 'w:count', 'doq': 'b:count', 'doalvarb': 'a:alvar', 'doalvarw': 'a:alvar', 'gosubalvar': 'a:alvar',
    'break': 'w:target', 'always': 'w:target,b:trigger', 'alwaysoff': 'w:target', 'force': 'w:target',
    'sprite': 'b:colour,b:size', 'setstrat': 'l:strat', 'setvBB': 'a:dst,a:src', 'setvBW': 'a:dst,a:src',
    'setvWW': 'a:dst,a:src', 'setvWB': 'a:dst,a:src', 'addvBB': 'a:dst,a:src', 'addvBW': 'a:dst,a:src',
    'addvWW': 'a:dst,a:src', 'addvWB': 'a:dst,a:src', 'negB': 'w:fieldoff', 'negW': 'w:fieldoff',
    'setrandomB': 'w:fieldoff,b:mask', 'setrandomW': 'w:fieldoff,w:mask', 'ifhitflag': 'w:target,b:mask',
    'sound': 'b:sound', 'sound2': 'b:sound', 'unlinkchild': 'b:child', 'importb': 'a:alvar,w:var', 'importw': 'a:alvar,w:var',
    'exportb': 'a:alvar,w:var', 'exportw': 'a:alvar,w:var', 'div2b': 'w:fieldoff', 'div2w': 'w:fieldoff',
    'indexb': 'l:table,w:index,w:fieldoff', 'indexw': 'l:table,w:index,w:fieldoff', 'pushb': 'a:alvar', 'pushw': 'a:alvar',
    'pullb': 'a:alvar', 'pullw': 'a:alvar', 'withinrange': 'w:radius,w:target', 'shapeinrange': 'w:radius,w:target',
    'becomechild': 'b:child', 'removechild': 'b:child', 'ifzerob': 'a:alvar,w:target', 'ifzerow': 'a:alvar,w:target',
    'ifnotzerob': 'a:alvar,w:target', 'ifnotzerow': 'a:alvar,w:target', 'set0b': 'a:alvar', 'set0w': 'a:alvar',
    'incb': 'a:alvar', 'incw': 'a:alvar', 'decb': 'a:alvar', 'decw': 'a:alvar', 'addrotx': 'b:value', 'addroty': 'b:value',
    'addrotz': 'b:value', 'weapon': 'b:weapon', 'addworldx': 'b:value', 'addworldy': 'b:value', 'addworldz': 'b:value', 'addws': 'a:alvar,b:value',
}
SIZES = {'b': 1, 'w': 2, 'a': 1, 'p': 2, 'l': 3}
# Control flow class: stop = no fall-through; targets = operand names that are path offsets.
STOP = {'goto', 'igoto', 'end', 'remove', 'explode', 'return', 'setstrat', 'break', 'debug'}
TRIGGERS = ['always', 'every2', 'every4', 'every8', 'every16', 'every32', 'every64', 'every128', 'whenhit',
            'whenhitbyplayer', 'whenflagged', 'whenshapedead', 'whendead']
FRIENDS = {1: 'rabbit', 2: 'falcon', 3: 'frog', 6: 'anyone'}   # ids index friends_hp-1 ($18A1+id); names VARS.INC


def s8(v): return v - 256 if v & 128 else v
def s16(v): return v - 65536 if v & 32768 else v


def decode_at(rom, specs, off):
    p = phys(PATHS) + off
    op = rom[p]
    assert op < NOPS, ('bad opcode', hex(off), op)
    sp = specs[op]
    name = sp['name']
    ins = dict(off='%04X' % off, rom='%02X:%04X' % ((PATHS + off) >> 16 if False else 4, (0xA3FE + off) & 0xffff), op='%02X' % op, name=name,
               length=sp['length'], bytes=rom[p:p + sp['length']].hex())
    # bank-04 LoROM address of the command (paths may cross into bank 05)
    lin = phys(PATHS) + off
    ins['rom'] = '%02X:%04X' % (lin // 0x8000, 0x8000 + lin % 0x8000)
    ins['rom_offset'] = '0x%05X' % lin
    args = {}
    if name in LAYOUT:
        q = p + 1
        for item in LAYOUT[name].split(','):
            t, nm = item.split(':')
            v = int.from_bytes(rom[q:q + SIZES[t]], 'little')
            if t == 'a':
                args[nm] = alvar_name(v)
                args[nm + '_raw'] = v
            elif t == 'b':
                args[nm] = v if nm in ('n', 'count', 'msg', 'sound', 'frame', 'mask', 'child', 'colour', 'size', 'level', 'trigger', 'friend', 'speed', 'rate', 'limit', 'hp', 'ap') else s8(v)
            elif t == 'w':
                args[nm] = v if nm in ('target', 'shape', 'mask', 'text', 'var', 'fieldoff', 'index', 'dist', 'radius', 'count') else s16(v)
            elif t == 'p':
                args[nm] = '%04X' % v
            else:
                args[nm] = '%06X' % v
            q += SIZES[t]
        assert q - p == sp['length'], (name, q - p, sp['length'])
        if 'target' in args:
            args['target'] = '%04X' % args['target']
        if name == 'always':
            args['trigger_name'] = TRIGGERS[args['trigger']] if args['trigger'] < len(TRIGGERS) else '?'
        if name in ('friend', 'notfriend'):
            args['friend_name'] = FRIENDS.get(args['friend'], '?')
    elif name == 'start65816':
        # Inline 65816 (P_START65816 ... P_END65816): runs with X=object, M8/X16,
        # DB=7E; its RTL returns to 04:9DCF which stores A16 in +$28 and re-dispatches.
        lin = phys(PATHS) + off + 1
        bank, addr = lin // 0x8000, 0x8000 + lin % 0x8000
        code, last_imm = [], None
        for line in DIS.disasm(rom, bank, addr, 40, m8=True, x8=False):
            code.append(line)
            text = line[20:].strip()
            if text.startswith('lda #$') and len(text) == 10:
                last_imm = int(text[6:], 16)
            if text == 'rtl':
                break
        assert code[-1].endswith('rtl') and last_imm is not None, code
        end = int(code[-1][3:7], 16) + 1
        ins['length'] = 1 + (end - addr)
        ins['bytes'] = rom[p:p + ins['length']].hex()
        args['code'] = [l[16:].strip() for l in code]
        args['continue'] = '%04X' % last_imm
    else:
        assert sp['length'] == 1, (name, sp['length'])
    ins['args'] = args
    return ins


def decode_paths(rom, specs, roots):
    insts, refs = {}, {}
    work = [(int(o, 16), n) for n, o in roots.items()]
    labels = {int(o, 16): n for n, o in roots.items()}
    spawned = {}
    while work:
        off, owner = work.pop()
        while off not in insts:
            ins = decode_at(rom, specs, off)
            ins['owner'] = owner
            insts[off] = ins
            name, a = ins['name'], ins['args']
            if 'target' in a:
                t = int(a['target'], 16)
                refs.setdefault(t, set()).add(ins['off'])
                work.append((t, owner))
            if 'path' in a:
                t = int(a['path'], 16)
                spawned.setdefault(a['path'], set()).add(owner)
                labels.setdefault(t, 'spawned_%04X' % t)
                work.append((t, labels[t]))
            if name == 'start65816':
                t = int(a['continue'], 16)
                refs.setdefault(t, set()).add(ins['off'])
                work.append((t, owner))
                break
            if name in STOP:
                break
            off += ins['length']
    return insts, refs, labels, spawned


CORNERIA_ROOTS = {'e_gate': '0000', 'korori': '0572', 'e_ufo': '0B61', 'ponpon': '0BDF', 'matemsg': '1DBD',
                  'patrol': '1FD1', 'chase6_1': '2B34', 'chase6_2': '2C5D', 'chase8_1': '2EB5', 'chase8_2': '2F81',
                  'chase8_3': '2FD5', 'frog1_1': '3418', 'falco_lv1': '360A', 'frog_lv1': '361B', 'tow_0': '3AE3',
                  'robotwithlog': '4345', 'robotswithlog': '436D', 'robot': '4453'}


def script_roots():
    """Path offsets referenced by mapsetpath (8C) in the recovered level script."""
    data = json.loads((ROOT / 'build/research/corneria1-script.json').read_text(encoding='utf-8'))
    found = {}

    def walk(o):
        if isinstance(o, dict):
            if o.get('opcode') == '8C' and 'path_offset' in o:
                found.setdefault(o.get('path_name', '?'), o['path_offset'])
            for v in o.values():
                walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)
    walk(data)
    return found


# ---------------------------------------------------------------- oracle
OBJ0 = 0x0336             # 02:F4BB: free list $0336 + k*$36, 70 objects; $121F allst, $1221 free
ALX0 = 0x1CCA
PLAYER_PTR = 0x123A
GAMEFRAME = 0x15BD
PLAYER_DZ = 0x14F6        # add_playerz (1F:DC69): z += [$14F6]
SKIP_OBJ = 0x156D         # do_strat_l skips the object stored here
FRIENDS_HP = 0x18A1       # friends_hp-1 (index = friend id 1..3)
CURRENT_LEVEL = 0x1FFF
SCRIPT_BANK = 0x1FF6
DOSTRATS_LOOP = (0x02DB01, 0x02DB1F)   # ldx allst ... do_strat_l per object ... plb
MAP_DISPATCH = 0x03ED65   # php/sep/phb/jsr ED6F/plb/plp/rtl
GSU_START = 0x7E4EE3      # RAM routine: A=program bank, X=program address


class World:
    """Synthetic RAM + the ROM's own object lists, heap, map handlers and strategies."""

    def __init__(self, rom, level=0, friends_hp=40, seed=None):
        self.rom = rom
        self.bus = CPU.Bus(rom)
        self.events = []
        hooks = {GSU_START: self._gsu, 0x03E993: self._msg, 0x03B7E5: self._sound, 0x1FBDEE: self._blink}
        self.cpu = CPU.CPU(self.bus, hooks)
        self.cpu.s = 0x02FF       # 1F:BDBA reset stack
        self.tick_no = 0
        self._call(0x0AF92E)      # initmem_l (heap 7E:A0A1, 0x4FFE bytes)
        self._call(0x02F4BB)      # init object free list
        w = self.bus.wram
        for i in (1, 2, 3):
            w[FRIENDS_HP + i] = friends_hp
        w[CURRENT_LEVEL] = level
        if seed is not None:              # random_l state: DP $EF,$F0,$F1,$F2
            w[0xEF:0xF3] = bytes(seed)
        # player object: first allocation (as observed: $123A = $0336, head of allst)
        self._call(0x1FD3A9, x=0)          # alloc: X=new (head of allst)
        player = self.cpu.x
        assert player == OBJ0, hex(player)
        self._call(0x1FD36E, x=0, y=player)  # clear block + alx, default flags
        self._call(0x1FD3A9, x=0)          # dummy object: target of failed spawns/fires
        dummy = self.cpu.x
        self._call(0x1FD36E, x=0, y=dummy)
        self.player, self.dummy = player, dummy
        self.w16(PLAYER_PTR, player)
        self.w16(SKIP_OBJ, dummy)          # observed: $156D = an allst object whose strategy is skipped
        w[player + 0x2A] = 0xFF
        w[player + 0x09] &= ~0x08          # player is not z-removable
        self.trace = []                    # (tick, obj, path pc) for every opcode dispatch
        self.cpu.watch[0x04805F] = lambda c: self.trace.append((self.tick_no, c.x, self.r16(c.x + 0x28)))

    # memory helpers
    def r8(self, a): return self.bus.wram[a]
    def r16(self, a): return self.bus.wram[a] | (self.bus.wram[a + 1] << 8)
    def w16(self, a, v): self.bus.wram[a] = v & 255; self.bus.wram[a + 1] = (v >> 8) & 255
    def s16(self, a): return s16(self.r16(a))

    def _call(self, target, **regs):
        c = self.cpu
        c.m, c.xf, c.db, c.d = True, False, 0x7E, 0
        regs.setdefault('x', c.x)
        c.call_long(target, **regs)

    # hooks (each emulates the callee and returns like RTL)
    def _gsu(self, c):
        prog = ((c.a & 0xff) << 16) | c.x
        if prog == 0x0181AA:      # GSU81AA arctan (ROM GSU executed by recover-intro-weapons)
            g = self.bus.gsuram
            x = g[0x62] | (g[0x63] << 8)
            y = g[0x2C] | (g[0x2D] << 8)
            v = _atan()(self.rom, x, y)
            g[0x40], g[0x41] = v & 255, v >> 8
        else:
            raise AssertionError('GSU program %06X not modelled' % prog)
        c.do_rtl()

    def _msg(self, c):
        self.events.append(dict(tick=self.tick_no, kind='msg', id=c.a & 0xff, obj=c.x, meter=self.bus.wram[0x1FFD]))
        c.do_rtl()

    def _sound(self, c):
        self.events.append(dict(tick=self.tick_no, kind='sound', id=c.a & 0xff, obj=c.x))
        c.do_rtl()

    def _blink(self, c):
        raise AssertionError('ROM debug blink (1F:BDEE) reached from %06X' % c.r16(c.s + 1))

    # level-script fragment executed by the ROM map handlers (bytes copied from the ROM)
    def map_commands(self, addr24):
        """Run the ROM's own level script from addr24 until its first yield.

        03:ED65 dispatches with DB = map bank ($1FF6), so object-list globals
        ($121F/$1221/...) are read through the bank's low-WRAM mirror exactly as
        in the game. Returns (lastobj, objects created).
        """
        before = set(self.objects())
        self.bus.wram[SCRIPT_BANK] = addr24 >> 16
        self._call(MAP_DISPATCH, x=(addr24 & 0xffff) - 0x8000)
        return self.r16(0x16F9), [o for o in self.objects() if o not in before]

    def objects(self):
        out, x = [], self.r16(0x121F)
        while x:
            if x not in (self.player, self.dummy) and x not in getattr(self, 'colliders', ()):
                out.append(x)
            x = self.r16(x)
        return out

    def tick(self, player_xyz=None, player_dz=None):
        """One original strategy pass: gameframe++, then 02:DB01 loop over allst."""
        if player_xyz is not None:
            for i, v in enumerate(player_xyz):
                self.w16(self.player + 0x0C + 2 * i, v)
        if player_dz is not None:
            self.w16(PLAYER_DZ, player_dz)
        self.w16(GAMEFRAME, self.r16(GAMEFRAME) + 1)
        self.tick_no += 1
        c = self.cpu
        c.m, c.xf, c.db, c.d = True, False, 0x7E, 0
        c.pb, c.pc = DOSTRATS_LOOP[0] >> 16, DOSTRATS_LOOP[0] & 0xffff
        c.run(DOSTRATS_LOOP[1])

    def make_collider(self, colltype=0x88, ap=1):
        """Synthetic collider (e.g. a player laser: colltype bit7+bit3 as tested by
        pathhit 04:A2C9). Not linked to any strategy; inputs to inject_collision."""
        self._call(0x1FD3A9, x=0)
        o = self.cpu.x
        self._call(0x1FD36E, x=0, y=o)
        self.bus.wram[o + 0x2E] = colltype
        self.bus.wram[o + 0x2B] = ap
        self.bus.wram[o + 0x2A] = 0xFF
        self.colliders = getattr(self, 'colliders', []) + [o]
        return o

    def inject_collision(self, obj, other, flags=(0, 0)):
        """Writes of the collision pass 02:A547..A56A for a detected pair (detection
        geometry itself is NOT modelled): both get sflags|=$80, collobjptr=other,
        hitflags|=flags. The next do_strat_l runs the collision strategy (ROM)."""
        w = self.bus.wram
        for a, b, f in ((obj, other, flags[1]), (other, obj, flags[0])):
            w[a + 0x1D] |= 0x80
            self.w16(a + 0x1B, b)
            w[a + 0x35] |= f

    def zremove_pass(self, view_back=120):
        """MODEL [H] of 02:F500 (needs GSU view-space z): remove objects with type&8
        (zremove) whose z + shape radius (00:shape+$0E) lies behind the camera,
        camera z = player z - view_back (viewdist 120, unrotated view). The ROM uses
        the GSU-transformed z at 70:0014+k*$1E; not executed here."""
        w = self.bus.wram
        pz = self.s16(self.player + 0x10)
        if w[0x14D2] & 1:
            return []
        gone = []
        for o in self.objects():
            if not (w[o + 9] & 8) or (w[o + 0x2E] & 4):
                continue
            shape = self.r16(o + 4)
            radius = s16(self.rom[shape + 0x0E] | (self.rom[shape + 0x0F] << 8)) if shape < 0x8000 else 0
            if s16((self.r16(o + 0x10) - (pz - view_back) + radius) & 0xffff) < 0:
                self._call(0x1FBFDC, x=o, y=self.r16(o))
                gone.append(o)
        return gone

    def state(self, obj):
        w = self.bus.wram
        alx = obj + ALX0
        return dict(obj='%04X' % obj, pc='%04X' % self.r16(obj + 0x28), op=w[alx + 0x12],
                    strat='%02X:%04X' % (w[obj + 0x18], self.r16(obj + 0x16)), shape='%04X' % self.r16(obj + 4),
                    x=self.s16(obj + 0x0C), y=self.s16(obj + 0x0E), z=self.s16(obj + 0x10),
                    rot=[w[obj + 0x12], w[obj + 0x13], w[obj + 0x14]], vel=s8(w[obj + 0x15]),
                    v=[self.s16(obj + 0x2F), self.s16(obj + 0x31), self.s16(obj + 0x33)],
                    hp=w[obj + 0x2A], ap=w[obj + 0x2B], weapon=w[obj + 0x2C], type=w[obj + 9],
                    sflags=[w[obj + 0x1D], w[obj + 0x1E], w[obj + 0x1F], w[obj + 0x20]],
                    sbyte=[w[obj + 0x22], w[obj + 0x23], w[obj + 0x24], w[obj + 0x25]],
                    accel=[w[obj + 0x0A], w[obj + 0x0B]], ptr='%04X' % self.r16(obj + 6),
                    pbyte=[w[alx + 0x32], w[alx + 0x33]], anim=w[alx + 0x1D], stratmem='%04X' % self.r16(alx + 0x30),
                    stack='%04X' % self.r16(alx + 0x2E))


_ATAN = None


def _atan():
    global _ATAN
    if _ATAN is None:
        import runpy
        _ATAN = runpy.run_path(str(ROOT / 'tools/recover-intro-weapons.py'))['original_atan']
    return _ATAN


# ---------------------------------------------------------------- reports
def creators():
    """(mapsetpath command, creating command) pairs of the recovered Corneria 1 script."""
    data = json.loads((ROOT / 'build/level1-script.json').read_text(encoding='utf-8'))
    c = data['commands']
    out = []
    for i, x in enumerate(c):
        if x['opcode'] != '8C':
            continue
        j = i - 1
        while c[j]['opcode'] not in ('00', '70', '74', '86'):
            j -= 1
        assert c[j].get('wait_after', 0) == 0, x['addr']
        out.append(dict(setpath=x['addr'], path='%04X' % x['path_offset'], creator=c[j]['addr'], creator_name=c[j]['name'],
                        strategy=c[j].get('strategy'), x=c[j].get('x'), y=c[j].get('y'), z_rel=c[j].get('z_rel'),
                        between=[c[k]['name'] + ':' + c[k]['bytes'] for k in range(j + 1, i + 1)]))
    return out


def rng_step(st):
    """Python translation of random_l 02:FC4E (8-bit SBC chain over DP $EF..$F2)."""
    ef, f0, f1, f2 = st
    c = 0
    def sbc(a, m, c):
        r = a - m - (1 - c)
        return r & 255, int(r >= 0)
    a, c = sbc(ef, f0, 0); f0 = a
    a, c = sbc(a, f1, c); f1 = a
    a, c = sbc(a, f2, c); f2 = a
    a, c = sbc(a, ef, c); ef = a
    return a, [ef, f0, f1, f2]


def check_rng(rom, n=2000):
    w = World(rom, seed=[0x12, 0x34, 0x56, 0x78])
    st = [0x12, 0x34, 0x56, 0x78]
    for _ in range(n):
        w._call(0x02FC4A)
        a, st = rng_step(st)
        assert (w.cpu.a & 255, list(w.bus.wram[0xEF:0xF3])) == (a, st)
    return n


def chase_step(cur, tgt, bits=8):
    """Python translation of s_achase_var (04:8842 / 04:889A): one step toward tgt.

    d = tgt-cur (wrapping); |d|<8 is forced to +-8; step = d/8 truncated toward
    zero (three ASR-with-round-toward-zero); cur += step. Returns new value."""
    m = (1 << bits) - 1
    cur &= m; tgt &= m
    if cur == tgt:
        return cur
    d = (tgt - cur) & m
    if d >> (bits - 1):
        d -= 1 << bits
    if 0 <= d < 8:
        d = 8
    elif -8 <= d < 0:
        d = -8
    step = int(d / 8)
    return (cur + step) & m


def run_handler(w, obj, off):
    """Execute one path command (ROM) for obj at path offset off; stop at the next
    dispatch (04:805F) or at .move (04:A19A, before movement). Returns stop PC."""
    c = w.cpu
    w.w16(obj + 0x28, off)
    c.m, c.xf, c.db, c.d, c.x = True, False, 0x7E, 0, obj
    c.pb, c.pc = 0x04, STRAT_LOOP
    c.step(); c.step()   # leave 805F
    for _ in range(100000):
        pc24 = (c.pb << 16) | c.pc
        if pc24 in (0x040000 | STRAT_LOOP, 0x040000 | MOVE):
            c.s = 0x02FF
            return pc24 & 0xffff
        if pc24 in c.hooks:
            c.hooks[pc24](c)
            continue
        c.step()
    raise AssertionError('handler did not finish')


def check_chase(rom, insts):
    """Every achase/waitachase command of the decode x every current value: ROM == chase_step."""
    w = World(rom)
    obj = w.objects()[0] if w.objects() else None
    w._call(0x1FD3A9, x=0)
    obj = w.cpu.x
    w._call(0x1FD36E, x=0, y=obj)
    n = 0
    for off, ins in sorted(insts.items()):
        if ins['name'] not in ('achaseB', 'waitachaseB', 'achaseW'):
            continue
        a = ins['args']
        field = a['alvar_raw']
        addr = obj + (field if not field & 0x80 else ALX0 + (field & 0x7f))
        bits = 16 if ins['name'] == 'achaseW' else 8
        values = range(256) if bits == 8 else [v & 0xffff for v in range(-1100, 1100, 7)] + [0x7ff8, 0x8000, 0x8007]
        for cur in values:
            if bits == 8:
                w.bus.wram[addr] = cur
            else:
                w.w16(addr, cur)
            stop = run_handler(w, obj, off)
            got = w.bus.wram[addr] if bits == 8 else w.r16(addr)
            exp = chase_step(cur, a['value'], bits)
            assert got == exp, (ins['off'], ins['name'], cur, got, exp)
            done = cur == (a['value'] & ((1 << bits) - 1))   # waitachase: finishes only if equal on entry
            if ins['name'] == 'waitachaseB':
                assert (stop == STRAT_LOOP) == done and w.r16(obj + 0x28) == (off + (3 if done else 0)), (ins['off'], cur, hex(stop))
            else:
                assert stop == STRAT_LOOP and w.r16(obj + 0x28) == off + ins['length']
            n += 1
    return n


def gen_vecs(rom, vel, rotx, roty):
    """Python translation of genvecs 04:84BF (3D branch, sflags2 bit6 clear) ->
    1F:D5A7/1F:C41E. sin table 00:98A5 (s8, 256 entries), cos(i)=sin(i+64),
    m(a,b)=sign*floor(2|a||b|/256). vel=-128 yields (0,0,0) in the ROM."""
    if vel == -128:
        return (0, 0, 0)
    t = phys(0x0098A5)
    sn = lambda i: s8(rom[t + (i & 255)])
    cs = lambda i: sn(i + 64)
    def m(a, b):
        return (-1 if (a < 0) != (b < 0) else 1) * ((2 * abs(a) * abs(b)) // 256)
    return (m(m(vel, sn(-roty)), cs(rotx)), m(vel, sn(rotx)), m(m(vel, cs(-roty)), cs(rotx)))


def check_genvecs(rom, n=4000):
    import random
    w = World(rom)
    w._call(0x1FD3A9, x=0)
    o = w.cpu.x
    w._call(0x1FD36E, x=0, y=o)
    rnd = random.Random(0x84BF)
    cases = [(v, rx, ry) for v in (-128, -127, -1, 0, 1, 20, 40, 70, 127) for rx in (0, 32, 64, 128, 192, 224) for ry in (0, 42, 64, 128, 214)]
    cases += [(rnd.randrange(-128, 128), rnd.randrange(256), rnd.randrange(256)) for _ in range(n)]
    for vel, rx, ry in cases:
        w.bus.wram[o + 0x15], w.bus.wram[o + 0x12], w.bus.wram[o + 0x13], w.bus.wram[o + 0x1E] = vel & 255, rx, ry, 0
        c = w.cpu
        c.m, c.xf, c.db, c.d, c.x = True, False, 0x7E, 0, o
        c.push16(0xFFEF)                   # JSR frame: RTS returns to 04:FFF0
        c.pb, c.pc = 0x04, 0x84BF
        c.run(0x04FFF0)
        got = (w.s16(o + 0x2F), w.s16(o + 0x31), w.s16(o + 0x33))
        assert got == gen_vecs(rom, vel, rx, ry), (vel, rx, ry, got)
    return len(cases)


def straight_flight(tick, start=(0, -100, 0), dz=63, view_dz=63):
    x, y, z = start
    return (x & 0xffff, y & 0xffff, (z + dz * tick) & 0xffff), view_dz


def simulate(rom, creator_addr, path_offset, ticks, flight=straight_flight, stop_when_gone=True):
    w = World(rom)
    w.player_xyz = flight(0)[0]
    for i, v in enumerate(w.player_xyz):
        w.w16(w.player + 0x0C + 2 * i, v)
    last, new = w.map_commands(int(creator_addr.replace(':', ''), 16))
    target = [o for o in new if w.r16(o + 0x28) == path_offset]
    assert target, (creator_addr, [hex(o) for o in new])
    obj = target[0]
    states = []
    alive_until = None
    for t in range(1, ticks + 1):
        xyz, vdz = flight(t)
        w.tick(player_xyz=xyz, player_dz=vdz)
        live = w.objects()
        if obj not in live:
            alive_until = t
            if stop_when_gone and len(live) == len(new) - 1 - len([o for o in new if o != obj and o not in live]):
                pass
            if stop_when_gone:
                states.append(dict(tick=t, removed=True))
                break
        st = w.state(obj)
        st['tick'] = t
        st['others'] = len(live) - 1
        states.append(st)
    return w, obj, states, alive_until


PATH_STRATS = {0x04805F}


def level_run(rom, ticks, start=0x0DD11D, flight=straight_flight, zremove=True, every=1, out=None):
    """Run the ROM's Corneria 1 script (from start) + all object strategies.

    Per tick (order of 02:DAF0 dostrats, minus init_strats/player strategy, which
    the caller replaces by `flight`): player pose -> 03:ED42 map -> strategies ->
    optional zremove model. Yields (tick, world).
    """
    w = World(rom)
    w.bus.wram[SCRIPT_BANK] = start >> 16
    w.w16(0x16FF, (start & 0xffff) - 0x8000)
    w.w16(0x16FD, 0)
    xyz0, _ = flight(0)
    w.w16(0x1701, xyz0[2])
    for t in range(1, ticks + 1):
        xyz, vdz = flight(t)
        for i, v in enumerate(xyz):
            w.w16(w.player + 0x0C + 2 * i, v)
        w.bus.wram[w.player + 0x16:w.player + 0x19] = bytes(3)   # player strategy replaced by `flight`
        w.w16(PLAYER_DZ, vdz)
        w.tick_no = t
        w._call(0x03ED42)                 # map script advance (counter -= player dz)
        w.tick_no = t - 1
        w.tick()
        if zremove:
            w.zremove_pass()
        yield t, w


def path_objects(w):
    return [o for o in w.objects() if (w.bus.wram[o + 0x18] << 16 | w.r16(o + 0x16)) in PATH_STRATS]


def selftest(rom, ticks=1500):
    specs = opcode_specs(rom)
    insts, refs, labels, spawned = decode_paths(rom, specs, CORNERIA_ROOTS)
    report = []
    executed = set()
    for cr in creators():
        w, obj, states, gone = simulate(rom, cr['creator'], int(cr['path'], 16), ticks)
        pcs = {pc for (_, o, pc) in w.trace}
        unknown = sorted(pc for pc in pcs if pc not in insts)
        assert not unknown, (cr, ['%04X' % u for u in unknown])
        executed |= pcs
        ops = sorted({insts[pc]['name'] for pc in pcs})
        report.append(dict(instance=cr['setpath'], path=cr['path'], creator=cr['creator'], ticks=len(states),
                           removed_tick=gone, executed_commands=len(pcs), ops=ops,
                           events=[e for e in w.events][:40], io_writes=len(w.bus.io_writes),
                           final=states[-2] if states and states[-1].get('removed') and len(states) > 1 else states[-1]))
    cover = dict(decoded=len(insts), executed=len(executed & set(insts)))
    return report, cover, insts, refs, labels, spawned, specs


SPAWNED_NAMES = {  # paths reached only via spawn/qspawn operands; UltraStarFox labels matched command-by-command
    '44B9': 'robexplode', '43B7': 'robotwithlog2', '43CE': 'carriedlog', '4369': 'dummy', '3B1A': 'tow_1',
    '3B50': 'dsmoke2', '3B52': 'dsmoke3', '3B54': 'dsmoke', '3544': 'e_rabbit', '3549': 'e_frog', '354E': 'e_falcon'}


def build_json(rom, ticks_isolated=1500, ticks_level=2100):
    specs = opcode_specs(rom)
    bad = verify_names(rom, specs)
    assert not bad, bad
    insts, refs, labels, spawned = decode_paths(rom, specs, CORNERIA_ROOTS)
    used = sorted({int(i['op'], 16) for i in insts.values()})
    checks = dict(rng_random_l=check_rng(rom), chase_step=check_chase(rom, insts), gen_vecs=check_genvecs(rom))
    report, cover, *_ = selftest(rom, ticks_isolated)
    level_pcs, level_events, level_samples = set(), [], []
    for t, w in level_run(rom, ticks_level):
        if t % 100 == 0:
            level_samples.append(dict(tick=t, script='0D:%04X' % (w.r16(0x16FF) + 0x8000), objects=len(w.objects()),
                                      path_objects=len(path_objects(w))))
    level_pcs = {pc for (_, o, pc) in w.trace}
    unknown = sorted('%04X' % p for p in level_pcs if p not in insts)
    assert not unknown, unknown
    executed = cover_set = set()
    for r in report:
        pass
    paths = {}
    owner_of = {}
    for off, ins in sorted(insts.items()):
        owner_of.setdefault(ins['owner'], []).append(ins)
    for name, lst in owner_of.items():
        start = CORNERIA_ROOTS.get(name) or name.replace('spawned_', '')
        paths[name if not name.startswith('spawned_') else SPAWNED_NAMES.get(start, name)] = dict(
            entry=start, rom='%02X:%04X' % ((phys(PATHS) + int(start, 16)) // 0x8000, 0x8000 + (phys(PATHS) + int(start, 16)) % 0x8000),
            instructions=[dict({k: v for k, v in i.items() if k != 'owner'}, label=('L' + i['off']) if int(i['off'], 16) in refs else None,
                               executed_in_level_run=int(i['off'], 16) in level_pcs) for i in lst])
    return dict(
        rom='ref/Star Fox (USA).sfc', sha256=SHA, revision_byte_7FDB=0, generator='tools/path-oracle.py',
        interpreter=dict(
            istrats={'pathdha_istrat': '04:8004 (HP=AP=10, then path_istrat)', 'patht_istrat': '04:800E (unused here)',
                     'path_istrat': '04:8022 (HP/AP from setalvar)'},
            strat_loop='04:805F', fetch='lda.l $04A3FE,x with X=obj+$28 (word, offset from paths 04:A3FE)',
            mode_store='alx+$12 ($1CDC,x) = opcode', dispatcher='09:C027 [$53]=04:807C, 4-byte entries [bank][addr-1]',
            table='04:807C', opcodes=NOPS, move='04:A19A', end2='04:A2AB', triggers='04:A099', getparam='04:A34A+12*(n-1)',
            addalvaroffset='04:A083', helpers={'%s%d' % (k, n): '04:%04X' % a for a, (k, n) in sorted(HELPERS.items())},
            trigger_table='04:A0CF', heap='7E:A0A1 (initmem 0A:F92E)', pathhit='04:A2C9'),
        opcodes=[dict(s, used_by_corneria=s['op'] in used, op='%02X' % s['op']) for s in specs],
        roots=CORNERIA_ROOTS, spawned={k: sorted(v) for k, v in spawned.items()},
        paths=paths,
        translations_validated=dict(checks, note='Python functions rng_step, chase_step, gen_vecs in tools/path-oracle.py equal ROM execution on these many cases'),
        oracle=dict(isolated_instances=report, isolated_coverage=cover,
                    level_run=dict(start='0D:D11D', ticks=ticks_level, flight='x=0,y=-100,z+=63/tick, $14F6=63',
                                   executed_commands=len(level_pcs & set(insts)), decoded_commands=len(insts),
                                   msgs=[e for e in w.events if e['kind'] == 'msg'], samples=level_samples)))


def main(argv):
    rom = load_rom()
    cmd = argv[1] if len(argv) > 1 else 'decode'
    if cmd == 'decode':
        data = build_json(rom)
        out = ROOT / 'build/research/corneria-paths.json'
        out.write_text(json.dumps(data, indent=1) + '\n', encoding='utf-8')
        o = data['oracle']
        print('opcodes', NOPS, 'used', sum(s['used_by_corneria'] for s in data['opcodes']),
              'paths', len(data['paths']), 'commands', sum(len(p['instructions']) for p in data['paths'].values()))
        print('isolated coverage', o['isolated_coverage'], 'level executed', o['level_run']['executed_commands'])
        print('wrote', out.relative_to(ROOT))
    elif cmd == 'run':
        name = argv[2]
        ticks = int(argv[argv.index('--ticks') + 1]) if '--ticks' in argv else 300
        off = CORNERIA_ROOTS.get(name, name)
        cr = [c for c in creators() if c['path'] == off.upper()]
        assert cr, 'path not created by the Corneria 1 script: %s' % name
        w, obj, states, gone = simulate(rom, cr[0]['creator'], int(off, 16), ticks)
        for s in states:
            print(json.dumps(s))
        for e in w.events:
            print(json.dumps(dict(event=e)))
    elif cmd == 'level':
        ticks = int(argv[argv.index('--ticks') + 1]) if '--ticks' in argv else 2100
        for t, w in level_run(rom, ticks):
            for o in path_objects(w):
                s = w.state(o)
                s['tick'] = t
                print(json.dumps(s))
    else:
        raise SystemExit(__doc__)


if __name__ == '__main__':
    main(sys.argv)
