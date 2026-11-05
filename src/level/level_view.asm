; Level view and draw list (research: build/research/view-and-culling.md).
; getview 02:F926 (exterior, viewtype 0): viewpos = shake + pviewpos +
; viewfloat + arm, arm = (0,0,-outdist).R(-viewrotx,0,0).R(0,-viewroty,0);
; W = R(+outvx, +outvy - turnrot, outvz - plrotz) (dozrot=1 on Corneria).
; R(): GSU 01:829F mcrotmatzxy16 with sin16 00:99E5 interpolated; fq products.
; The 68000 composes the view (as the original 65816 asks the GSU for two
; small matrices) and computes rel.W per object for the painter order and
; the cone rejection (GSU 01:B17F/01:AF12); the SVP composes Aт.W per object.
M4_LVW equ $fff300
M4_LVW_POS equ M4_LVW+0 ;3 WORDs viewpos
M4_LVW_W equ M4_LVW+6 ;9 WORDs W row-major
M4_LVW_FLOATY equ M4_LVW+24 ;.w $14EA viewfloatY
M4_LVW_FLOATPTR equ M4_LVW+26 ;.w $14E6
M4_LVW_R equ M4_LVW+28 ;9 WORDs scratch matrix
M4_LVW_ARM equ M4_LVW+46 ;3 WORDs arm vector
M4_LVW_TRIG equ M4_LVW+52 ;sx,cx,sy,cy,sz,cz
M4_LVW_SCR equ M4_LVW+64 ;3 WORDs scratch vector
M4_LVW_DROPPED equ M4_LVW+70 ;.w objects beyond the 40-entry draw list

; fq(d0,d1) -> d0 = floor(d0*d1/32768), 16-bit wrap.
M4LvwFq:
        muls.w d1,d0
        asr.l #8,d0
        asr.l #7,d0
        rts

; sin16 of the 16-bit angle d0 -> d0 (t[i] + floor(f*(t[i+1]-t[i])/256)).
M4LvwSin16:
        if def(M4_GRAPHICS117)
        jmp G117H106Sin16
        nop
        nop
        else
        movem.l d1-d2/a0,-(sp)
        lea M4LevelSin16,a0
        endif
M4LvwSin16Body:
        moveq #0,d1
        move.w d0,d1
        lsr.w #8,d1
        add.w d1,d1
        andi.w #255,d0
        move.w (a0,d1.w),d2
        move.w 2(a0,d1.w),d1
        sub.w d2,d1
        muls.w d0,d1
        asr.l #8,d1
        add.w d2,d1
        move.w d1,d0
        movem.l (sp)+,d1-d2/a0
        rts

; R(d0=ax, d1=ay, d2=az) -> M4_LVW_R (row-major).
M4LvwRotation:
        if def(M4_GRAPHICS117)
        jmp G117H109Rotation
        nop
        nop
        else
        movem.l d0-d7/a0,-(sp)
        lea M4_LVW_TRIG,a0
        endif
M4LvwRotationBody:
        move.w d1,d6
        move.w d2,d7
        move.w d0,d5
        jsr M4LvwSin16
        move.w d0,(a0) ;sx
        move.w d5,d0
        addi.w #$4000,d0
        jsr M4LvwSin16
        move.w d0,2(a0) ;cx
        move.w d6,d0
        jsr M4LvwSin16
        move.w d0,4(a0) ;sy
        move.w d6,d0
        addi.w #$4000,d0
        jsr M4LvwSin16
        move.w d0,6(a0) ;cy
        move.w d7,d0
        jsr M4LvwSin16
        move.w d0,8(a0) ;sz
        move.w d7,d0
        addi.w #$4000,d0
        jsr M4LvwSin16
        move.w d0,10(a0) ;cz
        ; t1=fq(cz,sy) t2=fq(cz,cy) t3=fq(sz,sy) t4=fq(sz,cy)
        move.w 10(a0),d0
        move.w 4(a0),d1
        jsr M4LvwFq
        move.w d0,d4 ;t1
        move.w 10(a0),d0
        move.w 6(a0),d1
        jsr M4LvwFq
        move.w d0,d5 ;t2
        move.w 8(a0),d0
        move.w 4(a0),d1
        jsr M4LvwFq
        move.w d0,d6 ;t3
        move.w 8(a0),d0
        move.w 6(a0),d1
        jsr M4LvwFq
        move.w d0,d7 ;t4
        lea M4_LVW_R,a1
        move.w d6,d0 ;m11 = fq(t3,sx)+t2
        move.w (a0),d1
        jsr M4LvwFq
        add.w d5,d0
        move.w d0,(a1)
        move.w d4,d0 ;m12 = fq(t1,sx)-t4
        move.w (a0),d1
        jsr M4LvwFq
        sub.w d7,d0
        move.w d0,2(a1)
        move.w 2(a0),d0 ;m13 = fq(cx,sy)
        move.w 4(a0),d1
        jsr M4LvwFq
        move.w d0,4(a1)
        move.w 2(a0),d0 ;m21 = fq(cx,sz)
        move.w 8(a0),d1
        jsr M4LvwFq
        move.w d0,6(a1)
        move.w 2(a0),d0 ;m22 = fq(cx,cz)
        move.w 10(a0),d1
        jsr M4LvwFq
        move.w d0,8(a1)
        move.w (a0),d0 ;m23 = -sx
        neg.w d0
        move.w d0,10(a1)
        move.w d7,d0 ;m31 = fq(t4,sx)-t1
        move.w (a0),d1
        jsr M4LvwFq
        sub.w d4,d0
        move.w d0,12(a1)
        move.w d5,d0 ;m32 = fq(t2,sx)+t3
        move.w (a0),d1
        jsr M4LvwFq
        add.w d6,d0
        move.w d0,14(a1)
        move.w 2(a0),d0 ;m33 = fq(cx,cy)
        move.w 6(a0),d1
        jsr M4LvwFq
        move.w d0,16(a1)
        movem.l (sp)+,d0-d7/a0
        rts

; a0 = vector (3 WORDs), a1 = matrix -> a2 result: r_j = sum_k fq(v_k, M[k][j]),
; k = 0..2 in order, 16-bit wrap (unrolled; same products as M4LvwFq).
; WORD of a Q15 product. hw109 (make-round48.py): ADD/SWAP keeps the same
; low WORD as ASR #15 (bits 15..30) with fewer cycles.
M4LvwQ15 macro
        if def(M4_GRAPHICS117)
        add.l d0,d0
        swap d0
        else
        asr.l #8,d0
        asr.l #7,d0
        endif
        endm
M4LvwRowTimes:
        movem.l d0-d4,-(sp)
        movem.w (a0),d2-d4
        move.w d2,d0
        muls.w 0(a1),d0
        M4LvwQ15
        move.w d0,d1
        move.w d3,d0
        muls.w 6(a1),d0
        M4LvwQ15
        add.w d0,d1
        move.w d4,d0
        muls.w 12(a1),d0
        M4LvwQ15
        add.w d0,d1
        move.w d1,0(a2)
        move.w d2,d0
        muls.w 2(a1),d0
        M4LvwQ15
        move.w d0,d1
        move.w d3,d0
        muls.w 8(a1),d0
        M4LvwQ15
        add.w d0,d1
        move.w d4,d0
        muls.w 14(a1),d0
        M4LvwQ15
        add.w d0,d1
        move.w d1,2(a2)
        move.w d2,d0
        muls.w 4(a1),d0
        M4LvwQ15
        move.w d0,d1
        move.w d3,d0
        muls.w 10(a1),d0
        M4LvwQ15
        add.w d0,d1
        move.w d4,d0
        muls.w 16(a1),d0
        M4LvwQ15
        add.w d0,d1
        move.w d1,4(a2)
        movem.l (sp)+,d0-d4
        rts

; getview after all strategies of the tick. Also writes the SVP view block.
M4LevelView:
        movem.l d0-d7/a0-a2,-(sp)
        ; init_strats_l 06:8522 viewfloatY (wobble flymode bit4)
        clr.w M4_LVW_FLOATY
        btst #4,M4_LP_FLYMODE
        beq.s M4LvwNoFloat
        move.w M4_LVW_FLOATPTR,d1
        lea M4LevelViewFloat,a0
        move.w (a0,d1.w),d0
        move.b M4_LP_PSF,d2
        andi.b #$18,d2
        bne.s M4LvwFloatFull
        jsr M4LpDiv2
M4LvwFloatFull:
        move.w d0,M4_LVW_FLOATY
        addq.w #2,d1
        cmpi.w #$48,d1
        bne.s M4LvwFloatPtr
        moveq #0,d1
M4LvwFloatPtr:
        move.w d1,M4_LVW_FLOATPTR
M4LvwNoFloat:
        btst #1,M4_SC_VIEWTYPE
        bne M4LvwFixed
        ; viewpos = shake + pviewpos + viewfloat
        lea M4_LVW_POS,a2
        move.b M4_LP_VIEWSHAKE,d0
        ext.w d0
        add.w M4_LP_PVIEWX,d0
        move.w d0,(a2)
        move.b M4_LP_VIEWSHAKE+1,d0
        ext.w d0
        add.w M4_LP_PVIEWY,d0
        add.w M4_LVW_FLOATY,d0
        move.w d0,2(a2)
        move.b M4_LP_VIEWSHAKE+2,d0
        ext.w d0
        add.w M4_LP_PVIEWZ,d0
        move.w d0,4(a2)
        ; arm: b1 = (0,0,-outdist).R(-outvx,0,0); b2 = b1.R(0,-outvy,0)
        move.w M4_LP_OUTVX,d0
        neg.w d0
        moveq #0,d1
        moveq #0,d2
        jsr M4LvwRotation
        lea M4_LVW_ARM,a0
        clr.l (a0)
        move.w M4_LP_OUTDIST,d0
        neg.w d0
        move.w d0,4(a0)
        lea M4_LVW_R,a1
        lea M4_LVW_SCR,a2 ;b1 scratch (3 WORDs after trig)
        jsr M4LvwRowTimes
        move.l (a2),(a0)
        move.w 4(a2),4(a0)
        moveq #0,d0
        move.w M4_LP_OUTVY,d1
        sub.w M4_LP_TURNROT,d1
        neg.w d1
        moveq #0,d2
        jsr M4LvwRotation
        jsr M4LvwRowTimes
        lea M4_LVW_POS,a0
        move.w (a2),d0
        add.w d0,(a0)
        move.w 2(a2),d0
        add.w d0,2(a0)
        move.w 4(a2),d0
        add.w d0,4(a0)
        ; W = R(+outvx, +outvy-turnrot, outvz-plrotz)
        move.w M4_LP_OUTVX,d0
        move.w M4_LP_OUTVY,d1
        sub.w M4_LP_TURNROT,d1
        move.w M4_LP_OUTVZ,d2
        sub.w M4_LP_PLROTZ,d2
        jsr M4LvwRotation
M4LvwComposed:
        lea M4_LVW_R,a0
        lea M4_LVW_W,a1
        lea M4_GEO_VIEW+2,a2
        moveq #8,d0
M4LvwCopyW:
        move.w (a0),(a1)+
        move.w (a0)+,(a2)+
        dbra d0,M4LvwCopyW
        move.w #1,M4_GEO_VIEW
        jsr M4SpCrosshairCalc ;02:FB9D..FC49 at the end of getview
        ; mshowgrid_l 03:BAE3: x0=((vx&$FF)^$FF)-1920, z0 likewise, y0=-vy;
        ; start=(x0,y0,z0).W; px/pz = asr7 of W rows 1 and 3 (+256 world steps)
        lea M4_LVW_SCR,a0
        move.w M4_LVW_POS,d0
        andi.w #$ff,d0
        eori.w #$ff,d0
        subi.w #1920,d0
        move.w d0,(a0)
        move.w M4_LVW_POS+2,d0
        neg.w d0
        move.w d0,2(a0)
        move.w M4_LVW_POS+4,d0
        andi.w #$ff,d0
        eori.w #$ff,d0
        subi.w #1920,d0
        move.w d0,4(a0)
        lea M4_LVW_W,a1
        lea M4_GEO_GRID+2,a2
        jsr M4LvwRowTimes
        lea M4_GEO_GRID+8,a2
        moveq #2,d1
M4LvwGridPx:
        move.w (a1)+,d0
        asr.w #7,d0
        move.w d0,(a2)+
        dbra d1,M4LvwGridPx
        lea M4_LVW_W+12,a1
        moveq #2,d1
M4LvwGridPz:
        move.w (a1)+,d0
        asr.w #7,d0
        move.w d0,(a2)+
        dbra d1,M4LvwGridPz
        moveq #0,d0
        move.b M4_SC_DOTS,d0
        bpl.s M4LvwGridOn
        moveq #0,d0 ;negative (03:BAE3 bit 15): stars, not the grid
M4LvwGridOn:
        move.w d0,M4_GEO_GRID ;dotsflag (levelinfo bit3, 03:F019; 0 in bg_1_1i)
        movem.l (sp)+,d0-d7/a0-a2
        rts
; viewtype bit1 (Fpos, 02:FAA5): viewpos = $C1/$C3/$C5, no arm. Bit0 (toobj,
; 02:FAC6) toward the player: outvx = -Xangle (1F:D03E: atan(dy, distXZ)),
; outvy = Yangle (1F:D021: atan(dx, dz)), arctan GSU 01:81AA; the view
; rotation is (outvx, outvy, outvz = 0), without turnrot and plrotz.
M4LvwFixed:
        lea M4_LVW_POS,a0
        move.l M4_SC_VIEWPOS,(a0)
        move.w M4_SC_VIEWPOS+4,4(a0)
        btst #0,M4_SC_VIEWTYPE
        beq.s M4LvwFixedRot
        lea LV_PLAYER,a2
        move.w M4_SC_VIEWTOOBJ,d0 ;getview 02:F926 toobj: Y = $15A0 (0: the player)
        beq.s M4LvwFixedPl
        movea.w d0,a2
M4LvwFixedPl:
        jsr M4EnDistXZ
        move.w d0,d1
        move.w 2(a2),d0
        sub.w 2(a0),d0
        jsr M4IntroWeaponAtan
        neg.w d0
        move.w d0,M4_LP_OUTVX
        move.w (a2),d0
        sub.w (a0),d0
        move.w 4(a2),d1
        sub.w 4(a0),d1
        jsr M4IntroWeaponAtan
        move.w d0,M4_LP_OUTVY
M4LvwFixedRot:
        move.w M4_LP_OUTVX,d0
        move.w M4_LP_OUTVY,d1
        moveq #0,d2
        jsr M4LvwRotation
        bra M4LvwComposed

; showview: rel = obj - viewpos (WORD wrap), (x,y,z) = rel.W into 56/58/60,
; cone rejection 01:AF12, sortz = sh_sortz + z (+15000 atgnd), painter order.
M4LevelDraw:
        movem.l d1-d7/a0-a4,-(sp)
        if def(M4_DRAWLIST_OVERLAP)
        bclr #1,M4_OVL_STATE ;built during the previous cmd10 (M4OvlWindow)
        bne.s M4LvwListReady
        endif
        bsr.s M4LevelDrawList
M4LvwListReady:
        ; after the list: during cmd10(k-1) these still hold results of k-1
        clr.w M4P_EARLY ;level: cmd8 overlaps the BSP order (measured: an early kick makes SVP9 wait for the raster, 9.6 -> 8.4 images/s in the tunnel)
        clr.w M4_POLY_COUNT
        clr.w M4_MESH_ERROR
        clr.l M4_GEO_OVERLAP
        tst.w M4_SC_TIME_TWEEN
        bne.s M4LvwHookReady ;presentation-only image: no collisions or logic tail
        if def(M4_LOGIC_OVERLAP)
        move.l #M4OvlWindow,M4_GEO_OVERLAP
        else
        move.l #M4LevelOverlapWork,M4_GEO_OVERLAP
        endif
M4LvwHookReady:
        jsr M4IntroSceneDrawSorted
        tst.l M4_GEO_OVERLAP ;not run (no cmd10 this tick): run it now
        beq.s M4LvwOverlapDone
        move.l d0,-(sp) ;keep the draw result
        movea.l M4_GEO_OVERLAP,a0
        clr.l M4_GEO_OVERLAP
        jsr (a0)
        move.l (sp)+,d0
M4LvwOverlapDone:
        movem.l (sp)+,d1-d7/a0-a4
        rts

; Draw list of the tick (RAM only: rel.W into 56/58/60, cone, painter order in
; M4_SHIP_DRAW_LIST, shadow proxies). Clobbers d0-d5/a0-a4.
M4LevelDrawList:
        clr.w M4_SHIP_DRAW_COUNT
        if def(M4_STEXT)
        clr.w M4_END_TEXTN ;text objects: separate list (level_ending.asm)
        endif
        clr.w M4_LVW_DROPPED
        jsr M4LcOrder ;marioshowview walks allst
        movea.l a2,a4
M4LvwDrawNext:
        move.l (a4)+,d0
        beq M4LvwDrawEnd
        movea.l d0,a0
        if def(M4_STEXT)
        btst #0,X_TEXTFL(a0) ;textobj (MDRAWLIS.MC .notpart): msprint only, never the mesh
        beq.s M4LvwNotText
        jsr M4EndTextEntry
        bra M4LvwDrawSkip
M4LvwNotText:
        endif
        tst.b 21(a0)
        beq M4LvwDrawSkip
        btst #1,49(a0) ;invisible
        bne M4LvwDrawSkip
        btst #0,X_TEXTFL(a0) ;textobj (MDRAWLIS.MC .notpart): msprint only, never the mesh
        bne M4LvwDrawSkip
        lea M4_LVW_SCR,a2 ;rel
        move.w (a0),d0
        sub.w M4_LVW_POS,d0
        move.w d0,(a2)
        move.w 2(a0),d0
        sub.w M4_LVW_POS+2,d0
        move.w d0,2(a2)
        move.w 4(a0),d0
        sub.w M4_LVW_POS+4,d0
        move.w d0,4(a2)
        movem.l a0,-(sp)
        movea.l a2,a0
        lea M4_LVW_W,a1
        lea M4_LVW_ARM,a2
        jsr M4LvwRowTimes
        movem.l (sp)+,a0
        move.l M4_LVW_ARM,56(a0)
        move.w M4_LVW_ARM+4,60(a0)
        ; cone: r = size; z+r<0, |x|-2r-asr1(z)>=0, |y|-2r-asr1(z)>=0
        move.w 46(a0),d0
        lsl.w #5,d0
        lea M4LevelShapeDescriptors,a3
        adda.w d0,a3
        move.w 26(a3),d4 ;size
        move.w 60(a0),d0
        add.w d4,d0
        bmi M4LvwDrawSkip
        jsr M4SpriteEntry ;mssprite objects skip the lateral cone test (01:AEBB)
        beq.s M4LvwConeTest
        ; Asteroid sprite shapes without ssprite (sflags $20): their face $50
        ; s_sprite is a stub in rev0, the object collides but is not drawn
        ; (hard on AF5D, stage-asteroid1.md section 3.1). Only these shapes are
        ; gated: the Corneria effect creators do not all model sflags $20.
        move.w 46(a0),d0
        cmpi.w #M4_FX_ASTEROID_S,d0
        blo M4LvwConeDone
        cmpi.w #M4_FX_BLACKHOLE,d0
        bhi M4LvwConeDone
        btst #F2_SPRITE,48(a0)
        beq M4LvwDrawSkip
        bra M4LvwConeDone
M4LvwConeTest:
        add.w d4,d4
        move.w 60(a0),d5
        asr.w #1,d5
        add.w d5,d4 ;2r + asr1(z)
        move.w 56(a0),d0
        bpl.s M4LvwConeX
        neg.w d0
M4LvwConeX:
        sub.w d4,d0
        bpl M4LvwDrawSkip
        move.w 58(a0),d0
        bpl.s M4LvwConeY
        neg.w d0
M4LvwConeY:
        sub.w d4,d0
        bpl M4LvwDrawSkip
M4LvwConeDone:
        ; SVP coordinate contract |v| < 16384: farther objects are not drawn
        ; (original saturates z at 12287 and still draws them, tiny).
        cmpi.w #12287,60(a0)
        bgt M4LvwDrawSkip
        ; and |x|, |y| <= 12287 (mssprite objects skip the lateral cone test:
        ; beyond it they are off screen for every z <= 12287)
        move.w 56(a0),d0
        bpl.s M4LvwContractX
        neg.w d0
M4LvwContractX:
        cmpi.w #12287,d0
        bhi M4LvwDrawSkip
        move.w 58(a0),d0
        bpl.s M4LvwContractY
        neg.w d0
M4LvwContractY:
        cmpi.w #12287,d0
        bhi M4LvwDrawSkip
        ; SVP9 projects every vertex with z >= 32 in 16 bits: with r = size,
        ; zmin = max(32, z - r), require |x| + r and |y| + r < 64 zmin
        ; (beyond, the object is off screen at any of its sizes)
        moveq #0,d2
        move.w 26(a3),d2 ;r
        move.w 60(a0),d1
        add.w d2,d1
        cmpi.w #32,d1
        blt.s M4LvwContractDone ;every vertex behind the near plane
        move.w 60(a0),d1
        sub.w d2,d1
        cmpi.w #32,d1
        bge.s M4LvwContractZ
        moveq #32,d1
M4LvwContractZ:
        ext.l d1
        asl.l #6,d1
        move.w 56(a0),d0
        bpl.s M4LvwContractPx
        neg.w d0
M4LvwContractPx:
        ext.l d0
        add.l d2,d0
        cmp.l d1,d0
        bge M4LvwDrawSkip
        move.w 58(a0),d0
        bpl.s M4LvwContractPy
        neg.w d0
M4LvwContractPy:
        ext.l d0
        add.l d2,d0
        cmp.l d1,d0
        bge M4LvwDrawSkip
M4LvwContractDone:
        move.w 18(a3),d3 ;sh_sortz
        add.w 60(a0),d3
        btst #0,45(a0) ;atgnd
        beq.s M4LvwSortz
        addi.w #15000,d3
M4LvwSortz:
        cmpi.w #40,M4_SHIP_DRAW_COUNT
        bhs.s M4LvwDrawFull
        jsr M4IntroSceneSortAt
        bra M4LvwDrawSkip
M4LvwDrawFull:
        addq.w #1,M4_LVW_DROPPED
M4LvwDrawSkip:
        bra M4LvwDrawNext
M4LvwDrawEnd:
        if def(M4_GRAPHICS117)
        jmp G117H106DrawEnd
        else
        jsr M4LvwShadows
        endif
M4LvwDrawEndBody:
        if def(M4_PROFILE)
        move.l d0,-(sp)
        moveq #1,d0
        jsr M4ProfMark
        move.l (sp)+,d0
        endif
        rts

; After the faces were built (mesh colours consumed the hit flashes) and
; while the SVP runs cmd10: hit flash clear, collisions (init_strats_ram_l,
; consumed next tick) and z-remove (alienflags_l 02:F4F1). Same order and
; inputs as after the draw; none of them touches the drawing buffers.
M4_GEO_OVERLAP equ $fff2fa ;.l routine run by the cmd10 request (0 = none)
M4LevelOverlapWork:
        movem.l d7/a0,-(sp)
        lea M4_LV_OBJ,a0 ;the draw consumes the hit flash (sflags hitflash)
        moveq #M4_LV_SLOTS-1,d7
M4LvwFlashClear:
        andi.w #$fffb,30(a0)
        bclr #7,49(a0)
        lea 64(a0),a0
        dbra d7,M4LvwFlashClear
        movem.l (sp)+,d7/a0
        jsr M4LevelCollisions ;init_strats_ram_l: consumed next tick
        jsr M4LevelZRemove ;alienflags_l 02:F4F1 runs after the draw
        rts

; Shadow pass (build/research/shadow.md): mdo_3d_display draws every shadow
; before the normal pass (01:AC44) when m_pfm (playerflymode) & 8. Objects of
; the draw list (not invisible) with asf_shadow: the object's own shape,
; flattened (SVP9 pose bit), at big_s = (rel.x, shadowheight - viewposy,
; rel.z).W (mallrotzsort 01:B19A, fq products, 16-bit wrap), with its own
; cone test and z, all faces colour HL $09 (01:9063). Shadows go to the front
; of the draw list in the order of their objects (sortz descending).
; Corneria shadowheight 0 (03:915D). Proxies copy the object (64 bytes) with
; the shadow view position and byte 50 = 1. Only level shapes (no sprite or
; effect kinds).
M4_LVW_SHADOWS equ $ff5800 ;8 proxies x 64 bytes (intro background decode area)
M4LvwShadows:
        movem.l d0-d7/a0-a5,-(sp)
        moveq #0,d6 ;shadows in the front block
        btst #3,M4_LP_FLYMODE
        beq M4LvwShadowDone
        lea M4_LVW_SHADOWS,a5
        jsr M4LcOrder
        movea.l a2,a4
M4LvwShadowNext:
        move.l (a4)+,d0
        beq M4LvwShadowDone
        movea.l d0,a0
        cmpi.b #M4_LEVEL_KIND+2,21(a0)
        blo M4LvwShadowNext
        btst #1,49(a0)
        bne M4LvwShadowNext
        btst #F2_SHADOW,48(a0)
        beq M4LvwShadowNext
        cmpi.w #8,d6
        bhs M4LvwShadowNext
        move.w 46(a0),d0
        lsl.w #5,d0
        lea M4LevelShapeDescriptors,a3
        adda.w d0,a3
        lea M4_LVW_SCR,a2
        move.w (a0),d0
        sub.w M4_LVW_POS,d0
        move.w d0,(a2)
        moveq #0,d0 ;shadowheight
        sub.w M4_LVW_POS+2,d0
        move.w d0,2(a2)
        move.w 4(a0),d0
        sub.w M4_LVW_POS+4,d0
        move.w d0,4(a2)
        move.l a0,-(sp)
        movea.l a2,a0
        lea M4_LVW_W,a1
        lea M4_LVW_ARM,a2
        jsr M4LvwRowTimes
        movea.l (sp)+,a0
        movem.w M4_LVW_ARM,d1-d3
        move.w 26(a3),d4 ;cone with the shadow's z and the shape size
        move.w d3,d0
        add.w d4,d0
        bmi M4LvwShadowNext
        add.w d4,d4
        move.w d3,d5
        asr.w #1,d5
        add.w d5,d4
        move.w d1,d0
        bpl.s M4LvwShadowX
        neg.w d0
M4LvwShadowX:
        sub.w d4,d0
        bpl M4LvwShadowNext
        move.w d2,d0
        bpl.s M4LvwShadowY
        neg.w d0
M4LvwShadowY:
        sub.w d4,d0
        bpl M4LvwShadowNext
        cmpi.w #12287,d3
        bgt M4LvwShadowNext
        cmpi.w #40,M4_SHIP_DRAW_COUNT
        bhs M4LvwShadowFull
        movea.l a0,a1 ;proxy = object, shadow view position, marker
        movea.l a5,a2
        moveq #15,d0
M4LvwShadowCopy:
        move.l (a1)+,(a2)+
        dbra d0,M4LvwShadowCopy
        movem.w d1-d3,56(a5)
        move.b #1,50(a5)
        move.w 18(a3),d3 ;key: the object's own sortz
        add.w 60(a0),d3
        btst #0,45(a0)
        beq.s M4LvwShadowKey
        addi.w #15000,d3
M4LvwShadowKey:
        lea M4_SHIP_DRAW_LIST,a2 ;position in the front block (descending)
        moveq #0,d2
M4LvwShadowFind:
        cmp.w d6,d2
        beq.s M4LvwShadowInsert
        move.w 4(a2),d0
        subq.w #1,d0
        sub.w d3,d0
        bmi.s M4LvwShadowInsert
        lea 6(a2),a2
        addq.w #1,d2
        bra.s M4LvwShadowFind
M4LvwShadowInsert:
        move.w M4_SHIP_DRAW_COUNT,d0
        move.w d0,d1
        mulu.w #6,d1
        lea M4_SHIP_DRAW_LIST,a1
        adda.w d1,a1 ;end of the list
        sub.w d2,d0
        beq.s M4LvwShadowStore
        subq.w #1,d0
M4LvwShadowShift:
        move.l -6(a1),(a1)
        move.w -2(a1),4(a1)
        subq.l #6,a1
        dbra d0,M4LvwShadowShift
M4LvwShadowStore:
        move.l a5,(a2)
        move.w d3,4(a2)
        addq.w #1,M4_SHIP_DRAW_COUNT
        lea 64(a5),a5
        addq.w #1,d6
        bra M4LvwShadowNext
M4LvwShadowFull:
        addq.w #1,M4_LVW_DROPPED
        bra M4LvwShadowNext
M4LvwShadowDone:
        movem.l (sp)+,d0-d7/a0-a5
        rts

; viewfloat table 06:BADA (36 WORDs).
M4LevelViewFloat:
        incbin '../build/M4LevelViewFloat.bin'
M4LevelSin16:
        incbin '../build/level-sin16.bin'
        even
