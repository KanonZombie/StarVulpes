; Intro playercred camera, selected Star Fox USA ROM.
; 0B:B566 initializer; 0B:B6EA strategy; 0B:D111 Z viewmove;
; 1F:C41E zero-angle vector; 02:F926 getview (zero rotation subset).
; a0 context (18 bytes): worldZ.w, cachedPlayerZ.w, pviewZ.w,
; pviewVelocityZ.w, viewZ.w, slowStarsZ.w, objectVZ.w, speed.b,
; boostCount.b, outDistance.w.
; Word operations wrap. CMP branches deliberately use N rather than N xor V.
; Camera/view ordering: BeginTick BEFORE map/objects, Player AFTER map,
; Finish AFTER all object strategies. Text paths see previous viewZ.
; No VBlank cadence, controller or unrelated player behavior is chosen here.

M4IntroCameraBeginTick:
        move.w (a0),2(a0)       ; 06:835D global strategy cache
        rts

; Call on original playercred initializer event AFTER BeginTick. Preserve
; cachedPlayerZ! The background installs the initializer after playerZ=63.
; The following Player call then produces pviewZ=64, not44.
M4IntroCameraReset:
        clr.w (a0)
        clr.w 4(a0)
        move.w #65,6(a0)
        clr.w 8(a0)
        move.b #65,14(a0)
        move.w #120,16(a0)
        rts

; Restricted to original intro zero pitch/yaw and positive speed. Carries out
; original two 8-bit hardware products, including truncation between them.
; Original sin0=0, cos0=127 at physical0018A5/0018E5. 65 ->64 ->63.
M4IntroCameraPlayer:
        moveq #0,d0
        move.b 14(a0),d0
        bmi.s M4IntroCameraUnsupported
        add.w d0,d0
        mulu.w #127,d0
        lsr.l #8,d0
        add.w d0,d0
        mulu.w #127,d0
        lsr.l #8,d0
        move.w d0,12(a0)
        add.w d0,(a0)           ; 1F:C7CB, add al_vz to al_worldz
        bsr M4IntroCameraViewMove
        addi.w #16,10(a0)       ; 0B:B70A, medpspeed/4
        moveq #0,d0
        rts
M4IntroCameraUnsupported:
        moveq #-1,d0
        rts

; General word-semantic Z fragment, tested against executable original bytes.
; Caller must have pstratflags bits0/2 clear and inside-view mode disabled.
M4IntroCameraViewMove:
        move.w 6(a0),d0
        add.w d0,4(a0)
        cmp.w 12(a0),d0
        beq.s M4IntroCameraClamp
        bmi.s M4IntroCameraVelUp
        subq.w #1,6(a0)
        bra.s M4IntroCameraClamp
M4IntroCameraVelUp:
        addq.w #1,6(a0)
M4IntroCameraClamp:
        move.w 4(a0),d0
        sub.w 2(a0),d0
        tst.w d0
        bmi.s M4IntroCameraClampLow
        cmpi.w #50,d0
        bmi.s M4IntroCameraClampDone
        move.w #50,d0
        bra.s M4IntroCameraClampDone
M4IntroCameraClampLow:
        cmpi.w #-200,d0
        bpl.s M4IntroCameraClampDone
        move.w #-200,d0
M4IntroCameraClampDone:
        add.w 2(a0),d0
        move.w d0,4(a0)
        cmpi.b #10,15(a0)
        beq.s M4IntroCameraChase
        bpl.s M4IntroCameraViewReturn
M4IntroCameraChase:
        move.w 2(a0),d0
        cmp.w 4(a0),d0
        beq.s M4IntroCameraViewReturn
        sub.w 4(a0),d0
        tst.w d0
        bmi.s M4IntroCameraChaseNegative
        cmpi.w #8,d0
        bpl.s M4IntroCameraDivide
        moveq #8,d0
        bra.s M4IntroCameraDivide
M4IntroCameraChaseNegative:
        cmpi.w #-8,d0
        bmi.s M4IntroCameraDivide
        moveq #-8,d0
M4IntroCameraDivide:
        move.w d0,d1
        asr.w #3,d0             ; same as three signed /2 toward zero
        tst.w d1
        bpl.s M4IntroCameraChaseDone
        andi.w #7,d1
        beq.s M4IntroCameraChaseDone
        addq.w #1,d0
M4IntroCameraChaseDone:
        add.w d0,4(a0)
M4IntroCameraViewReturn:
        rts

; Only after all strategies. With original zero rotation/float/shake/offset,
; getview's two rotation passes place the view exactly outdist behind pview.
M4IntroCameraFinish:
        move.w 4(a0),d0
        sub.w 16(a0),d0
        move.w d0,8(a0)
        rts
