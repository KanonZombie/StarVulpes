"""Generate the port's VR-method page layout without a commercial snapshot."""
import hashlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
snapshot=ROOT/'evidence/vr-video-900-vram.bin'
vram=snapshot.read_bytes() if snapshot.is_file() else None
BLACK_TILE=0x4ce
BLACK_ENTRY=0xe000|BLACK_TILE
plane=[BLACK_ENTRY]*2048
pages=[]
for page in range(2):
    entries=[BLACK_ENTRY]*896
    for row in range(24):
        for column in range(32):
            slot=(row//2)*64+column*2+(row&1)
            tile=(1+slot+page*0x1cb) if slot<458 else 0x397+slot-458
            entries[(row+2)*32+column]=0xc000|tile
    base=page*26*32
    for i,entry in enumerate(entries):
        assert plane[base+i]==BLACK_ENTRY or plane[base+i]==entry
        plane[base+i]=entry
        if vram is not None:
            original=int.from_bytes(vram[0xc000+page*0x680+i*2:0xc002+page*0x680+i*2],'big')
            assert (entry&0x7ff)==((original&0x7ff) or BLACK_TILE),(page,i)
    pages.append(entries)
sets=[set(v&0x7ff for v in p)-{0,BLACK_TILE} for p in pages]
assert len(sets[0]&sets[1])==310 and len(sets[0]-sets[1])==458
assert len(sets[1]-sets[0])==458
# Star Fox window: GSU screen num_col28 x num_row24 (SF/INC/VARS.INC); every
# original capture keeps x0..15 and 240..255 black. Mask those columns of
# the active rows with the opaque margin tile. Tiles and DMA are unchanged.
SF_WINDOW_COLUMNS=(0,1,30,31)
for page in range(2):
    for row in range(24):
        for column in SF_WINDOW_COLUMNS:
            plane[page*26*32+(row+2)*32+column]=BLACK_ENTRY
constants={'M4VR_BITMAP0':0x303000,'M4VR_BITMAP1':0x309000,
           'M4VR_MASK_TILE':BLACK_TILE,'M4VR_MASK_VRAM':BLACK_TILE*32,'M4VR_BITMAP_BYTES':0x6000,'M4VR_PLANE_A':0xc000,
           'M4VR_PLANE_B':0xe000,'M4VR_SAT':0xd800,'M4VR_HSCROLL':0xd000,
           'M4VR_FONT':0xfe20,'M4VR_GEOMETRY':0x30f020,
           'M4VR_FACES':0x319040,'M4VR_PARTICLES':0x31d060,'M4VR_PRIMITIVES':0x301e00}
# Payload and register counts deliberately differ: original SVP delay repair.
descriptors=[(0x20,0x1361,0,0x26c0),(0x26e0,0x941,0x26c0,0x1280),(0x72e0,0x1361,0x3940,0x26c0),
             (0x3980,0x1361,0,0x26c0),(0x6040,0x941,0x26c0,0x1280),(0x72e0,0x1361,0x3940,0x26c0)]
assert sum(d[3] for d in descriptors[:3])==0x6000
(ROOT/'build/vr-plane-a.map.bin').write_bytes(b''.join(v.to_bytes(2,'big') for v in plane))
lines=['; Generated layout for two partially shared pages.']
lines += [f'{name} equ ${value:x}' for name,value in constants.items()]
lines += ['M4VRBitmapAddresses:','        dc.l M4VR_BITMAP0,M4VR_BITMAP1','M4VRDMADescriptors:']
for slot in range(2):
    for dest,count,offset,size in descriptors[slot*3:slot*3+3]:
        source=constants[f'M4VR_BITMAP{slot}']+offset
        dma_source=(source+2)//2
        registers=[0x9300|(count&255),0x9400|(count>>8),0x9500|(dma_source&255),
                   0x9600|((dma_source>>8)&255),0x9700|(dma_source>>16)]
        command=0x40000000|((dest&0x3fff)<<16)|(dest>>14)
        lines += ['        dc.w '+','.join(f'${v:04x}' for v in registers),
                  f'        dc.l ${command|0x80:08x},${command:08x},${source:08x}']
lines += ['M4VRScrollValues:','        dc.w $0001,$00d1','M4VRPlaneAMap:',"        incbin '../build/vr-plane-a.map.bin'",'        even']
(ROOT/'build/vr-video-layout.inc').write_text('\n'.join(lines)+'\n',encoding='ascii')
report=dict(check='PASS',reference_vram_sha256=hashlib.sha256(vram).hexdigest() if vram is not None else None,
            plane_a='C000,32x64; page maps C000/C680; VScroll1/D1',
            exclusive_tiles_per_page=458,shared_tiles=310,
            opaque_margin_tile=BLACK_TILE,margin_palette=3,margin_colour=1,margin_priority='high; BG B low',sf_window_columns=SF_WINDOW_COLUMNS,
            tile_order='32 columns, vertical pairs; slot=(row//2)*64+column*2+(row&1)',
            descriptors=descriptors,constants=constants,
            scope='Generated layout and optional comparison against the local reference snapshot.')
(ROOT/'build/vr-video-layout.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS VR layout:2048 entries,458 exclusive tiles/page,310 shared, six original-length DMA descriptors')
