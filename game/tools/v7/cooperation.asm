; Explicit commands and the two-way support lifecycle.
StopCooperation:
 JSR DropBrace
 JMP StopNpcWindows
StopNpcCooperation:
 JSR ReleaseBraceLoad
StopNpcWindows:
 LDA #$00
 STA FootWindow
 STA HandWindow
 STA DashTimer
 STA MoodTimer
 STA MoodKind
 STA IdleTicks
 STA IdleDone
 RTS

DropBrace:
 JSR ReleaseBraceLoad
 LDA #$00
 STA BraceOn
 RTS
ReleaseBraceLoad:
 LDA BraceHead
 BEQ BraceClear
 LDA #$00
 STA NpcGround
 STA NpcVY
BraceClear:
 LDA #$00
 STA BraceHead
 STA BraceTimer
 RTS

CooperationPre:
 LDA $077a
 BEQ CoopSinglePlayer
 JMP StopCooperation
CoopSinglePlayer:
 ; Existing routes pay only one bounded state check when no new action exists.
 LDA NewPartnerInput
 ORA BraceOn
 ORA FootWindow
 ORA HandWindow
 ORA DashTimer
 ORA MoodTimer
 ORA FootCooldown
 ORA AirSpent
 ORA BraceSpent
 BNE CoopWork
 RTS
CoopWork:
 LDA NewInput
 AND #$20
 BEQ CoopPlayerActions
 LDA #$00
 STA FootWindow
 STA HandWindow
 STA DashTimer
 STA MoodTimer
 STA MoodKind
CoopPlayerActions:
 LDA NewInput
 AND #$c0
 BEQ CoopTick
 LDA MoodKind
 CMP #$02
 BNE CoopPlayerHand
 LDA #$00
 STA MoodTimer
 STA MoodKind
CoopPlayerHand:
 LDA HandKind
 CMP #$02
 BNE CoopTick
 LDA #$00
 STA HandWindow
CoopTick:
 LDA FootCooldown
 BEQ CoopTickMood
 DEC FootCooldown
CoopTickMood:
 LDA MoodTimer
 BEQ CoopTickDash
 DEC MoodTimer
 LDA MoodKind
 CMP #$02
 BNE CoopTickDash
 LDA RawInput
 AND #$03
 BEQ CoopTickDash
 LDA #$00
 STA MoodTimer
 STA MoodKind
CoopTickDash:
 LDA DashTimer
 BEQ CoopTickHand
 DEC DashTimer
 BNE CoopTickHand
 LDA #$01
 STA Stance
CoopTickHand:
 LDA HandWindow
 BEQ CoopTickFoot
 DEC HandWindow
CoopTickFoot:
 LDA FootWindow
 BEQ CoopBraceLife
 DEC FootWindow
 BNE CoopBraceLife
 LDA #$14
 STA FootCooldown
 JSR LookAtPartner
CoopBraceLife:
 LDA BraceOn
 BEQ CoopGroundReset
 LDA NewInput
 AND #$c0
 BNE CoopDropBrace
 LDA $1d
 BNE CoopDropBrace
 LDA $86
 CMP BracePlayerX
 BNE CoopDropBrace
 LDA $6d
 CMP BracePlayerPage
 BNE CoopDropBrace
 LDA $ce
 CMP BracePlayerY
 BNE CoopDropBrace
 LDA BraceHead
 BEQ CoopGroundReset
 LDA BraceTimer
 BEQ CoopDropBrace
 DEC BraceTimer
 BNE CoopGroundReset
CoopDropBrace:
 JSR DropBrace
CoopGroundReset:
 LDA $1d
 ORA HeadOn
 BNE CoopInput
 LDA #$00
 STA AirSpent
 LDA BraceOn
 ORA BraceHead
 BNE CoopInput
 JSR GroundAtNpc
 BEQ CoopInput
 LDA #$00
 STA BraceSpent
CoopInput:
 LDA NewPartnerInput
 BEQ CoopDone
 CMP #$c0
 BEQ CoopDone
 LDA NewInput
 AND #$e0
 BNE CoopDone
 LDA #$00
 STA MoodTimer
 STA MoodKind
 LDA RawInput
 AND #$0f
 STA CoopDirection
 LDA NewPartnerInput
 CMP #$40
 BEQ CoopHandCommand
 LDA CoopDirection
 BEQ CoopGreeting
 CMP #$08
 BEQ CoopBraceCommand
 CMP #$04
 BEQ CoopFootCommand
 CMP #$01
 BEQ CoopDashCommand
 CMP #$02
 BEQ CoopDashCommand
CoopDone:
 RTS
CoopGreeting:
 LDA BraceOn
 BNE CoopToggleOff
 JMP StartGreeting
CoopBraceCommand:
 LDA BraceOn
 BNE CoopToggleOff
 JMP StartBrace
CoopToggleOff:
 JMP DropBrace
CoopFootCommand:
 JMP StartFootWindow
CoopDashCommand:
 JMP StartAssistRun
CoopHandCommand:
 JMP StartHandWindow

CoopGroundPartner:
 LDA Stagger
 ORA Recovery
 ORA HeadOn
 ORA BraceHead
 BNE CoopGroundNo
 LDA NpcGround
 BEQ CoopGroundNo
 JMP GroundAtNpc
CoopGroundNo:
 LDA #$00
 RTS

StartBrace:
 LDA $1d
 ORA HeadOn
 ORA BraceSpent
 ORA Stagger
 BNE BraceStartDone
 LDA $b5
 CMP #$01
 BNE BraceStartDone
 LDA #$01
 STA BraceOn
 LDA $86
 STA BracePlayerX
 LDA $6d
 STA BracePlayerPage
 LDA $ce
 STA BracePlayerY
BraceStartDone:
 RTS

StartFootWindow:
 LDA FootCooldown
 ORA FootWindow
 BNE FootStartDone
 JSR CoopGroundPartner
 BEQ FootStartDone
 LDA #$0c
 STA FootWindow
 LDA #$20
 STA FootCooldown
 LDA NpcDir
 STA FootFacing
 LDA #$00
 STA HandWindow
 INC FootAttemptCount
FootStartDone:
 RTS

StartHandWindow:
 LDA CoopDirection
 CMP #$08
 BEQ StartFireWindow
 CMP #$01
 BEQ StartAirWindow
 CMP #$02
 BEQ StartAirWindow
 RTS
StartFireWindow:
 JSR CoopGroundPartner
 BEQ HandStartDone
 LDA #$01
 STA HandKind
 JMP SetHandWindow
StartAirWindow:
 LDA AirSpent
 ORA HeadOn
 ORA Stagger
 BNE HandStartDone
 LDA $1d
 CMP #$01
 BCC HandStartDone
 CMP #$03
 BCS HandStartDone
 LDA $9f
 BMI HandStartDone
 LDA #$02
 STA HandKind
SetHandWindow:
 LDA NpcDir
 STA FootFacing
 LDA CoopDirection
 STA HandDirection
 LDA #$0c
 STA HandWindow
 LDA #$00
 STA FootWindow
HandStartDone:
 RTS

GetPartnerDelta:
 LDA $86
 SEC
 SBC NpcX
 STA Distance
 LDA $6d
 SBC NpcPage
 STA TempY
 RTS

StartAssistRun:
 LDA $1d
 BNE AssistStartDone
 JSR CoopGroundPartner
 BEQ AssistStartDone
 JSR GetPartnerDelta
 LDA CoopDirection
 CMP #$01
 BEQ AssistRight
 LDA TempY
 BNE AssistStartDone
 LDA Distance
 CMP #$0c
 BCC AssistStartDone
 CMP #$10
 BCS AssistStartDone
 JMP AssistAligned
AssistRight:
 LDA TempY
 CMP #$ff
 BNE AssistStartDone
 LDA Distance
 CMP #$f1
 BCC AssistStartDone
 CMP #$f5
 BCS AssistStartDone
AssistAligned:
 LDA $ce
 SEC
 SBC NpcY
 CLC
 ADC #$04
 CMP #$09
 BCS AssistStartDone
 LDA CoopDirection
 STA DashDirection
 STA NpcDir
 LDA #$10
 STA DashTimer
 LDA #$00
 STA Stance
 INC DashCount
 JSR CoopTouchSound
AssistStartDone:
 RTS

StartGreeting:
 LDA $1d
 ORA $57
 BNE GreetingDone
 JSR CoopGroundPartner
 BEQ GreetingDone
 JSR NearbyNpcDanger
 BNE GreetingDone
 JSR GetPartnerDelta
 LDA TempY
 BEQ GreetingRight
 CMP #$ff
 BNE GreetingDone
 LDA Distance
 CMP #$f1
 BCC GreetingDone
 CMP #$f5
 BCS GreetingDone
 LDA $33
 CMP #$01
 BNE GreetingDone
 LDA NpcDir
 CMP #$02
 BNE GreetingDone
 JMP GreetingY
GreetingRight:
 LDA Distance
 CMP #$0c
 BCC GreetingDone
 CMP #$10
 BCS GreetingDone
 LDA $33
 CMP #$02
 BNE GreetingDone
 LDA NpcDir
 CMP #$01
 BNE GreetingDone
GreetingY:
 LDA $ce
 SEC
 SBC NpcY
 CLC
 ADC #$04
 CMP #$09
 BCS GreetingDone
 LDA #$02
 STA MoodKind
 LDA #$0c
 STA MoodTimer
 LDA #$00
 STA DashTimer
 INC ClapCount
 JSR CoopTouchSound
GreetingDone:
 RTS

LookAtPartner:
 LDA Stagger
 ORA HeadOn
 ORA BraceHead
 BNE LookDone
 JSR NearbyNpcDanger
 BNE LookDone
 LDA #$01
 STA MoodKind
 LDA #$0c
 STA MoodTimer
 INC LookCount
LookDone:
 RTS

BracePhysics:
 LDA BraceOn
 BEQ BracePhysicsDrop
 LDA Stagger
 BNE BracePhysicsDrop
 JSR PlayerHorizontalHead
 BEQ BracePhysicsDrop
 JSR GetSupportTop
 LDA NpcY
 STA ContactSavedY
 LDA SupportTop
 SEC
 SBC #$20
 STA NpcY
 JSR BodyClear
 BNE BracePhysicsSpace
 LDA ContactSavedY
 STA NpcY
 JMP BracePhysicsDrop
BracePhysicsSpace:
 LDA #$01
 STA NpcGround
 LDA #$00
 STA NpcVX
 STA NpcVY
 STA NpcYFrac
 RTS
BracePhysicsDrop:
 JMP DropBrace

GetSupportTop:
 LDA $ce
 LDY $0754
 BEQ SupportTopReady
 CLC
 ADC #$10
SupportTopReady:
 CLC
 ADC #$01
 STA SupportTop
 RTS

BraceContact:
 LDA BraceOn
 BNE BraceContactActive
 RTS
BraceContactActive:
 LDA BraceHead
 ORA BraceSpent
 ORA Stagger
 ORA NpcGround
 BEQ BraceContactFree
 RTS
BraceContactFree:
 JSR CompanionContactVisible
 BNE BraceContactVisible
 RTS
BraceContactVisible:
 LDA NpcVY
 BPL BraceContactFalling
 RTS
BraceContactFalling:
 LDA NpcYHigh
 CMP #$01
 BEQ BraceContactOnPage
 RTS
BraceContactOnPage:
 LDA $b5
 CMP #$01
 BNE BraceContactDone
 LDA NpcY
 CMP PrevNpcY
 BCC BraceContactDone
 BEQ BraceContactDone
 JSR GetSupportTop
 LDA PrevNpcY
 CLC
 ADC #$20
 BCS BraceContactDone
 CMP SupportTop
 BEQ BraceWasAbove
 BCS BraceContactDone
BraceWasAbove:
 LDA NpcY
 CLC
 ADC #$20
 BCS BraceContactDone
 CMP SupportTop
 BCC BraceContactDone
 JSR PlayerHorizontalHead
 BEQ BraceContactDone
 LDA NpcY
 STA ContactSavedY
 LDA SupportTop
 SEC
 SBC #$20
 STA NpcY
 JSR BodyClear
 BNE BraceLanded
 LDA ContactSavedY
 STA NpcY
 RTS
BraceLanded:
 LDA #$01
 STA BraceHead
 STA BraceSpent
 STA NpcGround
 LDA #$2a
 STA BraceTimer
 LDA #$00
 STA NpcVX
 STA NpcVY
 STA NpcYFrac
 STA NpcJumpKind
 INC BraceLandCount
 JSR CoopTouchSound
BraceContactDone:
 RTS

CooperationPost:
 LDA $0e
 CMP #$08
 BEQ CooperationWorldReady
 JMP StopCooperation
CooperationWorldReady:
 LDA BraceOn
 BEQ CooperationStable
 LDA $1d
 ORA $0714
 BNE CooperationMoved
 LDA $86
 CMP BracePlayerX
 BNE CooperationMoved
 LDA $6d
 CMP BracePlayerPage
 BNE CooperationMoved
 LDA $ce
 CMP BracePlayerY
 BEQ CooperationStable
CooperationMoved:
 JSR DropBrace
CooperationStable:
 LDA BraceOn
 BEQ CooperationPalmReady
 JSR BraceContact
CooperationPalmReady:
 LDA HandWindow
 BEQ CooperationFacingReady
 JSR PalmContacts
CooperationFacingReady:
 LDA NpcDir
 STA RenderDir
 LDA MoodTimer
 BEQ CooperationNoCosmetic
 LDA MoodKind
 CMP #$04
 BCS CooperationNoCosmetic
 JSR NearbyNpcDanger
 BEQ CooperationNoCosmetic
 LDA #$00
 STA MoodTimer
 STA MoodKind
 STA IdleTicks
CooperationNoCosmetic:
 LDA Stagger
 ORA HeadOn
 ORA BraceHead
 BEQ CoopPostAvailable
 RTS
CoopPostAvailable:
 LDA HandWindow
 BEQ CoopFootPose
 LDA HandKind
 CMP #$01
 BNE CoopAirHandPose
 LDA #$06
 BNE CoopActiveHandPose
CoopAirHandPose:
 LDA #$09
CoopActiveHandPose:
 STA NpcPose
 RTS
CoopFootPose:
 LDA FootWindow
 BEQ CoopMoodPose
 LDA #$04
 STA NpcPose
 RTS
CoopMoodPose:
 LDA MoodTimer
 BEQ CoopIdle
 LDA MoodKind
 CMP #$01
 BEQ CoopLookPose
 CMP #$02
 BEQ CoopClapPose
 CMP #$04
 BEQ CoopFootFollowthrough
 CMP #$05
 BEQ CoopPalmFollowthrough
 LDA MoodTimer
 AND #$04
 BEQ CoopToeDown
 LDA #$08
 BNE CoopPoseStore
CoopToeDown:
 LDA #$00
 JMP CoopPoseStore
CoopFootFollowthrough:
 LDA #$04
 BNE CoopPoseStore
CoopPalmFollowthrough:
 LDA HandKind
 CMP #$01
 BNE CoopAirFollowthrough
 LDA #$06
 BNE CoopPoseStore
CoopAirFollowthrough:
 LDA #$09
 BNE CoopPoseStore
CoopClapPose:
 LDA #$05
 BNE CoopPoseStore
CoopLookPose:
 JSR GetPartnerDelta
 LDA #$01
 LDY TempY
 BPL CoopLookDirection
 LDA #$02
CoopLookDirection:
 STA RenderDir
 LDA #$0a
CoopPoseStore:
 STA NpcPose
 RTS
CoopIdle:
 LDA Stance
 BEQ CoopIdleReset
 LDA NpcGround
 BEQ CoopIdleReset
 LDA IdleDone
 BNE CoopPostDone
 JSR NearbyNpcDanger
 BNE CoopIdleReset
 JSR GetPartnerDelta
 LDA TempY
 BEQ CoopIdleRight
 CMP #$ff
 BNE CoopIdleTick
 LDA Distance
 CMP #$e1
 BCS CoopPostDone
 JMP CoopIdleTick
CoopIdleRight:
 LDA Distance
 CMP #$20
 BCC CoopPostDone
CoopIdleTick:
 INC IdleTicks
 LDA IdleTicks
 CMP #$3c
 BCC CoopPostDone
 LDA #$01
 STA IdleDone
 LDA #$03
 STA MoodKind
 LDA #$0a
 STA MoodTimer
 INC TapCount
CoopPostDone:
 RTS
CoopIdleReset:
 LDA #$00
 STA IdleTicks
 STA IdleDone
 RTS

; Only cosmetics use this conservative bounded danger check. Native combat and
; physical object contacts retain their actual bounding-box owners.
NearbyNpcDanger:
 LDX #$04
NpcDangerLoop:
 LDA $0f,X
 BEQ NpcDangerNext
 LDA NpcX
 SEC
 SBC $87,X
 STA Distance
 LDA NpcPage
 SBC $6e,X
 BEQ NpcDangerRight
 CMP #$ff
 BNE NpcDangerNext
 LDA Distance
 CMP #$d0
 BCC NpcDangerNext
 JMP NpcDangerY
NpcDangerRight:
 LDA Distance
 CMP #$31
 BCS NpcDangerNext
NpcDangerY:
 LDA NpcY
 SEC
 SBC $cf,X
 CLC
 ADC #$20
 CMP #$41
 BCC NpcDangerYes
NpcDangerNext:
 DEX
 BPL NpcDangerLoop
 LDA #$00
 RTS
NpcDangerYes:
 LDA #$01
 RTS

; Contact needs both the current world coordinates and a usable visible area.
CompanionContactVisible:
 LDA NpcYHigh
 CMP #$01
 BNE ContactNotVisible
 LDA NpcY
 CMP #$20
 BCC ContactNotVisible
 CMP #$d1
 BCS ContactNotVisible
 LDA NpcX
 SEC
 SBC $071c
 STA ScreenX
 LDA NpcPage
 SBC $071a
 BNE ContactNotVisible
 LDA ScreenX
 CMP #$08
 BCC ContactNotVisible
 CMP #$e8
 BCS ContactNotVisible
 LDA #$01
 RTS
ContactNotVisible:
 LDA #$00
 RTS

; Native player/hazard sounds retain priority. A successful partner contact
; queues one short existing pulse on an otherwise empty sound channel.
CoopTouchSound:
 LDA $ff
 BNE CoopSoundDone
 LDA #$04
 STA $ff
CoopSoundDone:
 RTS
