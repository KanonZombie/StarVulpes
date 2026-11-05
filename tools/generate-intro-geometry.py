"""Own SSP1601 geometry backend, selected-ROM models and Q15 matrix.

cmd9: up to32 nine-WORD poses at301800. Outputs1024B/object at30E000.
cmd10: bounded face descriptors -> exact clipped primitives at30C000.
No game rules, pose animation or floating point. CPU reference remains separate.
"""
from pathlib import Path
import runpy
ROOT=Path(__file__).resolve().parents[1]
rom=(ROOT/'ref/Star Fox (USA).sfc').read_bytes()
model=runpy.run_path(str(ROOT/'tools/recover-intro-model.py'))['recover'](rom)
laser=runpy.run_path(str(ROOT/'tools/recover-intro-weapons.py'))['laser_model'](rom)
effects=runpy.run_path(str(ROOT/'tools/recover-intro-effects.py'))
boss_models=[runpy.run_path(str(ROOT/'tools/recover-intro-model.py'))['recover'](rom,a) for a in (0x6644,0x6628,0x48a0)]
models=[('Ship',model),('Laser',laser),('Explosion',effects['model'](rom,0x3e04)),('ExplosionSprite',effects['model'](rom,0x311d)),('Smoke',effects['model'](rom,0x2dd5))]+list(zip(('Boss','BossChild1','BossChild2'),boss_models))
models += [('Debris',runpy.run_path(str(ROOT/'tools/recover-intro-model.py'))['recover'](rom,0x660c)),
           ('Particle',dict(vertices=[[0,0,0]],visibility=[])),
           ('Explosion8',effects['model'](rom,0x3e20)),('ExplosionSprite8',effects['model'](rom,0x3139))]
models += [(n,runpy.run_path(str(ROOT/'tools/recover-intro-model.py'))['recover'](rom,a)) for n,a in (('ZacoE388',0x6388),('ZacoC22C',0x422c))]
# 14..16 zaco2intro muzzle flashes (06:B662), 17 title my_demo (00:BCD0).
models += [(n,effects['model'](rom,a)) for n,a in (('Flash0',0x3075),('Flash1',0x3091),('Flash2',0x30ad))]
models += [('MyDemo',runpy.run_path(str(ROOT/'tools/recover-intro-model.py'))['recover'](rom,0x3cd0))]
# 18..22 level effects (explode_Istrat 06:F45F classes, Hplasma 06:AD53, nova bomb AF41 06:A782;
# the laser spark B2A5 is a stub in the original, 01:A787, and has no model).
models += [(n,effects['model'](rom,a)) for n,a in (('Explosion4',0x3587),('ExplosionSprite4',0x3101),
           ('ExplosionSprite16',0x3155),('Ball',0x2eed),('Nuke',0x2f41))]
lines=['; Own SSP1601 geometry; program WORD pointers; DRAM WORD pointers.']
# Genesis Plus GX / PicoDrive idle-loop hack (ssp16.c read_PM4): a PM4 read
# that returns 0 from the instruction at byte $0854 or $4F12 (Virtua Racing's
# wait loops on 30FE08/30FE06) stops the SSP until the 68000 writes 30FE08 /
# 30FE06, which this port never does (the intro hung at tick 36). A blind
# 'ld -,PM4' always returns 0. Code emitted while GUARD is set puts, before each
# PM4-reading instruction, a NOP that assembles only when it would sit at one
# of those addresses (tools/check-svp-genplus-idle.py checks the ROM).
HAZARD_PCS=(0x0854,0x4f12)
def _two_words(op):
 hi=op>>9
 return hi in (0x04,0x06,0x24,0x26) or ((hi&0x0f)==4 and (hi&0x70) in (0x10,0x30,0x40,0x50,0x60,0x70))
def _reads_pm4(op):
 hi=op>>9
 if hi==0x00:return op not in (0,0x37) and (op&0x0f)==12
 if hi in (0x02,0x0a):return ((op>>4)&0x0f)==12
 if (hi&0x0f)==0 and (hi&0x70) in (0x10,0x30,0x40,0x50,0x60,0x70):return (op&0x0f)==12
 return False
def _guard_segments(v):
 segs,cur,i=[],[],0
 while i<len(v):
  op=v[i];n=2 if isinstance(op,int) and _two_words(op) else 1
  if isinstance(op,int) and _reads_pm4(op) and cur:segs.append(cur);cur=[]
  if isinstance(op,int) and _reads_pm4(op):segs.append(None)
  cur+=list(v[i:i+n]);i+=n
 segs.append(cur)
 return segs
_GUARD_IF='        if (*=$%04x)|(*=$%04x)'%HAZARD_PCS
GUARD=True
def emit(*v):
 if GUARD:
  for seg in _guard_segments(v):
   if seg is None:lines.extend([_GUARD_IF,'        dc.w 0','        endif'])
   elif seg:_emit_line(seg)
 else:_emit_line(v)
def _emit_line(v):
 # at most 12 values per dc.w line: asm68k 2.53 crashes writing listing lines
 # longer than about 512 characters (same bytes either way)
 items=[f'${x&65535:04x}' if isinstance(x,int) else x for x in v]
 # and at most ~200 characters of operands (long symbolic expressions)
 cur=[]
 for it in items:
  if cur and (len(cur)==12 or len(','.join(cur+[it]))>200):lines.append('        dc.w '+','.join(cur));cur=[]
  cur.append(it)
 lines.append('        dc.w '+','.join(cur))
def label(n):lines.append(n+':')
def load(n):emit(0xe003,0x0600+n)
def store(n):emit(0x0e00+n)
def imm(v):emit(0xe003,0x0830,v)
def branch(n,c='always'):emit(dict(always=0x4c00,z1=0x4d50,z0=0x4c50,n1=0x4d70)[c],n+'/2')
def call(n):emit(0x4800,n+'/2')
def ret():emit(0x0065)
def add(n,k):load(n);emit(0x8800,k);store(n)
def readrom():emit(0x4a10,0xe003,0x0031)
def readb(index,plus=0):load(index);emit(0x8800,plus,0x1530,0xe003,0x0330)
def writeb(index,slot,plus=0):load(index);emit(0x8800,plus,0x1530);load(slot);emit(0x0530)
def pm(pointer,write=False):load(pointer);emit(0x00e3,0x08e0,0x0818,0x00c0 if write else 0x000c)
def product(a,b):load(a);emit(0x0013);load(b);emit(0x0023,0x0037)
def save32(h,l):store(h);emit(0x003f);store(l)
def restore(h,l):load(l);emit(0x00f3,0x0600+h)
def n0(n):emit(0x4c70,n+'/2')

# Table word from the SVP ROM data block (src/system/core.asm, right after the
# 128 KiB program window): A = index -> A = word, read through PM4 (ROM read
# mode $080x, word address; a table never crosses a 64K-word page).
def georom(page_slot=None):
    # A = WORD address & $ffff inside a geometry ROM page -> A = word (PM4 ROM read).
    # Page: the model table's (constant) or RAM slot page_slot ($0800|page, entry word 6).
    if page_slot is None:
        emit(0x00e3, 0x08e0, '$0800|((SVP_GeoModels/2)>>16)', 0x000c, 0xe003, 0x003c)
    else:
        emit(0x00e3); load(page_slot); emit(0x00e3, 0x000c, 0xe003, 0x003c)
def romtab(name, minus=0):
    emit(0x8800, f'((SVP_{name}/2)&$ffff)-{minus}', 0x00e3, 0x08e0, f'$0800|((SVP_{name}/2)>>16)', 0x000c, 0xe003, 0x003c)

label('SVP_Geometry')
emit(0x0032);store(0)
emit(0x08e0,10,0x08e0,0x0018,0x000c,0xe003,0x003c);store(2);store(3)
emit(0x6800,0);branch('SVP_GeoInvalid','n1');emit(0x6800,41)
# count positive0..32: compare33, nonnegative is invalid.
branch('SVP_GeoCountValid','n1');branch('SVP_GeoInvalid')
# Vanishing point offset (MAILBOX words 13/14, signed; 0 = the GSU 112/96
# centre of the levels): the controls (64,48) and continue (76,92) screens.
label('SVP_GeoCountValid');emit(0x08e0,13,0x08e0,0x0018,0x000c,0xe003,0x003c);store(0x1f0);emit(0x08e0,14,0x08e0,0x0018,0x000c,0xe003,0x003c);store(0x1f1)
load(2);emit(0x6800,0);branch('SVP_GeoDone','z1')
imm(0xc00);store(1);imm('((M4_GEO_OUTPUT-$300000)/2)');store(4)
label('SVP_GeoObject')
pm(1)
for s in range(0x60,0x69):emit(0xe003,0x003c);store(s)
add(1,9)
# Shadow pose: model WORD bit 15, leaving ids >=256 distinct from shadows.
load(0x60);emit(0xa800,0x8000);store(0x7a);load(0x60);emit(0xa800,0x7fff);store(0x60)
load(0x60);emit(0x6800,0);branch('SVP_GeoInvalid','n1');emit(0x6800,'SVP_GEO_MODEL_COUNT');branch('SVP_GeoModelValid','n1');branch('SVP_GeoInvalid')
# Eight-WORD entries: count, visibility, vertices, visibility list, frame
# table, frame count, 0, 0. Original point stream Frames: (anim&63) mod n.
label('SVP_GeoModelValid');load(0x60);emit(0x9003,0x9003,0x9003,0x8800,'((SVP_GeoModels/2)&$ffff)');store(5)
# One PM4 read stream over the seven consecutive entry words (same words as one
# georom() per word; slot 5 is not read again).
emit(0x00e3,0x08e0,'$0800|((SVP_GeoModels/2)>>16)',0x000c)
for slot in [8,9,6,7,0x0c,0x7d,0x7f]:emit(0x003c);store(slot)
load(0x7d);emit(0x6800,0);branch('SVP_GeoModelReady','z1')
load(0x61);emit(0xa800,63);store(0x61)
label('SVP_GeoFrameModulo');load(0x61);emit(0x6600+0x7d);branch('SVP_GeoFrameReady','n1')
emit(0x2600+0x7d);store(0x61);branch('SVP_GeoFrameModulo')
label('SVP_GeoFrameReady');load(0x61);emit(0x8600+0x0c);georom(0x7f);store(6)
label('SVP_GeoModelReady')
# Matrix native829F: BYTE-negated angles; each FMULT returns floor(product/32768).
for axis in range(3):
 for cos in range(2):
  load(0x66+axis);emit(0x9006,0xa800,255)
  if cos:emit(0x8800,64,0xa800,255)
  emit(0x8800,'SVP_GeoSine/2');readrom();store(0x10+axis*2+cos)
for a,b,t in [(0x15,0x12,0x18),(0x15,0x13,0x19),(0x14,0x12,0x1a),(0x14,0x13,0x1b)]:product(a,b);store(t)
for a,b,op,t,result in [(0x1a,0x10,0x8600,0x19,0x20),(0x18,0x10,0x2600,0x1b,0x23),
                       (0x1b,0x10,0x2600,0x18,0x22),(0x19,0x10,0x8600,0x1a,0x25)]:
 product(a,b);store(0xf);load(0xf);emit(op+t);store(result)
for a,b,result in [(0x11,0x12,0x26),(0x11,0x14,0x21),(0x11,0x15,0x24),(0x11,0x13,0x28)]:product(a,b);store(result)
load(0x10);emit(0x9006);store(0x27)
# Level view (DRAM 301C00: flag, W11..W33 row-major; written by the 68000 per
# tick, getview 02:F926 W=R(+viewrot)). GSU 01:8500: rx=rz=0 and ry=0 -> W;
# ry=$80 -> W with rows 1 and 3 negated; otherwise mat = M0 x W where M0 is the
# object matrix above (the zero-view consumer matrix), each element the sum
# of three fq products with 16-bit wrap (01:952E). Translation arrives in view
# coordinates. Flag 0 (intro/title) leaves M0 untouched.
imm(0xe00);store(0x7c)
load(0xf2);emit(0x6800,2);branch('SVP_GeoViewLive','z0')
imm('((M4_CHAIN_VIEW-$300000)/2)');store(0x7c)
label('SVP_GeoViewLive');pm(0x7c)
emit(0xe003,0x003c);store(0x7e)
for k in range(9):emit(0xe003,0x003c);store(0xb0+k)
load(0x7e);emit(0x6800,0);branch('SVP_GeoViewDone','z1')
load(0x66);emit(0x6800,0);branch('SVP_GeoViewGeneral','z0')
load(0x68);emit(0x6800,0);branch('SVP_GeoViewGeneral','z0')
load(0x67);emit(0x6800,0);branch('SVP_GeoViewIdentity','z1')
load(0x67);emit(0x6800,128);branch('SVP_GeoViewGeneral','z0')
for k in range(9):
 load(0xb0+k)
 if k<3 or k>=6:emit(0x9006)
 store(0x20+k)
branch('SVP_GeoViewShortcut')
label('SVP_GeoViewIdentity')
for k in range(9):load(0xb0+k);store(0x20+k)
# Shadow on the shortcuts (01:8565 / 01:85CE): W (rows 1, 3 negated for ry=$80)
# with m21..m23 = 0.
label('SVP_GeoViewShortcut')
load(0x7a);emit(0x6800,0);branch('SVP_GeoViewDone','z1')
imm(0);store(0x23);store(0x24);store(0x25)
branch('SVP_GeoViewDone')
label('SVP_GeoViewGeneral')
# Shadow, general case (01:85F7): Aᵀ.m12 = m22 = m32 = 0 before Aᵀ x W.
load(0x7a);emit(0x6800,0);branch('SVP_GeoViewCompose','z1')
imm(0);store(0x21);store(0x24);store(0x27)
label('SVP_GeoViewCompose')
for i in range(3):
 for j in range(3):
  product(0x20+3*i,0xb0+j);store(0xc2)
  product(0x21+3*i,0xb3+j);emit(0x8600+0xc2);store(0xc2)
  product(0x22+3*i,0xb6+j);emit(0x8600+0xc2);store(0xb9+3*i+j)
for k in range(9):load(0xb9+k);store(0x20+k)
label('SVP_GeoViewDone')
# Stream records to DRAM: RAM B holds index*3 transformed WORDs (85 vertices max).
pm(4,True)
for slot in list(range(0x20,0x29))+[8,9]:load(slot);emit(0x00c3)
for _ in range(5):imm(0);emit(0x00c3)
imm(0);store(0xb)
# Vertex loop, VR method (VR ROM 002C46..: MLD/MPYA over a RAM A row and RAM B
# operands). Same words as the former one-product-per-step loop:
#  - c = hi(sum_j 2*v_j*m[axis+3j]) + t (32-bit wrap sum, 16-bit wrap add);
#  - c outside [-16384,16383] -> invalid before this vertex's RAM B or DRAM
#    writes ((c+16384) mod 2^16 has bit 15 set exactly then);
#  - RAM B[index*3+axis] = c (r5 streams; written before projecting, so a
#    model of more than 80 vertices still overwrites B F0/F1, the vanishing
#    point, as before);
#  - records x,y,z,sx,sy continue the PM4 write stream left after the 16-word
#    header (base+16+5*index), the slow projection path does not touch PM4.
# Scratch: RAM A C8..D0 transposed matrix, C6 counter, E4 M(z), E5/E6 q+1;
# RAM B FD..FF model vertex (free while vertices <= 84, asserted below).
for axis in range(3):
 for j in range(3):emit(0x0620+axis+3*j);store(0xc8+3*axis+j)
emit(0x0608);store(0xc6);emit(0x1d00)
label('SVP_GeoVertex')
emit(0x0606,0x00e3,0x067f,0x00e3,0x000c,0x1cfd,0x05c4,0x05c4,0x05c4)
emit(0x0606,0x8800,3);store(6);emit(0x18c8)
for axis in range(3):
 emit(0x1cfd,0xb744,0x9744,0x9744,0x8007,0x8600+0x63+axis);store(0x40+axis)
 emit(0x8800,0x4000);branch('SVP_GeoInvalid','n1')
 emit(0x0640+axis,0x0535)
emit(0x0642,0x6800,32);branch('SVP_GeoBehind','n1')
emit(0x0830,1);store(0xb)
emit(0x0642,0x6800,129);branch('SVP_GeoProjSlow','n1')
emit(0x6800,257);branch('SVP_GeoProjNear','n1')
# Inline SVP_GeoProject fast path for both axes (same z, one M lookup):
# q1 = hi(2|x|M) (+shl when z<257) + 1; q = q1 - [256|x| < q1*z]; the result
# is centre + B[F0+axis] +/- q (16-bit wrap), trunc(256x/z) as the call gave.
for near in (0,1):
 if near:label('SVP_GeoProjNear')
 emit(0x8800,'((SVP_RomProj/2)&$ffff)-129',0x00e3,0x08e0,'$0800|((SVP_RomProj/2)>>16)',0x000c,0x003c);store(0xe4)
 emit(0x19e4,0x1a42,0x18e5)
 for axis,centre in [(0,128),(1,112)]:
  tag=f'{near}{axis}'
  emit(0xe003,0x0640+axis,0x6800,0);branch(f'SVP_GeoProjNeg{tag}','n1')
  for neg in (0,1):
   if neg:label(f'SVP_GeoProjNeg{tag}');emit(0x9006)
   emit(0x0013,0x0221,0x0037)
   if near:emit(0x9003)
   emit(0x8800,1);store(0xe5+axis);emit(0x0820,256,0x0037,0x0214,0x0222,0x2007)
   branch(f'SVP_GeoProjDec{tag}{neg}','n1')
   for dec in (0,1):
    if dec:label(f'SVP_GeoProjDec{tag}{neg}')
    emit(0x0830,(centre-dec if not neg else centre+dec)&0xffff,0x8600+0x1f0+axis,(0x2600 if neg else 0x8600)+0xe5+axis);store(0x43+axis)
    if not (neg and dec):branch(f'SVP_GeoProjAxis{tag}')
  label(f'SVP_GeoProjAxis{tag}')
 branch('SVP_GeoProjectionReady')
label('SVP_GeoProjSlow')
for axis,centre in [(0,128),(1,112)]:
 load(0x40+axis);store(0x38);load(0x42);store(0x32)
 call('SVP_GeoProjectCache');emit(0x8800,centre,0x8600+0x1f0+axis);store(0x43+axis)
branch('SVP_GeoProjectionReady')
label('SVP_GeoBehind');imm(0);store(0x43);store(0x44)
label('SVP_GeoProjectionReady')
emit(0x1840,0x02c4,0x02c4,0x02c4,0x02c4,0x02c4)
emit(0xe003,0x06c6,0x2800,1);store(0xc6);branch('SVP_GeoVertex','z0')
# Visibility (original back-face test, sign of S = n.p0, n = e1 x e2,
# e1 = p1-p0, e2 = p2-p0, visible iff S < 0). The index triples stream from
# the geometry ROM (one PM4 read address per object), the flags to DRAM
# base+436+i, after 16 header + 84*5 vertex WORDs. The former +336
# overlapped vertices64..71 of mybase_0 and corrupted its faces at ExitBase.
# One PM4 write address per object. n_a is the same signed32 as
# before: W_a = 2*e1u*e2v - 2*e1v*e2u mod 2^32, n_a = W_a >> 1.
# Exact tier: hi(W_a) in {-1,0} for all a <=> n_a in [-32768,32767] (lo WORD
# = n_a). Then |S| <= 3*2^29 and D = sum 2*n_a*p_a mod 2^32 equals 2S unless
# D is outside (-2^30,2^30): |2S| < 3*2^30 except 2S = 3*2^30 (all n=-32768,
# p=-16384), which reads D = -2^30 and is sent on. Otherwise the former exact
# path (early sign, signed48) runs on the same n and p0.
# Scratch RAM A: C5 index*3 of p0, C7 counter, D8..DB e1 rows [1,2,0,1],
# DC..DE e2 [2,1,0], DF hi(W) OR, E0..E2 lo(n), E8..EA hi(W).
load(9);emit(0x6800,0);branch('SVP_GeoFinishObject','z1')
store(0xc7)
emit(0x0604,0x8800,436,0x00e3,0x08e0,0x0818,0x00c0)
emit(0x0607,0x00e3,0x067f,0x00e3,0x000c)
label('SVP_GeoVisibility')
emit(0x003c,0x1530);store(0xc5);emit(0x15c1,0x15c2)
for axis,e1,e2 in [(0,(0xda,),0xde),(1,(0xd8,0xdb),0xdd),(2,(0xd9,),0xdc)]:
 emit(0x0335,0x2300);[store(s) for s in e1];emit(0x0336,0x2304);store(e2)
emit(0x18d8,0x19dc)
for axis in range(3):
 if axis==1:emit(0x0214,0x0225,0x0037,0x0210,0x19dc,0x0225,0x2007)
 else:emit(0x0214,0x0225,0x0037,0x0210,0x0225,0x2007)
 store(0xe8+axis);emit(0x9002,0x003f);store(0xe0+axis)
emit(0x06e8,0x8800,1);store(0xdf)
for axis in (1,2):
 emit(0x0600+0xe8+axis,0x8800,1,0xc6df)
 if axis==1:store(0xdf)
emit(0xa800,0xfffe);branch('SVP_GeoVisFallback','z0')
emit(0x18e0,0x06c5,0x1530,0xb744,0x9744,0x9744,0x8007)
emit(0x8800,0x4000);branch('SVP_GeoVisFallback','n1');branch('SVP_GeoVisFallback','z1')
emit(0x6800,0x4000);branch('SVP_GeoVisT1Visible','n1')
emit(0x08c0,0);branch('SVP_GeoVisNext')
label('SVP_GeoVisT1Visible');emit(0x08c0,1);branch('SVP_GeoVisNext')
# Former exact path inputs: n_a hi/lo at 80+2a/81+2a, p0 at 54..56.
label('SVP_GeoVisFallback')
for axis in range(3):emit(0x0600+0xe8+axis,0x9002);store(0x80+2*axis);emit(0x0600+0xe0+axis);store(0x81+2*axis)
emit(0x06c5,0x1530)
for axis in range(3):emit(0x0334);store(0x54+axis)
label('SVP_GeoDot48')
# Exact early sign: n_i=256*h_i+l_i, l_i in0..255, |n_i|<2^21 so h_i fits.
# S=256*H+E, H=sum(h_i*p_i); |p|<=16384 gives |E|<=3*255*16384<256*49152.
# |H|>=49152 fixes sign(S) and 2H fits signed32; otherwise exact signed48.
lines.append('        if def(M4_VR_DMA)')
for axis in range(3):
 emit(0xe003,0x0680+axis*2,0x6800,32);n0('SVP_GeoDot48Exact')
 emit(0x6800,0xffe0);branch('SVP_GeoDot48Exact','n1')
for axis in range(3):
 restore(0x80+axis*2,0x81+axis*2);emit(*([0x9003]*8));store(0x94+axis)
emit(0xe003,0x0694,0x0013,0x0654,0x0023,0x0037)
emit(0x1895,0x1955,0x0210,0x0221,0x8007)
emit(0x1896,0x1956,0x0210,0x0221,0x8007)
emit(0x0810,3,0x0820,16384,0x6800,0);branch('SVP_GeoDot48Negative','n1')
emit(0x6007);branch('SVP_GeoDot48Exact','n1');imm(0);branch('SVP_GeoVisibilityValue')
label('SVP_GeoDot48Negative');emit(0x8007);branch('SVP_GeoVisible','n1')
label('SVP_GeoDot48Exact')
lines.append('        endif')
# Exact signed48 dot. Normal32*position16; no normalWORD truncation.
imm(0);store(0x89);store(0x8a);store(0x8b)
for axis in range(3):
 # Signed lowWORD product, sign extended to48bits.
 product(0x81+axis*2,0x54+axis);emit(0x9002);save32(0x87,0x86)
 load(0x87);emit(0x6800,0);branch(f'SVP_GeoLowNegative{axis}','n1')
 imm(0);branch(f'SVP_GeoLowSign{axis}')
 label(f'SVP_GeoLowNegative{axis}');imm(65535)
 label(f'SVP_GeoLowSign{axis}');store(0x88);call('SVP_GeoAdd48')
 # HighWORD product shifted16bits.
 product(0x80+axis*2,0x54+axis);emit(0x9002);save32(0x88,0x87)
 imm(0);store(0x86);call('SVP_GeoAdd48')
 # A negative lowWORD was interpreted signed; restore its unsigned weight.
 load(0x81+axis*2);emit(0x6800,0);branch(f'SVP_GeoCorrection{axis}','n1');branch(f'SVP_GeoDotNext{axis}')
 label(f'SVP_GeoCorrection{axis}');imm(0);store(0x86);load(0x54+axis);store(0x87)
 emit(0x6800,0);branch(f'SVP_GeoCorrectionNegative{axis}','n1');imm(0);branch(f'SVP_GeoCorrectionSign{axis}')
 label(f'SVP_GeoCorrectionNegative{axis}');imm(65535)
 label(f'SVP_GeoCorrectionSign{axis}');store(0x88);call('SVP_GeoAdd48')
 label(f'SVP_GeoDotNext{axis}')
label('SVP_GeoDotReady');load(0x8b);emit(0x6800,0);branch('SVP_GeoVisible','n1')
imm(0);branch('SVP_GeoVisibilityValue')
label('SVP_GeoVisible');imm(1)
label('SVP_GeoVisibilityValue');emit(0x00c3)
label('SVP_GeoVisNext');emit(0xe003,0x06c7,0x2800,1);store(0xc7);branch('SVP_GeoVisibility','z0')
label('SVP_GeoFinishObject');load(4);emit(0x8800,11);store(0xe);pm(0xe,True);load(0xb);emit(0x00c3)
label('SVP_GeoNext');add(4,512);load(2);emit(0x2800,1);store(2);branch('SVP_GeoObject','z0')
label('SVP_GeoDone');load(0);emit(0x0023);load(3);branch('SVP_PublishResult')
label('SVP_GeoInvalid');load(0);emit(0x0023);imm(65535);branch('SVP_PublishResult')

# Add operand86..88 into accumulator89..8B, exact modular48.
label('SVP_GeoAdd48');imm(0);store(0x8c)
for limb in range(3):
 load(0x8c);store(0x8d)
 load(0x89+limb);store(0x90);load(0x86+limb);store(0x91);call('SVP_GeoAdd16')
 load(0x93);store(0x8c);load(0x92);store(0x90);load(0x8d);store(0x91);call('SVP_GeoAdd16')
 load(0x92);store(0x89+limb);load(0x93);emit(0x868c);store(0x8c)
ret()
label('SVP_GeoAdd16');load(0x90);emit(0x8691);store(0x92)
load(0x90);emit(0x6800,0);branch('SVP_GeoAddFirstNegative','n1')
load(0x91);emit(0x6800,0);branch('SVP_GeoAddMixed','n1');branch('SVP_GeoAddNoCarry')
label('SVP_GeoAddFirstNegative');load(0x91);emit(0x6800,0);branch('SVP_GeoAddCarry','n1')
label('SVP_GeoAddMixed');load(0x92);emit(0x6800,0);branch('SVP_GeoAddNoCarry','n1')
label('SVP_GeoAddCarry');imm(1);branch('SVP_GeoAddCarryReady')
label('SVP_GeoAddNoCarry');imm(0)
label('SVP_GeoAddCarryReady');store(0x93);ret()

# Signed x*256/z truncation. General divider below consumes signed32 numerator.
label('SVP_GeoProject')
# VR method (ROM B[F3] recip table, ssp_00B8): reciprocal multiply. Exactness
# kept with one remainder fix: M=floor(2^(23-s)/z), q in{qe,qe+1}. Domain
# |x|<=16384, z129..16383 (tools/check-svp-projection.py); else exact divider.
lines.append('        if def(M4_VR_DMA)')
emit(0xe003,0x0632,0x6800,129);branch('SVP_GeoProjectSlow','n1')
emit(0x6800,16384);n0('SVP_GeoProjectSlow')
emit(0x6800,257);branch('SVP_GeoProjectNear','n1')
romtab('RomProj',129);emit(0x0023)
emit(0xe003,0x0638,0x9007,0x6800,16385);n0('SVP_GeoProjectSlow')
emit(0x0e33,0x0013,0x0037);branch('SVP_GeoProjectEstimate')
label('SVP_GeoProjectNear')
romtab('RomProj',129);emit(0x0023)
emit(0xe003,0x0638,0x9007,0x6800,16385);n0('SVP_GeoProjectSlow')
emit(0x0e33,0x0013,0x0037,0x9003)
label('SVP_GeoProjectEstimate')
emit(0x0e34,0x8800,1,0x0013,0x0632,0x0023,0x0037,0x9006)  # A=-2(qe+1)z
emit(0x1833,0x0210,0x0820,256,0x8007)  # +512a
branch('SVP_GeoProjectSign','n1');emit(0x0634,0x8800,1,0x0e34)
label('SVP_GeoProjectSign');emit(0xe003,0x0638,0x6800,0);branch('SVP_GeoProjectNegative','n1')
emit(0xe003,0x0634);ret()
label('SVP_GeoProjectNegative');emit(0xe003,0x0634,0x9006);ret()
label('SVP_GeoProjectSlow')
lines.append('        endif')
load(0x38);emit(0x0013,0x0820,128,0x0037);save32(0x30,0x31)
call('SVP_GeoDivide');ret()
# Signed32 / signed16 exact toward zero, quotient must fit signed16.
# The remainder comparison is unsigned (Genplus does not implement L/C).
label('SVP_GeoDivide')
# Same contract, unrolled restoring division: A=rem:low, ADD A,P (P=2) sets the
# quotient bit above the always-zero bit0 slot; bit0 of N is resolved last.
lines.append('        if def(M4_VR_DMA)')
restore(0x30,0x31);emit(0x9007);branch('SVP_GeoInvalid','n1')
emit(0x0e34,0x003f,0x0e35,0xa800,1,0x0e36)
emit(0xe003,0x0632,0x9007);branch('SVP_GeoInvalid','z1');emit(0x0e37)
branch('SVP_GeoDivFastSeed','n1')  # |D|=32768 always exceeds the high WORD
emit(0x0634,0x2637);n0('SVP_GeoInvalid')
label('SVP_GeoDivFastSeed')
emit(0xe003,0x0635,0xa800,0xfffe,0x00f3,0x0634,0x0810,1,0x0820,1)
for i in range(15):
 emit(0x9003,0x6637);branch(f'SVP_GeoDivFast{i}','n1');emit(0x2637,0x8007);label(f'SVP_GeoDivFast{i}')
emit(0x0e34,0x003f,0x0e35,0xe003,0x0634,0x9003,0x8636,0x6637);branch('SVP_GeoDivFastQuotient','n1')
emit(0x0635,0x8800,1,0x0e35)
label('SVP_GeoDivFastQuotient');emit(0xe003,0x0635,0x6800,0);n0('SVP_GeoDivFastSign')
emit(0x6800,32768);branch('SVP_GeoInvalid','z0')
emit(0xe003,0x0630,0xe632);n0('SVP_GeoInvalid')
label('SVP_GeoDivFastSign');emit(0xe003,0x0630,0xe632);branch('SVP_GeoDivFastNegative','n1')
emit(0xe003,0x0635);ret()
label('SVP_GeoDivFastNegative');emit(0xe003,0x0635,0x9006);ret()
lines.append('        else')
imm(0);store(0x33)
restore(0x30,0x31);emit(0x6800,0)
branch('SVP_GeoDivNumNegative','n1');branch('SVP_GeoDivDenominator')
label('SVP_GeoDivNumNegative');emit(0x9006);save32(0x30,0x31);imm(1);store(0x33)
label('SVP_GeoDivDenominator');load(0x32);emit(0x6800,0);branch('SVP_GeoInvalid','z1');branch('SVP_GeoDivDenNegative','n1');branch('SVP_GeoDivStart')
label('SVP_GeoDivDenNegative');emit(0x9006);store(0x32);load(0x33);emit(0xe800,1);store(0x33)
# A fitting WORD quotient needs only the lower16 numerator bits. Seed the
# remainder with its upper WORD; upper>=denominator would overflow unsigned16.
label('SVP_GeoDivStart');load(0x30);store(0x34);emit(0x6800,0);branch('SVP_GeoInvalid','n1')
load(0x32);emit(0x6800,0);branch('SVP_GeoDivSeedValid','n1')
load(0x34);emit(0x2632);branch('SVP_GeoDivSeedValid','n1');branch('SVP_GeoInvalid')
label('SVP_GeoDivSeedValid');imm(0);store(0x35);imm(16);store(0x36)
label('SVP_GeoDivBit')
imm(0);store(0x37);load(0x31);emit(0x6800,0);branch('SVP_GeoDivBitOne','n1');branch('SVP_GeoDivShift')
label('SVP_GeoDivBitOne');imm(1);store(0x37)
label('SVP_GeoDivShift');load(0x31);emit(0x9003);store(0x31)
load(0x35);emit(0x6800,0);branch('SVP_GeoInvalid','n1') # would overflow unsigned16 on next shift
load(0x35);emit(0x9003);store(0x35)
load(0x34);emit(0x9003,0x8637);store(0x34);emit(0x6800,0);branch('SVP_GeoDivSubtract','n1')
load(0x32);emit(0x6800,0);branch('SVP_GeoDivNext','n1')
load(0x34);emit(0x2632);branch('SVP_GeoDivNext','n1');branch('SVP_GeoDivStoreRemainder')
label('SVP_GeoDivSubtract');load(0x34);emit(0x2632)
label('SVP_GeoDivStoreRemainder');store(0x34);add(0x35,1)
label('SVP_GeoDivNext');load(0x36);emit(0x2800,1);store(0x36);branch('SVP_GeoDivBit','z0')
load(0x35);emit(0x6800,0);branch('SVP_GeoDivLarge','n1');branch('SVP_GeoDivSign')
label('SVP_GeoDivLarge');emit(0x6800,32768);branch('SVP_GeoInvalid','z0');load(0x33);emit(0x6800,0);branch('SVP_GeoInvalid','z1')
label('SVP_GeoDivSign');load(0x33);emit(0x6800,0);branch('SVP_GeoDivReturnPositive','z1');load(0x35);emit(0x9006);ret()
label('SVP_GeoDivReturnPositive');load(0x35);ret()
lines.append('        endif')

# Intro models keep ids0..17, level effects 18..22. Level shapes follow (tools/level-shapes.py).
GUARD=False # tables and model data below; other generators reusing emit() do not guard
LEVEL=runpy.run_path(str(ROOT/'tools/level-shapes.py'))
assert len(models)==LEVEL['FIRST_LEVEL_MODEL'],len(models)
models += [(n,m) for n,m in LEVEL['geometry_models'](rom)]
VISIBLE={'Ship','Laser','Boss','BossChild1','BossChild2','Debris','ZacoE388','ZacoC22C','MyDemo'}|{n for n,_ in LEVEL['geometry_models'](rom)}
lines.insert(1,f'SVP_GEO_MODEL_COUNT equ {len(models)}')
# Model table, vertices, visibility lists and frames live in SVP ROM data
# blocks (build/svp-geo-rom.inc, read with georom()): the 64K-word program
# window cannot hold the level shapes. Each block stays inside one 64K-word
# page (own guard); entry word 6 = $0800|page of that model's data, the other
# pointers are WORD addresses & $ffff inside that page (RAM slot $7F).
prog_lines=lines
def dcwords(ls): return sum(len(l.split(None,1)[1].split(',')) for l in ls if l.strip().startswith('dc.w'))
blocks=[]
lines=[];label('SVP_GeoModels')
# Share only byte-identical geometric inputs. Model ids and their material/
# BSP descriptors remain distinct. Repeated Arwing variants and boss parts
# need not duplicate the same vertices/visibility/animation in ROM.
canonical, unique = {}, {}
for n,m in models:
 key=repr((m['vertices'],m['visibility'],m.get('frames') if len(m.get('frames') or [])>1 else None))
 canonical[n]=unique.setdefault(key,n)
for n,m in models:
 data_name=canonical[n]
 frames=m.get('frames') if len(m.get('frames') or [])>1 else None
 emit(len(m['vertices']),len(m['visibility']) if n in VISIBLE else 0,'((SVP_Geo'+data_name+'Vertices/2)&$ffff)','((SVP_Geo'+data_name+'Visibility/2)&$ffff)',
      '((SVP_Geo'+data_name+'Frames/2)&$ffff)' if frames else 0,len(frames) if frames else 0,'$0800|((SVP_Geo'+data_name+'Vertices/2)>>16)',0)
for n,m in models:
 if canonical[n]!=n: continue
 assert len(m['vertices'])<=84,(n,len(m['vertices'])) # RAM B: index*3 < 253 (8-bit SSP pointers; B FD..FF is the SVP9 vertex scratch), SVP_GeoIndexOffsets covers 0..255
 assert 436+len(m['visibility'])<=512,(n,len(m['visibility'])) # object DRAM block, including visibility tail
 cur=lines;lines=[]
 label('SVP_Geo'+n+'Vertices')
 for v in m['vertices']:emit(*v)
 label('SVP_Geo'+n+'Visibility')
 for v in m['visibility']:emit(*[i*3 for i in v])
 frames=m.get('frames') if len(m.get('frames') or [])>1 else None
 if frames:
  shared_frames = {repr(m['vertices']): 'SVP_Geo'+n+'Vertices'}
  frame_names = [shared_frames.setdefault(repr(v), 'SVP_Geo'+n+'Frame'+str(i)) for i,v in enumerate(frames)]
  label('SVP_Geo'+n+'Frames');emit(*['(('+name+'/2)&$ffff)' for name in frame_names])
  for i,vertices in enumerate(frames):
   if frame_names[i] != 'SVP_Geo'+n+'Frame'+str(i): continue
   label('SVP_Geo'+n+'Frame'+str(i))
   for v in vertices:emit(*v)
 one=lines;lines=cur
 if dcwords(lines)+dcwords(one)>60000:blocks.append(lines);lines=[]
 lines+=one
blocks.append(lines);lines=prog_lines
out=['; Generated by tools/generate-intro-geometry.py: SVP geometry ROM data (models, vertices,',
     '; visibility, frames) in blocks of one 64K-WORD page each, read through PM4. Include outside the',
     '; SVP program window.']
for k,b in enumerate(blocks):
 w=dcwords(b);assert w<0x10000,(k,w)
 out+=['        even',f'        if ((*+{2*w}-1)>>17)<>(*>>17)','        dcb.b ((*+$1ffff)&$fe0000)-*,0','        endif',
       f'SVP_GeoRom{k}:']+b+[f'SVP_GeoRom{k}End:',f'        if ((SVP_GeoRom{k}End/2-1)>>16)<>((SVP_GeoRom{k}/2)>>16)',
       f'        inform 3,"SVP_GeoRom{k} crosses a 64K-word page"','        endif']
(ROOT/'build/svp-geo-rom.inc').write_text('\n'.join(out)+'\n',encoding='ascii')
label('SVP_GeoSine');data=(ROOT/'build/intro-matrix-sine.bin').read_bytes()
for p in range(0,len(data),16):emit(*[int.from_bytes(data[i:i+2],'big') for i in range(p,min(p+16,len(data)),2)])
(ROOT/'build/svp-intro-geometry.inc').write_text('\n'.join(lines)+'\n',encoding='ascii')
# Projection reciprocals M(z), z = 129..16383, in the SVP ROM data block.
_m=[(1<<(22 if z<=256 else 23))//z for z in range(129,16384)]
rd=['; Generated by tools/generate-intro-geometry.py: SVP projection table (read with PM4).','SVP_RomProj:']
for p in range(0,len(_m),16):rd.append('        dc.w '+','.join(f'${v:04x}' for v in _m[p:p+16]))
rd.append('SVP_RomProjEnd:')
(ROOT/'build/svp-rom-geometry.inc').write_text('\n'.join(rd)+'\n',encoding='ascii')
print('Generated own SVP9: native matrix, vertices, visibility and exact projection')
