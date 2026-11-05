; Stage unit: Space Armada (0D:D2C3, route 1 stage 3). Strategies, player
; modes and effects of this stage; its strategy table is searched by
; M4LevelFindStrategy (M4LevelStrategyTables, level_objects.asm).
; Shape descriptors (fleet and interiors): tools/stages/armada_tunnel.py.
; Documentation, ROM correspondence and tests of the fleet and interiors:
; build/agent-armada-fleet/FLEET.md (armada-oracle.py: ROM 65816 vs this
; 68000 code, tick by tick, on the stage script).
; RAM: $FF9D00..$FF9DFF (reserved for this stage).
M4_AR equ $ff9d00
M4_AR_GF2 equ M4_AR+0 ;.b gameflags2 $14D3 (bit0 gf2_stratflag1: opens sdoor1)
; Extended object fields of this stage (free X offsets 38..55).
X_AR_1CE1 equ -$8000+38 ;.b alx $1CE1 (cruiser2fire launcher x offset)

M4StrategiesSpaceArmada:
        ; the fleet (level_armada_fleet.asm)
        dc.l $0ab304,M4ArShips
        dc.l $0ab34c,M4ArSzaco5
        dc.l $08db39,M4ArWingLazer
        ; up1man 08:D85A: M4StratUp1man (level_meteor.asm, meteor-compare up1man)
        dc.l $08a386,M4ArShip1a
        dc.l $089e1f,M4ArShip2
        dc.l $0ab50a,M4ArSDoor1
        dc.l $0ab5fd,M4ArSDoor2
        dc.l $08a035,M4ArShip3
        dc.l $0acc0d,M4ArShip3a
        dc.l $0ab721,M4ArCruiser1
        dc.l $0ab727,M4ArCruiser1F
        dc.l $0ab01c,M4ArCruiser2
        dc.l $0aaf28,M4ArCruiser2Fire
        include 'stages/level_armada_tunnel_strats.asm'
        include 'stages/level_armada_boss_strats.asm'
        include 'stages/level_armada_final_strats.asm'
        include 'stages/level_armada_player_strats.asm'
        dc.l 0

; ---------------------------------------------------------------------
; Helpers. a0 object, a1 player.

; d0.b = gameframe + lo8(al1pt). al1pt is the original-like address $0336 +
; slot * $36 (02:F4BB pool, 54-byte records) so that objects get distinct
; phases as in the ROM (the port's 64-byte slots would share one).
M4ArPhase:
        move.l d1,-(sp)
        move.w a0,d1
        subi.w #M4_LV_OBJ&$ffff,d1
        lsr.w #6,d1
        mulu.w #$36,d1
        addi.w #$36,d1
        move.w M4_LV_GAMEFRAME,d0
        add.b d1,d0
        move.l (sp)+,d1
        rts

; banktoplayer 1F:DA57 with the phase of M4ArPhase: rotz += asr6(x - px);
; every 4th (gameframe + al1pt): roty +/- 1 by the side, rotx +/- 1 by y.
M4ArBankToPlayer:
        movem.l d0-d1,-(sp)
        move.w (a0),d0
        sub.w M4_SC_PPOSX,d0
        move.w d0,d1
        asr.w #6,d1
        add.b d1,14(a0)
        move.w d0,d1
        bsr M4ArPhase
        andi.b #3,d0
        bne M4ArBankDone
        tst.w d1
        bmi M4ArBankYawNeg
        addq.b #1,13(a0)
        bra M4ArBankPitch
M4ArBankYawNeg:
        subq.b #1,13(a0)
M4ArBankPitch:
        move.w 2(a0),d0
        sub.w M4_SC_PPOSY,d0
        bmi M4ArBankPitchNeg
        addq.b #1,12(a0)
        bra M4ArBankDone
M4ArBankPitchNeg:
        subq.b #1,12(a0)
M4ArBankDone:
        movem.l (sp)+,d0-d1
        rts

; rotx = Achase8_n(rotx, pitchTo(a2)), roty = Achase8_n(roty, yawTo(a2));
; d2 = n.
M4ArChaseAim:
        jsr M4EnPitchTo
        move.b d0,d1
        move.b 12(a0),d0
        jsr M4EnChase8
        move.b d0,12(a0)
        jsr M4EnYawTo
        move.b d0,d1
        move.b 13(a0),d0
        jsr M4EnChase8
        move.b d0,13(a0)
        rts

; d0 = ROM shape header -> d0 = descriptor (or $FFFF nullshape) and the
; original header kept in X_SHAPEHDR of a2 by the callers below.
; Create an object behind the current one with the shape of header d0 ->
; a2 (Z set on failure). 1F:D54B.
M4ArCreateHdr:
        movem.l d0/d1,-(sp)
        move.w d0,d1
        jsr M4LevelShapeIndex
        jsr M4EnCreate
        beq M4ArCreateFail
        move.w d1,X_SHAPEHDR(a2)
M4ArCreateFail:
        movem.l (sp)+,d0/d1
        cmpa.w #0,a2
        rts
; Shape of header d0 on a2.
M4ArSetShapeA2:
        movem.l d0-d1/a0,-(sp)
        movea.l a2,a0
        move.w d0,X_SHAPEHDR(a0)
        jsr M4LevelShapeIndex
        jsr M4LevelSetShape
        movem.l (sp)+,d0-d1/a0
        rts
; Shape of header d0 on a0.
M4ArSetShape:
        movem.l d0-d1,-(sp)
        move.w d0,X_SHAPEHDR(a0)
        jsr M4LevelShapeIndex
        jsr M4LevelSetShape
        movem.l (sp)+,d0-d1
        rts

; link_child 1F:D56F: d0 header, d1.b id, d2.l Istrat -> a2 child created
; behind a0 (1F:D54B), sbyte1 = id, al_ptr = a0, sword1 0, appended to the
; sword1 chain of a0; mother/child sflags4. Z set on failure.
M4ArMakeChild:
        movem.l d0-d2/a3,-(sp)
        bsr M4ArCreateHdr
        beq M4ArMakeChildDone
        move.l d2,32(a2)
        move.b d1,36(a2)
        move.w a0,X_ALPTR(a2)
        clr.w 40(a2)
        movea.l a0,a3
M4ArMakeChildTail:
        move.w 40(a3),d0
        beq M4ArMakeChildLink
        movea.w d0,a3
        bra M4ArMakeChildTail
M4ArMakeChildLink:
        move.w a2,40(a3)
        bset #6,X2_FL4(a0)
        bset #4,X2_FL4(a2)
M4ArMakeChildDone:
        movem.l (sp)+,d0-d2/a3
        cmpa.w #0,a2
        rts

; find_child 1F:DC40 (d0.b id, mother a3) and remove it now (1F:D540 on an
; object other than the running one: removedeadal). Z set when missing.
M4ArRemoveChild:
        movem.l d1/a0/a2,-(sp)
        movea.l a3,a2
        jsr M4PvFindChild
        move.l a2,d1
        beq M4ArRemoveChildDone
        movea.l a2,a0
        jsr M4LevelRemove
        moveq #1,d1
M4ArRemoveChildDone:
        tst.l d1
        movem.l (sp)+,d1/a0/a2
        rts

        include 'stages/level_armada_fleet.asm'
        include 'stages/level_armada_tunnel.asm'
        include 'stages/level_armada_boss.asm'
        include 'stages/level_armada_final.asm'
        include 'stages/level_armada_player.asm'
