; Continuous SPC ports. Original playersnd / nearobjs in SOUND.ASM.
; Mono steady-state PCM windows are a destination adaptation (manifest.json).
; $FF0098/9A last loop parameters; 9C/9D inatunnel/gamemode; 9E nearest object.
M4_SOUND_OBJECTS equ $ff00a0 ;64 bytes, one per level slot

M4SoundObjectsClear:
        movem.l d0/a0,-(sp)
        lea M4_SOUND_OBJECTS,a0
        moveq #15,d0
M4SoundObjectsZero:
        clr.l (a0)+
        dbra d0,M4SoundObjectsZero
        clr.w $ff009e
        clr.w $ff00e4 ;lastplayx, reset by original playercred
        movem.l (sp)+,d0/a0
        rts
M4SoundObjectClear:
        move.l d0,-(sp)
        moveq #0,d0
        bsr M4SoundObjectSet
        move.l (sp)+,d0
        rts
M4SoundObjectSet: ;a0=level object, d0.b=original alx_snd2
        move.w sr,-(sp)
        movem.l d1/a1,-(sp)
        move.w a0,d1
        subi.w #M4_LV_OBJ&$ffff,d1
        lsr.w #6,d1
        cmpi.w #M4_LV_SLOTS,d1
        bhs.s M4SoundObjectSetDone
        lea M4_SOUND_OBJECTS,a1
        move.b d0,(a1,d1.w)
M4SoundObjectSetDone:
        movem.l (sp)+,d1/a1
        move.w (sp)+,sr
        rts

M4SoundSetBg: ;d0.w = original background number
        move.w sr,-(sp)
        movem.l d0/a0,-(sp)
        andi.w #$ff,d0
        add.w d0,d0
        lea M4SoundBgTable,a0
        move.w (a0,d0.w),$ff009c
        movem.l (sp)+,d0/a0
        move.w (sp)+,sr
        rts

M4SoundTick:
        move.w sr,-(sp)
        movem.l d0-d7/a0-a3,-(sp)
        cmpi.w #1,M4_SFX_DIAG+4
        bne M4SoundTickDone
        moveq #0,d0
        btst #1,M4_LP_PSF3 ;psf3_enginesnd
        beq.s M4SoundPlayerLoop
        btst #6,M4_LP_GAMEFLAGS ;PLAYERDEAD
        bne M4SoundPlayerLoop
        btst #7,M4_LP_PSF2 ;playerHP0: original dying motor $4B
        beq.s M4SoundPlayerAlive
        moveq #$4b,d0
        bra M4SoundPlayerReady
M4SoundPlayerAlive:
        move.w #$c4,d0 ;planet, normal speed
        tst.b $ff009c ;inatunnel
        beq.s M4SoundNotTunnel
        cmpi.b #2,$ff009c ;water uses planet patch
        beq.s M4SoundPlayerSpeed
        move.w #$84,d0
        bra.s M4SoundPlayerSpeed
M4SoundNotTunnel:
        btst #0,$ff009d ;SPACE_MODE=1, VARS.INC
        beq.s M4SoundPlayerSpeed
        moveq #4,d0
M4SoundPlayerSpeed:
        btst #5,M4_LP_PSF2
        beq.s M4SoundPlayerBrake
        addq.w #4,d0
        bra.s M4SoundPlayerLoop
M4SoundPlayerBrake:
        btst #6,M4_LP_PSF2
        beq.s M4SoundPlayerLoop
        addq.w #8,d0
M4SoundPlayerLoop:
        tst.w d0
        beq.s M4SoundPlayerReady
        move.w M4_LP_JOY,d1
        andi.w #(1<<J_L)|(1<<J_R),d1
        beq.s M4SoundPlayerReady
        move.w LV_PLAYER,d1
        move.w d1,d2
        sub.w $ff00e4,d1
        move.w d2,$ff00e4
        tst.w d1
        bpl.s M4SoundAccelPositive
        neg.w d1
M4SoundAccelPositive:
        cmpi.w #2,d1
        blo.s M4SoundPlayerReady
        addq.w #1,d0
        cmpi.w #4,d1
        blo.s M4SoundPlayerReady
        addq.w #1,d0
        cmpi.w #8,d1
        blo.s M4SoundPlayerReady
        addq.w #1,d0
M4SoundPlayerReady:
        lea M4EngineTable,a1
        lea $ff0098,a2
        moveq #0,d1
        move.l #512,d4
        bsr M4SoundLoop
        ; Closest live object carrying sound2, original allst traversal.
        move.w M4_LV_HEAD,d7
        move.w #$7fff,d6
        moveq #0,d5
        moveq #0,d3
M4SoundNearest:
        tst.w d7
        beq.s M4SoundNearestDone
        movea.w d7,a0
        move.w X_NEXT(a0),d7
        btst #0,25(a0) ;afexp
        bne.s M4SoundNearest
        move.w a0,d0
        subi.w #M4_LV_OBJ&$ffff,d0
        lsr.w #6,d0
        lea M4_SOUND_OBJECTS,a1
        moveq #0,d2
        move.b (a1,d0.w),d2
        andi.w #15,d2
        beq.s M4SoundNearest
        move.w 4(a0),d0
        sub.w LV_PLAYER+4,d0
        bpl.s M4SoundRange
        neg.w d0
M4SoundRange:
        cmp.w d0,d6
        blo.s M4SoundNearest
        move.w d0,d6
        move.w a0,d5
        move.w d2,d3
        bra.s M4SoundNearest
M4SoundNearestDone:
        moveq #0,d0
        cmp.w $ff009e,d5 ;new nearest is silent for the first tick
        bne.s M4SoundNearestStore
        cmpi.w #3150,d6 ;original cutoff; pan/distance gain omitted in mono
        bhs.s M4SoundNearestStore
        move.w d3,d0
M4SoundNearestStore:
        move.w d5,$ff009e
        lea M4ObjectSoundTable,a1
        lea $ff009a,a2
        moveq #1,d1
        move.l #768,d4
        bsr M4SoundLoop
M4SoundTickDone:
        movem.l (sp)+,d0-d7/a0-a3
        move.w (sp)+,sr
        rts

; d0=parameter, d1=channel, d4=length, a1=pointer table, a2=last parameter.
; A finite effect can preempt a loop and finishes before the loop resumes.
M4SoundLoop:
        tst.w M4_MUSIC_ACTIVE
        beq.s M4SoundLoopChannel
        addq.w #1,d1 ;engine 1, nearest object 2; leave music PCM0 untouched
M4SoundLoopChannel:
        move.w d0,d6
        move.w sr,-(sp)
        ori.w #$0700,sr
        jsr XGM2_RequestBus
        move.b XGM2_DRIVER_COMMAND,d3
        moveq #1,d2
        lsl.b d1,d2
        move.b XGM2_DRIVER_STATUS,d0
        or.b d3,d0
        and.b d0,d2
        btst d1,d3
        bne.s M4SoundLoopPending
        move.w d1,d0
        lsl.w #3,d0
        lea XGM2_PCM_PARAM_BASE,a0
        move.b XGM2_PCM_PRIORITY_OFFSET(a0,d0.w),d3
        bra.s M4SoundLoopBusDone
M4SoundLoopPending:
        lea XGM2_PCM_ARG_BASE,a0
        move.b (a0,d1.w),d3
M4SoundLoopBusDone:
        jsr XGM2_ReleaseBus
        move.w (sp)+,sr
        tst.b d2
        beq.s M4SoundLoopFree
        btst #7,d3
        beq.s M4SoundLoopDone ;one shot owns this channel
        tst.w d6
        beq.s M4SoundLoopStop
        cmp.w (a2),d6
        beq.s M4SoundLoopDone
M4SoundLoopFree:
        tst.w d6
        beq.s M4SoundLoopForget
        move.w d6,d0
        lsl.w #2,d0
        movea.l (a1,d0.w),a0
        move.l a0,d0
        beq.s M4SoundLoopDone
        move.l d4,d0
        moveq #0,d2
        moveq #3,d3 ;half rate, loop
        jsr XGM2_PlayPCM
        tst.b d0
        beq.s M4SoundLoopDone
        move.w d6,(a2)
        lea $ff00e0,a0
        move.b #$ff,(a0,d1.w) ;this channel now belongs to a continuous port
M4SoundLoopDone:
        rts
M4SoundLoopStop:
        move.w d1,d0
        jsr XGM2_StopPCM
M4SoundLoopForget:
        clr.w (a2)
        rts

M4SoundStopLoops:
        movem.l d0-d7/a0-a2,-(sp)
        cmpi.w #1,M4_SFX_DIAG+4
        bne.s M4SoundStopLoopsDone
        lea $ff0098,a2
        moveq #0,d0
        moveq #0,d1
        bsr M4SoundLoop
        lea $ff009a,a2
        moveq #0,d0
        moveq #1,d1
        bsr M4SoundLoop
M4SoundStopLoopsDone:
        jsr M4MusicStop
        movem.l (sp)+,d0-d7/a0-a2
        rts

; makesnd uses playpt's world position, not pviewVelZ or viewZ.
; INTRO_CAMERA+0 is player worldZ; +6 is velocity (normally63).
; d0 = near effect ID, a0 = object. Keeps registers and CCR.
M4SoundIntroAt:
        move.w sr,-(sp)
        movem.l d0-d2/a2,-(sp)
        move.w d0,d2
        subq.l #6,sp
        clr.l (sp)
        move.w INTRO_CAMERA,4(sp)
        movea.l sp,a2
        jsr M4EnDistXZ
        addq.l #6,sp
        jsr M4SfxSelectGeneric
        movem.l (sp)+,d0-d2/a2
        move.w (sp)+,sr
        rts

; d2=ported weapon type, a4=shooter. Original fire_* sound helper, after
; successful allocation/gen_weapon and before flash/puff (06:A7E3..B40B).
M4SoundWeapon:
        move.w sr,-(sp)
        movem.l d0/a0-a1,-(sp)
        lea M4WeaponSounds,a1
        moveq #0,d0
        move.b (a1,d2.w),d0
        beq.s M4SoundWeaponDone
        movea.l a4,a0
        jsr M4SfxAt
M4SoundWeaponDone:
        movem.l (sp)+,d0/a0-a1
        move.w (sp)+,sr
        rts
M4WeaponSounds:
        include '../build/m4-weapon-sounds.inc'
        even
