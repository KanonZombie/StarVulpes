; Level music: Corneria 1 (the official ROM plays it through MDSDRV).
; PCM0 belongs to music while active; PCM1/2 arbitrate loops, effects and voices.
M4_MUSIC_ACTIVE equ $ff00ec ;.w, kept outside original game state
M4_MUSIC_STARTS equ $ff00ee ;.w successful start count

M4MusicLevel:
        move.w sr,-(sp)
        movem.l d0/a0,-(sp)
        cmpi.b #$0d,M4_GS_NEWBANK
        bne.s M4MusicLevelDone
        move.w M4_GS_NEWMAP,d0
        andi.w #$7fff,d0
        cmpi.w #$5068,d0 ;Corneria 1 (including its checkpoint restarts)
        bne.s M4MusicLevelDone
        bsr M4MusicCorneria
M4MusicLevelDone:
        movem.l (sp)+,d0/a0
        move.w (sp)+,sr
        rts

; The official ROM jumps from here to its MDSDRV Corneria (build-release.py
; writes a 6-byte jmp over this entry). The other targets have no music: the
; former XGM2 conversion of the arrangement never reached the official ROM.
M4MusicCorneria:
        rts
        dcb.w 2,$4e71 ;room for the jmp of build-release.py

M4MusicStop:
        move.w sr,-(sp)
        move.l d0,-(sp)
        tst.w M4_MUSIC_ACTIVE
        beq.s M4MusicStopDone
        jsr XGM2_Stop
        moveq #0,d0
        jsr XGM2_StopPCM
        clr.w M4_MUSIC_ACTIVE
M4MusicStopDone:
        move.l (sp)+,d0
        move.w (sp)+,sr
        rts
