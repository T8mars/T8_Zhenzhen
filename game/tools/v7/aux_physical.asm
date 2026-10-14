AuxEdgeCommand:
 LDA AuxState
 CMP #EDGE_ARM
 BEQ AuxEdgeTryGrab
 CMP #EDGE_HANG
 BEQ AuxEdgeRelease
 CMP #EDGE_CLIMB
 BEQ AuxEdgeRelease
 JSR AuxGroundAvailable
 BEQ AuxEdgeDone
 LDA NpcDir
 STA AuxFacing
 JSR AuxStaticEdge
 BEQ AuxEdgeDone
 JSR AuxClearAction
 LDA #EDGE_ARM
 STA AuxState
 LDA #$78
 STA AuxTimer
 LDA #$01
 STA Stance
AuxEdgeDone:
 RTS
AuxEdgeRelease:
 JMP AuxReleasePlayer
AuxEdgeTryGrab:
 LDA AuxEdgeSpent
 BNE AuxEdgeDone
 LDA $1d
 BEQ AuxEdgeDone
 LDA $9f
 BMI AuxEdgeDone
 JSR AuxStaticEdge
 BEQ AuxEdgeDone
 JSR AuxGetPartnerDelta
 LDA AuxFacing
 CMP #$02
 BEQ AuxEdgePlayerLeft
 LDA TempY
 BNE AuxEdgeDone
 LDA Distance
 CMP #$0c
 BCC AuxEdgeDone
 CMP #$21
 BCS AuxEdgeDone
 JMP AuxEdgePlayerY
AuxEdgePlayerLeft:
 LDA TempY
 CMP #$ff
 BNE AuxEdgeDone
 LDA Distance
 CMP #$e0
 BCC AuxEdgeDone
 CMP #$f5
 BCS AuxEdgeDone
AuxEdgePlayerY:
 LDA $ce
 SEC
 SBC NpcY
 CMP #$19
 BCS AuxEdgeDone
 LDA #EDGE_HANG
 STA AuxState
 LDA #$24
 STA AuxTimer
 LDA #$01
 STA AuxEdgeSpent
 INC EdgeGrabCount
 LDA $ce
 STA AuxPlayerY
 LDA $86
 STA AuxPlayerX
 LDA $6d
 STA AuxPlayerPage
 JSR AuxHoldPlayerVelocity
 JMP AuxCoopTouchSound

AuxStaticEdge:
 ; Static support is read from the native tile buffer, not platform state.
 LDA AuxPlatformOn
 BNE AuxStaticEdgeNo
 JSR AuxGroundAtNpc
 BEQ AuxStaticEdgeNo
 LDA NpcY
 CLC
 ADC #$21
 STA ProbeY
 LDA AuxFacing
 CMP #$02
 BEQ AuxStaticProbeLeft
 LDA NpcX
 CLC
 ADC #$16
 STA ProbeX
 LDA NpcPage
 ADC #$00
 STA ProbePage
 JMP AuxStaticProbe
AuxStaticProbeLeft:
 LDA NpcX
 SEC
 SBC #$06
 STA ProbeX
 LDA NpcPage
 SBC #$00
 STA ProbePage
AuxStaticProbe:
 JSR AuxReadPoint
 JSR AuxIsSolid
 BNE AuxStaticEdgeNo
 LDA #$01
 RTS
AuxStaticEdgeNo:
 LDA #$00
 RTS

AuxTossCommand:
 LDA AuxState
 CMP #LIFT_HOLD
 BEQ AuxAimLift
 LDA AuxLiftSpent
 BNE AuxTossDone
 LDA $1d
 ORA $57
 BNE AuxTossDone
 JSR AuxGroundAvailable
 BEQ AuxTossDone
 JSR AuxNear
 BEQ AuxTossDone
 JSR AuxBodyClear
 BEQ AuxTossDone
 JSR AuxClearAction
 LDA AuxUserRaw
 AND #$03
 STA AuxFacing
 STA NpcDir
 LDA #LIFT_HOLD
 STA AuxState
 LDA #$01
 STA AuxLiftSpent
 LDA #$5a
 STA AuxTimer
 LDA #$08
 STA AuxLiftPhase
 LDA #$00
 STA $06fc
 STA AuxUserRaw
 STA NpcVY
 STA NpcYFrac
 STA NpcGround
 STA AuxLiftReady
 LDA AuxFacing
 STA $33
AuxTossDone:
 RTS
AuxAimLift:
 LDA AuxUserRaw
 AND #$03
 CMP #$01
 BEQ AuxAimFacing
 CMP #$02
 BNE AuxAimMask
AuxAimFacing:
 CMP AuxFacing
 BEQ AuxAimMask
 STA AuxFacing
 STA NpcDir
 STA $33
 LDA #$00
 STA AuxLiftReady
AuxAimMask:
 LDA AuxUserRaw
 AND #$fc
 STA AuxUserRaw
 STA $06fc
 RTS
AuxThrowHeld:
 JSR AuxClearAction
 LDA AuxFacing
 STA NpcDir
 CMP #$02
 BEQ AuxTossLeft
 LDA #$28
 BNE AuxTossVelocity
AuxTossLeft:
 LDA #$d8
AuxTossVelocity:
 STA NpcVX
 LDA #$01
 STA NpcJumpKind
 LDA #$80
 JSR AuxBeginNpcJump
 INC TossCount
 LDA #$00
 STA $06fc
 RTS

AuxBrakeCommand:
 LDA AuxState
 CMP #BRAKE_ARM
 BEQ AuxBrakeGrab
 CMP #BRAKE_ON
 BEQ AuxBrakeRelease
 JSR AuxGroundAvailable
 BEQ AuxBrakeDone
 JSR AuxClearAction
 LDA #BRAKE_ARM
 STA AuxState
 LDA #$78
 STA AuxTimer
 LDA #$01
 STA Stance
AuxBrakeDone:
 RTS
AuxBrakeRelease:
 JMP AuxClearAction
AuxBrakeGrab:
 LDA $1d
 BNE AuxBrakeDone
 JSR AuxNear
 BEQ AuxBrakeDone
 JSR AuxGroundAtNpc
 BEQ AuxBrakeDone
 LDA #BRAKE_ON
 STA AuxState
 LDA #$10
 STA AuxTimer
 INC BrakeGrabCount
 JMP AuxCoopTouchSound

AuxPhysicalPre:
 LDA AuxState
 CMP #EDGE_ARM
 BEQ AuxPhysicalArm
 CMP #BRAKE_ARM
 BEQ AuxPhysicalArm
 CMP #EDGE_HANG
 BEQ AuxPhysicalHanging
 CMP #EDGE_CLIMB
 BEQ AuxPhysicalHanging
 CMP #BRAKE_ON
 BEQ AuxPhysicalBrake
 CMP #LIFT_HOLD
 BEQ AuxPhysicalLift
 CMP #BACK_LOAD
 BEQ AuxPhysicalLoad
 RTS
AuxPhysicalArm:
 LDA AuxTimer
 BEQ AuxPhysicalCancel
 DEC AuxTimer
 JSR AuxGroundAtNpc
 BEQ AuxPhysicalCancel
 JSR AuxNearbyNpcDanger
 BNE AuxPhysicalCancel
 RTS
AuxPhysicalHanging:
 LDA AuxTimer
 BEQ AuxPhysicalRelease
 DEC AuxTimer
 LDA AuxExtraRaw
 AND #$20
 BEQ AuxPhysicalRelease
 JSR AuxGroundAtNpc
 BEQ AuxPhysicalRelease
 JSR AuxNearbyNpcDanger
 BNE AuxPhysicalRelease
 JSR AuxHoldPlayerVelocity
 INC AuxHangTicks
 RTS
AuxPhysicalBrake:
 LDA AuxTimer
 BEQ AuxPhysicalCancel
 DEC AuxTimer
 LDA AuxExtraRaw
 AND #$10
 BEQ AuxPhysicalCancel
 LDA $1d
 BNE AuxPhysicalCancel
 JSR AuxGroundAtNpc
 BEQ AuxPhysicalCancel
 JSR AuxNear
 BEQ AuxPhysicalCancel
 LDA $57
 BEQ AuxPhysicalBrakeTick
 BMI AuxBrakeNegative
 SEC
 SBC #$04
 BCS AuxBrakeStore
 LDA #$00
 BEQ AuxBrakeStore
AuxBrakeNegative:
 CLC
 ADC #$04
 BCC AuxBrakeStore
 LDA #$00
AuxBrakeStore:
 STA $57
AuxPhysicalBrakeTick:
 INC AuxBrakeTicks
 RTS
AuxPhysicalLift:
 LDA AuxTimer
 BEQ AuxPhysicalCancel
 DEC AuxTimer
 LDA AuxUserRaw
 AND #$c3
 BNE AuxPhysicalCancel
 LDA $1d
 BNE AuxPhysicalCancel
 JSR AuxNearbyNpcDanger
 BNE AuxPhysicalCancel
 RTS
AuxPhysicalLoad:
 LDA AuxGlideTimer
 BEQ AuxPhysicalCancel
 LDA NewInput
 AND #$20
 BNE AuxPhysicalCancel
 JSR AuxNearbyNpcDanger
 BNE AuxPhysicalCancel
 RTS
AuxPhysicalRelease:
 JMP AuxReleasePlayer
AuxPhysicalCancel:
 JMP AuxClearAction

AuxHoldPlayerVelocity:
 LDA #$00
 STA $9f
 STA $0433
 STA $0416
 STA $57
 STA $0705
 RTS
AuxReleasePlayer:
 JSR AuxClearAction
 LDA #$01
 STA $9f
 LDA #$02
 STA $1d
 RTS

AuxHeldPhysics:
 LDA AuxState
 CMP #BACK_LOAD
 BEQ AuxLoadFollow
 LDA AuxLiftPhase
 BEQ AuxLiftTurn
 LDA NpcY
 STA AuxTemp
 DEC NpcY
 JSR AuxBodyClear
 BNE AuxLiftStepAccepted
 LDA AuxTemp
 STA NpcY
 JMP AuxClearAction
AuxLiftStepAccepted:
 DEC AuxLiftPhase
 JMP AuxLiftTurn
AuxHeldDone:
 RTS
AuxLiftTurn:
 LDA AuxFacing
 CMP #$02
 BEQ AuxLiftGoalLeft
 LDA $86
 CLC
 ADC #$14
 STA AuxLiftGoalX
 LDA $6d
 ADC #$00
 STA AuxLiftGoalPage
 JMP AuxLiftGoalReady
AuxLiftGoalLeft:
 LDA $86
 SEC
 SBC #$14
 STA AuxLiftGoalX
 LDA $6d
 SBC #$00
 STA AuxLiftGoalPage
AuxLiftGoalReady:
 LDA NpcX
 CMP AuxLiftGoalX
 BNE AuxLiftMove
 LDA NpcPage
 CMP AuxLiftGoalPage
 BNE AuxLiftMove
 LDA AuxLiftPhase
 BNE AuxHeldDone
 LDA #$01
 STA AuxLiftReady
 RTS
AuxLiftMove:
 JSR AuxSaveNpcCoordinates
 LDA NpcX
 SEC
 SBC AuxLiftGoalX
 LDA NpcPage
 SBC AuxLiftGoalPage
 BMI AuxLiftMoveRight
 LDA #$ff
 BNE AuxLiftMoveChosen
AuxLiftMoveRight:
 LDA #$01
AuxLiftMoveChosen:
 STA DeltaX
 LDA Stance
 STA AuxCarryStance
 LDA #$01
 STA Stance
 JSR AuxMoveHorizontal
 LDA AuxCarryStance
 STA Stance
 JSR AuxLoweringExit
 BNE AuxHeldDone
 JSR AuxRestoreNpcCoordinates
 RTS
AuxLoweringExit:
 ; Every held location must retain a legal continuous lowering route.
 LDA NpcY
 STA AuxLowerSavedY
 LDA $ce
 SEC
 SBC NpcY
 CMP #$09
 BCS AuxLoweringNo
AuxLoweringLoop:
 LDA NpcY
 CMP $ce
 BEQ AuxLoweringFloor
 INC NpcY
 JSR AuxBodyClear
 BEQ AuxLoweringNo
 JMP AuxLoweringLoop
AuxLoweringFloor:
 JSR AuxGroundAtNpc
 BEQ AuxLoweringNo
 LDA AuxLowerSavedY
 STA NpcY
 LDA #$01
 RTS
AuxLoweringNo:
 LDA AuxLowerSavedY
 STA NpcY
 LDA #$00
 RTS
AuxLoadFollow:
 ; Carry only the measured player displacement, with native terrain probes.
 LDA $86
 SEC
 SBC AuxPlayerX
 STA DeltaX
 LDA $6d
 SBC AuxPlayerPage
 BEQ AuxLoadPositiveDelta
 CMP #$ff
 BNE AuxLoadInvalid
 LDA DeltaX
 BPL AuxLoadInvalid
 JMP AuxLoadDeltaReady
AuxLoadPositiveDelta:
 LDA DeltaX
 BMI AuxLoadInvalid
AuxLoadDeltaReady:
 LDA DeltaX
 CLC
 ADC #$04
 CMP #$09
 BCS AuxLoadInvalid
 JSR AuxMoveHorizontal
 LDA $ce
 SEC
 SBC AuxPlayerY
 STA DeltaY
 CLC
 ADC #$04
 CMP #$09
 BCS AuxLoadInvalid
 JSR AuxMoveVertical
 LDA $86
 STA AuxPlayerX
 LDA $6d
 STA AuxPlayerPage
 LDA $ce
 STA AuxPlayerY
 RTS
AuxLoadInvalid:
 JMP AuxClearAction

AuxPhysicalPost:
 LDA AuxState
 CMP #BACK_LOAD
 BEQ AuxLateBackCarry
 LDA AuxGlideTimer
 BEQ AuxPostNoGlide
 JSR AuxGlideContact
AuxPostNoGlide:
 RTS
AuxLateBackCarry:
 LDA $1d
 BEQ AuxBackCarryLanded
 LDA AuxGlideTimer
 BEQ AuxBackCarryLanded
 JMP AuxHeldPhysics
AuxBackCarryLanded:
 JMP AuxClearAction

AuxTerrain:
 LDA AuxState
 CMP #EDGE_HANG
 BEQ AuxTerrainHang
 CMP #EDGE_CLIMB
 BEQ AuxTerrainHang
 RTS
AuxTerrainHang:
 ; Restore the physical hand constraint, then move continuously through space.
 LDA AuxPlayerY
 STA $ce
 LDA AuxPlayerX
 STA $86
 LDA AuxPlayerPage
 STA $6d
 LDA AuxUserRaw
 AND #$08
 BEQ AuxTerrainDone
 LDA AuxState
 CMP #EDGE_CLIMB
 BEQ AuxClimbChoiceReady
 LDA #EDGE_CLIMB
 STA AuxState
 LDA #$20
 STA AuxTimer
AuxClimbChoiceReady:
 LDA $ce
 CMP NpcY
 BCC AuxClimbHeightReady
 DEC $ce
 JSR AuxPlayerClear
 BNE AuxClimbUpAccepted
 INC $ce
 RTS
AuxClimbUpAccepted:
 LDA $ce
 STA AuxPlayerY
 CMP NpcY
 BCS AuxTerrainDone
AuxClimbHeightReady:
 LDA $86
 CMP NpcX
 BNE AuxClimbHorizontal
 LDA $6d
 CMP NpcPage
 BNE AuxClimbHorizontal
 INC $ce
 JSR AuxPlayerClear
 BEQ AuxClimbLandingBlocked
 JSR AuxPlayerGround
 BEQ AuxClimbLandingBlocked
 LDA $ce
 STA AuxPlayerY
 INC EdgeClimbCount
 JMP AuxReleasePlayer
AuxClimbLandingBlocked:
 DEC $ce
 RTS
AuxClimbHorizontal:
 LDA AuxFacing
 CMP #$01
 BEQ AuxClimbLeft
 INC $86
 BNE AuxClimbProbe
 INC $6d
 JMP AuxClimbProbe
AuxClimbLeft:
 LDA $86
 BNE AuxClimbDec
 DEC $6d
AuxClimbDec:
 DEC $86
AuxClimbProbe:
 JSR AuxPlayerClear
 BNE AuxClimbXAccepted
 LDA AuxPlayerX
 STA $86
 LDA AuxPlayerPage
 STA $6d
 RTS
AuxClimbXAccepted:
 LDA $86
 STA AuxPlayerX
 LDA $6d
 STA AuxPlayerPage
AuxTerrainDone:
 RTS

AuxPlayerClear:
 JSR AuxSaveNpcCoordinates
 JSR AuxUsePlayerCoordinates
 JSR AuxBodyClear
 PHA
 JSR AuxRestoreNpcCoordinates
 PLA
 RTS
AuxPlayerGround:
 JSR AuxSaveNpcCoordinates
 JSR AuxUsePlayerCoordinates
 JSR AuxGroundAtNpc
 PHA
 JSR AuxRestoreNpcCoordinates
 PLA
 RTS
AuxSaveNpcCoordinates:
 LDA NpcX
 STA AuxSavedX
 LDA NpcPage
 STA AuxSavedPage
 LDA NpcY
 STA AuxSavedY
 RTS
AuxUsePlayerCoordinates:
 LDA $86
 STA NpcX
 LDA $6d
 STA NpcPage
 LDA $ce
 STA NpcY
 RTS
AuxRestoreNpcCoordinates:
 LDA AuxSavedX
 STA NpcX
 LDA AuxSavedPage
 STA NpcPage
 LDA AuxSavedY
 STA NpcY
 RTS

AuxApplyGlide:
 LDA $1d
 BEQ AuxStopGlide
 LDA $9f
 BMI AuxStopGlide
 LDA AuxState
 CMP #BACK_LOAD
 BEQ AuxGlideHeavy
 LDA #$01
 BNE AuxGlideCap
AuxGlideHeavy:
 LDA #$02
AuxGlideCap:
 CMP $9f
 BCS AuxGlideMeasured
 STA $9f
AuxGlideMeasured:
 INC AuxGlideTicks
 RTS
AuxStopGlide:
 LDA #$00
 STA AuxGlideTimer
 RTS
AuxGlideContact:
 LDA $1d
 BEQ AuxGlideContactDone
 LDA $9f
 BMI AuxGlideContactDone
 LDA AuxState
 BNE AuxGlideContactDone
 LDA NpcGround
 ORA Stagger
 ORA HeadOn
 ORA BraceHead
 BNE AuxGlideContactDone
 LDA NpcVY
 BMI AuxGlideContactDone
 JSR AuxGetPartnerDelta
 LDA TempY
 BEQ AuxGlideFromRight
 CMP #$ff
 BNE AuxGlideContactDone
 LDA Distance
 CMP #$f9
 BCC AuxGlideContactDone
 JMP AuxGlideTestHeight
AuxGlideFromRight:
 LDA Distance
 CMP #$08
 BCS AuxGlideContactDone
AuxGlideTestHeight:
 LDX RenderSize
 LDA $ce
 CLC
 ADC AuxHeadOffset,X
 STA AuxTemp
 LDA PrevNpcY
 CLC
 ADC #$20
 CMP AuxTemp
 BCS AuxGlideContactDone
 LDA NpcY
 CLC
 ADC #$20
 CMP AuxTemp
 BCC AuxGlideContactDone
 SEC
 SBC AuxTemp
 CMP #$07
 BCS AuxGlideContactDone
 LDA AuxTemp
 SEC
 SBC #$20
 STA NpcY
 LDA #BACK_LOAD
 STA AuxState
 LDA #$00
 STA NpcVY
 STA NpcVX
 STA NpcGround
 LDA $86
 STA AuxPlayerX
 LDA $6d
 STA AuxPlayerPage
 LDA $ce
 STA AuxPlayerY
 INC GlideLoadCount
AuxGlideContactDone:
 RTS
AuxHeadOffset:
.byte $00,$10,$08
