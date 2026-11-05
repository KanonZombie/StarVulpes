; Constant-ID calls preserve D0 and CCR of the translated game.
M4PlaySfx macro sid
        move.w sr,-(sp)
        move.l d0,-(sp)
        move.w #\sid,d0
        jsr M4Sfx
        move.l (sp)+,d0
        move.w (sp)+,sr
        endm

M4PlaySfxAt macro sid
        move.w sr,-(sp)
        move.l d0,-(sp)
        move.w #\sid,d0
        jsr M4SfxAt
        move.l (sp)+,d0
        move.w (sp)+,sr
        endm

