"""SSP1601 instruction lengths and readable mnemonics for MegaSVP sources.

Decoding follows tools/ssp_sim.py (SSP:step). Used to write SSP code as
dc.w source with symbolic operands and to compare relocated copies.
"""
import struct

REG = ('-', 'x', 'y', 'a', 'st', 'stack', 'pc', 'p',
       'pm0', 'pm1', 'pm2', 'xst', 'pm4', 'ext5', 'pmc', 'al')
ALU = {0x10: 'sub', 0x30: 'cmp', 0x40: 'add', 0x50: 'and', 0x60: 'or', 0x70: 'eor'}
COND = {0x00: 'always', 0x50: 'z=0', 0x150: 'z=1', 0x70: 'n=0', 0x170: 'n=1'}


def two_words(op):
    hi = op >> 9
    return hi in (4, 6, 0x24, 0x26) or ((hi & 15) == 4 and (hi & 0x70) in ALU)


def is_branch(op):
    """call/bra/ld pc,#imm: the second word is a program WORD address."""
    return op >> 9 in (0x24, 0x26) or op == 0x0860


def words(data):
    return list(struct.unpack(f'>{len(data)//2}H', data))


def ptr(op, second=False):
    ri = (op & 3) | ((op >> 6) & 4)
    mod = (op >> 2) & 3
    if ri in (3, 7):
        return f'(r{ri})' if mod == 0 else ('(!)' if mod else f'r{ri}')
    return f'(r{ri}{"" if mod == 0 else "+!" if mod == 1 else "-" if mod == 2 else "+"})'


def mnemonic(op, imm=None):
    hi = op >> 9
    d, s = REG[(op >> 4) & 15], REG[op & 15]
    if op == 0:
        return 'nop'
    if hi == 0x00:
        return 'ld a,p' if op == 0x37 else f'ld {d},{s}'
    if hi == 0x01:
        return f'ld {d},{ptr(op)}'
    if hi == 0x02:
        return f'ld {ptr(op)},{d}'
    if hi == 0x04:
        return f'ld {d},#${imm:04x}'
    if hi == 0x06:
        return f'ld {ptr(op)},#${imm:04x}'
    if hi == 0x05:
        return f'ld {d},(({ptr(op)}))'
    if hi == 0x03:
        return f'ld a,(${op & 0x1ff:03x})'
    if hi == 0x07:
        return f'ld (${op & 0x1ff:03x}),a'
    if hi == 0x09:
        return f'ld {d},r{(op & 3) | ((op >> 6) & 4)}'
    if hi == 0x0a:
        return f'ld r{(op & 3) | ((op >> 6) & 4)},{d}'
    if hi in (0x0c, 0x0d, 0x0e, 0x0f):
        return f'ld r{(op >> 8) & 7},#${op & 0xff:02x}'
    if hi in (0x24, 0x26):
        c = COND.get(op & 0x1f0, f'cond${op & 0x1ff:03x}')
        return f'{"call" if hi == 0x24 else "bra"} {c},${imm:04x}'
    if hi == 0x25:
        return f'ld {d},((a))'
    if hi == 0x48:
        return f'mod{op & 7} cond${op & 0x1f0:03x}'
    if hi in (0x1b, 0x4b, 0x5b):
        return {0x1b: 'mpys', 0x4b: 'mpya', 0x5b: 'mld'}[hi] + f' {ptr(op)},{ptr(op >> 4)}'
    kind = ALU.get(hi & 0x70)
    group = hi & 15
    if kind:
        if group == 0:
            return f'{kind} a,{"p" if (op & 15) == 7 else "a" if (op & 15) == 3 else s}'
        if group == 1:
            return f'{kind} a,{ptr(op)}'
        if group == 3:
            return f'{kind} a,(${op & 0x1ff:03x})'
        if group == 4:
            return f'{kind} a,#${imm:04x}'
        if group == 5:
            return f'{kind} a,(({ptr(op)}))'
        if group == 9:
            return f'{kind} a,r{((op >> 6) & 4) | (op & 3)}'
        if group == 0xc:
            return f'{kind}i a,#${op & 0xff:02x}'
    return f'?{op:04x}'


def instructions(data, base):
    """Yield (byte address, [words]) for a code range starting at base."""
    w = words(data)
    i = 0
    while i < len(w):
        n = 2 if two_words(w[i]) else 1
        yield base + 2 * i, w[i:i + n]
        i += n
