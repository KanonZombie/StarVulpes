"""Own command 6: original SNES planar tiles -> packed Mega Drive tiles."""
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
lines=['; Generated own SSP1601 planar conversion. Input 301000, output 303000.',
       '; 80 tiles; 20 input address,21 row count,22 tile count,23 output,24 sum.',
       '; Y retains sequence; PM4 is the only external data port used.']
def emit(*words): lines.append('        dc.w '+','.join(f'${v:04x}' if isinstance(v,int) else v for v in words))
def label(name): lines.append(name+':')
def load(slot): emit(0xe003,0x0600+slot)
def store(slot): emit(0x0e00+slot)
def immediate(value): emit(0xe003,0x0830,value)
def branch(name,zero=False): emit(0x4d50 if zero else 0x4c00,name+'/2')
def read(address,result):
    load(address); emit(0x00e3,0x08e0,0x0018,0x000c,0xe003,0x003c);store(result)
def expand(slot,high):
    load(slot);emit(0xa800,0xf000 if high else 0x0f00)
    for _ in range(8 if high else 4): emit(0x9002)
    emit(0xa800,0x00f0);store(0x26)
    load(slot);emit(0xa800,0x00f0 if high else 0x000f)
    if high:
        for _ in range(4):emit(0x9002)
    emit(0xc626,0x8800,'SVP_PlanarPairs/2',0x4a10,0xe003,0x0031)
def pack(high,result):
    expand(0x10,high);store(0x12)
    expand(0x11,high);emit(0x9003,0x9003,0xc612);store(result)

label('SVP_Planar')
for slot,value in ((0x20,0x800),(0x21,8),(0x22,80),(0x23,'((BG_OUTPUT-$300000)/2)'),(0x24,0)):
    immediate(value);store(slot)
label('SVP_PlanarRow')
read(0x20,0x10)
load(0x20);emit(0x8800,8);store(0x25);read(0x25,0x11)
pack(True,0x14);pack(False,0x15)
load(0x23);emit(0x00e3,0x08e0,0x0818,0x00c0)
load(0x14);emit(0x00c3);load(0x15);emit(0x00c3)
load(0x24);emit(0x8614,0x8615);store(0x24)
load(0x23);emit(0x8800,2);store(0x23)
load(0x20);emit(0x8800,1);store(0x20)
load(0x21);emit(0x2800,1);store(0x21);branch('SVP_PlanarNextTile',True);branch('SVP_PlanarRow')
label('SVP_PlanarNextTile')
load(0x22);emit(0x2800,1);store(0x22);branch('SVP_PlanarDone',True)
load(0x20);emit(0x8800,8);store(0x20);immediate(8);store(0x21);branch('SVP_PlanarRow')
label('SVP_PlanarDone')
emit(0x08e0,8,0x08e0,0x0018,0x00c0);load(0x24);emit(0x00c3)
immediate(1280);branch('SVP_PublishResult')
label('SVP_PlanarPairs')
for index in range(256):
    word=sum((((index>>(7-pixel))&1)|(((index>>(3-pixel))&1)<<1))<<(12-4*pixel) for pixel in range(4))
    emit(word)
(ROOT/'build/svp-planar.inc').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('Generated own SVP planar conversion, 80 original tiles')
