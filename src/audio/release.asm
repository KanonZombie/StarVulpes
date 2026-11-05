; Linked separately into verified ROM alignment padding. The normal build
; installs these hooks after graphics117, preserving its linked overlay ABI.
; Selected USA ROM: WORLD setbgmdo / BGS bg_1_1i and bg_1_1c.
; Actual music-bank decoding/catalogue is separate from this Corneria fix.
        org $1af100

ReleaseMusicBg:
        move.w sr,-(sp)
        movem.l d0/a0,-(sp)
        cmpi.w #3,d0 ;03:905F -> do_bgm_10 (initial SPC command $10)
        beq.s ReleaseMusicScramble
        cmpi.w #$1b,d0 ;03:910B -> do_bgm_11 (initial command $03)
        beq.s ReleaseMusicCorneria
        cmpi.w #$15,d0 ;03:91A9 -> do_bgm_31 (Corneria 3)
        beq.s ReleaseMusicCorneria
        bra.s ReleaseMusicBgDone
ReleaseMusicScramble:
        ; Stop the previous scene. Do not start Corneria before take-off.
        jsr M4MusicStop
        bra.s ReleaseMusicBgDone
ReleaseMusicCorneria:
        jsr M4MusicCorneria
ReleaseMusicBgDone:
        movem.l (sp)+,d0/a0
        move.w (sp)+,sr
        ; Replay M4SoundSetBg's displaced prologue, then its ordinary work.
        move.w sr,-(sp)
        movem.l d0/a0,-(sp)
        jmp M4SoundSetBg+6

ReleaseMusicCommit:
        move.w sr,-(sp)
        move.l d0,-(sp)
        cmpi.w #$14,20(a0)
        bne.s ReleaseMusicCommitDone
        btst #7,M4_LP_PSF2 ;setbgmdo skips requests while playerHP0
        bne.s ReleaseMusicCommitDone
        moveq #0,d0
        move.b 1(a1),d0 ;original command bytes, not soundtrack file number
        cmpi.w #$f0,d0
        beq.s ReleaseMusicCommandStop
        cmpi.w #3,d0
        beq.s ReleaseMusicCommandCorneria
        cmpi.w #4,d0
        bne.s ReleaseMusicCommitDone
ReleaseMusicCommandCorneria:
        cmpi.w #$1b,TEXT_MAP_CONTEXT+12
        beq.s ReleaseMusicPlayCorneria
        cmpi.w #$15,TEXT_MAP_CONTEXT+12
        bne.s ReleaseMusicCommitDone
ReleaseMusicPlayCorneria:
        jsr M4MusicCorneria
        bra.s ReleaseMusicCommitDone
ReleaseMusicCommandStop:
        ; F1 is a timed volume fade, not an immediate stop. Its generic
        ; consumer remains pending; do not silently substitute F0 for it.
        jsr M4MusicStop
ReleaseMusicCommitDone:
        move.l (sp)+,d0
        move.w (sp)+,sr
        jsr M4ScriptCommit
        jmp M4LvCommit+6

ReleasePCMGuard:
        ; EverDrive SVP v1/v2: CPU/Z80 ROM aperture is 000000..1FFFFF.
        ; 200000..3FFFFF must never be mistaken for sample ROM. The old
        ; Genplus allocation used those addresses; it is not hardware safe.
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
ReleaseAudioEnd:
