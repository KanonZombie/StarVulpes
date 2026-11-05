; Path interpreter (path_istrat 04:8022 / .strat 04:805F), all stages.
; Specification: build/research/corneria-paths.md (USA rev0, handlers read
; and executed by tools/path-oracle.py); correspondence in LEVEL_ORIGIN.md;
; the last 44 opcodes and their ROM-vs-68000 test: build/agent-paths/
; PATH_OPS.md (tools/path-ops-oracle.py runs both handler sets).
; Path bytes: build/level-paths.bin (offset 0 = 04:A3FE); handler table
; build/level-paths.inc (166 opcodes, all with a handler; operands or
; references the port does not model stop the level: M4PvFatal codes).
; A tick runs commands until the first one that yields; then .move
; (04:A19A), triggers (04:A099), children positions (09:E118).
; Handler convention: a0 object, a1 player, a4 = opcode address; d7 out:
PV_CONT equ 0 ;next command, same tick
PV_YIELD equ 1 ;.move, then .end2
PV_END2 equ 2 ;triggers/children, no movement (explode)
PV_END equ 3 ;.end: no triggers (remove)
PV_TRET equ 4 ;return popped $FFFF: end of a trigger routine
PV_GOTO equ 5 ;04:A22A: smoke check, then .end2 (gotopos)
; d6 = remove request of the current object (deferred, 1F:D501).
; Handlers may clobber d0-d5/a2-a3.
X2_FL2 equ -$7000+0 ;.b path sflags2: $80 spaceship $40 zaco $20 genvecs $10 reltoplayer
X2_FL3 equ -$7000+1 ;.b sflags3: $04 hit, $02 smoke, $01 hit by the player
X2_FL4 equ -$7000+2 ;.b sflags4: $40 mother, $20 flagged, $10 child, $08 invisible
X2_WEAPON equ -$7000+3 ;.b +$2C weapon id
X2_PBYTE1 equ -$7000+4 ;.b alx+$32
X2_PBYTE2 equ -$7000+5 ;.b alx+$33
X2_PWORD1 equ -$7000+6 ;.w alx+$34
X2_SP equ -$7000+8 ;.b gosub/do stack depth (WORDs)
X2_NTRIG equ -$7000+9 ;.b triggers
X2_STACK equ -$7000+10 ;12 WORDs (heap nodes of mpush/mpull)
X2_TRIG equ -$7000+34 ;6 x (target.w, type.b, 0)
X2_CHILDX equ -$7000+58 ;.b x3 alx+$22..24 child offset (x/8)
X2_CHILDRX equ -$7000+61 ;.b x3 alx+$25..27 child rotation offset
PV_STACKMAX equ 12
PV_TRIGMAX equ 6
M4_PV equ M4_LV+100
M4_PV_PATHPTR equ M4_PV+0 ;.w $F0AD
M4_PV_INTRIG equ M4_PV+2 ;.b running triggers
M4_PV_IFNOT equ M4_PV+3 ;.b $F0AF pifnot
M4_PV_FRIENDHP equ M4_PV+4 ;4 BYTEs $18A1.. (index = sbyte4 friend id: 1 rabbit $18A2, 2 falcon $18A3, 3 frog $18A4)
M4_PV_METER equ M4_PV+8 ;.b $1FFD friends_meter
M4_PV_LINK equ M4_PV+10 ;.w $176B pathlink
M4_PV_LASTOBJ equ M4_PV+14 ;.l $F0CA becomelastobj
; Path globals 7E:F0B0..F0DF (import/export with DB = $7E), little-endian as
; on the SNES: gbyte1/2 F0B1/F0B2, F0B4 (Corneria), ebyte2 F0D5, F0D6, F0D7,
; eword1 F0D9, eword2 F0DB (training.md 3).
M4_PV_GLOB equ $fff870
M4_PV_GLOBBASE equ $f0b0
M4_PV_GLOBSIZE equ 48
; become 04:9B6B / unbecome: the object the path belongs to and the child's
; own path pointer while the commands act on the child ($F0C6/$F0C8).
M4_PV_BECOME equ $fff8a0 ;.l real object (0 = none)
M4_PV_BECOMEPC equ $fff8a4 ;.w child's path pointer
; Port fields used by the paths (extended block, X_ offsets 27..30).
X_TEXTFL equ -$8000+27 ;.b bit0 textobj (sflags $1D $40, text)
X_COLTAB equ -$8000+28 ;.w alx+$20 ($1CEA): colour table / text string
X_DEBRIS equ -$8000+56 ;.w alx+$1A ($1CE4) debrisshape: original shape header (debris;
; the same equate as level_asteroid.asm, whose explode debris 06:F1DA reads it)
X_TY equ -$8000+60 ;.b alx+$2B ($1CF5) trail colour (trail; .move 04:A247)
M4_PV_ROUTE equ 0 ;$1FFF on route 1 [H, corneria-enemies.md]

; initialise_l 02:E265: friends_hp = 40 for every friend (game start).
M4PathGameInit:
        move.l #$28282828,M4_PV_FRIENDHP
        clr.b M4_PV_METER
        rts
M4PathLevelInit:
        clr.l M4_PV
        clr.w M4_PV_LINK
        lea M4_PV_GLOB,a0
        moveq #M4_PV_GLOBSIZE/4-1,d0
M4PvGlobClear:
        clr.l (a0)+
        dbra d0,M4PvGlobClear
        clr.l M4_PV_BECOME
        clr.l M4_PV_LASTOBJ
        rts

; pathdha_istrat 04:8004: HP = AP = 10, then path_istrat.
M4PathIstratDha:
        move.b #10,38(a0)
        move.b #10,39(a0)
; path_istrat 04:8022: loop strategy, pathhit / explode pointers, enemy1,
; shadow, sbyte4 0, pathptr 0, then the loop in the same call.
M4PathIstrat:
        move.l #M4PathStrat,32(a0)
        move.l #M4PvHit,X_COLL(a0)
        move.l #M4LevelExplode,X_EXP(a0)
        ori.b #CF_ENEMY1,44(a0)
        bset #F2_SHADOW,48(a0)
        clr.b X_SBYTE4(a0)
        clr.w M4_PV_PATHPTR
M4PathStrat:
        moveq #0,d6
        bsr M4PvExec
        cmpi.w #PV_YIELD,d7
        bne M4PathNotYield
        bsr M4PvMove
        bra M4PvEnd2
M4PathNotYield:
        cmpi.w #PV_GOTO,d7
        bne M4PathNotGoto
        bsr M4PvSmoke
        bra M4PvEnd2
M4PathNotGoto:
        cmpi.w #PV_END2,d7
        beq M4PvEnd2
        cmpi.w #PV_END,d7
        beq M4PvEnd
        bra M4PvFail ;PV_TRET outside a trigger
; .end2 04:A2AB: triggers, children positions (mother), hit flags cleared.
M4PvEnd2:
        bsr M4PvTriggers
        tst.w d6
        bne M4PvEnd
        btst #6,X2_FL4(a0)
        beq M4PvEnd
        bsr M4PvRotChildren
; .end 04:A2BC
M4PvEnd:
        andi.b #$fa,X2_FL3(a0)
        move.l d6,d0
        rts
M4PvFail:
        move.w #-1,M4_LV_STATUS
        move.w 42(a0),M4_LV_BADINDEX
        moveq #0,d0
        rts

; pathhit 04:A2C9: hit flag; hit by the player when the collider is a
; friend laser; then hitflash_Istrat (which ends in the path loop).
M4PvHit:
        bset #2,X2_FL3(a0)
        jsr M4LcCollider
        move.l a2,d0
        beq M4PvHitFlash
        btst #7,44(a2)
        beq M4PvHitFlash
        btst #3,44(a2)
        beq M4PvHitFlash
        bset #0,X2_FL3(a0)
M4PvHitFlash:
        jmp M4LcHitFlash

; Command loop until a handler returns d7 != 0.
M4PvExec:
        moveq #0,d0
        move.w 42(a0),d0
        cmpi.w #M4_PATH_SIZE,d0
        bhs M4PvBadPc
        lea M4PathBytes,a4
        adda.l d0,a4
        moveq #0,d0
        move.b (a4),d0
        cmpi.w #M4_PATH_OPS,d0
        bhs M4PvBadOpHere
        add.w d0,d0
        add.w d0,d0
        lea M4PathOps,a2
        movea.l (a2,d0.w),a2
        moveq #PV_CONT,d7
        jsr (a2)
        tst.w d7
        beq M4PvExec
        rts
M4PvBadPc:
        move.w #$7fff,M4_LV_BADOP
        bra M4PvBadCommon
M4PvBadOpHere:
M4PvBadOp:
        moveq #0,d0
        move.b (a4),d0
        ori.w #$7000,d0
        move.w d0,M4_LV_BADOP
M4PvBadCommon:
        move.w #-1,M4_LV_STATUS
        move.w 42(a0),M4_LV_BADINDEX
        moveq #PV_END,d7
        rts
; d0 = code -> level failure at this command. Codes: $70xx opcode/operand not
; ported, $7B60 setstrat to an unported strategy, $7Cxx command xx would follow
; a null object reference into WRAM 0 in the ROM, $7D43 debug (1F:BDEE).
M4PvFatal:
        move.w d0,M4_LV_BADOP
        bra M4PvBadCommon
M4PvBadAlvarOp: ;handler level: d0 = alvar byte not usable here
        andi.w #$ff,d0
        ori.w #$7e00,d0
        bra M4PvFatal
M4PvNullRef:
        moveq #0,d0
        move.b (a4),d0
        ori.w #$7c00,d0
        bra M4PvFatal

; Operand helpers. d1 = operand offset -> d0.w little-endian WORD.
M4PvRdW:
        move.b 1(a4,d1.w),d0
        lsl.w #8,d0
        move.b (a4,d1.w),d0
        rts
M4PvAdd:
        add.w d0,42(a0)
        rts
M4PvJumpAt: ;d1 = operand offset of the destination
        bsr M4PvRdW
        move.w d0,42(a0)
        rts
M4PvPush: ;d0.w
        moveq #0,d1
        move.b X2_SP(a0),d1
        cmpi.w #PV_STACKMAX,d1
        bhs M4PvStackBad
        add.w d1,d1
        lea X2_STACK(a0),a2
        move.w d0,(a2,d1.w)
        addq.b #1,X2_SP(a0)
        rts
M4PvPull: ;-> d0.w
        moveq #0,d1
        move.b X2_SP(a0),d1
        beq M4PvStackBad
        subq.w #1,d1
        move.b d1,X2_SP(a0)
        add.w d1,d1
        lea X2_STACK(a0),a2
        move.w (a2,d1.w),d0
        rts
M4PvStackBad:
        move.w #$7ffe,M4_LV_BADOP
        move.w #-1,M4_LV_STATUS
        moveq #0,d0
        rts
; alvar byte d0 (addalvaroffset 04:A083) -> a2 = port field, d1 = 1 for the
; shape (+$04: descriptor/header conversion), else 0. Unmapped -> failure.
M4PvAlvar:
        moveq #0,d1
        lea M4PvAlvarMap,a2
M4PvAlvarFind:
        cmpi.w #$ffff,(a2)
        beq M4PvAlvarBad
        cmp.b 1(a2),d0
        beq M4PvAlvarFound
        addq.l #4,a2
        bra M4PvAlvarFind
M4PvAlvarFound:
        move.w 2(a2),d1
        cmpi.w #$7fff,d1
        beq M4PvAlvarShape
        lea (a0,d1.w),a2
        moveq #0,d1
        rts
M4PvAlvarShape:
        movea.l a0,a2
        moveq #1,d1
        rts
M4PvAlvarBad:
        ori.w #$7e00,d0
        move.w d0,M4_LV_BADOP
        move.w #-1,M4_LV_STATUS
        lea M4_LV_BADINDEX,a2 ;harmless scratch target
        moveq #0,d1
        rts
M4PvAlvarMap: ;original alvar byte -> port offset ($7FFF shape)
        dc.w $04,$7fff,$0c,0,$0e,2,$10,4,$12,12,$13,13,$14,14,$15,15
        dc.w $2a,38,$2b,39
        dc.w $80+$23,X2_CHILDX+1,$80+$25,X2_CHILDRX,$80+$32,X2_PBYTE1
        dc.w $80+$33,X2_PBYTE2,$80+$34,X2_PWORD1
        dc.w $22,36,$80+$20,X_COLTAB,$80+$2a,X_TX,$80+$22,X2_CHILDX
        dc.w $80+$1c,18,$80+$24,X2_CHILDX+2,$80+$26,X2_CHILDRX+1,$80+$27,X2_CHILDRX+2,$ffff
; Original alvar d0.b -> Z set when the field is a WORD (+0C/0E/10, alx+$20/$34).
M4PvIsWordField:
        cmpi.b #$0c,d0
        beq.s M4PvIsWordDone
        cmpi.b #$0e,d0
        beq.s M4PvIsWordDone
        cmpi.b #$10,d0
        beq.s M4PvIsWordDone
        cmpi.b #$80+$20,d0
        beq.s M4PvIsWordDone
        cmpi.b #$80+$34,d0
M4PvIsWordDone:
        rts
; WORD access to alvar d0 -> a2 (d1 = 1 shape). A byte field read as a WORD
; would take its SNES neighbour: not modelled ($7Exx).
M4PvAlvarW:
        move.w d0,-(sp)
        bsr M4PvAlvar
        move.w (sp)+,d0
        tst.w d1
        bne.s M4PvAlvarWDone
        bsr M4PvIsWordField
        bne M4PvAlvarBad
M4PvAlvarWDone:
        rts
; BYTE access to alvar d0 -> a2 = the byte (low byte of a WORD field, as the
; 8-bit 65816 access at the field address). Shape: $7Exx.
M4PvAlvarB:
        move.w d0,-(sp)
        bsr M4PvAlvar
        move.w (sp)+,d0
        tst.w d1
        bne M4PvAlvarBad
        bsr M4PvIsWordField
        bne.s M4PvAlvarBDone
        addq.l #1,a2
M4PvAlvarBDone:
        rts
; field WORD offsets (negB/negW/div2b/setrandom/indexb): X + w.
M4PvField: ;d0.w = field offset -> a2
        cmpi.w #$0022,d0 ;sbyte1 (indexb index, training 38E7)
        beq M4PvFieldS1
        cmpi.w #$0012,d0 ;rotx/roty/rotz (setrandomB, Titania/Sector Z/Asteroid 3)
        blo.s M4PvFieldNotRot
        cmpi.w #$0014,d0
        bhi.s M4PvFieldNotRot
        lea 12-$12(a0,d0.w),a2
        rts
M4PvFieldNotRot:
        cmpi.w #$1cea,d0 ;alx+$20 coltab
        beq M4PvFieldCol
        cmpi.w #$1cec,d0 ;alx+$22 childx
        beq M4PvFieldCx
        cmpi.w #$1cfc,d0
        beq M4PvFieldP1
        cmpi.w #$1cfd,d0
        beq M4PvFieldP2
        cmpi.w #$1cfe,d0
        beq M4PvFieldW1
        bra M4PvAlvarBad
M4PvFieldP1:
        lea X2_PBYTE1(a0),a2
        rts
M4PvFieldS1:
        lea 36(a0),a2
        rts
M4PvFieldCol:
        lea X_COLTAB(a0),a2
        rts
M4PvFieldCx:
        lea X2_CHILDX(a0),a2
        rts
M4PvFieldP2:
        lea X2_PBYTE2(a0),a2
        rts
M4PvFieldW1:
        lea X2_PWORD1(a0),a2
        rts
; Shape header of a2 -> d0.w. A missing render descriptor is not a logical
; nullshape: retain the original value (including zero and unknown headers).
; carriedlog 04:E7D0 imports zero, then 04:E7D4 tests it before selecting B882.
M4PvShapeHeader:
        move.w 46(a2),d0
        cmpi.w #$ffff,d0
        beq M4PvShapeNull
        lsl.w #5,d0
        move.l a3,-(sp)
        lea M4LevelShapeDescriptors,a3
        move.w 16(a3,d0.w),d0
        move.l (sp)+,a3
        rts
M4PvShapeNull:
        move.w X_SHAPEHDR(a2),d0
        rts
; d0 = header -> SetShape on a2 (unknown headers: not drawn, $FFFF).
M4PvSetShape:
        movem.l d0/a0,-(sp)
        movea.l a2,a0
        move.w d0,X_SHAPEHDR(a0)
        jsr M4LevelShapeIndex
        jsr M4LevelSetShape
        movem.l (sp)+,d0/a0
        rts
; genvecs 04:84BF: zaco objects use gen2d (1F:C177), else gen_3dvecs.
M4PvGenVecs:
        btst #6,X2_FL2(a0)
        bne M4PvGen2d
        jmp M4EnGen3d
M4PvGen2d:
        jmp M4EnGen2d
; Conditional jump: d2 = condition (nonzero = jump), d1 = operand offset of
; the destination, d3 = command length. ifnot inverts and is consumed.
M4PvCondIfnot:
        tst.b M4_PV_IFNOT
        beq M4PvCond
        clr.b M4_PV_IFNOT
        eori.w #1,d2
M4PvCond:
        tst.w d2
        beq M4PvCondNo
        bra M4PvJumpAt
M4PvCondNo:
        add.w d3,42(a0)
        rts

; ---------------------------------------------------------------------
; Flow and time.
M4PvOp_wait: ;847F: sbyte3 counts n ticks
        move.b 1(a4),d0
        cmp.b X_SBYTE3(a0),d0
        bne M4PvWaitMore
        clr.b X_SBYTE3(a0)
        addq.w #2,42(a0)
        rts
M4PvWaitMore:
        addq.b #1,X_SBYTE3(a0)
        moveq #PV_YIELD,d7
        rts
M4PvOp_wait1:
        addq.w #1,42(a0)
        moveq #PV_YIELD,d7
        rts
M4PvOp_loop: ;84F3: sbyte2 counter, body n+1 times
        move.b 1(a4),d0
        cmp.b 37(a0),d0
        bne M4PvLoopMore
        clr.b 37(a0)
        addq.w #4,42(a0)
        rts
M4PvLoopMore:
        addq.b #1,37(a0)
        moveq #2,d1
        bsr M4PvJumpAt
        moveq #PV_YIELD,d7
        rts
M4PvOp_goto:
        moveq #1,d1
        bsr M4PvJumpAt
        moveq #PV_YIELD,d7
        rts
M4PvOp_igoto:
        moveq #1,d1
        bra M4PvJumpAt
M4PvOp_gosub: ;9912: push own address, jump
        move.w 42(a0),d0
        bsr M4PvPush
        moveq #1,d1
        bra M4PvJumpAt
M4PvOp_return: ;9928
        bsr M4PvPull
        cmpi.w #$ffff,d0
        beq M4PvReturnTrigger
        addq.w #3,d0
        move.w d0,42(a0)
        rts
M4PvReturnTrigger:
        moveq #PV_TRET,d7
        rts
M4PvOp_doq: ;99CA: push(PC+2), push(n)
        move.w 42(a0),d0
        addq.w #2,d0
        bsr M4PvPush
        moveq #0,d0
        move.b 1(a4),d0
        bsr M4PvPush
        addq.w #2,42(a0)
        rts
M4PvOp_next: ;9A37
        bsr M4PvPull
        subq.w #1,d0
        bne M4PvNextMore
        bsr M4PvPull
        addq.w #1,42(a0)
        rts
M4PvNextMore:
        move.w d0,d2
        bsr M4PvPull
        move.w d0,42(a0)
        bsr M4PvPush
        move.w d2,d0
        bsr M4PvPush
        moveq #PV_YIELD,d7
        rts
M4PvOp_break: ;9B02
        bsr M4PvPull
        bsr M4PvPull
        moveq #1,d1
        bra M4PvJumpAt
M4PvOp_breakc: ;9B2D: drops the do frame, continues after the command
        bsr M4PvPull
        bsr M4PvPull
        bra M4PvAdd1
M4PvOp_do: ;9A01 [count.w]: push(PC+3), push(count)
        move.w 42(a0),d0
        addq.w #3,d0
        bsr M4PvPush
        moveq #1,d1
        bsr M4PvRdW
        bsr M4PvPush
        addq.w #3,42(a0)
        rts
M4PvOp_inext: ;9AA8: next without yielding (the body restarts this tick)
        bsr M4PvPull
        subq.w #1,d0
        bne.s M4PvInextMore
        bsr M4PvPull
        bra M4PvAdd1
M4PvInextMore:
        move.w d0,d2
        bsr M4PvPull
        move.w d0,42(a0)
        bsr M4PvPush
        move.w d2,d0
        bra M4PvPush
; doalvarb 994D / doalvarw 998D [alvar]: push(PC+2), push(variable).
M4PvOp_doalvarb:
        bsr M4PvDoAlvarPc
        move.b 1(a4),d0
        bsr M4PvAlvarB
        moveq #0,d0
        move.b (a2),d0
        bra.s M4PvDoAlvarPush
M4PvOp_doalvarw:
        bsr M4PvDoAlvarPc
        move.b 1(a4),d0
        bsr M4PvAlvarW
        tst.w d1
        beq.s M4PvDoAlvarWord
        bsr M4PvShapeHeader
        bra.s M4PvDoAlvarPush
M4PvDoAlvarWord:
        move.w (a2),d0
M4PvDoAlvarPush:
        bsr M4PvPush
        addq.w #2,42(a0)
        rts
M4PvDoAlvarPc:
        move.w 42(a0),d0
        addq.w #2,d0
        bra M4PvPush
; gosubalvar 98DF [alvar]: $28 -= 1 and pushed (return lands after this
; 2-byte command), then PC = variable - $A3FE (a bank-04 path address).
M4PvOp_gosubalvar:
        move.b 1(a4),d0
        bsr M4PvAlvarW
        tst.w d1
        bne M4PvBadOp
        move.w (a2),d2
        subq.w #1,42(a0)
        move.w 42(a0),d0
        bsr M4PvPush
        subi.w #$a3fe,d2
        move.w d2,42(a0)
        rts
M4PvOp_randomgoto: ;9325: random_l < $7F -> jump
        jsr M4IntroRandom
        moveq #0,d2
        cmpi.b #$7f,d0
        bhs M4PvRandNo
        moveq #1,d2
M4PvRandNo:
        moveq #1,d1
        moveq #3,d3
        bra M4PvCond
M4PvOp_end: ;931C: zremove, yields without advancing
        bset #3,45(a0)
        moveq #PV_YIELD,d7
        rts
M4PvOp_remove: ;8CC0: children of a mother removed, then itself
        btst #6,X2_FL4(a0)
        beq M4PvRemoveSelf
        move.w 40(a0),d0
M4PvRemoveChild:
        tst.w d0
        beq M4PvRemoveSelf
        movea.w d0,a2
        move.w 40(a2),d0
        exg a0,a2
        jsr M4LevelRemove
        exg a0,a2
        bra M4PvRemoveChild
M4PvRemoveSelf:
        moveq #1,d6
        moveq #PV_END,d7
        rts
M4PvOp_explode: ;8CE7
        moveq #0,d0
        move.b X_SBYTE4(a0),d0
        beq M4PvExplodeKids
        lea M4_PV_FRIENDHP,a2
        clr.b (a2,d0.w)
M4PvExplodeKids:
        btst #6,X2_FL4(a0)
        beq M4PvExplodeSelf
        move.w 40(a0),d0
M4PvExplodeChild:
        tst.w d0
        beq M4PvExplodeSelf
        movea.w d0,a2
        bset #SF_COLLDISABLE,49(a2)
        clr.b 38(a2)
        move.w 40(a2),d0
        bra M4PvExplodeChild
M4PvExplodeSelf:
        bset #SF_COLLDISABLE,49(a0)
        clr.b 38(a0)
        moveq #PV_END2,d7
        rts
M4PvOp_ifnot:
        move.b #1,M4_PV_IFNOT
        addq.w #1,42(a0)
        rts
; start65816 9DB4: the inline routines of Corneria and of path 2078 (Armada), translated.
M4PvOp_start65816:
        jsr M4EndPv65 ;score paths stage1..7 (level_ending.asm): Z = handled
        bne.s M4Pv65NotEnd
        rts
M4Pv65NotEnd:
        move.w 42(a0),d0
        cmpi.w #$0026,d0 ;Fortuna flower: jsl makepollen 06:F9C2 (level_titania.asm)
        bne.s M4Pv65NotPollen
        jmp M4TiPath65Pollen
M4Pv65NotPollen:
        cmpi.w #$0892,d0 ;e_spla_dw: jsl enemydownsea_l 03:B751
        bne.s M4Pv65NotSplaDw
        jmp M4TiPath65Snd1
M4Pv65NotSplaDw:
        cmpi.w #$08a0,d0 ;e_spla_up: jsl enemyupsea_l 03:B735
        bne.s M4Pv65NotSplaUp
        jmp M4TiPath65Snd2
M4Pv65NotSplaUp:
        cmpi.w #$3aee,d0 ;tow_0: expstrat 06:FAA0
        bne M4Pv65NotTow
        move.l #M4Tow0Explode,X_EXP(a0)
        move.w #$3b06,42(a0)
        rts
M4Pv65NotTow:
        cmpi.w #$3b59,d0 ;dsmoke3: colframe 0|$80
        bne M4Pv65NotSmoke3
        move.b #$80,18(a0)
        move.w #$3b67,42(a0)
        rts
M4Pv65NotSmoke3:
        cmpi.w #$3b69,d0 ;dsmoke: colframe cycles 0..14
        bne M4Pv65NotSmoke
        move.b 18(a0),d0
        addq.b #1,d0
        bmi M4Pv65SmokeMask
        addi.b #15,d0
M4Pv65SmokeMask:
        andi.b #$7f,d0
        cmpi.b #15,d0
        blo M4Pv65SmokeStore
        subi.b #15,d0
M4Pv65SmokeStore:
        ori.b #$80,d0
        move.b d0,18(a0)
        move.w #$3b89,42(a0)
        rts
M4Pv65NotSmoke:
        cmpi.w #$4724,d0 ;04:EB22 jsl 06:916D makeengine (path 2078, Armada zaco_7)
        bne.s M4Pv65NotMake
        movem.l d0-d7/a1-a6,-(sp)
        jsr M4WpMakeEngine
        movem.l (sp)+,d0-d7/a1-a6
        move.w #$472f,42(a0)
        rts
M4Pv65NotMake:
        cmpi.w #$4734,d0 ;04:EB32 jsl 06:91DF updateengine
        bne.s M4Pv65NotUpd
        movem.l d0-d7/a1-a6,-(sp)
        jsr M4WpUpdateEngine
        movem.l (sp)+,d0-d7/a1-a6
        move.w #$473f,42(a0)
        rts
M4Pv65NotUpd:
        cmpi.w #$44ba,d0 ;robexplode: sflags3 |= $40 (nopolyexp)
        bne M4PvBadOp
        bset #F2_NOPOLYEXP,48(a0)
        move.w #$44c7,42(a0)
        rts
; tow_0 expstrat 06:FAA0: sword2 = 160, then pillar3explode (06:FAB5).
M4Tow0Explode:
        move.w #160,X_SWORD2(a0)
        jmp M4Pillar3ExplodeBody

; ---------------------------------------------------------------------
; Conditions (N flag of the subtraction unless stated).
M4PvOp_distless: ;902D: |pz - oz| < d
        movea.l a1,a2
M4PvDistCommon:
        jsr M4EnZD
        move.w d0,d2
        moveq #1,d1
        bsr M4PvRdW
        sub.w d0,d2
        smi d2
        andi.w #1,d2
        moveq #3,d1
        moveq #5,d3
        bra M4PvCondIfnot
M4PvOp_shapedistless: ;907A: same with ptr; ptr 0 -> add5 (ifnot kept)
        move.w X_ALPTR(a0),d0
        bne M4PvShapeDist
        addq.w #5,42(a0)
        rts
M4PvShapeDist:
        movea.w d0,a2
        bra M4PvDistCommon
M4PvOp_hitground: ;90A7: h + y >= 0
        moveq #1,d1
        bsr M4PvRdW
        add.w 2(a0),d0
        spl d2
        andi.w #1,d2
        moveq #3,d1
        moveq #5,d3
        bra M4PvCondIfnot
M4PvOp_iflevel: ;9202: l - 1 == route index
        move.b 1(a4),d0
        subq.b #1,d0
        cmpi.b #M4_PV_ROUTE,d0
        seq d2
        andi.w #1,d2
        moveq #2,d1
        moveq #4,d3
        bra M4PvCondIfnot
M4PvOp_leftofplayer: ;922A: N(px - ox) clear
        move.w (a1),d0
        sub.w (a0),d0
        spl d2
        bra M4PvSideCond
M4PvOp_rightofplayer:
        move.w (a1),d0
        sub.w (a0),d0
        smi d2
M4PvSideCond:
        andi.w #1,d2
        moveq #1,d1
        moveq #3,d3
        bra M4PvCond
M4PvOp_behindplayer: ;924C: N(pz - oz) clear
        move.w 4(a1),d0
        sub.w 4(a0),d0
        spl d2
        bra M4PvSideCond
M4PvOp_shapedead: ;91F7: ptr == 0
        tst.w X_ALPTR(a0)
        seq d2
        bra M4PvSideCond
M4PvOp_aboveplayer: ;925B: N(py - oy) clear (16 bits, no ifnot)
        move.w 2(a1),d0
        sub.w 2(a0),d0
        spl d2
        bra M4PvSideCond
M4PvOp_belowplayer: ;926C: N(py - oy) set
        move.w 2(a1),d0
        sub.w 2(a0),d0
        smi d2
        bra M4PvSideCond
M4PvOp_playerdead: ;948C: pshipflags2 $14D9 bit7 or $14D2 bit1
        moveq #1,d2
        btst #7,M4_LP_PSF2
        bne M4PvSideCond
        btst #1,M4_LP_GAMEFLAGS
        sne d2
        bra M4PvSideCond
M4PvOp_hitwall: ;90CE: x - minx >= maxx - minx or y - miny >= maxy - miny
        moveq #1,d2 ;(unsigned 16 bits; $1571/$1573/$1579/$157B)
        move.w M4_LP_MAXX,d0
        sub.w M4_LP_MINX,d0
        move.w (a0),d1
        sub.w M4_LP_MINX,d1
        cmp.w d0,d1
        bhs M4PvSideCond
        move.w M4_LP_MAXY,d0
        sub.w M4_LP_MINY,d0
        move.w 2(a0),d1
        sub.w M4_LP_MINY,d1
        cmp.w d0,d1
        scc d2
        bra M4PvSideCond
M4PvOp_ifhitflag: ;9D85 [target.w][mask]: hitflags & mask -> cleared, jump
        move.b 3(a4),d0
        move.b 20(a0),d1
        and.b d0,d1
        bne.s M4PvHitFlagYes
        addq.w #4,42(a0)
        rts
M4PvHitFlagYes:
        not.b d0
        and.b d0,20(a0)
        moveq #1,d1
        bra M4PvJumpAt
; shapeinrange 9F84 [r.w][target.w]: as withinrange with ptr (09:80A7 is
; inlined: |ptr.z - z| < 200), then 1F:D115 |dx| + |dy| (ptr - object).
M4PvOp_shapeinrange:
        move.w X_ALPTR(a0),d0
        beq M4PvNullRef
        movea.w d0,a2
        jsr M4EnZD
        moveq #0,d2
        subi.w #200,d0
        bpl.s M4PvShapeRangeDone
        move.w (a2),d0
        sub.w (a0),d0
        bpl.s M4PvShapeRangeX
        neg.w d0
M4PvShapeRangeX:
        move.w 2(a2),d3
        sub.w 2(a0),d3
        bpl.s M4PvShapeRangeY
        neg.w d3
M4PvShapeRangeY:
        add.w d3,d0
        bmi.s M4PvShapeRangeDone
        move.w d0,d3
        moveq #1,d1
        bsr M4PvRdW
        sub.w d0,d3
        smi d2
        andi.w #1,d2
M4PvShapeRangeDone:
        moveq #3,d1
        moveq #5,d3
        bra M4PvCond
M4PvOp_ifsameb:
        move.b 1(a4),d0
        bsr M4PvAlvar
        tst.w d1
        bne M4PvSameShapeB
        move.b (a2),d0
        cmp.b 2(a4),d0
        seq d2
        andi.w #1,d2
        moveq #3,d1
        moveq #5,d3
        bra M4PvCondIfnot
M4PvSameShapeB:
        bra M4PvBadOp
M4PvOp_ifsamew:
        move.b 1(a4),d0
        bsr M4PvAlvar
        tst.w d1
        beq M4PvSameWord
        bsr M4PvShapeHeader
        move.w d0,d4
        bra M4PvSameWCmp
M4PvSameWord:
        move.w (a2),d4
M4PvSameWCmp:
        moveq #2,d1
        bsr M4PvRdW
        cmp.w d0,d4
        seq d2
        andi.w #1,d2
        moveq #4,d1
        moveq #6,d3
        bra M4PvCondIfnot
M4PvOp_ifbetweenB: ;93E8: lo < v <= hi (N(lo - v) set, N(hi - v) clear)
        move.b 1(a4),d0
        bsr M4PvAlvar
        move.b (a2),d4
        moveq #0,d2
        move.b 2(a4),d0
        sub.b d4,d0
        bpl M4PvBetweenBNo
        move.b 3(a4),d0
        sub.b d4,d0
        bmi M4PvBetweenBNo
        moveq #1,d2
M4PvBetweenBNo:
        moveq #4,d1
        moveq #6,d3
        bra M4PvCondIfnot
M4PvOp_ifbetweenW:
        move.b 1(a4),d0
        bsr M4PvAlvar
        move.w (a2),d4
        moveq #0,d2
        moveq #2,d1
        bsr M4PvRdW
        sub.w d4,d0
        bpl M4PvBetweenWNo
        moveq #4,d1
        bsr M4PvRdW
        sub.w d4,d0
        bmi M4PvBetweenWNo
        moveq #1,d2
M4PvBetweenWNo:
        moveq #6,d1
        moveq #8,d3
        bra M4PvCondIfnot
M4PvOp_ifzerob: ;9334 (ignores ifnot)
        bsr M4PvZeroB
        seq d2
        bra M4PvZeroCond
M4PvOp_ifnotzerob:
        bsr M4PvZeroB
        sne d2
        bra M4PvZeroCond
M4PvOp_ifnotzerow:
        move.b 1(a4),d0
        bsr M4PvAlvar
        tst.w d1
        beq M4PvNotZeroW
        bsr M4PvShapeHeader
        tst.w d0
        sne d2
        bra M4PvZeroCond
M4PvNotZeroW:
        tst.w (a2)
        sne d2
        bra.s M4PvZeroCond
M4PvOp_ifzerow: ;9349 (ignores ifnot)
        move.b 1(a4),d0
        bsr M4PvAlvarW
        tst.w d1
        beq.s M4PvZeroW
        bsr M4PvShapeHeader
        tst.w d0
        seq d2
        bra.s M4PvZeroCond
M4PvZeroW:
        tst.w (a2)
        seq d2
M4PvZeroCond:
        andi.w #1,d2
        moveq #2,d1
        moveq #4,d3
        bra M4PvCond
M4PvZeroB:
        move.b 1(a4),d0
        bsr M4PvAlvar
        tst.b (a2)
        rts
M4PvOp_notfriend: ;9280: id 6 -> sbyte4 == 0; else sbyte4 != id
        move.b X_SBYTE4(a0),d0
        cmpi.b #6,1(a4)
        bne M4PvNotFriendId
        tst.b d0
        seq d2
        bra M4PvNotFriendCond
M4PvNotFriendId:
        cmp.b 1(a4),d0
        sne d2
M4PvNotFriendCond:
        andi.w #1,d2
        moveq #2,d1
        moveq #4,d3
        bra M4PvCondIfnot
M4PvOp_almostdead: ;92D5: friend and its hp < 11
        moveq #0,d2
        moveq #0,d0
        move.b X_SBYTE4(a0),d0
        beq M4PvAlmostNo
        lea M4_PV_FRIENDHP,a2
        move.b (a2,d0.w),d0
        subi.b #11,d0
        bpl M4PvAlmostNo
        moveq #1,d2
M4PvAlmostNo:
        moveq #1,d1
        moveq #3,d3
        bra M4PvCond
M4PvOp_ifflag: ;9888
        bclr #5,X2_FL4(a0)
        sne d2
        andi.w #1,d2
        moveq #1,d1
        moveq #3,d3
        bra M4PvCond
M4PvOp_childdead: ;9733: jump when child n of the mother is missing
        bsr M4PvMother
        move.l a2,d0
        bne M4PvChildDeadFind
        addq.w #4,42(a0) ;no mother: alive
        rts
M4PvChildDeadFind:
        move.b 1(a4),d0
        bsr M4PvFindChild
        move.l a2,d0
        seq d2
        andi.w #1,d2
        moveq #2,d1
        moveq #4,d3
        bra M4PvCond
; Mother of a0 (itself when mother, else ptr) -> a2 or 0.
M4PvMother:
        movea.l a0,a2
        btst #6,X2_FL4(a0)
        bne M4PvMotherDone
        suba.l a2,a2
        move.w X_ALPTR(a0),d0
        beq M4PvMotherDone
        movea.w d0,a2
M4PvMotherDone:
        rts
; findchild 1F:DC40: child d0.b of mother a2 (sword1 chain) -> a2 or 0.
M4PvFindChild:
        move.w 40(a2),d1
        beq M4PvFindChildNone
        movea.w d1,a2
        cmp.b 36(a2),d0
        bne M4PvFindChild
        rts
M4PvFindChildNone:
        suba.l a2,a2
        rts

; ---------------------------------------------------------------------
; Variables.
M4PvOp_setb: ;[value][alvar]
        move.b 2(a4),d0
        bsr M4PvAlvar
        move.b 1(a4),(a2)
        addq.w #3,42(a0)
        rts
M4PvOp_setw: ;[value.w][alvar]
        move.b 3(a4),d0
        bsr M4PvAlvar
        move.w d1,d2
        moveq #1,d1
        bsr M4PvRdW
        tst.w d2
        bne M4PvSetwShape
        move.w d0,(a2)
        addq.w #4,42(a0)
        rts
M4PvSetwShape:
        bsr M4PvSetShape
        addq.w #4,42(a0)
        rts
M4PvOp_set0b:
        move.b 1(a4),d0
        bsr M4PvAlvar
        clr.b (a2)
        addq.w #2,42(a0)
        rts
M4PvOp_set0w:
        move.b 1(a4),d0
        bsr M4PvAlvar
        clr.w (a2)
        addq.w #2,42(a0)
        rts
M4PvOp_addb: ;[alvar][value]
        move.b 1(a4),d0
        bsr M4PvAlvar
        move.b 2(a4),d0
        add.b d0,(a2)
        addq.w #3,42(a0)
        rts
M4PvOp_addw: ;[alvar][value.w]
        move.b 1(a4),d0
        bsr M4PvAlvar
        moveq #2,d1
        bsr M4PvRdW
        add.w d0,(a2)
        addq.w #4,42(a0)
        rts
M4PvOp_incb:
        move.b 1(a4),d0
        bsr M4PvAlvar
        addq.b #1,(a2)
        addq.w #2,42(a0)
        rts
M4PvOp_decb:
        move.b 1(a4),d0
        bsr M4PvAlvar
        subq.b #1,(a2)
        addq.w #2,42(a0)
        rts
M4PvOp_decw: ;8610: alvar.w -= 1
        move.b 1(a4),d0
        bsr M4PvAlvarW
        tst.w d1
        bne M4PvBadOp
        subq.w #1,(a2)
        addq.w #2,42(a0)
        rts
M4PvOp_addws: ;8592 [alvar][value]: alvar.w += sext(value)
        move.b 1(a4),d0
        bsr M4PvAlvarW
        tst.w d1
        bne M4PvBadOp
        move.b 2(a4),d0
        ext.w d0
        add.w d0,(a2)
        addq.w #3,42(a0)
        rts
; [dst][src] alvars (8AB0) -> a3 src (d4 = 1 shape), a2 dst (d1 = 1 shape),
; d5 = src alvar byte; d0 = dst alvar byte.
M4PvSrcDst2:
        move.b 2(a4),d0
        move.b d0,d5
        bsr M4PvAlvar
        movea.l a2,a3
        move.w d1,d4
        move.b 1(a4),d0
        move.w d0,-(sp)
        bsr M4PvAlvar
        move.w (sp)+,d0
        rts
M4PvOp_setvWW: ;8A6F: dst.w = src.w
        bsr M4PvSrcDst2
        tst.w d1
        bne.s M4PvSetvWWSrc
        bsr M4PvIsWordField
        bne M4PvBadAlvarOp
M4PvSetvWWSrc:
        move.b d5,d0
        tst.w d4
        bne.s M4PvSetvWWShape
        bsr M4PvIsWordField
        bne M4PvBadAlvarOp
        move.w (a3),d0
        bra.s M4PvSetvWStore
M4PvSetvWWShape:
        move.l a2,-(sp)
        movea.l a0,a2
        bsr M4PvShapeHeader
        movea.l (sp)+,a2
M4PvSetvWStore: ;d0 -> dst (d1 = 1: shape)
        tst.w d1
        bne.s M4PvSetvWSetShape
        move.w d0,(a2)
        addq.w #3,42(a0)
        rts
M4PvSetvWSetShape:
        bsr M4PvSetShape
        addq.w #3,42(a0)
        rts
M4PvOp_setvWB: ;8A91: dst.w = sext(src.b)
        bsr M4PvSrcDst2
        tst.w d1
        bne.s M4PvSetvWBSrc
        bsr M4PvIsWordField
        bne M4PvBadAlvarOp
M4PvSetvWBSrc:
        move.b d5,d0
        tst.w d4
        bne M4PvBadAlvarOp
        bsr M4PvIsWordField
        bne.s M4PvSetvWBByte
        addq.l #1,a3
M4PvSetvWBByte:
        move.b (a3),d0
        ext.w d0
        bra.s M4PvSetvWStore
M4PvOp_addvBW: ;8A2A: dst.b += low byte of src.w (8-bit add)
        bsr M4PvSrcDst2
        tst.w d1
        bne M4PvBadAlvarOp
        bsr M4PvIsWordField
        bne.s M4PvAddvBWDst
        addq.l #1,a2
M4PvAddvBWDst:
        move.b d5,d0
        tst.w d4
        bne M4PvBadAlvarOp
        bsr M4PvIsWordField
        bne.s M4PvAddvBWSrc
        addq.l #1,a3
M4PvAddvBWSrc:
        move.b (a3),d0
        add.b d0,(a2)
        addq.w #3,42(a0)
        rts
M4PvOp_addrotx:
        move.b 1(a4),d0
        add.b d0,12(a0)
        addq.w #2,42(a0)
        rts
M4PvOp_addroty:
        move.b 1(a4),d0
        add.b d0,13(a0)
        addq.w #2,42(a0)
        rts
M4PvOp_addrotz:
        move.b 1(a4),d0
        add.b d0,14(a0)
        addq.w #2,42(a0)
        rts
M4PvOp_addworldx:
        move.b 1(a4),d0
        ext.w d0
        add.w d0,(a0)
        addq.w #2,42(a0)
        rts
M4PvOp_addworldy:
        move.b 1(a4),d0
        ext.w d0
        add.w d0,2(a0)
        addq.w #2,42(a0)
        rts
M4PvOp_addworldz:
        move.b 1(a4),d0
        ext.w d0
        add.w d0,4(a0)
        addq.w #2,42(a0)
        rts
; [dst][src] alvars.
M4PvSrcDst:
        move.b 2(a4),d0
        bsr M4PvAlvar
        movea.l a2,a3
        move.b 1(a4),d0
        bra M4PvAlvar
M4PvOp_setvBB:
        bsr M4PvSrcDst
        move.b (a3),(a2)
        addq.w #3,42(a0)
        rts
M4PvOp_addvBB:
        bsr M4PvSrcDst
        move.b (a3),d0
        add.b d0,(a2)
        addq.w #3,42(a0)
        rts
M4PvOp_addvWW:
        bsr M4PvSrcDst
        move.w (a3),d0
        add.w d0,(a2)
        addq.w #3,42(a0)
        rts
M4PvOp_addvWB:
        bsr M4PvSrcDst
        move.b (a3),d0
        ext.w d0
        add.w d0,(a2)
        addq.w #3,42(a0)
        rts
M4PvOp_negB:
        moveq #1,d1
        bsr M4PvRdW
        bsr M4PvField
        neg.b (a2)
        addq.w #3,42(a0)
        rts
M4PvOp_negW:
        moveq #1,d1
        bsr M4PvRdW
        bsr M4PvField
        neg.w (a2)
        addq.w #3,42(a0)
        rts
M4PvOp_div2b: ;9E3A: ASR rounding toward zero
        moveq #1,d1
        bsr M4PvRdW
        bsr M4PvField
        move.b (a2),d0
        bpl M4PvDiv2Pos
        addq.b #1,d0
M4PvDiv2Pos:
        asr.b #1,d0
        move.b d0,(a2)
        addq.w #3,42(a0)
        rts
M4PvOp_setrandomB: ;9D3A
        moveq #1,d1
        bsr M4PvRdW
        bsr M4PvField
        jsr M4IntroRandom
        and.b 3(a4),d0
        move.b d0,(a2)
        addq.w #4,42(a0)
        rts
M4PvOp_setrandomW: ;9D5C: high byte from the first call, low from the second
        moveq #1,d1
        bsr M4PvRdW
        bsr M4PvField
        jsr M4IntroRandom
        move.b d0,d2
        lsl.w #8,d2
        jsr M4IntroRandom
        move.b d0,d2
        moveq #3,d1
        bsr M4PvRdW
        and.w d0,d2
        move.w d2,(a2)
        addq.w #5,42(a0)
        rts
M4PvOp_indexb: ;9E75: [X+dst] = table[[X+idx]] (00:98A5 sine, 04:DD02 xpos)
        lea M4IntroShipSine,a3
        cmpi.b #$a5,1(a4)
        bne.s M4PvIndexXpos
        cmpi.b #$98,2(a4)
        beq.s M4PvIndexTable
M4PvIndexXpos:
        cmpi.b #$02,1(a4) ;04:DD02 display_pword1 digit x (-25, 0, +25)
        bne M4PvBadOp
        cmpi.b #$dd,2(a4)
        bne M4PvBadOp
        cmpi.b #$04,3(a4)
        bne M4PvBadOp
        lea M4PathBytes+$dd02-$a3fe,a3
M4PvIndexTable:
        moveq #4,d1
        bsr M4PvRdW
        bsr M4PvField
        moveq #0,d2
        move.b (a2),d2
        moveq #6,d1
        bsr M4PvRdW
        bsr M4PvField
        move.b (a3,d2.w),(a2)
        addq.w #8,42(a0)
        rts
; WORD field offset d0.w (div2w/indexw) -> a2; only the WORD fields of
; M4PvField (alx+$20 coltab, alx+$34 pword1), else not modelled.
M4PvFieldW:
        cmpi.w #$1cea,d0
        beq M4PvFieldCol
        cmpi.w #$1cfe,d0
        beq M4PvFieldW1
        bra M4PvAlvarBad
; BYTE read at field offset d0.w -> a2 (low byte of the WORD fields).
M4PvFieldB:
        bsr M4PvField
        cmpi.w #$1cea,d0
        beq.s M4PvFieldBLow
        cmpi.w #$1cfe,d0
        bne.s M4PvFieldBDone
M4PvFieldBLow:
        addq.l #1,a2
M4PvFieldBDone:
        rts
; div2w 9E58: negative words -> trunc0(v/2); the bpl for v >= 0 enters the
; 8-bit code of div2b with M = 16 (cmp #$6A80, sta): v is stored unchanged.
M4PvOp_div2w:
        moveq #1,d1
        bsr M4PvRdW
        bsr M4PvFieldW
        move.w (a2),d0
        bpl.s M4PvDiv2wDone
        addq.w #1,d0
        asr.w #1,d0
        move.w d0,(a2)
M4PvDiv2wDone:
        addq.w #3,42(a0)
        rts
; indexw 9E8A [table.l][index field.w][dst field.w]: dst.w = table.w[idx]
; (idx = byte at the index field). Port: tables of the path area 04:A3FE...
M4PvOp_indexw:
        cmpi.b #$04,3(a4)
        bne M4PvBadOp
        moveq #1,d1
        bsr M4PvRdW
        subi.w #$a3fe,d0
        bcs M4PvBadOp
        lea M4PathBytes,a3
        adda.w d0,a3
        moveq #4,d1
        bsr M4PvRdW
        bsr M4PvFieldB
        moveq #0,d2
        move.b (a2),d2
        add.w d2,d2
        moveq #6,d1
        bsr M4PvRdW
        bsr M4PvFieldW
        move.b 1(a3,d2.w),d0
        lsl.w #8,d0
        move.b (a3,d2.w),d0
        move.w d0,(a2)
        addq.w #8,42(a0)
        rts
M4PvOp_importw: ;8AD5: alvar = global word [var.w]
        move.b 1(a4),d0
        bsr M4PvAlvar
        bsr M4PvGlobalOp
        beq M4PvBadOp
        move.b 1(a3),d0
        lsl.w #8,d0
        move.b (a3),d0
        tst.w d1
        beq M4PvImportWord
        bsr M4PvSetShape
        bra M4PvImportDone
M4PvImportWord:
        move.w d0,(a2)
M4PvImportDone:
        addq.w #4,42(a0)
        rts
M4PvOp_exportw: ;8AF1: global word = alvar
        move.b 1(a4),d0
        bsr M4PvAlvar
        tst.w d1
        beq M4PvExportWord
        bsr M4PvShapeHeader
        bra M4PvExportStore
M4PvExportWord:
        move.w (a2),d0
M4PvExportStore:
        move.w d0,-(sp)
        bsr M4PvGlobalOp
        move.w (sp)+,d0
        move.l a3,d2
        beq M4PvBadOp
        move.b d0,(a3)
        lsr.w #8,d0
        move.b d0,1(a3)
        addq.w #4,42(a0)
        rts
M4PvOp_importb: ;8AB8: alvar.b = global byte [var.w]
        move.b 1(a4),d0
        bsr M4PvAlvar
        bsr M4PvGlobalOp
        beq M4PvBadOp
        move.b (a3),(a2)
        addq.w #4,42(a0)
        rts
M4PvOp_exportb: ;8AE4: global byte = alvar.b
        move.b 1(a4),d0
        bsr M4PvAlvar
        bsr M4PvGlobalOp
        beq M4PvBadOp
        move.b (a2),(a3)
        addq.w #4,42(a0)
        rts
; Operand var.w at 2(a4) -> a3 = port byte (0 and Z set when unmapped).
M4PvGlobalOp:
        moveq #0,d0
        move.b 3(a4),d0
        lsl.w #8,d0
        move.b 2(a4),d0
; d0.w = 7E address -> a3 (0, Z set: not mapped). Keeps d1/a2.
M4PvGlobalPtr:
        cmpi.w #$1f11,d0 ;c_type: end_game_seq signal of the score paths (04:49F3)
        bne.s M4PvGlobalNotCType
        lea M4_CTL_TYPE,a3
        move.l a3,d0
        rts
M4PvGlobalNotCType:
        cmpi.w #$1503,d0 ;player_rollZvel (importb in the formation paths)
        bne.s M4PvGlobalTable
        lea M4_LP_ROLLZVEL,a3
        move.l a3,d0
        rts
M4PvGlobalTable:
        subi.w #M4_PV_GLOBBASE,d0
        cmpi.w #M4_PV_GLOBSIZE,d0
        bhs.s M4PvGlobalNone
        lea M4_PV_GLOB,a3
        adda.w d0,a3
        move.l a3,d0
        rts
M4PvGlobalNone:
        suba.l a3,a3
        move.l a3,d0
        rts
M4PvOp_incw: ;9B: alvar.w += 1
        move.b 1(a4),d0
        cmpi.b #$95,d0 ;alx+$15 depthoffset (low byte of the SNES WORD; fadeintotal 04:4815)
        bne.s M4PvIncwWord
        addq.b #1,X_DEPTHOFF(a0) ;carry into alx+$16 not modelled (values 5..8)
        addq.w #2,42(a0)
        rts
M4PvIncwWord:
        bsr M4PvAlvar
        addq.w #1,(a2)
        addq.w #2,42(a0)
        rts
M4PvOp_setvBW: ;62: dst.b = low byte of src.w
        move.b 2(a4),d0
        bsr M4PvAlvar
        move.w (a2),d2
        move.b 1(a4),d0
        bsr M4PvAlvar
        move.b d2,(a2)
        addq.w #3,42(a0)
        rts
; mpush/mpull on the object heap (shared LIFO with gosub/do): bytes are
; pushed as WORDs.
M4PvOp_pushb: ;82
        move.b 1(a4),d0
        bsr M4PvAlvar
        moveq #0,d0
        move.b (a2),d0
        bsr M4PvPush
        addq.w #2,42(a0)
        rts
M4PvOp_pushw: ;83
        move.b 1(a4),d0
        bsr M4PvAlvar
        move.w (a2),d0
        bsr M4PvPush
        addq.w #2,42(a0)
        rts
M4PvOp_pullb: ;84
        bsr M4PvPull
        move.w d0,d2
        move.b 1(a4),d0
        bsr M4PvAlvar
        move.b d2,(a2)
        addq.w #2,42(a0)
        rts
M4PvOp_pullw: ;85
        bsr M4PvPull
        move.w d0,d2
        move.b 1(a4),d0
        bsr M4PvAlvar
        move.w d2,(a2)
        addq.w #2,42(a0)
        rts
; withinrange 04:9F4F [r.w][target.w]: 09:80A7 (|pz - z| < 200, bit N),
; then 1F:D115 $1591 = |dx| + |dy| (16 bits, player - object): true when
; N($1591) clear and N($1591 - r) set. No ifnot: 9F4F..9F81 and its exits
; 8396/840D neither read nor clear $F0AF (agent-paths oracle).
M4PvOp_withinrange:
        movea.l a1,a2
        jsr M4EnZD
        moveq #0,d2
        subi.w #200,d0
        bpl.s M4PvRangeDone
        move.w (a1),d0
        sub.w (a0),d0
        bpl.s M4PvRangeX
        neg.w d0
M4PvRangeX:
        move.w 2(a1),d3
        sub.w 2(a0),d3
        bpl.s M4PvRangeY
        neg.w d3
M4PvRangeY:
        add.w d3,d0
        bmi.s M4PvRangeDone
        move.w d0,d3
        moveq #1,d1
        bsr M4PvRdW
        sub.w d0,d3
        smi d2
        andi.w #1,d2
M4PvRangeDone:
        moveq #3,d1
        moveq #5,d3
        bra M4PvCond
; become 92 / unbecome 91 ($F0C6..$F0CA): the next commands act on the last
; spawned object; the path pointer travels in that object's pointer field.
M4PvOp_become: ;A061: on $F0CA
        move.l M4_PV_LASTOBJ,d0
        beq M4PvBadOp
        movea.l d0,a2
        moveq #1,d3
        bra.s M4PvBecomeTo
; becomemother 9FC9 / becomeshape 9FEA (same code): on ptr; becomechild A00B
; [child]: on child n of the mother (itself, or ptr). No null check in the ROM.
M4PvOp_becomemother:
M4PvOp_becomeshape:
        move.w X_ALPTR(a0),d0
        beq M4PvNullRef
        movea.w d0,a2
        moveq #1,d3
        bra.s M4PvBecomeTo
M4PvOp_becomechild:
        bsr M4PvMother
        move.l a2,d0
        beq M4PvNullRef
        move.b 1(a4),d0
        bsr M4PvFindChild
        move.l a2,d0
        beq M4PvNullRef
        moveq #2,d3
; a2 = object the next commands act on, d3 = command length ($F0C6/$F0C8).
M4PvBecomeTo:
        tst.l M4_PV_BECOME
        bne M4PvBadOp ;nested (not modelled)
        move.l a0,M4_PV_BECOME
        move.w 42(a2),M4_PV_BECOMEPC
        move.w 42(a0),d0
        add.w d3,d0
        move.w d0,42(a2)
        movea.l a2,a0
        rts
M4PvOp_unbecome:
        move.l M4_PV_BECOME,d0
        beq M4PvBadOp
        movea.l d0,a2
        move.w 42(a0),d0
        addq.w #1,d0
        move.w d0,42(a2)
        move.w M4_PV_BECOMEPC,42(a0)
        clr.l M4_PV_BECOME
        movea.l a2,a0
        rts
; text 04:989B [string.w][colour][size]: textobj (sflags $1D |= $40), no
; collision ($1E |= 1), colour in alx+$15 ($1CDF), string in alx+$20, size
; in alx+$2A ($1CF4). Drawn as GSU scaled text (bank $14 strings).
M4PvOp_text:
        bset #0,X_TEXTFL(a0)
        bset #SF_COLLDISABLE,49(a0)
        move.b 3(a4),X_DEPTHOFF(a0)
        moveq #1,d1
        bsr M4PvRdW
        move.w d0,X_COLTAB(a0)
        move.b 4(a4),X_TX(a0)
        addq.w #5,42(a0)
        rts

; ---------------------------------------------------------------------
; Movement, orientation, appearance.
M4PvOp_setvel: ;84AA
        move.b 1(a4),15(a0)
        btst #5,X2_FL2(a0)
        bne M4PvSetvelDone
        bsr M4PvGenVecs
M4PvSetvelDone:
        addq.w #2,42(a0)
        rts
M4PvOp_accel: ;909A: count = target, count1 = step (applied by .move)
        move.b 1(a4),19(a0)
        move.b 2(a4),X_COUNT1(a0)
        addq.w #3,42(a0)
        rts
M4PvOp_reltoplayeron:
        bset #4,X2_FL2(a0)
        bra M4PvAdd1
M4PvOp_reltoplayeroff:
        bclr #4,X2_FL2(a0)
        bra M4PvAdd1
M4PvOp_alwaysgenvecson:
        bset #5,X2_FL2(a0)
        bra M4PvAdd1
M4PvOp_alwaysgenvecsoff:
        bclr #5,X2_FL2(a0)
        bra M4PvAdd1
M4PvOp_spaceshipon:
        bset #7,X2_FL2(a0)
        bra M4PvAdd1
M4PvOp_spaceshipoff:
        bclr #7,X2_FL2(a0)
        bra M4PvAdd1
M4PvOp_smokeon:
        bset #1,X2_FL3(a0)
        bra M4PvAdd1
M4PvOp_smokeoff:
        bclr #1,X2_FL3(a0)
        bra M4PvAdd1
M4PvOp_shadowon:
        bset #F2_SHADOW,48(a0)
        bra M4PvAdd1
M4PvOp_shadowoff:
        bclr #F2_SHADOW,48(a0)
        bra M4PvAdd1
M4PvOp_invisibleon: ;9B58: sflags4 invisible (not drawn, no zremove/flags), colldisable
        bset #3,X2_FL4(a0)
        bset #1,49(a0)
        bset #SF_COLLDISABLE,49(a0)
        bra M4PvAdd1
M4PvOp_invisibleoff: ;9B67: sflags4 &= ~$08, sflags2 &= ~$01 (collisions on)
        bclr #3,X2_FL4(a0)
        bclr #1,49(a0)
        bclr #SF_COLLDISABLE,49(a0)
        bra M4PvAdd1
M4PvOp_zacoon: ;8449: sflags2 $40 (.move: vel = rotx, gen2d 1F:C177)
        bset #6,X2_FL2(a0)
        bra M4PvAdd1
M4PvOp_zacooff: ;8452
        bclr #6,X2_FL2(a0)
        bra M4PvAdd1
M4PvOp_invincibleoff: ;9483: sflags3 &= ~$20 (nohitaffect)
        bclr #SF_NOHITAFFECT,49(a0)
        bra M4PvAdd1
M4PvOp_immune: ;901B: Y = ptr; if Y: Y.immuneptr = X, X.immuneptr = Y
        move.w X_ALPTR(a0),d0
        beq M4PvAdd1
        movea.w d0,a2
        move.w a0,28(a2)
        move.w d0,28(a0)
        bra M4PvAdd1
M4PvOp_trail: ;98D6 [colour]: alx+$2B (the copies are made by .move 04:A247)
        move.b 1(a4),X_TY(a0)
        addq.w #2,42(a0)
        rts
; debris 913E [shape.w]: alx+$1A debrisshape, read by explode_Istrat at
; 06:F4A8 (06:F1DA: particle helper 06:F7E6 + 2 pieces 06:F360; port
; M4AstDebris, level_asteroid.asm).
M4PvOp_debris:
        moveq #1,d1
        bsr M4PvRdW
        move.w d0,X_DEBRIS(a0)
        addq.w #3,42(a0)
        rts
M4PvOp_debug: ;971D: jml 1F:BDEE (debug blink/restart)
        move.w #$7d43,d0
        bra M4PvFatal
M4PvOp_collisionson:
        bclr #SF_COLLDISABLE,49(a0)
        bra M4PvAdd1
M4PvOp_collisionsoff:
        bset #SF_COLLDISABLE,49(a0)
        bra M4PvAdd1
M4PvOp_invincibleon:
        bset #SF_NOHITAFFECT,49(a0)
        bra M4PvAdd1
M4PvOp_zremoveon:
        bset #3,45(a0)
        bra M4PvAdd1
M4PvOp_zremoveoff:
        bclr #3,45(a0)
M4PvAdd1:
        addq.w #1,42(a0)
        rts
M4PvOp_initanim: ;9101
        move.b 1(a4),d0
        ori.b #$80,d0
        move.b d0,16(a0)
        addq.w #2,42(a0)
        rts
M4PvOp_addanim: ;9112
        move.b 16(a0),d0
        add.b 1(a4),d0
        bmi M4PvAnimMask
        add.b 2(a4),d0
M4PvAnimMask:
        andi.b #$7f,d0
        cmp.b 2(a4),d0
        blo M4PvAnimStore
        sub.b 2(a4),d0
M4PvAnimStore:
        ori.b #$80,d0
        move.b d0,16(a0)
        addq.w #3,42(a0)
        rts
M4PvOp_sprite: ;9CC5 [colour][size]: sflags $20 (ssprite), alx+$15, alx+$2A
        bset #F2_SPRITE,48(a0)
        move.b 1(a4),X_DEPTHOFF(a0)
        move.b 2(a4),X_TX(a0)
        addq.w #3,42(a0)
        rts
M4PvOp_sound: ;04:9E20 jsl 03:B7E5 / 04:9E2A
        move.b 1(a4),d0
        jsr M4Sfx
        addq.w #2,42(a0)
        rts
M4PvOp_sound2: ;continuous object sound2 parameter; not a port3 SFX ID
        move.b 1(a4),d0
        jsr M4SoundObjectSet
        addq.w #2,42(a0)
        rts
M4PvOp_msg: ;04:92B8 send_message_l (level_radio.asm)
        move.b 1(a4),d0
        jsr M4RadioSend
        addq.w #2,42(a0)
        rts
M4PvOp_msgwithmeter: ;04:92C4: meter request, then as msg
        st M4_PV_METER
        move.b 1(a4),d0
        jsr M4RadioSend
        addq.w #2,42(a0)
        rts
; achase step (04:8842): 1/8 of the difference, min +/-1.
M4PvOp_achaseB: ;[value][alvar]
        move.b 2(a4),d0
        bsr M4PvAlvar
        move.b (a2),d0
        move.b 1(a4),d1
        moveq #3,d2
        jsr M4EnChase8
        move.b d0,(a2)
        addq.w #3,42(a0)
        rts
M4PvOp_waitachaseB: ;890D: advances only when already equal on entry
        move.b 2(a4),d0
        bsr M4PvAlvar
        move.b (a2),d0
        move.b 1(a4),d1
        cmp.b d0,d1
        bne M4PvWaitChaseStep
        addq.w #3,42(a0)
        rts
M4PvWaitChaseStep:
        moveq #3,d2
        jsr M4EnChase8
        move.b d0,(a2)
        moveq #PV_YIELD,d7
        rts
M4PvOp_achaseW: ;889A: [value.w][alvar]
        move.b 3(a4),d0
        bsr M4PvAlvar
        moveq #1,d1
        bsr M4PvRdW
        move.w d0,d1
        move.w (a2),d0
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,(a2)
        addq.w #4,42(a0)
        rts
M4PvOp_waitachaseW: ;8978 [value.w][alvar]: advances only when equal on entry
        move.b 3(a4),d0
        bsr M4PvAlvarW
        tst.w d1
        bne M4PvBadOp
        moveq #1,d1
        bsr M4PvRdW
        move.w d0,d1
        move.w (a2),d0
        cmp.w d0,d1
        bne.s M4PvWaitChaseWStep
        addq.w #4,42(a0)
        rts
M4PvWaitChaseWStep:
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,(a2)
        moveq #PV_YIELD,d7
        rts
; faceplayer 86C8: pitch/yaw one step (min 4, /4); waitfaceplayer 8627 and
; faceshape 8BF7: min 8, /8, advance only when both were already equal.
M4PvOp_faceplayer:
        movea.l a1,a2
        moveq #2,d2
        bsr M4PvFace
        addq.w #1,42(a0)
        rts
M4PvOp_waitfaceplayer:
        movea.l a1,a2
M4PvWaitFace:
        moveq #3,d2
        bsr M4PvFace
        cmpi.w #2,d4
        bne M4PvWaitFaceYield
        addq.w #1,42(a0)
        rts
M4PvWaitFaceYield:
        moveq #PV_YIELD,d7
        rts
M4PvOp_faceshape:
        move.w X_ALPTR(a0),d0
        bne M4PvFaceShape
        addq.w #1,42(a0)
        rts
M4PvFaceShape:
        movea.w d0,a2
        bra M4PvWaitFace
; a2 target, d2 = n -> d4 = number of angles already equal (0..2).
M4PvFace:
        moveq #0,d4
        jsr M4EnPitchTo
        move.b d0,d1
        move.b 12(a0),d0
        jsr M4EnChase8
        move.b d0,12(a0)
        add.w d3,d4
        jsr M4EnYawTo
        move.b d0,d1
        move.b 13(a0),d0
        jsr M4EnChase8
        move.b d0,13(a0)
        add.w d3,d4
        rts
; gotopos 8D2E: way point (x, y, z) around the player (x, z rotated by the
; reference's yaw, 1F:CDF0); flies to it with its own steering (min 4, /4) and
; leaves through 04:A22A; within 300 (CF92 and |dy|) it brakes and advances
; once stopped.
; 02:FC62: d0.w word x d4.w (sign-extended byte b) -> d0.w = trunc(w*2b/256)
; (sign and magnitude with the hardware multiplier; b = -128 gives 0: the
; 8-bit asl of 128). Matches the ROM routine on 6072 cases (agent-paths).
M4PvFc62:
        cmpi.w #-128,d4
        beq.s M4PvFc62Zero
        muls.w d4,d0
        bpl.s M4PvFc62Pos
        addi.l #127,d0
M4PvFc62Pos:
        asr.l #7,d0
        rts
M4PvFc62Zero:
        moveq #0,d0
        rts
; gotoshapepos 8EA2: the same around ptr (no ptr: add8) with approach step 1
; instead of 20 (8F6E lda #$01).
M4PvOp_gotoshapepos:
        move.w X_ALPTR(a0),d0
        bne.s M4PvGotoShape
        addq.w #8,42(a0)
        rts
M4PvGotoShape:
        movea.w d0,a2
        bra.s M4PvGoto
M4PvOp_gotopos:
        movea.l a1,a2 ;reference object: the player
M4PvGoto:
        moveq #1,d1
        bsr M4PvRdW
        move.w d0,d3 ;x
        moveq #5,d1
        bsr M4PvRdW
        move.w d0,d5 ;z
        lea M4IntroShipSine,a3
        moveq #0,d0
        move.b 13(a2),d0
        move.b (a3,d0.w),d1 ;s
        ext.w d1
        move.b 64(a3,d0.w),d2 ;c
        ext.w d2
        ; 1F:CDF0: four 02:FC62 products (M4PvFc62)
        move.w d3,d0
        move.w d1,d4
        bsr M4PvFc62
        move.w d0,-(sp) ;x*s
        move.w d5,d0
        move.w d2,d4
        bsr M4PvFc62
        add.w (sp)+,d0 ;z' = x*s + z*c
        add.w 4(a2),d0
        move.w d0,X_WPZ(a0)
        move.w d5,d0
        move.w d1,d4
        bsr M4PvFc62
        move.w d0,-(sp) ;z*s
        move.w d3,d0
        move.w d2,d4
        bsr M4PvFc62
        sub.w (sp)+,d0 ;x' = x*c - z*s
        add.w (a2),d0
        move.w d0,X_WPX(a0)
        moveq #3,d1
        bsr M4PvRdW
        add.w 2(a2),d0
        move.w d0,X_WPY(a0)
        btst #4,X2_FL2(a0)
        beq M4PvGotoNoRel
        jsr M4EnAddPZ
M4PvGotoNoRel:
        jsr M4EnMove
        move.w X_WPX(a0),d0
        sub.w (a0),d0
        bpl M4PvGotoAx
        neg.w d0
M4PvGotoAx:
        move.w X_WPZ(a0),d1
        sub.w 4(a0),d1
        bpl M4PvGotoAz
        neg.w d1
M4PvGotoAz:
        add.w d1,d0
        subi.w #300,d0
        bpl M4PvGotoFar
        move.w 2(a0),d0
        sub.w X_WPY(a0),d0
        bpl M4PvGotoAy
        neg.w d0
M4PvGotoAy:
        cmpi.w #300,d0
        bhs M4PvGotoFar
        moveq #0,d0
        moveq #2,d1
        move.b 15(a0),d4
        jsr M4EnSpeedTo
        tst.b d4
        bne M4PvGotoSteer
        addq.w #8,42(a0) ;stopped: arrived
        rts
M4PvGotoFar:
        move.b 7(a4),d0
        moveq #20,d1
        cmpi.b #$17,(a4)
        bne.s M4PvGotoStep
        moveq #1,d1 ;gotoshapepos
M4PvGotoStep:
        jsr M4EnSpeedTo
M4PvGotoSteer:
        jsr M4EnWayAngles
        move.b d1,d5
        move.b d0,d1
        move.b 13(a0),d0
        moveq #2,d2
        jsr M4EnChase8
        move.b d0,13(a0)
        move.b d5,d1
        move.b 12(a0),d0
        jsr M4EnChase8
        move.b d0,12(a0)
        jsr M4EnGen3d
        moveq #PV_GOTO,d7
        rts

; ---------------------------------------------------------------------
; Objects, weapons, links.
M4PvOp_weapon:
        move.b 1(a4),X2_WEAPON(a0)
        addq.w #2,42(a0)
        rts
; fire 87BB / firecanhit 87C9: zero offsets, weapon +$2C; fire adds
; collflags enemy1 to the weapon. Weapon ids: 6 FriendElaser, 10/12
; RelSlowElaser(Home), 38 Hplasma, 56 relbeamball.
M4PvOp_fire:
        moveq #1,d4
        bra.s M4PvFire
M4PvOp_firecanhit:
        moveq #0,d4
M4PvFire:
        bsr M4PvFireSub
        bra M4PvAdd1
; fireatplayer 87CF / fireatplayercanhit 87DD (87E3): the weapon's ptr = the
; player; fireatshape 87EE / fireatshapecanhit 87FC (8802): = own ptr. The
; ROM writes the dummy $156D when the fire fails; the port skips it.
M4PvOp_fireatplayer:
        moveq #1,d4
        bra.s M4PvFireAtPl
M4PvOp_fireatplayercanhit:
        moveq #0,d4
M4PvFireAtPl:
        bsr M4PvFireSub
        beq M4PvAdd1
        move.w a1,X_ALPTR(a2)
        bra M4PvAdd1
M4PvOp_fireatshape:
        moveq #1,d4
        bra.s M4PvFireAtSh
M4PvOp_fireatshapecanhit:
        moveq #0,d4
M4PvFireAtSh:
        bsr M4PvFireSub
        beq M4PvAdd1
        move.w X_ALPTR(a0),X_ALPTR(a2)
        bra M4PvAdd1
; 8811: fire_weapon 1F:D146 with zero offsets and the weapon +$2C, $F0CA =
; weapon; d4 = 1 adds collflags enemy1 (87BB) -> a2 weapon (Z set: none).
M4PvFireSub:
        lea M4PvWeaponTypes,a2
        move.b X2_WEAPON(a0),d0
M4PvFireFind:
        move.b (a2)+,d1
        bmi.s M4PvFireUnknown
        move.b (a2)+,d2
        cmp.b d1,d0
        bne M4PvFireFind
        moveq #0,d0
        move.b d2,d0
        moveq #0,d3
        moveq #0,d5
        move.l d4,-(sp)
        moveq #0,d4
        move.l d6,-(sp)
        move.l d7,-(sp)
        moveq #0,d6
        moveq #0,d7
        suba.l a3,a3
        jsr M4EnFire
        move.l (sp)+,d7
        move.l (sp)+,d6
        move.l (sp)+,d4
        move.l a2,M4_PV_LASTOBJ
        move.l a2,d0
        beq.s M4PvFireDone
        tst.w d4
        beq.s M4PvFireDone
        ori.b #CF_ENEMY1,44(a2)
M4PvFireDone:
        move.l a2,d0
        rts
M4PvFireUnknown:
        bsr M4PvBadOp
        suba.l a2,a2
        move.l a2,d0
        rts
M4PvWeaponTypes: ;id, M4EnFire type (fire_weapon ids, level_weapons.asm M4_WT_*)
        dc.b 10,0,12,1,38,2,6,3,56,4,34,4,18,5,2,6,4,7,8,8,14,9,20,10,22,11
        dc.b 24,12,26,13,28,14,32,15,36,16,46,17,48,18,50,19,58,20,60,21,62,22,-1
        even
; Create a path object behind a0 with header d0 and path d2 -> a2 (or 0).
M4PvMake:
        movem.l d0-d1/a0,-(sp)
        jsr M4LevelAlloc
        movea.l a0,a2
        cmpa.w #0,a0
        beq M4PvMakeDone
        move.w d0,X_SHAPEHDR(a0) ;original header (findshape of uncatalogued shapes)
        jsr M4LevelShapeIndex
        jsr M4LevelSetShape
        move.w d2,42(a0)
        move.l #M4PathIstrat,32(a0)
M4PvMakeDone:
        movem.l (sp)+,d0-d1/a0
        move.l a2,M4_PV_LASTOBJ
        cmpa.w #0,a2
        rts
; spawn 95E5 / spawnlink 9560: [shape.w][path.w][rx][ry][rz][hp][ap][x][y][z]
M4PvOp_spawn:
        bsr M4PvSpawn
        moveq #13,d0
        bra M4PvAdd
M4PvOp_spawnlink:
        bsr M4PvSpawn
        move.w a2,X_ALPTR(a0)
        cmpa.w #0,a2
        beq M4PvSpawnLinkDone
        move.w a0,X_ALPTR(a2)
M4PvSpawnLinkDone:
        moveq #13,d0
        bra M4PvAdd
; -> a2 new object (or 0), position = parent + 4*rot(offset).
M4PvSpawn:
        moveq #1,d1
        bsr M4PvRdW
        move.w d0,d4
        moveq #3,d1
        bsr M4PvRdW
        move.w d0,d2
        move.w d4,d0
        bsr M4PvMake
        beq M4PvSpawnNone
        move.b 5(a4),d0
        add.b 12(a0),d0
        move.b d0,12(a2)
        move.b 6(a4),d0
        add.b 13(a0),d0
        move.b d0,13(a2)
        move.b 7(a4),d0
        add.b 14(a0),d0
        move.b d0,14(a2)
        move.b 8(a4),38(a2)
        move.b 9(a4),39(a2)
        move.l a2,-(sp)
        move.b 10(a4),d3
        move.b 11(a4),d4
        move.b 12(a4),d5
        movea.l a0,a2
        jsr M4WeaponOffset
        movea.l (sp)+,a2
        add.w (a0),d3
        add.w 2(a0),d4
        add.w 4(a0),d5
        move.w d3,(a2)
        move.w d4,2(a2)
        move.w d5,4(a2)
M4PvSpawnNone:
        rts
; qspawn 9573: [shape.w][path.w][hp][ap]; position and angles copied.
M4PvOp_qspawn:
        moveq #1,d1
        bsr M4PvRdW
        move.w d0,d4
        moveq #3,d1
        bsr M4PvRdW
        move.w d0,d2
        move.w d4,d0
        bsr M4PvMake
        beq M4PvQspawnDone
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        move.w 12(a0),12(a2)
        move.b 14(a0),14(a2)
        move.b 5(a4),38(a2)
        move.b 6(a4),39(a2)
M4PvQspawnDone:
        moveq #7,d0
        bra M4PvAdd
; spawnchild 94A5: child n linked at the end of the mother's chain
; (1F:D56F: child sbyte1 = n, ptr = mother, sword1 0; sflags4 mother/child),
; offsets and rotation offsets kept for rotpos (09:E03F); collflags enemy1.
M4PvOp_spawnchild:
        moveq #1,d1
        bsr M4PvRdW
        move.w d0,d4
        moveq #3,d1
        bsr M4PvRdW
        move.w d0,d2
        move.w d4,d0
        bsr M4PvMake
        beq M4PvChildDone
        ori.b #CF_ENEMY1,44(a2)
        move.b 10(a4),X2_CHILDX(a2)
        move.b 11(a4),X2_CHILDX+1(a2)
        move.b 12(a4),X2_CHILDX+2(a2)
        move.b 5(a4),X2_CHILDRX(a2)
        move.b 6(a4),X2_CHILDRX+1(a2)
        move.b 7(a4),X2_CHILDRX+2(a2)
        move.b 8(a4),38(a2)
        move.b 9(a4),39(a2)
        move.b 13(a4),36(a2)
        move.w a0,X_ALPTR(a2)
        clr.w 40(a2)
        movea.l a0,a3
M4PvChildTail:
        move.w 40(a3),d0
        beq M4PvChildLink
        movea.w d0,a3
        bra M4PvChildTail
M4PvChildLink:
        move.w a2,40(a3)
        bset #6,X2_FL4(a0)
        bset #4,X2_FL4(a2)
M4PvChildDone:
        moveq #14,d0
        bra M4PvAdd
; rotpos_allchildren 09:E118 / 09:E03F: child rot = mother rot + offsets,
; position = mother + 8*rot(offset) (rotz, rotx, roty as gen_weapon).
M4PvRotChildren:
        movem.l d0-d5/a2-a3,-(sp)
        move.w 40(a0),d0
M4PvRotNext:
        tst.w d0
        beq M4PvRotDone
        movea.w d0,a3
        move.b X2_CHILDRX(a3),d0
        add.b 12(a0),d0
        move.b d0,12(a3)
        move.b X2_CHILDRX+1(a3),d0
        add.b 13(a0),d0
        move.b d0,13(a3)
        move.b X2_CHILDRX+2(a3),d0
        add.b 14(a0),d0
        move.b d0,14(a3)
        move.b X2_CHILDX(a3),d3
        move.b X2_CHILDX+1(a3),d4
        move.b X2_CHILDX+2(a3),d5
        movea.l a0,a2
        jsr M4WeaponOffset
        add.w d3,d3
        add.w d4,d4
        add.w d5,d5
        add.w (a0),d3
        add.w 2(a0),d4
        add.w 4(a0),d5
        move.w d3,(a3)
        move.w d4,2(a3)
        move.w d5,4(a3)
        move.w 40(a3),d0
        bra M4PvRotNext
M4PvRotDone:
        movem.l (sp)+,d0-d5/a2-a3
        rts
M4PvOp_flagchild: ;97A8
        bsr M4PvMother
        move.l a2,d0
        beq M4PvFlagChildDone
        move.b 1(a4),d0
        bsr M4PvFindChild
        move.l a2,d0
        beq M4PvFlagChildDone
        bset #5,X2_FL4(a2)
M4PvFlagChildDone:
        addq.w #2,42(a0)
        rts
M4PvOp_unlinkchild: ;980B: child loses its child flag and leaves the chain
        bsr M4PvMother
        move.l a2,d0
        beq M4PvUnlinkDone
        move.b 1(a4),d0
        bsr M4PvFindChild
        move.l a2,d0
        beq M4PvUnlinkDone
        bclr #4,X2_FL4(a2)
        move.w X_ALPTR(a2),d0
        beq M4PvUnlinkDone
        movea.w d0,a3
        move.w a2,d1
M4PvUnlinkFind:
        move.w 40(a3),d0
        beq M4PvUnlinkDone
        cmp.w d0,d1
        beq M4PvUnlinkCut
        movea.w d0,a3
        bra M4PvUnlinkFind
M4PvUnlinkCut:
        move.w 40(a2),40(a3)
M4PvUnlinkDone:
        addq.w #2,42(a0)
        rts
; linkchild 9768 [child]: child n of this object (1F:DC40 from X); if found
; and not already ptr: X.ptr = child, child.ptr = old X.ptr; the first
; object of allst whose ptr is the child (09:B1C7) takes the child's old ptr
; (none: the ROM writes the dummy $156D, skipped); then flagchild (97A8).
M4PvOp_linkchild:
        move.b 1(a4),d0
        movea.l a0,a2
        bsr M4PvFindChild
        move.l a2,d0
        beq M4PvAdd2
        move.w a2,d1
        cmp.w X_ALPTR(a0),d1
        beq M4PvAdd2
        move.w X_ALPTR(a2),d3
        move.w X_ALPTR(a0),X_ALPTR(a2)
        move.w d1,X_ALPTR(a0)
        move.w M4_LV_HEAD,d0
M4PvLinkFind:
        tst.w d0
        beq M4PvOp_flagchild
        movea.w d0,a3
        cmp.w X_ALPTR(a3),d1
        beq.s M4PvLinkFound
        move.w X_NEXT(a3),d0
        bra.s M4PvLinkFind
M4PvLinkFound:
        move.w d3,X_ALPTR(a3)
        bra M4PvOp_flagchild
M4PvAdd2:
        addq.w #2,42(a0)
        rts
; unlinkself 97DD: a child leaves its mother's chain (as divorcefamily
; 1F:DBA4); ptr is kept. Without ptr the ROM walks from WRAM 0: fatal.
M4PvOp_unlinkself:
        btst #4,X2_FL4(a0)
        beq M4PvAdd1
        movea.l a0,a2
        bsr M4PvDivorce
        beq M4PvNullRef
        bra M4PvAdd1
; a2 child: child flag cleared, removed from the sword1 chain of its mother
; (ptr). Z set when it has no ptr (nothing done).
M4PvDivorce:
        move.w X_ALPTR(a2),d0
        beq.s M4PvDivorceDone
        bclr #4,X2_FL4(a2)
        movea.w d0,a3
        move.w a2,d1
M4PvDivorceNext:
        move.w 40(a3),d0
        beq.s M4PvDivorceEnd
        cmp.w d0,d1
        beq.s M4PvDivorceCut
        movea.w d0,a3
        bra.s M4PvDivorceNext
M4PvDivorceCut:
        move.w 40(a2),40(a3)
M4PvDivorceEnd:
        moveq #1,d0
M4PvDivorceDone:
        rts
; removechild 8C9D [child]: child n of the mother (itself, or ptr) removed
; through 1F:D540/D501: deferred for the running object, else removedeadal
; (divorcefamily first: 1F:BFE3). Missing mother/child: the ROM follows 0.
M4PvOp_removechild:
        bsr M4PvMother
        move.l a2,d0
        beq M4PvNullRef
        move.b 1(a4),d0
        bsr M4PvFindChild
        move.l a2,d0
        beq M4PvNullRef
        cmpa.l a0,a2
        bne.s M4PvRemoveChildNow
        moveq #1,d6
        bra M4PvAdd2
M4PvRemoveChildNow:
        btst #4,X2_FL4(a2)
        beq.s M4PvRemoveChildFree
        bsr M4PvDivorce
M4PvRemoveChildFree:
        exg a0,a2
        jsr M4LevelRemove
        exg a0,a2
        bra M4PvAdd2
; findnextshape 8BB8 [shape.w]: from ptr (included; 1F:C870 from $14CC =
; ptr) on along allst, the nearest object with that shape at distXZ in
; [0, 3000); none or no ptr: ptr = 0. Shape 0 selects another search
; (1F:C8B9, sflags3 $08): not modelled.
M4PvOp_findnextshape:
        move.w X_ALPTR(a0),d3
        beq.s M4PvFindNextSet
        moveq #1,d1
        bsr M4PvRdW
        tst.w d0
        beq M4PvBadOp
        move.w d0,d5
        jsr M4LevelShapeIndex
        move.w d0,d4
        move.w #3000,d2
        bsr M4PvFindShape
M4PvFindNextSet:
        move.w d3,X_ALPTR(a0)
        addq.w #3,42(a0)
        rts
; particle 9DE4: nullshape object (1F:D54B) with strategy 06:F7E6 at this
; position (1F:DAD9); $F0CA is not touched. 06:F7E6/F81C (particleexplode,
; UltraStarFox STRAT/EXPSTRAT.ASM) is M4StratParticles (level_asteroid.asm,
; shared with explode debris 06:F1DA): logic only, the GSU particles (MARIO
; MPART.MC: partobj, sbyte1..3 = 60 particles, life 30, type 6) are PEND.
M4PvOp_particle:
        move.w #$ffff,d0
        jsr M4EnCreate
        beq M4PvAdd1
        move.l #M4StratParticles,32(a2)
        move.w #$aca1,X_SHAPEHDR(a2)
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        bra M4PvAdd1
; setstrat 9CE6 [strat.l]: stratptr = strat (it runs from the next tick),
; stratstate alx+$12 = 0, $28 = 0; .move and yield. Strategy routines: the
; level table M4LevelStrategies (level_objects.asm); an unported address is
; fatal ($7B60; BADINDEX = this command).
M4PvOp_setstrat:
        moveq #0,d0
        move.b 3(a4),d0
        swap d0
        move.b 2(a4),d0
        lsl.w #8,d0
        move.b 1(a4),d0
        jsr M4LevelFindStrategy
        move.l a2,d1
        beq.s M4PvSetStratBad
        move.l a2,32(a0)
        clr.b X_STATE(a0)
        clr.w 42(a0)
        clr.w X_SWORD2(a0)
        moveq #PV_YIELD,d7
        rts
M4PvSetStratBad:
        move.w #$7b60,d0
        bra M4PvFatal
M4PvOp_flagmother: ;985C (the same code as flagshape)
M4PvOp_flagshape: ;9872
        move.w X_ALPTR(a0),d0
        beq M4PvAdd1b
        movea.w d0,a2
        bset #5,X2_FL4(a2)
M4PvAdd1b:
        addq.w #1,42(a0)
        rts
M4PvOp_link: ;91DF: pairs two objects through $176B
        move.w M4_PV_LINK,d0
        bne M4PvLinkPair
        move.w a0,M4_PV_LINK
        bra M4PvAdd1b
M4PvLinkPair:
        move.w d0,X_ALPTR(a0)
        movea.w d0,a2
        move.w a0,X_ALPTR(a2)
        clr.w M4_PV_LINK
        bra M4PvAdd1b
; findshape 8B7E: nearest object with that header within [0, 7000).
M4PvOp_findshape:
        moveq #1,d1
        bsr M4PvRdW
        tst.w d0
        beq M4PvBadOp ;shape 0: 1F:C8B9 (sflags3 $08 search), not modelled
        move.w d0,d5
        jsr M4LevelShapeIndex
        move.w d0,d4
        move.w #7000,d2
        move.w M4_LV_HEAD,d3
        bsr M4PvFindShape
        move.w d3,X_ALPTR(a0)
        addq.w #3,42(a0)
        rts
; 1F:C870: the nearest object (not a0) from d3 on along allst with shape
; header d5 (descriptor d4; for shapes outside the port catalog, $FFFF, the
; original header kept in X_SHAPEHDR), distXZ (1F:D0AB) in [0, d2); the
; first one on ties. -> d3 = object (low WORD) or 0.
M4PvFindShape:
        suba.l a3,a3
M4PvFindShapeLoop:
        tst.w d3
        beq.s M4PvFindShapeEnd
        movea.w d3,a2
        move.w X_NEXT(a2),d3
        cmpa.l a0,a2
        beq.s M4PvFindShapeLoop
        cmp.w 46(a2),d4
        bne.s M4PvFindShapeLoop
        cmpi.w #$ffff,d4
        bne.s M4PvFindShapeDist
        cmp.w X_SHAPEHDR(a2),d5
        bne.s M4PvFindShapeLoop
M4PvFindShapeDist:
        jsr M4EnDistXZ
        tst.w d0
        bmi.s M4PvFindShapeLoop
        move.w d0,d1
        sub.w d2,d1
        bpl.s M4PvFindShapeLoop
        move.w d0,d2
        movea.l a2,a3
        bra.s M4PvFindShapeLoop
M4PvFindShapeEnd:
        move.w a3,d3
        rts
; Triggers list (5C always / 5D alwaysoff / 5E force).
M4PvOp_always: ;[target.w][type]
        moveq #0,d0
        move.b X2_NTRIG(a0),d0
        cmpi.w #PV_TRIGMAX,d0
        bhs M4PvStackBad
        add.w d0,d0
        add.w d0,d0
        lea X2_TRIG(a0),a2
        adda.w d0,a2
        moveq #1,d1
        bsr M4PvRdW
        move.w d0,(a2)
        move.b 3(a4),2(a2)
        addq.b #1,X2_NTRIG(a0)
        addq.w #4,42(a0)
        rts
M4PvOp_alwaysoff: ;[target.w]: entry removed
        moveq #1,d1
        bsr M4PvRdW
        lea X2_TRIG(a0),a2
        moveq #0,d2
        move.b X2_NTRIG(a0),d2
        beq M4PvOffDone
        subq.w #1,d2
M4PvOffFind:
        cmp.w (a2),d0
        beq M4PvOffCut
        addq.l #4,a2
        dbra d2,M4PvOffFind
        bra M4PvOffDone
M4PvOffCut:
        subq.w #1,d2
        bmi M4PvOffLast
M4PvOffShift:
        move.l 4(a2),(a2)+
        dbra d2,M4PvOffShift
M4PvOffLast:
        subq.b #1,X2_NTRIG(a0)
M4PvOffDone:
        addq.w #3,42(a0)
        rts
M4PvOp_force: ;9CB1
        tst.b M4_PV_INTRIG
        beq M4PvForceDone
        moveq #1,d1
        bsr M4PvRdW
        move.w d0,M4_PV_PATHPTR
M4PvForceDone:
        addq.w #3,42(a0)
        rts

; ---------------------------------------------------------------------
; Friends (ids 1 rabbit, 2 falcon, 3 frog; 6 = any).
M4PvOp_friend: ;9155
        moveq #0,d0
        move.b 1(a4),d0
        cmpi.b #6,d0
        beq M4PvFriendAny
        lea M4_PV_FRIENDHP,a2
        tst.b (a2,d0.w)
        beq M4PvFriendDone
        move.b d0,X_SBYTE4(a0)
        bra M4PvFriendDone
M4PvFriendAny:
        lea M4_PV_FRIENDHP,a2
        moveq #0,d1 ;alive mask: bit0 rabbit, bit1 falcon, bit2 frog
        tst.b 1(a2)
        beq M4PvFrA
        bset #0,d1
M4PvFrA:
        tst.b 2(a2)
        beq M4PvFrB
        bset #1,d1
M4PvFrB:
        tst.b 3(a2)
        beq M4PvFrC
        bset #2,d1
M4PvFrC:
        tst.w d1
        beq M4PvFriendDone
        cmpi.w #7,d1
        bne M4PvFriendTwo
        jsr M4IntroRandom
        moveq #2,d2
        cmpi.b #$32,d0
        blo M4PvFriendSet
        moveq #1,d2
        cmpi.b #$96,d0
        blo M4PvFriendSet
        moveq #3,d2
        bra M4PvFriendSet
M4PvFriendTwo:
        cmpi.w #6,d1 ;falcon + frog
        bne M4PvFriendFR
        moveq #3,d3
        moveq #$66,d4
        bra M4PvFriendPick
M4PvFriendFR:
        cmpi.w #3,d1 ;falcon + rabbit
        bne M4PvFriendRF
        moveq #1,d3
        moveq #$66,d4
        bra M4PvFriendPick
M4PvFriendRF:
        cmpi.w #5,d1 ;rabbit + frog: r < $7F frog, else rabbit
        bne M4PvFriendOne
        jsr M4IntroRandom
        moveq #3,d2
        cmpi.b #$7f,d0
        blo M4PvFriendSet
        moveq #1,d2
        bra M4PvFriendSet
M4PvFriendPick: ;r < d4 falcon, else d3
        jsr M4IntroRandom
        moveq #2,d2
        cmp.b d4,d0
        blo M4PvFriendSet
        move.w d3,d2
        bra M4PvFriendSet
M4PvFriendOne:
        moveq #1,d2
        btst #0,d1
        bne M4PvFriendSet
        moveq #2,d2
        btst #1,d1
        bne M4PvFriendSet
        moveq #3,d2
M4PvFriendSet:
        move.b d2,X_SBYTE4(a0)
M4PvFriendDone:
        addq.w #2,42(a0)
        rts
M4PvOp_damage: ;92EE: friends_hp[sbyte4] = max(0, hp - 10)
        moveq #0,d0
        move.b X_SBYTE4(a0),d0
        lea M4_PV_FRIENDHP,a2
        move.b (a2,d0.w),d1
        subi.b #10,d1
        bcc M4PvDamageStore
        moveq #0,d1
M4PvDamageStore:
        move.b d1,(a2,d0.w)
        addq.w #1,42(a0)
        rts

; ---------------------------------------------------------------------
; .move 04:A19A.
M4PvMove:
        tst.b X_COUNT1(a0)
        beq M4PvMoveSpace
        move.b 15(a0),d0
        move.b d0,d1
        sub.b 19(a0),d1
        bpl M4PvAccelDown
        add.b X_COUNT1(a0),d0
        move.b d0,d1
        sub.b 19(a0),d1
        bmi M4PvAccelStore
        bra M4PvAccelReach
M4PvAccelDown:
        sub.b X_COUNT1(a0),d0
        move.b d0,d1
        sub.b 19(a0),d1
        bpl M4PvAccelStore
M4PvAccelReach:
        move.b 19(a0),d0
        clr.b X_COUNT1(a0)
M4PvAccelStore:
        move.b d0,15(a0)
        btst #5,X2_FL2(a0)
        bne M4PvMoveSpace
        bsr M4PvGenVecs
M4PvMoveSpace:
        btst #7,X2_FL2(a0)
        beq M4PvMoveZaco
        move.b 14(a0),d0 ;roty += trunc0(trunc0(rotz/2)/2)
        ext.w d0
        bpl M4PvSpace1
        addq.w #1,d0
M4PvSpace1:
        asr.w #1,d0
        bpl M4PvSpace2
        addq.w #1,d0
M4PvSpace2:
        asr.w #1,d0
        add.b d0,13(a0)
M4PvMoveZaco:
        btst #6,X2_FL2(a0)
        beq M4PvMoveRel
        move.b 12(a0),15(a0)
        btst #5,X2_FL2(a0)
        bne M4PvMoveRel
        bsr M4PvGenVecs
M4PvMoveRel:
        btst #4,X2_FL2(a0)
        beq M4PvMoveGen
        jsr M4EnAddPZ
M4PvMoveGen:
        btst #5,X2_FL2(a0)
        beq M4PvMovePos
        bsr M4PvGenVecs
M4PvMovePos:
        jsr M4EnMove
; smoke (04:A22A): every 4th (gameframe + al1pt) with the ROM-like record address.
M4PvSmoke:
        btst #1,X2_FL3(a0)
        beq M4PvSmokeDone
        move.l d1,-(sp) ;al1pt = lo8($0336 + slot * $36), as M4B1Al1pt
        jsr M4B1Al1pt
        move.w M4_LV_GAMEFRAME,d0
        add.w d1,d0
        move.l (sp)+,d1
        andi.w #3,d0
        bne M4PvSmokeDone
        jsr M4FxSmoke
M4PvSmokeDone:
; Trail (04:A247): a text object with a trail colour (alx+$2B) leaves each
; tick a nullshape copy (1F:D54B): rotations, position, string, size, colour
; = trail colour, textobj, no collision, strategy 04:A2F1.
        btst #0,X_TEXTFL(a0)
        beq.s M4PvTrailDone
        tst.b X_TY(a0)
        beq.s M4PvTrailDone
        move.w #$ffff,d0
        jsr M4EnCreate
        beq.s M4PvTrailDone
        move.b 12(a0),12(a2)
        move.b 13(a0),13(a2)
        move.b 14(a0),14(a2)
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        move.w X_COLTAB(a0),X_COLTAB(a2)
        move.b X_TX(a0),X_TX(a2)
        move.b X_TY(a0),X_DEPTHOFF(a2)
        bset #0,X_TEXTFL(a2)
        bset #SF_COLLDISABLE,49(a2)
        move.l #M4PvTrailIstrat,32(a2)
        move.w #$aca1,X_SHAPEHDR(a2)
M4PvTrailDone:
        rts
; Trail copy 04:A2F1: HP 10, AP 8, sbyte1 = 5, then 04:A30A every tick: on
; even sbyte1 the colour (alx+$15) steps down unless it is 1, 5 or 9; z +=
; pviewvelz; sbyte1 - 1, removed (1F:D501) once it was 0.
M4PvTrailIstrat:
        move.b #10,38(a0)
        move.b #8,39(a0)
        move.l #M4PvTrailTick,32(a0)
        move.b #5,36(a0)
M4PvTrailTick:
        btst #0,36(a0)
        bne.s M4PvTrailMove
        move.b X_DEPTHOFF(a0),d0
        cmpi.b #1,d0
        beq.s M4PvTrailMove
        cmpi.b #5,d0
        beq.s M4PvTrailMove
        cmpi.b #9,d0
        beq.s M4PvTrailMove
        subq.b #1,X_DEPTHOFF(a0)
M4PvTrailMove:
        jsr M4EnAddPZ
        tst.b 36(a0)
        beq M4EnRemoveSelf
        subq.b #1,36(a0)
        moveq #0,d0
        rts

; Triggers 04:A099: evaluated after the movement; a met trigger runs its
; routine to the return of $FFFF (it cannot yield). force replaces the
; path pointer restored at the end.
M4PvTriggers:
        tst.b X2_NTRIG(a0)
        beq M4PvTrigNone
        move.w 42(a0),M4_PV_PATHPTR
        move.b #1,M4_PV_INTRIG
        moveq #0,d5
M4PvTrigNext:
        cmp.b X2_NTRIG(a0),d5
        bhs M4PvTrigEnd
        move.w d5,d0
        add.w d0,d0
        add.w d0,d0
        lea X2_TRIG(a0),a2
        adda.w d0,a2
        moveq #0,d0
        move.b 2(a2),d0
        bsr M4PvTrigCond
        beq M4PvTrigSkip
        move.w (a2),-(sp)
        move.w #$ffff,d0
        bsr M4PvPush
        move.w (sp)+,42(a0)
        move.w d5,-(sp)
        bsr M4PvExec
        move.w (sp)+,d5
        cmpi.w #PV_TRET,d7
        bne M4PvTrigAbort
M4PvTrigSkip:
        addq.w #1,d5
        bra M4PvTrigNext
M4PvTrigAbort:
        cmpi.w #PV_END,d7
        beq M4PvTrigEnd ;remove inside a trigger
        bra M4PvBadCommon ;a trigger yielded
M4PvTrigEnd:
        move.w M4_PV_PATHPTR,42(a0)
        clr.w M4_PV_PATHPTR
        clr.b M4_PV_INTRIG
M4PvTrigNone:
        rts
; d0 = type -> Z clear when met (table 04:A0CF).
M4PvTrigCond:
        tst.w d0
        beq M4PvTrigMet
        cmpi.w #7,d0
        bhi M4PvTrigFlags
        moveq #1,d1
        lsl.w d0,d1
        subq.w #1,d1
        and.w M4_LV_GAMEFRAME,d1
        seq d1
        tst.b d1
        rts
M4PvTrigFlags:
        cmpi.w #8,d0
        bne M4PvTrig9
        btst #2,X2_FL3(a0)
        rts
M4PvTrig9:
        cmpi.w #9,d0
        bne M4PvTrig10
        btst #0,X2_FL3(a0)
        rts
M4PvTrig10:
        cmpi.w #10,d0
        bne M4PvTrig11
        bclr #5,X2_FL4(a0)
        rts
M4PvTrig11:
        cmpi.w #11,d0
        bne M4PvTrig12
        tst.w X_ALPTR(a0)
        seq d1
        tst.b d1
        rts
M4PvTrig12:
        tst.b 38(a0)
        seq d1
        tst.b d1
        rts
M4PvTrigMet:
        moveq #1,d1
        rts

M4PathBytes:
        incbin '../build/level-paths.bin'
        even
        include '../build/level-paths.inc'
