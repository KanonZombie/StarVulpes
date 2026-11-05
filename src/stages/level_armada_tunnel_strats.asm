; Space Armada unit (tunnel): strategy table entries (dc.l original 24-bit address,Istrat).
; Included inside M4StrategiesSpaceArmada (level_armada.asm). Scope: interior/tunnel strategies (build/agent-armada/research/tunnel/SPEC.md).
; Already in other tables (not repeated): 09:F72B.. pieces, 08:F145 exit, exitlight3..6, exitopen/exitopensnd (venom planet).
        dc.l $0af0ec,M4TnOpenLR ;open_l BB10
        dc.l $0af17d,M4TnUpDoor ;up_door D198
        dc.l $0abb1f,M4TnTwall0 ;bou_0 DCC0
        dc.l $0abbfa,M4TnWarker3 ;warker_3 DE2C, s_wark_0 DB8C
        dc.l $0ab69c,M4TnLeng0 ;leng_0 DB1C
        dc.l $099529,M4TnIris ;iris BDE8 (+ child C8BC 00:FACF)
        dc.l $08d5f0,M4TnItem6 ;item_6 C4B0
        dc.l $08a258,M4TnCore0 ;core_1_0 C6E0
        dc.l $08a299,M4TnCore1 ;core_1_1 C6FC
        dc.l $08f1f7,M4TnExitOpenSnd2 ;bshipexitface C1A0
        dc.l $0af235,M4TnColonyExit ;E5D4
