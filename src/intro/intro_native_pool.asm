; Original allocator identity: entry78AE, base0336/stride54/70 blocks.
; Retain original LIFO free-list semantics independently of MD pool slots.
; Fire's original delay is BYTE(gameframe+al1pt)&3, so identity is observable.
M4_NATIVE_HEAD equ $ff82ac
M4_NATIVE_ERROR equ $ff82ae
M4_NATIVE_NEXT equ $ff9000 ; seventy WORD links by source block index
M4_NATIVE_TRAILS equ $ff9200
M4_NATIVE_PARENTS equ $ff9220
M4_NATIVE_SHIPS equ $ff9224
M4_NATIVE_FIRE equ $ff922a

M4IntroNativeInit:
        lea M4_NATIVE_NEXT,a0
        moveq #69,d1
M4NativeClearLinks:
        clr.w (a0)+
        dbra d1,M4NativeClearLinks
        lea M4_NATIVE_TRAILS,a0
        moveq #10,d1
M4NativeClearIdentities:
        clr.l (a0)+
        dbra d1,M4NativeClearIdentities
        clr.w M4_NATIVE_ERROR
        move.w #$444,M4_NATIVE_PARENTS
        move.w #$47a,M4_NATIVE_PARENTS+2
        move.w #$4b0,M4_NATIVE_HEAD
        lea M4_NATIVE_NEXT+14,a0
        move.w #$4e6,d0
        moveq #61,d1
M4NativeLinkFree:
        move.w d0,(a0)+
        addi.w #54,d0
        dbra d1,M4NativeLinkFree
        rts

; d0=native identity, 0 error. Preserve all other registers.
M4IntroNativeAllocate:
        movem.l d1/a0,-(sp)
        moveq #0,d0
        move.w M4_NATIVE_HEAD,d0
        beq.s M4NativeAllocateBad
        move.w d0,d1
        subi.w #$336,d1
        andi.l #$ffff,d1
        divu.w #54,d1
        add.w d1,d1
        lea M4_NATIVE_NEXT,a0
        move.w (a0,d1.w),M4_NATIVE_HEAD
        clr.w (a0,d1.w)
        bra.s M4NativeAllocateReturn
M4NativeAllocateBad:
        move.w #-1,M4_NATIVE_ERROR
M4NativeAllocateReturn:
        movem.l (sp)+,d1/a0
        rts

; d0=native identity; original removed block becomes the free-list head.
M4IntroNativeRemove:
        movem.l d0-d1/a0,-(sp)
        move.w d0,d1
        subi.w #$336,d1
        andi.l #$ffff,d1
        divu.w #54,d1
        add.w d1,d1
        lea M4_NATIVE_NEXT,a0
        move.w M4_NATIVE_HEAD,(a0,d1.w)
        move.w d0,M4_NATIVE_HEAD
        movem.l (sp)+,d0-d1/a0
        rts

; Hook own trail slot d2 (unshifted). Slot and source identity are separate.
M4IntroNativeTrailAllocate:
        movem.l d0-d1/a4,-(sp)
        bsr M4IntroNativeAllocate
        move.w d2,d1
        add.w d1,d1
        lea M4_NATIVE_TRAILS,a4
        move.w d0,(a4,d1.w)
        movem.l (sp)+,d0-d1/a4
        rts

; Hook own trail byte offset d2 (index*32) at removal, preserve caller state.
M4IntroNativeTrailRemove:
        movem.l d0-d1/a4,-(sp)
        move.w d2,d1
        lsr.w #4,d1
        lea M4_NATIVE_TRAILS,a4
        move.w (a4,d1.w),d0
        bsr M4IntroNativeRemove
        clr.w (a4,d1.w)
        movem.l (sp)+,d0-d1/a4
        rts

; a0=text parent after its path tick. Remove identity exactly once.
M4IntroNativeParent:
        movem.l d0-d1/a4,-(sp)
        tst.w 16(a0)
        bne.s M4NativeParentDone
        moveq #0,d1
        cmpa.l #TEXT_OBJECTS,a0
        beq.s M4NativeParentIndex
        moveq #2,d1
M4NativeParentIndex:
        lea M4_NATIVE_PARENTS,a4
        move.w (a4,d1.w),d0
        beq.s M4NativeParentDone
        bsr M4IntroNativeRemove
        clr.w (a4,d1.w)
M4NativeParentDone:
        movem.l (sp)+,d0-d1/a4
        rts
