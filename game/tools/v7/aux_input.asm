AuxInput:
 LDA $06fc
 STA AuxUserRaw
 LDA AuxManual
 BEQ AuxReadNativePrevious
 LDA AuxPrevUser
 JMP AuxPreviousReady
AuxReadNativePrevious:
 LDA PrevInput
AuxPreviousReady:
 EOR #$ff
 AND AuxUserRaw
 STA AuxNewUser
 LDA AuxUserRaw
 STA AuxPrevUser
 LDA AuxRawPad2
 AND #$30
 STA AuxExtraRaw
 LDA AuxPrevExtra
 EOR #$ff
 AND AuxExtraRaw
 STA AuxNewExtra
 LDA AuxExtraRaw
 STA AuxPrevExtra
 LDA $0770
 CMP #$01
 BNE AuxInputReset
 LDA $0e
 CMP #$08
 BNE AuxInputReset
 LDA $0776
 AND #$01
 ORA $077a
 BNE AuxInputReset
 LDA Active
 BEQ AuxInputInactive
 LDA Stagger
 BNE AuxInputReset
 JMP AuxInputAvailable
AuxInputReset:
 JMP AuxReset
AuxInputInactive:
 LDA AuxManual
 ORA AuxState
 BEQ AuxInputIdle
 JMP AuxReset
AuxInputIdle:
 JMP AuxRecomputeLive
AuxInputAvailable:
 LDA AuxState
 CMP #LIFT_HOLD
 BNE AuxInputPartnerBody
 LDA AuxNewUser
 AND #$e0
 BNE AuxInputPartnerBody
 LDA AuxExtraRaw
 AND #$20
 BEQ AuxInputLetGoLift
 JSR AuxAimLift
 JMP AuxInputPartnerBody
AuxInputLetGoLift:
 LDA AuxLiftReady
 AND #$01
 BEQ AuxInputDropLift
 JSR AuxThrowHeld
 JMP AuxInputPartnerBody
AuxInputDropLift:
 JSR AuxClearAction
AuxInputPartnerBody:
 LDA AuxNewUser
 AND #$20
 BEQ AuxInputManual
 LDA AuxState
 CMP #BACK_LOAD
 BEQ AuxInputJumpFromBack
 JSR AuxClearAction
 JMP AuxInputManual
AuxInputJumpFromBack:
 JSR AuxClearAction
 LDA #$01
 STA NpcGround
AuxInputManual:
 LDA AuxManual
 BEQ AuxInputNormal
 LDA AuxUserRaw
 AND #$60
 ORA NewPartnerInput
 BNE AuxManualExit
 LDA AuxNewExtra
 AND #$20
 BEQ AuxManualContinue
 LDA AuxUserRaw
 AND #$0f
 BNE AuxManualContinue
AuxManualExit:
 LDA AuxNewExtra
 AND #$df
 STA AuxNewExtra
 LDA #$00
 STA AuxManual
 STA AuxPose
 STA CacheValid
 LDA #$01
 STA Stance
 JMP AuxInputNormal
AuxManualContinue:
 LDA AuxNewUser
 AND #$80
 BEQ AuxManualMask
 LDA NpcGround
 BEQ AuxManualMask
 JSR AuxJumpManual
AuxManualMask:
 LDA AuxUserRaw
 AND #$10
 STA $06fc
 JMP AuxRecomputeLive
AuxInputNormal:
 LDA AuxNewUser
 AND #$e0
 BEQ AuxInputCommands
 LDA AuxNewUser
 AND #$c0
 BNE AuxInputPlayerAction
 JMP AuxRecomputeLive
AuxInputPlayerAction:
 LDA AuxState
 CMP #LIFT_HOLD
 BEQ AuxInputDrop
 CMP #EDGE_HANG
 BEQ AuxInputDrop
 CMP #EDGE_CLIMB
 BEQ AuxInputDrop
 CMP #BRAKE_ON
 BEQ AuxInputDrop
 LDA #$00
 STA AuxFanTimer
 STA AuxGlideTimer
 STA AuxPlayerPose
 JMP AuxRecomputeLive
AuxInputDrop:
 JSR AuxClearAction
 JMP AuxRecomputeLive
AuxInputCommands:
 LDA AuxState
 CMP #LIFT_HOLD
 BEQ AuxInputPartner
 LDA AuxNewExtra
 AND #$20
 BEQ AuxInputW
 JSR AuxQCommand
AuxInputW:
 LDA AuxNewExtra
 AND #$10
 BEQ AuxInputPartner
 JSR AuxWCommand
AuxInputPartner:
 LDA NewPartnerInput
 CMP #$40
 BNE AuxInputE
 LDA AuxUserRaw
 AND #$0f
 BEQ AuxInputFan
 CMP #$04
 BEQ AuxInputBall
 JMP AuxInputOldJob
AuxInputFan:
 JSR AuxStartFan
 JMP AuxInputFinish
AuxInputBall:
 JSR AuxToggleBall
 JMP AuxInputFinish
AuxInputE:
 CMP #$80
 BNE AuxInputFinish
 LDA AuxState
 CMP #BALL_READY
 BEQ AuxInputPush
 CMP #FAN_HIDE
 BEQ AuxInputPeek
AuxInputOldJob:
 LDA NewPartnerInput
 BEQ AuxInputFinish
 JSR AuxClearAction
AuxInputFinish:
 JMP AuxRecomputeLive
AuxInputPush:
 JSR AuxPushBall
 JMP AuxInputFinish
AuxInputPeek:
 JSR AuxPeekFan
 JMP AuxInputFinish

AuxStartFan:
 LDA NewPartnerInput
 AND #$bf
 STA NewPartnerInput
 LDA AuxState
 CMP #FAN_HIDE
 BNE AuxFanAvailable
 LDA #$0c
 STA AuxPlayerPose
 RTS
AuxFanAvailable:
 LDA AuxFanTimer
 BNE AuxFanStartDone
 LDA #$0a
 STA AuxFanTimer
 LDA #$00
 STA AuxFanHit
 LDA $33
 STA AuxFanFacing
AuxFanStartDone:
 RTS
AuxToggleBall:
 LDA NewPartnerInput
 AND #$bf
 STA NewPartnerInput
 LDA AuxState
 CMP #BALL_READY
 BEQ AuxToggleBallOff
 CMP #BALL_ROLL
 BEQ AuxToggleBallOff
 JSR AuxGroundAvailable
 BEQ AuxBallStartDone
 JSR AuxClearAction
 LDA #BALL_READY
 STA AuxState
 LDA NpcDir
 STA AuxFacing
 LDA #$01
 STA NpcGround
 STA Stance
AuxBallStartDone:
 RTS
AuxToggleBallOff:
 JMP AuxClearAction
AuxPushBall:
 LDA #$00
 STA NewPartnerInput
 JSR AuxBackContact
 BEQ AuxPushDone
 LDA AuxUserRaw
 AND #$03
 CMP AuxFacing
 BNE AuxPushDone
 LDA #BALL_ROLL
 STA AuxState
 LDA #$20
 STA AuxTimer
 STA DashTimer
 LDA AuxFacing
 STA DashDirection
 LDA #$01
 STA Stance
 INC BallPushCount
 JSR AuxCoopTouchSound
AuxPushDone:
 RTS
AuxPeekFan:
 LDA #$00
 STA NewPartnerInput
 JSR AuxNear
 BEQ AuxPeekDone
 LDA AuxTimer
 CMP #$20
 BCC AuxFanReturn
 JSR AuxGetPartnerDelta
 LDA TempY
 BMI AuxPeekLeft
 LDA #$08
 BNE AuxPeekStore
AuxPeekLeft:
 LDA #$07
AuxPeekStore:
 STA AuxPose
 LDA #$1c
 STA AuxTimer
 INC FanPeekCount
AuxPeekDone:
 RTS
AuxFanReturn:
 JSR AuxClearAction
 JMP AuxCoopTouchSound

AuxQCommand:
 LDA AuxUserRaw
 AND #$0f
 BEQ AuxEnterManual
 CMP #$04
 BEQ AuxStartHide
 CMP #$08
 BEQ AuxQEdge
 CMP #$01
 BEQ AuxQToss
 CMP #$02
 BEQ AuxQToss
 RTS
AuxQEdge:
 JMP AuxEdgeCommand
AuxQToss:
 JMP AuxTossCommand
AuxEnterManual:
 LDA AuxNewUser
 AND #$80
 BNE AuxQDone
 JSR AuxGroundAvailable
 BEQ AuxQDone
 JSR AuxClearAction
 LDA #$01
 STA AuxManual
 INC ManualEnterCount
 LDA #$00
 STA $06fc
AuxQDone:
 RTS
AuxStartHide:
 JSR AuxGroundAvailable
 BEQ AuxQDone
 JSR AuxNear
 BEQ AuxQDone
 LDA $1d
 BNE AuxQDone
 JSR AuxClearAction
 LDA #$00
 STA AuxFanTimer
 LDA #FAN_HIDE
 STA AuxState
 LDA #$60
 STA AuxTimer
 LDA #$06
 STA AuxPose
 LDA #$01
 STA Stance
 INC FanHideCount
 RTS

AuxWCommand:
 LDA AuxUserRaw
 AND #$0f
 BEQ AuxStartBackPose
 CMP #$08
 BEQ AuxStartGlide
 CMP #$04
 BEQ AuxWBrake
 RTS
AuxWBrake:
 JMP AuxBrakeCommand
AuxStartGlide:
 LDA AuxState
 CMP #FAN_HIDE
 BEQ AuxWDone
 LDA $1d
 BEQ AuxWDone
 LDA $9f
 BMI AuxWDone
 LDA AuxFanSpent
 BNE AuxWDone
 LDA #$01
 STA AuxFanSpent
 LDA #$28
 STA AuxGlideTimer
 INC GlideCount
AuxWDone:
 RTS
AuxStartBackPose:
 JSR AuxGroundAvailable
 BEQ AuxWDone
 LDA $1d
 ORA $57
 BNE AuxWDone
 JSR AuxNear
 BEQ AuxWDone
 LDA $33
 CMP NpcDir
 BEQ AuxWDone
 JSR AuxGetPartnerDelta
 LDA TempY
 BMI AuxBackNpcLeft
 LDA $33
 CMP #$01
 BNE AuxWDone
 JMP AuxBackStart
AuxBackNpcLeft:
 LDA $33
 CMP #$02
 BNE AuxWDone
AuxBackStart:
 JSR AuxClearAction
 LDA #BACK_POSE
 STA AuxState
 LDA #$48
 STA AuxTimer
 STA AuxPlayerPose
 LDA #$01
 STA Stance
 INC BackPoseCount
 RTS
