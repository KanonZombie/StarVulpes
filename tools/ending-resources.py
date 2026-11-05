"""Ending unit resources: credits map 0D:F1EE and the end_game_seq texts (USA rev0).

Authority: ref/Star Fox (USA).sfc, SHA-256 3857b529...a84d (LoROM, no header). The credits
script is walked with the ROM-verified decoder of tools/inventory-levels.py (decode/walk_script,
imported, not copied); strings are read from the GSU message bank $14 (msprint draw list
MDRAWLIS.MC: m_shapebank = mariomsgs>>16; encoding of `mariomsg`: byte = 1 + char - 'A', 0 ends;
UltraStarFox MARIO/MDATA.MC only supplies names). The end_game_seq string pointers are the
immediates of 02:E56F..E69C / 02:E762..E8A1 / 02:E8DB.. (read from the ROM bytes, below).

Output: build/agent-ending/ending-resources.json
  * credits: every command in program order (object events with position, shape, strategy,
    string, colour (depthoffset), size (tscrollx), path offset; waits),
  * cards: the text objects grouped by the waits between them,
  * strings: every string used by the ending (bytes, decoded text, glyph codes),
  * glyphs: the set of character codes the ending needs (the intro SVP font has only 1..26),
  * the_end: the six THE END pathobj (shape header, path offset).
Usage: python -I tools/ending-resources.py
"""
import hashlib
import json
import runpy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
I = runpy.run_path(str(ROOT / 'tools/inventory-levels.py'), run_name='inventory_levels')
ROM, SHA = I['ROM'], I['SHA']
assert hashlib.sha256(ROM).hexdigest() == '3857b5294ea8f7468849437bb2d8271564e8a0ff30774622e9c872bcbd53a84d'
MSG_BANK = 0x14
PATH_BASE = 0x04A3FE          # paths: lda.l $04A3FE,x (path-oracle.py PATHS)
PATCHT, PATH_ISTRAT = 0x04800E, 0x048022


def phys(bank, addr):
    return (bank & 0x7F) * 0x8000 + (addr & 0x7FFF)


# Character codes seen in the ROM strings (msg_0..msg_9 = 28..37, msg_00 = 40 40 28 65 = "  0%"):
# 1..26 A..Z, 28..37 digits, 40 space, 65 '%' (the USF source writes '#').
GLYPH_CHARS = {k: chr(64 + k) for k in range(1, 27)}
GLYPH_CHARS.update({28 + k: str(k) for k in range(10)})
GLYPH_CHARS.update({40: ' ', 65: '%'})


def text(ptr):
    """Bytes of a mariomsg at 14:ptr and its decoding (GLYPH_CHARS; '?' = code not identified)."""
    o = phys(MSG_BANK, ptr)
    raw = []
    while ROM[o] and len(raw) < 40:
        raw.append(ROM[o])
        o += 1
    s = ''.join(GLYPH_CHARS.get(b, '?') for b in raw)
    return dict(ptr='%04X' % ptr, rom_offset='0x%05X' % phys(MSG_BANK, ptr), codes=raw, text=s)


def rom_word(bank, addr):
    o = phys(bank, addr)
    return ROM[o] | ROM[o + 1] << 8


def immediate(bank, addr, opcode):
    assert ROM[phys(bank, addr)] == opcode, (bank, addr)
    return rom_word(bank, addr + 1)


# end_game_seq loads message addresses with LDA or adds the base with ADC.
END_STRINGS = {name: immediate(2, addr, 0xa9)
               for name, addr in [('stage', 0xe5b5), ('total', 0xe7a8), ('ave', 0xe864)]}
digit_base = immediate(2, 0xea73, 0x69)
percent_base = immediate(2, 0xe5f0, 0x69)
END_STRINGS.update({f'n{k}': digit_base + 2 * k for k in range(10)})
END_STRINGS.update({f'p{k}': percent_base + 5 * k for k in range(101)})
# setthepath 02:E69D table (jmp ($E6A7,x)): sta $28,x immediates of each entry.
SETTHEPATH = {}
for k in range(11):
    entry = rom_word(0x02, 0xE6A7 + 2 * k)
    o = phys(0x02, entry)
    assert ROM[o] == 0xFA and ROM[o + 1:o + 3].hex() == 'c220' and ROM[o + 3] == 0xA9 and ROM[o + 6:o + 8].hex() == '9528'
    SETTHEPATH[k] = dict(entry='02:%04X' % entry, path='%04X' % (ROM[o + 4] | ROM[o + 5] << 8),
                         stage_check=k < 7)


def main():
    cmds = {}
    reach = I['walk_script'](0x0D, 0x71EE, cmds)
    # program order: execute the control flow from the entry (mapjsr 28 pushes its return, maprts 2A pops,
    # mapgoto 2E to an already executed command ends the walk: the final `mapwait 5000 / mapgoto` loop).
    order, seen, stack, pc = [], set(), [], (0x0D, 0x71EE)
    while pc not in seen:
        seen.add(pc)
        e = cmds[pc]
        order.append(e)
        if e['opcode'] == '28':
            stack.append(tuple(e['return_to']))
            pc = (int(e['target'][:2], 16), int(e['target'][3:], 16) & 0x7FFF)
        elif e['opcode'] == '2A':
            pc = stack.pop()
        else:
            nx = [tuple(n) for n in e['next']]
            assert len(nx) == 1, (e['addr'], nx)
            pc = nx[0]
    assert set(seen) == set(reach), sorted(set(reach) - seen)
    out, objs, cur = [], [], None
    for e in order:
        d = dict(addr=e['addr'], op=e['opcode'], name=e['name'])
        for k in ('wait', 'x', 'y', 'z_rel', 'shape_header', 'strategy', 'path_offset', 'field', 'value', 'var',
                  'var_name', 'target', 'routine'):
            if k in e:
                d[k] = e[k]
        if e['opcode'] in ('00', '74'):
            cur = dict(addr=e['addr'], x=e['x'], y=e['y'], z_rel=e['z_rel'], shape='%04X' % e['shape_header'],
                       strategy='%06X' % e['strategy'], colour=None, size=0, path=None, string=None)
            objs.append(cur)
        elif cur is not None and e['opcode'] == '3E' and e['field'] == 'FCEA':
            cur['string'] = text(e['value'])
        elif cur is not None and e['opcode'] == '3C' and e['field'] == 'FCDF':
            cur['colour'] = e['value']
        elif cur is not None and e['opcode'] == '3C' and e['field'] == 'FCF4':
            cur['size'] = e['value'] - 256 if e['value'] & 0x80 else e['value']
        elif cur is not None and e['opcode'] == '8C':
            cur['path'] = '%04X' % e['path_offset']
        elif cur is not None and e['opcode'] == '36':
            cur.setdefault('alvar', {})[e['field']] = e['value']
        if 'shape_header' in d:
            d['shape_header'] = '%04X' % d['shape_header']
        if 'strategy' in d:
            d['strategy'] = '%06X' % d['strategy']
        out.append(d)
    # cards: text objects between two plain mapwait (opcode 12) commands
    cards, card = [], []
    for e in order:
        if e['opcode'] == '12' and card:
            cards.append(card)
            card = []
        if e['opcode'] == '74':
            o = [x for x in objs if x['addr'] == e['addr']][0]
            card.append(o['string']['text'] if o['string'] else None)
    if card:
        cards.append(card)
    strings = {}
    for o in objs:
        if o['string']:
            strings[o['string']['ptr']] = o['string']
    for n, p in END_STRINGS.items():
        t = text(p)
        t['name'] = n
        strings.setdefault(t['ptr'], t)
    glyphs = sorted({c for s in strings.values() for c in s['codes']})
    text_objs = [o for o in objs if o['strategy'] == '%06X' % PATCHT]
    the_end = [o for o in objs if o['strategy'] == '%06X' % PATH_ISTRAT]
    res = dict(rom=I['ROM_PATH'] if 'ROM_PATH' in I else 'ref/Star Fox (USA).sfc', rom_sha256=SHA,
               generator='tools/ending-resources.py',
               creditsmap=dict(entry='0D:F1EE', rom_offset='0x6F1EE', commands=len(out),
                               bytes_sha256=hashlib.sha256(ROM[0x6F1EE:0x6F870]).hexdigest()),
               setthepath=SETTHEPATH, end_strings={n: '%04X' % p for n, p in END_STRINGS.items()},
               credits=out, text_objects=text_objs, cards=cards, the_end=the_end,
               strings=strings, glyph_codes=glyphs,
               glyphs_outside_intro_font=[c for c in glyphs if not 1 <= c <= 26],
               text_sizes=sorted({o['size'] for o in text_objs}),
               text_colours=sorted({o['colour'] for o in text_objs if o['colour'] is not None}),
               max_string_length=max(len(s['codes']) for s in strings.values()))
    dst = ROOT / 'build/agent-ending/ending-resources.json'
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(json.dumps(res, indent=1) + '\n', encoding='utf-8')
    print('credits commands', len(out), 'text objects', len(text_objs), 'cards', len(cards),
          'the_end', len(the_end))
    for c in cards:
        print('  ', ' / '.join(x or '?' for x in c))
    print('glyph codes outside 1..26:', ['%02X' % c for c in res['glyphs_outside_intro_font']])
    print('sizes', res['text_sizes'], 'colours', res['text_colours'], 'max length', res['max_string_length'])
    print('setthepath', {k: v['path'] for k, v in SETTHEPATH.items()})


if __name__ == '__main__':
    main()
