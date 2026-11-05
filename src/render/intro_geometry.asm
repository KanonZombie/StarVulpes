; Own host coordination only. SVP9 accepts model IDs and poses, SVP10
; consumes ordered face references. No CPU matrix/vertex/projection/clip work.
M4_GEO_INPUT equ $301800
M4_GEO_OUTPUT equ $30f020
M4_FACE_INPUT equ $319040
M4_GEO_EXPECT equ $ff9ae0
M4_GEO_VP equ $fff830 ;.w x, .w y vanishing point offset from the GSU 112/96 centre
M4_FACE_COUNT equ $ff9ae2
M4_GEO_CURRENT equ $ff9ae4
M4_GEO_COUNT equ $ff9aec
M4_GEO_DIAG equ $ff9b00
M4_GEOM_PHASES equ $ff9250 ;CPU logic/poses,SVP9,CPU face order,SVP10
M4_GEOM_WORK equ $ff9b20 ;pending image; copied only on complete publication

M4_GEO_VIEW equ $301c00 ;DRAM: view flag + W (9 WORDs) for SVP9 (level only)
M4_GEO_GRID equ $301c20 ;DRAM: dotsflag, start xyz, px, pz (SVP_Grid in cmd8)
M4IntroGeometryInit:
        clr.b M4_CHAIN_ACTIVE
        clr.l M4_GEO_HOOK9 ;cold RAM is undefined; startup cmd9 tests precede Prepare
        clr.w M4_GEO_VIEW ;intro/title: object matrices without a view
        clr.l M4_GEO_OVERLAP ;no level work in the cmd10 request
        clr.w M4_GEO_GRID ;no ground dot grid
        jsr M4LevelStarsOff ;nor stars
        lea M4_GEO_DIAG,a0
        moveq #7,d0
M4GeometryClearDiag:
        clr.l (a0)+
        dbra d0,M4GeometryClearDiag
        move.w #$a55a,M4_GEO_INPUT-2
        move.w #$a55a,M4_GEO_INPUT+720
        move.w #$a55a,M4_GEO_OUTPUT-2
        move.w #$a55a,M4_GEO_OUTPUT+40960
        move.w #$a55a,M4_FACE_INPUT-2
        move.w #$a55a,M4_FACE_INPUT+16384
        move.l #'M4GE',M4_GEO_DIAG
        rts

; M4_BSP_SVP: faces by SVP jobs (cmd12) unless the test control (valid only with the OVLT magic, M4_OVL_CTL
; bit3) selects the 68000 reference; or the build defines M4_BSP_CPU.
M4BspModeSelect:
        move.b #1,M4_BSP_SVP
        if def(M4_BSP_CPU)
        clr.b M4_BSP_SVP
        endif
        cmpi.l #'OVLT',M4_OVL_MAGIC
        bne.s M4BspModeDone
        btst #3,M4_OVL_CTL
        beq.s M4BspModeDone
        clr.b M4_BSP_SVP
M4BspModeDone:
        rts

M4IntroGeometryPrepare:
        if def(M4_GRAPHICS117)
        jmp G117H114Prepare
        nop
        nop
        nop
        else
        movem.l d1-d7/a0-a6,-(sp)
        bsr M4BspModeSelect
        bsr M4ChainSelect
        endif
M4IntroGeometryPrepareBody:
        clr.w M4_FACE_COUNT
        clr.l M4_GEO_HOOK9
        clr.l M4_GEOM_WORK
        clr.l M4_GEOM_WORK+4
        move.w M4_SHIP_DRAW_COUNT,d7
        move.w d7,M4_GEO_COUNT
        move.w d7,M4_GEO_DIAG+4
        cmpi.w #40,d7
        bhi M4GeometryBad
        tst.w d7
        bne.s M4GeometryHasObjects
        tst.w M4_GEO_VIEW ;level path without objects (route map): an empty
        beq M4GeometryGood ;cmd9 keeps the cmd9/cmd10 sequence for its texts
        bra.w M4GeometryRequestNow
M4GeometryHasObjects:
        lea M4_GEO_INPUT,a1
        lea M4_SHIP_DRAW_LIST,a2
        subq.w #1,d7
M4GeometryPose:
        movea.l (a2),a0
        moveq #0,d0
        move.b 21(a0),d0
        cmpi.w #3,d0
        blo.s M4GeometryShip
        subq.w #2,d0
        bra.s M4GeometryKind
M4GeometryShip:
        moveq #0,d0
M4GeometryKind:
        tst.w M4_GEO_VIEW
        beq.s M4GeometryKindStore
        move.l a3,-(sp)
        move.w 46(a0),d0
        lsl.w #5,d0
        lea M4LevelShapeDescriptors,a3
        move.w 14(a3,d0.w),d0
        movea.l (sp)+,a3
        tst.b 50(a0) ;level shadow proxy (level_view.asm): flattened pose
        beq.s M4GeometryKindStore
        ori.w #$8000,d0 ;separate flag from model ids >= 256
M4GeometryKindStore:
        move.w d0,(a1)+
        moveq #0,d0
        move.b 18(a0),d0
        cmpi.b #14,21(a0)
        blo.s M4GeometryAnimationReady
        move.b 16(a0),d0
        ; level shapes: own animframe only with bit7, else gameframe&127
        ; (marioshowview 02:F581 draw-list entry +$19)
        cmpi.b #M4_LEVEL_KIND+2,21(a0)
        blo.s M4GeometryAnimationReady
        tst.b d0
        bmi.s M4GeometryAnimationReady
        move.w M4_SCENE_TICK,d0
        andi.w #127,d0
M4GeometryAnimationReady:
        move.w d0,(a1)+
        moveq #0,d0
        move.b 19(a0),d0
        move.w d0,(a1)+
        tst.w M4_GEO_VIEW
        beq.s M4GeometryIntroPose
        move.l 56(a0),(a1)+ ;level: rel.W view coordinates
        move.w 60(a0),(a1)+
        bra.s M4GeometryPoseAngles
M4GeometryIntroPose:
        move.l (a0),(a1)+
        move.w 4(a0),d0
        sub.w INTRO_CAMERA+8,d0
        move.w d0,(a1)+
M4GeometryPoseAngles:
        moveq #0,d0
        move.b 12(a0),d0
        move.w d0,(a1)+
        move.b 13(a0),d0
        move.w d0,(a1)+
        move.b 14(a0),d0
        move.w d0,(a1)+
        lea 6(a2),a2
        dbra d7,M4GeometryPose
M4GeometryRequestNow:
        tst.b M4_BSP_SVP
        beq.s M4GeometryNoJobs
        move.l #M4_GEO_OUTPUT,M4_GEO_CURRENT ;the jobs of the objects are written during the cmd9 request
        move.l #M4IntroSceneDrawObjects,M4_GEO_HOOK9
M4GeometryNoJobs:
        move.w M4_CLOCK,d0
        move.w d0,M4_GEO_DIAG+10
        sub.w M4_PHASE_STAMP,d0
        move.w d0,M4_GEOM_WORK
        move.w M4_GEO_COUNT,d0
        move.w d0,M4_GEO_EXPECT
        if def(M4_GRAPHICS117)
        jmp G117H114StoreGeo ;no early-raster mailbox overwrite
        else
        move.w d0,MAILBOX+20
        endif
M4GeometryNoJobsStored:
        tst.b M4_CHAIN_ACTIVE
        beq.s M4GeometrySeparate
        clr.l M4_GEO_HOOK9
        bsr M4IntroSceneDrawObjects ;jobs need poses, never the SVP9 results
        bra M4GeometryGood ;SVP9 runs inside cmd13, submitted by Clip
M4GeometrySeparate:
        moveq #9,d0
        bsr M4IntroGeometryRequest
        tst.w d0
        bne M4GeometryReturn
        move.w TEXT_VIDEO_DIAG+6,M4_GEO_DIAG+12
        move.w MAILBOX+4,M4_GEO_DIAG+16
        move.w M4_CLOCK,d0
        move.w d0,d1
        sub.w M4_GEO_DIAG+10,d0
        move.w d0,M4_GEOM_WORK+2
        move.w d1,M4_GEO_DIAG+10
        cmpi.w #$a55a,M4_GEO_INPUT-2
        bne M4GeometryBad
        cmpi.w #$a55a,M4_GEO_INPUT+720
        bne M4GeometryBad
        cmpi.w #$a55a,M4_GEO_OUTPUT-2
        bne M4GeometryBad
        cmpi.w #$a55a,M4_GEO_OUTPUT+40960
        bne M4GeometryBad
        bsr M4PipeKick ;previous tick's cmd8 runs during this tick's BSP order
        move.l #M4_GEO_OUTPUT,M4_GEO_CURRENT
M4GeometryGood:
        moveq #0,d0
        bra M4GeometryReturn
M4GeometryBad:
        moveq #-2,d0 ;error code
M4GeometryReturn:
        if def(M4_GRAPHICS117)
        jmp G117H114AbortReturn
        else
        movem.l (sp)+,d1-d7/a0-a6
        rts
        endif

; Prepared geometry remains owned by DSP/job until the complete image publishes.
; Read only visibility flags for original BSP traversal; face packets reference
; the DSP output directly. nearZ rejection was computed by the SVP.
M4IntroGeometryLoad:
        movea.l M4_GEO_CURRENT,a1
        move.w 22(a1),M4_MESH_NEAR
        move.w 20(a1),d1
        cmpi.w #64,d1
        bhi.s M4GeometryLoadBad
        tst.w d1
        beq.s M4GeometryLoadDone
        lea 872(a1),a1 ;16 header +84*5 vertex WORDs, then visibility
        lea M4_MESH_VIS,a2
        subq.w #1,d1
M4GeometryVisibility:
        move.w (a1)+,d0
        move.b d0,(a2)+
        dbra d1,M4GeometryVisibility
M4GeometryLoadDone:
        moveq #0,d0
        rts
M4GeometryLoadBad:
        move.w #$E101,M4_MESH_ERROR ;error site 1
        moveq #-3,d0 ;error code
        rts

; a4=face record; current DSP object is stable. Counts/materials/BSP only.
M4IntroGeometryFace:
        move.w M4_FACE_COUNT,d0
        cmpi.w #512,d0
        bhs M4GeometryFaceBad
        lsl.w #5,d0
        lea M4_FACE_INPUT,a1
        adda.w d0,a1
        move.w (a4),(a1)
        moveq #0,d0
        move.b M4_MESH_COLOUR,d0
        move.w d0,2(a1)
        move.l M4_GEO_CURRENT,d0
        subi.l #$300000,d0
        lsr.l #1,d0
        move.w d0,4(a1)
        move.w M4_MESH_KIND,6(a1)
        clr.l 8(a1)
        clr.l 12(a1)
        cmpi.w #2,M4_MESH_KIND
        beq.s M4GeometryExplosionFace
        cmpi.w #10,M4_MESH_KIND
        bne.s M4GeometryFaceIndices
M4GeometryExplosionFace:
        movea.l M4_MESH_OBJECT,a0
        moveq #0,d0
        move.b 19(a0),d0
        move.w d0,8(a1)
        move.l 14(a4),10(a1)
        move.w 18(a4),14(a1)
M4GeometryFaceIndices:
        clr.l 16(a1)
        clr.l 20(a1)
        clr.l 24(a1)
        clr.l 28(a1)
        move.w (a4),d1
        cmpi.w #2,d1
        blo M4GeometryFaceBad
        cmpi.w #8,d1
        bhi M4GeometryFaceBad
        subq.w #1,d1
        lea 6(a4),a0
        lea 16(a1),a2
M4GeometryFaceIndex:
        move.w (a0)+,d0
        lsr.w #1,d0 ; byte vertex offset6*v -> WORD offset3*v
        move.w d0,(a2)+
        dbra d1,M4GeometryFaceIndex
        addq.w #1,M4_FACE_COUNT
        rts
M4GeometryFaceBad:
        move.w #$E102,M4_MESH_ERROR ;error site 2
        rts

; Ordered emitter reference, not CPU-generated coordinates or pixels.
M4IntroGeometryParticle:
        move.w #1,M4P_EARLY ;cmd8 particles read this tick's SVP9 records
        move.w M4_FACE_COUNT,d0
        cmpi.w #512,d0
        bhs M4GeometryFaceBad
        bsr M4FaceSlot
        movea.l a2,a1
        clr.l (a1)
        tst.b M4_BSP_SVP
        beq.s M4GeometryParticleCpu
        move.l M4_GEO_CURRENT,d0 ;job: only when the object is near ($4000 | object index, cmd12)
        subi.l #M4_GEO_OUTPUT,d0
        lsr.l #8,d0
        lsr.l #2,d0
        ori.w #$4000,d0
        move.w d0,(a1)
M4GeometryParticleCpu:
        move.l M4_GEO_CURRENT,d0
        subi.l #$300000,d0
        lsr.l #1,d0
        move.w d0,4(a1)
        move.w #9,6(a1)
        movea.l M4_MESH_OBJECT,a0
        moveq #0,d0
        move.b 18(a0),d0
        move.w d0,8(a1)
        move.w 24(a0),10(a1)
        clr.l 12(a1)
        clr.l 16(a1)
        clr.l 20(a1)
        clr.l 24(a1)
        clr.l 28(a1)
        addq.w #1,M4_FACE_COUNT
        rts

; mssprite 01:CCA8 (build/research/sprites.md): a0 draw entry, a1 sprite
; entry (generate-svp-sprites.py: sh_size, shift, n, n x (texture, size)).
; Face kind 30: view x/y/z, W = 2*sh_size + (s8(tx) << shift) (0 -> 1),
; texture of colframe & (n-1), its size. Level colframe: own with bit7,
; else gameframe & 127 (02:F581 +$1A); intro effects keep their own frame.
; The intro explosion2 comes from the medium explosion (sh_size 90): tx $FD.
M4IntroGeometrySprite:
        movem.l d0-d2/a2,-(sp)
        move.w M4_FACE_COUNT,d0
        cmpi.w #512,d0
        bhs M4GeometrySpriteBad
        bsr M4FaceSlot
        clr.l (a2)
        clr.w 4(a2)
        move.w #$801e,6(a2) ;sprite packet (bit 15: not a model kind)
        tst.w M4_GEO_VIEW
        beq.s M4GeometrySpriteIntro
        move.l 56(a0),8(a2)
        move.w 60(a0),12(a2)
        move.b X_TX(a0),d1
        moveq #0,d0
        move.b 18(a0),d0
        bmi.s M4GeometrySpriteOwn
        move.w M4_SCENE_TICK,d0
        bra.s M4GeometrySpriteFrame
M4GeometrySpriteIntro:
        move.l (a0),8(a2)
        move.w 4(a0),d0
        sub.w INTRO_CAMERA+8,d0
        move.w d0,12(a2)
        moveq #0,d1
        cmpi.b #5,21(a0)
        bne.s M4GeometrySpriteIntroFrame
        moveq #-3,d1
M4GeometrySpriteIntroFrame:
        moveq #0,d0
        move.b 18(a0),d0
M4GeometrySpriteOwn:
M4GeometrySpriteFrame:
        andi.w #127,d0
        move.w 4(a1),d2
        subq.w #1,d2
        and.w d2,d0
        lsl.w #2,d0
        move.l 6(a1,d0.w),16(a2) ;texture WORD address, texsize
        ext.w d1
        move.w 2(a1),d2
        lsl.w d2,d1
        move.w (a1),d0
        add.w d0,d0
        add.w d1,d0
        bne.s M4GeometrySpriteSize
        moveq #1,d0
M4GeometrySpriteSize:
        move.w d0,14(a2)
        clr.l 20(a2)
        clr.l 24(a2)
        clr.l 28(a2)
        addq.w #1,M4_FACE_COUNT
        movem.l (sp)+,d0-d2/a2
        rts
M4GeometrySpriteBad:
        move.w #$E103,M4_MESH_ERROR ;error site 3
        movem.l (sp)+,d0-d2/a2
        rts

M4IntroGeometryClip:
        movem.l d1-d7/a0-a6,-(sp)
        tst.b M4_CHAIN_ACTIVE
        bne.s M4GeometryClipRun
        tst.w M4_GEO_COUNT
        bne.s M4GeometryClipRun
        tst.w M4_GEO_VIEW ;level path without objects: the radio/text records
        beq M4GeometryGood
        tst.w M4_FACE_COUNT
        beq M4GeometryGood
M4GeometryClipRun:
        move.w M4_CLOCK,d0
        move.w d0,d1
        sub.w M4_GEO_DIAG+10,d0
        move.w d0,M4_GEOM_WORK+4
        move.w d1,M4_GEO_DIAG+10
        move.w M4_FACE_COUNT,d0
        move.w d0,M4_GEO_EXPECT
        move.w d0,M4_GEO_DIAG+6
        if def(M4_GRAPHICS117)
        jmp G117H114StoreFace ;no early-raster mailbox overwrite
        else
        move.w d0,MAILBOX+20
        endif
M4GeometryClipRunStored:
        moveq #10,d0
        tst.b M4_BSP_SVP
        beq.s M4GeometryClipCmd
        moveq #12,d0 ;SVP12: BSP walk, colours and packets of the jobs, then cmd10 on them (echo = jobs)
M4GeometryClipCmd:
        bsr M4IntroGeometryRequest
        move.w MAILBOX+30,M4_GEO_DIAG+18 ;SVP12: packets written, or its error code (diagnostic)
        tst.w d0
        bne M4GeometryReturn
        tst.b M4_BSP_SVP
        beq.s M4GeometryClipFaces
        move.w MAILBOX+30,d0 ;packets written by SVP12
        move.w d0,M4_FACE_COUNT
        move.w d0,M4_GEO_DIAG+6
M4GeometryClipFaces:
        move.w TEXT_VIDEO_DIAG+6,M4_GEO_DIAG+14
        move.w MAILBOX+20,M4_POLY_COUNT
        move.w MAILBOX+20,M4_GEO_DIAG+8
        move.w M4_CLOCK,d0
        sub.w M4_GEO_DIAG+10,d0
        move.w d0,M4_GEOM_WORK+6
        cmpi.w #256,M4_POLY_COUNT
        bhi M4GeometryBad
        bne.s M4GeometryNotFull
        addq.w #1,INTRO_DIAG+12 ;images whose excess polygons the SVP dropped
M4GeometryNotFull:
        cmpi.w #$a55a,M4_FACE_INPUT-2
        bne M4GeometryBad
        cmpi.w #$a55a,M4_FACE_INPUT+16384
        bne M4GeometryBad
        cmpi.w #$a55a,M4_POLY_INPUT-2
        bne M4GeometryBad
        cmpi.w #$a55a,M4_POLY_INPUT+4096
        bne M4GeometryBad
        bra M4GeometryGood

; Fresh command9/10; expected count result, complemented echo/ACK, no stale
; publish. Geometry buffers are separate from the final bitmap.
M4IntroGeometryRequest:
        tst.b M4_CHAIN_ACTIVE
        beq.s M4GeometryRequestSeparate
        cmpi.w #12,d0
        beq M4ChainRequest
M4GeometryRequestSeparate:
        cmpi.w #9,d0
        bne.s M4GeometryRequestFlush
        cmpi.w #2,M4P_STATE ;started early: SVP9 must not overwrite its records
        bne.s M4GeometryRequestFresh
M4GeometryRequestFlush:
        move.w d0,-(sp)
        bsr M4PipeFlush
        move.w (sp)+,d1
        tst.w d0
        bne M4GeometryRequestFlushBad
        move.w d1,d0
M4GeometryRequestFresh:
        move.l M4_GEO_VP,MAILBOX+26 ;vanishing point offset x, y (0: GSU 112/96)
        move.w d0,MAILBOX+8
        addq.w #1,TEXT_VIDEO_DIAG+6
        move.w TEXT_VIDEO_DIAG+6,d0
        not.w d0
        move.w d0,MAILBOX+6
        move.w d0,ACK_SEQUENCE
        move.w #$dead,MAILBOX+4
        move.w XST_STATUS,d0
        move.w TEXT_VIDEO_DIAG+6,XST
        ; level: CPU work of this tick that does not touch the drawing runs
        ; while the SVP computes cmd10 (M4LevelOverlapWork, level_view.asm)
        cmpi.w #9,MAILBOX+8 ;SVP mode: the object jobs are written while the SVP computes cmd9
        bne.s M4GeometryNoHook
        tst.l M4_GEO_HOOK9
        beq.s M4GeometryNoHook
        movem.l d0-d7/a0-a6,-(sp)
        movea.l M4_GEO_HOOK9,a0
        clr.l M4_GEO_HOOK9
        jsr (a0)
        movem.l (sp)+,d0-d7/a0-a6
M4GeometryNoHook:
        if def(M4_GRAPHICS117)
        jmp G117H115NoHook
        else
        tst.l M4_GEO_OVERLAP
        endif
M4GeometryNoHookBody:
        beq.s M4GeometryNoOverlap
        cmpi.w #10,MAILBOX+8
        beq.s M4GeometryOverlapRun
        cmpi.w #12,MAILBOX+8
        beq.s M4GeometryOverlapRun
        cmpi.w #13,MAILBOX+8
        bne.s M4GeometryNoOverlap
M4GeometryOverlapRun:
        movem.l d0-d7/a0-a6,-(sp)
        movea.l M4_GEO_OVERLAP,a0
        clr.l M4_GEO_OVERLAP
        jsr (a0)
        movem.l (sp)+,d0-d7/a0-a6
M4GeometryNoOverlap:
        move.l #TIMEOUT_POLLS,d1
M4GeometryPoll:
        move.w XST_STATUS,d0
        btst #0,d0
        bne.s M4GeometryReady
        subq.l #1,d1
        bne.s M4GeometryPoll
        moveq #-2,d0
        rts
M4GeometryReady:
        move.w TEXT_VIDEO_DIAG+6,d0
        cmp.w MAILBOX+6,d0
        bne.s M4GeometryRequestBad
        cmp.w ACK_SEQUENCE,d0
        bne.s M4GeometryRequestAckBad
        move.w M4_GEO_EXPECT,d0
        cmp.w MAILBOX+4,d0
        bne.s M4GeometryRequestEchoBad
        moveq #0,d0
        rts
M4GeometryRequestFlushBad:
        moveq #-12,d0 ;error code
        rts
M4GeometryRequestAckBad:
        moveq #-13,d0 ;error code
        rts
M4GeometryRequestEchoBad:
        move.w MAILBOX+4,INTRO_DIAG+12 ;diagnostic: echo and expected
        move.w M4_GEO_EXPECT,INTRO_DIAG+14
        move.w MAILBOX+8,INTRO_DIAG+10
        moveq #-14,d0 ;error code
        rts
M4GeometryRequestBad:
        moveq #-4,d0 ;error code
        rts
