AuxPre:
 LDA AuxPlayerPose
 BEQ AuxPreFan
 DEC AuxPlayerPose
 LDA AuxUserRaw
 AND #$c3
 BEQ AuxPreFan
 LDA #$00
 STA AuxPlayerPose
AuxPreFan:
 LDA AuxFanTimer
 BEQ AuxPreGlide
 DEC AuxFanTimer
 JSR AuxFanContact
AuxPreGlide:
 LDA AuxGlideTimer
 BEQ AuxPreBudget
 DEC AuxGlideTimer
 JSR AuxApplyGlide
 LDA AuxExtraRaw
 AND #$10
 BNE AuxPreBudget
 LDA #$00
 STA AuxGlideTimer
AuxPreBudget:
 LDA $1d
 ORA HeadOn
 BNE AuxPreState
 JSR AuxGroundAtNpc
 BEQ AuxPreState
 LDA AuxState
 BNE AuxPreState
 LDA #$00
 STA AuxLiftSpent
 STA AuxEdgeSpent
 STA AuxFanSpent
AuxPreState:
 LDA AuxState
 BEQ AuxPreDone
 CMP #BALL_READY
 BEQ AuxPreReady
 CMP #BALL_ROLL
 BEQ AuxPreRoll
 CMP #FAN_HIDE
 BEQ AuxPreTimed
 CMP #BACK_POSE
 BEQ AuxPreTimed
 JSR AuxPhysicalPre
 JMP AuxPreDone
AuxPreReady:
 JSR AuxGroundAtNpc
 BEQ AuxPreCancel
 JMP AuxPreDone
AuxPreRoll:
 LDA DashTimer
 BEQ AuxPreCancel
 LDA AuxTimer
 BEQ AuxPreCancel
 DEC AuxTimer
 LDA Stagger
 BNE AuxPreCancel
 JMP AuxPreDone
AuxPreTimed:
 LDA AuxTimer
 BEQ AuxPreCancel
 DEC AuxTimer
 JSR AuxNearbyNpcDanger
 BNE AuxPreCancel
 JMP AuxPreDone
AuxPreCancel:
 JSR AuxClearAction
AuxPreDone:
 JMP AuxRecomputeLive

AuxSteer:
 LDA AuxManual
 BEQ AuxSteerState
 LDA #$01
 STA AuxHandled
 LDA AuxUserRaw
 AND #$03
 CMP #$01
 BEQ AuxManualRight
 CMP #$02
 BEQ AuxManualLeft
 LDA #$00
 STA NpcVX
 RTS
AuxManualRight:
 LDA #$01
 STA NpcDir
 LDA #$20
 STA NpcVX
 JMP AuxManualBounds
AuxManualLeft:
 LDA #$02
 STA NpcDir
 LDA #$e0
 STA NpcVX
AuxManualBounds:
 LDA NpcX
 SEC
 SBC $071c
 STA AuxTemp
 LDA NpcPage
 SBC $071a
 BNE AuxManualStop
 LDA AuxTemp
 CMP #$08
 BCC AuxManualStop
 CMP #$e0
 BCS AuxManualStop
 RTS
AuxManualStop:
 LDA #$00
 STA NpcVX
 RTS
AuxSteerState:
 LDA AuxState
 BEQ AuxSteerDone
 LDA #$01
 STA AuxHandled
 LDA AuxState
 CMP #BALL_ROLL
 BNE AuxSteerStop
 LDA AuxFacing
 STA NpcDir
 CMP #$02
 BEQ AuxRollLeft
 LDA #$30
 BNE AuxRollSet
AuxRollLeft:
 LDA #$d0
AuxRollSet:
 STA NpcVX
 RTS
AuxSteerStop:
 LDA #$00
 STA NpcVX
AuxSteerDone:
 RTS

AuxPhysics:
 LDA AuxState
 CMP #LIFT_HOLD
 BEQ AuxPhysicsHeld
 CMP #BACK_LOAD
 BEQ AuxPhysicsHeld
 JSR AuxPlatformBefore
 RTS
AuxPhysicsHeld:
 LDA #$01
 STA AuxHandled
 JMP AuxHeldPhysics

AuxPost:
 LDA $0e
 CMP #$08
 BEQ AuxPostPlaying
 JMP AuxReset
AuxPostPlaying:
 JSR AuxPlatformAfter
 JSR AuxPhysicalPost
 LDA AuxState
 BEQ AuxPostDefault
 CMP #BALL_READY
 BEQ AuxPostReady
 CMP #BALL_ROLL
 BEQ AuxPostRoll
 CMP #EDGE_ARM
 BEQ AuxPostEdge
 CMP #EDGE_HANG
 BEQ AuxPostEdge
 CMP #EDGE_CLIMB
 BEQ AuxPostEdge
 CMP #LIFT_HOLD
 BEQ AuxPostLift
 CMP #BACK_POSE
 BEQ AuxPostBack
 CMP #BRAKE_ARM
 BEQ AuxPostBrake
 CMP #BRAKE_ON
 BEQ AuxPostBrake
 CMP #BACK_LOAD
 BEQ AuxPostLoad
 JMP AuxPostDone
AuxPostReady:
 LDA #$01
 BNE AuxPostPose
AuxPostRoll:
 LDA #$02
 BNE AuxPostPose
AuxPostEdge:
 LDA #$04
 BNE AuxPostPose
AuxPostLift:
 LDA #$05
 BNE AuxPostPose
AuxPostBack:
 LDA #$09
 BNE AuxPostPose
AuxPostBrake:
 LDA #$0b
 BNE AuxPostPose
AuxPostLoad:
 LDA #$0c
 BNE AuxPostPose
AuxPostDefault:
 LDA AuxManual
 BEQ AuxPostOrdinary
 LDA #$03
 BNE AuxPostPose
AuxPostOrdinary:
 LDA AuxPlatformOn
 AND Stance
 BEQ AuxPostPlain
 LDA #$0a
 BNE AuxPostPose
AuxPostPlain:
 LDA #$00
AuxPostPose:
 STA AuxPose
AuxPostDone:
 JMP AuxRecomputeLive

AuxEnemy:
 LDA AuxState
 CMP #LIFT_HOLD
 BEQ AuxEnemyHeld
 CMP #BACK_LOAD
 BEQ AuxEnemyHeld
 LDA AuxState
 CMP #BALL_ROLL
 BNE AuxEnemyDone
 LDX SkillSlot
 LDA $16,X
 CMP #$06
 BNE AuxEnemyDone
 JSR AuxEnemyFront
 BEQ AuxEnemyDone
 JSR AuxStompNativeEnemy
 JSR AuxClearAction
 LDA #$01
 STA NpcGround
 STA Stance
 STA AuxHandled
 LDA #$00
 STA NpcVY
 STA NpcJumpKind
 INC BallHitCount
AuxEnemyDone:
 RTS
AuxEnemyHeld:
 LDA #$01
 STA AuxHandled
 RTS
AuxEnemyFront:
 LDA $87,X
 SEC
 SBC NpcX
 STA AuxTemp
 LDA $6e,X
 SBC NpcPage
 STA AuxTempPage
 LDA AuxFacing
 CMP #$02
 BEQ AuxEnemyLeft
 LDA AuxTempPage
 BNE AuxEnemyMiss
 LDA AuxTemp
 CMP #$10
 BCS AuxEnemyMiss
 JMP AuxEnemyY
AuxEnemyLeft:
 LDA AuxTempPage
 CMP #$ff
 BEQ AuxEnemyNegative
 LDA AuxTemp
 BNE AuxEnemyMiss
 BEQ AuxEnemyY
AuxEnemyNegative:
 LDA AuxTemp
 CMP #$f1
 BCC AuxEnemyMiss
AuxEnemyY:
 LDA NpcY
 CLC
 ADC #$20
 SEC
 SBC $cf,X
 CMP #$09
 BCC AuxEnemyMiss
 CMP #$1d
 BCS AuxEnemyMiss
 LDA #$01
 RTS
AuxEnemyMiss:
 LDA #$00
 RTS

AuxFanContact:
 LDA AuxFanHit
 BEQ AuxFanScan
 RTS
AuxFanScan:
 LDA #$ff
 STA AuxBestSlot
 LDA #$20
 STA AuxBest
 LDX #$04
AuxFanScanLoop:
 STX AuxIndex
 LDA $0f,X
 CMP #$01
 BNE AuxFanScanNext
 LDA $16,X
 CMP #$06
 BNE AuxFanScanNext
 LDA $1e,X
 BNE AuxFanScanNext
 LDA $b6,X
 CMP #$01
 BNE AuxFanScanNext
 LDA $87,X
 SEC
 SBC $86
 STA AuxCandidate
 LDA $6e,X
 SBC $6d
 STA AuxTempPage
 LDA AuxFanFacing
 CMP #$02
 BEQ AuxFanScanLeft
 LDA AuxTempPage
 BNE AuxFanScanNext
 LDA AuxCandidate
 CMP #$08
 BCC AuxFanScanNext
 CMP #$1d
 BCS AuxFanScanNext
 JMP AuxFanScanY
AuxFanScanLeft:
 LDA AuxTempPage
 CMP #$ff
 BNE AuxFanScanNext
 LDA AuxCandidate
 EOR #$ff
 CLC
 ADC #$01
 STA AuxCandidate
 CMP #$08
 BCC AuxFanScanNext
 CMP #$1d
 BCS AuxFanScanNext
AuxFanScanY:
 LDA $ce
 CLC
 ADC #$10
 SEC
 SBC $cf,X
 CLC
 ADC #$08
 CMP #$19
 BCS AuxFanScanNext
 LDA AuxCandidate
 CMP AuxBest
 BCS AuxFanScanNext
 STA AuxBest
 STX AuxBestSlot
AuxFanScanNext:
 DEX
 BPL AuxFanScanLoop
 LDX AuxBestSlot
 CPX #$ff
 BNE AuxFanPush
 RTS
AuxFanPush:
 STX AuxIndex
 LDA #$08
 STA AuxTravel
AuxFanPushStep:
 LDX AuxIndex
 LDA $87,X
 STA ProbeX
 LDA $6e,X
 STA ProbePage
 LDA $cf,X
 CLC
 ADC #$08
 STA ProbeY
 LDA AuxFanFacing
 CMP #$02
 BEQ AuxFanProbeLeft
 LDA ProbeX
 CLC
 ADC #$10
 STA ProbeX
 LDA ProbePage
 ADC #$00
 STA ProbePage
 JMP AuxFanProbe
AuxFanProbeLeft:
 DEC ProbeX
 LDA ProbeX
 CMP #$ff
 BNE AuxFanProbe
 DEC ProbePage
AuxFanProbe:
 JSR AuxReadPoint
 JSR AuxIsSolid
 BNE AuxFanPushDone
 LDX AuxIndex
 LDA AuxFanFacing
 CMP #$02
 BEQ AuxFanMoveLeft
 INC $87,X
 BNE AuxFanMoveDone
 INC $6e,X
 JMP AuxFanMoveDone
AuxFanMoveLeft:
 LDA $87,X
 BNE AuxFanMoveLow
 DEC $6e,X
AuxFanMoveLow:
 DEC $87,X
AuxFanMoveDone:
 DEC AuxTravel
 BNE AuxFanPushStep
AuxFanPushDone:
 LDA #$01
 STA AuxFanHit
 INC FanPushCount
 JMP AuxCoopTouchSound
