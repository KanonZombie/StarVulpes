; Consumer of original intro commands 74/3E/8C/3C, not hand-built text poses.
; Entry is the Nintendo Presents segment at original script index $78ae.
; The preceding loader/wipe/player scheduler is a separate integration unit.
TEXT_OBJECTS equ $ff8400
TEXT_MAP_CONTEXT equ $ff8280
TEXT_OBJECT_COUNT equ $ff8270
TEXT_LAST_OBJECT equ $ff8274

M4TextObjectsInit:
        lea TEXT_OBJECTS,a0
        moveq #0,d0
        moveq #15,d1
M4TextObjectsClear:
        move.l d0,(a0)+
        dbra d1,M4TextObjectsClear
        lea TEXT_MAP_CONTEXT,a0
        moveq #7,d1 ;includes the program pointer at +28 (0 = intro stream)
M4TextObjectsClearMap:
        move.l d0,(a0)+
        dbra d1,M4TextObjectsClearMap
        clr.w TEXT_OBJECT_COUNT
        clr.l TEXT_LAST_OBJECT
        lea TEXT_MAP_CONTEXT,a0
        move.w #$78ae,(a0)
        move.b #13,19(a0)
        bsr M4ScriptNext
M4TextObjectsEvent:
        cmpi.w #1,d0
        bne M4TextObjectsReturn
        move.w 20(a0),d0
        cmpi.w #$74,d0
        beq.s M4TextObjectsCreate
        movea.l TEXT_LAST_OBJECT,a5
        move.l a5,d0
        beq M4TextObjectsInvalid
        move.w 20(a0),d0
        cmpi.w #$3e,d0
        beq M4TextObjectsWord
        cmpi.w #$8c,d0
        beq M4TextObjectsPath
        cmpi.w #$3c,d0
        beq M4TextObjectsByte
        bra M4TextObjectsInvalid
M4TextObjectsCreate:
        cmpi.b #$e4,9(a1)
        bne M4TextObjectsInvalid
        cmpi.w #2,TEXT_OBJECT_COUNT
        bhs M4TextObjectsInvalid
        move.w TEXT_OBJECT_COUNT,d0
        lsl.w #5,d0
        lea TEXT_OBJECTS,a5
        adda.w d0,a5
        move.l a5,TEXT_LAST_OBJECT
        addq.w #1,TEXT_OBJECT_COUNT
        bsr M4ScriptOperand
        move.w d1,2(a0) ; original mapwait from command, usually zero here
        moveq #0,d2
        moveq #3,d3
M4TextObjectsCoordinate:
        move.b 1(a1,d3.w),d1
        lsl.w #8,d1
        move.b (a1,d3.w),d1
        move.w d1,(a5,d2.w)
        addq.w #2,d2
        addq.w #2,d3
        cmpi.w #6,d2
        bne.s M4TextObjectsCoordinate
        ; Original mapdobjdo adds the player's world Z at creation.
        move.w INTRO_CAMERA,d1
        add.w d1,4(a5)
        move.w #1,16(a5)
        bra.s M4TextObjectsCommit
M4TextObjectsWord:
        cmpi.b #$ea,1(a1)
        bne.s M4TextObjectsInvalid
        cmpi.b #$fc,2(a1)
        bne.s M4TextObjectsInvalid
        move.b 4(a1),d1
        lsl.w #8,d1
        move.b 3(a1),d1
        move.w d1,18(a5)
        bra.s M4TextObjectsCommit
M4TextObjectsPath:
        bsr M4ScriptOperand
        move.w d1,6(a5)
        bra.s M4TextObjectsCommit
M4TextObjectsByte:
        cmpi.b #$fc,2(a1)
        bne.s M4TextObjectsInvalid
        cmpi.b #$df,1(a1)
        beq.s M4TextObjectsDepth
        cmpi.b #$f4,1(a1)
        bne.s M4TextObjectsInvalid
        move.b 3(a1),20(a5)
        bra.s M4TextObjectsCommit
M4TextObjectsDepth:
        move.b 3(a1),10(a5)
M4TextObjectsCommit:
        bsr M4ScriptCommit
        bra M4TextObjectsEvent
M4TextObjectsInvalid:
        moveq #-1,d0
M4TextObjectsReturn:
        rts
