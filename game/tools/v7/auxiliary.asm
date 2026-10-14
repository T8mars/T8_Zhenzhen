.org $8000
AuxDispatch:
 LDA #$00
 STA AuxHandled
 LDA AuxOp
 BEQ AuxDispatchInput
 CMP #$01
 BEQ AuxDispatchPre
 CMP #$02
 BEQ AuxDispatchSteer
 CMP #$03
 BEQ AuxDispatchPhysics
 CMP #$04
 BEQ AuxDispatchPost
 CMP #$05
 BEQ AuxDispatchEnemy
 CMP #$06
 BEQ AuxCacheDispatch
 CMP #$08
 BEQ AuxDispatchPause
 JMP AuxTerrain
AuxDispatchPause:
 JSR AuxReset
 LDA $06fc
 STA AuxPrevUser
 LDA AuxRawPad2
 AND #$30
 STA AuxPrevExtra
 RTS
AuxDispatchInput:
 JMP AuxInput
AuxDispatchPre:
 JMP AuxPre
AuxDispatchSteer:
 JMP AuxSteer
AuxDispatchPhysics:
 JMP AuxPhysics
AuxDispatchPost:
 JMP AuxPost
AuxDispatchEnemy:
 JMP AuxEnemy
AuxCacheDispatch:
 JMP AuxCache

AuxRecomputeLive:
 LDA AuxState
 ORA AuxManual
 ORA AuxFanTimer
 ORA AuxGlideTimer
 ORA AuxPlayerPose
 ORA AuxLiftSpent
 ORA AuxEdgeSpent
 ORA AuxFanSpent
 STA AuxLive
 RTS
AuxClearAction:
 LDA AuxState
 BNE AuxClearOwned
 RTS
AuxClearOwned:
 CMP #BALL_ROLL
 BNE AuxClearRollDone
 LDA #$00
 STA DashTimer
AuxClearRollDone:
 LDA #$00
 STA AuxState
 STA AuxTimer
 STA AuxPose
 STA NpcVX
 STA CacheValid
 RTS
AuxReset:
 JSR AuxClearAction
 LDA #$00
 STA AuxManual
 STA AuxFanTimer
 STA AuxGlideTimer
 STA AuxPlayerPose
 STA AuxLiftSpent
 STA AuxEdgeSpent
 STA AuxFanSpent
 STA AuxPlatformOn
 STA AuxCarryMotion
 JMP AuxRecomputeLive

AuxGroundAvailable:
 LDA Stagger
 ORA Recovery
 ORA HeadOn
 ORA BraceHead
 BNE AuxNo
 LDA NpcYHigh
 CMP #$01
 BNE AuxNo
 JMP AuxGroundAtNpc
AuxNo:
 LDA #$00
 RTS
AuxNear:
 JSR AuxGetPartnerDelta
 LDA TempY
 BEQ AuxNearRight
 CMP #$ff
 BNE AuxNo
 LDA Distance
 CMP #$e5
 BCC AuxNo
 JMP AuxNearY
AuxNearRight:
 LDA Distance
 CMP #$1c
 BCS AuxNo
AuxNearY:
 LDA $ce
 SEC
 SBC NpcY
 CLC
 ADC #$08
 CMP #$11
 BCS AuxNo
 LDA #$01
 RTS
AuxBackContact:
 JSR AuxNear
 BEQ AuxNo
 LDA $1d
 BNE AuxNo
 LDA AuxFacing
 CMP #$01
 BEQ AuxBackRight
 LDA TempY
 BNE AuxNo
 LDA Distance
 CMP #$0b
 BCC AuxNo
 CMP #$15
 BCS AuxNo
 LDA #$01
 RTS
AuxBackRight:
 LDA TempY
 CMP #$ff
 BNE AuxNo
 LDA Distance
 CMP #$ec
 BCC AuxNo
 CMP #$f6
 BCS AuxNo
 LDA #$01
 RTS
AuxJumpManual:
 LDA #$01
 STA NpcJumpKind
 LDA #$a0
 JMP AuxBeginNpcJump
