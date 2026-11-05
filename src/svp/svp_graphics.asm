; Command 1: turn palette index C into 64 alternating C/2 pixels (one 8x8 tile).
; Input C is unsigned, masked to four bits. Output words are $C2C2.
; Address each word explicitly, avoiding unresolved blind-access increment quirks.
SVP_Graphics:
        dc.w $08e0,$0000,$08e0,$0018,$000c ; PM4 read input C
        dc.w $e003,$003c,$b80f             ; eor a,a / ld a,ext4 / andi 0f
        dc.w $0810,$0002                  ; ld x,0002 (white palette index)
        dc.w $9003,$9003,$9003,$9003       ; shl four times: C -> C0
        dc.w $c001                        ; or a,x: C2
        dc.w $0013                        ; ld x,a: save C2
        dc.w $9003,$9003,$9003,$9003       ; shift left eight: C2 -> C200
        dc.w $9003,$9003,$9003,$9003
        dc.w $c001                        ; or a,x: C2C2

        dc.w $08e0,$0010,$08e0,$0018,$00c0
SVP_GraphicsFirstWrite:
        dc.w $00c3                        ; first of 16 calculated tile words
        dc.w $08e0,$0011,$08e0,$0018,$00c0,$00c3
        dc.w $08e0,$0012,$08e0,$0018,$00c0,$00c3
        dc.w $08e0,$0013,$08e0,$0018,$00c0,$00c3
        dc.w $08e0,$0014,$08e0,$0018,$00c0,$00c3
        dc.w $08e0,$0015,$08e0,$0018,$00c0,$00c3
        dc.w $08e0,$0016,$08e0,$0018,$00c0,$00c3
        dc.w $08e0,$0017,$08e0,$0018,$00c0,$00c3
        dc.w $08e0,$0018,$08e0,$0018,$00c0,$00c3
        dc.w $08e0,$0019,$08e0,$0018,$00c0,$00c3
        dc.w $08e0,$001a,$08e0,$0018,$00c0,$00c3
        dc.w $08e0,$001b,$08e0,$0018,$00c0,$00c3
        dc.w $08e0,$001c,$08e0,$0018,$00c0,$00c3
        dc.w $08e0,$001d,$08e0,$0018,$00c0,$00c3
        dc.w $08e0,$001e,$08e0,$0018,$00c0,$00c3
        dc.w $08e0,$001f,$08e0,$0018,$00c0,$00c3
        dc.w $4c00,SVP_PublishResult/2     ; result/echo/XST AFTER all tile writes
