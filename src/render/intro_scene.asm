; Own consumers of selected-ROM commands86 at78E0/78EE/78FC.
; Scope ends BEFORE the next unimplemented consumer; no skipped script event.
M4_SHIPS equ $ff8700 ; three original 32-byte contexts
M4_SHIP_CREATED equ $ff8278
M4_SCENE_TICK equ $ff827a
M4_SCENE_PENDING equ $ff827e
M4_SHIP_SPAWNS equ $ff8760
M4_SHIP_DRAW_LIST equ $ffb200 ;40(context LONG,Z WORD) entries
M4_SHIP_DRAW_COUNT equ $ff9ac0

M4IntroSceneInit:
        bsr M4IntroNativeInit
        bsr M4IntroWeaponsInit
        bsr M4IntroEffectsInit
        bsr M4IntroGeometryInit
        bsr M4IntroBossInit
        bsr M4IntroFastInit
        bsr M4IntroZacosInit
        lea M4_FIRE_OBJECT,a0
        moveq #7,d0
M4IntroSceneClearFire:
        clr.l (a0)+
        dbra d0,M4IntroSceneClearFire
        clr.l M4_FIRE_CREATED
        clr.w M4_LAST_NATIVE
        clr.l M4_LAST_CONTEXT
        clr.l M4_MAPVAR1_CONTEXT
        clr.w M4_MAPVAR1_NATIVE
        lea M4_SHIPS,a0
        moveq #23,d0
M4IntroSceneClear:
        clr.l (a0)+
        dbra d0,M4IntroSceneClear
        clr.w M4_SHIP_CREATED
        clr.w M4_POLY_COUNT
        clr.w M4_SCENE_PENDING
        clr.l M4_SHIP_SPAWNS
        clr.w M4_SHIP_SPAWNS+4
        move.w INTRO_CAMERA,TEXT_MAP_CONTEXT+4 ; original map lastZ189 at entry
        move.w INTRO_CAMERA,TEXT_MAP_CONTEXT+8
        move.w #$a55a,M4_POLY_INPUT-2
        move.w #$a55a,M4_POLY_INPUT+4096
        rts

; Called after camera cache, BEFORE object traversal. Return0/1pending/FFFF.
M4IntroSceneMap:
        lea TEXT_MAP_CONTEXT,a0
        move.w INTRO_CAMERA+2,d0
        jsr M4ScriptTick
M4IntroSceneEvent:
        cmpi.w #1,d0
        bne M4IntroSceneReturn
        cmpi.w #$4a,20(a0)
        beq M4IntroSceneSave
        cmpi.w #$48,20(a0)
        beq M4IntroSceneLink
        cmpi.w #$86,20(a0)
        bne M4IntroScenePending
        cmpi.w #$790e,(a0)
        beq M4IntroSceneCreateFire
        cmpi.w #$7924,(a0)
        beq M4IntroSceneCreateBoss
        cmpi.w #$7935,(a0)
        blo.s M4IntroSceneOldShips
        cmpi.w #$79eb,(a0) ;eight zacointro, zaco2intro and four more
        blo M4IntroSceneCreateZaco
M4IntroSceneOldShips:
        cmpi.w #3,M4_SHIP_CREATED
        bhs M4IntroScenePending
        cmpi.b #$f0,9(a1)
        bne M4IntroScenePending
        cmpi.b #$e5,10(a1)
        bne M4IntroScenePending
        cmpi.b #7,13(a1)
        bne M4IntroScenePending
        moveq #0,d4
        cmpi.b #$90,11(a1)
        bne.s M4IntroSceneOtherShip
        cmpi.b #$8a,12(a1)
        beq M4IntroSceneCreate
M4IntroSceneOtherShip:
        moveq #1,d4
        cmpi.b #$3b,11(a1)
        bne.s M4IntroSceneThirdShip
        cmpi.b #$8b,12(a1)
        beq M4IntroSceneCreate
M4IntroSceneThirdShip:
        moveq #2,d4
        cmpi.b #$ea,11(a1)
        bne M4IntroScenePending
        cmpi.b #$88,12(a1)
        bne M4IntroScenePending
        bra M4IntroSceneCreate
M4IntroSceneCreateZaco:
        cmpi.b #$c5,11(a1)
        bne.s M4SceneCheckZaco2
        cmpi.b #$8e,12(a1)
        beq.s M4SceneZacoStrategy
        bra M4IntroScenePending
M4SceneCheckZaco2:
        cmpi.b #$91,11(a1) ;zaco2intro_Istrat07:8F91
        bne M4IntroScenePending
        cmpi.b #$8f,12(a1)
        bne M4IntroScenePending
M4SceneZacoStrategy:
        cmpi.b #7,13(a1)
        bne M4IntroScenePending
        cmpi.b #$88,9(a1)
        bne.s M4SceneCheckZacoC22C
        cmpi.b #$e3,10(a1)
        beq.s M4SceneZacoValidated
        bra M4IntroScenePending
M4SceneCheckZacoC22C:
        cmpi.b #$2c,9(a1)
        bne M4IntroScenePending
        cmpi.b #$c2,10(a1)
        bne M4IntroScenePending
M4SceneZacoValidated:
        movea.l a0,a6
        jsr M4ScriptOperand
        move.w d1,2(a0)
        bsr M4IntroZacoCreate
        tst.w d0
        bne M4IntroSceneReturn
        movea.l a6,a0
        jsr M4ScriptCommit
        bra M4IntroSceneEvent
M4IntroSceneCreateBoss:
        cmpi.b #$44,9(a1)
        bne M4IntroScenePending
        cmpi.b #$e6,10(a1)
        bne M4IntroScenePending
        cmpi.b #$a3,11(a1)
        bne M4IntroScenePending
        cmpi.b #$8c,12(a1)
        bne M4IntroScenePending
        cmpi.b #7,13(a1)
        bne M4IntroScenePending
        movea.l a0,a6
        jsr M4ScriptOperand
        move.w d1,2(a0)
        bsr M4IntroBossCreate
        tst.w d0
        bne M4IntroSceneReturn
        movea.l a6,a0
        jsr M4ScriptCommit
        bra M4IntroSceneEvent
M4IntroSceneCreate:
        movea.l a0,a6
        move.w d4,d5
        jsr M4ScriptOperand
        move.w d1,2(a0) ; wait from ORIGINAL command, not elapsed MD frames
        move.w M4_SHIP_CREATED,d0
        move.w d0,d2
        add.w d2,d2
        lea M4_SHIP_SPAWNS,a2
        move.w M4_SCENE_TICK,(a2,d2.w)
        lsl.w #5,d0
        lea M4_SHIPS,a0
        adda.w d0,a0
        move.w d5,d0
        move.w INTRO_CAMERA+2,d1
        bsr M4IntroShipInit
        tst.w d0
        bne M4IntroSceneReturn
        move.l a0,M4_LAST_CONTEXT
        bsr M4IntroNativeAllocate
        move.w d0,M4_LAST_NATIVE
        move.w M4_SHIP_CREATED,d1
        add.w d1,d1
        lea M4_NATIVE_SHIPS,a1
        move.w d0,(a1,d1.w)
        addq.w #1,M4_SHIP_CREATED
        movea.l a6,a0
        jsr M4ScriptCommit
        bra M4IntroSceneEvent
M4IntroSceneSave:
        cmpi.w #$790a,(a0)
        bne M4IntroScenePending
        cmpi.b #$36,1(a1)
        bne M4IntroScenePending
        cmpi.b #$17,2(a1)
        bne M4IntroScenePending
        tst.b 3(a1)
        bne M4IntroScenePending
        move.l M4_LAST_CONTEXT,M4_MAPVAR1_CONTEXT
        move.w M4_LAST_NATIVE,M4_MAPVAR1_NATIVE
        jsr M4ScriptCommit
        bra M4IntroSceneEvent
M4IntroSceneCreateFire:
        cmpi.b #$a1,9(a1) ; script WORDs are LE and may be odd-aligned
        bne M4IntroScenePending
        cmpi.b #$ac,10(a1)
        bne M4IntroScenePending
        cmpi.b #$e6,11(a1)
        bne M4IntroScenePending
        cmpi.b #$8b,12(a1)
        bne M4IntroScenePending
        cmpi.b #7,13(a1)
        bne M4IntroScenePending
        tst.w M4_FIRE_CREATED
        bne M4IntroScenePending
        movea.l a0,a6
        lea M4_FIRE_OBJECT,a2
        moveq #0,d2
        moveq #3,d3
M4IntroSceneFireCoordinate:
        move.b 1(a1,d3.w),d0
        lsl.w #8,d0
        move.b (a1,d3.w),d0
        move.w d0,(a2,d2.w)
        addq.w #2,d2
        addq.w #2,d3
        cmpi.w #6,d2
        bne.s M4IntroSceneFireCoordinate
        move.w INTRO_CAMERA+2,d0
        add.w d0,4(a2)
        jsr M4ScriptOperand
        move.w d1,2(a0)
        movea.l a2,a0
        bsr M4IntroFireInit
        move.w #1,M4_FIRE_CREATED
        move.l a0,M4_LAST_CONTEXT
        bsr M4IntroNativeAllocate
        move.w d0,M4_NATIVE_FIRE
        move.w d0,M4_LAST_NATIVE
        movea.l a6,a0
        jsr M4ScriptCommit
        bra M4IntroSceneEvent
M4IntroSceneLink:
        cmpi.w #$791c,(a0)
        bne M4IntroScenePending
        cmpi.b #$26,1(a1)
        bne M4IntroScenePending
        tst.b 2(a1)
        bne M4IntroScenePending
        cmpi.b #$36,3(a1)
        bne M4IntroScenePending
        cmpi.b #$17,4(a1)
        bne M4IntroScenePending
        tst.b 5(a1)
        bne M4IntroScenePending
        move.w M4_MAPVAR1_NATIVE,M4_FIRE_TARGET
        jsr M4ScriptCommit
        bra M4IntroSceneEvent
M4IntroScenePending:
        move.w 20(a0),M4_SCENE_PENDING
        moveq #1,d0
M4IntroSceneReturn:
        rts

; Original insert-first traversal: newest ship first, then texts/player.
M4IntroSceneShips:
        movem.l d1-d7/a0-a6,-(sp)
        bsr M4IntroZacosStep
        bsr M4IntroBossStep
        tst.w M4_FIRE_CREATED
        beq.s M4IntroSceneShipCount
        lea M4_FIRE_OBJECT,a0
        move.w M4_SCENE_TICK,d0
        move.w M4_NATIVE_FIRE,d1
        move.w INTRO_CAMERA+6,d2
        bsr M4IntroFireTick
        tst.w d0
        beq.s M4IntroSceneFireComplete
        bsr M4IntroWeaponsFire
        tst.w d0
        bne M4IntroSceneShipsExit
        lea M4_FIRE_OBJECT,a0
        clr.w 26(a0)
        move.w INTRO_CAMERA+6,d0
        add.w d0,4(a0)
M4IntroSceneFireComplete:
        tst.w M4_FIRE_OBJECT+22
        bne.s M4IntroSceneShipCount
        move.w M4_NATIVE_FIRE,d0
        beq.s M4IntroSceneShipCount
        clr.w M4_NATIVE_FIRE
        bsr M4IntroNativeRemove
M4IntroSceneShipCount:
        bsr M4IntroWeaponsTick
        bsr M4IntroFlashesTick
        move.w M4_SHIP_CREATED,d5
        beq M4IntroSceneShipsDone
        subq.w #1,d5
M4IntroSceneShipNext:
        move.w d5,d0
        lsl.w #5,d0
        lea M4_SHIPS,a0
        adda.w d0,a0
        move.w M4_SCENE_TICK,d0
        move.w INTRO_CAMERA+6,d1
        ; The strategy clobbers d0-d7; destination index is caller state.
        move.w d5,-(sp)
        cmpi.b #12,21(a0)
        bne.s M4IntroSceneNormalShip
        bsr M4IntroFastParentTick
        bra.s M4IntroSceneShipTicked
M4IntroSceneNormalShip:
        bsr M4IntroShipTick
M4IntroSceneShipTicked:
        move.w (sp)+,d5
        tst.w d0
        beq.s M4IntroSceneShipComplete
        cmpi.w #3,26(a0)
        beq.s M4IntroSceneFastBirth
        cmpi.w #2,26(a0)
        bne.s M4IntroSceneEffectPending
        bsr M4IntroEffectMedium
        move.w d5,-(sp)
        bsr M4IntroShipResume
        move.w (sp)+,d5
        bra.s M4IntroSceneShipComplete
M4IntroSceneFastBirth:
        bsr M4IntroFastDebrisCreate
        tst.w d0
        bne M4IntroSceneShipsExit
        bra.s M4IntroSceneShipComplete
M4IntroSceneEffectPending:
        move.w #$eeee,M4_SCENE_PENDING
        bra.s M4IntroSceneShipsExit
M4IntroSceneShipComplete:
        cmpi.w #2,d5
        bne.s M4IntroSceneShipRemoval
        bsr M4IntroFastActorsTick
        tst.w d0
        bne M4IntroSceneShipsExit
        bsr M4IntroEffectsStep
M4IntroSceneShipRemoval:
        cmpi.w #5,24(a0)
        bne.s M4IntroSceneShipRemoved
        move.w d5,d0
        add.w d0,d0
        lea M4_NATIVE_SHIPS,a1
        adda.w d0,a1
        move.w (a1),d0
        beq.s M4IntroSceneShipRemoved
        clr.w (a1)
        bsr M4IntroNativeRemove
M4IntroSceneShipRemoved:
        dbra d5,M4IntroSceneShipNext
M4IntroSceneShipsDone:
        moveq #0,d0
M4IntroSceneShipsExit:
        movem.l (sp)+,d1-d7/a0-a6
        rts

; Original worldZ sort, new before equal, same null/old_type sortZ bias0.
M4IntroSceneDraw:
        clr.w M4P_EARLY ;previous tick was already latched or drawn serially
        clr.w M4_POLY_COUNT
        clr.w M4_MESH_ERROR
        clr.w M4_SHIP_DRAW_COUNT
        bsr M4IntroZacosSort
        bsr M4IntroBossSort
        bsr M4IntroSceneSortWeapons ; original traversal weapons before ships
        bsr M4IntroSceneSortFlashes
        move.w M4_SHIP_CREATED,d7
        beq M4IntroSceneDrawSorted
        subq.w #1,d7
M4IntroSceneSort:
        move.w d7,d0
        lsl.w #5,d0
        lea M4_SHIPS,a0
        adda.w d0,a0
        tst.w 22(a0)
        beq.s M4IntroSceneSortNext
        bsr M4IntroSceneSortObject
        cmpi.w #2,d7
        bne.s M4IntroSceneSortNext
        bsr M4IntroFastActorsSort
        bsr M4IntroSceneSortEffects
M4IntroSceneSortNext:
        dbra d7,M4IntroSceneSort
        bra.s M4IntroSceneDrawSorted
M4IntroSceneSortEffects:
        movem.l d7/a0,-(sp)
        move.w M4_EFFECT_COUNT,d7
        beq.s M4IntroSceneSortEffectsDone
        subq.w #1,d7
M4IntroSceneSortEffect:
        move.w d7,d0
        cmpi.w #2,d0
        bhs.s M4IntroSceneSortEffectSlot
        eori.w #1,d0
M4IntroSceneSortEffectSlot:
        lsl.w #5,d0
        lea M4_EFFECTS,a0
        adda.w d0,a0
        tst.w 22(a0)
        beq.s M4IntroSceneSortEffectNext
        bsr M4IntroSceneSortObject
M4IntroSceneSortEffectNext:
        dbra d7,M4IntroSceneSortEffect
M4IntroSceneSortEffectsDone:
        movem.l (sp)+,d7/a0
        rts
M4IntroSceneSortFlashes:
        lea M4_ZFLASHES,a0
        moveq #M4_ZFLASH_SLOTS-1,d7
M4IntroSceneSortFlash:
        tst.w 22(a0)
        beq.s M4IntroSceneSortFlashNext
        bsr M4IntroSceneSortObject
M4IntroSceneSortFlashNext:
        lea 32(a0),a0
        dbra d7,M4IntroSceneSortFlash
        rts
M4IntroSceneSortWeapons:
        move.w M4_WEAPON_COUNT,d7
        beq.s M4IntroSceneSortWeaponsDone
        subq.w #1,d7
M4IntroSceneSortWeapon:
        move.w d7,d0
        lsl.w #5,d0
        lea M4_WEAPONS,a0
        adda.w d0,a0
        tst.w 22(a0)
        beq.s M4IntroSceneSortWeaponNext
        bsr M4IntroSceneSortObject
M4IntroSceneSortWeaponNext:
        dbra d7,M4IntroSceneSortWeapon
M4IntroSceneSortWeaponsDone:
        rts
M4IntroSceneDrawSorted:
        bsr M4IntroGeometryPrepare
        if def(M4_PROFILE)
        move.l d0,-(sp)
        moveq #2,d0
        jsr M4ProfMark
        move.l (sp)+,d0
        endif
        tst.w d0
        bne M4IntroSceneDrawError
        tst.b M4_BSP_SVP
        bne.s M4IntroSceneNoRadio ;SVP mode: the jobs were written during the cmd9 request
        bsr M4IntroSceneDrawObjects
M4IntroSceneNoRadio:
        tst.w M4_MESH_ERROR
        bne M4IntroSceneDrawErrorReturn
        if def(M4_PROFILE)
        move.l d0,-(sp)
        moveq #6,d0
        jsr M4ProfMark
        move.l (sp)+,d0
        endif
        bsr M4IntroGeometryClip
        if def(M4_PROFILE)
        move.l d0,-(sp)
        moveq #7,d0
        jsr M4ProfMark
        move.l (sp)+,d0
        endif
        tst.w d0
        bne M4IntroSceneDrawError
M4IntroSceneDrawErrorReturn:
        if def(M4_GRAPHICS117)
        jmp G117H114AbortScene
        else
        move.w M4_MESH_ERROR,d0
        endif
        rts
M4IntroSceneDrawError:
        move.w d0,M4_MESH_ERROR
        rts

; The ordered object loop: sprite and mesh work of every drawn object (faces on the 68000, or the jobs of the SVP),
; then the level's radio/HUD/text packets. In SVP mode it runs from the cmd9 request (M4_GEO_HOOK9).
M4IntroSceneDrawObjects:
        lea M4_SHIP_DRAW_LIST,a4
        if def(M4_STEXT)
        clr.w M4_END_TEXTI ;level text objects in the same painter order
        endif
        move.w M4_SHIP_DRAW_COUNT,d7
        beq M4IntroSceneDrawDone
        subq.w #1,d7
M4IntroSceneDrawShip:
        if def(M4_STEXT)
        tst.w M4_END_TEXTN ;no text objects (every image outside the ending): no call
        beq.s M4IntroSceneNoText
        move.w 4(a4),d0
        jsr M4EndTextUpTo ;texts farther than this entry
M4IntroSceneNoText:
        endif
        movea.l (a4),a0
        bsr M4SpriteEntry
        beq.s M4IntroSceneNotSprite
        movea.l d0,a1
        bsr M4IntroGeometrySprite
        move.w M4_MESH_ERROR,d0 ;0 unless the face buffer is full
        bra M4IntroSceneDrawCheck
M4IntroSceneNotSprite:
        cmpi.b #3,21(a0)
        beq.s M4IntroSceneDrawLaser
        bhi.s M4IntroSceneDrawEffect
        bsr M4IntroMesh
        bra.s M4IntroSceneDrawCheck
M4IntroSceneDrawEffect:
        bsr M4IntroEffectMesh
        bra.s M4IntroSceneDrawCheck
M4IntroSceneDrawLaser:
        bsr M4IntroLaserMesh
M4IntroSceneDrawCheck:
        cmpi.b #3,21(a0)
        bhs.s M4IntroSceneFlashConsumed
        andi.w #$fffb,30(a0) ; original MAIN draw-list consumes hitflash once
M4IntroSceneFlashConsumed:
        tst.w d0
        bne M4IntroSceneDrawDone
        lea 6(a4),a4
        addi.l #1024,M4_GEO_CURRENT
        dbra d7,M4IntroSceneDrawShip
M4IntroSceneDrawDone:
        if def(M4_STEXT)
        tst.w M4_END_TEXTN
        beq.s M4IntroSceneNoTextRest
        jsr M4EndTextRest ;the nearest texts
M4IntroSceneNoTextRest:
        endif
        tst.w M4_GEO_VIEW ;level: the radio box is drawn after the objects
        beq.s M4IntroSceneObjectsEnd
        jsr M4BossBarDraw ;mdrawbossHP 01:AFEB (level_boss.asm)
        jsr M4SpCockpitHud ;GSU cockpit HUD 01:D76B (level_cockpit.asm)
        jsr M4RadioDraw
        jsr M4TxDraw ;pause / results texts (level_text.asm)
M4IntroSceneObjectsEnd:
        rts

; a0 object -> d0 = its mssprite entry (Z set: not a sprite). Level effect
; objects: the descriptor's texture entry (shared billboard geometry);
; otherwise the entry of its SVP model id.
M4SpriteEntry:
        movem.l d1/a1,-(sp)
        moveq #0,d0
        move.b 21(a0),d0
        subq.w #2,d0
        bmi.s M4SpriteNone
        tst.w M4_GEO_VIEW
        beq.s M4SpriteByModel
        move.w 46(a0),d0
        cmpi.w #M4_FX_FIRST,d0
        blo.s M4SpriteNone ;level polygon shapes
        cmpi.w #M4_LEVEL_DESCRIPTORS,d0
        bhs.s M4SpriteNone
        lsl.w #5,d0
        lea M4LevelShapeDescriptors,a1
        ; Historical FX indices may now alias real polygon descriptors.
        ; Only sprites have a texture pointer followed by a null group list.
        tst.l 4(a1,d0.w)
        bne.s M4SpriteNone
        move.l (a1,d0.w),d0
        beq.s M4SpriteDone
        move.w X_COLTAB(a0),d1 ;alx+$20 coltab instead of the header table
        beq.s M4SpriteDone
        lea M4SpriteColtabs,a1
M4SpriteColtabFind:
        tst.w (a1)
        beq.s M4SpriteDone ;not converted: header frames kept
        cmp.w (a1)+,d1
        beq.s M4SpriteColtabFound
        addq.l #4,a1
        bra.s M4SpriteColtabFind
M4SpriteColtabFound:
        move.l (a1),d0
        bra.s M4SpriteDone
M4SpriteByModel:
        cmpi.w #24,d0
        bhs.s M4SpriteNone
        lsl.w #2,d0
        lea M4SpriteModels,a1
        move.l (a1,d0.w),d0
        bra.s M4SpriteDone
M4SpriteNone:
        moveq #0,d0
M4SpriteDone:
        movem.l (sp)+,d1/a1 ;flags of movem are unchanged: test below
        tst.l d0
        rts

; Level entry: d3 = painter key already computed (sortz), a0 = context.
M4IntroSceneSortAt:
        movem.l d0-d3/a2-a3,-(sp)
        bra.s M4IntroSceneSortDepth
M4IntroSceneSortObject:
        movem.l d0-d3/a2-a3,-(sp)
        move.w 4(a0),d3
        sub.w INTRO_CAMERA+8,d3
        cmpi.b #7,21(a0)
        blo.s M4IntroSceneSortDepth
        cmpi.b #9,21(a0)
        bhi.s M4IntroSceneSortDepth
        addq.w #1,d3 ;original al_depthoff1 on body and both children
M4IntroSceneSortDepth:
        lea M4_SHIP_DRAW_LIST,a2
        move.w M4_SHIP_DRAW_COUNT,d2
        move.w d2,d1
        mulu.w #6,d1
        lea (a2,d1.w),a3
M4IntroSceneSortFind:
        tst.w d2
        beq.s M4IntroSceneSortInsert
        move.w 4(a2),d0
        subq.w #1,d0
        sub.w d3,d0
        bmi.s M4IntroSceneSortInsert
        lea 6(a2),a2
        subq.w #1,d2
        bra.s M4IntroSceneSortFind
M4IntroSceneSortInsert:
        tst.w d2
        beq.s M4IntroSceneSortStore
M4IntroSceneSortShift:
        move.l -6(a3),(a3)
        move.w -2(a3),4(a3)
        subq.l #6,a3
        subq.w #1,d2
        bne.s M4IntroSceneSortShift
M4IntroSceneSortStore:
        move.l a0,(a2)
        move.w d3,4(a2)
        addq.w #1,M4_SHIP_DRAW_COUNT
        movem.l (sp)+,d0-d3/a2-a3
        rts
