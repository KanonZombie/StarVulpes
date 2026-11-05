; Bounded MD visual frontend for original old_type and its original BSP.
; No movement/camera/event logic here. Native Q15 shape matrix, WORD poses.
; Normal path: SVP9 geometry, SVP10 clip, SVP8 raster. CPU orders original BSP.
M4_POLY_COUNT equ $ff8276
M4_MESH_MATRIX equ $ff8900
M4_MESH_VERTS equ $ff8920
M4_MESH_OBJECT equ $ff89e0
M4_MESH_ERROR equ $ff89e4
M4_MESH_COLOUR equ $ff89e6
M4_MESH_KIND equ $ff89e8 ;0=old_type,1=bounded elaser2a
M4_LEVEL_KIND equ 23 ;mesh kinds 23+index: level shape catalog (18..22 level effects)
M4_MESH_NEAR equ $ff89ea ;any transformed vertex at/forward of visual nearZ32
M4_MESH_BSP equ $ff89ec
M4_MESH_GROUPS equ $ff89f0
M4_MESH_NODES equ $ff89f4
M4_MESH_STRIDE equ $ff89f6
M4_MESH_MATERIALS equ $ff89f8
M4_MESH_VIS equ $ff8ac0
M4_MESH_CLIP_A equ $ff8b00
M4_MESH_CLIP_B equ $ff8c00
M4_POLY_INPUT equ $301e00
M4_BSP_SVP equ $fff9d4 ;.b 1: faces by SVP jobs (cmd12, tools/generate-svp-bsp.py), 0: the 68000 reference below
M4_GEO_HOOK9 equ $fff9d8 ;.l routine run by the cmd9 request after its kick (SVP mode: M4IntroSceneDrawObjects)

; a0=original ship context. Append primitives, preserving original BSP order.
M4IntroMesh:
        moveq #0,d0
        bra.s M4MeshStart
M4IntroLaserMesh:
        moveq #1,d0
        bra.s M4MeshStart
M4IntroEffectMesh:
        moveq #0,d0
        move.b 21(a0),d0
        subq.w #2,d0 ; kind4/5/6 -> mesh2/3/4
        tst.w M4_GEO_VIEW
        beq.s M4MeshStart
        move.l a1,-(sp)
        move.w 46(a0),d0
        lsl.w #5,d0
        lea M4LevelShapeDescriptors,a1
        move.w 14(a1,d0.w),d0 ;full model id: level catalogue can exceed 253
        movea.l (sp)+,a1
M4MeshStart:
        movem.l d1-d7/a0-a6,-(sp)
        move.w d0,M4_MESH_KIND
        move.l #M4IntroModelBSP,M4_MESH_BSP
        move.l #M4IntroModelGroups,M4_MESH_GROUPS
        move.w #19,M4_MESH_NODES
        move.w #20,M4_MESH_STRIDE ;indices4 + original normal3
        move.l #M4IntroMaterialColours,M4_MESH_MATERIALS
        cmpi.w #M4_LEVEL_KIND,d0
        bhs M4MeshLevelShape
        cmpi.w #17,d0
        bne.s M4MeshNotTitle
        moveq #6,d0 ;title my_demo descriptor
        bra.s M4MeshDescriptorReady
M4MeshNotTitle:
        cmpi.w #14,d0
        bhs M4MeshModelReady ;muzzle flashes: billboard, no BSP
        cmpi.w #12,d0
        bhs.s M4MeshZacoDescriptor
        cmpi.w #9,d0
        bhs M4MeshModelReady
        cmpi.w #5,d0
        blo M4MeshModelReady
        subi.w #5,d0
        bra.s M4MeshDescriptorReady
M4MeshZacoDescriptor:
        subq.w #8,d0
M4MeshDescriptorReady:
        cmpi.w #7,d0
        bhs M4MeshFail
        mulu.w #10,d0
        lea M4BossModelDescriptors,a1
        adda.w d0,a1
        move.l (a1)+,M4_MESH_BSP
        move.l (a1)+,M4_MESH_GROUPS
        move.w (a1),M4_MESH_NODES
        move.w #28,M4_MESH_STRIDE ;indices8 + original normal3
        move.l #M4BossMaterialColours,M4_MESH_MATERIALS
        cmpi.w #12,M4_MESH_KIND
        bhs.s M4MeshOriginalColours
        cmpi.w #8,M4_MESH_KIND
        bne.s M4MeshBossColours
M4MeshOriginalColours:
        move.l #M4IntroMaterialColours,M4_MESH_MATERIALS
M4MeshBossColours:
        bra.s M4MeshDescriptorDone
; Level shape catalog (tools/generate-level-shapes.py): kind 23+index.
M4MeshLevelShape:
        subi.w #M4_LEVEL_KIND,d0
        cmpi.w #M4_LEVEL_SHAPES,d0
        bhs M4MeshFail
        mulu.w #32,d0
        lea M4LevelShapeDescriptors,a1
        adda.w d0,a1
        move.l (a1)+,M4_MESH_BSP
        move.l (a1)+,M4_MESH_GROUPS
        addq.l #4,a1
        move.w (a1),M4_MESH_NODES
        move.w #28,M4_MESH_STRIDE
M4MeshDescriptorDone:
M4MeshModelReady:
        clr.w M4_MESH_NEAR
        move.l a0,M4_MESH_OBJECT
        tst.b M4_BSP_SVP ;SVP jobs: the SVP reads the visibility, near flag and light itself
        bne M4MeshPreparedDispatch
        if def(M4_PROFILE)
        move.l d0,-(sp)
        moveq #6,d0
        jsr M4ProfMark
        move.l (sp)+,d0
        endif
        bsr M4IntroGeometryLoad
        if def(M4_PROFILE)
        move.l d0,-(sp)
        moveq #3,d0
        jsr M4ProfMark
        move.l (sp)+,d0
        endif
        tst.w d0
        bne M4MeshExit
        tst.w M4_MESH_NEAR
        beq M4MeshExit
        bra M4MeshPreparedDispatch
        lea M4_MESH_MATRIX,a1
        bsr M4IntroMatrix
        lea M4IntroModelVertices,a4
        lea M4_MESH_VERTS,a5
        moveq #31,d7
        tst.w M4_MESH_KIND
        beq.s M4MeshVertex
        cmpi.w #2,M4_MESH_KIND
        bhs.s M4MeshEffectVertices
        moveq #0,d0
        move.b 18(a0),d0
        lsl.w #2,d0
        lea M4IntroLaserFrames,a4
        movea.l (a4,d0.w),a4
        moveq #5,d7
        bra.s M4MeshVertex
M4MeshEffectVertices:
        lea M4EffectExplosionVertices,a4
        moveq #8,d7
        cmpi.w #2,M4_MESH_KIND
        beq.s M4MeshVertex
        lea M4EffectExplosionSpriteVertices,a4
        moveq #3,d7
        cmpi.w #3,M4_MESH_KIND
        beq.s M4MeshVertex
        lea M4EffectSmokeVertices,a4
        moveq #4,d7
M4MeshVertex:
        lea M4_MESH_MATRIX,a3
        movea.l M4_MESH_OBJECT,a6
        moveq #0,d6
M4MeshAxis:
        move.w (a4),d0
        muls.w (a3),d0
        move.w 2(a4),d1
        muls.w 6(a3),d1
        add.l d1,d0
        move.w 4(a4),d1
        muls.w 12(a3),d1
        add.l d1,d0
        addq.l #2,a3 ; next COLUMN of native transposed matrix
        asr.l #8,d0
        asr.l #7,d0
        add.w (a6,d6.w),d0
        cmpi.w #4,d6
        bne.s M4MeshAxisCoordinate
        sub.w INTRO_CAMERA+8,d0
        cmpi.w #32,d0
        blt.s M4MeshAxisCoordinate
        move.w #1,M4_MESH_NEAR
M4MeshAxisCoordinate:
        ext.l d0
        cmpi.l #-16384,d0
        blt M4MeshFail
        cmpi.l #16383,d0
        bgt M4MeshFail
        move.w d0,(a5)+
        addq.w #2,d6
        cmpi.w #6,d6
        bne.s M4MeshAxis
        lea 6(a4),a4
        dbra d7,M4MeshVertex
        ; Every convex face is empty after near clipping if all vertices
        ; lie strictly behind32. Same independent always-clip pixel oracle.
        tst.w M4_MESH_NEAR
        beq M4MeshExit
        cmpi.w #2,M4_MESH_KIND
        bhs M4MeshEffectFaces
        lea M4IntroModelVisibility,a4
        lea M4_MESH_VIS,a5
        moveq #39,d7
        tst.w M4_MESH_KIND
        beq.s M4MeshVisibilityNext
        lea M4IntroLaserVisibility,a4
        moveq #5,d7
M4MeshVisibilityNext:
        bsr M4MeshVisibility
        tst.l d0
        smi (a5)+
        lea 6(a4),a4
        dbra d7,M4MeshVisibilityNext
        tst.w M4_MESH_ERROR
        bne M4MeshExit
M4MeshPreparedDispatch:
        cmpi.w #M4_LEVEL_KIND,M4_MESH_KIND
        bhs M4MeshBSPFaces
        cmpi.w #9,M4_MESH_KIND
        beq M4MeshParticleFace
        cmpi.w #17,M4_MESH_KIND
        beq.s M4MeshBSPFaces
        cmpi.w #14,M4_MESH_KIND
        bhs M4MeshEffectFaces
        cmpi.w #12,M4_MESH_KIND
        bhs.s M4MeshBSPFaces
        cmpi.w #10,M4_MESH_KIND
        bhs M4MeshEffectFaces
        cmpi.w #5,M4_MESH_KIND
        bhs.s M4MeshBSPFaces
        cmpi.w #2,M4_MESH_KIND
        bhs M4MeshEffectFaces
        tst.w M4_MESH_KIND
        bne.s M4MeshLaserFaces
M4MeshBSPFaces:
        tst.b M4_BSP_SVP
        bne M4MeshJobBSP
        bsr M4FastFacesBegin
        moveq #0,d0
        bsr M4FastNode
        bra M4FastFacesEnd
M4MeshJobBSP:
        moveq #1,d1
        bsr M4BspJob
        bra M4MeshExit
        moveq #0,d0
        bsr M4MeshNode
        bra M4MeshExit
M4MeshLaserFaces:
        tst.b M4_BSP_SVP
        bne M4MeshJobLaser
        bsr M4FastFacesBegin
        lea M4IntroLaserFaces,a1
        moveq #14,d2
        moveq #5,d3
        bsr M4FastList
        bra M4FastFacesEnd
M4MeshJobLaser:
        lea M4IntroLaserFaces,a1
        moveq #14,d2
        moveq #5,d3
        moveq #2,d1
        bsr M4BspJob
        bra M4MeshExit
        lea M4IntroLaserFaces,a4
        moveq #5,d7
M4MeshLaserFace:
        bsr M4MeshFace
        lea 14(a4),a4
        dbra d7,M4MeshLaserFace
        bra M4MeshExit
M4MeshEffectFaces:
        cmpi.w #18,M4_MESH_KIND
        bhs.s M4MeshLevelEffectFaces
        cmpi.w #10,M4_MESH_KIND
        beq.s M4MeshExplosion8Faces
        cmpi.w #11,M4_MESH_KIND
        beq.s M4MeshSprite8Faces
        lea M4EffectExplosionFaces,a4
        moveq #5,d7
        cmpi.w #2,M4_MESH_KIND
        beq.s M4MeshEffectFace
        lea M4EffectExplosionSpriteFaces,a4
        moveq #0,d7
        cmpi.w #3,M4_MESH_KIND
        beq.s M4MeshEffectFace
        lea M4EffectSmokeFaces,a4
        bra.s M4MeshEffectFace
M4MeshExplosion8Faces:
        lea M4EffectExplosion8Faces,a4
        moveq #7,d7
        bra.s M4MeshEffectFace
M4MeshSprite8Faces:
        lea M4EffectExplosionSprite8Faces,a4
        moveq #0,d7
        bra.s M4MeshEffectFace
M4MeshLevelEffectFaces:
        moveq #0,d7 ;billboards: one quad
        move.w M4_MESH_KIND,d0
        lea M4EffectExplosionSprite4Faces,a4
        cmpi.w #19,d0
        beq.s M4MeshEffectFace
        lea M4EffectExplosionSprite16Faces,a4
        cmpi.w #20,d0
        beq.s M4MeshEffectFace
        lea M4EffectBallFaces,a4
        cmpi.w #21,d0
        beq.s M4MeshEffectFace
        lea M4EffectSparkFaces,a4
        cmpi.w #22,d0
        beq.s M4MeshEffectFace
        lea M4EffectExplosion4Faces,a4
        moveq #3,d7
M4MeshEffectFace:
        movea.l a4,a1
        move.w d7,d3
        tst.b M4_BSP_SVP
        bne M4MeshJobEffect
        bsr M4FastFacesBegin
        moveq #20,d2
        bsr M4FastList
        bra M4FastFacesEnd
M4MeshJobEffect:
        moveq #20,d2
        moveq #2,d1
        bsr M4BspJob
        bra M4MeshExit
        bsr M4MeshFace
        lea 20(a4),a4
        dbra d7,M4MeshEffectFace
        bra M4MeshExit
M4MeshParticleFace:
        bsr M4IntroGeometryParticle
        bra M4MeshExit
M4MeshFail:
        move.w #$E201,M4_MESH_ERROR ;error site 1
M4MeshExit:
        move.w M4_MESH_ERROR,d0
        movem.l (sp)+,d1-d7/a0-a6
        rts

; Original visibility triples, evaluated geometrically before near clipping.
; Determinant sign = projected signed-area with the original Z-sign correction.
; old_type normal components fit signed16 (max7788 over recovered poses).
M4MeshVisibility:
        lea -12(sp),sp
        lea M4_MESH_VERTS,a0
        move.w (a4),d0
        adda.w d0,a0
        lea M4_MESH_VERTS,a1
        move.w 2(a4),d0
        adda.w d0,a1
        lea M4_MESH_VERTS,a2
        move.w 4(a4),d0
        adda.w d0,a2
        moveq #0,d2
        movea.l sp,a3
M4MeshEdgeVector:
        move.w (a1,d2.w),d0
        sub.w (a0,d2.w),d0
        move.w d0,(a3,d2.w)
        move.w (a2,d2.w),d0
        sub.w (a0,d2.w),d0
        move.w d0,6(a3,d2.w)
        addq.w #2,d2
        cmpi.w #6,d2
        bne.s M4MeshEdgeVector
        moveq #0,d4
        moveq #0,d2
M4MeshNormal:
        ; Cyclic axes: normalX=uY*vZ-uZ*vY etc.
        move.w d2,d3
        addq.w #2,d3
        cmpi.w #6,d3
        blo.s M4MeshNormalAxis1
        subq.w #6,d3
M4MeshNormalAxis1:
        move.w d3,d5
        addq.w #2,d5
        cmpi.w #6,d5
        blo.s M4MeshNormalAxis2
        subq.w #6,d5
M4MeshNormalAxis2:
        move.w (a3,d3.w),d0
        muls.w 6(a3,d5.w),d0
        move.w (a3,d5.w),d1
        muls.w 6(a3,d3.w),d1
        sub.l d1,d0
        cmpi.l #-32768,d0
        blt.s M4MeshVisibilityBad
        cmpi.l #32767,d0
        bgt.s M4MeshVisibilityBad
        muls.w (a0,d2.w),d0
        add.l d0,d4
        addq.w #2,d2
        cmpi.w #6,d2
        bne.s M4MeshNormal
        move.l d4,d0
        lea 12(sp),sp
        rts
M4MeshVisibilityBad:
        move.w #$E202,M4_MESH_ERROR ;error site 2
        moveq #0,d0
        lea 12(sp),sp
        rts

; Original GSU mdo_colour (01:904F) through resolved ROM descriptors, see
; tools/generate-intro-colours.py. Per object: depth level from bigz =
; fq(Zview,$7FFE) and 03:8FAA (boss parts: depthoffset1, 03:8F9A); light
; L = HIB(sum fq(M_ij,$49E5)), M_ij = fq(R_ij,$7FFE) from the SVP9 block
; (01:8500 shortcuts when rotX=rotZ=0, rotY 0/$80); colframe gameframe&127.
M4_MESH_LEVEL equ $ff8a00 ;BYTE
M4_MESH_COLFRAME equ $ff8a01 ;BYTE
M4_MESH_LIGHT equ $ff8a02 ;three WORDs, sign-extended BYTEs
M4_MESH_NORMAL equ $ff8a08 ;WORD offset of the normal in the face record
M4MeshColourTables:
        dc.l M4ColoursOldType,M4ColoursLaser,M4ColoursExplosion,M4ColoursSprite
        dc.l M4ColoursSmoke,M4ColoursBoss,M4ColoursBoss,M4ColoursBoss
        dc.l M4ColoursDebris,M4ColoursOldType,M4ColoursExplosion,M4ColoursSprite
        dc.l M4ColoursZacoE388,M4ColoursZacoC22C,M4ColoursFlash,M4ColoursFlash
        dc.l M4ColoursFlash,M4ColoursMyDemo
        ; 18..22 level effects: expl_4 (same table 03:8213 as expl_6),
        ; explosion/explosion4 and bouncyball billboards (flat adaptation as
        ; explosion2), spark (as the muzzle flashes)
        dc.l M4ColoursExplosion,M4ColoursSprite,M4ColoursSprite,M4ColoursSprite
        dc.l M4ColoursFlash
        include '../build/level-shape-colours.inc' ;kinds 23.. level shapes
M4MeshColourSetup:
        movem.l d0-d4/a0-a1,-(sp)
        bsr M4MeshColourPrefix
        tst.w M4_GEO_VIEW
        bne M4ColourLevelView
        bra M4ColourBigZ
; d5 = kind, M4_MESH_OBJECT: a3 = colour table (object coltab, hit flash), M4_MESH_NORMAL and M4_MESH_COLFRAME.
; Shared by the 68000 reference and the SVP jobs (M4BspJob). Clobbers d0, d1, a0, a1.
M4MeshColourPrefix:
        move.w d5,d0
        add.w d0,d0
        add.w d0,d0
        lea M4MeshColourTables,a3
        movea.l (a3,d0.w),a3
        movea.l M4_MESH_OBJECT,a0
        cmpi.w #M4_LEVEL_KIND,d5 ;level object colour table (alx+$20 coltab,
        blo.s M4ColourNoCtab ;01:AE0C): instead of the header table
        move.w X_COLTAB(a0),d0
        beq.s M4ColourNoCtab
        lea M4ColtabMap,a1
M4ColtabFind:
        move.w (a1)+,d1
        beq.s M4ColourNoCtab ;not converted: header table kept
        cmp.w d1,d0
        beq.s M4ColtabFound
        addq.l #4,a1
        bra.s M4ColtabFind
M4ColtabFound:
        movea.l (a1),a3
M4ColourNoCtab:
        btst #2,31(a0) ;hit-flash, consumed by the draw list (ships, level)
        beq.s M4ColourNoFlash
        cmpi.w #M4_LEVEL_KIND,d5
        bhs.s M4ColourFlash
        cmpi.w #1,d5
        bhs.s M4ColourNoFlash
M4ColourFlash:
        lea M4ColoursWhite,a3
M4ColourNoFlash:
        move.w M4_MESH_STRIDE,d0
        subq.w #6,d0
        move.w d0,M4_MESH_NORMAL
        move.w M4_SCENE_TICK,d0
        cmpi.w #M4_LEVEL_KIND,d5
        blo.s M4ColourNotLevel
        tst.b 18(a0) ;level: own colframe only with bit7 (02:F581 +$1A)
        bpl.s M4ColourFrame
        move.b 18(a0),d0
        bra.s M4ColourFrame
M4ColourNotLevel:
        cmpi.w #14,d5
        blo.s M4ColourFrame
        cmpi.w #16,d5
        bhi.s M4ColourFrame
        move.b 18(a0),d0 ;flash al_colframe has bit7 set
M4ColourFrame:
        andi.b #127,d0
        move.b d0,M4_MESH_COLFRAME
        rts
M4ColourBigZ:
        movea.l M4_MESH_OBJECT,a0
        ; bigz = fq(object Z - viewZ, $7FFE)
        move.w 4(a0),d0
        sub.w INTRO_CAMERA+8,d0
        muls.w #$7ffe,d0
        asr.l #8,d0
        asr.l #7,d0
        lea M4DepthNormal,a1
        cmpi.w #5,d5
        blo.s M4ColourDepthTable
        cmpi.w #8,d5
        bhs.s M4ColourDepthTable
        lea M4DepthOffset1,a1
M4ColourDepthTable:
        moveq #0,d1
M4ColourLevel:
        move.b (a1,d1.w),d2
        lsl.w #8,d2
        add.w d0,d2
        bmi.s M4ColourLevelFound
        addq.w #1,d1
        cmpi.w #3,d1
        bne.s M4ColourLevel
M4ColourLevelFound:
        move.b d1,M4_MESH_LEVEL
        ; light vector from the object's matrix (geometry block WORDs0..8)
        movea.l M4_GEO_CURRENT,a1
        tst.b 12(a0)
        bne.s M4ColourGeneral
        tst.b 14(a0)
        bne.s M4ColourGeneral
        move.b 13(a0),d0
        beq.s M4ColourIdentity
        cmpi.b #$80,d0
        bne.s M4ColourGeneral
        move.l #$ffb7ffb7,M4_MESH_LIGHT ;rows1,3 of W negated: (-74,73,-74)
        move.w #$ffb6,M4_MESH_LIGHT
        move.w #73,M4_MESH_LIGHT+2
        move.w #$ffb6,M4_MESH_LIGHT+4
        bra.s M4ColourSetupDone
M4ColourIdentity:
        move.w #73,M4_MESH_LIGHT ;W=diag($7FFE): HIB(3*fq($7FFE,$49E5))
        move.w #73,M4_MESH_LIGHT+2
        move.w #73,M4_MESH_LIGHT+4
        bra.s M4ColourSetupDone
M4ColourGeneral:
        lea M4_MESH_LIGHT,a0
        moveq #2,d4
M4ColourLightRow:
        moveq #0,d3
        moveq #2,d2
M4ColourLightTerm:
        move.w (a1)+,d0
        muls.w #$7ffe,d0
        asr.l #8,d0
        asr.l #7,d0 ;M_ij = fq(R_ij,$7FFE)
        muls.w #$49e5,d0
        asr.l #8,d0
        asr.l #7,d0 ;fq(M_ij,$49E5)
        add.w d0,d3
        dbra d2,M4ColourLightTerm
        asr.w #8,d3 ;HIB + SEX
        move.w d3,(a0)+
        dbra d4,M4ColourLightRow
M4ColourSetupDone:
        movem.l (sp)+,d0-d4/a0-a1
        rts
; Level view: bigz = view z of the object (rel.W, level object field 60),
; depth table stage1 03:8FB6; light = HIB(sum fq($49E5, mat_ij)) from the
; composed SVP block matrix (01:8615..867F), no zero-view shortcuts.
M4ColourLevelView:
        move.w 60(a0),d0
        movea.l M4_SC_DEPTH,a1 ;set_zdepthtable of the current BG
        tst.b X_DEPTHOFF(a0)
        beq.s M4ColourLevelViewTable
        lea M4DepthOffset1,a1 ;alx depthoffset 1: depthtables+0 03:8F9A
M4ColourLevelViewTable:
        moveq #0,d1
M4ColourLevelViewDepth:
        move.b (a1,d1.w),d2
        lsl.w #8,d2
        add.w d0,d2
        bmi.s M4ColourLevelViewFound
        addq.w #1,d1
        cmpi.w #3,d1
        bne.s M4ColourLevelViewDepth
M4ColourLevelViewFound:
        move.b d1,M4_MESH_LEVEL
        movea.l M4_GEO_CURRENT,a1
        lea M4_MESH_LIGHT,a0
        moveq #2,d4
M4ColourViewLightRow:
        moveq #0,d3
        moveq #2,d2
M4ColourViewLightTerm:
        move.w (a1)+,d0
        muls.w #$49e5,d0
        asr.l #8,d0
        asr.l #7,d0 ;fq(mat_ij,$49E5)
        add.w d0,d3
        dbra d2,M4ColourViewLightTerm
        asr.w #8,d3
        move.w d3,(a0)+
        dbra d4,M4ColourViewLightRow
        bra M4ColourSetupDone

; a1 face record, a3 colour table -> d0 HL. Preserves other registers.
M4FaceColour:
        movem.l d1-d3/a0,-(sp)
        move.w 4(a1),d0
        add.w d0,d0
        move.w (a3,d0.w),d0
        lea M4ColourPool,a0
        adda.w d0,a0
        move.b (a0)+,d0
        beq.s M4FaceColourFixed
        cmpi.b #1,d0
        beq.s M4FaceColourDepth
        cmpi.b #2,d0
        beq M4FaceColourLit
        cmpi.b #4,d0
        beq.s M4FaceColourTex
        cmpi.b #5,d0
        beq.s M4FaceColourTexAnim
        cmpi.b #6,d0
        beq.s M4FaceColourAnimDepth
        move.b (a0)+,d1 ;animated: n frames
        subq.b #1,d1
        and.b M4_MESH_COLFRAME,d1
        andi.w #255,d1
        move.b (a0,d1.w),d0
        bra.w M4FaceColourDone
M4FaceColourFixed:
        move.b (a0),d0
        bra.w M4FaceColourDone
; 6, n, n HL (as type 3), n rows L0..L3: row colframe & (n - 1), column depth
; level (material 54 of boss1, build/agent-boss1/BOSS1.md 3).
M4FaceColourAnimDepth:
        moveq #0,d1
        move.b (a0)+,d1
        move.w d1,d2
        subq.b #1,d1
        and.b M4_MESH_COLFRAME,d1
        lsl.w #2,d1
        add.w d2,d1
        moveq #0,d2
        move.b M4_MESH_LEVEL,d2
        add.w d2,d1
        move.b (a0,d1.w),d0
        bra.w M4FaceColourDone
; Textured material (generate-svp-texpoly.py): $8000 | index of SVP_TexMaterials
; (fixed, or the colframe & (n - 1) frame of an animated list, 01:90AA).
M4FaceColourTex:
        moveq #0,d0
        move.b (a0),d0
        bra.s M4FaceColourTexDone
M4FaceColourTexAnim:
        move.b (a0)+,d1
        subq.b #1,d1
        and.b M4_MESH_COLFRAME,d1
        andi.w #255,d1
        moveq #0,d0
        move.b (a0,d1.w),d0
M4FaceColourTexDone:
        ori.w #$8000,d0
        movem.l (sp)+,d1-d3/a0
        rts
M4FaceColourDepth:
        moveq #0,d1
        move.b M4_MESH_LEVEL,d1
        move.b 1(a0,d1.w),d0
        bra.s M4FaceColourDone
M4FaceColourLit:
        ; MULT 8x8 signed with L, 16-bit sum; s=floor(dot/1024) clamped6..15
        move.w M4_MESH_NORMAL,d1 ;dot = sum s8(normal_i) * light_i (16-bit)
        lea M4_MESH_LIGHT,a0
        move.w (a1,d1.w),d0
        ext.w d0
        muls.w (a0)+,d0
        move.w d0,d3
        move.w 2(a1,d1.w),d0
        ext.w d0
        muls.w (a0)+,d0
        add.w d0,d3
        move.w 4(a1,d1.w),d0
        ext.w d0
        muls.w (a0),d0
        add.w d0,d3
        asr.w #2,d3
        asr.w #8,d3
        cmpi.w #6,d3
        bge.s M4FaceColourHigh
        moveq #6,d3
M4FaceColourHigh:
        cmpi.w #15,d3
        ble.s M4FaceColourRow
        moveq #15,d3
M4FaceColourRow:
        subq.w #6,d3
        moveq #0,d1
        move.b M4_MESH_LEVEL,d1
        mulu.w #10,d1
        add.w d1,d3
        move.w 4(a1),d0
        add.w d0,d0
        move.w (a3,d0.w),d0
        lea M4ColourPool+2,a0
        adda.w d0,a0
        move.b (a0,d3.w),d0
M4FaceColourDone:
        andi.w #255,d0
        movem.l (sp)+,d1-d3/a0
        rts

M4DepthNormal:
        include '../build/m4-depth-normal.inc' ;03:8FAA
M4DepthOffset1:
        include '../build/m4-depth-offset1.inc' ;03:8F9A, depthoffset1
M4DepthStage1:
        include '../build/m4-depth-stage1.inc' ;03:8FB6 set_zdepthtable stage1 (Corneria 1_1c)
        even

; SVP jobs (cmd12, tools/generate-svp-bsp.py). The SVP walks the same BSP in the same order, tests the
; same visibility, computes the same colours and writes the same 32-byte packets as M4FastFacesBegin/
; M4FastNode/M4FastGroup/M4FastFace/M4FaceColour below, from one 16-WORD job per mesh object. Jobs fill the
; face array from its END, job j at M4_FACE_INPUT+(511-j)*32, in draw order; sprites, particles and the
; radio/text records are verbatim 32-byte jobs. SVP mode counts jobs in M4_FACE_COUNT.
; d0 = slot -> a2 = its 32-byte address (clobbers d0).
M4FaceSlot:
        lsl.w #5,d0
        tst.b M4_BSP_SVP
        bne.s M4FaceSlotJob
        lea M4_FACE_INPUT,a2
        adda.w d0,a2
        rts
M4FaceSlotJob:
        lea M4_FACE_INPUT+16352,a2
        suba.w d0,a2
        rts

; d1 = 1 BSP walk (M4_MESH_BSP/GROUPS/NODES/STRIDE) | 2 face list (a1 list, d2 bytes per record, d3 count-1).
; Job words: 0 type, 1 object index, 2 colframe|$100 explosion|$200 shadow, 3-4 colour table, 5-6 depth
; table bytes, 7-8 BSP/list, 9-10 groups, 11 nodes/count, 12 record WORDs, 13 explosion scale, 14 normal WORD offset.
M4BspJob:
        movem.l d0-d7/a0-a6,-(sp)
        move.w d1,d6
        move.w M4_MESH_KIND,d5
        movea.l M4_MESH_OBJECT,a4
        movea.l a1,a6
        move.w M4_FACE_COUNT,d0
        cmpi.w #512,d0
        bhs M4BspJobFull
        bsr M4FaceSlot
        addq.w #1,M4_FACE_COUNT
        movea.l a2,a5
        move.w #$8001,d0
        cmpi.w #2,d6
        bne.s M4BspJobType
        move.w #$8002,d0
M4BspJobType:
        move.w d0,(a5)
        move.l M4_GEO_CURRENT,d0
        subi.l #M4_GEO_OUTPUT,d0
        lsr.l #8,d0
        lsr.l #2,d0 ;object index of this tick's SVP9 output
        move.w d0,2(a5)
        bsr M4MeshColourPrefix ;a3 = colour table, M4_MESH_NORMAL, M4_MESH_COLFRAME
        if def(M4_PROFILE)
        move.l d0,-(sp)
        moveq #4,d0 ;slot 4: colour table (profile slots: tools/measure-level-profile.py)
        jsr M4ProfMark
        move.l (sp)+,d0
        endif
        moveq #0,d0
        move.b M4_MESH_COLFRAME,d0
        cmpi.w #2,d5
        beq.s M4BspJobExplosion
        cmpi.w #18,d5
        beq.s M4BspJobExplosion
        cmpi.w #10,d5
        bne.s M4BspJobMode
M4BspJobExplosion:
        ori.w #$100,d0
M4BspJobMode:
        tst.w M4_GEO_VIEW
        beq.s M4BspJobNoShadow
        tst.b 50(a4) ;level shadow proxy: CMODE 2, COLOR $09, no material (01:9063)
        beq.s M4BspJobNoShadow
        ori.w #$200,d0
M4BspJobNoShadow:
        move.w d0,4(a5)
        move.l a3,6(a5)
        tst.w M4_GEO_VIEW ;depth table of the colour level (M4ColourBigZ / M4ColourLevelView)
        bne.s M4BspJobDepthView
        lea M4DepthNormal,a1
        cmpi.w #5,d5
        blo.s M4BspJobDepth
        cmpi.w #8,d5
        bhs.s M4BspJobDepth
        lea M4DepthOffset1,a1
        bra.s M4BspJobDepth
M4BspJobDepthView:
        movea.l M4_SC_DEPTH,a1
        tst.b X_DEPTHOFF(a4)
        beq.s M4BspJobDepth
        lea M4DepthOffset1,a1
M4BspJobDepth:
        move.l (a1),10(a5)
        cmpi.w #2,d6
        beq.s M4BspJobList
        move.l M4_MESH_BSP,14(a5)
        move.l M4_MESH_GROUPS,18(a5)
        move.w M4_MESH_NODES,22(a5)
        move.w M4_MESH_STRIDE,d0
        bra.s M4BspJobStride
M4BspJobList:
        move.l a6,14(a5)
        clr.l 18(a5)
        addq.w #1,d3
        move.w d3,22(a5)
        move.w d2,d0
M4BspJobStride:
        lsr.w #1,d0
        move.w d0,24(a5)
        moveq #0,d0
        move.b 19(a4),d0
        move.w d0,26(a5)
        move.w M4_MESH_NORMAL,d0
        lsr.w #1,d0
        move.w d0,28(a5)
        clr.w 30(a5)
        if def(M4_PROFILE)
        move.l d0,-(sp)
        moveq #5,d0 ;slot 5: the job words
        jsr M4ProfMark
        move.l (sp)+,d0
        endif
        movem.l (sp)+,d0-d7/a0-a6
        rts
M4BspJobFull:
        move.w #$E204,M4_MESH_ERROR ;error site 4: no job slot, as a full face array
        movem.l (sp)+,d0-d7/a0-a6
        rts

; SVP path: same original BSP order and 32-byte packets as M4MeshNode/Group/
; Face + M4IntroGeometryFace, with state held in registers instead of a full
; movem per node/group/face. CPU reference keeps the routines below.
; a1 face/list, a2 VIS, a3 materials, a4 object, a5 BSP, a6 next packet,
; d2 stride, d3 list count-1, d4 geometry WORD pointer, d5 kind,
; d6 colour mode (bit0 effect byte, bit1 fixed14, bit8 explosion, bit9 shadow), d7 capacity.
M4FastFacesBegin:
        lea M4_MESH_VIS,a2
        movea.l M4_MESH_MATERIALS,a3
        movea.l M4_MESH_OBJECT,a4
        movea.l M4_MESH_BSP,a5
        move.w M4_MESH_STRIDE,d2
        move.l M4_GEO_CURRENT,d4
        subi.l #$300000,d4
        lsr.l #1,d4
        move.w M4_MESH_KIND,d5
        bsr M4MeshColourSetup ;a3 = original colour table, level/light/colframe
        if def(M4_PROFILE)
        addq.l #1,M4_PROF+52 ;objects through the fast faces
        endif
        if def(M4_PROFILE)
        move.l d0,-(sp)
        moveq #4,d0
        jsr M4ProfMark
        move.l (sp)+,d0
        endif
        moveq #0,d6
        cmpi.w #2,d5
        beq.s M4FastModeExplosion
        cmpi.w #18,d5
        beq.s M4FastModeExplosion
        cmpi.w #10,d5
        bne.s M4FastModeDone
M4FastModeExplosion:
        ori.w #$100,d6
M4FastModeDone:
        tst.w M4_GEO_VIEW
        beq.s M4FastModeNoShadow
        tst.b 50(a4) ;level shadow proxy: CMODE 2, COLOR $09, no material (01:9063)
        beq.s M4FastModeNoShadow
        ori.w #$200,d6
M4FastModeNoShadow:
        move.w M4_FACE_COUNT,d0
        move.w #512,d7
        sub.w d0,d7
        lsl.w #5,d0
        lea M4_FACE_INPUT,a6
        adda.w d0,a6
        rts

M4FastFacesEnd:
        if def(M4_PROFILE)
        move.l d0,-(sp)
        moveq #5,d0
        jsr M4ProfMark
        move.l (sp)+,d0
        endif
        move.w #512,d0
        sub.w d7,d0
        move.w d0,M4_FACE_COUNT
        bra M4MeshExit

M4FastNode:
        if def(M4_PROFILE)
        addq.l #1,M4_PROF+48 ;BSP nodes visited
        endif
        cmp.w M4_MESH_NODES,d0
        bhs.s M4FastNodeBad
        add.w d0,d0
        move.w d0,d1
        lsl.w #2,d0
        add.w d1,d0 ; ten-byte nodes
        lea (a5,d0.w),a0
        move.w (a0),d1
        cmpi.w #40,d1
        beq.s M4FastNodeSplit
        cmpi.w #64,d1
        beq.s M4FastNodeReturn
        cmpi.w #68,d1
        bne.s M4FastNodeBad
        move.w 4(a0),d0
        bra.s M4FastGroup
M4FastNodeSplit:
        move.w 2(a0),d1
        move.l a0,-(sp)
        tst.b (a2,d1.w)
        beq.s M4FastNodeInvisible
        move.w 6(a0),d0
        bsr.s M4FastNode
        movea.l (sp),a0
        move.w 4(a0),d0
        bsr.s M4FastGroup
        movea.l (sp)+,a0
        move.w 8(a0),d0
        bpl.s M4FastNode
M4FastNodeReturn:
        rts
M4FastNodeInvisible:
        move.w 8(a0),d0
        bmi.s M4FastNodeLeft
        bsr.s M4FastNode
M4FastNodeLeft:
        movea.l (sp)+,a0
        move.w 6(a0),d0
        bra.s M4FastNode
M4FastNodeBad:
        move.w #$E203,M4_MESH_ERROR ;error site 3
        rts

M4FastGroup:
        movea.l M4_MESH_GROUPS,a0
        add.w d0,d0
        add.w d0,d0
        movea.l (a0,d0.w),a1
        move.w (a1)+,d3
        subq.w #1,d3
        bmi.s M4FastListEnd ;an empty group (level shape 119 group 5): dbra from -1 would run 65536 faces
M4FastList:
        bsr.s M4FastFace
        adda.w d2,a1
        dbra d3,M4FastList
M4FastListEnd:
        rts

M4FastFace:
        if def(M4_PROFILE)
        addq.l #1,M4_PROF+40 ;faces tested
        endif
        move.w 2(a1),d0
        cmpi.w #255,d0
        beq.s M4FastFaceVisible
        tst.b (a2,d0.w)
        beq.s M4FastFaceReturn
M4FastFaceVisible:
        tst.w d7 ;errors are reported at the end of the object (fatal)
        beq.s M4FastFaceBad
        move.w (a1),d1
        subq.w #2,d1
        cmpi.w #6,d1
        bhi.s M4FastFaceBad
        btst #9,d6
        beq.s M4FastFaceMaterial
        moveq #$09,d0
        bra.s M4FastFaceShadow
M4FastFaceMaterial:
        bsr M4FaceColour
M4FastFaceShadow:
        if def(M4_PROFILE)
        addq.l #1,M4_PROF+44 ;face records written
        endif
M4FastFaceColour:
        move.w (a1),(a6)+
        move.w d0,(a6)+
        move.w d4,(a6)+
        move.w d5,(a6)+
        btst #8,d6
        bne.s M4FastFaceExplosion
        clr.l (a6)+
        clr.l (a6)+
        bra.s M4FastFaceIndices
M4FastFaceExplosion:
        moveq #0,d0
        move.b 19(a4),d0
        move.w d0,(a6)+
        move.l 14(a1),(a6)+
        move.w 18(a1),(a6)+
M4FastFaceIndices:
        lea 6(a1),a0
        move.w d1,d0
        addq.w #1,d0
M4FastFaceIndex:
        move.w (a0)+,(a6)
        lsr.w (a6)+ ; byte vertex offset6*v -> WORD offset3*v
        dbra d0,M4FastFaceIndex
        moveq #5,d0
        sub.w d1,d0
        bmi.s M4FastFaceDone
M4FastFaceClear:
        clr.w (a6)+
        dbra d0,M4FastFaceClear
M4FastFaceDone:
        subq.w #1,d7
M4FastFaceReturn:
        rts
M4FastFaceBad:
        move.w #$E204,M4_MESH_ERROR ;error site 4
        rts

M4MeshNode:
        movem.l d0-d7/a0-a6,-(sp)
        cmp.w M4_MESH_NODES,d0
        bhs.s M4MeshNodeBad
        mulu.w #10,d0
        movea.l M4_MESH_BSP,a4
        adda.w d0,a4
        cmpi.w #64,(a4)
        beq M4MeshNodeExit
        cmpi.w #68,(a4)
        beq.s M4MeshNodeLeaf
        cmpi.w #40,(a4)
        bne.s M4MeshNodeBad
        move.w 2(a4),d0
        lea M4_MESH_VIS,a0
        tst.b (a0,d0.w)
        beq.s M4MeshNodeInvisible
        move.w 6(a4),d0
        bsr M4MeshNode
        move.w 4(a4),d0
        bsr M4MeshGroup
        move.w 8(a4),d0
        bmi.s M4MeshNodeExit
        bsr M4MeshNode
        bra.s M4MeshNodeExit
M4MeshNodeInvisible:
        move.w 8(a4),d0
        bmi.s M4MeshNodeLeft
        bsr M4MeshNode
M4MeshNodeLeft:
        move.w 6(a4),d0
        bsr M4MeshNode
        bra.s M4MeshNodeExit
M4MeshNodeLeaf:
        move.w 4(a4),d0
        bsr M4MeshGroup
        bra.s M4MeshNodeExit
M4MeshNodeBad:
        move.w #$E205,M4_MESH_ERROR ;error site 5
M4MeshNodeExit:
        movem.l (sp)+,d0-d7/a0-a6
        rts

M4MeshGroup:
        movem.l d0-d7/a0-a6,-(sp)
        lsl.w #2,d0
        movea.l M4_MESH_GROUPS,a4
        movea.l (a4,d0.w),a4
        move.w (a4)+,d7
        subq.w #1,d7
M4MeshGroupNext:
        bsr M4MeshFace
        adda.w M4_MESH_STRIDE,a4
        dbra d7,M4MeshGroupNext
        movem.l (sp)+,d0-d7/a0-a6
        rts

M4MeshFace:
        movem.l d0-d7/a0-a6,-(sp)
        tst.w M4_MESH_ERROR
        bne M4MeshFaceExit
        move.w 2(a4),d0
        cmpi.w #255,d0
        beq.s M4MeshFaceVisible
        lea M4_MESH_VIS,a0
        tst.b (a0,d0.w)
        beq M4MeshFaceExit
M4MeshFaceVisible:
        cmpi.w #12,M4_MESH_KIND
        bhs.s M4MeshShipMaterial
        cmpi.w #10,M4_MESH_KIND
        bhs.s M4MeshEffectMaterial
        cmpi.w #5,M4_MESH_KIND
        bhs.s M4MeshShipMaterial
        cmpi.w #2,M4_MESH_KIND
        bhs.s M4MeshEffectMaterial
        tst.w M4_MESH_KIND
        beq.s M4MeshShipMaterial
        move.b #14,M4_MESH_COLOUR ; first original Ebullet material colourE
        bra.s M4MeshMaterialReady
M4MeshEffectMaterial:
        move.w 4(a4),d0
        move.b d0,M4_MESH_COLOUR
        bra.s M4MeshMaterialReady
M4MeshShipMaterial:
        move.w 4(a4),d0
        movea.l M4_MESH_MATERIALS,a0
        move.b (a0,d0.w),M4_MESH_COLOUR
M4MeshMaterialReady:
        bsr M4IntroGeometryFace
        bra M4MeshFaceExit
        move.w (a4),d6
        lea 6(a4),a3
        lea M4_MESH_CLIP_A,a1
        move.w d6,d7
        subq.w #1,d7
M4MeshFaceCopy:
        lea M4_MESH_VERTS,a0
        move.w (a3)+,d0
        adda.w d0,a0
        move.l (a0)+,(a1)+
        move.w (a0),(a1)+
        dbra d7,M4MeshFaceCopy
        cmpi.w #2,M4_MESH_KIND
        bne.s M4MeshFaceOffsetReady
        bsr M4EffectFaceOffset
M4MeshFaceOffsetReady:
        lea M4_MESH_CLIP_A,a0
        lea M4_MESH_CLIP_B,a1
        move.w d6,d0
        moveq #4,d1
        moveq #32,d2 ; visual near plane, state and event logic unaffected
        moveq #1,d3
        bsr M4MeshClipPlane
        tst.w d0
        beq M4MeshFaceExit
        move.w d0,d6
        exg a0,a1
        movea.l a0,a2
        subq.w #1,d0
        move.w d0,d7
        moveq #0,d3 ; OR of projected outcodes: zero => fully inside
        moveq #15,d4 ; AND: nonzero => outside a common screen plane
M4MeshProjectVertex:
        moveq #0,d5
        move.w 4(a2),d1
        move.w (a2),d0
        ext.l d0
        lsl.l #8,d0
        divs.w d1,d0
        bvs M4MeshFaceBad
        addi.w #128,d0
        move.w d0,(a2)
        tst.w d0
        bpl.s M4MeshProjectRight
        ori.w #1,d5
        bra.s M4MeshProjectY
M4MeshProjectRight:
        cmpi.w #255,d0
        ble.s M4MeshProjectY
        ori.w #2,d5
M4MeshProjectY:
        move.w 2(a2),d0
        ext.l d0
        lsl.l #8,d0
        divs.w d1,d0
        bvs M4MeshFaceBad
        addi.w #112,d0
        move.w d0,2(a2)
        tst.w d0
        bpl.s M4MeshProjectBottom
        ori.w #4,d5
        bra.s M4MeshProjectOutcode
M4MeshProjectBottom:
        cmpi.w #223,d0
        ble.s M4MeshProjectOutcode
        ori.w #8,d5
M4MeshProjectOutcode:
        or.w d5,d3
        and.w d5,d4
        lea 6(a2),a2
        dbra d7,M4MeshProjectVertex
        tst.w d4
        bne M4MeshFaceExit
        move.w d6,d0
        tst.w d3
        beq.s M4MeshScreenClipped ; same original vertex order, no intersections
        move.w d6,d0
        moveq #0,d1
        moveq #0,d2
        moveq #1,d3
        bsr M4MeshClipPlane
        exg a0,a1
        move.w #255,d2
        moveq #0,d3
        bsr M4MeshClipPlane
        exg a0,a1
        moveq #2,d1
        moveq #0,d2
        moveq #1,d3
        bsr M4MeshClipPlane
        exg a0,a1
        move.w #223,d2
        moveq #0,d3
        bsr M4MeshClipPlane
        exg a0,a1
M4MeshScreenClipped:
        cmpi.w #2,d0
        blo M4MeshFaceExit
        move.w d0,d6
        cmpi.w #2,(a4)
        bne.s M4MeshPolygon
        lea 6(a0),a2
        subq.w #2,d6
M4MeshLineDistinct:
        move.l (a0),d0
        cmp.l (a2),d0
        bne.s M4MeshLineReady
        lea 6(a2),a2
        dbra d6,M4MeshLineDistinct
        bra M4MeshFaceExit
M4MeshLineReady:
        moveq #2,d0
        bsr M4MeshReserve
        tst.w d0
        bne M4MeshFaceExit
        move.l (a0),2(a1)
        move.l (a2),6(a1)
        clr.l 10(a1)
        bra.s M4MeshPrimitiveColour
M4MeshPolygon:
        subq.w #3,d6
        bmi M4MeshFaceExit
        lea 6(a0),a2
        lea 12(a0),a3
M4MeshTriangle:
        move.w (a2),d0
        sub.w (a0),d0
        move.w 2(a3),d1
        sub.w 2(a0),d1
        muls.w d1,d0
        move.w (a3),d1
        sub.w (a0),d1
        move.w 2(a2),d2
        sub.w 2(a0),d2
        muls.w d2,d1
        sub.l d1,d0
        beq.s M4MeshTriangleNext
        move.l d0,d5
        moveq #3,d0
        bsr M4MeshReserve
        tst.w d0
        bne M4MeshFaceExit
        move.l (a0),2(a1)
        tst.l d5
        bmi.s M4MeshTriangleReverse
        move.l (a2),6(a1)
        move.l (a3),10(a1)
        bra.s M4MeshTriangleColour
M4MeshTriangleReverse:
        move.l (a3),6(a1)
        move.l (a2),10(a1)
M4MeshTriangleColour:
        moveq #0,d0
        move.b M4_MESH_COLOUR,d0
        move.w d0,14(a1)
M4MeshTriangleNext:
        lea 6(a2),a2
        lea 6(a3),a3
        dbra d6,M4MeshTriangle
        bra.s M4MeshFaceExit
M4MeshPrimitiveColour:
        moveq #0,d0
        move.b M4_MESH_COLOUR,d0
        move.w d0,14(a1)
        bra.s M4MeshFaceExit
M4MeshFaceBad:
        move.w #$E206,M4_MESH_ERROR ;error site 6
M4MeshFaceExit:
        movem.l (sp)+,d0-d7/a0-a6
        rts

; Reserve a primitive without silently truncating. d0=type; a1=output.
M4MeshReserve:
        move.w M4_POLY_COUNT,d4
        cmpi.w #256,d4
        bhs.s M4MeshReserveBad
        lsl.w #4,d4
        lea M4_POLY_INPUT,a1
        adda.w d4,a1
        move.w d0,(a1)
        addq.w #1,M4_POLY_COUNT
        moveq #0,d0
        rts
M4MeshReserveBad:
        move.w #$E207,M4_MESH_ERROR ;error site 7
        moveq #-5,d0 ;error code
        rts

; Convex Sutherland clipping. d0=count, d1=axis offset0/2/4,d2=boundary,
; d3=1 keeps>=boundary,0 keeps<=. a0=input,a1=output,16 entries of XYZ WORD.
; Signed division truncates toward0; intersection's clipping axis is exact.
; Returns d0=count; preserves other regs/inputs. Bounds checked, no clipping
; is used as a substitute for the original object lifecycle or movement.
M4MeshClipPlane:
        movem.l d1-d7/a0-a6,-(sp)
        tst.w d0
        beq M4MeshClipReturn
        move.w d0,d6
        subq.w #1,d0
        mulu.w #6,d0
        movea.l a0,a2
        adda.w d0,a2
        movea.l a0,a3
        movea.l a1,a4
        moveq #0,d7
M4MeshClipVertex:
        move.w (a2,d1.w),d4
        sub.w d2,d4
        move.w (a3,d1.w),d5
        sub.w d2,d5
        tst.w d3
        bne.s M4MeshClipDistances
        neg.w d4
        neg.w d5
M4MeshClipDistances:
        move.w d4,d0
        eor.w d5,d0
        bpl M4MeshClipCurrent
        cmpi.w #16,d7
        bhs M4MeshClipBad
        movem.l d4-d5,-(sp)
        sub.w d5,d4
        moveq #0,d5
M4MeshIntersectAxis:
        move.w (a3,d5.w),d0
        sub.w (a2,d5.w),d0
        muls.w 2(sp),d0
        divs.w d4,d0
        add.w (a2,d5.w),d0
        move.w d0,(a4)+
        addq.w #2,d5
        cmpi.w #6,d5
        bne.s M4MeshIntersectAxis
        lea -6(a4),a5
        move.w d2,(a5,d1.w)
        movem.l (sp)+,d4-d5
        addq.w #1,d7
M4MeshClipCurrent:
        tst.w d5
        bmi.s M4MeshClipNext
        cmpi.w #16,d7
        bhs.s M4MeshClipBad
        move.l (a3),(a4)+
        move.w 4(a3),(a4)+
        addq.w #1,d7
M4MeshClipNext:
        movea.l a3,a2
        lea 6(a3),a3
        subq.w #1,d6
        bne M4MeshClipVertex
        move.w d7,d0
        bra.s M4MeshClipReturn
M4MeshClipBad:
        move.w #$E208,M4_MESH_ERROR ;error site 8
        moveq #0,d0
M4MeshClipReturn:
        movem.l (sp)+,d1-d7/a0-a6
        rts

; Original MOBJ mexpfacesinit: reverse normalX/Z, rotate, force rotatedY
; negative, signed MULT(count), ASR twice, add this displacement to each
; face vertex. Q15 matrix is the documented MD numeric representation.
M4EffectFaceOffset:
        movem.l d0-d7/a0-a3,-(sp)
        lea M4_MESH_MATRIX,a3
        lea $ff89ec,a1
        moveq #0,d6
M4EffectNormalAxis:
        move.w 14(a4),d0
        neg.w d0
        muls.w (a3),d0
        move.w 16(a4),d1
        muls.w 6(a3),d1
        add.l d1,d0
        move.w 18(a4),d1
        neg.w d1
        muls.w 12(a3),d1
        add.l d1,d0
        addq.l #2,a3 ; next COLUMN of native transposed matrix
        asr.l #8,d0
        asr.l #7,d0
        cmpi.w #2,d6
        bne.s M4EffectNormalScale
        tst.w d0
        bmi.s M4EffectNormalScale
        neg.w d0
M4EffectNormalScale:
        movea.l M4_MESH_OBJECT,a0
        moveq #0,d1
        move.b 19(a0),d1
        muls.w d1,d0
        asr.l #2,d0
        move.w d0,(a1)+
        addq.w #2,d6
        cmpi.w #6,d6
        bne.s M4EffectNormalAxis
        lea M4_MESH_CLIP_A,a0
        move.w (a4),d7
        subq.w #1,d7
M4EffectOffsetVertex:
        lea $ff89ec,a1
        moveq #2,d6
M4EffectOffsetAxis:
        move.w (a1)+,d0
        add.w d0,(a0)+
        dbra d6,M4EffectOffsetAxis
        dbra d7,M4EffectOffsetVertex
        movem.l (sp)+,d0-d7/a0-a3
        rts
