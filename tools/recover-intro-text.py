"""Recover Nintendo/Presents resources and their exact selected-ROM path."""
from starfox_rom import rom_hex
import hashlib
import json
from pathlib import Path
import runpy

ROOT=Path(__file__).resolve().parents[1]

def zoom(rom,value):
    """Execute original embedded 65816 block (M=16), return X and next path."""
    pc=0x268f5;a=0;carry=False;negative=False;zero=False;x=value
    def flags(v):
        nonlocal negative,zero
        negative=bool(v&32768);zero=v==0
    for _ in range(60):
        op=rom[pc];pc+=1
        if op==0xc2:assert rom[pc]==32;pc+=1
        elif op==0xb5:assert rom[pc]==12;pc+=1;a=x;flags(a)
        elif op in (0xa9,0xc9,0x69,0x49):
            v=int.from_bytes(rom[pc:pc+2],'little');pc+=2
            if op==0xa9:a=v;flags(a)
            elif op==0xc9:carry=a>=v;flags((a-v)&65535)
            elif op==0x69:v=a+v+carry;carry=v>65535;a=v&65535;flags(a)
            else:a^=v;flags(a)
        elif op==0x6a:
            bit=a&1;a=(a>>1)|(int(carry)<<15);carry=bool(bit);flags(a)
        elif op==0x1a:a=(a+1)&65535;flags(a)
        elif op==0x18:carry=False
        elif op==0x75:
            assert rom[pc]==12;pc+=1;v=a+x+carry;carry=v>65535;a=v&65535;flags(a)
        elif op in (0x95,0x74):
            assert rom[pc]==12;pc+=1;x=a if op==0x95 else 0
        elif op in (0x10,0x30,0xf0,0xd0):
            delta=int.from_bytes(rom[pc:pc+1],'little',signed=True);pc+=1
            if (op==0x10 and not negative) or (op==0x30 and negative) or (op==0xf0 and zero) or (op==0xd0 and not zero):pc+=delta
        elif op==0x6b:return x,a
        else:raise AssertionError((hex(pc-1),hex(op)))
    raise AssertionError('Original zoom does not return')

def recover():
    rom,authority=runpy.run_path(str(ROOT/'tools/extract-intro.py'))['recover']()
    strategy_entry=bytes.fromhex(rom_hex(0x02bcd, 4))
    assert rom[0x283d+228*4:0x283d+229*4]==strategy_entry
    assert rom[0x2005f:0x20069]==bytes.fromhex(rom_hex(0x2005f, 10))
    path=rom[0x268ed:0x2695f]
    assert path[:8]==bytes.fromhex(rom_hex(0x268ed, 8))
    block=bytes.fromhex(rom_hex(0x268f5, 54))
    assert rom[0x268f5:0x2692b]==block
    assert rom[0x2692b:0x26939]==bytes.fromhex(rom_hex(0x2692b, 14))
    assert rom[0x2694d:0x2695f]==bytes.fromhex(rom_hex(0x2694d, 18))
    fragments={}
    for name,offset,code in [('wait',0x2047f,rom_hex(0x2047f, 16)),
                             ('trail',0x218d6,rom_hex(0x218d6, 9))]:
        assert rom[offset:offset+len(bytes.fromhex(code))]==bytes.fromhex(code)
        fragments[name]=dict(offset=offset,bytes=code)
    dispatch=bytes.fromhex(rom_hex(0x4c027, 31))
    assert rom[0x4c027:0x4c027+len(dispatch)]==dispatch
    strings=[]
    for name,offset in [('nintendo',0xa48e3),('presents',0xa48f6)]:
        end = rom.index(0, offset, offset + 32)
        data = rom[offset:end + 1]
        assert end > offset and all(1 <= glyph <= 26 for glyph in data[:-1])
        (ROOT/f'build/intro-{name}.bin').write_bytes(data)
        strings.append(dict(name=name,offset=offset,bytes=data.hex()))
    glyphs=rom[0xa3eda:0xa3eda+26*32]
    # Both original small/large scaled-text loops select bank 14 and load
    # (mscalechars-32)=BEBA. CPU/Super FX LoROM 14:BEDA is physical A3EDA.
    font_reference=bytes.fromhex(rom_hex(0x0cfd1, 16))
    assert rom[0xcfd1:0xcfd1+len(font_reference)]==font_reference
    assert rom[0xd08e:0xd08e+len(font_reference)]==font_reference
    # Extraction reads only the ROM. The 26 glyphs were compared once (16/10/2026)
    # with UltraStarFox SF/DATA/FONT/MOJI_2.fon: identical, same SHA-256 as below.
    assert hashlib.sha256(glyphs).hexdigest()=='1a91c5ba2d1108be5db491eb3677b12ffa2ebb5a6ab265f9c3d8d0bb380156c5'
    used=sorted(set(b for s in strings for b in bytes.fromhex(s['bytes']) if b))
    (ROOT/'build/intro-text-font.bin').write_bytes(glyphs)
    vectors=[]
    values=sorted(set([0,1,2,3,7,15,399,400,401,799,800,801,2999,3000,3001,16383,32767,32768,65535]+[(65536-v)&65535 for v in (2,3,7,15,399,400,401,799,800,801,2999,3000,3001,16383)]))
    digest=hashlib.sha256()
    for value in range(65536):
        result=zoom(rom,value)
        digest.update(b''.join(v.to_bytes(2,'big') for v in result))
    for value in values:
        result=zoom(rom,value)
        vectors.append(f'        dc.w ${value:04x},${result[0]:04x},${result[1]:04x}')
    (ROOT/'build/intro-text-zoom.inc').write_text(f'M4_TEXT_ZOOM_CASES equ {len(vectors)}\n'+'\n'.join(vectors)+'\n',encoding='utf-8')
    (ROOT/'build/intro-text-path.bin').write_bytes(path)
    report=dict(rom_sha256=authority['sha256'],strategy_table_offset=0x283d+228*4,
                strategy=int.from_bytes(strategy_entry[:3],'little'),
                path_base_offset=0x223fe,path_index=0x44ef,path_offset=0x268ed,path_bytes=path.hex(),
                zoom_offset=0x268f5,zoom_bytes=block.hex(),zoom_all_word_inputs_digest=digest.hexdigest(),zoom_cases=len(vectors),
                fragments=fragments,dispatch=dict(offset=0x4c027,handler_entries='Bank + (CPU address-1), dispatched through RTL; execution starts one byte after stored address.'),
                font_offset=0xa3eda,font_bytes=len(glyphs),font_sha256=hashlib.sha256(glyphs).hexdigest(),
                font_kernel_references=[0xcfd1,0xd08e],font_kernel_bytes=font_reference.hex(),
                used_glyphs=used,strings=strings,
                source='SF/PATH/DPATHDAT.ASM: dintro1; PATHS.ASM; MARIO/MDATA.MC; MARIO/MDSPRITE.MC',
                scope='Original path/resource recovery, not proof of target projection, traversal order or complete intro.')
    (ROOT/'build/intro-text-origin.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('Recovered original intro text/path; all 65536 zoom inputs terminate')
    return rom,report

def original_wait(rom,counter):
    """Execute the selected wait handler with its literal path operand 20."""
    pc=0x2047f;a=0;zero=False
    for _ in range(12):
        op=rom[pc];pc+=1
        if op==0x20:
            assert rom[pc:pc+2]==bytes.fromhex('4aa3');pc+=2
            # getparam1's input is the actual path stream, not a test constant.
            a=rom[0x223fe+0x4532+1]
        elif op==0xd5:assert rom[pc]==0x24;pc+=1;zero=a==counter
        elif op==0xd0:
            delta=int.from_bytes(rom[pc:pc+1],'little',signed=True);pc+=1
            if not zero:pc+=delta
        elif op==0xf6:assert rom[pc]==0x24;pc+=1;counter=(counter+1)&255
        elif op==0x5c:
            assert rom[pc:pc+3]==bytes.fromhex('d18304')
            assert rom[0x203d1:0x203d5].hex()==rom_hex(0x203d1, 4)
            return 0,True
        elif op==0x4c:assert rom[pc:pc+2]==bytes.fromhex('9aa1');return counter,False
        else:raise AssertionError((hex(pc-1),hex(op)))
    raise AssertionError('Wait did not return')

def tick(rom,state,view_z,delta_z):
    """Interpret this original path stream, with original zoom/wait execution.

    32-byte target representation, not original RAM architecture. No strategies
    other than this path are replaced or simulated here.
    """
    s=bytearray(state)
    word=lambda at:int.from_bytes(s[at:at+2],'big')
    def put(at,value):s[at:at+2]=(value&65535).to_bytes(2,'big')
    def raw(pc):return rom[0x223fe+pc]
    def operand(pc):return int.from_bytes(rom[0x223fe+pc:0x223fe+pc+2],'little')
    put(22,0)
    if not word(16):return bytes(s)
    pc=word(6)
    for _ in range(20):
        op=raw(pc)
        if op==0: s[11]=1;pc+=1
        elif op==0x5c:
            target=operand(pc+1);assert raw(pc+3)==0
            put(12 if target==0x454f else 14,target);pc+=4
        elif op==0x52:s[9]=raw(pc+1);pc+=2
        elif op==0x70:
            assert pc==0x44f6
            x,pc=zoom(rom,word(0));put(0,x)
        elif op==0x20:pc=operand(pc+1);break
        elif op==2:
            assert pc==0x4532
            s[8],completed=original_wait(rom,s[8])
            if not completed:break
            pc+=2
        elif op==0x15:put(16,0);return bytes(s)
        else:raise AssertionError((hex(pc),hex(op)))
    else:raise AssertionError('Path does not yield')
    put(6,pc)
    if s[11]:put(4,word(4)+delta_z)
    if s[9]:
        put(22,s[9]);s[24:28]=s[:4];s[28:30]=s[4:6]
    if word(12):
        # Actual keep4000 native bytes were checked by recover().
        put(4,view_z+int.from_bytes(rom[0x26954:0x26956],'little'))
    if word(14):
        pc=word(14);invert=False
        for _ in range(12):
            op=raw(pc)
            if op==0x9d:assert raw(pc+1)==0x95;s[10]=(s[10]-1)&255;pc+=2
            elif op==0x71:invert=True;pc+=1
            elif op==0x38:
                assert raw(pc+1)==0x95
                equal=s[10]==operand(pc+2)
                pc=operand(pc+4) if equal!=invert else pc+6
                invert=False
            elif op==0x5e:put(6,operand(pc+1));pc+=3
            elif op==0x12:pc+=3 # findshape has no movement/depth effect
            elif op==0x2a:pc=operand(pc+1) # selected intro has no walker_0
            elif op==0x54:break
            else:raise AssertionError((hex(pc),hex(op)))
        else:raise AssertionError('Fade trigger does not return')
    return bytes(s)

if __name__=='__main__':recover()
