"""ROM-authoritative intro background and bounded MDECRU translation.

Only demo tiles/map are extracted. Source guidance: MDECRU.MC and BGS.ASM;
StarfoxView's Decrunch.cs helps explain the reverse stream. This implementation
uses the original sentinel/refill and stops before a match after the final raw
byte, rather than adopting helper-specific padding/termination behavior.
"""
from starfox_rom import rom_hex
import hashlib
import json
from pathlib import Path
import runpy

ROOT=Path(__file__).resolve().parents[1]

def decode(stream):
    length=int.from_bytes(stream[-2:],'big')
    assert 0<length<32768,'Only bounded intro resources'
    source=len(stream)-4
    def previous_long():
        nonlocal source
        assert source>=4,'Truncated bitstream'
        source-=4
        return int.from_bytes(stream[source:source+4],'big')
    buffer=previous_long()
    assert buffer,'Missing suffix sentinel'
    bits_read=0
    def bits(count):
        nonlocal buffer,bits_read
        result=0
        for _ in range(count):
            bit=buffer&1; buffer>>=1
            if buffer==0:
                value=previous_long()
                bit=value&1; buffer=(value>>1)|0x80000000
            result=((result<<1)|bit)&65535 # original rd2 is a word
            bits_read+=1
        return result
    output=bytearray(length); dest=length; tokens=[]
    def raw(count):
        nonlocal dest
        assert 0<count<=dest
        for _ in range(count):
            dest-=1; output[dest]=bits(8)
    while dest:
        run=bits(3)
        if run==7:
            if bits(1)==0: run=bits(4)+7
            else:
                run=bits(10)
                if run==0: run=bits(18)
        if run:
            tokens.append(dict(kind='raw',run=run,destination=dest-run))
            raw(run)
            if dest==0: break # original mgetcom checks rdeststrt first
        control=bits(2)
        if control==0: run=2; offset=bits(8)
        elif control==1: run=3; offset=bits(8 if bits(1) else 14)
        else:
            if control==2: run=4
            else:
                control=bits(2)
                if control<2: run=control+5
                elif control==2: run=bits(2)+7
                else: run=bits(8)
            offset=bits(16 if bits(1)==0 else (8 if bits(1) else 12))
        # Original copy loop enters once even if byte count is zero.
        run=max(1,run)
        assert run<=dest and offset>0,'Invalid reference'
        tokens.append(dict(kind='match',run=run,offset=offset,destination=dest-run))
        for _ in range(run):
            reference=dest+offset-1
            assert dest<=reference<length,'Reference outside previously written bytes'
            dest-=1; output[dest]=output[reference]
    return bytes(output),dict(bits_read=bits_read,source_word_offset=source,tokens=tokens)

def recover():
    rom,data=runpy.run_path(str(ROOT/'tools/extract-intro.py'))['recover']()
    assert rom[0x1ed93:0x1ed95]==bytes.fromhex(rom_hex(0x1ed93, 2))
    assert rom[0x1f502:0x1f514]==bytes.fromhex(rom_hex(0x1f502, 18))
    assert rom[0x1f514:0x1f521]==bytes.fromhex(rom_hex(0x1f514, 13))
    assert rom[0x1ad35:0x1ad3b]==bytes.fromhex(rom_hex(0x1ad35, 6))
    assert rom[0x1a8db:0x1a8f7]==bytes.fromhex(rom_hex(0x1a8db, 28))
    assert rom[0x1a92d:0x1a938]==bytes.fromhex(rom_hex(0x1a397, 11))
    assert rom[0x1ab2b:0x1ab42]==bytes.fromhex(rom_hex(0x1ab2b, 23))
    assert rom[0x1ab42:0x1ab60]==bytes.fromhex(rom_hex(0x1ab42, 30))
    assert rom[0xb301:0xb325]==bytes.fromhex(rom_hex(0x0b301, 36))
    resources=[]
    build=ROOT/'build'; build.mkdir(exist_ok=True)
    for name,offset,size in [('tiles',0xa4deb,1924),('map',0xa556f,748)]:
        stream=rom[offset:offset+size]
        output,trace=decode(stream)
        (build/f'intro-bg-{name}.compressed.bin').write_bytes(stream)
        (build/f'intro-bg-{name}.raw.bin').write_bytes(output)
        resources.append(dict(name=name,offset=offset,compressed_bytes=size,
                              sha256=hashlib.sha256(stream).hexdigest(),decoded_bytes=len(output),
                              decoded_sha256=hashlib.sha256(output).hexdigest(),trace=trace))
    # Boot decodes the palette collection from an END pointer, not a length.
    # Record the exact earliest word consumed, without adopting the differently
    # compressed palettes.palz from the partial disassembly's other revision.
    boot_code=bytes.fromhex(rom_hex(0x1628a, 40))
    assert rom[0x1628a:0x1628a+len(boot_code)]==boot_code
    palettes,palette_trace=decode(rom[0xb8000:0xbf21c])
    palette_start=0xb8000+palette_trace['source_word_offset']
    assert palette_start==0xbe6c0 and len(palettes)==5120
    assert decode(rom[palette_start:0xbf21c])[0]==palettes
    palette=palettes[0xe0:0x1c0]
    (build/'intro-bg-palette.raw.bin').write_bytes(palette)
    md_palette=[]
    for bank in (0,6):
        for i in range(16):
            value=int.from_bytes(palette[(bank*16+i)*2:(bank*16+i)*2+2],'little')
            md_palette.append(((value&31)>>2)<<1|(((value>>5)&31)>>2)<<5|(((value>>10)&31)>>2)<<9)
    (build/'intro-bg-palette.md.bin').write_bytes(b''.join(v.to_bytes(2,'big') for v in md_palette))
    tilemap=(build/'intro-bg-map.raw.bin').read_bytes()
    md_map=[]
    # Diagnostic lower-left 32x28 block, unscaled. This is not a camera port.
    for y in range(28):
        for x in range(32):
            word=int.from_bytes(tilemap[4096+(y*32+x)*2:4098+(y*32+x)*2],'little')
            tile=word&1023; bank=(word>>10)&7
            assert tile<80 and bank in (0,6)
            md_map.append((tile+64)|((bank==6)<<13)|(((word>>14)&1)<<11)|(((word>>15)&1)<<12)|(((word>>13)&1)<<15))
    (build/'intro-bg-map.md.bin').write_bytes(b''.join(v.to_bytes(2,'big') for v in md_map))
    def packed_tiles(source):
        result=bytearray()
        for start in range(0,len(source),32):
            for y in range(8):
                row=[sum(((source[start+y*2+(bit&1)+(16 if bit>=2 else 0)]>>(7-x))&1)<<bit for bit in range(4)) for x in range(8)]
                result.extend((row[x]<<4)|row[x+1] for x in range(0,8,2))
        return bytes(result)
    tiles=(build/'intro-bg-tiles.raw.bin').read_bytes()
    modified=bytearray(tiles); modified[0]^=128
    checksums=[sum(int.from_bytes(p[i:i+2],'big') for i in range(0,len(p),2))&65535 for p in (packed_tiles(tiles),packed_tiles(modified))]
    (build/'intro-bg-constants.inc').write_text(f'BG_TILE_SUM equ ${checksums[0]:04x}\nBG_MODIFIED_SUM equ ${checksums[1]:04x}\n',encoding='utf-8')
    (build/'intro-bg-script-prefix.bin').write_bytes(rom[0x6f870:0x6f875])
    report=dict(rom=data['rom'],rom_sha256=data['sha256'],request_handler=0x1f502,
                request_function=0x1f514,currentbg=0x1743,bgflags=0x1f15,request_mask=4,
                key=0xf3,bg_table=0x1ac42,bg_entry=0x1a8db,
                initial_bg2_scroll_y=dict(offset=0x1a92d,value=24,bytes=rom_hex(0x1a397, 11)),
                decrunch_entry=0xb301,sfx_bank=1,sfx_pc=0xb301,
                original_tiles_destination=0x2800,original_map_destination=0x4000,map_word_addend=0xc0,
                original_tiles_vram=0xb800,original_map_vram=0xe000,resources=resources,
                palette_compressed_consumed_range=[palette_start,0xbf21c],palette_collection_bytes=len(palettes),
                palette_source_offset=0xe0,palette_sha256=hashlib.sha256(palette).hexdigest(),
                diagnostic_map_origin_tiles=[0,32],diagnostic_map_size=[32,28],
                destination_palette_banks=[0,6],destination_tile_checksums=checksums,
                sources=['SF/MARIO/MDECRU.MC','SF/ASM/BGS.ASM: bg_intro_1, dec_chr_l, dec_bg_l',
                         'SF/ASM/WORLD.ASM: setbgdo, setbg_l','SF/INC/BGMACS.INC'],
                limitation='Decoded from selected ROM; original runtime VRAM comparison and destination presentation still required.')
    (build/'intro-background.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('PASS selected intro background:',[(r['name'],r['decoded_bytes']) for r in resources])

if __name__=='__main__': recover()
