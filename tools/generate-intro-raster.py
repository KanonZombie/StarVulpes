"""Own SVP cmd8: clipped triangles/lines in the intro's MD tile framebuffer.

Input30C000: eight WORDs(type2/3,x0,y0,x1,y1,x2,y2,colour1..15), count
MAILBOX+20 <=256; +22=0 clear or1 append. Host supplies original BSP order.
SVP performs signed32 edge setup, exact span division, line stepping and all
pixel writes. Normal bitmap304000..309FFF, checksum+16, fresh result/echo/ACK.
Original projected coordinates remain in256x224; the backend retains y16..207
without changing edges/line stepping, and stores y-16 in a256x192 bitmap.
The exact span solver is reused from our tested M3 generator (own code).
"""
from pathlib import Path
import hashlib
import json
import runpy

ROOT = Path(__file__).resolve().parents[1]
lines = ['; Own SVP cmd8; input coordinates256x224, configurable retained view tile-major.']


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
    if hi==0x00: return op not in (0,0x37) and (op&0x0f)==12
    if hi in (0x02,0x0a): return ((op>>4)&0x0f)==12
    if (hi&0x0f)==0 and (hi&0x70) in (0x10,0x30,0x40,0x50,0x60,0x70): return (op&0x0f)==12
    return False


def _guard_segments(v):
    segs,cur,i=[],[],0
    while i<len(v):
        op=v[i]; n=2 if isinstance(op,int) and _two_words(op) else 1
        if isinstance(op,int) and _reads_pm4(op):
            if cur: segs.append(cur); cur=[]
            segs.append(None)
        cur+=list(v[i:i+n]); i+=n
    segs.append(cur)
    return segs


_GUARD_IF='        if (*=$%04x)|(*=$%04x)'%HAZARD_PCS
GUARD=True


def emit(*words):
    for seg in (_guard_segments(words) if GUARD else [words]):
        if seg is None:
            lines.extend([_GUARD_IF, '        dc.w 0', '        endif'])
        elif seg:
            lines.append('        dc.w '+','.join(f'${w & 65535:04x}' if isinstance(w,int) else w for w in seg))


def label(name): lines.append(name+':')
def load(slot): emit(0xe003,0x0600+slot)
def store(slot): emit(0x0e00+slot)
def immediate(value): emit(0xe003,0x0830,value)
def branch(name, condition='always'):
    emit({'always':0x4c00,'z1':0x4d50,'z0':0x4c50,'n1':0x4d70}[condition],name+'/2')


def restore(hi, lo):
    load(lo); emit(0x00f3,0x0600+hi)


def edge_add(hi, lo, slope):
    load(slope); emit(0x0013,0x0820,1)
    restore(hi,lo); emit(0x8007); store(hi); emit(0x003f); store(lo)


def span(edge):
    # Exact inclusive E>=0 coverage, doubled signed32 edges. Same M3 solver.
    prefix='SVP_IntroSpan'+str(edge)
    def jump(suffix,condition='always'): branch(prefix+suffix,condition)
    load(0x24+edge); emit(0x6800,0); jump('Flat','z1'); jump('Negative','n1')
    store(0x53)
    restore(0x2a+edge*2,0x2b+edge*2); emit(0x6800,0)
    jump('Target','n1'); jump('Done')
    label(prefix+'Target'); emit(0x9006); jump('Divide')
    label(prefix+'Negative'); emit(0x9006); store(0x53)
    restore(0x2a+edge*2,0x2b+edge*2); emit(0x6800,0)
    branch('SVP_IntroEndRow','n1')
    store(0x54); emit(0x003f); store(0x55)
    emit(0x0810,1,0x0820,1)
    restore(0x54,0x55); emit(0x8007)
    label(prefix+'Divide'); store(0x54); emit(0x003f); store(0x55)
    load(0x53); emit(0x0013)
    load(0x50); emit(0x0023)
    restore(0x54,0x55); emit(0x2007)
    jump('InRange','n1'); jump('InRange','z1')
    load(0x24+edge); emit(0x6800,0); jump('Done','n1'); branch('SVP_IntroEndRow')
    label(prefix+'InRange'); load(0x53); emit(0x6800,1); jump('Unit','z1')
    emit(0x0810,1,0x0820,1)
    restore(0x54,0x55); emit(0x2007,0x9002); store(0x56); emit(0x003f); store(0x57)
    load(0x53); emit(0x8800,'SVP_IntroReciprocals/2',0x4a20)
    load(0x56); emit(0x0013,0x0037,0x9002,0x003f); store(0x58)
    load(0x57); emit(0x9002,0xa800,0x7fff,0x0013,0x0037,0x8658,0x9003); store(0x59)
    label(prefix+'Correct'); load(0x59); emit(0x8800,1,0x0013)
    load(0x53); emit(0x0023)
    restore(0x54,0x55); emit(0x2007)
    jump('Quotient','n1'); jump('Quotient','z1')
    load(0x59); emit(0x8800,1); store(0x59); jump('Correct')
    label(prefix+'Quotient'); load(0x59); emit(0x8800,1); jump('Cut')
    label(prefix+'Unit'); restore(0x54,0x55); emit(0x9002,0x003f)
    label(prefix+'Cut'); store(0x59)
    load(0x24+edge); emit(0x6800,0); jump('Upper','n1')
    load(0x59); emit(0x2651); jump('Done','n1')
    load(0x59); store(0x51); jump('Done')
    label(prefix+'Upper'); load(0x59); emit(0x2652); jump('SetUpper','n1'); jump('Done')
    label(prefix+'SetUpper'); load(0x59); store(0x52); jump('Done')
    label(prefix+'Flat'); restore(0x2a+edge*2,0x2b+edge*2); emit(0x6800,0)
    branch('SVP_IntroEndRow','n1')
    label(prefix+'Done')


def walking_span(edge):
    # E is kept at a clamped boundary q, rather than at bbox xmin.
    # E(q,y+1)=E(q,y)+2*dx; E(q+1,y)=E(q,y)+2*dy.
    # Integer comparisons keep the old inclusive E>=0 coverage exactly.
    prefix='SVP_IntroWalk'+str(edge)
    q=0x90+edge;hi=0x2a+edge*2;lo=hi+1;slope=0x24+edge
    def jump(suffix,c='always'):branch(prefix+suffix,c)
    load(slope);emit(0x6800,0);jump('Flat','z1');jump('Upper','n1')
    for upper in (False,True):
        side='Upper' if upper else 'Lower'
        label(prefix+side)
        label(prefix+side+'Right')
        load(q);emit(0x2650);jump(side+'Left','z1')
        restore(hi,lo);emit(0x6800,0)
        if upper:jump(side+'Left','n1')
        else:
            jump(side+'MoveRight','n1');jump(side+'Left')
        label(prefix+side+'MoveRight')
        edge_add(hi,lo,slope)
        load(q);emit(0x8800,1);store(q);jump(side+'Right')
        label(prefix+side+'Left')
        load(q);emit(0x6800,0);jump(side+'Cut','z1')
        load(slope);emit(0x0013,0x0820,1)
        restore(hi,lo);emit(0x2007,0x6800,0)
        if upper:
            jump(side+'MoveLeft','n1');jump(side+'Cut')
        else:jump(side+'Cut','n1')
        label(prefix+side+'MoveLeft')
        store(hi);emit(0x003f);store(lo)
        load(q);emit(0x2800,1);store(q);jump(side+'Left')
        label(prefix+side+'Cut')
        load(q);emit(0x2600+(0x52 if upper else 0x51))
        jump(side+'Set','n1' if upper else 'z1')
        if not upper:
            jump('Done','n1')
            label(prefix+side+'Set');load(q);store(0x51)
        else:
            jump('Done');label(prefix+side+'Set');load(q);store(0x52)
        jump('Done')
    label(prefix+'Flat');restore(hi,lo);emit(0x6800,0)
    branch('SVP_IntroEndRow','n1')
    label(prefix+'Done')


def row_address():
    load(7); emit(0x2800,'M4_RENDER_TOP'); store(0x17)
    lines.append('        if def(M4_VR_DMA)')
    emit(0xa800,0xf0)
    lines.append('        else')
    emit(0xa800,0xf8)
    lines.append('        endif')
    for _ in range(6): emit(0x9003)
    store(0x10);load(0x17)
    lines.append('        if def(M4_VR_DMA)')
    emit(0xa800,15)
    lines.append('        else')
    emit(0xa800,7)
    lines.append('        endif')
    emit(0x9003,0x8610);fb['add_base'](globals());store(0x10)

def pixel_address(mode=0x0418):
    load(6); emit(0xa800,0xf8,0x9003)
    lines.append('        if def(M4_VR_DMA)')
    emit(0x9003)
    lines.append('        endif')
    emit(0x8610);store(0x11)
    load(6); emit(0xa800,4,0x9002,0x9002,0x8611,0x00e3,0x08e0,mode,0x00c0)

# VR-method triangle path (Virtua Racing 1EB7: per-row edge stepping, recip[dy]
# table, computed jump into unrolled PM4 writes). Exactness is kept: integer
# DDA with remainder, left=ceil/right=floor of the spanning edges, identical to
# the inclusive E>=0 rule for D>0 triangles (SVP10 emits only those). D<=0
# input keeps the previous walking solver (SVP_IntroTriangleSlow).
XT, YT, XM, YM, XB, YB = range(0xa0, 0xa6)
LONG, SH = 0xa8, 0xb0  # records: X, R'(-dy..-1), sq, sr, dy
TY, YEND, SIDE, CBL, CBR = 0xc0, 0xc1, 0xc2, 0xc4, 0xc5
DA, DDY, DQ, DR, DX, T1, T2, PH2, TGT = 0xc8, 0xc9, 0xca, 0xcb, 0xcc, 0xcd, 0xce, 0xcf, 0xd0
_uid = [0]


def uid(p):
    _uid[0] += 1
    return f'SVP_Tri{p}{_uid[0]}'


def br(name, c='always'):
    emit({'always':0x4c00,'z1':0x4d50,'z0':0x4c50,'n1':0x4d70,'n0':0x4c70}[c], name+'/2')


def clr(): emit(0xe003)
def lda(s): emit(0x0600+s)
def addm(s): emit(0x8600+s)
def subm(s): emit(0x2600+s)
def addi(v): emit(0x8800,v)
def subi(v): emit(0x2800,v)
def cmpi(v): emit(0x6800,v)
def andi(v): emit(0xa800,v)


def cross(ax, ay, bx, by, cx, cy):
    # A = 2*((bx-ax)(cy-ay)-(by-ay)(cx-ax)), full signed32 flags.
    clr(); lda(by); subm(ay); store(T1)
    lda(cx); subm(ax); store(T2)
    emit(0x1800+T1, 0x1900+T2)  # ldi r0,T1 ; ldi r1,T2
    lda(bx); subm(ax); emit(0x0013)
    lda(cy); subm(ay); emit(0x0023, 0x0037)
    emit(0x0210, 0x0221, 0x2007)  # X=(r0) Y=(r1) ; sub A,P


def swap_if(a, b):
    done = uid('Sorted')
    clr(); lda(b+1); subm(a+1); br(done, 'n0')
    for k in (0, 1):
        lda(a+k); emit(0x0013); lda(b+k); store(a+k); emit(0x0031); store(b+k)
    label(done)


def edge_setup(rec, xp, yp, xq, yq, ceil_side):
    neg, zero, done, ceil, end = (uid(n) for n in ('Neg', 'Zero', 'Step', 'Ceil', 'Ready'))
    clr(); lda(yq); subm(yp); store(rec+4); store(DDY)
    lda(xp); store(rec)
    clr(); lda(xq); subm(xp); store(DX); emit(0x9007); store(DA)
    emit(0x4800, 'SVP_TriDiv/2')
    clr(); lda(DX); cmpi(0); br(neg, 'n1')
    lda(DQ); store(rec+2); lda(DR); store(rec+3); br(done)
    label(neg); clr(); lda(DR); cmpi(0); br(zero, 'z1')
    lda(DQ); emit(0x9006); subi(1); store(rec+2)
    lda(rec+4); subm(DR); store(rec+3); br(done)
    label(zero); clr(); lda(DQ); emit(0x9006); store(rec+2); clr(); store(rec+3)
    label(done); clr(); lda(SIDE); cmpi(ceil_side); br(ceil, 'z1')
    clr(); lda(rec+4); emit(0x9006); store(rec+1); br(end)
    label(ceil); emit(0xe003, 0x0830, 0xffff); store(rec+1)
    label(end)


def edge_step(rec):
    carry, end = uid('Carry'), uid('Stepped')
    lda(rec+1); addm(rec+3); br(carry, 'n1')
    subm(rec+4); store(rec+1); lda(rec); addm(rec+2); addi(1); br(end)
    label(carry); store(rec+1); lda(rec); addm(rec+2)
    label(end); store(rec)


def tri_row(side):
    left, right = (LONG, SH) if side else (SH, LONG)
    row, skip, single = f'SVP_TriRow{side}', f'SVP_TriSkip{side}', f'SVP_TriSingle{side}'
    label(row)
    clr(); lda(TY); cmpi('M4_RENDER_TOP+M4_RENDER_HEIGHT'); br('SVP_TriDone', 'n0')
    cmpi('M4_RENDER_TOP'); br(skip, 'n1')
    lda(right); subm(left); br(skip, 'n1')
    # Same PMC4418 writes as the walking path: left mask, colour, right mask.
    clr(); lda(left); addi('SVP_TriCol/2'); emit(0x4a20)
    lda(TY); addi('SVP_TriRowBase/2'); emit(0x4a30); addm(0xf6); emit(0x8002)
    emit(0x00e3, 0x08e0, 0x4418, 0x00c0)
    row_colour(TY)
    clr(); lda(left); andi(3); addi('SVP_IntroLeftMasks/2'); emit(0x4a10)
    lda(0x13); emit(0xa001, 0x0013)  # X = row word & left mask
    lda(left); addi('SVP_TriQ4/2'); emit(0x4a20)
    lda(right); addi('SVP_TriQ4/2'); emit(0x4a30, 0x2002); br(single, 'z1')
    emit(0x00c1, 0x9006); addi(f'SVP_TriFillEnd{side}/2+1'); store(TGT)
    lda(right); andi(3); addi('SVP_IntroRightMasks/2'); emit(0x4a10)
    lda(0x13); emit(0xa001, 0x0013)
    lda(0x13); emit(0x0023)
    lda(TGT); emit(0x0063)
    emit(*([0x00c2]*62))  # 0..62 complete interior WORDs
    label(f'SVP_TriFillEnd{side}'); emit(0x00c1); br(skip)
    label(single); lda(right); andi(3); addi('SVP_IntroRightMasks/2'); emit(0x4a30, 0xa001, 0x00c3)
    label(skip)
    clr(); lda(TY); subm(YEND); br('SVP_TriPhaseEnd', 'z1')
    lda(TY); addi(1); store(TY)
    edge_step(left); edge_step(right); br(row)


def row_colour(yslot):
    # Original CMODE dither: (x^y)&1=0 uses low nibble L. Even rows L H L H.
    odd, done = uid('OddRow'), uid('RowColour')
    clr(); lda(yslot); andi(1); br(odd, 'z0'); lda(0xd2); br(done)
    label(odd); lda(0xd3)
    label(done); store(0x13)


def fast_triangle():
    cross(0x41, 0x42, 0x43, 0x44, 0x45, 0x46)
    br('SVP_IntroTriangleSlow', 'n1'); br('SVP_IntroTriangleSlow', 'z1')
    for src in range(6):
        lda(0x41+src); store(XT+src)
    swap_if(XT, XM); swap_if(XM, XB); swap_if(XT, XM)
    # Mid vertex left of the long edge (d>0) makes the long edge the right one.
    cross(XT, YT, XB, YB, XM, YM)
    br('SVP_TriSideLeft', 'n1'); clr(); br('SVP_TriSideStore')
    label('SVP_TriSideLeft'); emit(0xe003, 0x0830, 1)
    label('SVP_TriSideStore'); store(SIDE)
    edge_setup(LONG, XT, YT, XB, YB, 1)
    clr(); lda(YM); subm(YB); br('SVP_TriOnePhase', 'z1')
    clr(); lda(YM); subm(YT); br('SVP_TriFlatTop', 'z1')
    edge_setup(SH, XT, YT, XM, YM, 0)
    clr(); lda(YM); subi(1); store(YEND); emit(0x0830, 1); store(PH2); br('SVP_TriStart')
    label('SVP_TriOnePhase'); edge_setup(SH, XT, YT, XM, YM, 0)
    lda(YB); store(YEND); clr(); store(PH2); br('SVP_TriStart')
    label('SVP_TriFlatTop'); edge_setup(SH, XM, YM, XB, YB, 0)
    lda(YB); store(YEND); clr(); store(PH2)
    label('SVP_TriStart'); lda(YT); store(TY)
    clr(); lda(SIDE); cmpi(0); br('SVP_TriRow0', 'z1'); br('SVP_TriRow1')
    tri_row(0); tri_row(1)
    label('SVP_TriPhaseEnd')
    clr(); lda(PH2); cmpi(0); br('SVP_TriDone', 'z1')
    clr(); store(PH2); lda(YB); store(YEND)
    lda(TY); addi(1); store(TY)
    edge_step(LONG)
    edge_setup(SH, XM, YM, XB, YB, 0)
    clr(); lda(SIDE); cmpi(0); br('SVP_TriRow0', 'z1'); br('SVP_TriRow1')
    label('SVP_TriDone'); br('SVP_IntroNextPrimitive')
    # DA=|dx|0..255, DDY=1..223 -> DQ,DR exact; recip=ceil(32768/dy), one fix.
    label('SVP_TriDiv')
    clr(); lda(DDY); cmpi(1); br('SVP_TriDivOne', 'z1')
    addi('SVP_TriDivM/2'); emit(0x4a20)
    lda(DA); emit(0x0013, 0x0037); store(DQ)
    emit(0x0013); lda(DDY); emit(0x0023, 0x0037, 0x003f, 0x9002); store(DR)
    clr(); lda(DA); subm(DR); br('SVP_TriDivFix', 'n1'); store(DR); ret()
    label('SVP_TriDivFix'); addm(DDY); store(DR); lda(DQ); subi(1); store(DQ); ret()
    label('SVP_TriDivOne'); lda(DA); store(DQ); clr(); store(DR); ret()


def fast_tables():
    def table(name, values):
        label(name)
        for i in range(0, len(values), 16):
            emit(*values[i:i+16])
    table('SVP_TriRowBase', [((y-16)&0xf0)*64+((y-16)&15)*2 if 16 <= y < 208 else 0 for y in range(224)])
    table('SVP_LineRow', [((y-16)&0xf0)*64+((y-16)&15)*2 if 16 <= y < 208 else 0x8000 for y in range(224)])
    table('SVP_TriCol', [(x>>3)*32+((x>>2)&1) for x in range(256)])
    table('SVP_TriQ4', [x>>2 for x in range(256)])
    # (x^y)&1=0 -> low nibble L. Word pixels x..x+3 from bit15 down.
    table('SVP_DitherEven', [((v&15)<<12)|((v>>4)<<8)|((v&15)<<4)|(v>>4) for v in range(256)])
    table('SVP_DitherOdd', [((v>>4)<<12)|((v&15)<<8)|((v>>4)<<4)|(v&15) for v in range(256)])
    table('SVP_TriDivM', [0, 0]+[-(-32768//d) for d in range(2, 224)])


def ret(): emit(0x0065)


fb=runpy.run_path(str(ROOT/'tools/svp-framebuffer.py'))
label('SVP_IntroRaster'); emit(0x0032,0x0e00)
fb['setup'](globals(),'SVP_Intro','SVP_IntroInvalid')
emit(0x08e0,10,0x08e0,0x0018,0x000c,0xe003,0x003c); store(2)
emit(0x6800,257); branch('SVP_IntroCountOK','n1'); branch('SVP_IntroInvalid')
label('SVP_IntroCountOK'); emit(0x08e0,13,0x08e0,0x0018,0x000c,0xe003,0x003c);store(0x1f0);emit(0x08e0,14,0x08e0,0x0018,0x000c,0xe003,0x003c);store(0x1f1)
emit(0x08e0,11,0x08e0,0x0018,0x000c,0xe003,0x003c)
emit(0x6800,0); branch('SVP_IntroClear','z1')
emit(0x6800,1); branch('SVP_IntroBegin','z1'); branch('SVP_IntroInvalid')
label('SVP_IntroClear');fb['pm'](globals(),True);emit(0x0820,0)
immediate('M4_RENDER_HEIGHT*4'); label('SVP_IntroClearTile'); emit(*([0x00c2]*16),0x2800,1)
branch('SVP_IntroClearTile','z0')
lines.append('        if def(M4_VR_DMA)')
emit(0x4800,'SVP_Grid/2') # level ground dots behind the polygons (flag 0: none)
emit(0x4800,'SVP_Stars/2') # space stars (mshowdust 01:A8A6) behind the polygons (flag >= 0: none)
lines.append('        endif')
label('SVP_IntroBegin'); immediate('((M4_POLY_INPUT-$300000)/2)');store(1)
load(2); emit(0x6800,0); branch('SVP_IntroDone','z1')
label('SVP_IntroPrimitive'); load(1); emit(0x00e3,0x08e0,0x0818,0x000c)
for slot in range(0x40,0x48): emit(0xe003,0x003c); store(slot)
load(1); emit(0x8800,8); store(1)
load(0x40);emit(0x6800,4);branch('SVP_IntroParticle','z1')
lines.append('        if def(M4_VR_DMA)')
load(0x40);emit(0x6800,5);branch('SVP_IntroSprite','z1') # mssprite 01:CCA8 (generate-svp-sprites.py)
load(0x40);emit(0x6800,6);branch('SVP_IntroRadioFace','z1') # radio box (generate-level-radio.py)
load(0x40);emit(0x6800,7);branch('SVP_IntroRadioGlyph','z1')
load(0x40);emit(0x6800,8);branch('SVP_IntroRadioRect','z1')
load(0x40);emit(0x6800,9);branch('SVP_IntroSphere','z1')      # mdrawtsphere 01:B807 (generate-svp-sphere.py)
load(0x40);emit(0x6800,10);branch('SVP_IntroSphSprite','z1')  # mdrawsprite32/musprite (generate-svp-sphere.py)
lines.append('        if def(M4_STEXT)')
# Release: types 11 and 13 (msprint, generate-svp-ending-text.py) in SVP_STextDispatch;
# same six WORDs so no later SSP instruction moves.
emit(0x4c00,'SVP_STextDispatch/2',0,0,0,0)
lines.append('        else')
load(0x40);emit(0x6800,11);branch('SVP_IntroTexPoly','z1')    # mtscanstart 01:A3B2 (generate-svp-texpoly.py)
lines.append('        endif')
label('SVP_IntroPrimRest')
lines.append('        endif')
for slot,limit in ((0x41,256),(0x42,224),(0x43,256),(0x44,224),(0x45,256),(0x46,224),(0x47,16)):
    load(slot); emit(0x6800,0); branch('SVP_IntroInvalid','n1')
    if slot == 0x47: branch('SVP_IntroInvalid','z1')
    if slot == 0x47:
        lines.append('        if def(M4_VR_DMA)'); emit(0x6800,256); lines.append('        else'); emit(0x6800,16); lines.append('        endif')
    else:
        emit(0x6800,limit)
    branch('SVP_IntroValid'+str(slot),'n1'); branch('SVP_IntroInvalid')
    label('SVP_IntroValid'+str(slot))
lines.append('        if def(M4_VR_DMA)')
# Colour byte HL from SVP10/68000: two row words of the original dither.
load(0x47); emit(0x8800,'SVP_DitherEven/2',0x4a30); store(0xd2); store(0x13)
load(0x47); emit(0x8800,'SVP_DitherOdd/2',0x4a30); store(0xd3)
lines.append('        else')
load(0x47); emit(0x8800,'SVP_IntroColours/2',0x4a30); store(0x13)
lines.append('        endif')
load(0x40); emit(0x6800,2); branch('SVP_IntroLine','z1')
emit(0x6800,3); branch('SVP_IntroTriangle','z1')
lines.append('        if def(M4_VR_DMA)')
emit(0x6800,12); branch('SVP_GsuLine','z1') # GSU line 01:D8B3 (cockpit HUD 01:D76B)
lines.append('        endif')
branch('SVP_IntroInvalid')
label('SVP_IntroTriangle')
lines.append('        if def(M4_VR_DMA)')
fast_triangle()
lines.append('        endif')
label('SVP_IntroTriangleSlow')
for dimension in range(2):
    base=0x41+dimension
    for target,minimum in ((0x20+dimension,True),(0x22+dimension,False)):
        load(base); store(target)
        for other in (base+2,base+4):
            load(other); emit(0x2600+target)
            branch(f'SVP_IntroBBox{target}_{other}' if minimum else f'SVP_IntroBBoxDone{target}_{other}', 'n1')
            if minimum: branch(f'SVP_IntroBBoxDone{target}_{other}')
            label(f'SVP_IntroBBox{target}_{other}')
            load(other); store(target)
            label(f'SVP_IntroBBoxDone{target}_{other}')
for edge,(a,b) in enumerate(((1,2),(2,0),(0,1))):
    ax,ay,bx,by=0x41+a*2,0x42+a*2,0x41+b*2,0x42+b*2
    load(ay); emit(0x2600+by); store(0x24+edge)
    load(bx); emit(0x2600+ax); store(0x27+edge)
    load(0x20); emit(0x2600+ax,0x0013)
    load(0x24+edge); emit(0x0023,0x0037); store(0x30); emit(0x003f); store(0x31)
    load(0x21); emit(0x2600+ay,0x0013)
    load(0x27+edge); emit(0x0023)
    restore(0x30,0x31); emit(0x8007); store(0x2a+edge*2); emit(0x003f); store(0x2b+edge*2)
load(0x22); emit(0x2620,0x8800,1); store(0x50)
load(0x21); store(7)
lines.append('        if def(M4_VR_DMA)')
immediate(0)
for edge in range(3):store(0x90+edge)
lines.append('        endif')
label('SVP_IntroRow')
load(7); emit(0x6800,'M4_RENDER_TOP'); branch('SVP_IntroEndRow','n1')
# Signed y is bounded0..223. Accept only the chosen view window.
load(7); emit(0x6800,'M4_RENDER_TOP+M4_RENDER_HEIGHT'); branch('SVP_IntroRowVisible','n1'); branch('SVP_IntroEndRow'); label('SVP_IntroRowVisible')
lines.append('        if def(M4_VR_DMA)')
row_colour(7)
lines.append('        endif')
immediate(0); store(0x51); load(0x50); store(0x52)
lines.append('        if def(M4_VR_DMA)')
for edge in range(3):walking_span(edge)
lines.append('        else')
for edge in range(3):span(edge)
lines.append('        endif')
load(0x52); emit(0x2651); branch('SVP_IntroEndRow','z1'); branch('SVP_IntroEndRow','n1')
load(0x51); emit(0x8620); store(6)
load(0x52); emit(0x8620,0x2800,1); store(0x14)
row_address()
load(6); emit(0xa800,3,0x8800,'SVP_IntroLeftMasks/2',0x4a10)
load(0x13); emit(0xa001); store(0x15)
load(0x14); emit(0xa800,3,0x8800,'SVP_IntroRightMasks/2',0x4a10)
load(0x13); emit(0xa001); store(0x16)
load(6); emit(0x9002,0x9002); store(6); load(6); emit(0x9003,0x9003); store(6)
load(0x14); emit(0x9002,0x9002); store(0x14); load(0x14); emit(0x9003,0x9003); store(0x14)
# VR uses4418 (ROM0041A8 etc.): masked writes, cell increment1/31.
# It exactly follows paired vertical tiles, replacing per-word address setup.
lines.append('        if def(M4_VR_DMA)')
pixel_address(0x4418)
load(0x14); emit(0x2606,0x9002,0x9002) # words between aligned endpoints
branch('SVP_IntroFastSingle','z1')
emit(0x2800,1);store(0x18) # complete interior words,0..62
load(0x15);emit(0x00c3) # partial left word; PMC advances automatically
load(0x13);emit(0x0023) # retain repeated colour in Y
load(0x18)
label('SVP_IntroFastEight')
emit(0x6800,8);branch('SVP_IntroFastTail','n1')
emit(*([0x00c2]*8),0x2800,8);branch('SVP_IntroFastEight')
label('SVP_IntroFastTail');emit(0x6800,0);branch('SVP_IntroFastRight','z1')
label('SVP_IntroFastWord');emit(0x00c2,0x2800,1);branch('SVP_IntroFastWord','z0')
label('SVP_IntroFastRight');load(0x16);emit(0x00c3);branch('SVP_IntroEndRow')
label('SVP_IntroFastSingle');load(0x15);emit(0x0013);load(0x16);emit(0xa001,0x00c3)
lines.append('        else')
label('SVP_IntroFillWord'); pixel_address()
load(6); emit(0x2614); branch('SVP_IntroLastWord','z1')
load(0x15); emit(0x00c3); load(0x13); store(0x15)
load(6); emit(0x8800,4); store(6); branch('SVP_IntroFillWord')
label('SVP_IntroLastWord'); load(0x15); emit(0x0013); load(0x16); emit(0xa001,0x00c3)
lines.append('        endif')
label('SVP_IntroEndRow')
for hi,lo,slope in ((0x2a,0x2b,0x27),(0x2c,0x2d,0x28),(0x2e,0x2f,0x29)): edge_add(hi,lo,slope)
load(7); emit(0x8800,1); store(7)
load(0x23); emit(0x2607); branch('SVP_IntroNextPrimitive','n1'); branch('SVP_IntroRow')
label('SVP_IntroLine')
for start,end,distance,step in ((0x41,0x43,0x34,0x36),(0x42,0x44,0x35,0x37)):
    load(end); emit(0x2600+start); branch('SVP_IntroLineNegative'+str(start),'n1')
    store(distance); immediate(1); store(step); branch('SVP_IntroLineAxisDone'+str(start))
    label('SVP_IntroLineNegative'+str(start)); emit(0x9006); store(distance); immediate(65535); store(step)
    label('SVP_IntroLineAxisDone'+str(start))
load(0x34); emit(0x2635); store(0x38)
load(0x41); store(6); load(0x42); store(7)
lines.append('        if def(M4_VR_DMA)')
# Same pixels, order and writes as the stepping loop kept below (else branch):
# with e = dx-dy and the inclusive tests (x step iff 2e+dy >= 0, y step iff
# 2e <= dx) the major axis steps every time, so a line is max(dx,dy)+1 pixels
# (all dx 0..255, dy 0..223 checked, build/agent-svpperf/SVPPERF.md); the minor
# test becomes e <= dx>>1 (x major) or e+(dy>>1) >= 0 (y major). Per pixel the
# word address is SVP_TriCol[x] + SVP_LineRow[y] + base (LineRow = 8000 outside
# rows 16..207: col+row < 0 skips the write) and the written word is
# colour(y&1) & PixelMasks[x&3] from an 8-word RAM table (r1 = D8+4(y&1)+(x&3)).
# RAM: D4 col, D5 row, D6 table row base, D7 count, F0 threshold, F1 dx-dy.
for par,src in ((0,0xd2),(1,0xd3)):
    for k,mask in enumerate((0xf000,0x0f00,0x00f0,0x000f)):
        emit(0x0600+src,0xa800,mask);store(0xd8+4*par+k)
clr();lda(6);addi('SVP_TriCol/2');emit(0x4a30);store(0xd4)
clr();lda(7);addi('SVP_LineRow/2');emit(0x4a30);addm(0xf6);store(0xd5)
clr();lda(7);andi(1);emit(0x9003,0x9003);addi(0xd8);store(0xd6)
lda(6);andi(3);addm(0xd6);emit(0x1431)
lda(0x34);subm(0x35);store(0xf1);br('SVP_LineYMajor','n1')
def line_x_step():
    lda(6);addm(0x36);store(6);addi('SVP_TriCol/2');emit(0x4a30);store(0xd4)
    lda(6);andi(3);addm(0xd6);emit(0x1431)
def line_y_step():
    lda(7);addm(0x37);store(7);addi('SVP_LineRow/2');emit(0x4a30);addm(0xf6);store(0xd5)
    lda(0xd6);emit(0xe800,4);store(0xd6);emit(0x1231,0xe800,4,0x1431)
for major in 'XY':
    if major=='Y':label('SVP_LineYMajor')
    lda(0x34 if major=='X' else 0x35);store(0xd7);emit(0x9002);store(0xf0)
    label(f'SVP_Line{major}Pixel');lda(0xd4);addm(0xd5);br(f'SVP_Line{major}Count','n1')
    emit(0x00e3,0x08e0,0x0418,0x00c0,0x02c1)
    label(f'SVP_Line{major}Count');lda(0xd7);subi(1);store(0xd7);br('SVP_IntroNextPrimitive','n1')
    if major=='X':
        line_x_step()
        lda(0xf0);subm(0x38);br('SVP_LineXNoY','n1')
        lda(0x38);addm(0xf1);store(0x38);line_y_step();br('SVP_LineXPixel')
        label('SVP_LineXNoY');lda(0x38);subm(0x35);store(0x38);br('SVP_LineXPixel')
    else:
        line_y_step()
        lda(0x38);addm(0xf0);br('SVP_LineYNoX','n1')
        lda(0x38);addm(0xf1);store(0x38);line_x_step();br('SVP_LineYPixel')
        label('SVP_LineYNoX');lda(0x38);addm(0x34);store(0x38);br('SVP_LineYPixel')
lines.append('        else')
label('SVP_IntroLinePixel'); load(7); emit(0x6800,'M4_RENDER_TOP'); branch('SVP_IntroLineAdvance','n1'); emit(0x6800,'M4_RENDER_TOP+M4_RENDER_HEIGHT'); branch('SVP_IntroLineVisible','n1'); branch('SVP_IntroLineAdvance'); label('SVP_IntroLineVisible')
lines.append('        if def(M4_VR_DMA)')
row_colour(7)
lines.append('        endif')
row_address(); pixel_address()
load(6); emit(0xa800,3,0x8800,'SVP_IntroPixelMasks/2',0x4a10)
load(0x13); emit(0xa001,0x00c3)
label('SVP_IntroLineAdvance'); load(6); emit(0x2643); branch('SVP_IntroLineStep','z0')
load(7); emit(0x2644); branch('SVP_IntroNextPrimitive','z1')
label('SVP_IntroLineStep'); load(0x38); emit(0x9003); store(0x39)
load(0x39); emit(0x8635); branch('SVP_IntroLineSkipX','n1')
load(0x38); emit(0x2635); store(0x38)
load(6); emit(0x8636); store(6)
label('SVP_IntroLineSkipX'); load(0x34); emit(0x2639); branch('SVP_IntroLinePixel','n1')
load(0x38); emit(0x8634); store(0x38)
load(7); emit(0x8637); store(7); branch('SVP_IntroLinePixel')
lines.append('        endif')
label('SVP_IntroNextPrimitive'); load(2); emit(0x2800,1); store(2); branch('SVP_IntroPrimitive','z0');branch('SVP_IntroDone')
# Type 12: the GSU line of 01:D8B3 (tools/check-cockpit-hud.py: exact pixels of
# the ROM). From (x0,y0) to (x1,y1), max(|dx|,|dy|)+1 pixels; major-axis step
# every pixel; with e = (major - minor) >> 1: plot, minor step when e < minor
# (then e += major), e -= minor. Same pixel write as SVP_IntroLine.
lines.append('        if def(M4_VR_DMA)')
label('SVP_GsuLine')
for start,end,distance,step in ((0x41,0x43,0x34,0x36),(0x42,0x44,0x35,0x37)):
    load(end); emit(0x2600+start); branch('SVP_GsuLineNegative'+str(start),'n1')
    store(distance); immediate(1); store(step); branch('SVP_GsuLineAxisDone'+str(start))
    label('SVP_GsuLineNegative'+str(start)); emit(0x9006); store(distance); immediate(65535); store(step)
    label('SVP_GsuLineAxisDone'+str(start))
load(0x41); store(6); load(0x42); store(7)
for major,minor,mstep,nstep,mpos,npos,tag in ((0x34,0x35,0x36,0x37,6,7,'X'),(0x35,0x34,0x37,0x36,7,6,'Y')):
    if tag == 'X':
        load(0x34); emit(0x2635); branch('SVP_GsuLineY','n1') # |dx| < |dy|: y-major
    else:
        label('SVP_GsuLineY')
    load(major); emit(0x2600+minor); emit(0x9002); store(0x38) # e = (major - minor) >> 1
    load(major); emit(0x8800,1); store(0x39) # count = major + 1
    label('SVP_GsuLinePixel'+tag); load(7); emit(0x6800,'M4_RENDER_TOP'); branch('SVP_GsuLineAdvance'+tag,'n1')
    emit(0x6800,'M4_RENDER_TOP+M4_RENDER_HEIGHT'); branch('SVP_GsuLineVisible'+tag,'n1'); branch('SVP_GsuLineAdvance'+tag)
    label('SVP_GsuLineVisible'+tag)
    row_colour(7); row_address(); pixel_address()
    load(6); emit(0xa800,3,0x8800,'SVP_IntroPixelMasks/2',0x4a10)
    load(0x13); emit(0xa001,0x00c3)
    label('SVP_GsuLineAdvance'+tag)
    load(0x38); emit(0x2600+minor); branch('SVP_GsuLineMinor'+tag,'n1')
    store(0x38); branch('SVP_GsuLineMajor'+tag) # e >= minor: e -= minor
    label('SVP_GsuLineMinor'+tag); load(npos); emit(0x8600+nstep); store(npos)
    load(0x38); emit(0x8600+major); emit(0x2600+minor); store(0x38) # e += major - minor
    label('SVP_GsuLineMajor'+tag); load(mpos); emit(0x8600+mstep); store(mpos)
    load(0x39); emit(0x2800,1); store(0x39); branch('SVP_GsuLinePixel'+tag,'z0')
    branch('SVP_IntroNextPrimitive')
lines.append('        endif')
lines.append('        if def(M4_VR_DMA)')
label('SVP_IntroSprite');emit(0x4800,'SVP_Sprite/2');branch('SVP_IntroNextPrimitive')
label('SVP_IntroRadioFace');emit(0x4800,'SVP_RadioFace/2');branch('SVP_IntroNextPrimitive')
label('SVP_IntroRadioGlyph');emit(0x4800,'SVP_RadioGlyph/2');branch('SVP_IntroNextPrimitive')
label('SVP_IntroRadioRect');emit(0x4800,'SVP_RadioRect/2');branch('SVP_IntroNextPrimitive')
label('SVP_IntroSphere');emit(0x4800,'SVP_SphereRecord/2');branch('SVP_IntroNextPrimitive')
label('SVP_IntroSphSprite');emit(0x4800,'SVP_SphSprite/2');branch('SVP_IntroNextPrimitive')
label('SVP_IntroTexPoly');emit(0x4800,'SVP_TexPoly/2');branch('SVP_IntroNextPrimitive')
lines.append('        endif')
label('SVP_IntroParticle')
load(0x42);store(0x64)
load(0x43);emit(0x6800,0);branch('SVP_IntroParticleExisting','z1');immediate(6);branch('SVP_IntroParticleFlags')
label('SVP_IntroParticleExisting');immediate(4)
label('SVP_IntroParticleFlags');store(0x60);immediate(7);store(0x61);immediate(60);store(0x62);immediate(40);store(0x63)
load(0x41);emit(0x00e3,0x08e0,0x0818,0x000c)
for slot in (0x65,0x66,0x67):emit(0xe003,0x003c);store(slot)
immediate(0);store(0x69)
emit(0x4800,'SVP_ParticleWork/2')
emit(0x08e0,'((M4_PART_STATE-$300000)/2+4)',0x08e0,0x0818,0x00c0)
load(0x1c);emit(0x00c3);load(0x14);emit(0x00c3)
branch('SVP_IntroNextPrimitive')
label('SVP_IntroDone')
# Original global update runs after all owners' show passes. Skip an empty pool.
emit(0x08e0,'((M4_PART_STATE-$300000)/2+0)',0x08e0,0x0018,0x000c,0xe003,0x003c,0x6800,0x5054)
branch('SVP_IntroParticlesUpdated','z0')
emit(0x08e0,'((M4_PART_STATE-$300000)/2+4)',0x08e0,0x0018,0x000c,0xe003,0x003c,0x6800,0)
branch('SVP_IntroParticlesUpdated','z1')
immediate(8);store(0x60);immediate(1);store(0x64);emit(0x4800,'SVP_ParticleWork/2')
emit(0x08e0,'((M4_PART_STATE-$300000)/2+4)',0x08e0,0x0018,0x00c0);load(0x1c);emit(0x00c3)
label('SVP_IntroParticlesUpdated');fb['pm'](globals());fb['checksum'](globals(),'SVP_Intro')
emit(0xe003,0x0031,0x08e0,8,0x08e0,0x0018,0x00c0,0x00c3)
load(0); emit(0x0023); immediate('M4_RENDER_WORDS'); branch('SVP_PublishResult')
label('SVP_IntroInvalid'); load(0); emit(0x0023); immediate(0); branch('SVP_PublishResult')
GUARD=False # tables below
label('SVP_IntroColours'); emit(*(i*0x1111 for i in range(16)))
label('SVP_IntroLeftMasks'); emit(0xffff,0x0fff,0x00ff,0x000f)
label('SVP_IntroRightMasks'); emit(0xf000,0xff00,0xfff0,0xffff)
label('SVP_IntroPixelMasks'); emit(0xf000,0x0f00,0x00f0,0x000f)
lines.append('        if def(M4_VR_DMA)')
fast_tables()
lines.append('        endif')
label('SVP_IntroReciprocals')
for start in range(0,256,16): emit(*(32768//i if i else 0 for i in range(start,start+16)))
# Bounded commercial correspondence for the hardware optimization.
# The SVP code above does not read the Virtua Racing ROM; when it is present
# (and MEGASVP_NO_VR is unset) the two method opcodes are checked against it.
VR_ROM=ROOT/'ref/Virtua Racing.bin'
VR_SHA='291e74f9b4d5a2c0f2b7cbf6f2e0fbf72c16cb6d83b1f58dda78209f9a64c486'
import os
if VR_ROM.exists() and not os.environ.get('MEGASVP_NO_VR'):
    vr=VR_ROM.read_bytes()
    assert hashlib.sha256(vr).hexdigest()==VR_SHA
    assert vr[0x41a8:0x41ac]==bytes.fromhex('08e04418')
    assert vr[0x3c72:0x3c74]==bytes.fromhex('4418')
    vr_checked=True
else:
    print('Virtua Racing ROM not used: cell-span correspondence check skipped (code unchanged)')
    vr_checked=False
origin=dict(check='PASS' if vr_checked else 'SKIPPED (no VR ROM)',rom_sha256=VR_SHA,vr_rom_checked=vr_checked,
    source='IRAM generation1EB7 PC021B; physicalROM0041A8:08E0 4418; table003C72:4418',
    implementation='SVP_IntroFastEight/FastWord; endpoint masks unchanged',
    contract='paired vertical tiles:WORD increments1(even)/31(odd); span1..64WORDS; masked endpoints, full interior words, palette1..15; index0 holes preserved',
    core_reference='Genesis-Plus-GX core/cart_hw/svp/ssp16.c:pm_io cell increment',
    scope='Hardware method/opcode correspondence; no retail firmware reused. Runtime/bitmaps/performance reported separately.')
(ROOT/'build/svp-cell-span-origin.json').write_text(json.dumps(origin,indent=2)+'\n')
(ROOT/'build/svp-intro-raster.inc').write_text('\n'.join(lines)+'\n', encoding='ascii')
print('Generated SVP intro triangle/line setup, exact spans and packed pixels')
