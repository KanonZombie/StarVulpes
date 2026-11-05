"""Own SVP10: original ordered face packets, clipping and triangle/line setup.

Consumes SVP9 geometry, not CPU-transformed/projected coordinates. Uses the
same signed division and clipping contract as the retained68000 reference.
"""
import runpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
g=runpy.run_path(str(ROOT/'tools/generate-intro-geometry.py'))
# These emitters share their original module globals; take their actual list.
ctx=g['emit'].__globals__;lines=ctx['lines'];lines.clear();ctx['GUARD']=True # Genplus idle-loop guard (generate-intro-geometry.py)
romtab=g['romtab']
emit,label,load,store,imm,branch,call,ret,add,readrom,readb,writeb,pm,product,save32,restore=[ctx[n] for n in
 ['emit','label','load','store','imm','branch','call','ret','add','readrom','readb','writeb','pm','product','save32','restore']]
def reada(index,base=0):load(index);emit(0x8800,base,0x1430,0xe003,0x0230)
def clip(axis,boundary,side):
 imm(axis);store(0xb);imm(boundary);store(0xc);imm(side);store(0xd);call('SVP_FaceNearClip' if axis == 2 else 'SVP_FaceClip')
 load(8);emit(0x6800,0);branch('SVP_FaceNext','z1')

def setpoint(ptr,cache):
 for axis in range(3):readb(ptr,axis);store(cache+axis)

label('SVP_Faces')
emit(0x0032);store(0)
emit(0x08e0,10,0x08e0,0x0018,0x000c,0xe003,0x003c);store(2);store(3)
emit(0x6800,0);branch('SVP_GeoInvalid','n1');emit(0x6800,513);branch('SVP_FaceCountValid','n1');branch('SVP_GeoInvalid')
label('SVP_FaceCountValid');emit(0x08e0,13,0x08e0,0x0018,0x000c,0xe003,0x003c);store(0x1f0);emit(0x08e0,14,0x08e0,0x0018,0x000c,0xe003,0x003c);store(0x1f1)
imm('((M4_FACE_INPUT-$300000)/2)');store(1);imm('((M4_POLY_INPUT-$300000)/2)');store(5);imm(0);store(6)
load(2);emit(0x6800,0);branch('SVP_FacesDone','z1')
label('SVP_Face')
pm(1)
for s in range(0x60,0x70):emit(0xe003,0x003c);store(s)
add(1,16)
load(0x63);emit(0x6800,9);branch('SVP_FaceParticle','z1')
# Special packets carry bit 15 in the kind word: level model kinds (23 + shape
# index) reach 30..34 and must not be taken for them.
load(0x63);emit(0x6800,0x801e);branch('SVP_FaceSprite','z1')
# Radio box (generate-level-radio.py): kinds 31..33 -> cmd8 types 6..8, six words.
for kind in (31,32,33):load(0x63);emit(0x6800,0x8000|kind);branch('SVP_FaceRadio','z1')
# Kind 34: one raw cmd8 record (8 words verbatim; route map planets, types 9/10).
load(0x63);emit(0x6800,0x8022);branch('SVP_FaceRaw','z1')
load(0x60);store(8);emit(0x6800,2);branch('SVP_GeoInvalid','n1');emit(0x6800,9);branch('SVP_FaceNValid','n1');branch('SVP_GeoInvalid')
label('SVP_FaceNValid')
# Colour bit 15: textured material (index of SVP_TexMaterials, 0x8a = index + 1);
# the plain colour checks below then see colour 1.
imm(0);store(0x8a);load(0x61);emit(0x6800,0);emit(0x4c70,'SVP_FaceColourPlain/2')
emit(0xa800,0x7fff,0x8800,1);store(0x8a);imm(1);store(0x61)
label('SVP_FaceColourPlain');load(0x61);store(9);emit(0x6800,1);branch('SVP_GeoInvalid','n1')
# VR: original dither colour byte HL (1..255); legacy keeps MD indices1..15.
lines.append('        if def(M4_VR_DMA)');emit(0x6800,256);lines.append('        else');emit(0x6800,16);lines.append('        endif')
branch('SVP_FaceColourValid','n1');branch('SVP_GeoInvalid')
label('SVP_FaceColourValid')
imm(0);store(0xe);imm(48);store(0xf);store(0x47);store(0x48);store(0x49)
# Correct zero displacement (store48 above is only the clip buffer pointer).
imm(0);store(0x47);store(0x48);store(0x49)
imm(1);store(0x4a);store(0x4c)
load(0x63);emit(0x6800,2);branch('SVP_FaceExplosion','z1');emit(0x6800,10);branch('SVP_FaceNormalReady','z0')
label('SVP_FaceExplosion')
load(0x64);emit(0x6800,0);branch('SVP_FaceNormalReady','z1')
imm(0);store(0x4c)
load(0x62);store(7);pm(7)
for s in range(0x20,0x29):emit(0xe003,0x003c);store(s)
load(0x65);emit(0x9006);store(0x70);load(0x66);store(0x71);load(0x67);emit(0x9006);store(0x72)
for axis in range(3):
 product(0x70,0x20+axis);save32(0x52,0x53)
 for j in [1,2]:
  load(0x70+j);emit(0x0013);load(0x20+axis+j*3);emit(0x0023)
  restore(0x52,0x53);emit(0x8007);save32(0x52,0x53)
 load(0x52)
 if axis==1:
  emit(0x6800,0);branch('SVP_FaceNormalYNegative','n1');emit(0x9006)
  label('SVP_FaceNormalYNegative')
 emit(0x0013);load(0x64);emit(0x0023,0x0037,0x9002,0x9002,0x9002,0x003f);store(0x47+axis)
label('SVP_FaceNormalReady')
# VR-style streaming: r0 walks the index list, r4/r5 post-increment into the
# camera-space cache (B0..) and the SVP9 projection cache (B144..). Same words,
# same behind flag; the screen stage then reads B144 directly (no copy).
lines.append('        if def(M4_VR_DMA)')
emit(0x1868,0x1c00,0x1d90);load(8);store(0x4d)
label('SVP_FaceReadPointFast')
emit(0xe003,0x0234,0x8800,'SVP_GeoIndexOffsets/2',0x4a30,0x8662,0x8800,16,0x00e3,0x08e0,0x0818,0x000c)
for axis in range(3):emit(0xe003,0x003c,0x8600+0x47+axis,0x0534)
# |camera x,y| <=16384: z>=513 bounds projected coordinates below 8192.
# Reuse the old depth comparison/branch; normal vertices pay no extra words
# or cycles. Only the close branch reads/checks the projection cache.
store(0x72);emit(0x6800,513);branch('SVP_FacePointBehindFast','n1');branch('SVP_FaceCachePointFast')
label('SVP_FacePointBehindFast');call('SVP_FaceCacheGuard');branch('SVP_FaceCachePointDone')
label('SVP_FaceCachePointFast')
for axis in range(2):emit(0xe003,0x003c,0x0535)
label('SVP_FaceCachePointDone');load(0x72);emit(0x0535)
load(0x4d);emit(0x2800,1);store(0x4d);branch('SVP_FaceReadPointFast','z0')
load(0x8a);emit(0x6800,0);branch('SVP_FaceTextured','z0')
load(0x4a);emit(0xa64c);branch('SVP_FaceNeedsNearClip','z1')
imm(144);store(0xe);branch('SVP_FaceScreenBounds')
lines.append('        endif')
imm(0);store(0x4d);store(0x4e);imm(144);store(0x4f)
label('SVP_FaceReadPoint')
reada(0x4d,0x68);emit(0x8800,'SVP_GeoIndexOffsets/2');readrom();emit(0x8662,0x8800,16);store(7);pm(7)
for axis in range(3):
 emit(0xe003,0x003c,0x8600+0x47+axis);store(0x70+axis);writeb(0x4e,0x70+axis,axis)
load(0x72);emit(0x6800,32)
branch('SVP_FacePointBehind','n1');branch('SVP_FaceCachePoint')
label('SVP_FacePointBehind');imm(0);store(0x4a)
label('SVP_FaceCachePoint')
for axis in range(2):emit(0xe003,0x003c);store(0x70+axis);writeb(0x4f,0x70+axis,axis)
writeb(0x4f,0x72,2)
add(0x4e,3);add(0x4f,3);add(0x4d,1);load(0x4d);emit(0x2608);branch('SVP_FaceReadPoint','z0')
load(0x4a);emit(0xa64c);branch('SVP_FaceNeedsNearClip','z1')
# All vertices were projected once in SVP9; reuse those coordinates.
imm(144);store(0x4f);imm(0);store(0x4e);load(8);store(0x4d)
label('SVP_FaceUseProjection')
for axis in range(3):readb(0x4f,axis);store(0x70);writeb(0x4e,0x70,axis)
add(0x4f,3);add(0x4e,3);load(0x4d);emit(0x2800,1);store(0x4d);branch('SVP_FaceUseProjection','z0')
branch('SVP_FaceScreenBounds')
label('SVP_FaceNeedsNearClip')
clip(2,32,1)
load(0xe);store(0x4e);load(8);store(0x4d)
label('SVP_FaceProjectPoint')
readb(0x4e,2);store(0x32)
for axis,centre in [(0,128),(1,112)]:
 readb(0x4e,axis);store(0x38);call('SVP_GeoProject');emit(0x8800,centre,0x8600+0x1f0+axis);store(0x70);writeb(0x4e,0x70,axis)
add(0x4e,3);load(0x4d);emit(0x2800,1);store(0x4d);branch('SVP_FaceProjectPoint','z0')
label('SVP_FaceScreenBounds')
imm(0);store(0x82);imm(15);store(0x83);load(0xe);store(0x4e);load(8);store(0x4d)
label('SVP_FaceOutcode')
imm(0);store(0x80)
for axis,boundary,low,high in [(0,256,1,2),(1,224,4,8)]:
 readb(0x4e,axis);emit(0x6800,0);branch('SVP_FaceOutLow'+str(axis),'n1')
 emit(0x6800,boundary);branch('SVP_FaceOutDone'+str(axis),'n1')
 load(0x80);emit(0xc800,high);store(0x80);branch('SVP_FaceOutDone'+str(axis))
 label('SVP_FaceOutLow'+str(axis));load(0x80);emit(0xc800,low);store(0x80)
 label('SVP_FaceOutDone'+str(axis))
load(0x82);emit(0xc680);store(0x82);load(0x83);emit(0xa680);store(0x83)
add(0x4e,3);load(0x4d);emit(0x2800,1);store(0x4d);branch('SVP_FaceOutcode','z0')
load(0x83);emit(0x6800,0);branch('SVP_FaceNext','z0')
load(0x82);emit(0x6800,0);branch('SVP_FaceClipped','z1')
for axis,boundary,side in [(0,0,1),(0,255,0),(1,0,1),(1,223,0)]:clip(axis,boundary,side)
label('SVP_FaceClipped');load(8);emit(0x6800,2);branch('SVP_FaceNext','n1')
load(0x60);emit(0x6800,2);branch('SVP_FaceLine','z1')
load(8);emit(0x6800,3);branch('SVP_FaceNext','n1')
imm(1);store(0x4d)
label('SVP_FaceTriangle')
readb(0xe);store(0x70);readb(0xe,1);store(0x71)
load(0x4d);store(0x4e);emit(0x9003,0x864e,0x860e);store(0x4e)
for axis in range(2):readb(0x4e,axis);store(0x72+axis);readb(0x4e,3+axis);store(0x74+axis)
load(0x72);emit(0x2670);store(0x7a);load(0x75);emit(0x2671);store(0x7b);product(0x7a,0x7b);save32(0x52,0x53)
load(0x73);emit(0x2671,0x0013);load(0x74);emit(0x2670,0x0023);restore(0x52,0x53);emit(0x2007,0x6800,0)
branch('SVP_FaceTriangleNext','z1');branch('SVP_FaceTriangleReverse','n1');branch('SVP_FaceTriangleEmit')
label('SVP_FaceTriangleReverse')
for a,b in [(0x72,0x74),(0x73,0x75)]:load(a);store(0x80);load(b);store(a);load(0x80);store(b)
label('SVP_FaceTriangleEmit');imm(3);store(0x81);call('SVP_FaceEmit')
label('SVP_FaceTriangleNext');add(0x4d,1);load(8);emit(0x2800,1,0x264d);branch('SVP_FaceTriangle','z0');branch('SVP_FaceNext')
label('SVP_FaceLine')
readb(0xe);store(0x70);readb(0xe,1);store(0x71)
load(0xe);emit(0x8800,3);store(0x4e);load(8);emit(0x2800,1);store(0x4d)
label('SVP_FaceLinePoint')
readb(0x4e);store(0x72);emit(0x2670);branch('SVP_FaceLineEmit','z0');readb(0x4e,1);store(0x73);emit(0x2671);branch('SVP_FaceLineEmit','z0')
add(0x4e,3);load(0x4d);emit(0x2800,1);store(0x4d);branch('SVP_FaceLinePoint','z0');branch('SVP_FaceNext')
label('SVP_FaceLineEmit');readb(0x4e,1);store(0x73);imm(0);store(0x74);store(0x75);imm(2);store(0x81);call('SVP_FaceEmit')
branch('SVP_FaceNext')
# Textured face (textured-polygons.md 1, 01:8E3B): a point near/behind the
# camera -> not drawn (01:8E47); n must be 3..4 (u,v pairs of texturexytab);
# the whole face needs 1 + ceil(n/2) records. Header: 11, n, TB, mask, scroll
# x/y (0), near 0, 0; then pairs (x-16, y-16, u_k, v_k) in face order.
label('SVP_FaceTextured')
load(0x4a);emit(0xa64c);branch('SVP_FaceNext','z1')
imm(144);store(0xe)
load(8);emit(0x6800,3);branch('SVP_FaceNext','n1');emit(0x6800,5);branch('SVP_FaceTexN','n1');branch('SVP_FaceNext')
label('SVP_FaceTexN')
load(8);emit(0x8800,1,0x9002,0x8606,0x6800,256);branch('SVP_FaceTexRoom','n1');branch('SVP_FaceNext')
label('SVP_FaceTexRoom')
load(0x8a);emit(0x2800,1);store(0x8b);emit(0x9003,0x9003,0x9003);store(0x8c)
load(0x8b);emit(0x9003,0x868c,0x868b);store(0x8c)      # material index * 11
imm(11);store(0x81);load(8);store(0x70)
load(0x8c);emit(0x8800,1);romtab('TexMaterials');store(0x71)
load(0x8c);emit(0x8800,2);romtab('TexMaterials');store(0x72)
imm(0);store(0x73);store(0x74);store(0x75);store(9)
call('SVP_FaceEmit')
imm(0);store(0x8d);load(0xe);store(0x4e)
label('SVP_FaceTexPair')
for half, (sx, sy, su, sv) in enumerate([(0x81, 0x70, 0x71, 0x72), (0x73, 0x74, 0x75, 9)]):
    load(0x8d);emit(0x2608,0x4c70,f'SVP_FaceTexZero{half}/2')
    readb(0x4e,0);emit(0x2800,16);store(sx);readb(0x4e,1);emit(0x2800,16);store(sy)
    load(0x8d);emit(0x9003,0x868c,0x8800,3);romtab('TexMaterials');store(su)
    load(0x8d);emit(0x9003,0x868c,0x8800,4);romtab('TexMaterials');store(sv)
    add(0x4e,3);add(0x8d,1);branch(f'SVP_FaceTexNext{half}')
    label(f'SVP_FaceTexZero{half}');imm(0);store(sx);store(sy);store(su);store(sv)
    label(f'SVP_FaceTexNext{half}')
call('SVP_FaceEmit')
load(0x8d);emit(0x2608);branch('SVP_FaceTexPair','n1')
branch('SVP_FaceNext')
label('SVP_FaceRadio');load(0x63);emit(0xa800,0x7fff,0x2800,25);store(0x81);branch('SVP_FaceCopy6')
label('SVP_FaceRaw')
for i,slot in enumerate([0x81,0x70,0x71,0x72,0x73,0x74,0x75,9]):load(0x64+i);store(slot)
call('SVP_FaceEmit');branch('SVP_FaceNext')
label('SVP_FaceSprite');imm(5);store(0x81)
label('SVP_FaceCopy6')
for i in range(6):load(0x64+i);store(0x70+i)
imm(0);store(9);call('SVP_FaceEmit');branch('SVP_FaceNext')
label('SVP_FaceParticle');imm(4);store(0x81);load(0x62);emit(0x8800,16);store(0x70)
load(0x65);store(0x71);load(0x64);store(0x72);imm(0);store(0x73);store(0x74);store(0x75);store(9)
call('SVP_FaceEmit')
label('SVP_FaceNext');load(2);emit(0x2800,1);store(2);branch('SVP_Face','z0')
label('SVP_FacesDone')
emit(0x08e0,10,0x08e0,0x0018,0x00c0);load(6);emit(0x00c3)
load(0);emit(0x0023);load(3);branch('SVP_PublishResult')
# Output full (256 polygons = M4_POLY_INPUT): drop the rest of the image's
# polygons instead of invalidating the image (the 68000 counts count == 256).
label('SVP_FaceEmit');load(6);emit(0x6800,256);branch('SVP_FaceEmitValid','n1');ret()
label('SVP_FaceEmitValid');pm(5,True)
for slot in [0x81,*range(0x70,0x76),9]:load(slot);emit(0x00c3)
add(5,8);add(6,1);ret()

# Sutherland-Hodgman with WORD distances and exact signed32/WORD division.
# Buffers bankB0..47 and48..95, at most16 vertices. Swap ownership on return.
label('SVP_FaceClip')
load(8);emit(0x6800,0);branch('SVP_FaceClipEmpty','z1');store(0x76)
load(0xe);store(0x77);load(0xf);store(0x79);imm(0);store(0x78)
load(8);emit(0x2800,1);store(0x80);emit(0x9003,0x8680,0x860e);store(0x4e)
setpoint(0x4e,0x70)
label('SVP_FaceClipVertex');setpoint(0x77,0x73)
for base,distance in [(0x70,0x7a),(0x73,0x7b)]:
 reada(0xb,base);emit(0x260c);store(distance)
 load(0xd);emit(0x6800,0);branch('SVP_FaceClipDistDone'+str(base),'z0')
 load(distance);emit(0x9006);store(distance)
 label('SVP_FaceClipDistDone'+str(base))
load(0x7a);emit(0xe67b,0xa800,32768);branch('SVP_FaceClipCurrent','z1')
load(0x7a);emit(0x267b);store(0x7d)
for axis in range(3):
 load(0x73+axis);emit(0x2600+0x70+axis,0x0013);load(0x7a);emit(0x0023,0x0037,0x9002);save32(0x30,0x31)
 load(0x7d);store(0x32);call('SVP_GeoDivide');emit(0x8600+0x70+axis);store(0x80+axis)
# Plane coordinate is forced to its exact boundary after interpolation.
load(0xb);emit(0x8800,0x80,0x1430);load(0xc);emit(0x0430)
call('SVP_FaceClipAppend')
label('SVP_FaceClipCurrent');load(0x7b);emit(0x6800,0);branch('SVP_FaceClipContinue','n1')
for axis in range(3):load(0x73+axis);store(0x80+axis)
call('SVP_FaceClipAppend')
label('SVP_FaceClipContinue')
for axis in range(3):load(0x73+axis);store(0x70+axis)
add(0x77,3);load(0x76);emit(0x2800,1);store(0x76);branch('SVP_FaceClipVertex','z0')
load(0x78);store(8);load(0xe);store(0x80);load(0xf);store(0xe);load(0x80);store(0xf)
label('SVP_FaceClipEmpty');ret()
label('SVP_FaceClipAppend');load(0x78);emit(0x6800,16);branch('SVP_FaceClipAppendValid','n1');branch('SVP_GeoInvalid')
label('SVP_FaceClipAppendValid')
for axis in range(3):writeb(0x79,0x80+axis,axis)
add(0x79,3);add(0x78,1);ret()
guard_start=len(lines)
# Unsafe projection-cache entries request camera-space clipping, rather than
# overflowing a signed screen WORD during SVP9. The placeholder is never used
# as geometry: FaceCacheGuard routes the original xyz through NearClip.
label('SVP_GeoProjectCache')
load(0x32);emit(*([0x9003]*5));store(0x33)
load(0x38);emit(0x9007,0x2633);branch('SVP_GeoCacheExact','n1')
imm(0x7000);ret()
label('SVP_GeoCacheExact');branch('SVP_GeoProject')
label('SVP_FaceCacheGuard')
load(0x72);emit(0x6800,32);emit(0x4c70,'SVP_FaceCacheInFront/2')
imm(0);store(0x4a)
label('SVP_FaceCacheInFront')
for axis in range(2):
 emit(0xe003,0x003c,0x0535,0x9007,0x6800,8192)
 branch('SVP_FaceCacheSafe'+str(axis),'n1');imm(0);store(0x4a)
 label('SVP_FaceCacheSafe'+str(axis))
ret()
# Guard-band clipping in camera space. Only the exceptional near path whose
# projection would exceed +/-8192 enters this routine. The planes +/-x<=z,
# +/-y<=z enclose the viewport; they do not cut visible geometry. Integer
# intersections retain the existing toward-zero camera-coordinate contract.
label('SVP_FaceNearClip');call('SVP_FaceClip')
load(8);emit(0x6800,0);branch('SVP_GuardReturn','z1');store(0x84);load(0xe);store(0x83)
label('SVP_GuardScan')
readb(0x83,2);emit(0x6800,513);emit(0x4c70,'SVP_GuardScanNext/2')
emit(*([0x9003]*5));store(0x82)
for axis in range(2):
 readb(0x83,axis);emit(0x9007,0x2682);emit(0x4c70,'SVP_GuardStart/2')
label('SVP_GuardScanNext');add(0x83,3);load(0x84);emit(0x2800,1);store(0x84);branch('SVP_GuardScan','z0')
label('SVP_GuardReturn');ret()
label('SVP_GuardStart')
for axis in range(2):
 for side in range(2):
  imm(axis);store(0x85);imm(side);store(0x86);call('SVP_GuardPlane')
  load(8);emit(0x6800,0);branch('SVP_GuardReturn','z1')
ret()
label('SVP_GuardPlane')
load(8);store(0x76);load(0xe);store(0x77);load(0xf);store(0x79);imm(0);store(0x78)
load(8);emit(0x2800,1);store(0x80);emit(0x9003,0x8680,0x860e);store(0x4e);setpoint(0x4e,0x70)
label('SVP_GuardVertex');setpoint(0x77,0x73)
for base,dist in ((0x70,0x7a),(0x73,0x7b)):
 reada(0x85,base);store(dist);load(0x86);emit(0x6800,0);branch('SVP_GuardLow'+str(base),'z1')
 load(dist);emit(0x9006);store(dist)
 label('SVP_GuardLow'+str(base));load(base+2);emit(0x8600+dist);store(dist)
load(0x7a);emit(0xe67b,0xa800,32768);branch('SVP_GuardCurrent','z1')
load(0x7a);emit(0x9007);store(0x7c);load(0x7b);emit(0x9007,0x867c);store(0x7d)
for axis in range(3):
 load(0x73+axis);emit(0x2600+0x70+axis,0x0013);load(0x7c);emit(0x0023,0x0037,0x9002);save32(0x30,0x31)
 load(0x7d);store(0x32);call('SVP_GuardDivide');emit(0x8600+0x70+axis);store(0x80+axis)
load(0x82);store(0x87);load(0x86);emit(0x6800,0);branch('SVP_GuardBoundary','z0');load(0x87);emit(0x9006);store(0x87)
label('SVP_GuardBoundary');load(0x85);emit(0x8800,0x80,0x1430);load(0x87);emit(0x0430)
call('SVP_FaceClipAppend')
label('SVP_GuardCurrent');load(0x7b);emit(0x6800,0);branch('SVP_GuardNext','n1')
for axis in range(3):load(0x73+axis);store(0x80+axis)
call('SVP_FaceClipAppend')
label('SVP_GuardNext')
for axis in range(3):load(0x73+axis);store(0x70+axis)
add(0x77,3);load(0x76);emit(0x2800,1);store(0x76);branch('SVP_GuardVertex','z0')
load(0x78);store(8);load(0xe);store(0x80);load(0xf);store(0xe);load(0x80);store(0xf);ret()
# signed32 / unsigned16, |quotient| <=32767. Unlike GeoDivide the denominator
# may be 32768..65535 (opposite signed plane distances). Restoring division
# keeps the seventeenth remainder bit explicitly; no unsigned flag required.
label('SVP_GuardDivide');restore(0x30,0x31);emit(0x9007);save32(0x34,0x35);imm(16);store(0x36)
label('SVP_GuardDivBit');load(0x35);emit(0x9002);emit(*([0x9002]*14));emit(0xa800,1);store(0x37)
load(0x35);emit(0x9003);store(0x35)
load(0x34);emit(0x6800,0);branch('SVP_GuardDivCarry','n1');emit(0x9003,0x8637);store(0x34)
# Unsigned compare: unequal high bits decide; equal high bits allow SUB/N.
load(0x34);emit(0xe632);branch('SVP_GuardDivUnlike','n1')
load(0x34);emit(0x2632);branch('SVP_GuardDivNext','n1');branch('SVP_GuardDivSubtract')
label('SVP_GuardDivUnlike')
# R has bit15 iff R>=D when their high bits differ.
load(0x34);emit(0x6800,0);branch('SVP_GuardDivTake','n1');branch('SVP_GuardDivNext')
label('SVP_GuardDivCarry');load(0x34);emit(0x9003,0x8637);store(0x34)
label('SVP_GuardDivTake');load(0x34);emit(0x2632)
label('SVP_GuardDivSubtract');store(0x34);add(0x35,1)
label('SVP_GuardDivNext');load(0x36);emit(0x2800,1);store(0x36);branch('SVP_GuardDivBit','z0')
load(0x30);emit(0x6800,0);branch('SVP_GuardDivNegative','n1');load(0x35);ret()
label('SVP_GuardDivNegative');load(0x35);emit(0x9006);ret()
(ROOT/'build/svp-guard-clip.inc').write_text('\n'.join(lines[guard_start:])+'\n',encoding='ascii')
del lines[guard_start:]
ctx['GUARD']=False # data table
label('SVP_GeoIndexOffsets')
for start in range(0,256,16):emit(*[(i//3)*5 if i%3==0 else 0 for i in range(start,start+16)]) # vertex index*3 -> DRAM record offset (85 vertices max)
(ROOT/'build/svp-intro-faces.inc').write_text('\n'.join(lines)+'\n',encoding='ascii')
print('Generated own SVP10: face displacement, near/screen clipping, projection and ordered primitives')
