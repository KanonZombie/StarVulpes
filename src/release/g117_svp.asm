; graphics117 SSP program changes (lots 83..117, tools/hw-boot/make-round27.py
; .. make-round56.py). Generated once from the Nomad-measured 117 image as
; symbolic dc.w: branch targets use labels, IRAM targets stay numeric.
; Included at SVP_End: the stub block follows the generated program; the
; overrides then rewrite the listed routines in place and the PC returns.

        dc.w $0000                   ; nop
G117S15728:
        dc.w $e003                   ; eor a,a
        dc.w $06f2                   ; ld a,($0f2)
        dc.w $6800,$0003             ; cmp a,#$0003
        dc.w $4d50,G117S15742/2            ; bra z=1,$aba1
        dc.w $08e0,$000d             ; ld pmc,#$000d
        dc.w $4c00,SVP_FaceCountValid/2+2  ; bra always,$279d
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
G117S15742:
        dc.w $08e0,((G117ImgFaces)>>1)&$ffff ; ld pmc: PM4 reads G117ImgFaces
        dc.w $08e0,$0800|((G117ImgFaces)>>17)
        dc.w $000c                   ; ld -,pm4
        dc.w $08e0,$8020             ; ld pmc,#$8020
        dc.w $08e0,$081c             ; ld pmc,#$081c
        dc.w $00c0                   ; ld pm4,-
        dc.w $0810,$03c8             ; ld x,#$03c8
        dc.w $4800,G117S01f0e/2            ; call always,$0f87
        dc.w $4c00,G117S01e9e/2            ; bra always,$0f4f
G117S15762:
        dc.w $e003                   ; eor a,a
        dc.w $06f2                   ; ld a,($0f2)
        dc.w $6800,$0003             ; cmp a,#$0003
        dc.w $4d50,$0312                   ; bra z=1,$0312
        dc.w $e003                   ; eor a,a
        dc.w $0631                   ; ld a,($031)
        dc.w $4c00,SVP_GeoDivide/2+2       ; bra always,$25e2
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
G117S15780:
        dc.w $08e0,$8000             ; ld pmc,#$8000
        dc.w $08e0,$081c             ; ld pmc,#$081c
        dc.w $00c0                   ; ld pm4,-
        dc.w $e003                   ; eor a,a
        dc.w $0830,$00c2             ; ld a,#$00c2
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$00c2             ; ld a,#$00c2
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$00c2             ; ld a,#$00c2
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$00c2             ; ld a,#$00c2
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$00c2             ; ld a,#$00c2
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$00c2             ; ld a,#$00c2
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$00c2             ; ld a,#$00c2
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$00c2             ; ld a,#$00c2
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$00c2             ; ld a,#$00c2
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$00c2             ; ld a,#$00c2
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$00c2             ; ld a,#$00c2
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$00c2             ; ld a,#$00c2
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$00c2             ; ld a,#$00c2
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$00c2             ; ld a,#$00c2
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$00c2             ; ld a,#$00c2
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$00c2             ; ld a,#$00c2
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$2800             ; ld a,#$2800
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$0001             ; ld a,#$0001
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$4c50             ; ld a,#$4c50
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$0000             ; ld a,#$0000
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$4c00             ; ld a,#$4c00
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,SVP_IntroClearTile/2+20 ; ld a,#$0b21 (IRAM code word: branch target)
        dc.w $00c3                   ; ld pm4,a
        dc.w $e003                   ; eor a,a
        dc.w $06f6                   ; ld a,($0f6)
        dc.w $00e3                   ; ld pmc,a
        dc.w $08e0,$0818             ; ld pmc,#$0818
        dc.w $00c0                   ; ld pm4,-
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0300             ; ld a,#$0300
        dc.w $4c00,$0000                   ; bra always,$0000
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
G117S15830:
        dc.w $4c00,G117S15d00/2            ; bra always,$ae80
G117S15834:
        dc.w $08e0,((G117ImgRaster2)>>1)&$ffff ; ld pmc: PM4 reads G117ImgRaster2
        dc.w $08e0,$0800|((G117ImgRaster2)>>17)
        dc.w $000c                   ; ld -,pm4
        dc.w $08e0,$8020             ; ld pmc,#$8020
        dc.w $08e0,$081c             ; ld pmc,#$081c
        dc.w $00c0                   ; ld pm4,-
        dc.w $0810,$03c8             ; ld x,#$03c8
G117S1584c:
        dc.w $e003                   ; eor a,a
        dc.w $003c                   ; ld a,pm4
        dc.w $00c3                   ; ld pm4,a
        dc.w $0031                   ; ld a,x
        dc.w $2800,$0001             ; sub a,#$0001
        dc.w $0013                   ; ld x,a
        dc.w $4c50,G117S1584c/2            ; bra z=0,$ac26
        dc.w $4c00,SVP_Start/2+2           ; bra always,$0412
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
G117S15880:
        dc.w $08e0,((G117ImgGeometry)>>1)&$ffff ; ld pmc: PM4 reads G117ImgGeometry
        dc.w $08e0,$0800|((G117ImgGeometry)>>17)
        dc.w $000c                   ; ld -,pm4
        dc.w $08e0,$8020             ; ld pmc,#$8020
        dc.w $08e0,$081c             ; ld pmc,#$081c
        dc.w $00c0                   ; ld pm4,-
        dc.w $0810,$03c8             ; ld x,#$03c8
        dc.w $4800,G117S01f0e/2            ; call always,$0f87
        dc.w $0032                   ; ld a,y
        dc.w $0e00                   ; ld ($000),a
        dc.w $4c00,SVP_Geometry/2+2        ; bra always,$1df1
G117S158a4:
        dc.w $e003                   ; eor a,a
        dc.w $06f2                   ; ld a,($0f2)
        dc.w $6800,$0002             ; cmp a,#$0002
        dc.w $4d50,G117S15880/2            ; bra z=1,$ac40
        dc.w $0032                   ; ld a,y
        dc.w $0e00                   ; ld ($000),a
        dc.w $4c00,SVP_Geometry/2+2        ; bra always,$1df1
G117S158b8:
        dc.w $0053                   ; ld stack,a
        dc.w $003f                   ; ld a,al
        dc.w $0053                   ; ld stack,a
        dc.w $e003                   ; eor a,a
        dc.w $06f2                   ; ld a,($0f2)
        dc.w $6800,$0002             ; cmp a,#$0002
        dc.w $4d50,G117S158d8/2            ; bra z=1,$ac6c
        dc.w $0035                   ; ld a,stack
        dc.w $00f3                   ; ld al,a
        dc.w $0035                   ; ld a,stack
        dc.w $0606                   ; ld a,($006)
        dc.w $00e3                   ; ld pmc,a
        dc.w $4c00,SVP_GeoVertex/2+2       ; bra always,$215c
G117S158d8:
        dc.w $0035                   ; ld a,stack
        dc.w $00f3                   ; ld al,a
        dc.w $0035                   ; ld a,stack
        dc.w $4c00,$0020                   ; bra always,$0020
G117S158e2:
        dc.w $08e0,((G117ImgBsp)>>1)&$ffff ; ld pmc: PM4 reads G117ImgBsp
        dc.w $08e0,$0800|((G117ImgBsp)>>17)
        dc.w $000c                   ; ld -,pm4
        dc.w $08e0,$8020             ; ld pmc,#$8020
        dc.w $08e0,$081c             ; ld pmc,#$081c
        dc.w $00c0                   ; ld pm4,-
        dc.w $0810,$03c8             ; ld x,#$03c8
        dc.w $4800,G117S01f0e/2            ; call always,$0f87
        dc.w $0032                   ; ld a,y
        dc.w $0e00                   ; ld ($000),a
        dc.w $4c00,SVP_Bsp/2+2             ; bra always,$a1d1
G117S15906:
        dc.w $e003                   ; eor a,a
        dc.w $06f2                   ; ld a,($0f2)
        dc.w $6800,$0003             ; cmp a,#$0003
        dc.w $4d50,G117S158e2/2            ; bra z=1,$ac71
        dc.w $0032                   ; ld a,y
        dc.w $0e00                   ; ld ($000),a
        dc.w $4c00,SVP_Bsp/2+2             ; bra always,$a1d1
G117S1591a:
        dc.w $0053                   ; ld stack,a
        dc.w $003f                   ; ld a,al
        dc.w $0053                   ; ld stack,a
        dc.w $e003                   ; eor a,a
        dc.w $06f2                   ; ld a,($0f2)
        dc.w $6800,$0003             ; cmp a,#$0003
        dc.w $4d50,G117S1593a/2            ; bra z=1,$ac9d
        dc.w $0035                   ; ld a,stack
        dc.w $00f3                   ; ld al,a
        dc.w $0035                   ; ld a,stack
        dc.w $1811                   ; ld r0,#$11
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $4c00,SVP_BspObject/2+2       ; bra always,$a323
G117S1593a:
        dc.w $0035                   ; ld a,stack
        dc.w $00f3                   ; ld al,a
        dc.w $0035                   ; ld a,stack
        dc.w $4c00,$0020                   ; bra always,$0020
G117S15944:
        dc.w $0053                   ; ld stack,a
        dc.w $003f                   ; ld a,al
        dc.w $0053                   ; ld stack,a
        dc.w $e003                   ; eor a,a
        dc.w $06f2                   ; ld a,($0f2)
        dc.w $6800,$0003             ; cmp a,#$0003
        dc.w $4d50,G117S15964/2            ; bra z=1,$acb2
        dc.w $0035                   ; ld a,stack
        dc.w $00f3                   ; ld al,a
        dc.w $0035                   ; ld a,stack
        dc.w $e003                   ; eor a,a
        dc.w $0609                   ; ld a,($009)
        dc.w $4c00,SVP_BspCvt/2+2          ; bra always,$a532
G117S15964:
        dc.w $0035                   ; ld a,stack
        dc.w $00f3                   ; ld al,a
        dc.w $0035                   ; ld a,stack
        dc.w $4c00,$0160                   ; bra always,$0160
G117S1596e:
        dc.w $0053                   ; ld stack,a
        dc.w $003f                   ; ld a,al
        dc.w $0053                   ; ld stack,a
        dc.w $e003                   ; eor a,a
        dc.w $06f2                   ; ld a,($0f2)
        dc.w $6800,$0003             ; cmp a,#$0003
        dc.w $4d50,G117S1598e/2            ; bra z=1,$acc7
        dc.w $0035                   ; ld a,stack
        dc.w $00f3                   ; ld al,a
        dc.w $0035                   ; ld a,stack
        dc.w $0e07                   ; ld ($007),a
        dc.w $8635                   ; add a,($035)
        dc.w $4c00,SVP_BspAdv/2+2          ; bra always,$a54a
G117S1598e:
        dc.w $0035                   ; ld a,stack
        dc.w $00f3                   ; ld al,a
        dc.w $0035                   ; ld a,stack
        dc.w $4c00,$0178                   ; bra always,$0178
G117S15998:
        dc.w $0053                   ; ld stack,a
        dc.w $003f                   ; ld a,al
        dc.w $0053                   ; ld stack,a
        dc.w $e003                   ; eor a,a
        dc.w $06f2                   ; ld a,($0f2)
        dc.w $6800,$0003             ; cmp a,#$0003
        dc.w $4d50,G117S159b8/2            ; bra z=1,$acdc
        dc.w $0035                   ; ld a,stack
        dc.w $00f3                   ; ld al,a
        dc.w $0035                   ; ld a,stack
        dc.w $e003                   ; eor a,a
        dc.w $0637                   ; ld a,($037)
        dc.w $4c00,SVP_BspGroup/2+2        ; bra always,$a5f6
G117S159b8:
        dc.w $0035                   ; ld a,stack
        dc.w $00f3                   ; ld al,a
        dc.w $0035                   ; ld a,stack
        dc.w $4c00,$0189                   ; bra always,$0189
G117S159c2:
        dc.w $0053                   ; ld stack,a
        dc.w $003f                   ; ld a,al
        dc.w $0053                   ; ld stack,a
        dc.w $e003                   ; eor a,a
        dc.w $06f2                   ; ld a,($0f2)
        dc.w $6800,$0003             ; cmp a,#$0003
        dc.w $4d50,G117S159e2/2            ; bra z=1,$acf1
        dc.w $0035                   ; ld a,stack
        dc.w $00f3                   ; ld al,a
        dc.w $0035                   ; ld a,stack
        dc.w $e003                   ; eor a,a
        dc.w $062a                   ; ld a,($02a)
        dc.w $4c00,SVP_BspFaces/2+2        ; bra always,$a628
G117S159e2:
        dc.w $0035                   ; ld a,stack
        dc.w $00f3                   ; ld al,a
        dc.w $0035                   ; ld a,stack
        dc.w $4c00,$01bb                   ; bra always,$01bb
G117S159ec:
        dc.w $0053                   ; ld stack,a
        dc.w $003f                   ; ld a,al
        dc.w $0053                   ; ld stack,a
        dc.w $e003                   ; eor a,a
        dc.w $06f2                   ; ld a,($0f2)
        dc.w $6800,$0003             ; cmp a,#$0003
        dc.w $4d50,G117S15a0c/2            ; bra z=1,$ad06
        dc.w $0035                   ; ld a,stack
        dc.w $00f3                   ; ld al,a
        dc.w $0035                   ; ld a,stack
        dc.w $e003                   ; eor a,a
        dc.w $0e42                   ; ld ($042),a
        dc.w $4c00,SVP_BspColour/2+2       ; bra always,$aa4e
G117S15a0c:
        dc.w $0035                   ; ld a,stack
        dc.w $00f3                   ; ld al,a
        dc.w $0035                   ; ld a,stack
        dc.w $4c00,$0352                   ; bra always,$0352
G117RadioPackedLUT:
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0001                   ; ld -,x
        dc.w $0010                   ; ld x,-
        dc.w $0011                   ; ld x,x
        dc.w $0100                   ; ld -,-
        dc.w $0101                   ; ld -,x
        dc.w $0110                   ; ld x,-
        dc.w $0111                   ; ld x,x
        dc.w $1000                   ; ?1000
        dc.w $1001                   ; ?1001
        dc.w $1010                   ; ?1010
        dc.w $1011                   ; ?1011
        dc.w $1100                   ; ?1100
        dc.w $1101                   ; ?1101
        dc.w $1110                   ; ?1110
        dc.w $1111                   ; ?1111
        dc.w $0000                   ; nop
        dc.w $0002                   ; ld -,y
        dc.w $0020                   ; ld y,-
        dc.w $0022                   ; ld y,y
        dc.w $0200                   ; ld -,(r0)
        dc.w $0202                   ; ld -,(r2)
        dc.w $0220                   ; ld y,(r0)
        dc.w $0222                   ; ld y,(r2)
        dc.w $2000                   ; sub a,-
        dc.w $2002                   ; sub a,y
        dc.w $2020                   ; sub a,-
        dc.w $2022                   ; sub a,y
        dc.w $2200                   ; sub a,(r0)
        dc.w $2202                   ; sub a,(r2)
        dc.w $2220                   ; sub a,(r0)
        dc.w $2222                   ; sub a,(r2)
        dc.w $0000                   ; nop
        dc.w $0003                   ; ld -,a
        dc.w $0030                   ; ld a,-
        dc.w $0033                   ; ld a,a
        dc.w $0300                   ; ld -,(r4)
        dc.w $0303                   ; ld -,(r7)
        dc.w $0330                   ; ld a,(r4)
        dc.w $0333                   ; ld a,(r7)
        dc.w $3000                   ; ?3000
        dc.w $3003                   ; ?3003
        dc.w $3030                   ; ?3030
        dc.w $3033                   ; ?3033
        dc.w $3300                   ; sub a,r4
        dc.w $3303                   ; sub a,r7
        dc.w $3330                   ; sub a,r4
        dc.w $3333                   ; sub a,r7
        dc.w $0000                   ; nop
        dc.w $0004                   ; ld -,st
        dc.w $0040                   ; ld st,-
        dc.w $0044                   ; ld st,st
        dc.w $0400                   ; ld (r0),-
        dc.w $0404                   ; ld (r0+!),-
        dc.w $0440                   ; ld (r0),st
        dc.w $0444                   ; ld (r0+!),st
        dc.w $4000                   ; ?4000
        dc.w $4004                   ; ?4004
        dc.w $4040                   ; ?4040
        dc.w $4044                   ; ?4044
        dc.w $4400                   ; ?4400
        dc.w $4404                   ; ?4404
        dc.w $4440                   ; ?4440
        dc.w $4444                   ; ?4444
        dc.w $0000                   ; nop
        dc.w $0005                   ; ld -,stack
        dc.w $0050                   ; ld stack,-
        dc.w $0055                   ; ld stack,stack
        dc.w $0500                   ; ld (r4),-
        dc.w $0505                   ; ld (r5+!),-
        dc.w $0550                   ; ld (r4),stack
        dc.w $0555                   ; ld (r5+!),stack
        dc.w $5000                   ; ?5000
        dc.w $5005                   ; ?5005
        dc.w $5050                   ; ?5050
        dc.w $5055                   ; ?5055
        dc.w $5500                   ; ?5500
        dc.w $5505                   ; ?5505
        dc.w $5550                   ; ?5550
        dc.w $5555                   ; ?5555
        dc.w $0000                   ; nop
        dc.w $0006                   ; ld -,pc
        dc.w $0060                   ; ld pc,-
        dc.w $0066                   ; ld pc,pc
        dc.w $0600                   ; ld a,($000)
        dc.w $0606                   ; ld a,($006)
        dc.w $0660                   ; ld a,($060)
        dc.w $0666                   ; ld a,($066)
        dc.w $6000                   ; cmp a,-
        dc.w $6006                   ; cmp a,pc
        dc.w $6060                   ; cmp a,-
        dc.w $6066                   ; cmp a,pc
        dc.w $6600                   ; cmp a,($000)
        dc.w $6606                   ; cmp a,($006)
        dc.w $6660                   ; cmp a,($060)
        dc.w $6666                   ; cmp a,($066)
        dc.w $0000                   ; nop
        dc.w $0007                   ; ld -,p
        dc.w $0070                   ; ld p,-
        dc.w $0077                   ; ld p,p
        dc.w $0700                   ; ld a,($100)
        dc.w $0707                   ; ld a,($107)
        dc.w $0770                   ; ld a,($170)
        dc.w $0777                   ; ld a,($177)
        dc.w $7000                   ; ?7000
        dc.w $7007                   ; ?7007
        dc.w $7070                   ; ?7070
        dc.w $7077                   ; ?7077
        dc.w $7700                   ; ?7700
        dc.w $7707                   ; ?7707
        dc.w $7770                   ; ?7770
        dc.w $7777                   ; ?7777
        dc.w $0000                   ; nop
        dc.w $0008                   ; ld -,pm0
        dc.w $0080                   ; ld pm0,-
        dc.w $0088                   ; ld pm0,pm0
        dc.w $0800,$0808             ; ld -,#$0808
        dc.w $0880,$0888             ; ld pm0,#$0888
        dc.w $8000                   ; add a,-
        dc.w $8008                   ; add a,pm0
        dc.w $8080                   ; add a,-
        dc.w $8088                   ; add a,pm0
        dc.w $8800,$8808             ; add a,#$8808
        dc.w $8880,$8888             ; add a,#$8888
        dc.w $0000                   ; nop
        dc.w $0009                   ; ld -,pm1
        dc.w $0090                   ; ld pm1,-
        dc.w $0099                   ; ld pm1,pm1
        dc.w $0900,$0909             ; ld -,#$0909
        dc.w $0990,$0999             ; ld pm1,#$0999
        dc.w $9000                   ; mod0 cond$000
        dc.w $9009                   ; mod1 cond$000
        dc.w $9090                   ; mod0 cond$090
        dc.w $9099                   ; mod1 cond$090
        dc.w $9900                   ; addi a,#$00
        dc.w $9909                   ; addi a,#$09
        dc.w $9990                   ; addi a,#$90
        dc.w $9999                   ; addi a,#$99
        dc.w $0000                   ; nop
        dc.w $000a                   ; ld -,pm2
        dc.w $00a0                   ; ld pm2,-
        dc.w $00aa                   ; ld pm2,pm2
        dc.w $0a00                   ; ld -,(((r0)))
        dc.w $0a0a                   ; ld -,(((r2-)))
        dc.w $0aa0                   ; ld pm2,(((r0)))
        dc.w $0aaa                   ; ld pm2,(((r2-)))
        dc.w $a000                   ; and a,-
        dc.w $a00a                   ; and a,pm2
        dc.w $a0a0                   ; and a,-
        dc.w $a0aa                   ; and a,pm2
        dc.w $aa00                   ; and a,(((r0)))
        dc.w $aa0a                   ; and a,(((r2-)))
        dc.w $aaa0                   ; and a,(((r0)))
        dc.w $aaaa                   ; and a,(((r2-)))
        dc.w $0000                   ; nop
        dc.w $000b                   ; ld -,xst
        dc.w $00b0                   ; ld xst,-
        dc.w $00bb                   ; ld xst,xst
        dc.w $0b00                   ; ld -,(((r4)))
        dc.w $0b0b                   ; ld -,(((!)))
        dc.w $0bb0                   ; ld xst,(((r4)))
        dc.w $0bbb                   ; ld xst,(((!)))
        dc.w $b000                   ; ?b000
        dc.w $b00b                   ; ?b00b
        dc.w $b0b0                   ; ?b0b0
        dc.w $b0bb                   ; ?b0bb
        dc.w $bb00                   ; ?bb00
        dc.w $bb0b                   ; ?bb0b
        dc.w $bbb0                   ; ?bbb0
        dc.w $bbbb                   ; ?bbbb
        dc.w $0000                   ; nop
        dc.w $000c                   ; ld -,pm4
        dc.w $00c0                   ; ld pm4,-
        dc.w $00cc                   ; ld pm4,pm4
        dc.w $0c00,$0c0c             ; ld (r0),#$0c0c
        dc.w $0cc0,$0ccc             ; ld (r0),#$0ccc
        dc.w $c000                   ; or a,-
        dc.w $c00c                   ; or a,pm4
        dc.w $c0c0                   ; or a,-
        dc.w $c0cc                   ; or a,pm4
        dc.w $cc00                   ; ?cc00
        dc.w $cc0c                   ; ?cc0c
        dc.w $ccc0                   ; ?ccc0
        dc.w $cccc                   ; ?cccc
        dc.w $0000                   ; nop
        dc.w $000d                   ; ld -,ext5
        dc.w $00d0                   ; ld ext5,-
        dc.w $00dd                   ; ld ext5,ext5
        dc.w $0d00,$0d0d             ; ld (r4),#$0d0d
        dc.w $0dd0,$0ddd             ; ld (r4),#$0ddd
        dc.w $d000                   ; ?d000
        dc.w $d00d                   ; ?d00d
        dc.w $d0d0                   ; ?d0d0
        dc.w $d0dd                   ; ?d0dd
        dc.w $dd00                   ; ?dd00
        dc.w $dd0d                   ; ?dd0d
        dc.w $ddd0                   ; ?ddd0
        dc.w $dddd                   ; ?dddd
        dc.w $0000                   ; nop
        dc.w $000e                   ; ld -,pmc
        dc.w $00e0                   ; ld pmc,-
        dc.w $00ee                   ; ld pmc,pmc
        dc.w $0e00                   ; ld ($000),a
        dc.w $0e0e                   ; ld ($00e),a
        dc.w $0ee0                   ; ld ($0e0),a
        dc.w $0eee                   ; ld ($0ee),a
        dc.w $e000                   ; eor a,-
        dc.w $e00e                   ; eor a,pmc
        dc.w $e0e0                   ; eor a,-
        dc.w $e0ee                   ; eor a,pmc
        dc.w $ee00                   ; ?ee00
        dc.w $ee0e                   ; ?ee0e
        dc.w $eee0                   ; ?eee0
        dc.w $eeee                   ; ?eeee
        dc.w $0000                   ; nop
        dc.w $000f                   ; ld -,al
        dc.w $00f0                   ; ld al,-
        dc.w $00ff                   ; ld al,al
        dc.w $0f00                   ; ld ($100),a
        dc.w $0f0f                   ; ld ($10f),a
        dc.w $0ff0                   ; ld ($1f0),a
        dc.w $0fff                   ; ld ($1ff),a
        dc.w $f000                   ; ?f000
        dc.w $f00f                   ; ?f00f
        dc.w $f0f0                   ; ?f0f0
        dc.w $f0ff                   ; ?f0ff
        dc.w $ff00                   ; ?ff00
        dc.w $ff0f                   ; ?ff0f
        dc.w $fff0                   ; ?fff0
        dc.w $ffff                   ; ?ffff
G117RadioWidthMasks:
        dc.w $0000                   ; nop
        dc.w $8000                   ; add a,-
        dc.w $c000                   ; or a,-
        dc.w $e000                   ; eor a,-
        dc.w $f000                   ; ?f000
        dc.w $f800                   ; eori a,#$00
        dc.w $fc00                   ; ?fc00
        dc.w $fe00                   ; ?fe00
        dc.w $ff00                   ; ?ff00
        dc.w $ff80                   ; ?ff80
        dc.w $ffc0                   ; ?ffc0
        dc.w $ffe0                   ; ?ffe0
        dc.w $fff0                   ; ?fff0
        dc.w $fff8                   ; ?fff8
        dc.w $fffc                   ; ?fffc
        dc.w $fffe                   ; ?fffe
        dc.w $ffff                   ; ?ffff
G117RadioLutEnd:
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
G117S15c40:
        dc.w $e003                   ; eor a,a
        dc.w $0666                   ; ld a,($066)
        dc.w $7800                   ; cmpi a,#$00
        dc.w $4c50,G117S15c98/2            ; bra z=0,$ae4c
        dc.w $e003                   ; eor a,a
        dc.w $0668                   ; ld a,($068)
        dc.w $7800                   ; cmpi a,#$00
        dc.w $4c50,G117S15c98/2            ; bra z=0,$ae4c
        dc.w $e003                   ; eor a,a
        dc.w $0667                   ; ld a,($067)
        dc.w $7800                   ; cmpi a,#$00
        dc.w $4d50,G117S15c64/2            ; bra z=1,$ae32
        dc.w $7880                   ; cmpi a,#$80
        dc.w $4c50,G117S15c98/2            ; bra z=0,$ae4c
G117S15c64:
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0e00             ; ld a,#$0e00
        dc.w $0e7c                   ; ld ($07c),a
        dc.w $e003                   ; eor a,a
        dc.w $06f2                   ; ld a,($0f2)
        dc.w $7802                   ; cmpi a,#$02
        dc.w $4c50,G117S15c7e/2            ; bra z=0,$ae3f
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0e48             ; ld a,#$0e48
        dc.w $0e7c                   ; ld ($07c),a
G117S15c7e:
        dc.w $e003                   ; eor a,a
        dc.w $067c                   ; ld a,($07c)
        dc.w $00e3                   ; ld pmc,a
        dc.w $08e0,$0818             ; ld pmc,#$0818
        dc.w $000c                   ; ld -,pm4
        dc.w $e003                   ; eor a,a
        dc.w $003c                   ; ld a,pm4
        dc.w $7800                   ; cmpi a,#$00
        dc.w $4d50,G117S15c98/2            ; bra z=1,$ae4c
        dc.w $4c00,SVP_GeoViewLive/2       ; bra always,$1f67
G117S15c98:
        dc.w $e003                   ; eor a,a
        dc.w $0666                   ; ld a,($066)
        dc.w $4c00,SVP_GeoModelReady/2+2   ; bra always,$1e99
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
G117S15cd0:
        dc.w $e003                   ; eor a,a
        dc.w $06f2                   ; ld a,($0f2)
        dc.w $7802                   ; cmpi a,#$02
        dc.w $4d50,$0373                   ; bra z=1,$0373
        dc.w $e003                   ; eor a,a
        dc.w $0620                   ; ld a,($020)
        dc.w $4c00,SVP_GeoViewCompose/2+2  ; bra always,$2003
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
G117S15d00:
        dc.w $0840,$0000             ; ld st,#$0000
        dc.w $08e0,$83e9             ; ld pmc,#$83e9
        dc.w $08e0,$081c             ; ld pmc,#$081c
        dc.w $00c0                   ; ld pm4,-
        dc.w $e003                   ; eor a,a
        dc.w $0830,$e003             ; ld a,#$e003
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$003c             ; ld a,#$003c
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$00c3             ; ld a,#$00c3
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$003c             ; ld a,#$003c
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$00c3             ; ld a,#$00c3
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$003c             ; ld a,#$003c
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$00c3             ; ld a,#$00c3
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$003c             ; ld a,#$003c
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$00c3             ; ld a,#$00c3
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$003c             ; ld a,#$003c
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$00c3             ; ld a,#$00c3
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$003c             ; ld a,#$003c
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$00c3             ; ld a,#$00c3
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$4c00             ; ld a,#$4c00
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$0016             ; ld a,#$0016
        dc.w $00c3                   ; ld pm4,a
        dc.w $08e0,$8016             ; ld pmc,#$8016
        dc.w $08e0,$081c             ; ld pmc,#$081c
        dc.w $00c0                   ; ld pm4,-
        dc.w $e003                   ; eor a,a
        dc.w $0830,$003c             ; ld a,#$003c
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$00c3             ; ld a,#$00c3
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$003c             ; ld a,#$003c
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$00c3             ; ld a,#$00c3
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$0031             ; ld a,#$0031
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$3808             ; ld a,#$3808
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$0013             ; ld a,#$0013
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$4c50             ; ld a,#$4c50
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$03ea             ; ld a,#$03ea
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$0065             ; ld a,#$0065
        dc.w $00c3                   ; ld pm4,a
        dc.w $4c00,G117S15834/2            ; bra always,$ac1a
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
G117S15dc0:
        dc.w $08e0,$0e47             ; ld pmc,#$0e47
        dc.w $08e0,$0018             ; ld pmc,#$0018
        dc.w $000c                   ; ld -,pm4
        dc.w $e003                   ; eor a,a
        dc.w $003c                   ; ld a,pm4
        dc.w $6800,$4552             ; cmp a,#$4552
        dc.w $4c50,G117S15e68/2            ; bra z=0,$af34
        dc.w $08e0,$8000             ; ld pmc,#$8000
        dc.w $08e0,$081c             ; ld pmc,#$081c
        dc.w $00c0                   ; ld pm4,-
        dc.w $e003                   ; eor a,a
        dc.w $0830,$e003             ; ld a,#$e003
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$003c             ; ld a,#$003c
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$6800             ; ld a,#$6800
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$5254             ; ld a,#$5254
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$4d50             ; ld a,#$4d50
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$0010             ; ld a,#$0010
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$6800             ; ld a,#$6800
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$ffff             ; ld a,#$ffff
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$4c50             ; ld a,#$4c50
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$0000             ; ld a,#$0000
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$e003             ; ld a,#$e003
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$0830             ; ld a,#$0830
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$ffff             ; ld a,#$ffff
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$0ef3             ; ld a,#$0ef3
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$4c00             ; ld a,#$4c00
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,SVP_ChainFail/2         ; ld a,#$ab84 (IRAM code word: branch target)
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$0830             ; ld a,#$0830
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$0002             ; ld a,#$0002
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,$4c00             ; ld a,#$4c00
        dc.w $00c3                   ; ld pm4,a
        dc.w $0830,SVP_ChainGeometry/2+2   ; ld a,#$ab3e (IRAM code word: branch target)
        dc.w $00c3                   ; ld pm4,a
        dc.w $08e0,$0e46             ; ld pmc,#$0e46
        dc.w $08e0,$0018             ; ld pmc,#$0018
        dc.w $000c                   ; ld -,pm4
        dc.w $4c00,$0000                   ; bra always,$0000
G117S15e68:
        dc.w $0830,$0002             ; ld a,#$0002
        dc.w $4c00,SVP_ChainGeometry/2+2   ; bra always,$ab3e
G117SvpTail:

        org SVP_Start
G117Ovr0:
        dc.w $4c00,G117S15830/2            ; bra always,$ac18
G117Ovr0End:
        if *<>SVP_Start+$4
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_IntroClearTile
G117Ovr1:
        dc.w $4c00,G117S15780/2            ; bra always,$abc0
G117Ovr1End:
        if *<>SVP_IntroClearTile+$4
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_IntroPrimitive
G117Ovr2:
        dc.w $4c00,$0347                   ; bra always,$0347
G117Ovr2End:
        if *<>SVP_IntroPrimitive+$4
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_IntroTriangle
G117Ovr3:
        dc.w $4c00,$0020                   ; bra always,$0020
G117S017ee:
        dc.w $e003                   ; eor a,a
        dc.w $0664                   ; ld a,($064)
        dc.w $6800,$0000             ; cmp a,#$0000
        dc.w $4d50,$00ce                   ; bra z=1,$00ce
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0000             ; ld a,#$0000
        dc.w $0e4c                   ; ld ($04c),a
        dc.w $e003                   ; eor a,a
        dc.w $0662                   ; ld a,($062)
        dc.w $0e07                   ; ld ($007),a
        dc.w $e003                   ; eor a,a
        dc.w $0607                   ; ld a,($007)
        dc.w $00e3                   ; ld pmc,a
        dc.w $08e0,$0818             ; ld pmc,#$0818
        dc.w $000c                   ; ld -,pm4
        dc.w $e003                   ; eor a,a
        dc.w $003c                   ; ld a,pm4
        dc.w $0e20                   ; ld ($020),a
        dc.w $e003                   ; eor a,a
        dc.w $003c                   ; ld a,pm4
        dc.w $0e21                   ; ld ($021),a
        dc.w $e003                   ; eor a,a
        dc.w $003c                   ; ld a,pm4
        dc.w $0e22                   ; ld ($022),a
        dc.w $e003                   ; eor a,a
        dc.w $003c                   ; ld a,pm4
        dc.w $0e23                   ; ld ($023),a
        dc.w $e003                   ; eor a,a
        dc.w $003c                   ; ld a,pm4
        dc.w $0e24                   ; ld ($024),a
        dc.w $e003                   ; eor a,a
        dc.w $003c                   ; ld a,pm4
        dc.w $0e25                   ; ld ($025),a
        dc.w $e003                   ; eor a,a
        dc.w $003c                   ; ld a,pm4
        dc.w $0e26                   ; ld ($026),a
        dc.w $e003                   ; eor a,a
        dc.w $003c                   ; ld a,pm4
        dc.w $0e27                   ; ld ($027),a
        dc.w $e003                   ; eor a,a
        dc.w $003c                   ; ld a,pm4
        dc.w $0e28                   ; ld ($028),a
        dc.w $e003                   ; eor a,a
        dc.w $0665                   ; ld a,($065)
        dc.w $9006                   ; mod6 cond$000
        dc.w $0e70                   ; ld ($070),a
        dc.w $e003                   ; eor a,a
        dc.w $0666                   ; ld a,($066)
        dc.w $0e71                   ; ld ($071),a
        dc.w $e003                   ; eor a,a
        dc.w $0667                   ; ld a,($067)
        dc.w $9006                   ; mod6 cond$000
        dc.w $0e72                   ; ld ($072),a
        dc.w $e003                   ; eor a,a
        dc.w $0670                   ; ld a,($070)
        dc.w $0013                   ; ld x,a
        dc.w $e003                   ; eor a,a
        dc.w $0620                   ; ld a,($020)
        dc.w $0023                   ; ld y,a
        dc.w $0037                   ; ld a,p
        dc.w $0e52                   ; ld ($052),a
        dc.w $003f                   ; ld a,al
        dc.w $0e53                   ; ld ($053),a
        dc.w $e003                   ; eor a,a
        dc.w $0671                   ; ld a,($071)
        dc.w $0013                   ; ld x,a
        dc.w $e003                   ; eor a,a
        dc.w $0623                   ; ld a,($023)
        dc.w $0023                   ; ld y,a
        dc.w $e003                   ; eor a,a
        dc.w $0653                   ; ld a,($053)
        dc.w $00f3                   ; ld al,a
        dc.w $0652                   ; ld a,($052)
        dc.w $8007                   ; add a,p
        dc.w $0e52                   ; ld ($052),a
        dc.w $003f                   ; ld a,al
        dc.w $0e53                   ; ld ($053),a
        dc.w $e003                   ; eor a,a
        dc.w $0672                   ; ld a,($072)
        dc.w $0013                   ; ld x,a
        dc.w $e003                   ; eor a,a
        dc.w $0626                   ; ld a,($026)
        dc.w $0023                   ; ld y,a
        dc.w $e003                   ; eor a,a
        dc.w $0653                   ; ld a,($053)
        dc.w $00f3                   ; ld al,a
        dc.w $0652                   ; ld a,($052)
        dc.w $8007                   ; add a,p
        dc.w $0e52                   ; ld ($052),a
        dc.w $003f                   ; ld a,al
        dc.w $0e53                   ; ld ($053),a
        dc.w $e003                   ; eor a,a
        dc.w $0652                   ; ld a,($052)
        dc.w $0013                   ; ld x,a
        dc.w $e003                   ; eor a,a
        dc.w $0664                   ; ld a,($064)
        dc.w $0023                   ; ld y,a
        dc.w $0037                   ; ld a,p
        dc.w $9002                   ; mod2 cond$000
        dc.w $9002                   ; mod2 cond$000
        dc.w $9002                   ; mod2 cond$000
        dc.w $003f                   ; ld a,al
        dc.w $0e47                   ; ld ($047),a
        dc.w $e003                   ; eor a,a
        dc.w $0670                   ; ld a,($070)
        dc.w $0013                   ; ld x,a
        dc.w $e003                   ; eor a,a
        dc.w $0621                   ; ld a,($021)
        dc.w $0023                   ; ld y,a
        dc.w $0037                   ; ld a,p
        dc.w $0e52                   ; ld ($052),a
        dc.w $003f                   ; ld a,al
        dc.w $0e53                   ; ld ($053),a
        dc.w $e003                   ; eor a,a
        dc.w $0671                   ; ld a,($071)
        dc.w $0013                   ; ld x,a
        dc.w $e003                   ; eor a,a
        dc.w $0624                   ; ld a,($024)
        dc.w $0023                   ; ld y,a
        dc.w $e003                   ; eor a,a
        dc.w $0653                   ; ld a,($053)
        dc.w $00f3                   ; ld al,a
        dc.w $0652                   ; ld a,($052)
        dc.w $8007                   ; add a,p
        dc.w $0e52                   ; ld ($052),a
        dc.w $003f                   ; ld a,al
        dc.w $0e53                   ; ld ($053),a
        dc.w $e003                   ; eor a,a
        dc.w $0672                   ; ld a,($072)
        dc.w $0013                   ; ld x,a
        dc.w $e003                   ; eor a,a
        dc.w $0627                   ; ld a,($027)
        dc.w $0023                   ; ld y,a
        dc.w $e003                   ; eor a,a
        dc.w $0653                   ; ld a,($053)
        dc.w $00f3                   ; ld al,a
        dc.w $0652                   ; ld a,($052)
        dc.w $8007                   ; add a,p
        dc.w $0e52                   ; ld ($052),a
        dc.w $003f                   ; ld a,al
        dc.w $0e53                   ; ld ($053),a
        dc.w $e003                   ; eor a,a
        dc.w $0652                   ; ld a,($052)
        dc.w $6800,$0000             ; cmp a,#$0000
        dc.w $4d70,G117S0191e/2            ; bra n=1,$0c8f
        dc.w $9006                   ; mod6 cond$000
G117S0191e:
        dc.w $0013                   ; ld x,a
        dc.w $e003                   ; eor a,a
        dc.w $0664                   ; ld a,($064)
        dc.w $0023                   ; ld y,a
        dc.w $0037                   ; ld a,p
        dc.w $9002                   ; mod2 cond$000
        dc.w $9002                   ; mod2 cond$000
        dc.w $9002                   ; mod2 cond$000
        dc.w $003f                   ; ld a,al
        dc.w $0e48                   ; ld ($048),a
        dc.w $e003                   ; eor a,a
        dc.w $0670                   ; ld a,($070)
        dc.w $0013                   ; ld x,a
        dc.w $e003                   ; eor a,a
        dc.w $0622                   ; ld a,($022)
        dc.w $0023                   ; ld y,a
        dc.w $0037                   ; ld a,p
        dc.w $0e52                   ; ld ($052),a
        dc.w $003f                   ; ld a,al
        dc.w $0e53                   ; ld ($053),a
        dc.w $e003                   ; eor a,a
        dc.w $0671                   ; ld a,($071)
        dc.w $0013                   ; ld x,a
        dc.w $e003                   ; eor a,a
        dc.w $0625                   ; ld a,($025)
        dc.w $0023                   ; ld y,a
        dc.w $e003                   ; eor a,a
        dc.w $0653                   ; ld a,($053)
        dc.w $00f3                   ; ld al,a
        dc.w $0652                   ; ld a,($052)
        dc.w $8007                   ; add a,p
        dc.w $0e52                   ; ld ($052),a
        dc.w $003f                   ; ld a,al
        dc.w $0e53                   ; ld ($053),a
        dc.w $e003                   ; eor a,a
        dc.w $0672                   ; ld a,($072)
        dc.w $0013                   ; ld x,a
        dc.w $e003                   ; eor a,a
        dc.w $0628                   ; ld a,($028)
        dc.w $0023                   ; ld y,a
        dc.w $e003                   ; eor a,a
        dc.w $0653                   ; ld a,($053)
        dc.w $00f3                   ; ld al,a
        dc.w $0652                   ; ld a,($052)
        dc.w $8007                   ; add a,p
        dc.w $0e52                   ; ld ($052),a
        dc.w $003f                   ; ld a,al
        dc.w $0e53                   ; ld ($053),a
        dc.w $e003                   ; eor a,a
        dc.w $0652                   ; ld a,($052)
        dc.w $0013                   ; ld x,a
        dc.w $e003                   ; eor a,a
        dc.w $0664                   ; ld a,($064)
        dc.w $0023                   ; ld y,a
        dc.w $0037                   ; ld a,p
        dc.w $9002                   ; mod2 cond$000
        dc.w $9002                   ; mod2 cond$000
        dc.w $9002                   ; mod2 cond$000
        dc.w $003f                   ; ld a,al
        dc.w $0e49                   ; ld ($049),a
        dc.w $4c00,$00ce                   ; bra always,$00ce
        dc.w $e003                   ; eor a,a
        dc.w $064d                   ; ld a,($04d)
        dc.w $8800,$0068             ; add a,#$0068
        dc.w $1430                   ; ld r0,a
        dc.w $e003                   ; eor a,a
        dc.w $0230                   ; ld a,(r0)
        dc.w $8800,SVP_GeoIndexOffsets/2   ; add a,#$2f15 (table base)
        dc.w $4a10                   ; ld x,((a))
        dc.w $e003                   ; eor a,a
        dc.w $0031                   ; ld a,x
        dc.w $8662                   ; add a,($062)
        dc.w $8800,$0010             ; add a,#$0010
        dc.w $0e07                   ; ld ($007),a
        dc.w $e003                   ; eor a,a
        dc.w $0607                   ; ld a,($007)
        dc.w $00e3                   ; ld pmc,a
        dc.w $08e0,$0818             ; ld pmc,#$0818
        dc.w $000c                   ; ld -,pm4
        dc.w $e003                   ; eor a,a
        dc.w $003c                   ; ld a,pm4
        dc.w $8647                   ; add a,($047)
        dc.w $0e70                   ; ld ($070),a
        dc.w $e003                   ; eor a,a
        dc.w $064e                   ; ld a,($04e)
        dc.w $8800,$0000             ; add a,#$0000
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0670                   ; ld a,($070)
        dc.w $0530                   ; ld (r4),a
        dc.w $e003                   ; eor a,a
        dc.w $003c                   ; ld a,pm4
        dc.w $8648                   ; add a,($048)
        dc.w $0e71                   ; ld ($071),a
        dc.w $e003                   ; eor a,a
        dc.w $064e                   ; ld a,($04e)
        dc.w $8800,$0001             ; add a,#$0001
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0671                   ; ld a,($071)
        dc.w $0530                   ; ld (r4),a
        dc.w $e003                   ; eor a,a
        dc.w $003c                   ; ld a,pm4
        dc.w $8649                   ; add a,($049)
        dc.w $0e72                   ; ld ($072),a
        dc.w $e003                   ; eor a,a
        dc.w $064e                   ; ld a,($04e)
        dc.w $8800,$0002             ; add a,#$0002
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0672                   ; ld a,($072)
        dc.w $0530                   ; ld (r4),a
        dc.w $e003                   ; eor a,a
        dc.w $0672                   ; ld a,($072)
        dc.w $6800,$0020             ; cmp a,#$0020
        dc.w $4d70,G117S01a1e/2            ; bra n=1,$0d0f
        dc.w $4c00,G117S01a26/2            ; bra always,$0d13
G117S01a1e:
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0000             ; ld a,#$0000
        dc.w $0e4a                   ; ld ($04a),a
G117S01a26:
        dc.w $e003                   ; eor a,a
        dc.w $003c                   ; ld a,pm4
        dc.w $0e70                   ; ld ($070),a
        dc.w $e003                   ; eor a,a
        dc.w $064f                   ; ld a,($04f)
        dc.w $8800,$0000             ; add a,#$0000
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0670                   ; ld a,($070)
        dc.w $0530                   ; ld (r4),a
        dc.w $e003                   ; eor a,a
        dc.w $003c                   ; ld a,pm4
        dc.w $0e71                   ; ld ($071),a
        dc.w $e003                   ; eor a,a
        dc.w $064f                   ; ld a,($04f)
        dc.w $8800,$0001             ; add a,#$0001
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0671                   ; ld a,($071)
        dc.w $0530                   ; ld (r4),a
        dc.w $e003                   ; eor a,a
        dc.w $064f                   ; ld a,($04f)
        dc.w $8800,$0002             ; add a,#$0002
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0672                   ; ld a,($072)
        dc.w $0530                   ; ld (r4),a
        dc.w $e003                   ; eor a,a
        dc.w $064e                   ; ld a,($04e)
        dc.w $8800,$0003             ; add a,#$0003
        dc.w $0e4e                   ; ld ($04e),a
        dc.w $e003                   ; eor a,a
        dc.w $064f                   ; ld a,($04f)
        dc.w $8800,$0003             ; add a,#$0003
        dc.w $0e4f                   ; ld ($04f),a
        dc.w $e003                   ; eor a,a
        dc.w $064d                   ; ld a,($04d)
        dc.w $8800,$0001             ; add a,#$0001
        dc.w $0e4d                   ; ld ($04d),a
        dc.w $e003                   ; eor a,a
        dc.w $064d                   ; ld a,($04d)
        dc.w $2608                   ; sub a,($008)
        dc.w $4c50,SVP_TriNeg9/2           ; bra z=0,$0ccd
        dc.w $e003                   ; eor a,a
        dc.w $064a                   ; ld a,($04a)
        dc.w $a64c                   ; and a,($04c)
        dc.w $4d50,G117S01b30/2            ; bra z=1,$0d98
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0090             ; ld a,#$0090
        dc.w $0e4f                   ; ld ($04f),a
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0000             ; ld a,#$0000
        dc.w $0e4e                   ; ld ($04e),a
        dc.w $e003                   ; eor a,a
        dc.w $0608                   ; ld a,($008)
        dc.w $0e4d                   ; ld ($04d),a
G117S01aaa:
        dc.w $e003                   ; eor a,a
        dc.w $064f                   ; ld a,($04f)
        dc.w $8800,$0000             ; add a,#$0000
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0330                   ; ld a,(r4)
        dc.w $0e70                   ; ld ($070),a
        dc.w $e003                   ; eor a,a
        dc.w $064e                   ; ld a,($04e)
        dc.w $8800,$0000             ; add a,#$0000
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0670                   ; ld a,($070)
        dc.w $0530                   ; ld (r4),a
        dc.w $e003                   ; eor a,a
        dc.w $064f                   ; ld a,($04f)
        dc.w $8800,$0001             ; add a,#$0001
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0330                   ; ld a,(r4)
        dc.w $0e70                   ; ld ($070),a
        dc.w $e003                   ; eor a,a
        dc.w $064e                   ; ld a,($04e)
        dc.w $8800,$0001             ; add a,#$0001
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0670                   ; ld a,($070)
        dc.w $0530                   ; ld (r4),a
        dc.w $e003                   ; eor a,a
        dc.w $064f                   ; ld a,($04f)
        dc.w $8800,$0002             ; add a,#$0002
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0330                   ; ld a,(r4)
        dc.w $0e70                   ; ld ($070),a
        dc.w $e003                   ; eor a,a
        dc.w $064e                   ; ld a,($04e)
        dc.w $8800,$0002             ; add a,#$0002
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0670                   ; ld a,($070)
        dc.w $0530                   ; ld (r4),a
        dc.w $e003                   ; eor a,a
        dc.w $064f                   ; ld a,($04f)
        dc.w $8800,$0003             ; add a,#$0003
        dc.w $0e4f                   ; ld ($04f),a
        dc.w $e003                   ; eor a,a
        dc.w $064e                   ; ld a,($04e)
        dc.w $8800,$0003             ; add a,#$0003
        dc.w $0e4e                   ; ld ($04e),a
        dc.w $e003                   ; eor a,a
        dc.w $064d                   ; ld a,($04d)
        dc.w $2800,$0001             ; sub a,#$0001
        dc.w $0e4d                   ; ld ($04d),a
        dc.w $4c50,G117S01aaa/2            ; bra z=0,$0d55
        dc.w $4c00,$0123                   ; bra always,$0123
G117S01b30:
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0002             ; ld a,#$0002
        dc.w $0e0b                   ; ld ($00b),a
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0020             ; ld a,#$0020
        dc.w $0e0c                   ; ld ($00c),a
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0001             ; ld a,#$0001
        dc.w $0e0d                   ; ld ($00d),a
        dc.w $4800,SVP_FaceNearClip/2          ; call always,$2df9
        dc.w $e003                   ; eor a,a
        dc.w $0608                   ; ld a,($008)
        dc.w $6800,$0000             ; cmp a,#$0000
        dc.w $4d50,$02ca                   ; bra z=1,$02ca
        dc.w $e003                   ; eor a,a
        dc.w $060e                   ; ld a,($00e)
        dc.w $0e4e                   ; ld ($04e),a
        dc.w $e003                   ; eor a,a
        dc.w $0608                   ; ld a,($008)
        dc.w $0e4d                   ; ld ($04d),a
G117S01b64:
        dc.w $e003                   ; eor a,a
        dc.w $064e                   ; ld a,($04e)
        dc.w $8800,$0002             ; add a,#$0002
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0330                   ; ld a,(r4)
        dc.w $0e32                   ; ld ($032),a
        dc.w $e003                   ; eor a,a
        dc.w $064e                   ; ld a,($04e)
        dc.w $8800,$0000             ; add a,#$0000
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0330                   ; ld a,(r4)
        dc.w $0e38                   ; ld ($038),a
        dc.w $4800,SVP_GeoProject/2        ; call always,$257d
        dc.w $8800,$0080             ; add a,#$0080
        dc.w $87f0                   ; add a,($1f0)
        dc.w $0e70                   ; ld ($070),a
        dc.w $e003                   ; eor a,a
        dc.w $064e                   ; ld a,($04e)
        dc.w $8800,$0000             ; add a,#$0000
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0670                   ; ld a,($070)
        dc.w $0530                   ; ld (r4),a
        dc.w $e003                   ; eor a,a
        dc.w $064e                   ; ld a,($04e)
        dc.w $8800,$0001             ; add a,#$0001
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0330                   ; ld a,(r4)
        dc.w $0e38                   ; ld ($038),a
        dc.w $4800,SVP_GeoProject/2        ; call always,$257d
        dc.w $8800,$0070             ; add a,#$0070
        dc.w $87f1                   ; add a,($1f1)
        dc.w $0e70                   ; ld ($070),a
        dc.w $e003                   ; eor a,a
        dc.w $064e                   ; ld a,($04e)
        dc.w $8800,$0001             ; add a,#$0001
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0670                   ; ld a,($070)
        dc.w $0530                   ; ld (r4),a
        dc.w $e003                   ; eor a,a
        dc.w $064e                   ; ld a,($04e)
        dc.w $8800,$0003             ; add a,#$0003
        dc.w $0e4e                   ; ld ($04e),a
        dc.w $e003                   ; eor a,a
        dc.w $064d                   ; ld a,($04d)
        dc.w $2800,$0001             ; sub a,#$0001
        dc.w $0e4d                   ; ld ($04d),a
        dc.w $4c50,G117S01b64/2            ; bra z=0,$0db2
        dc.w $4c00,$0123                   ; bra always,$0123
G117S01be8:
        dc.w $e003                   ; eor a,a
        dc.w $064a                   ; ld a,($04a)
        dc.w $a64c                   ; and a,($04c)
        dc.w $4d50,$02ca                   ; bra z=1,$02ca
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0090             ; ld a,#$0090
        dc.w $0e0e                   ; ld ($00e),a
        dc.w $e003                   ; eor a,a
        dc.w $0608                   ; ld a,($008)
        dc.w $6800,$0003             ; cmp a,#$0003
        dc.w $4d70,$02ca                   ; bra n=1,$02ca
        dc.w $6800,$0005             ; cmp a,#$0005
        dc.w $4d70,G117S01c12/2            ; bra n=1,$0e09
        dc.w $4c00,$02ca                   ; bra always,$02ca
G117S01c12:
        dc.w $e003                   ; eor a,a
        dc.w $0608                   ; ld a,($008)
        dc.w $8800,$0001             ; add a,#$0001
        dc.w $9002                   ; mod2 cond$000
        dc.w $8606                   ; add a,($006)
        dc.w $6800,$0100             ; cmp a,#$0100
        dc.w $4d70,G117S01c2a/2            ; bra n=1,$0e15
        dc.w $4c00,$02ca                   ; bra always,$02ca
G117S01c2a:
        dc.w $e003                   ; eor a,a
        dc.w $068a                   ; ld a,($08a)
        dc.w $2800,$0001             ; sub a,#$0001
        dc.w $0e8b                   ; ld ($08b),a
        dc.w $9003                   ; mod3 cond$000
        dc.w $9003                   ; mod3 cond$000
        dc.w $9003                   ; mod3 cond$000
        dc.w $0e8c                   ; ld ($08c),a
        dc.w $e003                   ; eor a,a
        dc.w $068b                   ; ld a,($08b)
        dc.w $9003                   ; mod3 cond$000
        dc.w $868c                   ; add a,($08c)
        dc.w $868b                   ; add a,($08b)
        dc.w $0e8c                   ; ld ($08c),a
        dc.w $e003                   ; eor a,a
        dc.w $0830,$000b             ; ld a,#$000b
        dc.w $0e81                   ; ld ($081),a
        dc.w $e003                   ; eor a,a
        dc.w $0608                   ; ld a,($008)
        dc.w $0e70                   ; ld ($070),a
        dc.w $e003                   ; eor a,a
        dc.w $068c                   ; ld a,($08c)
        dc.w $8800,$0001             ; add a,#$0001
        dc.w $8800,((SVP_TexMaterials/2)&$ffff); add a,#$7000 (PM4 base of SVP_TexMaterials)
        dc.w $00e3                   ; ld pmc,a
        dc.w $08e0,$0800|((SVP_TexMaterials/2)>>16) ; ld pmc,#$080d
        dc.w $000c                   ; ld -,pm4
        dc.w $e003                   ; eor a,a
        dc.w $003c                   ; ld a,pm4
        dc.w $0e71                   ; ld ($071),a
        dc.w $e003                   ; eor a,a
        dc.w $068c                   ; ld a,($08c)
        dc.w $8800,$0002             ; add a,#$0002
        dc.w $8800,((SVP_TexMaterials/2)&$ffff); add a,#$7000 (PM4 base of SVP_TexMaterials)
        dc.w $00e3                   ; ld pmc,a
        dc.w $08e0,$0800|((SVP_TexMaterials/2)>>16) ; ld pmc,#$080d
        dc.w $000c                   ; ld -,pm4
        dc.w $e003                   ; eor a,a
        dc.w $003c                   ; ld a,pm4
        dc.w $0e72                   ; ld ($072),a
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0000             ; ld a,#$0000
        dc.w $0e73                   ; ld ($073),a
        dc.w $0e74                   ; ld ($074),a
        dc.w $0e75                   ; ld ($075),a
        dc.w $0e09                   ; ld ($009),a
        dc.w $4800,$02e0                   ; call always,$02e0
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0000             ; ld a,#$0000
        dc.w $0e8d                   ; ld ($08d),a
        dc.w $e003                   ; eor a,a
        dc.w $060e                   ; ld a,($00e)
        dc.w $0e4e                   ; ld ($04e),a
G117S01caa:
        dc.w $e003                   ; eor a,a
        dc.w $068d                   ; ld a,($08d)
        dc.w $2608                   ; sub a,($008)
        dc.w $4c70,G117S01d30/2            ; bra n=0,$0e98
        dc.w $e003                   ; eor a,a
        dc.w $064e                   ; ld a,($04e)
        dc.w $8800,$0000             ; add a,#$0000
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0330                   ; ld a,(r4)
        dc.w $2800,$0010             ; sub a,#$0010
        dc.w $0e81                   ; ld ($081),a
        dc.w $e003                   ; eor a,a
        dc.w $064e                   ; ld a,($04e)
        dc.w $8800,$0001             ; add a,#$0001
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0330                   ; ld a,(r4)
        dc.w $2800,$0010             ; sub a,#$0010
        dc.w $0e70                   ; ld ($070),a
        dc.w $e003                   ; eor a,a
        dc.w $068d                   ; ld a,($08d)
        dc.w $9003                   ; mod3 cond$000
        dc.w $868c                   ; add a,($08c)
        dc.w $8800,$0003             ; add a,#$0003
        dc.w $8800,((SVP_TexMaterials/2)&$ffff); add a,#$7000 (PM4 base of SVP_TexMaterials)
        dc.w $00e3                   ; ld pmc,a
        dc.w $08e0,$0800|((SVP_TexMaterials/2)>>16) ; ld pmc,#$080d
        dc.w $000c                   ; ld -,pm4
        dc.w $e003                   ; eor a,a
        dc.w $003c                   ; ld a,pm4
        dc.w $0e71                   ; ld ($071),a
        dc.w $e003                   ; eor a,a
        dc.w $068d                   ; ld a,($08d)
        dc.w $9003                   ; mod3 cond$000
        dc.w $868c                   ; add a,($08c)
        dc.w $8800,$0004             ; add a,#$0004
        dc.w $8800,((SVP_TexMaterials/2)&$ffff); add a,#$7000 (PM4 base of SVP_TexMaterials)
        dc.w $00e3                   ; ld pmc,a
        dc.w $08e0,$0800|((SVP_TexMaterials/2)>>16) ; ld pmc,#$080d
        dc.w $000c                   ; ld -,pm4
        dc.w $e003                   ; eor a,a
        dc.w $003c                   ; ld a,pm4
        dc.w $0e72                   ; ld ($072),a
        dc.w $e003                   ; eor a,a
        dc.w $064e                   ; ld a,($04e)
        dc.w $8800,$0003             ; add a,#$0003
        dc.w $0e4e                   ; ld ($04e),a
        dc.w $e003                   ; eor a,a
        dc.w $068d                   ; ld a,($08d)
        dc.w $8800,$0001             ; add a,#$0001
        dc.w $0e8d                   ; ld ($08d),a
        dc.w $4c00,G117S01d3e/2            ; bra always,$0e9f
G117S01d30:
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0000             ; ld a,#$0000
        dc.w $0e81                   ; ld ($081),a
        dc.w $0e70                   ; ld ($070),a
        dc.w $0e71                   ; ld ($071),a
        dc.w $0e72                   ; ld ($072),a
G117S01d3e:
        dc.w $e003                   ; eor a,a
        dc.w $068d                   ; ld a,($08d)
        dc.w $2608                   ; sub a,($008)
        dc.w $4c70,G117S01dc4/2            ; bra n=0,$0ee2
        dc.w $e003                   ; eor a,a
        dc.w $064e                   ; ld a,($04e)
        dc.w $8800,$0000             ; add a,#$0000
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0330                   ; ld a,(r4)
        dc.w $2800,$0010             ; sub a,#$0010
        dc.w $0e73                   ; ld ($073),a
        dc.w $e003                   ; eor a,a
        dc.w $064e                   ; ld a,($04e)
        dc.w $8800,$0001             ; add a,#$0001
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0330                   ; ld a,(r4)
        dc.w $2800,$0010             ; sub a,#$0010
        dc.w $0e74                   ; ld ($074),a
        dc.w $e003                   ; eor a,a
        dc.w $068d                   ; ld a,($08d)
        dc.w $9003                   ; mod3 cond$000
        dc.w $868c                   ; add a,($08c)
        dc.w $8800,$0003             ; add a,#$0003
        dc.w $8800,((SVP_TexMaterials/2)&$ffff); add a,#$7000 (PM4 base of SVP_TexMaterials)
        dc.w $00e3                   ; ld pmc,a
        dc.w $08e0,$0800|((SVP_TexMaterials/2)>>16) ; ld pmc,#$080d
        dc.w $000c                   ; ld -,pm4
        dc.w $e003                   ; eor a,a
        dc.w $003c                   ; ld a,pm4
        dc.w $0e75                   ; ld ($075),a
        dc.w $e003                   ; eor a,a
        dc.w $068d                   ; ld a,($08d)
        dc.w $9003                   ; mod3 cond$000
        dc.w $868c                   ; add a,($08c)
        dc.w $8800,$0004             ; add a,#$0004
        dc.w $8800,((SVP_TexMaterials/2)&$ffff); add a,#$7000 (PM4 base of SVP_TexMaterials)
        dc.w $00e3                   ; ld pmc,a
        dc.w $08e0,$0800|((SVP_TexMaterials/2)>>16) ; ld pmc,#$080d
        dc.w $000c                   ; ld -,pm4
        dc.w $e003                   ; eor a,a
        dc.w $003c                   ; ld a,pm4
        dc.w $0e09                   ; ld ($009),a
        dc.w $e003                   ; eor a,a
        dc.w $064e                   ; ld a,($04e)
        dc.w $8800,$0003             ; add a,#$0003
        dc.w $0e4e                   ; ld ($04e),a
        dc.w $e003                   ; eor a,a
        dc.w $068d                   ; ld a,($08d)
        dc.w $8800,$0001             ; add a,#$0001
        dc.w $0e8d                   ; ld ($08d),a
        dc.w $4c00,G117S01dd2/2            ; bra always,$0ee9
G117S01dc4:
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0000             ; ld a,#$0000
        dc.w $0e73                   ; ld ($073),a
        dc.w $0e74                   ; ld ($074),a
        dc.w $0e75                   ; ld ($075),a
        dc.w $0e09                   ; ld ($009),a
G117S01dd2:
        dc.w $4800,$02e0                   ; call always,$02e0
        dc.w $e003                   ; eor a,a
        dc.w $068d                   ; ld a,($08d)
        dc.w $2608                   ; sub a,($008)
        dc.w $4d70,G117S01caa/2            ; bra n=1,$0e55
        dc.w $4c00,$02ca                   ; bra always,$02ca
G117S01de4:
        dc.w $e003                   ; eor a,a
        dc.w $0663                   ; ld a,($063)
        dc.w $a800,$7fff             ; and a,#$7fff
        dc.w $2800,$0019             ; sub a,#$0019
        dc.w $0e81                   ; ld ($081),a
        dc.w $4c00,G117S01e36/2            ; bra always,$0f1b
G117S01df6:
        dc.w $e003                   ; eor a,a
        dc.w $0664                   ; ld a,($064)
        dc.w $0e81                   ; ld ($081),a
        dc.w $e003                   ; eor a,a
        dc.w $0665                   ; ld a,($065)
        dc.w $0e70                   ; ld ($070),a
        dc.w $e003                   ; eor a,a
        dc.w $0666                   ; ld a,($066)
        dc.w $0e71                   ; ld ($071),a
        dc.w $e003                   ; eor a,a
        dc.w $0667                   ; ld a,($067)
        dc.w $0e72                   ; ld ($072),a
        dc.w $e003                   ; eor a,a
        dc.w $0668                   ; ld a,($068)
        dc.w $0e73                   ; ld ($073),a
        dc.w $e003                   ; eor a,a
        dc.w $0669                   ; ld a,($069)
        dc.w $0e74                   ; ld ($074),a
        dc.w $e003                   ; eor a,a
        dc.w $066a                   ; ld a,($06a)
        dc.w $0e75                   ; ld ($075),a
        dc.w $e003                   ; eor a,a
        dc.w $066b                   ; ld a,($06b)
        dc.w $0e09                   ; ld ($009),a
        dc.w $4800,$02e0                   ; call always,$02e0
        dc.w $4c00,$02ca                   ; bra always,$02ca
G117S01e2e:
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0005             ; ld a,#$0005
        dc.w $0e81                   ; ld ($081),a
G117S01e36:
        dc.w $e003                   ; eor a,a
        dc.w $0664                   ; ld a,($064)
        dc.w $0e70                   ; ld ($070),a
        dc.w $e003                   ; eor a,a
        dc.w $0665                   ; ld a,($065)
        dc.w $0e71                   ; ld ($071),a
        dc.w $e003                   ; eor a,a
        dc.w $0666                   ; ld a,($066)
        dc.w $0e72                   ; ld ($072),a
        dc.w $e003                   ; eor a,a
        dc.w $0667                   ; ld a,($067)
        dc.w $0e73                   ; ld ($073),a
        dc.w $e003                   ; eor a,a
        dc.w $0668                   ; ld a,($068)
        dc.w $0e74                   ; ld ($074),a
        dc.w $e003                   ; eor a,a
        dc.w $0669                   ; ld a,($069)
        dc.w $0e75                   ; ld ($075),a
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0000             ; ld a,#$0000
        dc.w $0e09                   ; ld ($009),a
        dc.w $4800,$02e0                   ; call always,$02e0
        dc.w $4c00,$02ca                   ; bra always,$02ca
G117S01e6a:
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0004             ; ld a,#$0004
        dc.w $0e81                   ; ld ($081),a
        dc.w $e003                   ; eor a,a
        dc.w $0662                   ; ld a,($062)
        dc.w $8800,$0010             ; add a,#$0010
        dc.w $0e70                   ; ld ($070),a
        dc.w $e003                   ; eor a,a
        dc.w $0665                   ; ld a,($065)
        dc.w $0e71                   ; ld ($071),a
        dc.w $e003                   ; eor a,a
        dc.w $0664                   ; ld a,($064)
        dc.w $0e72                   ; ld ($072),a
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0000             ; ld a,#$0000
        dc.w $0e73                   ; ld ($073),a
        dc.w $0e74                   ; ld ($074),a
        dc.w $0e75                   ; ld ($075),a
        dc.w $0e09                   ; ld ($009),a
        dc.w $4800,$02e0                   ; call always,$02e0
        dc.w $4c00,$02ca                   ; bra always,$02ca
G117S01e9e:
        dc.w $08e0,$000d             ; ld pmc,#$000d
        dc.w $08e0,$0018             ; ld pmc,#$0018
        dc.w $000c                   ; ld -,pm4
        dc.w $e003                   ; eor a,a
        dc.w $003c                   ; ld a,pm4
        dc.w $0ff0                   ; ld ($1f0),a
        dc.w $08e0,$000e             ; ld pmc,#$000e
        dc.w $08e0,$0018             ; ld pmc,#$0018
        dc.w $000c                   ; ld -,pm4
        dc.w $e003                   ; eor a,a
        dc.w $003c                   ; ld a,pm4
        dc.w $0ff1                   ; ld ($1f1),a
        dc.w $e003                   ; eor a,a
        dc.w $0830,$c820             ; ld a,#$c820
        dc.w $0e01                   ; ld ($001),a
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0f00             ; ld a,#$0f00
        dc.w $0e05                   ; ld ($005),a
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0000             ; ld a,#$0000
        dc.w $0e06                   ; ld ($006),a
        dc.w $e003                   ; eor a,a
        dc.w $0602                   ; ld a,($002)
        dc.w $6800,$0000             ; cmp a,#$0000
        dc.w $4d50,$02d1                   ; bra z=1,$02d1
        dc.w $4c00,$0020                   ; bra always,$0020
G117S01ee6:
        dc.w $08e0,((G117ImgRaster)>>1)&$ffff ; ld pmc: PM4 reads G117ImgRaster
        dc.w $08e0,$0800|((G117ImgRaster)>>17)
        dc.w $000c                   ; ld -,pm4
        dc.w $08e0,$8020             ; ld pmc,#$8020
        dc.w $08e0,$081c             ; ld pmc,#$081c
        dc.w $00c0                   ; ld pm4,-
        dc.w $0810,$03c8             ; ld x,#$03c8
        dc.w $4800,G117S01f0e/2            ; call always,$0f87
        dc.w $4c00,G117S01f06/2            ; bra always,$0f83
G117S01f06:
        dc.w $0830,$0000             ; ld a,#$0000
        dc.w $4c00,SVP_ChainEnd/2+2        ; bra always,$ab8e
G117S01f0e:
        dc.w $4c00                   ; bra always,$03e9 (operand below is a branch target)
G117S01f10:
        dc.w $03e9
        dc.w $00c3                   ; ld pm4,a
        dc.w $003c                   ; ld a,pm4
        dc.w $00c3                   ; ld pm4,a
        dc.w $003c                   ; ld a,pm4
        dc.w $00c3                   ; ld pm4,a
        dc.w $003c                   ; ld a,pm4
        dc.w $00c3                   ; ld pm4,a
        dc.w $003c                   ; ld a,pm4
        dc.w $00c3                   ; ld pm4,a
        dc.w $003c                   ; ld a,pm4
        dc.w $00c3                   ; ld pm4,a
        dc.w $003c                   ; ld a,pm4
        dc.w $00c3                   ; ld pm4,a
        dc.w $003c                   ; ld a,pm4
        dc.w $00c3                   ; ld pm4,a
        dc.w $0031                   ; ld a,x
        dc.w $2800,$0008             ; sub a,#$0008
        dc.w $0013                   ; ld x,a
        dc.w $4c50,G117S01f10/2            ; bra z=0,$0f88
        dc.w $0065                   ; ld pc,stack
G117S01f3e:
        dc.w $e003                   ; eor a,a
        dc.w $06f2                   ; ld a,($0f2)
        dc.w $6800,$0003             ; cmp a,#$0003
        dc.w $4d50,$03b8                   ; bra z=1,$03b8
        dc.w $e003                   ; eor a,a
        dc.w $0678                   ; ld a,($078)
        dc.w $4c00,SVP_FaceClipAppend/2+2  ; bra always,$2eec
G117Ovr3End:
        if *<>SVP_IntroTriangle+$768
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_IntroParticlesUpdated+$c
G117Ovr4:
        dc.w $4c00,G117S05006/2            ; bra always,$2803
G117Ovr4End:
        if *<>SVP_IntroParticlesUpdated+$10
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_Geometry
G117Ovr5:
        dc.w $4c00,G117S158a4/2            ; bra always,$ac52
G117Ovr5End:
        if *<>SVP_Geometry+$4
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_GeoModelReady
G117Ovr6:
        dc.w $4c00,G117S15c40/2            ; bra always,$ae20
G117Ovr6End:
        if *<>SVP_GeoModelReady+$4
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_GeoViewCompose
G117Ovr7:
        dc.w $4c00,G117S15cd0/2            ; bra always,$ae68
G117Ovr7End:
        if *<>SVP_GeoViewCompose+$4
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_GeoVertex
G117Ovr8:
        dc.w $4c00,G117S158b8/2            ; bra always,$ac5c
G117Ovr8End:
        if *<>SVP_GeoVertex+$4
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_GeoDivide
G117Ovr9:
        dc.w $4c00,G117S15762/2            ; bra always,$abb1
G117Ovr9End:
        if *<>SVP_GeoDivide+$4
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_FaceCountValid
G117Ovr10:
        dc.w $4c00,G117S15728/2            ; bra always,$ab94
G117Ovr10End:
        if *<>SVP_FaceCountValid+$4
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_Face+$c
G117Ovr11:
        dc.w $1860                   ; ld r0,#$60
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $e003                   ; eor a,a
        dc.w $0601                   ; ld a,($001)
        dc.w $8800,$0010             ; add a,#$0010
        dc.w $0e01                   ; ld ($001),a
        dc.w $e003                   ; eor a,a
        dc.w $0663                   ; ld a,($063)
        dc.w $6800,$0009             ; cmp a,#$0009
        dc.w $4d50,SVP_FaceParticle/2      ; bra z=1,$2d9b
        dc.w $a800,$8000             ; and a,#$8000
        dc.w $4d50,SVP_Face/2+95           ; bra z=1,$281c
        dc.w $e003                   ; eor a,a
        dc.w $0663                   ; ld a,($063)
        dc.w $6800,$801e             ; cmp a,#$801e
        dc.w $4d50,SVP_FaceSprite/2        ; bra z=1,$2d7d
        dc.w $e003                   ; eor a,a
        dc.w $0663                   ; ld a,($063)
        dc.w $6800,$801f             ; cmp a,#$801f
        dc.w $4d50,SVP_FaceRadio/2         ; bra z=1,$2d58
        dc.w $e003                   ; eor a,a
        dc.w $0663                   ; ld a,($063)
        dc.w $6800,$8020             ; cmp a,#$8020
        dc.w $4d50,SVP_FaceRadio/2         ; bra z=1,$2d58
        dc.w $e003                   ; eor a,a
        dc.w $0663                   ; ld a,($063)
        dc.w $6800,$8021             ; cmp a,#$8021
        dc.w $4d50,SVP_FaceRadio/2         ; bra z=1,$2d58
        dc.w $e003                   ; eor a,a
        dc.w $0663                   ; ld a,($063)
        dc.w $6800,$8022             ; cmp a,#$8022
        dc.w $4d50,SVP_FaceRaw/2           ; bra z=1,$2d61
        dc.w $4c00,SVP_Face/2+95           ; bra always,$281c
G117S05006:
        dc.w $e003                   ; eor a,a
        dc.w $06f2                   ; ld a,($0f2)
        dc.w $6800,$0001             ; cmp a,#$0001
        dc.w $4d50,G117S05020/2            ; bra z=1,$2810
        dc.w $e003                   ; eor a,a
        dc.w $0810,$0000             ; ld x,#$0000
        dc.w $0820,$0180             ; ld y,#$0180
        dc.w $4c00,SVP_IntroChecksumDirect/2; bra always,$15f3
G117S05020:
        dc.w $0810,$0000             ; ld x,#$0000
        dc.w $4c00,SVP_IntroChecksumDirect/2+40; bra always,$161b
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
G117Ovr11End:
        if *<>SVP_Face+$be
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_FaceCachePointFast
G117Ovr12:
        dc.w $05c5,$05c5             ; normal stream: same as pre-guard
        dc.w $4c00,SVP_FaceCachePointDone/2
        dc.w $0000,$0000
G117Ovr12End:
        if *<>SVP_FaceCachePointFast+$c
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_FaceOutcode+$14
G117Ovr13:
        dc.w $0334                   ; ld a,(r4+!)
G117Ovr13End:
        if *<>SVP_FaceOutcode+$16
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_FaceOutDone0+$2
G117Ovr14:
        dc.w $0334                   ; ld a,(r4+!)
        dc.w $4c00,SVP_FaceOutDone0/2+7    ; bra always,$2ae9
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
G117Ovr14End:
        if *<>SVP_FaceOutDone0+$e
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_FaceEmitValid+$12
G117Ovr15:
        dc.w $1870                   ; ld r0,#$70
        dc.w $02c4                   ; ld pm4,(r0+!)
        dc.w $02c4                   ; ld pm4,(r0+!)
        dc.w $02c4                   ; ld pm4,(r0+!)
        dc.w $02c4                   ; ld pm4,(r0+!)
        dc.w $02c4                   ; ld pm4,(r0+!)
        dc.w $02c4                   ; ld pm4,(r0+!)
        dc.w $4c00,SVP_FaceEmitValid/2+27  ; bra always,$2deb
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
G117Ovr15End:
        if *<>SVP_FaceEmitValid+$36
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_FaceClipAppend
G117Ovr16:
        dc.w $4c00,G117S01f3e/2            ; bra always,$0f9f
G117Ovr16End:
        if *<>SVP_FaceClipAppend+$4
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_SprSizeOk+$58
G117Ovr17:
        dc.w $4c00,G117S071aa/2            ; bra always,$38d5
G117Ovr17End:
        if *<>SVP_SprSizeOk+$5c
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_SprSPix+$1a
G117Ovr18:
        dc.w $4800,G117S071ce/2            ; call always,$38e7
G117Ovr18End:
        if *<>SVP_SprSPix+$1e
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_SprBBegin+$4
G117Ovr19:
        dc.w $0534                   ; ld (r4+!),a
        dc.w $0534                   ; ld (r4+!),a
G117Ovr19End:
        if *<>SVP_SprBBegin+$8
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_SprBBegin+$84
G117Ovr20:
        dc.w $1c00                   ; ld r4,#$00
        dc.w $e003                   ; eor a,a
        dc.w $0630                   ; ld a,($030)
        dc.w $a800,$0003             ; and a,#$0003
        dc.w $0fc5                   ; ld ($1c5),a
        dc.w $0065                   ; ld pc,stack
G117S071aa:
        dc.w $08e0,(SVP_SprNibVals>>1)&$ffff ; ld pmc: PM4 reads SVP_SprNibVals
        dc.w $08e0,$0800|(SVP_SprNibVals>>17)
        dc.w $000c                   ; ld -,pm4
        dc.w $1d40                   ; ld r5,#$40
        dc.w $0830,$0040             ; ld a,#$0040
        dc.w $0fca                   ; ld ($1ca),a
G117S071bc:
        dc.w $05c5                   ; ld (r5+!),pm4
        dc.w $e003                   ; eor a,a
        dc.w $07ca                   ; ld a,($1ca)
        dc.w $3801                   ; subi a,#$01
        dc.w $0fca                   ; ld ($1ca),a
        dc.w $4c50,G117S071bc/2            ; bra z=0,$38de
        dc.w $4c00,SVP_SprLarge/2          ; bra always,$372e
G117S071ce:
        dc.w $e003                   ; eor a,a
        dc.w $0632                   ; ld a,($032)
        dc.w $7800                   ; cmpi a,#$00
        dc.w $4d50,G117S071f4/2            ; bra z=1,$38fa
        dc.w $e003                   ; eor a,a
        dc.w $07c5                   ; ld a,($1c5)
        dc.w $9003                   ; mod3 cond$000
        dc.w $9003                   ; mod3 cond$000
        dc.w $9003                   ; mod3 cond$000
        dc.w $9003                   ; mod3 cond$000
        dc.w $8632                   ; add a,($032)
        dc.w $8800,SVP_SprNibVals/2        ; add a,#$39af (table base)
        dc.w $4a10                   ; ld x,((a))
        dc.w $e003                   ; eor a,a
        dc.w $0031                   ; ld a,x
        dc.w $c300                   ; or a,(r4)
        dc.w $0530                   ; ld (r4),a
G117S071f4:
        dc.w $e003                   ; eor a,a
        dc.w $0630                   ; ld a,($030)
        dc.w $9801                   ; addi a,#$01
        dc.w $0e30                   ; ld ($030),a
        dc.w $e003                   ; eor a,a
        dc.w $07c5                   ; ld a,($1c5)
        dc.w $9801                   ; addi a,#$01
        dc.w $0fc5                   ; ld ($1c5),a
        dc.w $7804                   ; cmpi a,#$04
        dc.w $4c50,G117S07210/2            ; bra z=0,$3908
        dc.w $e003                   ; eor a,a
        dc.w $0fc5                   ; ld ($1c5),a
        dc.w $0304                   ; ld -,(r4+!)
G117S07210:
        dc.w $0065                   ; ld pc,stack
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $e003                   ; eor a,a
        dc.w $0632                   ; ld a,($032)
        dc.w $7800                   ; cmpi a,#$00
        dc.w $4d50,G117S0725a/2            ; bra z=1,$392d
        dc.w $e003                   ; eor a,a
        dc.w $07c5                   ; ld a,($1c5)
        dc.w $9003                   ; mod3 cond$000
        dc.w $9003                   ; mod3 cond$000
        dc.w $9003                   ; mod3 cond$000
        dc.w $9003                   ; mod3 cond$000
        dc.w $8632                   ; add a,($032)
        dc.w $9840                   ; addi a,#$40
        dc.w $1531                   ; ld r5,a
        dc.w $0331                   ; ld a,(r5)
        dc.w $c300                   ; or a,(r4)
        dc.w $0530                   ; ld (r4),a
G117S0725a:
        dc.w $e003                   ; eor a,a
        dc.w $0630                   ; ld a,($030)
        dc.w $9801                   ; addi a,#$01
        dc.w $0e30                   ; ld ($030),a
        dc.w $e003                   ; eor a,a
        dc.w $07c5                   ; ld a,($1c5)
        dc.w $9801                   ; addi a,#$01
        dc.w $0fc5                   ; ld ($1c5),a
        dc.w $7804                   ; cmpi a,#$04
        dc.w $4c50,G117S07276/2            ; bra z=0,$393b
        dc.w $e003                   ; eor a,a
        dc.w $0fc5                   ; ld ($1c5),a
        dc.w $0304                   ; ld -,(r4+!)
G117S07276:
        dc.w $0065                   ; ld pc,stack
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
G117Ovr20End:
        if *<>SVP_SprBBegin+$184
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_SprFlush+$2
G117Ovr21:
        dc.w $e003                   ; eor a,a
        dc.w $07c9                   ; ld a,($1c9)
        dc.w $0fca                   ; ld ($1ca),a
        dc.w $7800                   ; cmpi a,#$00
        dc.w $4d50,G117S072e2/2            ; bra z=1,$3971
        dc.w $e003                   ; eor a,a
        dc.w $07c4                   ; ld a,($1c4)
        dc.w $00e3                   ; ld pmc,a
        dc.w $08e0,$4418             ; ld pmc,#$4418
        dc.w $00c0                   ; ld pm4,-
G117S072d2:
        dc.w $0334                   ; ld a,(r4+!)
        dc.w $00c3                   ; ld pm4,a
        dc.w $e003                   ; eor a,a
        dc.w $07ca                   ; ld a,($1ca)
        dc.w $3801                   ; subi a,#$01
        dc.w $0fca                   ; ld ($1ca),a
        dc.w $4c50,G117S072d2/2            ; bra z=0,$3969
G117S072e2:
        dc.w $0065                   ; ld pc,stack
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
G117Ovr21End:
        if *<>SVP_SprFlush+$9e
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_RadioFace
G117Ovr22:
        dc.w $4c00,$0317                   ; bra always,$0317
G117Ovr22End:
        if *<>SVP_RadioFace+$4
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_RadSpan
G117Ovr23:
        dc.w $4c00,$027c                   ; bra always,$027c
G117Ovr23End:
        if *<>SVP_RadSpan+$4
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_RadioGlyph
G117Ovr24:
        dc.w $4c00,$03af                   ; bra always,$03af
G117Ovr24End:
        if *<>SVP_RadioGlyph+$4
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_Bsp
G117Ovr25:
        dc.w $4c00,G117S15906/2            ; bra always,$ac83
G117Ovr25End:
        if *<>SVP_Bsp+$4
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_BspObject
G117Ovr26:
        dc.w $4c00,G117S1591a/2            ; bra always,$ac8d
G117Ovr26End:
        if *<>SVP_BspObject+$4
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_BspCvt
G117Ovr27:
        dc.w $4c00,G117S15944/2            ; bra always,$aca2
G117Ovr27End:
        if *<>SVP_BspCvt+$4
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_BspAdv
G117Ovr28:
        dc.w $4c00,G117S1596e/2            ; bra always,$acb7
G117Ovr28End:
        if *<>SVP_BspAdv+$4
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_BspGroup
G117Ovr29:
        dc.w $4c00,G117S15998/2            ; bra always,$accc
G117Ovr29End:
        if *<>SVP_BspGroup+$4
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_BspFaces
G117Ovr30:
        dc.w $4c00,G117S159c2/2            ; bra always,$ace1
G117Ovr30End:
        if *<>SVP_BspFaces+$4
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_BspColour
G117Ovr31:
        dc.w $4c00,G117S159ec/2            ; bra always,$acf6
G117Ovr31End:
        if *<>SVP_BspColour+$4
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_ChainGeometry
G117Ovr32:
        dc.w $4c00,G117S15dc0/2            ; bra always,$aee0
G117Ovr32End:
        if *<>SVP_ChainGeometry+$4
        inform 3,"graphics117 SSP override length changed"
        endif
        org SVP_ChainEnd
G117Ovr33:
        dc.w $4c00,G117S01ee6/2            ; bra always,$0f73
G117Ovr33End:
        if *<>SVP_ChainEnd+$4
        inform 3,"graphics117 SSP override length changed"
        endif
        org G117SvpTail

