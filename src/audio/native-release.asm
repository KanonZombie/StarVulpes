; Native release audio; original bank/command numbers, Z80-owned FM writes.
        org $1af100
RA_MAGIC equ $ff0100
RA_BANK equ $ff0104
RA_COMMAND equ $ff0106
RA_SONG equ $ff0108
RA_FRAME equ $ff010c
RA_FADE equ $ff0110
RA_TICKACC equ $ff0112
RA_ATT equ $ff0116
RA_FXPTR equ $ff0118
RA_FXWAIT equ $ff011c
RA_FXPRIO equ $ff011e
RA_FXSTART equ $ff0120
RA_LASTATT equ $ff0122
RA_FXBASE equ $ff0124
RA_TEMPOPTR equ $ff0128
RA_TEMPOBASE equ $ff012c
RA_TEMPO equ $ff0130
RA_END equ $ff0132
RA_LOOP equ $ff0134
RA_MASK equ $ff0136
RA_QUEUE equ $ff0140
RA_RATE equ $ff0230
RA_WCOUNT equ $ff0232
RA_WTEMPO equ $ff0234
RA_WDELTA equ $ff0236
RA_WTARGET equ $ff0238
RA_TRANS_PENDING equ $ff0239
RA_TRANSPOSE equ $ff023a
RA_LAST_ELAPSED equ $ff023c

ReleaseAudioInit:
        move.w sr,-(sp)
        movem.l d0-d1/a0,-(sp)
        lea RA_MAGIC,a0
        moveq #0,d0
        move.w #($140/4)-1,d1
ReleaseAudioClear:
        move.l d0,(a0)+
        dbra d1,ReleaseAudioClear
        move.l #'RAUD',RA_MAGIC
        move.w #-1,RA_BANK
        move.w #-1,RA_LASTATT
        movem.l (sp)+,d0-d1/a0
        move.w (sp)+,sr
        lea M4_SFX_DIAG,a0
        jmp M4SoundInit+6

ReleaseIntroStart:
        ; Startup-only fixtures are reused in this continuous release.
        ; Bypass their tests explicitly; do not manufacture PASS statuses.
        clr.l M4_GEO_VP
        clr.w M4VR_LATE
        jsr M4TextVideoInit
        moveq #ReleaseBank_intro,d0
        bsr ReleaseSetBank
        jmp ReleaseIntroAfterTests

ReleaseMusicBg:
        move.w sr,-(sp)
        movem.l d0-d2/a0,-(sp)
        btst #2,TEXT_MAP_CONTEXT+11
        beq.s ReleaseMusicBgDone
        move.w TEXT_MAP_CONTEXT+12,d0
        cmpi.w #267,d0
        bhi.s ReleaseMusicBgDone
        lea ReleaseBgConditional,a0
        tst.b (a0,d0.w)
        beq.s ReleaseMusicBgUnconditional
        btst #0,TEXT_MAP_CONTEXT+11 ;bgflags $1F15: bgf_restart
        beq.s ReleaseMusicBgDone
ReleaseMusicBgUnconditional:
        add.w d0,d0
        lea ReleaseBgBanks,a0
        move.w (a0,d0.w),d0
        beq.s ReleaseMusicBgDone
        subq.w #1,d0
        bsr ReleaseSetBank
ReleaseMusicBgDone:
        movem.l (sp)+,d0-d2/a0
        move.w (sp)+,sr
        lea TEXT_MAP_CONTEXT,a0
        jmp M4ScTransSwap+6

ReleaseMusicCommit:
        move.w sr,-(sp)
        movem.l d0-d7/a0-a3,-(sp)
        cmpi.w #1,26(a0)
        bne.s ReleaseMusicCommitDone
        cmpi.w #$14,20(a0)
        bne.s ReleaseMusicCommitDone
        btst #7,M4_LP_PSF2 ;WORLD setbgmdo skips playerHP0
        bne.s ReleaseMusicCommitDone
        moveq #0,d0
        move.b 1(a1),d0
        bsr ReleaseCommand
ReleaseMusicCommitDone:
        movem.l (sp)+,d0-d7/a0-a3
        move.w (sp)+,sr
        cmpi.w #1,26(a0)
        jmp M4ScriptCommit+6

; Public adapters preserve registers/CCR used by translated callers.
ReleaseSetBank:
        move.w sr,-(sp)
        movem.l d0-d7/a0-a3,-(sp)
        cmpi.w #34,d0
        bhi.s ReleaseSetBankDone
        move.w d0,RA_BANK
        add.w d0,d0
        lea ReleaseInitialTable,a0
        move.w (a0,d0.w),d0
        bsr ReleaseCommand
ReleaseSetBankDone:
        movem.l (sp)+,d0-d7/a0-a3
        move.w (sp)+,sr
        rts

ReleaseCommand:
        move.w sr,-(sp)
        movem.l d0-d7/a0-a3,-(sp)
        ori.w #$0700,sr
        cmpi.w #1,M4_SFX_DIAG+4
        bne ReleaseCommandDone
        cmpi.w #$f0,d0
        beq ReleaseStopCommand
        cmpi.w #$ff,d0
        beq ReleaseStopCommand
        cmpi.w #$f1,d0
        beq ReleaseFadeCommand
        cmpi.w #$f2,d0
        beq ReleaseDuckCommand
        cmpi.w #$f3,d0
        beq ReleaseRestoreCommand
        cmpi.w #$f4,d0
        beq ReleaseWarpDown
        cmpi.w #$f5,d0
        beq ReleaseWarpUp
        cmpi.w #19,d0
        bhi ReleaseCommandDone
        tst.w d0
        beq ReleaseCommandDone
        move.w RA_BANK,d1
        cmpi.w #34,d1
        bhi ReleaseCommandDone
        move.w d0,d2
        mulu.w #80,d1
        lsl.w #2,d0
        add.w d1,d0
        lea ReleaseBankTable,a0
        movea.l (a0,d0.w),a0
        move.l a0,d0
        beq ReleaseCommandDone
        move.w d2,RA_COMMAND
        move.l a0,RA_SONG
        clr.l RA_FRAME
        clr.l RA_LAST_ELAPSED
        clr.w RA_FADE
        clr.l RA_TICKACC
        clr.w RA_ATT
        move.w #-1,RA_LASTATT
        move.w #256,RA_RATE
        clr.w RA_WCOUNT
        clr.w RA_WTEMPO
        clr.b RA_TRANSPOSE
        move.b #1,RA_TRANS_PENDING
        lea ReleaseTrackTable,a1
ReleaseFindTrack:
        move.l (a1),d1
        beq ReleaseCommandDone
        cmp.l RA_SONG,d1
        beq.s ReleaseTrackFound
        lea 16(a1),a1
        bra.s ReleaseFindTrack
ReleaseTrackFound:
        move.w 4(a1),RA_END
        move.w 6(a1),RA_LOOP
        move.l 8(a1),RA_TEMPOPTR
        move.l 8(a1),RA_TEMPOBASE
        move.w 12(a1),RA_MASK
        movea.l RA_TEMPOPTR,a1
        move.w 2(a1),RA_TEMPO
        moveq #9,d7 ;COMMAND plus the driver's multi-byte TEMPO read
        jsr XGM2_RequestAccess
        tst.b d0
        beq ReleaseCommandDone
        clr.b $a0015c ;discard unconsumed queue before SID upload
        clr.b $a0015d ;new score resets original SPC key transpose
        move.b RA_MASK+1,$a0015e
        clr.b XGM2_TEMPO_ARG_FRAC
        move.b #1,XGM2_TEMPO_ARG_INT
        jsr XGM2_ReleaseBus
        movea.l RA_SONG,a0
        jsr XGM2_Play
        tst.b d0
        beq ReleaseCommandDone
        move.w #1,M4_MUSIC_ACTIVE
        addq.w #1,M4_MUSIC_STARTS
        bra ReleaseCommandDone
ReleaseStopCommand:
        bsr ReleaseMusicStop
        bra ReleaseCommandDone
ReleaseFadeCommand:
        cmpi.w #17,RA_COMMAND ;original _6B7 leaves player-down music alone
        beq ReleaseCommandDone
        move.w #160,RA_FADE ;SPC _6B7: $A0 music ticks
        bra.s ReleaseCommandDone
ReleaseDuckCommand:
        move.w #13,RA_ATT ;SPC F2: ($70/$C0)^2 amplitude
        bra.s ReleaseCommandDone
ReleaseRestoreCommand:
        clr.w RA_ATT
        bra.s ReleaseCommandDone
ReleaseWarpDown:
        move.b #-2,RA_TRANSPOSE
        moveq #9,d2
        bra.s ReleaseWarpTempo
ReleaseWarpUp:
        move.b #3,RA_TRANSPOSE
        moveq #$30,d2
ReleaseWarpTempo:
        move.b #1,RA_TRANS_PENDING
        move.b d2,RA_WTARGET
        tst.w RA_WTEMPO
        bne.s ReleaseWarpCurrent
        move.w RA_TEMPO,d1
        lsl.w #8,d1
        move.w d1,RA_WTEMPO
ReleaseWarpCurrent:
        lsl.w #8,d2
        sub.w RA_WTEMPO,d2
        ext.l d2
        divs.w #143,d2
        move.w d2,RA_WDELTA
        move.w #143,RA_WCOUNT
ReleaseCommandDone:
        movem.l (sp)+,d0-d7/a0-a3
        move.w (sp)+,sr
        rts

ReleaseMusicStop:
        move.w sr,-(sp)
        movem.l d0-d7/a0-a2,-(sp)
        ori.w #$0700,sr
        clr.w RA_FADE
        clr.w M4_MUSIC_ACTIVE
        jsr XGM2_Stop
        movem.l (sp)+,d0-d7/a0-a2
        move.w (sp)+,sr
        rts

ReleaseCorneria:
        move.w sr,-(sp)
        move.l d0,-(sp)
        moveq #ReleaseBank_11,d0
        bsr ReleaseSetBank
        move.l (sp)+,d0
        move.w (sp)+,sr
        rts

ReleaseSfx:
        move.w sr,-(sp)
        movem.l d0-d7/a0-a2,-(sp)
        ori.w #$0700,sr
        andi.w #$ff,d0
        cmpi.w #3,d0
        bne.s ReleaseSfxNotDeath
        move.l d0,-(sp)
        moveq #17,d0
        bsr ReleaseCommand
        move.l (sp)+,d0
ReleaseSfxNotDeath:
        cmpi.w #$b0,d0
        bhs.s ReleaseSfxOriginal
        move.w d0,d1
        lsl.w #2,d1
        lea ReleaseFxTable,a0
        movea.l (a0,d1.w),a0
        move.l a0,d1
        beq.s ReleaseSfxOriginal
        mulu.w #12,d0
        lea M4SfxTable,a1
        move.w 8(a1,d0.w),d1
        tst.l RA_FXPTR
        beq.s ReleaseSfxStart
        cmp.w RA_FXPRIO,d1
        blo.s ReleaseSfxReturn
ReleaseSfxStart:
        move.w d1,RA_FXPRIO
        move.l a0,RA_FXBASE
        addq.l #2,a0
        move.l a0,RA_FXPTR
        clr.w RA_FXWAIT
        move.w #1,RA_FXSTART
        addq.w #1,M4_SFX_DIAG+8
ReleaseSfxReturn:
        movem.l (sp)+,d0-d7/a0-a2
        move.w (sp)+,sr
        rts
ReleaseSfxOriginal:
        movem.l (sp)+,d0-d7/a0-a2
        move.w (sp)+,sr
        move.w sr,-(sp)
        movem.l d0-d7/a0-a2,-(sp)
        jmp M4Sfx+6

ReleaseAudioIRQ:
        bsr ReleaseAudioTick
        jmp M4IntroVBlankIRQ

ReleaseAudioTick:
        movem.l d0-d7/a0-a3,-(sp)
        cmpi.l #'RAUD',RA_MAGIC
        bne ReleaseAudioTickDone
        cmpi.w #1,M4_SFX_DIAG+4
        bne ReleaseAudioTickDone
        ; Do not release a bus lock belonging to an interrupted IRQ4 DMA
        ; guard or a translated caller. Busy queues defer by one VBlank.
        btst #0,XGM2_Z80_BUSREQ
        beq ReleaseAudioTickDone
        jsr XGM2_RequestBus
        move.b XGM2_ACCESS,d0
        andi.b #$0d,d0 ;COMMAND, elapsed timestamp write, or TEMPO read
        bne ReleaseAudioTickRelease
        btst #4,XGM2_DRIVER_COMMAND ;new PLAY has not reset its timestamp yet
        bne ReleaseAudioTickRelease
        tst.b $a0015c
        bne ReleaseAudioTickRelease
        lea RA_QUEUE,a1
        bsr ReleaseMusicTick
        movea.l RA_FXPTR,a0
        move.l a0,d0
        beq ReleaseAudioQueue
        tst.w RA_FXSTART
        beq.s ReleaseAudioNoPatch
        clr.w RA_FXSTART
        move.b #5,(a1)+
        move.b #1,(a1)+
        clr.b (a1)+
        move.b #6,(a1)+
        clr.b (a1)+
        move.b #$df,(a1)+
        move.b #6,(a1)+
        clr.b (a1)+
        move.b #$ff,(a1)+
        movea.l RA_FXBASE,a2
        tst.b (a2)
        beq.s ReleaseAudioNoPatch
        move.b #6,(a1)+
        clr.b (a1)+
        move.b #$e7,(a1)+
ReleaseAudioNoPatch:
        tst.w RA_FXWAIT
        beq.s ReleaseAudioNextNote
        subq.w #1,RA_FXWAIT
        bne ReleaseAudioQueue
ReleaseAudioNextNote:
        moveq #0,d0
        move.b (a0)+,d0
        beq ReleaseAudioFxEnd
        move.w d0,RA_FXWAIT
        moveq #0,d2
        move.b (a0)+,d2
        move.w (a0)+,d3
        move.l a0,RA_FXPTR
        move.b #6,(a1)+
        clr.b (a1)+
        move.w d3,d0
        andi.b #15,d0
        ori.b #$c0,d0
        move.b d0,(a1)+
        move.b #6,(a1)+
        clr.b (a1)+
        lsr.w #4,d3
        move.b d3,(a1)+
        movea.l RA_FXBASE,a2
        tst.b (a2)
        beq.s ReleaseAudioTone
        ori.b #$f0,d2
        bra.s ReleaseAudioEffectVolume
ReleaseAudioTone:
        ori.b #$d0,d2
ReleaseAudioEffectVolume:
        move.b #6,(a1)+
        clr.b (a1)+
        move.b d2,(a1)+
        bra.s ReleaseAudioQueue
ReleaseAudioFxEnd:
        clr.l RA_FXPTR
        clr.w RA_FXPRIO
        move.b #5,(a1)+
        clr.b (a1)+
        clr.b (a1)+
ReleaseAudioQueue:
        move.l a1,d0
        subi.l #RA_QUEUE,d0
        beq.s ReleaseAudioTickRelease
        cmpi.w #48,d0
        bhi.s ReleaseAudioTickRelease
        move.w d0,d2
        divu.w #3,d2
        subq.w #1,d0
        lea RA_QUEUE,a0
        lea $a01dc0,a1
ReleaseAudioSend:
        move.b (a0)+,(a1)+
        dbra d0,ReleaseAudioSend
        move.b d2,$a0015c ;commit last; Z80 owns the queue until zero
ReleaseAudioTickRelease:
        jsr XGM2_ReleaseBus
ReleaseAudioTickDone:
        movem.l (sp)+,d0-d7/a0-a3
        rts

ReleaseMusicTick:
        tst.w M4_MUSIC_ACTIVE
        beq ReleaseMusicTickDone
        ; Use consumed score frames, not successful mailbox/VBlank visits.
        ; This keeps loops/fades aligned after an IRQ defers a busy queue.
        moveq #0,d0
        move.b $a00167,d0
        lsl.l #8,d0
        move.b $a00166,d0
        lsl.l #8,d0
        move.b $a00165,d0
        move.l d0,d5
        sub.l RA_LAST_ELAPSED,d5
        andi.l #$ffffff,d5
        move.l d0,RA_LAST_ELAPSED
        move.l d5,d0
        lsl.l #8,d0
        add.l d0,RA_FRAME
        move.l RA_FRAME,d1
        lsr.l #8,d1
        cmp.w RA_END,d1
        blo.s ReleaseMusicTempo
        cmpi.w #$ffff,RA_LOOP
        beq.s ReleaseMusicTempo
        moveq #0,d0
        move.w RA_END,d0
        sub.w RA_LOOP,d0
        lsl.l #8,d0
        sub.l d0,RA_FRAME
        move.l RA_FRAME,d1
        lsr.l #8,d1
        move.l RA_TEMPOBASE,RA_TEMPOPTR
ReleaseMusicTempo:
        movea.l RA_TEMPOPTR,a0
ReleaseMusicTempoNext:
        cmp.w (a0),d1
        blo.s ReleaseMusicTempoReady
        cmpi.w #$ffff,(a0)
        beq.s ReleaseMusicTempoReady
        move.w 2(a0),RA_TEMPO
        addq.l #4,a0
        bra.s ReleaseMusicTempoNext
ReleaseMusicTempoReady:
        move.l a0,RA_TEMPOPTR
        moveq #0,d1
        move.w RA_TEMPO,d1
ReleaseMusicClock:
        mulu.w d5,d1
        mulu.w #500,d1 ;timer0: 8000/16 Hz; TMP/256 music-clock divider
        add.l d1,RA_TICKACC
ReleaseMusicClockTick:
        cmpi.l #256*60,RA_TICKACC
        blo.s ReleaseMusicRate
        subi.l #256*60,RA_TICKACC
        tst.w RA_WCOUNT
        beq.s ReleaseMusicClockFade
        move.w RA_WDELTA,d0
        add.w d0,RA_WTEMPO
        subq.w #1,RA_WCOUNT
        bne.s ReleaseMusicClockFade
        moveq #0,d0
        move.b RA_WTARGET,d0
        lsl.w #8,d0
        move.w d0,RA_WTEMPO
ReleaseMusicClockFade:
        tst.w RA_FADE
        beq.s ReleaseMusicClockTick
        subq.w #1,RA_FADE
        bne.s ReleaseMusicClockTick
        clr.w M4_MUSIC_ACTIVE
        ori.b #$20,XGM2_DRIVER_COMMAND
        bra.s ReleaseMusicClockTick
ReleaseMusicRate:
        move.w #256,d0
        tst.w RA_WTEMPO
        beq.s ReleaseMusicSetRate
        moveq #0,d0
        move.w RA_WTEMPO,d0
        divu.w RA_TEMPO,d0
ReleaseMusicSetRate:
        cmp.w RA_RATE,d0
        beq.s ReleaseMusicControl
        move.w d0,RA_RATE
        move.b d0,XGM2_TEMPO_ARG_FRAC
        lsr.w #8,d0
        move.b d0,XGM2_TEMPO_ARG_INT
ReleaseMusicControl:
        tst.b RA_TRANS_PENDING
        beq.s ReleaseMusicFadeVolume
        clr.b RA_TRANS_PENDING
        move.b #4,(a1)+ ;cooperative Z80 control descriptor
        move.b RA_TRANSPOSE,(a1)+
        move.b RA_MASK+1,(a1)+
ReleaseMusicFadeVolume:
        move.w RA_ATT,d0
        tst.w RA_FADE
        beq.s ReleaseMusicVolume
        move.w RA_FADE,d1
        lea ReleaseFadeAtt,a0
        moveq #0,d2
        move.b (a0,d1.w),d2
        add.w d2,d0
        cmpi.w #127,d0
        bls.s ReleaseMusicVolume
        moveq #127,d0
ReleaseMusicVolume:
        cmp.w RA_LASTATT,d0
        beq.s ReleaseMusicTickDone
        move.w d0,RA_LASTATT
        move.b d0,$a0010c
        mulu.w #3,d0
        lsr.w #3,d0
        cmpi.w #15,d0
        bls.s ReleaseMusicPsgAtt
        moveq #15,d0
ReleaseMusicPsgAtt:
        move.b d0,$a0010d
        ori.b #$c0,XGM2_DRIVER_COMMAND
ReleaseMusicTickDone:
        rts

ReleasePCMGuard:
        move.w sr,-(sp)
        movem.l d1-d2,-(sp)
        move.l a0,d1
        cmpi.l #$200000,d1
        bhs.s ReleasePCMUnavailable
        move.l d1,d2
        add.l d0,d2
        bcs.s ReleasePCMUnavailable
        cmpi.l #$200000,d2
        bhi.s ReleasePCMUnavailable
        movem.l (sp)+,d1-d2
        move.w (sp)+,sr
        movem.l d1-d7/a0-a2,-(sp)
        move.w sr,-(sp)
        jmp XGM2_PlayPCM+6
ReleasePCMUnavailable:
        movem.l (sp)+,d1-d2
        moveq #0,d0
        move.w (sp)+,sr
        rts

        even
