"""Minimal 65816 disassembler for selected-ROM study (LoROM, no header).

Usage: dis65816.py BANK:ADDR [count] [--m8|--m16] [--x8|--x16]
Tracks REP/SEP for M/X widths linearly (no branch merging). Output only.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
M = {  # mnemonic, mode
0x00:('brk','imm8'),0x01:('ora','(dp,x)'),0x02:('cop','imm8'),0x03:('ora','sr'),0x04:('tsb','dp'),0x05:('ora','dp'),0x06:('asl','dp'),0x07:('ora','[dp]'),
0x08:('php',''),0x09:('ora','#m'),0x0a:('asl','a'),0x0b:('phd',''),0x0c:('tsb','abs'),0x0d:('ora','abs'),0x0e:('asl','abs'),0x0f:('ora','long'),
0x10:('bpl','rel'),0x11:('ora','(dp),y'),0x12:('ora','(dp)'),0x13:('ora','(sr),y'),0x14:('trb','dp'),0x15:('ora','dp,x'),0x16:('asl','dp,x'),0x17:('ora','[dp],y'),
0x18:('clc',''),0x19:('ora','abs,y'),0x1a:('inc','a'),0x1b:('tcs',''),0x1c:('trb','abs'),0x1d:('ora','abs,x'),0x1e:('asl','abs,x'),0x1f:('ora','long,x'),
0x20:('jsr','abs'),0x21:('and','(dp,x)'),0x22:('jsl','long'),0x23:('and','sr'),0x24:('bit','dp'),0x25:('and','dp'),0x26:('rol','dp'),0x27:('and','[dp]'),
0x28:('plp',''),0x29:('and','#m'),0x2a:('rol','a'),0x2b:('pld',''),0x2c:('bit','abs'),0x2d:('and','abs'),0x2e:('rol','abs'),0x2f:('and','long'),
0x30:('bmi','rel'),0x31:('and','(dp),y'),0x32:('and','(dp)'),0x33:('and','(sr),y'),0x34:('bit','dp,x'),0x35:('and','dp,x'),0x36:('rol','dp,x'),0x37:('and','[dp],y'),
0x38:('sec',''),0x39:('and','abs,y'),0x3a:('dec','a'),0x3b:('tsc',''),0x3c:('bit','abs,x'),0x3d:('and','abs,x'),0x3e:('rol','abs,x'),0x3f:('and','long,x'),
0x40:('rti',''),0x41:('eor','(dp,x)'),0x42:('wdm','imm8'),0x43:('eor','sr'),0x44:('mvp','mv'),0x45:('eor','dp'),0x46:('lsr','dp'),0x47:('eor','[dp]'),
0x48:('pha',''),0x49:('eor','#m'),0x4a:('lsr','a'),0x4b:('phk',''),0x4c:('jmp','abs'),0x4d:('eor','abs'),0x4e:('lsr','abs'),0x4f:('eor','long'),
0x50:('bvc','rel'),0x51:('eor','(dp),y'),0x52:('eor','(dp)'),0x53:('eor','(sr),y'),0x54:('mvn','mv'),0x55:('eor','dp,x'),0x56:('lsr','dp,x'),0x57:('eor','[dp],y'),
0x58:('cli',''),0x59:('eor','abs,y'),0x5a:('phy',''),0x5b:('tcd',''),0x5c:('jml','long'),0x5d:('eor','abs,x'),0x5e:('lsr','abs,x'),0x5f:('eor','long,x'),
0x60:('rts',''),0x61:('adc','(dp,x)'),0x62:('per','rel16'),0x63:('adc','sr'),0x64:('stz','dp'),0x65:('adc','dp'),0x66:('ror','dp'),0x67:('adc','[dp]'),
0x68:('pla',''),0x69:('adc','#m'),0x6a:('ror','a'),0x6b:('rtl',''),0x6c:('jmp','(abs)'),0x6d:('adc','abs'),0x6e:('ror','abs'),0x6f:('adc','long'),
0x70:('bvs','rel'),0x71:('adc','(dp),y'),0x72:('adc','(dp)'),0x73:('adc','(sr),y'),0x74:('stz','dp,x'),0x75:('adc','dp,x'),0x76:('ror','dp,x'),0x77:('adc','[dp],y'),
0x78:('sei',''),0x79:('adc','abs,y'),0x7a:('ply',''),0x7b:('tdc',''),0x7c:('jmp','(abs,x)'),0x7d:('adc','abs,x'),0x7e:('ror','abs,x'),0x7f:('adc','long,x'),
0x80:('bra','rel'),0x81:('sta','(dp,x)'),0x82:('brl','rel16'),0x83:('sta','sr'),0x84:('sty','dp'),0x85:('sta','dp'),0x86:('stx','dp'),0x87:('sta','[dp]'),
0x88:('dey',''),0x89:('bit','#m'),0x8a:('txa',''),0x8b:('phb',''),0x8c:('sty','abs'),0x8d:('sta','abs'),0x8e:('stx','abs'),0x8f:('sta','long'),
0x90:('bcc','rel'),0x91:('sta','(dp),y'),0x92:('sta','(dp)'),0x93:('sta','(sr),y'),0x94:('sty','dp,x'),0x95:('sta','dp,x'),0x96:('stx','dp,y'),0x97:('sta','[dp],y'),
0x98:('tya',''),0x99:('sta','abs,y'),0x9a:('txs',''),0x9b:('txy',''),0x9c:('stz','abs'),0x9d:('sta','abs,x'),0x9e:('stz','abs,x'),0x9f:('sta','long,x'),
0xa0:('ldy','#x'),0xa1:('lda','(dp,x)'),0xa2:('ldx','#x'),0xa3:('lda','sr'),0xa4:('ldy','dp'),0xa5:('lda','dp'),0xa6:('ldx','dp'),0xa7:('lda','[dp]'),
0xa8:('tay',''),0xa9:('lda','#m'),0xaa:('tax',''),0xab:('plb',''),0xac:('ldy','abs'),0xad:('lda','abs'),0xae:('ldx','abs'),0xaf:('lda','long'),
0xb0:('bcs','rel'),0xb1:('lda','(dp),y'),0xb2:('lda','(dp)'),0xb3:('lda','(sr),y'),0xb4:('ldy','dp,x'),0xb5:('lda','dp,x'),0xb6:('ldx','dp,y'),0xb7:('lda','[dp],y'),
0xb8:('clv',''),0xb9:('lda','abs,y'),0xba:('tsx',''),0xbb:('tyx',''),0xbc:('ldy','abs,x'),0xbd:('lda','abs,x'),0xbe:('ldx','abs,y'),0xbf:('lda','long,x'),
0xc0:('cpy','#x'),0xc1:('cmp','(dp,x)'),0xc2:('rep','imm8'),0xc3:('cmp','sr'),0xc4:('cpy','dp'),0xc5:('cmp','dp'),0xc6:('dec','dp'),0xc7:('cmp','[dp]'),
0xc8:('iny',''),0xc9:('cmp','#m'),0xca:('dex',''),0xcb:('wai',''),0xcc:('cpy','abs'),0xcd:('cmp','abs'),0xce:('dec','abs'),0xcf:('cmp','long'),
0xd0:('bne','rel'),0xd1:('cmp','(dp),y'),0xd2:('cmp','(dp)'),0xd3:('cmp','(sr),y'),0xd4:('pei','dp'),0xd5:('cmp','dp,x'),0xd6:('dec','dp,x'),0xd7:('cmp','[dp],y'),
0xd8:('cld',''),0xd9:('cmp','abs,y'),0xda:('phx',''),0xdb:('stp',''),0xdc:('jml','[abs]'),0xdd:('cmp','abs,x'),0xde:('dec','abs,x'),0xdf:('cmp','long,x'),
0xe0:('cpx','#x'),0xe1:('sbc','(dp,x)'),0xe2:('sep','imm8'),0xe3:('sbc','sr'),0xe4:('cpx','dp'),0xe5:('sbc','dp'),0xe6:('inc','dp'),0xe7:('sbc','[dp]'),
0xe8:('inx',''),0xe9:('sbc','#m'),0xea:('nop',''),0xeb:('xba',''),0xec:('cpx','abs'),0xed:('sbc','abs'),0xee:('inc','abs'),0xef:('sbc','long'),
0xf0:('beq','rel'),0xf1:('sbc','(dp),y'),0xf2:('sbc','(dp)'),0xf3:('sbc','(sr),y'),0xf4:('pea','abs'),0xf5:('sbc','dp,x'),0xf6:('inc','dp,x'),0xf7:('sbc','[dp],y'),
0xf8:('sed',''),0xf9:('sbc','abs,y'),0xfa:('plx',''),0xfb:('xce',''),0xfc:('jsr','(abs,x)'),0xfd:('sbc','abs,x'),0xfe:('inc','abs,x'),0xff:('sbc','long,x')}
SIZE = {'':0,'a':0,'imm8':1,'dp':1,'(dp,x)':1,'sr':1,'[dp]':1,'(dp),y':1,'(dp)':1,'(sr),y':1,'dp,x':1,'dp,y':1,'[dp],y':1,
        'abs':2,'abs,x':2,'abs,y':2,'(abs)':2,'(abs,x)':2,'[abs]':2,'long':3,'long,x':3,'rel':1,'rel16':2,'mv':2}


def phys(bank, addr):
    return bank * 0x8000 + (addr & 0x7fff)


def disasm(rom, bank, addr, count, m8=True, x8=False):
    out = []
    for _ in range(count):
        p = phys(bank, addr)
        op = rom[p]
        name, mode = M[op]
        n = SIZE.get(mode, 0)
        if mode == '#m': n = 1 if m8 else 2
        if mode == '#x': n = 1 if x8 else 2
        arg = int.from_bytes(rom[p + 1:p + 1 + n], 'little') if n else None
        raw = rom[p:p + 1 + n].hex()
        if mode in ('rel', 'rel16'):
            d = arg - (1 << (8 * n)) if arg >= 1 << (8 * n - 1) else arg
            text = f'{name} ${(addr + 1 + n + d) & 0xffff:04X}'
        elif mode in ('#m', '#x'):
            text = f'{name} #${arg:0{2 * n}X}'
        elif mode == '':
            text = name
        elif mode == 'a':
            text = name + ' a'
        else:
            text = f'{name} {mode.replace("dp", f"${arg:02X}" if n == 1 else "dp").replace("abs", f"${arg:04X}").replace("long", f"${arg:06X}").replace("imm8", f"#${arg:02X}").replace("sr", f"${arg:02X},s").replace("mv", f"${arg:04X}")}'
        if op == 0xc2:
            m8 = m8 and not arg & 0x20; x8 = x8 and not arg & 0x10
        if op == 0xe2:
            m8 = m8 or bool(arg & 0x20); x8 = x8 or bool(arg & 0x10)
        out.append(f'{bank:02X}:{addr:04X}  {raw:<10} {text}')
        addr += 1 + n
    return out


if __name__ == '__main__':
    rom = (ROOT / 'ref/Star Fox (USA).sfc').read_bytes()
    b, a = sys.argv[1].split(':')
    count = int(sys.argv[2]) if len(sys.argv) > 2 and not sys.argv[2].startswith('--') else 60
    print('\n'.join(disasm(rom, int(b, 16), int(a, 16), count, m8='--m16' not in sys.argv, x8='--x8' in sys.argv)))
