; Venom 1 unit (planet): strategy table entries (dc.l original 24-bit address,Istrat).
; Included inside M4StrategiesVenom (level_venom.asm). Owner: see build/agent-venom/planet/.
; houdai5f 0A:8F35 is already in M4StrategiesMeteor (searched first): not repeated.
        dc.l $0ad567,M4VpStratSpacebar ;spacebarshoot (Xsolidspacebar DF98 / Ysolidspacebar E040)
        dc.l $099171,M4VpStratWallL ;walll (wall1 B4FB)
        dc.l $09917a,M4VpStratWallR ;wallr
        dc.l $08d075,M4VpStratFlyPillarS ;flypillars (B866, map)
        dc.l $08d0a5,M4VpStratFlyPillar ;flypillar (B866, mother 05:53B5)
        dc.l $0997b7,M4VpStratPillar2 ;pillar2 (B449, mother 05:533B)
        dc.l $09f72b,M4VpStratTopRight1 ;tunnel_0 CAEC
        dc.l $09f737,M4VpStratTopLeft1
        dc.l $09f743,M4VpStratBotLeft1
        dc.l $09f74f,M4VpStratBotRight1
        dc.l $0af65e,M4VpStratTunPillar ;tunnel pillars DBE0 / DBFC
        dc.l $08f145,M4VpStratExit ;exit_1 C0A4
        dc.l $08f18b,M4VpStratExitLight3 ;exitlight C0F8
        dc.l $08f193,M4VpStratExitLight4
        dc.l $08f19b,M4VpStratExitLight5
        dc.l $08f1a3,M4VpStratExitLight6
        dc.l $08f206,M4VpStratExitOpen ;exitface C14C
        dc.l $08f200,M4VpStratExitOpen ;exitopensnd: + set_sound2 5 (audio only)
        dc.l $068738,M4VpStratNoCollAnim0 ;last_b_3 D048
