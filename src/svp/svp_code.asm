; SSP1601 program at ROM byte $820 / DSP word $410, jumped to from $800.
; Instruction encodings: svpdev tools/ssp16asm/src/assembler/instructions.rs.
; Protocol adapted from svpdev SVP_tests (Javier de Siloniz Sandino, MIT).
; See THIRD_PARTY.md. Words are emitted by asm68k, not 68000 instructions.
; Deliberately no auto-increment: every PM4 access names one exact DRAM word.

SVP_Start:
        dc.w $0840,$0000         ; ld st,0000: EXT0=status, EXT3=XST
        dc.w $e003               ; eor a,a: clear ALL 32 accumulator bits
SVP_Wait:
        dc.w $0038               ; ld a,ext0: read/clear host request flag
        dc.w $b802               ; andi 02: host wrote XST?
        dc.w $4d50,SVP_Wait/2    ; bra z=1,wait (DSP word addresses)
        dc.w $002b               ; ld y,ext3: retain request sequence
        dc.w $e003,$0ef2         ; RAM A F2: no continuation for ordinary requests
        dc.w $08e0,$0004         ; command at DSP $180004 / host $300008
        dc.w $08e0,$0018
        dc.w $000c               ; program PM4 READ
        dc.w $e003,$003c         ; eor a,a / ld a,ext4
        dc.w $6800,$000b
        dc.w $4d50,SVP_Particles/2
        dc.w $6800,$000d
        dc.w $4d50,SVP_Chain/2
        dc.w $6800,$0009
        dc.w $4d50,SVP_Geometry/2
        dc.w $6800,$000a
        dc.w $4d50,SVP_Faces/2
        dc.w $6800,$000c         ; cmd12: BSP walk, colours and packets, then cmd10 (tools/generate-svp-bsp.py)
        dc.w $4d50,SVP_Bsp/2
        dc.w $6800,$0008
        dc.w $4d50,SVP_IntroRaster/2
        dc.w $6800,$0007
        dc.w $4d50,SVP_Text/2
        dc.w $6800,$0006
        dc.w $4d50,SVP_Planar/2
        dc.w $6800,$0001         ; cmpi a,0001: graphics command?
        dc.w $4d50,SVP_Graphics/2

        dc.w $08e0,$0000         ; ld ext6,0000: operand A at DSP $180000
        dc.w $08e0,$0018         ; ld ext6,0018: DRAM, increment 0
        dc.w $000c               ; ld -,ext4: program PM4 READ
        dc.w $001c               ; ld x,ext4: operand A
        dc.w $08e0,$0001         ; operand B at DSP $180001
        dc.w $08e0,$0018
        dc.w $000c               ; program PM4 READ
        dc.w $e003               ; eor a,a: defined low half before arithmetic
        dc.w $003c               ; ld a,ext4: B into upper 16 accumulator bits
        dc.w $8001               ; add a,x: (A+B) modulo 65536 in upper half

SVP_PublishResult:
        dc.w $4c00,SVP_ChainResult/2
SVP_PublishResultBody:
        dc.w $08e0,$0002         ; result at DSP $180002 / host $300004
        dc.w $08e0,$0018
        dc.w $00c0               ; ld ext4,-: program PM4 WRITE
SVP_ResultWrite:
        dc.w $00c3               ; ld ext4,a: publish calculated result
        dc.w $08e0,$0003         ; sequence echo at DSP $180003
        dc.w $08e0,$0018
        dc.w $00c0               ; program PM4 WRITE
        dc.w $00c2               ; ld ext4,y: publish sequence AFTER result
SVP_Complete:
        dc.w $08e0,$0009         ; DRAM completion sequence, portable to Fusion
        dc.w $08e0,$0018
        dc.w $00c0,$00c2         ; publish AFTER result and echo
        dc.w $00b2               ; ld ext3,y: completion flag AFTER both writes
        dc.w $4c00,SVP_Wait/2    ; bra always,wait: accept another fresh job
        include 'svp/svp_graphics.asm'
        include '../build/svp-planar.inc'
        include '../build/svp-text.inc'
        include '../build/svp-intro-raster.inc'
        include '../build/svp-intro-geometry.inc'
        include '../build/svp-intro-faces.inc'
        include '../build/svp-intro-particles.inc'
        include '../build/svp-sprites.inc'
        include '../build/agent-texpoly/svp-texpoly.inc' ;textured faces (generate-svp-texpoly.py)
        include '../build/svp-radio.inc'
        include '../build/agent-sphere/svp-sphere.inc' ;route map planets (generate-svp-sphere.py)
        include '../build/agent-stars/svp-stars.inc' ;space star field (generate-svp-stars.py)
        include '../build/svp-bsp.inc' ;SVP12: BSP walk and face packets (generate-svp-bsp.py)
        include '../build/svp-chain.inc'
SVP_End:
        if def(M4_GRAPHICS117)
        include 'release/g117_svp.asm' ;stub block, then in-place overrides
        endif
