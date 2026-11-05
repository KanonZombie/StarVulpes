; Star field (dotsflag $FF) inputs for SVP_Stars (build/agent-stars/INTEGRATION.md).
; ROM ref/Star Fox (USA).sfc rev0: every image 02:DA52/02:F100 copy $16FB to m_dotsorstars
; 70:019E and, bit 15 set, 03:BCE1..BD65 writes 70:00C6..CA = viewpos ($C1/$C3/$C5) and
; 70:00D2..E2 = $161D..$162D (W of getview 02:FB49 = R(+viewrotx,+viewroty,+viewrotz), GSU
; 01:829F, row-major m11..m33); GSU mshowdust 01:A8A6 draws the stars before the polygons.
; minitdust 01:A861 seeds them in initgame3d_l (03:B819 -> initmario3d 03:B85B -> 03:BCD1).
; Port: M4_LVW_POS/M4_LVW_W (M4LevelView) are viewpos and W with the same formula, order and
; precision (tools/check-svp-stars.py compares M4LvwRotation with GSU 01:829F word by word).
M4_GEO_STARS equ $301c40 ;DRAM 14 WORDs: m_dotsorstars, 70:1A26, viewpos xyz, W 9 WORDs
M4_STARS_STATE equ $31f600 ;DRAM 362 WORDs, SVP-owned: magic $5344, m_rand 70:0140, 120 x (x,y,z)
M4_STARS_MODE equ 0 ;70:1A26 (setbginfo 03:EFDC.., levelinfo bits 5/6): 0 in Asteroid 1 ($17)

; Stage start (initgame3d_l -> minitdust), with the SVP idle (after M4PipeFlush):
; the next SVP_Stars seeds the table (m_rand $19F8) before drawing.
M4LevelStarsInit:
        clr.w M4_STARS_STATE
        rts

; Screens without the level view (next to clr.w M4_GEO_GRID in M4IntroGeometryInit).
M4LevelStarsOff:
        clr.w M4_GEO_STARS
        rts

; Per image, after M4LevelDraw and before M4TextVideoDraw requests/latches this image's
; cmd8: the overlapped cmd8 of the previous image also reads this block, so it is sealed
; first (M4PipeFlush; no-op when nothing is pending). d0 = 0 or the M4PipeFlush error.
M4LevelStarsInput:
        if def(M4_VR_DMA)
        jsr M4PipeFlush
        tst.w d0
        bne.s M4LvsReturn
        endif
        movem.l d1/a0-a1,-(sp)
        lea M4_GEO_STARS,a1
        move.b M4_SC_DOTS,d0 ;dotsflag $16FB ($FF and $16FC $FF: stars)
        ext.w d0
        move.w d0,(a1)+ ;m_dotsorstars: SVP_Stars only acts if negative
        move.w #M4_STARS_MODE,(a1)+
        lea M4_LVW_POS,a0 ;viewpos (3 WORDs) then W (9 WORDs) are contiguous
        moveq #5,d1
M4LvsCopy:
        move.l (a0)+,(a1)+
        dbra d1,M4LvsCopy
        movem.l (sp)+,d1/a0-a1
        moveq #0,d0
M4LvsReturn:
        rts
