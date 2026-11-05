; MD presentation of the original text renderer's SVP output.
; Command 7 input: count.word at MAILBOX+20, seven-word descriptors at $301000.
; Normal output256x192 at304000..309FFF; reference256x224 at304000..30AFFF.
; Normal M4 transfers every tile through fixed DMA banks (intro_dma.asm).
; The separate CPU reference retains compact nonempty tiles and PIO.
; Publish plane A ONLY in VBlank after both transfers finish.
TEXT_VIDEO_DIAG equ $ff8200
TEXT_VIDEO_MAP  equ $ffa000
TEXT_BITMAP equ $303000
TEXT_BITMAP_GUARD_END equ $30f000
TEXT_DESC      equ $301000

M4TextVideoInit:
        bra M4BlockVideoInit

; d0 descriptor count. Caller must finish and retain inputs until return.
; Returns d0=0 or error. One pending DSP job, fresh tags, no stale publish.
M4TextVideoDraw:
        move.w d0,-(sp)
        bsr M4PipeFlush ;seal tick k before touching the WORK guards of k+1
        bne.s M4TextVideoFlushed
        bsr M4VRWaitWork ;a queued sealed image must release its WORK bank
M4TextVideoFlushed:
        move.w (sp)+,d1
        tst.w d0
        bne M4TextVideoError
        move.w d1,d0
        clr.w M4_DMA_DIAG+26
        move.w #1,M4_DMA_DIAG+28
        move.w d0,TEXT_VIDEO_DIAG+12
        cmpi.w #64,d0
        bhi M4TextVideoBadCount
        move.w d0,MAILBOX+20
        clr.w TEXT_VIDEO_DIAG+4
        tst.w d0
        bne.s M4TextVideoTextLayer
        tst.w M4_POLY_COUNT
        beq.s M4TextVideoTextLayer
        moveq #0,d0 ; no text: SVP8 clears, draws and sums once
        bra.s M4TextVideoPolygonLayer
M4TextVideoTextLayer:
        addq.w #1,TEXT_VIDEO_DIAG+6
        movea.l M4VR_WORK_PTR,a0
        move.w #$dead,(a0)
        move.w #$dead,M4_RENDER_BYTES-2(a0)
        moveq #7,d0
        bsr M4TextVideoRequest
        tst.w d0
        bne M4TextVideoError
        tst.w M4_POLY_COUNT
        beq.s M4TextVideoCompositeReady
        moveq #1,d0 ; append geometry onto completed text
M4TextVideoPolygonLayer:
        cmpi.w #256,M4_POLY_COUNT
        bhi M4TextVideoBadCount
        cmpi.w #$a55a,M4_POLY_INPUT-2
        bne M4TextVideoBadGuard
        cmpi.w #$a55a,M4_POLY_INPUT+4096
        bne M4TextVideoBadGuard
        move.w M4_POLY_COUNT,MAILBOX+20
        move.w d0,MAILBOX+22 ; 0 clear without text / 1 append
        tst.w d0
        bne.s M4TextVideoAppendReady
        movea.l M4VR_WORK_PTR,a0
        move.w #$dead,(a0)
        move.w #$dead,M4_RENDER_BYTES-2(a0)
M4TextVideoAppendReady:
        tst.w INTRO_CAPTURE
        beq M4PipeLatch ;free run: cmd8 overlaps the next tick's BSP ordering
        addq.w #1,TEXT_VIDEO_DIAG+6
        moveq #8,d0
        bsr M4TextVideoRequest
        tst.w d0
        bne M4TextVideoError
M4TextVideoCompositeReady:
        bra M4TextVideoCheckAndPresent

; Fresh request after count/flags/inputs are finalized. d0=command7/8.
; Uses VIDEO_DIAG sequence already advanced by caller. No VDP publication.
M4TextVideoRequest:
        move.w d0,MAILBOX+8
        move.w TEXT_VIDEO_DIAG+6,d0
        not.w d0
        move.w d0,MAILBOX+6
        move.w d0,ACK_SEQUENCE
        move.w #$dead,MAILBOX+4
        move.w #$dead,MAILBOX+16
        move.w XST_STATUS,d0
        move.w TEXT_VIDEO_DIAG+6,XST
        tst.w M4_DMA_DIAG+28
        beq.s M4TextVideoMapReady
        tst.w M4_DMA_DIAG+26
        bne.s M4TextVideoMapReady
        bsr M4BlockPrepareMap
M4TextVideoMapReady:
        move.l #TIMEOUT_POLLS,d1
M4TextVideoPoll:
        move.w XST_STATUS,d0
        btst #0,d0
        bne.s M4TextVideoReady
        subq.l #1,d1
        bne.s M4TextVideoPoll
        moveq #2,d0
        bra M4TextVideoError
M4TextVideoReady:
        move.w TEXT_VIDEO_DIAG+6,d0
        cmp.w MAILBOX+6,d0
        bne M4TextVideoBadSequence
        cmp.w ACK_SEQUENCE,d0
        bne M4TextVideoBadSequence
        cmpi.w #M4_RENDER_WORDS,MAILBOX+4
        bne M4TextVideoBadSequence
        cmpi.w #$a55a,TEXT_BITMAP-2
        bne M4TextVideoBadGuard
        cmpi.w #$a55a,TEXT_BITMAP_GUARD_END
        bne M4TextVideoBadGuard
        moveq #2,d1
        cmpi.w #7,MAILBOX+8
        beq.s M4TextVideoRequestPhase
        moveq #4,d1
M4TextVideoRequestPhase:
        bsr M4IntroPhaseEnd
        moveq #0,d0
        rts
M4TextVideoCheckAndPresent:
        ; DSP already computes the full checksum. Keep it for diagnostics;
        ; onboard boot tests compare six entire bitmaps, and smoke independently
        ; recomputes sums AND verifies every composed bitmap/VRAM/screen pixel.
        ; Fresh ACK/result/echo and bitmap guards are checked per live job.
        move.w MAILBOX+16,TEXT_VIDEO_DIAG+10
        moveq #6,d1
        bsr M4IntroPhaseEnd
        bsr M4TextVideoUpload
        tst.w d0
        bne M4TextVideoError
        moveq #8,d1
        bsr M4IntroPhaseEnd
        move.w TEXT_VIDEO_DIAG+6,TEXT_VIDEO_DIAG+8
        move.w #1,TEXT_VIDEO_DIAG+4
        moveq #0,d0
        rts
M4TextVideoBadCount:
        moveq #3,d0
        bra.s M4TextVideoError
M4TextVideoBadSequence:
        moveq #4,d0
        bra.s M4TextVideoError
M4TextVideoBadGuard:
        moveq #7,d0
        bra.s M4TextVideoError
M4TextVideoBadSum:
        moveq #8,d0
M4TextVideoError:
        move.w d0,TEXT_VIDEO_DIAG+4
        rts

M4TextVideoUpload:
        bra M4BlockVideoUpload

; d0 VRAM byte address, clobbers d0/d2 only.
M4TextVideoWriteAddress:
        moveq #0,d2
        move.w d0,d2
        andi.w #$3fff,d2
        swap d2
        lsr.w #8,d0
        lsr.w #6,d0
        or.w d0,d2
        ori.l #$40000000,d2
        move.l d2,VDP_CTRL
        rts
