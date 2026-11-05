; MDSDRV complete bank. Supplied FM/PSG MML; no XGM2 chip access.
; Cooperative mode3 PCM gate covers the real IRQ4 DMA interval.
        org ReleaseHostBase
RA_MAGIC equ $ff0100
RA_BANK equ $ff0104
RA_COMMAND equ $ff0106
RA_SONG equ $ff0108
RA_FRAME equ $ff010c
RA_ATT equ $ff0116
RA_FADE equ $ff0110
RA_FXPRIO equ $ff0120 ;two priorities: player F, world/radio L (PSG fallback)
RA_DMA_DEFER equ $ff0128
RA_DMA_ARMS equ $ff012c
RA_SCORE equ $ff0134
RA_TEMPOPTR equ $ff0138
RA_TEMPOBASE equ $ff013c
RA_TEMPO equ $ff0140
RA_END equ $ff0142
RA_LOOP equ $ff0144
RA_TICKACC equ $ff0146
RA_WCOUNT equ $ff014a
RA_WTEMPO equ $ff014c
RA_WDELTA equ $ff014e
RA_WTARGET equ $ff0150
RA_TRANSPOSE equ $ff0151
RA_RATE equ $ff0152
RA_LASTVOL equ $ff0154
MDS_WORK equ $ff0400
MDS_WORK_BYTES equ $3ec

ReleaseAudioInit:
        move.w sr,-(sp)
        ori.w #$0700,sr
        movem.l d0-d7/a0-a6,-(sp)
        lea RA_MAGIC,a0
        moveq #0,d0
        move.w #($700/4)-1,d1
ReleaseMDSClear:
        move.l d0,(a0)+
        dbra d1,ReleaseMDSClear
        move.l #'MDSD',RA_MAGIC
        move.w #-1,RA_BANK
        move.l #'M4SD',M4_SFX_DIAG
        clr.l M4_SFX_DIAG+4
        clr.l M4_MUSIC_ACTIVE
        lea MDS_WORK,a0
        lea ReleaseMDSSeq,a1
        suba.l a2,a2 ;headers contain physical addresses; bank base is zero
        jsr ReleaseMDSDriver
        tst.w d0
        bne ReleaseMDSInitFailed
        clr.l $ff0098
        clr.w $ff009c
        jsr M4SoundObjectsClear
        lea MDS_WORK,a0
        moveq #$11,d0
        moveq #3,d1
        move.w #192,d2
        jsr ReleaseMDSDriver+12
        ; K/L PCM do not own an FM track and never write FM6's pan.
        ; Reset mode/timers left by the loader and explicitly route DAC
        ; to both speakers before the first music-only PCM request.
        lea MDS_WORK,a0
        moveq #8,d0
        move.w #$2200,d1
        jsr ReleaseMDSDriver+12
        lea MDS_WORK,a0
        moveq #8,d0
        move.w #$2700,d1
        jsr ReleaseMDSDriver+12
        lea MDS_WORK,a0
        moveq #9,d0
        move.w #$b6c0,d1
        jsr ReleaseMDSDriver+12
        bsr ReleaseZ80Bus
        move.b #$c9,$a00038 ;software HBlank gate replaces hardware VBL gate
        clr.b $a00e07
        clr.b $a00e20
        move.w #0,$a11100
        move.w #1,M4_SFX_DIAG+4
        bra.s ReleaseMDSInitDone
ReleaseMDSInitFailed:
        move.w #-1,M4_SFX_DIAG+4
ReleaseMDSInitDone:
        movem.l (sp)+,d0-d7/a0-a6
        move.w (sp)+,sr
        rts

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
        ori.w #$0700,sr
        movem.l d0-d7/a0-a6,-(sp)
        cmpi.w #1,M4_SFX_DIAG+4
        bne ReleaseMDSCommandDone
        cmpi.w #$f0,d0
        beq ReleaseMDSStop
        cmpi.w #$ff,d0
        beq ReleaseMDSStop
        cmpi.w #$f1,d0
        beq ReleaseMDSFade
        cmpi.w #$f2,d0
        beq ReleaseMDSDuck
        cmpi.w #$f3,d0
        beq ReleaseMDSRestore
        cmpi.w #$f4,d0
        beq ReleaseWarpDown
        cmpi.w #$f5,d0
        beq ReleaseWarpUp
        cmpi.w #19,d0
        bhi ReleaseMDSCommandDone
        tst.w d0
        beq ReleaseMDSCommandDone
        move.w d0,RA_COMMAND
        move.w RA_BANK,d1
        cmpi.w #34,d1
        bhi ReleaseMDSCommandDone
        mulu.w #40,d1
        add.w d0,d0
        add.w d1,d0
        lea ReleaseBankTable,a0
        move.w (a0,d0.w),d0
        move.w d0,RA_SONG
        clr.l RA_FRAME
        clr.w RA_ATT
        clr.w RA_FADE
        clr.l RA_SCORE
        clr.l RA_TICKACC
        clr.w RA_WCOUNT
        clr.w RA_WTEMPO
        clr.b RA_TRANSPOSE
        move.w #-1,RA_LASTVOL
        tst.w d0
        beq.s ReleaseMDSRequest
        lsl.w #3,d0
        lea ReleaseClockTable,a0
        move.l (a0,d0.w),RA_TEMPOPTR
        move.l (a0,d0.w),RA_TEMPOBASE
        move.w 4(a0,d0.w),RA_END
        move.w 6(a0,d0.w),RA_LOOP
        movea.l RA_TEMPOPTR,a0
        move.w 2(a0),RA_TEMPO
ReleaseMDSRequest:
        ; A queued song resets its slot volume on the next driver update.
        ; Set its initial BGM attenuation too; the low byte keeps SFX at 0.
        lea MDS_WORK,a0
        moveq #7,d0
        move.w #8*256,d1
        cmpi.w #ReleaseBank_intro,RA_BANK
        bne.s ReleaseMDSInitialVolume
        move.w #12*256,d1
ReleaseMDSInitialVolume:
        jsr ReleaseMDSDriver+12
        move.w RA_SONG,d0
        lea MDS_WORK,a0
        moveq #3,d1 ;MDSDRV BGM priority slot
        jsr ReleaseMDSDriver+8
        move.w RA_SONG,M4_MUSIC_ACTIVE
        addq.w #1,M4_MUSIC_STARTS
        bsr ReleaseMusicVolume
        bra ReleaseMDSCommandDone
ReleaseMDSStop:
        clr.w RA_SONG
        clr.w M4_MUSIC_ACTIVE
        clr.w RA_FADE
        clr.w RA_WCOUNT
        clr.w RA_WTEMPO
        clr.b RA_TRANSPOSE
        lea MDS_WORK,a0
        moveq #0,d0
        moveq #3,d1
        jsr ReleaseMDSDriver+8
        bra ReleaseMDSCommandDone
ReleaseMDSFade:
        cmpi.w #17,RA_COMMAND ;original player-down music ignores fade
        beq ReleaseMDSCommandDone
        move.w #160,RA_FADE ;original _6B7:$A0 musical ticks
        bra ReleaseMDSCommandDone
ReleaseMDSDuck:
        moveq #13,d2
        bra.s ReleaseMDSVolume
ReleaseMDSRestore:
        moveq #0,d2
ReleaseMDSVolume:
        move.w d2,RA_ATT
        move.w #-1,RA_LASTVOL
        bsr ReleaseMusicVolume
        bra ReleaseMDSCommandDone
ReleaseWarpDown:
        move.b #-2,RA_TRANSPOSE
        moveq #9,d2
        bra.s ReleaseWarpTarget
ReleaseWarpUp:
        move.b #3,RA_TRANSPOSE
        moveq #$30,d2
ReleaseWarpTarget:
        tst.w M4_MUSIC_ACTIVE
        beq.s ReleaseMDSCommandDone
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
ReleaseMDSCommandDone:
        movem.l (sp)+,d0-d7/a0-a6
        move.w (sp)+,sr
        rts

ReleaseMusicStop:
        move.w sr,-(sp)
        move.l d0,-(sp)
        move.w #$f0,d0
        bsr ReleaseCommand
        move.l (sp)+,d0
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

ReleaseAudioIRQ:
        movem.l d0-d7/a0-a6,-(sp)
        cmpi.w #1,M4_SFX_DIAG+4
        bne.s ReleaseMDSIRQDone
        bsr ReleaseDmaEnd ;also releases an armed but missed DMA window
        lea MDS_WORK,a0
        jsr ReleaseMDSDriver+4
        bsr ReleaseMusicTick
        addq.l #1,RA_FRAME
ReleaseMDSIRQDone:
        movem.l (sp)+,d0-d7/a0-a6
        jmp M4IntroVBlankIRQ

; Musical time comes from consumed MDS score ticks, not game ticks or the
; number of requests. Source TMP uses500/(256*60) ticks per score frame.
ReleaseMusicTick:
        tst.w M4_MUSIC_ACTIVE
        beq ReleaseMusicTickDone
        moveq #0,d5
        move.w MDS_WORK+$1c+6,d5 ;stock w_seq_step[3], verified listing
        add.l d5,RA_SCORE
        move.l RA_SCORE,d1
        cmp.w RA_END,d1
        blo.s ReleaseMusicTempo
        cmpi.w #$ffff,RA_LOOP
        beq.s ReleaseMusicTempo
        moveq #0,d0
        move.w RA_END,d0
        sub.w RA_LOOP,d0
        sub.l d0,RA_SCORE
        move.l RA_SCORE,d1
        move.l RA_TEMPOBASE,RA_TEMPOPTR
ReleaseMusicTempo:
        movea.l RA_TEMPOPTR,a0
ReleaseMusicTempoNext:
        cmp.w (a0),d1
        blo.s ReleaseMusicClock
        cmpi.w #$ffff,(a0)
        beq.s ReleaseMusicClock
        move.w 2(a0),RA_TEMPO
        addq.l #4,a0
        bra.s ReleaseMusicTempoNext
ReleaseMusicClock:
        move.l a0,RA_TEMPOPTR
        moveq #0,d1
        move.w RA_TEMPO,d1
        mulu.w d5,d1
        mulu.w #500,d1
        add.l d1,RA_TICKACC
ReleaseMusicClockTick:
        cmpi.l #256*60,RA_TICKACC
        blo.s ReleaseMusicRate
        subi.l #256*60,RA_TICKACC
        tst.w RA_WCOUNT
        beq.s ReleaseMusicFadeTick
        move.w RA_WDELTA,d0
        add.w d0,RA_WTEMPO
        subq.w #1,RA_WCOUNT
        bne.s ReleaseMusicFadeTick
        moveq #0,d0
        move.b RA_WTARGET,d0
        lsl.w #8,d0
        move.w d0,RA_WTEMPO
ReleaseMusicFadeTick:
        tst.w RA_FADE
        beq.s ReleaseMusicClockTick
        subq.w #1,RA_FADE
        bne.s ReleaseMusicClockTick
        bsr ReleaseMusicStop
        bra ReleaseMusicTickDone
ReleaseMusicRate:
        tst.w RA_WTEMPO
        beq.s ReleaseMusicVolume
        moveq #0,d0
        move.w RA_WTEMPO,d0
        divu.w RA_TEMPO,d0 ;Q8 ratio of target to source tempo
        move.w d0,RA_RATE
        lsr.w #1,d0 ;MDS raw127 means128/128 ticks per update
        subq.w #1,d0
        move.w d0,d2
        lea MDS_WORK,a0
        moveq #$0f,d0
        moveq #3,d1
        jsr ReleaseMDSDriver+12
ReleaseMusicVolume:
        move.w RA_ATT,d2
        move.w RA_FADE,d1
        beq.s ReleaseMusicVolumeReady
        lea ReleaseFadeAtt,a0
        moveq #0,d0
        move.b (a0,d1.w),d0
        add.w d0,d2
        cmpi.w #127,d2
        bls.s ReleaseMusicVolumeReady
        moveq #127,d2
ReleaseMusicVolumeReady:
        ; Leave headroom for effects without changing their samples/gains.
        ; Intro combat needs more separation than title/flight/boss.
        addq.w #8,d2
        cmpi.w #ReleaseBank_intro,RA_BANK
        bne.s ReleaseMusicMixClamp
        addq.w #4,d2
ReleaseMusicMixClamp:
        cmpi.w #127,d2
        bls.s ReleaseMusicMixReady
        moveq #127,d2
ReleaseMusicMixReady:
        cmp.w RA_LASTVOL,d2
        beq.s ReleaseMusicTickDone
        move.w d2,RA_LASTVOL
        lea MDS_WORK,a0
        moveq #$0d,d0
        moveq #3,d1
        jsr ReleaseMDSDriver+12
ReleaseMusicTickDone:
        rts

ReleaseDmaBegin:
        ; IRQ4 wrapper entered only after the Z80 acknowledged. Its gate
        ; drains the internal buffer and makes no banked-ROM access.
        rts
ReleaseZ80Bus:
        move.w #$100,$a11100
ReleaseDmaWait:
        btst #0,$a11100
        bne.s ReleaseDmaWait
ReleaseDmaDone:
        rts
ReleaseDmaEnd:
        cmpi.w #1,M4_SFX_DIAG+4
        bne.s ReleaseDmaEndDone
        bsr ReleaseZ80Bus
        clr.b $a00e07
        move.w #0,$a11100
ReleaseDmaEndDone:
        rts

; Arm while there is time for a complete Z80 refill batch. Starting a DMA
; without acknowledgement is forbidden: defer that window instead.
ReleaseHBlankIRQ:
        move.w sr,-(sp)
        ori.w #$0700,sr
        movem.l d0-d1,-(sp)
        cmpi.w #1,M4_SFX_DIAG+4
        bne ReleaseHintReturn
        tst.w M4VR_READY_BUSY
        beq ReleaseHintReturn
        tst.w M4N_ON
        beq ReleaseHintWindow
        move.w M4N_RUNS,d0
        cmp.w M4N_NEXT,d0
        beq ReleaseHintOriginal ;UI SAT/CRAM only: no SVP DMA to gate PCM
ReleaseHintWindow:
        move.w $c00008,d0
        lsr.w #8,d0
        tst.w M4N_ON
        beq ReleaseHintNormalWindow
        tst.w M4N_VBLANK
        beq ReleaseHintNormalWindow
        cmpi.w #191,d0 ;same 32-line refill lead for the line223 map window
        blo ReleaseHintReturn
        cmpi.w #225,d0 ;entry/port latency can cross line224 while IRQ6 is masked
        bhi ReleaseHintReturn
        bra ReleaseHintGate
ReleaseHintNormalWindow:
        cmpi.w #175,d0
        blo ReleaseHintReturn
        cmpi.w #215,d0
        bhi ReleaseHintReturn
ReleaseHintGate:
        bsr ReleaseZ80Bus
        tst.b $a00e07
        bne ReleaseHintArmed
        tst.w M4N_ON
        beq.s ReleaseHintArm
        tst.w M4N_VBLANK
        beq.s ReleaseHintArm
        cmpi.w #223,d0
        bhs ReleaseHintMissedMap ;late entry needs a gate armed in this same field
ReleaseHintArm:
        move.b #1,$a00e07
        addq.l #1,RA_DMA_ARMS
ReleaseHintArmed:
        moveq #0,d1
        move.b $a00e20,d1
        move.w #0,$a11100
        tst.w M4N_ON
        beq ReleaseHintNormalDeadline
        tst.w M4N_VBLANK
        beq ReleaseHintNormalDeadline
        cmpi.w #223,d0
        blo ReleaseHintReturn
        bra ReleaseHintAck
ReleaseHintNormalDeadline:
        cmpi.w #207,d0
        blo ReleaseHintReturn
ReleaseHintAck:
        tst.b d1
        bne ReleaseHintOriginal
        addq.l #1,RA_DMA_DEFER
        bra ReleaseHintReturn
ReleaseHintMissedMap:
        move.w #0,$a11100
        addq.l #1,RA_DMA_DEFER
ReleaseHintReturn:
        movem.l (sp)+,d0-d1
        move.w (sp)+,sr
        rte
ReleaseHintOriginal:
        tst.w M4N_ON
        beq ReleaseHintRestore
        tst.w M4N_VBLANK
        beq ReleaseHintRestore
        ori.w #$0700,8(sp) ;keep IRQ6 masked across the handoff and line224 wait
ReleaseHintRestore:
        movem.l (sp)+,d0-d1
        move.w (sp)+,sr
        jmp M4VRHBlankIRQ

ReleaseSfx:
        move.w sr,-(sp)
        ori.w #$0700,sr
        movem.l d0-d7/a0-a6,-(sp)
        cmpi.w #1,M4_SFX_DIAG+4
        bne ReleaseSfxDone
        andi.w #$ff,d0
        addq.w #1,M4_SFX_DIAG+6
        move.w d0,M4_SFX_DIAG+10
        cmpi.w #3,d0
        bne.s ReleaseSfxNotDeath
        moveq #17,d0
        bsr ReleaseCommand
        moveq #3,d0
ReleaseSfxNotDeath:
        cmpi.w #$b0,d0
        bhs ReleaseSfxAbsent
        lsl.w #2,d0
        lea ReleaseFxTable,a1
        adda.w d0,a1
        moveq #0,d4
        move.w (a1),d4
        beq.s ReleaseSfxAbsent
        moveq #0,d5
        move.b 3(a1),d5
        andi.w #1,d5 ;slot0 player F, slot1 world/radio L/PSG; source voice in manifest
        if ReleaseIntroLaserSong
        cmpi.w #ReleaseBank_intro,RA_BANK
        bne.s ReleaseSfxResource
        cmpi.w #$45*4,d0
        bne.s ReleaseSfxResource
        move.w #ReleaseIntroLaserSong,d4
        moveq #0,d5 ;intro shots on F, explosion on L; no player fire here
ReleaseSfxResource:
        endif
        moveq #0,d6
        move.b 2(a1),d6
        lea MDS_WORK,a0
        moveq #2,d0
        move.w d5,d1
        jsr ReleaseMDSDriver+12
        tst.w d0
        bne.s ReleaseSfxCheckPriority
        move.w d5,d1
        add.w d1,d1
        btst #7,4(a0,d1.w) ;a pending request already owns this slot
        beq.s ReleaseSfxAccept
ReleaseSfxCheckPriority:
        move.w d5,d1
        add.w d1,d1
        lea RA_FXPRIO,a0
        cmp.w (a0,d1.w),d6
        blo.s ReleaseSfxRejected
ReleaseSfxAccept:
        move.w d5,d1
        add.w d1,d1
        lea RA_FXPRIO,a0
        move.w d6,(a0,d1.w)
        lea MDS_WORK,a0
        move.w d4,d0
        move.w d5,d1
        jsr ReleaseMDSDriver+8
        addq.w #1,M4_SFX_DIAG+8
        bra.s ReleaseSfxDone
ReleaseSfxAbsent:
        addq.w #1,M4_SFX_DIAG+14
        bra.s ReleaseSfxDone
ReleaseSfxRejected:
        addq.w #1,M4_SFX_DIAG+12
ReleaseSfxDone:
        movem.l (sp)+,d0-d7/a0-a6
        move.w (sp)+,sr
        rts

ReleaseSoundLoop:
        move.w sr,-(sp)
        ori.w #$0700,sr
        movem.l d0-d7/a0-a6,-(sp)
        andi.w #$ff,d0
        cmp.w (a2),d0
        beq.s ReleaseLoopDone
        move.w d0,(a2)
        move.w $ff0098,d0
        add.w d0,d0
        lea ReleaseEngineIndex,a0
        move.w (a0,d0.w),d0
        move.w $ff009a,d1
        andi.w #15,d1
        add.w d1,d1
        add.w d1,d0
        lea ReleaseContinuousTable,a1
        move.w (a1,d0.w),d0
        lea MDS_WORK,a0
        moveq #2,d1
        jsr ReleaseMDSDriver+8
ReleaseLoopDone:
        movem.l (sp)+,d0-d7/a0-a6
        move.w (sp)+,sr
        rts

; No public caller may enter the incompatible XGM2 PCM interface.
ReleasePCMGuard:
        rts
