; Nintendo/Presents subset of selected USA ROM GSU msprint (physical CEF0).
; Original projection 9263/942F/9493: signed truncation of coord*256/z.
; For z=4000, size 0 => char=8,string=65,scale=$8200;
; size=-32 => char=6,string=48,scale=$6000. Centre subtracts CEIL(width/2).
; Original division is exact in this range: divisor<32768, dividend<2^31.
; The GSU text caller at ADCC passes depth directly as colour (except 15).
; Coordinates remain in the original 224x192 space; SVP adds +16,+16.
;
; a0=text_path context; a1=descriptor (x,y,scale,colour,strptr,len,char_width).
; d0=camera-relative Z (3500..5000, covering the initial parents/trails).
; Returns d0=0 success, -1 unsupported Z/size/depth; clobbers d0-d3.
; Clipping remains the renderer's job: partly visible strings cannot be
; rejected from their origin alone. Original per-character clipping must
; run inside the SVP (including x<=0 whole-character skip).
M4TextProject:
        cmpi.w #3500,d0
        blo M4TextProjectUnsupported
        cmpi.w #5000,d0
        bhi M4TextProjectUnsupported
        moveq #0,d3
        move.b 10(a0),d3
        cmpi.w #14,d3
        bhi M4TextProjectUnsupported
        tst.w d3
        beq M4TextProjectUnsupported
        move.w d3,6(a1)
        moveq #127,d1
        tst.b 20(a0)
        beq.s M4TextProjectSizeOK
        cmpi.b #$e0,20(a0)
        bne M4TextProjectUnsupported
        moveq #95,d1
M4TextProjectSizeOK:
        move.l d1,d2
        lsl.l #8,d1
        divu.w d0,d1
        move.w d1,12(a1)        ; original m_sprsize for clipping
        move.w d1,d3
        addq.w #1,d3
        lsr.w #1,d3             ; ceil(projected character width / 2)
        lsl.l #8,d2
        lsl.l #3,d2             ; original string has eight characters
        divu.w d0,d2
        move.w d2,d1
        lsl.w #8,d1
        lsl.w #1,d1             ; floor(width*65536/128), exact since 128|65536
        move.w d1,4(a1)
        addq.w #1,d2
        lsr.w #1,d2             ; ceil(projected whole string width / 2)
        move.w (a0),d1
        ext.l d1
        lsl.l #8,d1
        divs.w d0,d1
        addi.w #112,d1
        sub.w d2,d1
        move.w d1,(a1)
        move.w 2(a0),d1
        ext.l d1
        lsl.l #8,d1
        divs.w d0,d1
        addi.w #96,d1
        sub.w d3,d1
        move.w d1,2(a1)
        moveq #0,d0
        rts
M4TextProjectUnsupported:
        moveq #-1,d0
        rts
