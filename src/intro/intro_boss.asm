; Selected-ROM07:8CA3 boss,07:8DFB child and script13:F924.
; Parent and both children have zero angles and zero extended relative offsets.
; Native init_objvars1F:D36E clears those bytes;1F:D56F only links/marks children.
M4_BOSSES equ $ffb100 ;body,child1,child2, three32B contexts
M4_BOSS_CREATED equ $ffb160
M4_BOSS_SCROLL equ $ffb162 ;original bg2Yscroll, starts24
M4_BOSS_BG_BOTTOM equ $ffb164
M4_BOSS_SCROLL_PRESENT equ $ffb166
M4_NATIVE_BOSSES equ $ffb168

M4IntroBossInit:
        lea M4_BOSSES,a0
        moveq #27,d0
M4BossClear:
        clr.l (a0)+
        dbra d0,M4BossClear
        move.w #24,M4_BOSS_SCROLL
        move.w #24,M4_BOSS_SCROLL_PRESENT
        move.w #31,M4_BOSS_BG_BOTTOM
        rts

; a1=original14-byte86 command. Read its WORDs LE; worldZ uses cached camera.
M4IntroBossCreate:
        tst.w M4_BOSS_CREATED
        bne M4BossCreateBad
        lea M4_BOSSES,a2
        moveq #0,d2
        moveq #3,d3
M4BossCoordinates:
        move.b 1(a1,d3.w),d0
        lsl.w #8,d0
        move.b (a1,d3.w),d0
        move.w d0,(a2,d2.w)
        addq.w #2,d2
        addq.w #2,d3
        cmpi.w #6,d2
        bne.s M4BossCoordinates
        move.w INTRO_CAMERA+2,d0
        add.w d0,4(a2)
        move.w #5,8(a2)
        move.w #15,10(a2)
        moveq #0,d5
M4BossAllocate:
        move.w d5,d0
        lsl.w #5,d0
        lea M4_BOSSES,a0
        adda.w d0,a0
        move.b d5,21(a0)
        addi.b #7,21(a0) ;geometry models5/6/7
        move.w #1,22(a0)
        bsr M4IntroNativeAllocate
        tst.w d0
        beq.s M4BossCreateBad
        move.w d5,d1
        add.w d1,d1
        lea M4_NATIVE_BOSSES,a3
        move.w d0,(a3,d1.w)
        addq.w #1,d5
        cmpi.w #3,d5
        blo.s M4BossAllocate
        move.w #1,M4_BOSS_CREATED
        move.l #M4_BOSSES,M4_LAST_CONTEXT
        move.w M4_NATIVE_BOSSES,M4_LAST_NATIVE
        moveq #0,d0
        rts
M4BossCreateBad:
        moveq #-1,d0
        rts

M4IntroBossStep:
        movem.l d0-d7/a0-a6,-(sp)
        tst.w M4_BOSS_CREATED
        beq.s M4BossStepDone
        lea M4_BOSSES,a0
        lea M4_BOSS_SCROLL,a1
        move.w M4_SCENE_TICK,d0
        move.w INTRO_CAMERA+6,d1
        bsr M4IntroBossTick
        ; Children follow in the same traversal. Zero relative offsets stay
        ; zero; parent rotation is never changed by this original strategy.
        lea M4_BOSSES+32,a1
        moveq #1,d7
M4BossChildPose:
        move.l (a0),(a1)
        move.w 4(a0),4(a1)
        move.w 12(a0),12(a1)
        move.b 14(a0),14(a1)
        lea 32(a1),a1
        dbra d7,M4BossChildPose
M4BossStepDone:
        movem.l (sp)+,d0-d7/a0-a6
        rts

M4IntroBossSort:
        tst.w M4_BOSS_CREATED
        beq.s M4BossSortDone
        moveq #0,d7
M4BossSortNext:
        lea M4BossTraversal,a1
        move.w d7,d0
        add.w d0,d0
        move.w (a1,d0.w),d0
        lea M4_BOSSES,a0
        adda.w d0,a0
        bsr M4IntroSceneSortObject
        addq.w #1,d7
        cmpi.w #3,d7
        blo.s M4BossSortNext
M4BossSortDone:
        rts
M4BossTraversal:
        dc.w 0,64,32

; BG B is a32-row circular viewport of the original64-row source map.
; Only the newly entering row is replaced, while it is outside the old view.
; Tile metadata stays on CPU; SVP remains responsible for polygon pixels.
M4IntroBossBackgroundPrepare:
        rts ;all64 source rows were loaded, no circular32-row map
        movem.l d0-d7/a0-a6,-(sp)
        move.w M4_BOSS_SCROLL,d6
        addi.w #223,d6
        lsr.w #3,d6
        cmp.w M4_BOSS_BG_BOTTOM,d6
        beq M4BossBackgroundDone
        move.w d6,M4_BOSS_BG_BOTTOM
        move.w d6,d0
        andi.w #31,d0
        lsl.w #7,d0
        addi.w #$e000,d0
        bsr M4TextVideoWriteAddress
        moveq #0,d7
M4BossBackgroundTile:
        move.w d6,d0
        andi.w #32,d0
        lsl.w #6,d0
        move.w d6,d1
        andi.w #31,d1
        lsl.w #5,d1
        add.w d1,d0
        move.w d7,d1
        andi.w #32,d1
        lsl.w #5,d1
        add.w d1,d0
        move.w d7,d1
        andi.w #31,d1
        add.w d1,d0
        add.w d0,d0
        lea BG_MAP,a0
        move.w (a0,d0.w),d0
        rol.w #8,d0
        move.w d0,d1
        andi.w #1023,d1
        addi.w #M4_DMA_BG/32,d1
        move.w d0,d2
        andi.w #$1c00,d2
        beq.s M4BossBackgroundPalette
        ori.w #$2000,d1
M4BossBackgroundPalette:
        btst #14,d0
        beq.s M4BossBackgroundVFlip
        ori.w #$800,d1
M4BossBackgroundVFlip:
        btst #15,d0
        beq.s M4BossBackgroundPriority
        ori.w #$1000,d1
M4BossBackgroundPriority:
        btst #13,d0
        beq.s M4BossBackgroundWrite
        ori.w #$8000,d1
M4BossBackgroundWrite:
        move.w d1,VDP_DATA
        addq.w #1,d7
        cmpi.w #64,d7
        bne M4BossBackgroundTile
M4BossBackgroundDone:
        movem.l (sp)+,d0-d7/a0-a6
        rts
M4IntroBossBackgroundPublish:
        move.l #$40020010,VDP_CTRL ;VSRAM BG B, same VBlank as polygon page
        move.w M4_BOSS_SCROLL,VDP_DATA
        move.w M4_BOSS_SCROLL,M4_BOSS_SCROLL_PRESENT
        rts
