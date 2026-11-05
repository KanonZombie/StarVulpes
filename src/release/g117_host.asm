; graphics117 68000 host code, lots 106..117 (tools/hw-boot/make-round45.py,
; 48, 49, 53, 54, 56; ROUND53..56.md). Every routine is entered from a JMP
; placed at the start of the original routine (if def(M4_GRAPHICS117) in
; its source) and resumes at the label after the displaced instructions.
; 106 (make-round45.py): remove repeated camera work and CPU producer overhead.
G117H106Collision:
        tst.b M4_SCREEN
        bne.s G117H106CollisionOriginal
        movem.l d0/a0-a1,-(sp)
        lea G117H106Aabb(pc),a0
        lea G117_AABB_RAM,a1
        moveq #(G117H106AabbEnd-G117H106Aabb)/2-1,d0
G117H106CollisionCopy:
        move.w (a0)+,(a1)+
        dbra d0,G117H106CollisionCopy
        movem.l (sp)+,d0/a0-a1
G117H106CollisionOriginal:
        movem.l d0-d7/a0-a6,-(sp) ;displaced from M4LevelCollisions
        clr.w M4_LC_PAIRS
        jmp M4LevelCollisionsBody
G117H106AabbDispatch:
        tst.b M4_SCREEN
        bne.s G117H106AabbCPU
        jmp G117_AABB_RAM
G117H106AabbCPU:
        movem.l d0-d3,-(sp)      ;displaced from M4LcAabb
        moveq #4,d3
        jmp M4LcAabbBody

; Only this draw-list producer writes the cache epoch, after coordinates.
G117H106DrawEnd:
        move.w M4_LV_GAMEFRAME,G117_EPOCH
        jsr M4LvwShadows         ;displaced from M4LvwDrawEnd
        jmp M4LvwDrawEndBody
G117H106ViewXZ:
        tst.b M4_SCREEN
        bne.s G117H106ViewCPU
        move.w M4_LV_GAMEFRAME,d0
        cmp.w G117_EPOCH,d0
        bne.s G117H106ViewCPU
        tst.b 21(a0)
        beq.s G117H106ViewCPU
        btst #1,49(a0)
        bne.s G117H106ViewCPU
        btst #0,X_TEXTFL(a0)
        bne.s G117H106ViewCPU
        move.w 60(a0),d0
        move.w 56(a0),d2
        rts
G117H106ViewCPU:
        jmp M4LvViewXZ

G117H106Sin16:
        tst.b d0
        bne.s G117H106SinCPU
        movem.l d1/a0,-(sp)
        move.w d0,d1
        lsr.w #7,d1
        lea M4LevelSin16,a0
        andi #$ef,ccr ;zero interpolant: original ADD has carry/X zero
        move.w (a0,d1.w),d0
        movem.l (sp)+,d1/a0
        rts
G117H106SinCPU:
        movem.l d1-d2/a0,-(sp)   ;displaced from M4LvwSin16
        lea M4LevelSin16,a0
        jmp M4LvwSin16Body

; Same32-byte record and full-buffer behavior, no DRAM read/modify/write zeros.
G117H106Radio:
        move.l d0,-(sp)
        move.w M4_FACE_COUNT,d0
        cmpi.w #512,d0
        bhs.s G117H106RadioFull
        jsr M4FaceSlot
        moveq #0,d0
        move.l d0,(a2)
        move.w d0,4(a2)
        move.w d1,d0
        ori.w #$8000,d0
        move.w d0,6(a2)
        move.w d2,8(a2)
        move.w d3,10(a2)
        moveq #0,d0
        move.l d0,12(a2)
        move.l d0,16(a2)
        move.l d0,20(a2)
        move.l d0,24(a2)
        move.l d0,28(a2)
        addq.w #1,M4_FACE_COUNT
        move.l (sp)+,d0
        rts
G117H106RadioFull:
        jmp M4RadioRecordFull

; Position-independent RAM copy. Same WORD abs($8000), wrapped sums and N test.
G117H106Aabb:
        movem.l d0-d1,-(sp)
        lea M4_LC_POS,a6
        move.w M4_LC_EXT+4,d0
        add.w M4_LC_BEXT+4,d0
        move.w M4_LC_BPOS+4,d1
        sub.w M4_LC_POS+4,d1
        bpl.s G117H106AbsZ
        neg.w d1
G117H106AbsZ:
        sub.w d0,d1
        bpl.s G117H106Miss
        move.w M4_LC_EXT,d0
        add.w M4_LC_BEXT,d0
        move.w M4_LC_BPOS,d1
        sub.w M4_LC_POS,d1
        bpl.s G117H106AbsX
        neg.w d1
G117H106AbsX:
        sub.w d0,d1
        bpl.s G117H106Miss
        move.w M4_LC_EXT+2,d0
        add.w M4_LC_BEXT+2,d0
        move.w M4_LC_BPOS+2,d1
        sub.w M4_LC_POS+2,d1
        bpl.s G117H106AbsY
        neg.w d1
G117H106AbsY:
        sub.w d0,d1
        bpl.s G117H106Miss
        moveq #0,d0
        bra.s G117H106AabbOut
G117H106Miss:
        moveq #1,d0
G117H106AabbOut:
        movem.l (sp)+,d0-d1
        rts
G117H106AabbEnd:

        g117at $15d998
; 109 (make-round48.py): exact axis-specialized native Q15 camera matrices.
G117H109Rotation:
        tst.w d2
        bne G117H109RotationReference
        tst.w d1
        beq G117H109RotationX
        tst.w d0
        beq G117H109RotationY
G117H109RotationReference:
        movem.l d0-d7/a0,-(sp)   ;displaced from M4LvwRotation
        lea M4_LVW_TRIG,a0
        jmp M4LvwRotationBody
G117H109RotationX:
        movem.l d0-d7/a0,-(sp)
        lea M4_LVW_TRIG,a0
        move.w d0,d5
        jsr M4LvwSin16
        move.w d0,(a0)
        move.w d5,d0
        addi.w #$4000,d0
        jsr M4LvwSin16
        move.w d0,2(a0)
        move.l #$00007fff,4(a0)
        move.l #$00007fff,8(a0)
        lea M4_LVW_R,a1
        move.l #$7ffe0000,(a1)
        clr.l 4(a1)
        move.w (a0),d0
        neg.w d0
        move.w d0,10(a1)
        clr.w 12(a1)
        move.w (a0),d0
        move.w #$7ffe,d1
        jsr M4LvwFq
        move.w d0,14(a1)
        move.w 2(a0),d0
        move.w #$7fff,d1
        jsr M4LvwFq
        move.w d0,8(a1)
        move.w d0,16(a1)
        movem.l (sp)+,d0-d7/a0
        rts
G117H109RotationY:
        movem.l d0-d7/a0,-(sp)
        lea M4_LVW_TRIG,a0
        move.w d1,d6
        move.l #$00007fff,(a0)
        move.w d1,d0
        jsr M4LvwSin16
        move.w d0,4(a0)
        move.w d6,d0
        addi.w #$4000,d0
        jsr M4LvwSin16
        move.w d0,6(a0)
        move.l #$00007fff,8(a0)
        lea M4_LVW_R,a1
        clr.w 2(a1)
        clr.w 6(a1)
        move.w #$7ffe,8(a1)
        clr.w 10(a1)
        clr.w 14(a1)
        move.w 4(a0),d0
        move.w #$7fff,d1
        jsr M4LvwFq
        move.w d0,4(a1)
        neg.w d0
        move.w d0,12(a1)
        move.w 6(a0),d0
        move.w #$7fff,d1
        jsr M4LvwFq
        move.w d0,(a1)
        move.w d0,16(a1)
        movem.l (sp)+,d0-d7/a0
        rts

        g117at $15daba
; 110 (make-round49.py): M4VRTiltBuild with the line loops unrolled by eight.
G117H110TiltBuild:
        movem.l d0-d7/a0-a1,-(sp)
        movea.l M4VR_TILT_PEND,a0
        move.w M4VR_ARG_TILT,d0
        moveq #0,d6 ;mirror
        move.w d0,d1
        bpl.s G117H110TiltAbs
        neg.w d1
        moveq #1,d6
G117H110TiltAbs:
        lsr.w #8,d1
        andi.w #7,d1
        lsl.w #5,d1
        lea M4TiltTables,a1
        adda.w d1,a1
        move.w M4VR_PEND_HSCROLL,d2 ;H = -B
        move.w d2,d3
        neg.w d3
        andi.w #7,d3 ;f = B & 7
        move.w d2,d4
        andi.w #15,d4 ;sh = (-B) & 15
        move.w M4VR_PEND_SCROLL,d5
        subi.w #16,d5 ;bg2scroll
        moveq #0,d7
G117H110TiltColumn:
        move.w d7,d1
        lsl.w #4,d1
        addq.w #8,d1
        add.w d4,d1 ;centre x
        cmpi.w #255,d1
        bls.s G117H110TiltCentre
        move.w #255,d1
G117H110TiltCentre:
        add.w d3,d1
        lsr.w #3,d1 ;slot
        subq.w #1,d1 ;table entry (slot 0: hidden column, entry 0)
        bpl.s G117H110TiltEntryLow
        moveq #0,d1
G117H110TiltEntryLow:
        cmpi.w #31,d1
        bls.s G117H110TiltEntry
        moveq #31,d1
G117H110TiltEntry:
        tst.w d6
        beq.s G117H110TiltDirect
        neg.w d1
        addi.w #31,d1
G117H110TiltDirect:
        moveq #0,d0
        move.b (a1,d1.w),d0
        add.w d5,d0
        andi.w #511,d0
        move.w d0,(a0)+
        addq.w #1,d7
        cmpi.w #16,d7
        bne.s G117H110TiltColumn
        move.w M4VR_ARG_TILT,d0
        not.w d0
        asr.w #7,d0 ;s
        move.w d0,d1
        muls.w #112,d1 ;k*s, k = 112 at line 0
        lsl.l #8,d1
        move.w d0,d3
        ext.l d3
        lsl.l #8,d3
        moveq #13,d7
G117H110TiltUpper:
        rept 8
        move.l d1,d4
        swap d4 ;a_k in low WORD
        move.w d2,d5
        sub.w d4,d5 ;-(B + a_k)
        andi.w #$3ff,d5
        move.w d5,(a0)+
        sub.l d3,d1
        endr
        dbra d7,G117H110TiltUpper
        move.l d3,d1 ;k = 1 at line 112
        moveq #13,d7
G117H110TiltLower:
        rept 8
        move.l d1,d4
        swap d4
        move.w d2,d5
        add.w d4,d5
        addq.w #1,d5 ;-(B - a_k - 1)
        andi.w #$3ff,d5
        move.w d5,(a0)+
        add.l d3,d1
        endr
        dbra d7,G117H110TiltLower
        movem.l (sp)+,d0-d7/a0-a1
        rts

        g117at $15dc84
; 114 (make-round53.py): start raster(k-1) while the CPU writes poses/jobs(k);
; publish READY last.
G117H114Prepare:
        movem.l d1-d7/a0-a6,-(sp) ;displaced from M4IntroGeometryPrepare
        jsr M4BspModeSelect
        jsr M4ChainSelect
        clr.b G117_ACTIVE
        rept 5                   ;115 removed the level-only screen test in place
        nop
        endr
        tst.b M4_CHAIN_ACTIVE
        beq G117H114PrepareOriginal
        cmpi.w #40,M4_SHIP_DRAW_COUNT
        bhi G117H114PrepareOriginal
        cmpi.w #1,M4P_STATE
        bne G117H114PrepareOriginal
        tst.w M4VR_ERROR
        bne G117H114PrepareOriginal
        tst.w M4VR_COMPLETE
        bne G117H114PrepareOriginal
        move.w #1,M4_CHAIN_HDR
        clr.w M4_CHAIN_HDR+6
        clr.w G117_READY
        move.w #$4552,G117_MAGIC
        move.l M4_GEO_VP,MAILBOX+26
        move.w #13,MAILBOX+8
        move.w M4P_COUNT,MAILBOX+20
        move.w M4P_FLAG,MAILBOX+22
        addq.w #1,TEXT_VIDEO_DIAG+6
        move.w TEXT_VIDEO_DIAG+6,d0
        not.w d0
        move.w d0,MAILBOX+6
        move.w d0,ACK_SEQUENCE
        move.w #$dead,MAILBOX+4
        move.w #$dead,MAILBOX+16
        move.w #3,M4P_STATE
        move.b #1,G117_ACTIVE
        move.w XST_STATUS,d0
        move.w TEXT_VIDEO_DIAG+6,XST
G117H114PrepareOriginal:
        jmp M4IntroGeometryPrepareBody
G117H114StoreGeo:
        tst.b G117_ACTIVE
        bne.s G117H114StoreGeoDone
        move.w d0,MAILBOX+20
G117H114StoreGeoDone:
        jmp M4GeometryNoJobsStored
G117H114StoreFace:
        tst.b G117_ACTIVE
        bne.s G117H114StoreFaceDone
        move.w d0,MAILBOX+20
G117H114StoreFaceDone:
        jmp M4GeometryClipRunStored
G117H114Join:
        tst.b G117_ACTIVE
        beq.s G117H114JoinReference
        lea M4_GEO_VIEW,a0
        lea M4_CHAIN_VIEW,a1
        moveq #4,d1
G117H114JoinView:
        move.l (a0)+,(a1)+
        dbra d1,G117H114JoinView
        move.w M4_GEO_COUNT,M4_CHAIN_HDR+2
        move.w M4_FACE_COUNT,M4_CHAIN_HDR+4
        move.w #$5254,G117_READY
        clr.b G117_ACTIVE
        moveq #13,d0
        jmp M4GeometryNoHook
G117H114JoinReference:
        clr.w G117_MAGIC
        lea M4_GEO_VIEW,a0       ;displaced from M4ChainRequest
        jmp M4ChainRequestBody
G117H114AbortReturn:
        bsr.s G117H114AbortIfNeeded
        movem.l (sp)+,d1-d7/a0-a6
        rts
G117H114AbortScene:
        move.w M4_MESH_ERROR,d0
        bsr.s G117H114AbortIfNeeded
        rts
G117H114AbortIfNeeded:
        tst.w d0
        beq.s G117H114AbortDone
        tst.b G117_ACTIVE
        beq.s G117H114AbortDone
        move.w #$ffff,G117_READY
        clr.b G117_ACTIVE
G117H114AbortDone:
        tst.w d0
        rts

        g117at $15de1c
; 115 (make-round54.py): select the common SVP chain by its inputs/ownership,
; not by scene.
G117H115Select:
        move.b M4_CHAIN_ACTIVE,d1
        clr.b M4_CHAIN_ACTIVE
        tst.b M4_BSP_SVP
        beq.s G117H115Done
        tst.w INTRO_CAPTURE
        bne.s G117H115Done
        cmpi.w #2,M4P_STATE ;a separately running raster retains its inputs
        beq.s G117H115Done
        cmpi.l #'OVLT',M4_OVL_MAGIC
        bne.s G117H115Inputs
        btst #4,M4_OVL_CTL ;explicit same-ROM reference
        bne.s G117H115Done
G117H115Inputs:
        tst.w M4_GEO_VIEW ;view scenes can have radio/text jobs without meshes
        bne.s G117H115Enable
        tst.w M4_SHIP_DRAW_COUNT
        bne.s G117H115Enable
        tst.w M4P_STATE ;empty text-only images need no geometry chain
        beq.s G117H115Done
G117H115Enable:
        move.b #1,M4_CHAIN_ACTIVE
G117H115Done:
        jmp M4ChainSelectDone ;retain the original leaving-chain flush

; Scenes with a CPU overlap callback already seal in M4OvlWindow.
; Other scenes seal raster(k-1) while geometry/BSP(k) runs, before the ACK.
G117H115NoHook:
        cmpi.w #3,M4P_STATE
        bne.s G117H115Replay
        tst.l M4_GEO_OVERLAP
        bne.s G117H115Replay
        movem.l d0-d7/a0-a6,-(sp)
        jsr M4PipeFlush
        tst.w d0
        beq.s G117H115Restore
        move.l d0,(sp) ;propagate the original flush error through Request
        movem.l (sp)+,d0-d7/a0-a6
        rts
G117H115Restore:
        movem.l (sp)+,d0-d7/a0-a6
G117H115Replay:
        tst.l M4_GEO_OVERLAP     ;displaced from M4GeometryNoHook
        jmp M4GeometryNoHookBody

        g117at $15deb6
; 117 (make-round56.py): per-pass immutable cache of Z, Z extent and
; descriptor for every listed object; the sweep runs from RAM.
G117H117Cache:
        tst.b M4_SCREEN
        bne G117H117CacheOriginal
        movem.l d0-d4/a0-a4,-(sp)
        cmpi.l #'RCV1',G117_SWEEP_MAGIC
        beq.s G117H117CachedCode
        lea G117SweepImage,a0
        lea G117_SWEEP_RAM,a1
        move.w #(G117SweepImageEnd-G117SweepImage)/2-1,d0
G117H117Copy:
        move.w (a0)+,(a1)+
        dbra d0,G117H117Copy
        move.l #'RCV1',G117_SWEEP_MAGIC
G117H117CachedCode:
        lea M4_LC_LIST,a4
        move.w d6,d4
        subq.w #1,d4
        bmi.s G117H117CacheDone
G117H117Next:
        movea.l (a4)+,a0
        jsr M4LcDescriptor
        move.w a0,d0
        andi.w #$0fff,d0
        lsr.w #3,d0
        lea G117_LC_CACHE,a1
        adda.w d0,a1
        move.w 4(a0),(a1)+
        move.w 24(a3),(a1)+
        move.l a3,(a1)
        dbra d4,G117H117Next
G117H117CacheDone:
        movem.l (sp)+,d0-d4/a0-a4
G117H117CacheOriginal:
        move.w d6,M4_LC_COUNT    ;displaced from M4LcBuildDone
        jmp M4LcBuildDoneBody
G117H117Dispatch:
        tst.b M4_SCREEN
        bne.s G117H117Reference
        jmp G117_SWEEP_RAM
G117H117Reference:
        jmp G117SweepRef
