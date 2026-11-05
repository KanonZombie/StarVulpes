; Own event adapter. IDs/priorities are the Star Fox SPC IDs, PCM is rendered
; offline from the selected ROM (extract-sf-sfx.py). No SPC code runs here.
; XGM2 2.11 supplies the three-channel Z80 DAC mixer (MIT, THIRD_PARTY.md).
M4_SFX_DIAG equ $ff0080 ;M4SD.l, ready.w, requests.w, played.w, last.w, failed.w, absent.w

M4SoundInit:
        lea M4_SFX_DIAG,a0
        moveq #3,d0
M4SoundClear:
        clr.l (a0)+
        dbra d0,M4SoundClear
        move.l #'M4SD',M4_SFX_DIAG
        clr.l $ff0098
        clr.w $ff009c
        move.l #'M4MU',$ff00e8
        clr.l M4_MUSIC_ACTIVE
        move.l #$ffffffff,$ff00e0 ;original SPC voice owning each DAC channel
        jsr M4SoundObjectsClear
        if ~def(M4_NO_SOUND)
        jsr XGM2_Init
        tst.b d0
        beq.s M4SoundInitFailed
        ; Timer A=1019, half-rate effects and music at 5327 Hz.
        move.w #1,M4_SFX_DIAG+4
        endif
        rts
M4SoundInitFailed:
        move.w #$ffff,M4_SFX_DIAG+4
        rts

; d0.b=original ID; preserve registers and CCR for translated game code.
M4Sfx:
        move.w sr,-(sp)
        movem.l d0-d7/a0-a2,-(sp)
        if ~def(M4_NO_SOUND)
        cmpi.w #1,M4_SFX_DIAG+4
        bne M4SfxDone
        addq.w #1,M4_SFX_DIAG+6
        andi.w #$ff,d0
        move.w d0,M4_SFX_DIAG+10
        cmpi.w #$b0,d0
        bhs M4SfxAbsent
        mulu.w #12,d0
        lea M4SfxTable,a1
        adda.w d0,a1
        movea.l (a1)+,a0
        move.l a0,d0
        beq M4SfxAbsent
        move.l (a1)+,d0
        move.w (a1)+,d2 ;original low-nibble priority
        move.w (a1),d6 ;original voice: repeated shots/radio replace themselves
        moveq #-1,d1 ;three mixer channels, priority replacement
        move.l d0,-(sp)
        move.w sr,-(sp)
        ori.w #$0700,sr
        jsr XGM2_RequestBus
        move.b XGM2_DRIVER_STATUS,d3
        or.b XGM2_DRIVER_COMMAND,d3
        jsr XGM2_ReleaseBus
        move.w (sp)+,sr
        lea $ff00e0,a2
        moveq #2,d5
M4SfxFindVoice:
        tst.w d5
        bne.s M4SfxFindVoiceActive
        tst.w M4_MUSIC_ACTIVE
        bne.s M4SfxNextVoice
M4SfxFindVoiceActive:
        btst d5,d3
        beq.s M4SfxNextVoice
        cmp.b (a2,d5.w),d6
        beq.s M4SfxSameVoice
M4SfxNextVoice:
        dbra d5,M4SfxFindVoice
        bra.s M4SfxChoose
M4SfxSameVoice:
        move.w d5,d1
M4SfxChoose:
        move.l (sp)+,d0
        moveq #1,d3 ;5327 Hz half rate, finite sample (no invented loop)
        jsr XGM2_PlayPCM
        tst.b d0
        beq.s M4SfxNotPlayed
        lsr.w #8,d0
        subq.w #1,d0
        lea $ff00e0,a2
        move.b d6,(a2,d0.w)
        addq.w #1,M4_SFX_DIAG+8
        bra.s M4SfxDone
M4SfxAbsent:
        addq.w #1,M4_SFX_DIAG+14
        bra.s M4SfxDone
M4SfxNotPlayed:
        addq.w #1,M4_SFX_DIAG+12 ;busy/higher priority or failed handshake
        endif
M4SfxDone:
        movem.l (sp)+,d0-d7/a0-a2
        move.w (sp)+,sr
        rts

; a0=object, d0=near ID. Hitflash's inline $24 uses unsigned 1000/2000;
; other helpers use makesnd 03:B785 (2000/1150/3150, including dead middle).
M4SfxAt:
        move.w sr,-(sp)
        movem.l d0-d2/a2,-(sp)
        move.w d0,d2
        lea LV_PLAYER,a2
        jsr M4EnDistXZ
        bsr M4SfxSelect
        movem.l (sp)+,d0-d2/a2
        move.w (sp)+,sr
        rts

M4SfxSelect: ;d0.w=range WORD from ROM 1F:D0AB, d2.w=near ID
        cmpi.w #$24,d2
        bne.s M4SfxSelectGeneric
        cmpi.w #1000,d0
        blo.s M4SfxSelectEmit
        addq.w #1,d2
        cmpi.w #2000,d0
        blo.s M4SfxSelectEmit
        addq.w #1,d2
        bra.s M4SfxSelectEmit
M4SfxSelectGeneric:
        cmpi.w #2000,d0
        blo.s M4SfxSelectEmit
        cmpi.w #1150,d0 ;unreachable in selected ROM; preserve, do not repair
        blo.s M4SfxSelectMid
        cmpi.w #3150,d0
        bhs.s M4SfxSelectDone
        addq.w #1,d2
M4SfxSelectMid:
        addq.w #1,d2
        cmpi.w #$46,d2 ;mono laser centre $45, middle $47, far $48
        beq.s M4SfxSelectLaser
        cmpi.w #$47,d2
        bne.s M4SfxSelectEmit
M4SfxSelectLaser:
        addq.w #1,d2
M4SfxSelectEmit:
        move.w d2,d0
        jmp M4Sfx
M4SfxSelectDone:
        rts

; makesnd 03:B785 with five IDs at a1 (lsnd, csnd, rsnd, msnd, fsnd), a0 =
; object: rangexz < 2000: pviewposx - worldx >= 170 lsnd, < -170 rsnd, else
; csnd; < 1150 msnd (unreachable in the selected ROM: kept); < 3150 fsnd.
M4SfxAt5:
        move.w sr,-(sp)
        movem.l d0-d2/a2,-(sp)
        lea LV_PLAYER,a2
        jsr M4EnDistXZ
        cmpi.w #2000,d0
        blo.s M4Sfx5Near
        moveq #3,d2
        cmpi.w #1150,d0
        blo.s M4Sfx5Emit
        moveq #4,d2
        cmpi.w #3150,d0
        blo.s M4Sfx5Emit
        bra.s M4Sfx5Done
M4Sfx5Near:
        move.w M4_LP_PVIEWX,d1
        sub.w (a0),d1
        bmi.s M4Sfx5Left
        moveq #0,d2
        cmpi.w #170,d1
        bhs.s M4Sfx5Emit
        moveq #1,d2
        bra.s M4Sfx5Emit
M4Sfx5Left:
        moveq #2,d2
        cmpi.w #-170,d1
        blo.s M4Sfx5Emit
        moveq #1,d2
M4Sfx5Emit:
        moveq #0,d0
        move.b (a1,d2.w),d0
        jsr M4Sfx
M4Sfx5Done:
        movem.l (sp)+,d0-d2/a2
        move.w (sp)+,sr
        rts

; Protect the DAC ring-buffer refills from the 68k/VDP DMA bus conflict.
; Called only on the actual IRQ4 transfer, with IRQs already masked.
M4SoundDmaBegin:
        if ~def(M4_NO_SOUND)
        cmpi.w #1,M4_SFX_DIAG+4
        bne.s M4SoundDmaBeginDone
        jsr XGM2_RequestBus
        move.b #1,XGM2_IN_DMA
        jsr XGM2_ReleaseBus
        endif
M4SoundDmaBeginDone:
        rts
M4SoundDmaEnd:
        if ~def(M4_NO_SOUND)
        cmpi.w #1,M4_SFX_DIAG+4
        bne.s M4SoundDmaEndDone
        jsr XGM2_RequestBus
        clr.b XGM2_IN_DMA
        jsr XGM2_ReleaseBus
        endif
M4SoundDmaEndDone:
        rts

        if def(M4_SFX_TEST)
; Private probe only: SFXT at FF0090 and ID.w at FF0094, cleared on consume.
M4SoundTestTick:
        cmpi.l #'SFXT',$ff0090
        bne.s M4SoundTestDone
        tst.w $ff0094
        beq.s M4SoundTestDone
        move.w $ff0094,d0
        clr.w $ff0094
        cmpi.w #$fe,d0
        bne.s M4SoundTestNotMusic
        jsr M4MusicCorneria
        rts
M4SoundTestNotMusic:
        cmpi.w #$ff,d0
        bne.s M4SoundTestSingle
        moveq #$35,d0
        jsr M4Sfx
        moveq #$0d,d0
        jsr M4Sfx
        moveq #$21,d0
M4SoundTestSingle:
        jsr M4Sfx
M4SoundTestDone:
        rts
        endif

        include 'audio/xgm2.asm'
        include 'audio/loops.asm'
        include 'audio/music.asm'
        include '../build/sf-sfx-table.inc'
