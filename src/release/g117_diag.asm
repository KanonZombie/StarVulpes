; graphics117 diagnostics from hw86..90 (tools/hw-boot/make-round29.py,
; make-round32.py; RAM moved by make-round54.py, 115): chain poll run from
; RAM, a sampled phase marker, and the error-context capture.

; M4PipeFlushChain -> G117PollCopy: the same SVP chain poll, executed from RAM.
G117_POLL_RAM equ $ff4600       ; 36 bytes; independent of screen work RAM
G117PollCopy:
        movem.l d2/a0-a1,-(sp)
        lea G117PollImage(pc),a0
        lea G117_POLL_RAM,a1
        moveq #(G117PollImageEnd-G117PollImage)/2-1,d2
G117PollWord:
        move.w (a0)+,(a1)+
        dbra d2,G117PollWord
        movem.l (sp)+,d2/a0-a1
        jmp G117_POLL_RAM
G117PollImage:
        obj G117_POLL_RAM
G117Poll:
        move.l #TIMEOUT_POLLS,d1
G117PollLoop:
        tst.w M4_CHAIN_HDR+6
        bne.w G117PollDone
        subq.l #1,d1
        bne.w G117PollLoop
        moveq #2,d0
        jmp M4PipeFlushError
G117PollDone:
        jmp M4PipeFlushChainDone
        objend
G117PollImageEnd:

        g117at $15bd00
; M4PipeFlushChainDone -> G117Marker: phase mark 3 only while sampling.
G117Marker:
        cmpi.w #2,G117_PROBE_STATE
        bne.w G117MarkerReplay
        move.l d0,-(sp)
        moveq #3,d0
        jsr M4ProfMark
        move.l (sp)+,d0
G117MarkerReplay:
        moveq #4,d0              ; displaced from M4PipeFlushChainDone
        cmpi.w #1,M4_CHAIN_HDR+6
        jmp M4PipeFlushChainDone10

        g117at $15be00
; M4IntroFailed -> G117FatalContext: capture registers and diagnostic words,
; then the report (G117PrbFatal).
G117_FATAL_D0 equ $ff5e80
G117_FATAL_D1 equ $ff5e84
G117_FATAL_SR equ $ff5ed0
g117field macro
        moveq #0,d0
        move.w \1,d0
        move.l d0,G117_FATAL+\2
        endm
G117FatalContext:
        move.w sr,G117_FATAL_SR
        move.w #$2700,sr
        move.l d0,G117_FATAL_D0
        move.l d1,G117_FATAL_D1
        moveq #0,d0
        move.l G117_FATAL_D0,d0
        move.l d0,G117_FATAL
        moveq #0,d0
        move.l G117_FATAL_D1,d0
        move.l d0,G117_FATAL+4
        g117field G117_FATAL_SR,8
        g117field DIAG+4,12
        g117field INTRO_DIAG+4,16
        g117field INTRO_DIAG+6,20
        g117field TEXT_VIDEO_DIAG+4,24
        g117field M4_GEO_DIAG+4,28
        g117field $ff4494,32
        g117field $ff4484,36
        g117field $ff44a4,40
        g117field $ff44c4,44
        g117field $ff4524,48
        g117field $ff4534,52
        g117field $ff4544,56
        g117field $ff44d4,60
        g117field M4_BOSS_GEO_DIAG+4,64
        g117field M4_PART_DIAG+4,68
        g117field M4_LATE_DIAG+4,72
        g117field M4_NATIVE_ERROR,76
        move.l G117_FATAL_D0,d0
        move.l G117_FATAL_D1,d1
        jmp G117PrbFatal
