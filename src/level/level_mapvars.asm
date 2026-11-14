; Original WRAM/GSU variables reached by the map scripts (setvar, and/or,
; branch blocks, mapif), with their port location. Variables whose consumers
; are not ported yet still get a byte here so the scripts run in order and
; the later consumer reads the same place (build/map-programs.json lists the
; writers). WORD variables keep the original little-endian byte order in this
; block (orig -> port, orig+1 -> port+1) unless they are port WORDs.
M4_MV equ $fff9b0 ;block of written-only variables (32 bytes)
M4_MV_176F equ M4_MV+0 ;.b $176F map flags (flags176f_wait/switch)
M4_MV_1FE2 equ M4_MV+1 ;.b $1FE2 numendok (theenddead)
M4_MV_1FDF equ M4_MV+2 ;.b $1FDF
M4_MV_1EF3 equ M4_MV+3 ;.b $1EF3 (Meteor)
M4_MV_1784 equ M4_MV+4 ;.b $1784
M4_MV_16A4 equ M4_MV+5 ;.b $16A4 dospacesc
M4_MV_1551 equ M4_MV+6 ;.b $1551 psvar
M4_MV_1F13 equ M4_MV+8 ;.w $1F13 (Meteor), little-endian
M4_MV_1F17 equ M4_MV+10 ;.w $1F17
M4_MV_1F19 equ M4_MV+12 ;.w $1F19
M4_MV_1743 equ M4_MV+14 ;.w $1743
M4_MV_1FE4 equ M4_MV+16 ;.w $1FE4
M4_MV_1F37 equ M4_MV+18 ;.w $1F37
M4_MV_1F39 equ M4_MV+20 ;.w $1F39
M4_MV_DEPTH equ M4_MV+26 ;.w 70:004E m_depthstab, little-endian
M4_MV_END equ M4_MV+32

M4MapVarsInit:
        movem.l d0/a0,-(sp)
        move.b M4_MV_1784,-(sp) ;infog is written by map commands across stages
        lea M4_MV,a0
        moveq #7,d0
M4MvClear:
        clr.l (a0)+
        dbra d0,M4MvClear
        clr.w M4_SPACE_SCROLLZ
        move.b #$8a,M4_MV_DEPTH
        move.b #$8b,M4_MV_DEPTH+1
        move.b (sp)+,M4_MV_1784
        movem.l (sp)+,d0/a0
        rts

; d0.l = original address (bank 00 = WRAM 7E:0000..1FFF) -> a3 = port byte,
; d1 = 0 (Z) when known, -1 otherwise.
M4LvVarAddr:
        movem.l d2/a2,-(sp)
        move.l d0,d2
        swap d2
        cmpi.w #$7e,d2 ;7E:xxxx below $2000 = 00:xxxx
        bne.s M4LvVarSearch
        move.l d0,d2
        andi.l #$ffff,d2
        cmpi.w #$2000,d2
        bhs.s M4LvVarSearch
        move.l d2,d0 ;7E:0000..1FFF = 00:0000..1FFF
M4LvVarSearch:
        cmpi.l #$0018a1,d0 ;friends_hp $18A1+id
        blo.s M4LvVarTab
        cmpi.l #$0018a4,d0
        bhi.s M4LvVarTab
        lea M4_PV_FRIENDHP-$18a1,a3
        adda.w d0,a3
        bra.s M4LvVarFound
M4LvVarTab:
        lea M4LvVarTable,a2
M4LvVarNext:
        move.l (a2)+,d2
        beq.s M4LvVarNone
        movea.l (a2)+,a3
        cmp.l d2,d0
        bne.s M4LvVarNext
M4LvVarFound:
        movem.l (sp)+,d2/a2
        moveq #0,d1
        rts
M4LvVarNone:
        cmpi.l #$7ef0b0,d0 ;path globals 7E:F0B0..F0DF (M4_PV_GLOB, level_paths.asm),
        blo.s M4LvVarUnknown ;e.g. ebyte3 7E:F0D8 read by 05:8399; after the table: F0B7
        cmpi.l #$7ef0e0,d0 ;is M4_LV_SKILLFLY
        bhs.s M4LvVarUnknown
        move.w d0,d2
        subi.w #$f0b0,d2
        lea M4_PV_GLOB,a3
        adda.w d2,a3
        bra.s M4LvVarFound
M4LvVarUnknown:
        movem.l (sp)+,d2/a2
        moveq #-1,d1
        rts
M4LvVarTable:
        dc.l $7ef0b7,M4_LV_SKILLFLY
        dc.l $00150f,M4_SC_PPOSX+1 ;player_pos $150F..$1514 (port WORDs, big-endian):
        dc.l $001510,M4_SC_PPOSX ;addalvarptr.w of Titania 05:8200, 05:85C4, 05:85D9
        dc.l $001511,M4_SC_PPOSY+1
        dc.l $001512,M4_SC_PPOSY
        dc.l $001513,M4_LP_POSZ+1
        dc.l $001514,M4_LP_POSZ
        dc.l $0018b4,M4_FADE ;fadedir
        dc.l $0014d8,M4_LP_PSF
        dc.l $0014d9,M4_LP_PSF2
        dc.l $0014da,M4_LP_PSF3
        dc.l $0014dc,M4_LP_FLYMODE ;playerflymode (credits 0D:F22F: pfm_wobble off)
        dc.l $0014d2,M4_LP_GAMEFLAGS
        dc.l $0014df,M4_BOSS_PSTRATF
        dc.l $0014dd,M4_SPP_FM
        dc.l $0014de,M4_SPP_FMOPT
        dc.l $00021c,M4_SC_MMETERS ;70:021C m_meters (setvar low address)
        dc.l $701a26,M4_MV+30 ;70:1A26 stars/snow/pollen
        dc.l $70004e,M4_MV_DEPTH
        dc.l $70004f,M4_MV_DEPTH+1
        dc.l $001964,M4_SC_STAYBLACK
        dc.l $0015b7,M4_SC_SCRAMBLE
        dc.l $001f07,M4_SC_KEEPPSTRAT
        dc.l $00173e,M4_LV_SPECIALS+1
        dc.l $0014db,M4_LV_SPECIALDEAD+1
        dc.l $00001c,M4_GM_CLB2
        dc.l $001fd0,M4_GM_DONEACIRCLE
        dc.l $001fe0,M4_TR_PRTTRAIN
        dc.l $001fcf,M4_GM_ONECRED
        dc.l $001fff,M4_GS_WHICHROUTE ;route 0/1/2
        dc.l $00176f,M4_MV_176F
        dc.l $001fe2,M4_MV_1FE2
        dc.l $001fdf,M4_MV_1FDF
        dc.l $001ef3,M4_MV_1EF3
        dc.l $001784,M4_MV_1784
        dc.l $0016a4,M4_MV_16A4
        dc.l $001551,M4_MV_1551
        dc.l $001f13,M4_MV_1F13
        dc.l $001f14,M4_MV_1F13+1
        dc.l $001f17,M4_MV_1F17
        dc.l $001f18,M4_MV_1F17+1
        dc.l $001f19,M4_MV_1F19
        dc.l $001f1a,M4_MV_1F19+1
        dc.l $001743,M4_MV_1743
        dc.l $001744,M4_MV_1743+1
        dc.l $001fe4,M4_MV_1FE4
        dc.l $001fe5,M4_MV_1FE4+1
        dc.l $001f37,M4_MV_1F37
        dc.l $001f38,M4_MV_1F37+1
        dc.l $001f39,M4_MV_1F39
        dc.l $001f3a,M4_MV_1F39+1
        dc.l $00169e,M4_SC_BG2Y+1 ;bg2Yscroll (port WORD, big-endian)
        dc.l $00169f,M4_SC_BG2Y
        dc.l $00159a,M4_LP_VIEWDIST+1 ;viewdist (port WORD): store_byte_word 0D:D745
        dc.l $00159b,M4_LP_VIEWDIST
        dc.l $001fd4,M4_GS_LEVELFIN ;levelfinished: branch_if_byte_zero 0D:D669 (wait until 0)
        dc.l 0

; ---------------------------------------------------------------------
; Map blocks (kinds of tools/generate-map-programs.py) beyond the Corneria
; set. a0 = map context, a2 = block record (2 kind, 4 next, 6 branch,
; 8 arg.l, 12 arg2.l). Entered with d0 = kind from M4LvBlock.
M4MvBlockExt:
        cmpi.w #M4_LEVEL_KIND_CLEARREALOBJMAP_L,d0
        beq M4MvClearRealObj
        cmpi.w #M4_LEVEL_KIND_BRANCH_IF_BYTE_ZERO,d0
        beq M4MvBranchZero
        cmpi.w #M4_LEVEL_KIND_BRANCH_IF_BYTE_NE,d0
        beq M4MvBranchNe
        cmpi.w #M4_LEVEL_KIND_CLEAR_BOSS_MAXHP,d0
        beq M4MvClearBossMax
        cmpi.w #M4_LEVEL_KIND_CLEARMAP_L,d0
        beq M4MvClearMap
        cmpi.w #M4_LEVEL_KIND_SET_DOTSFLAG,d0
        beq M4MvSetDots
        cmpi.w #M4_LEVEL_KIND_RESET_VIEW_Z,d0
        beq M4MvResetViewZ
        cmpi.w #M4_LEVEL_KIND_BRANCH_IF_SHAPE_ABSENT,d0
        beq M4MvShapeAbsent
        cmpi.w #M4_LEVEL_KIND_AND_BYTES2,d0
        beq M4MvAndBytes2
        cmpi.w #M4_LEVEL_KIND_CLEAR_BYTE,d0
        beq M4MvClearByte
        cmpi.w #M4_LEVEL_KIND_STORE_BYTE_WORD,d0
        beq M4MvStoreByteWord
        cmpi.w #M4_LEVEL_KIND_AND_OR_BYTES,d0
        beq M4MvAndOrBytes
        cmpi.w #M4_LEVEL_KIND_FLAGS176F_WAIT,d0
        beq M4MvF176Wait
        cmpi.w #M4_LEVEL_KIND_FLAGS176F_SWITCH,d0
        beq M4MvF176Switch
        cmpi.w #M4_LEVEL_KIND_INITFADEWHITE2NORM_L,d0
        beq M4MvWhite2Norm
        cmpi.w #M4_LEVEL_KIND_BG_1_4B_1,d0
        beq M4MvBg14b
        jmp M4LvUnsupported
; bg_1_4b_1 03:9877 (Titania): zdepth 70:0050 = $8FAA, gamepal 2,
; m_depthstab 70:004E = $8C0A, shadowheight $1961 = 0.
M4MvBg14b:
        move.l #M4DepthNormal,M4_SC_DEPTH
        move.b #$0a,M4_MV_DEPTH
        move.b #$8c,M4_MV_DEPTH+1
        moveq #2,d0
        jsr M4LvGamepal
        bra M4MvNext
; gamepal 02:F484: d0 = n -> MD line 2 = build/level-gamepals.md.bin row n.
M4LvGamepal:
        movem.l d0-d1/a0-a1,-(sp)
        andi.w #7,d0
        lsl.w #5,d0
        lea M4LevelGamepals,a0
        adda.w d0,a0
        lea M4_BASE_CRAM+64,a1
        moveq #15,d1
M4LvGamepalCopy:
        move.w (a0)+,(a1)+
        dbra d1,M4LvGamepalCopy
        eori.b #$40,M4_SC_PALVER
        movem.l (sp)+,d0-d1/a0-a1
        rts
M4LevelGamepals:
        incbin '../build/level-gamepals.md.bin'
M4MvNext:
        jmp M4LvGoNext
M4MvBranch:
        move.w 6(a2),d0
        jmp M4LvGoTo
M4MvArg2:
        move.w 14(a2),d0
        jmp M4LvGoTo
M4MvBad:
        jmp M4LvUnsupported
; byte at the original address 8(a2) -> d1 (flags of the value), a3.
M4MvReadArg:
        move.l 8(a2),d0
        andi.l #$ffffff,d0
        jsr M4LvVarAddr
        tst.l d1
        bmi.s M4MvReadBad
        move.b (a3),d1
        rts
M4MvReadBad:
        addq.l #4,sp ;drop the caller: unsupported
        bra.s M4MvBad
; branch_if_byte_zero: if byte addr == 0 -> branch else next.
M4MvBranchZero:
        bsr.s M4MvReadArg
        tst.b d1
        beq.s M4MvBranch
        bra.s M4MvNext
; branch_if_byte_ne: if byte addr != value -> branch else next.
M4MvBranchNe:
        bsr.s M4MvReadArg
        cmp.b 15(a2),d1
        bne.s M4MvBranch
        bra.s M4MvNext
; clear_boss_maxhp: 70:019A = 0.
M4MvClearBossMax:
        clr.b M4_BOSS_MAXHP
        bra.s M4MvNext
; clearmap_l 1F:D3E0.
M4MvClearMap:
        jsr M4ScClearMap
        bra.s M4MvNext
; set_dotsflag: dotsflag 1, $16FC 0, 70:1A26/27 0.
M4MvSetDots:
        move.b #1,M4_SC_DOTS
        bra.s M4MvNext
; reset_view_z: lastplayz $1701, pviewposz and the player worldZ = 0.
M4MvResetViewZ:
        clr.w 4(a0)
        clr.w M4_LP_PVIEWZ
        clr.w LV_PLAYER+4
        bra.s M4MvNext
; branch_if_shape_absent (09:B1FF): no object of allst with the shape header
; arg -> branch, else next.
M4MvShapeAbsent:
        move.w 10(a2),d1
        move.w M4_LV_HEAD,d0
M4MvShapeNext:
        tst.w d0
        beq M4MvBranch
        movea.w d0,a3
        cmp.w X_SHAPEHDR(a3),d1
        beq M4MvNext
        move.w X_NEXT(a3),d0
        bra.s M4MvShapeNext
; byte at the original 16-bit address d0.w (bank 00) -> a3 (unsupported on miss).
M4MvAddr16:
        andi.l #$ffff,d0
        jsr M4LvVarAddr
        tst.l d1
        bpl.s M4MvAddrOk
        addq.l #4,sp
        bra M4MvBad
M4MvAddrOk:
        rts
; and_bytes2: byte addr &= m1; byte addrb &= m2.
M4MvAndBytes2:
        move.w 10(a2),d0
        bsr.s M4MvAddr16
        move.b 14(a2),d0
        and.b d0,(a3)
        move.w 12(a2),d0
        bsr.s M4MvAddr16
        move.b 15(a2),d0
        and.b d0,(a3)
        bra M4MvNext
; and_or_bytes: byte addr &= m1; byte addrb |= m2.
M4MvAndOrBytes:
        move.w 10(a2),d0
        bsr.s M4MvAddr16
        move.b 14(a2),d0
        and.b d0,(a3)
        move.w 12(a2),d0
        bsr.s M4MvAddr16
        move.b 15(a2),d0
        or.b d0,(a3)
        bra M4MvNext
; clear_byte: byte addr = 0.
M4MvClearByte:
        move.w 10(a2),d0
        bsr.s M4MvAddr16
        clr.b (a3)
        bra M4MvNext
; store_byte_word: byte addr = value (arg bits 31..24); word addrw = valuew.
M4MvStoreByteWord:
        move.w 10(a2),d0
        bsr.s M4MvAddr16
        move.b 8(a2),(a3)
        move.w 12(a2),d0
        bsr.s M4MvAddr16
        move.b 15(a2),(a3) ;low byte
        move.w 12(a2),d0
        addq.w #1,d0
        bsr.s M4MvAddr16
        move.b 14(a2),(a3) ;high byte
        bra M4MvNext
; flags176f_wait: b = $176F; b & 2 -> branch; !(b & 1) -> arg2 (wait on the
; previous command); else $176F = b & $FE -> next.
M4MvF176Wait:
        move.b M4_MV_176F,d1
        btst #1,d1
        bne M4MvBranch
        btst #0,d1
        beq M4MvArg2
        bclr #0,M4_MV_176F
        bra M4MvNext
; flags176f_switch: b = $176F; $176F = 0; b & 1 -> branch; b & 2 -> arg2; else next.
M4MvF176Switch:
        move.b M4_MV_176F,d1
        clr.b M4_MV_176F
        btst #0,d1
        bne M4MvBranch
        btst #1,d1
        bne M4MvArg2
        bra M4MvNext
; initfadewhite2norm_l 02:FEC1: white window 31, then fadewhite2norm 02:FEE8
; lowers it one step per tick (M4MvWhiteTick; MD add = level >> 2).
M4MvWhite2Norm:
        move.b #31,M4_MV+28
        move.b #7,M4_WHITEADD
        bra M4MvNext
M4MvWhiteTick:
        move.b M4_MV+28,d0
        beq.s M4MvWhiteDone
        subq.b #1,d0
        move.b d0,M4_MV+28
        lsr.b #2,d0
        move.b d0,M4_WHITEADD
M4MvWhiteDone:
        rts

; mapif kinds beyond chkstratdone1 / chkbossdead: carry -> branch, else
; wait (the false path of M4LvBossAlive).
M4MvMapIfExt:
        cmpi.w #M4_LEVEL_KIND_CHKSTAGEDONE,2(a2)
        bne.s M4MvIfStrat2
        bclr #7,M4_LP_GAMEFLAGS ;06:8BA1 stagedone, cleared
        beq.s M4MvIfFalse
        bra M4MvBranch
M4MvIfStrat2:
        cmpi.w #M4_LEVEL_KIND_CHKSTRATDONE2,2(a2)
        bne.s M4MvIfEnd
        btst #4,M4_LP_GAMEFLAGS ;06:8BD1 stratdone2, not cleared
        beq.s M4MvIfFalse
        bra M4MvBranch
M4MvIfEnd:
        cmpi.w #M4_LEVEL_KIND_THEENDDEAD,2(a2)
        bne M4MvBad
        cmpi.b #$ff,M4_MV_1FE2 ;0A:9821 numendok == $FF
        bne.s M4MvIfFalse
        bra M4MvBranch
M4MvIfFalse:
        jmp M4LvBossAlive

; clearrealobjmap_l 1F:D3FD: every object of allst with sflags3 $08 (realobj)
; removed (removedeadal 1F:BFDC); the player never carries it in the port.
M4MvClearRealObj:
        movem.l d0/a0,-(sp)
        move.w M4_LV_HEAD,d0
M4MvClearRealNext:
        tst.w d0
        beq.s M4MvClearRealDone
        movea.w d0,a0
        move.w X_NEXT(a0),d0
        cmpa.w #LV_PLAYER&$ffff,a0
        beq.s M4MvClearRealNext
        btst #3,X2_FL3(a0)
        beq.s M4MvClearRealNext
        move.w d0,-(sp)
        jsr M4LevelRemove
        move.w (sp)+,d0
        bra.s M4MvClearRealNext
M4MvClearRealDone:
        movem.l (sp)+,d0/a0
        bra M4MvNext
