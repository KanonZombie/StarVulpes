; SVP13 owns all drawing inputs until its final ACK. Raster(k-1) has a
; separate result/phase: the host seals that bitmap while cmd9/12/10 run.
; The original VR bank/DMA protocol is unchanged (docs/VR_PIPELINE.md).
M4_CHAIN_ACTIVE equ $fff9dc ;.b selected once per draw, never inferred from mailbox
M4_CHAIN_HDR equ $301c80 ;18 WORDs, below bitmap: raster?, objects, jobs,
; phase (0 raster pending,1 raster done,FFFF error), raster result, checksum,
; two reserved words, snapshot of GEO_VIEW (flag + 9 matrix words).
M4_CHAIN_VIEW equ M4_CHAIN_HDR+16

M4ChainSelect:
        if def(M4_GRAPHICS117)
        jmp G117H115Select
        else
        move.b M4_CHAIN_ACTIVE,d1
        endif
        clr.b M4_CHAIN_ACTIVE
        if ~def(M4_NO_CHAIN)
        tst.b M4_BSP_SVP
        beq.s M4ChainSelectDone
        tst.w M4_GEO_VIEW
        beq.s M4ChainSelectDone
        tst.b M4_OVL_LOOP ;only the four loops with a defined CPU window
        beq.s M4ChainSelectDone
        tst.w INTRO_CAPTURE ;capture protocol retains the separate commands
        bne.s M4ChainSelectDone
        cmpi.w #2,M4P_STATE ;transition from an already started cmd8
        beq.s M4ChainSelectDone
        cmpi.l #'OVLT',M4_OVL_MAGIC
        bne.s M4ChainSelectOn
        btst #4,M4_OVL_CTL ;same-ROM reference: separate commands
        bne.s M4ChainSelectDone
M4ChainSelectOn:
        move.b #1,M4_CHAIN_ACTIVE
M4ChainSelectDone:
        tst.b M4_CHAIN_ACTIVE
        bne.s M4ChainSelectReturn
        tst.b d1
        beq.s M4ChainSelectReturn
        cmpi.w #1,M4P_STATE ;leaving the chain (capture/control): any old
        bne.s M4ChainSelectReturn ;particle geometry must survive until cmd8
        jsr M4PipeKick ;the ordinary cmd9 request now flushes it BEFORE cmd9
M4ChainSelectReturn:
        rts

; Called with all poses/jobs built. No geometry or pixels on the 68000.
M4ChainRequest:
        if def(M4_GRAPHICS117)
        jmp G117H114Join
        else
        lea M4_GEO_VIEW,a0
        endif
M4ChainRequestBody:
        lea M4_CHAIN_VIEW,a1
        moveq #4,d1
M4ChainCopyView:
        move.l (a0)+,(a1)+
        dbra d1,M4ChainCopyView
        clr.w M4_CHAIN_HDR
        clr.w M4_CHAIN_HDR+6
        move.w M4_GEO_COUNT,M4_CHAIN_HDR+2
        move.w M4_FACE_COUNT,M4_CHAIN_HDR+4
        tst.w M4P_STATE
        beq.s M4ChainNoRaster
        move.w #1,M4_CHAIN_HDR
        move.w M4P_COUNT,MAILBOX+20
        move.w M4P_FLAG,MAILBOX+22
        move.w #3,M4P_STATE ;raster is owned by cmd13, not a separate XST request
M4ChainNoRaster:
        moveq #13,d0
        bra M4GeometryRequestFresh
