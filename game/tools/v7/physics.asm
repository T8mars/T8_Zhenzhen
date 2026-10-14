; Real fixed-point motion and terrain contact own all companion coordinates.
ChooseFollowVelocity:
 LDA NpcGround
 BNE FollowOnGround
 LDA Stagger
 BEQ FollowAirHealthy
 LDA #$00
 STA NpcVX
 RTS
FollowAirHealthy:
 LDA NpcJumpKind
 CMP #$01
 BEQ FollowAirTakeoff
 RTS
FollowAirTakeoff:
 ; Resume the immutable takeoff velocity once terrain no longer blocks it.
 ; The NPC neither changes facing nor chooses a new airborne target.
 LDA NpcAirVX
 STA NpcVX
 RTS
FollowOnGround:
 LDA FootWindow
 ORA HandWindow
 ORA BraceHead
 BNE FollowCoopStop
 LDA DashTimer
 BEQ FollowOrdinary
 CMP #$10
 BEQ FollowCoopStop
 LDA Stagger
 ORA Recovery
 BNE FollowCoopStop
 LDA DashDirection
 STA NpcDir
 CMP #$02
 BEQ FollowDashLeft
 LDA #$38
 STA NpcVX
 RTS
FollowDashLeft:
 LDA #$c8
 STA NpcVX
 RTS
FollowCoopStop:
 LDA #$00
 STA NpcVX
 RTS
FollowOrdinary:
 LDA Stance
 ORA HeadOn
 ORA Stagger
 ORA Recovery
 BEQ FollowAvailable
 LDA #$00
 STA NpcVX
 RTS
FollowAvailable:
 LDA $33
 STA NpcDir
 LDA $86
 SEC
 SBC NpcX
 STA Distance
 LDA $6d
 SBC NpcPage
 BEQ FollowTargetRight
 CMP #$ff
 BEQ FollowTargetLeft
 BMI FollowMoveLeft
 JMP FollowMoveRight
FollowTargetLeft:
 LDA Distance
 CMP #$ec
 BCC FollowMoveLeft
 JMP FollowStop
FollowTargetRight:
 LDA Distance
 CMP #$15
 BCS FollowMoveRight
FollowStop:
 LDA #$00
 STA NpcVX
 RTS
FollowMoveRight:
 LDA #$20
 STA NpcVX
 LDA #$01
 STA NpcDir
 RTS
FollowMoveLeft:
 LDA #$e0
 STA NpcVX
 LDA #$02
 STA NpcDir
FollowVelocityDone:
 RTS

StepFraction:
 STA FixedSpeed
 LDA #$00
 BIT FixedSpeed
 BPL FractionPositive
 LDA #$ff
FractionPositive:
 STA FixedHigh
 TXA
 CLC
 ADC FixedSpeed
 STA FixedLow
 AND #$0f
 STA FixedRemainder
 LDA FixedHigh
 ADC #$00
 STA FixedHigh
 LDX #$04
FractionShift:
 LSR FixedHigh
 ROR FixedLow
 DEX
 BNE FractionShift
 LDY FixedRemainder
 LDA FixedLow
 RTS

NpcPhysics:
 LDA BraceHead
 BEQ PhysicsTerrainStart
 JSR BracePhysics
 LDA BraceHead
 BEQ PhysicsTerrainStart
 RTS
PhysicsTerrainStart:
 JSR GroundAtNpc
 BNE PhysicsHasFloor
 LDA #$00
 STA NpcGround
PhysicsHasFloor:
 LDA NpcVX
 LDX NpcXFrac
 JSR StepFraction
 STY NpcXFrac
 STA DeltaX
 JSR MoveHorizontal
 LDA NpcGround
 BNE PhysicsDone
 LDA NpcVY
 CLC
 ADC #$06
 BMI PhysicsVelocity
 CMP #$61
 BCC PhysicsVelocity
 LDA #$60
PhysicsVelocity:
 STA NpcVY
 LDX NpcYFrac
 JSR StepFraction
 STY NpcYFrac
 STA DeltaY
 JSR MoveVertical
 LDA NpcYHigh
 CMP #$02
 BCC PhysicsDone
 JSR DropHead
 LDA #$00
 STA Active
 LDA #$01
 STA RecallNeeded
PhysicsDone:
 RTS

MoveHorizontal:
 LDA DeltaX
 BNE HorizontalMoved
 RTS
HorizontalMoved:
 BPL HorizontalRight
 EOR #$ff
 CLC
 ADC #$01
 LDX #$02
 BNE HorizontalPrepare
HorizontalRight:
 LDX #$01
HorizontalPrepare:
 STA MoveSteps
 STX MoveDirection
HorizontalStep:
 LDA MoveDirection
 CMP #$02
 BEQ HorizontalDec
 INC NpcX
 BNE HorizontalTest
 INC NpcPage
 JMP HorizontalTest
HorizontalDec:
 LDA NpcX
 BNE HorizontalDecLow
 DEC NpcPage
HorizontalDecLow:
 DEC NpcX
HorizontalTest:
 JSR BodyClear
 BEQ HorizontalBlocked
 LDA DashTimer
 BEQ HorizontalAccepted
 JSR GroundAtNpc
 BEQ HorizontalBlocked
HorizontalAccepted:
 DEC MoveSteps
 BNE HorizontalStep
 LDA NpcGround
 BEQ HorizontalDone
 JSR GroundAtNpc
 BNE HorizontalDone
 JSR LowerFloorAtNpc
 BNE HorizontalDrop
 JSR AutoTerrainJump
 RTS
HorizontalDrop:
 LDA #$00
 STA NpcGround
 STA NpcVY
 RTS
HorizontalBlocked:
 LDA MoveDirection
 CMP #$02
 BEQ UndoHorizontalLeft
 LDA NpcX
 BNE UndoHorizontalRightLow
 DEC NpcPage
UndoHorizontalRightLow:
 DEC NpcX
 JMP HorizontalObstacle
UndoHorizontalLeft:
 INC NpcX
 BNE HorizontalObstacle
 INC NpcPage
HorizontalObstacle:
 LDA DashTimer
 BEQ HorizontalOrdinaryObstacle
 LDA #$00
 STA DashTimer
 STA NpcVX
 LDA #$01
 STA Stance
 RTS
HorizontalOrdinaryObstacle:
 LDA NpcGround
 BEQ HorizontalStop
 JSR AutoTerrainJump
 RTS
HorizontalStop:
 LDA #$00
 STA NpcVX
HorizontalDone:
 RTS

AutoTerrainJump:
 LDA Stance
 ORA FootWindow
 ORA HandWindow
 ORA HeadOn
 ORA Stagger
 ORA Recovery
 BNE AutoJumpDone
 LDA #$01
 STA NpcJumpKind
 LDA NpcDir
 CMP #$02
 BEQ AutoJumpLeft
 LDA #$14
 BNE AutoJumpVX
AutoJumpLeft:
 LDA #$ec
AutoJumpVX:
 STA NpcVX
 LDA #$90
 JMP BeginNpcJump
AutoJumpDone:
 RTS

MoveVertical:
 LDA DeltaY
 BEQ VerticalDone
 BPL VerticalDown
 EOR #$ff
 CLC
 ADC #$01
 STA MoveSteps
VerticalUpStep:
 LDA NpcY
 BNE VerticalDecLow
 DEC NpcYHigh
VerticalDecLow:
 DEC NpcY
 JSR CeilingAtNpc
 BEQ VerticalUpClear
 INC NpcY
 BNE VerticalStopUp
 INC NpcYHigh
VerticalStopUp:
 LDA #$00
 STA NpcVY
 STA NpcYFrac
 RTS
VerticalUpClear:
 DEC MoveSteps
 BNE VerticalUpStep
 RTS
VerticalDown:
 STA MoveSteps
VerticalDownStep:
 INC NpcY
 BNE VerticalFloor
 INC NpcYHigh
VerticalFloor:
 JSR GroundAtNpc
 BEQ VerticalDownClear
 LDA AuxGroundSurface
 SEC
 SBC #$20
 STA NpcY
 STA NpcFloorY
 LDA #$01
 STA NpcYHigh
 STA NpcGround
 LDA #$00
 STA NpcVY
 STA NpcYFrac
 STA NpcJumpKind
 STA NpcChain
 LDA AuxCarryMotion
 BNE VerticalSupportMoved
 LDA #$08
 STA Recovery
VerticalSupportMoved:
 RTS
VerticalDownClear:
 DEC MoveSteps
 BNE VerticalDownStep
VerticalDone:
 RTS

GroundAtNpc:
 LDA AuxPlatformOn
 BEQ GroundTileOnly
 JSR PlatformGroundContact
 BEQ GroundTileOnly
 LDX AuxPlatformSlot
 LDA $cf,X
 STA AuxGroundSurface
 LDA #$01
 RTS
GroundTileOnly:
 LDA NpcYHigh
 CMP #$01
 BNE NoFloor
 LDA NpcY
 CLC
 ADC #$20
 BCS NoFloor
 STA ProbeY
 LDA NpcX
 CLC
 ADC #$03
 STA ProbeX
 LDA NpcPage
 ADC #$00
 STA ProbePage
 JSR ReadPoint
 JSR IsSolid
 BNE HasFloor
 LDA NpcX
 CLC
 ADC #$0c
 STA ProbeX
 LDA NpcPage
 ADC #$00
 STA ProbePage
 JSR ReadPoint
 JSR IsSolid
HasFloor:
 BEQ GroundSurfaceDone
 PHA
 LDA ProbeY
 AND #$f0
 STA AuxGroundSurface
 PLA
GroundSurfaceDone:
 RTS
NoFloor:
 LDA #$00
 RTS

LowerFloorAtNpc:
 ; Ordinary drops fall; only a genuine gap invokes the short terrain hop.
 ; Search is bounded by the visible native block-buffer rows.
 LDA NpcYHigh
 CMP #$01
 BNE NoLowerFloor
 LDA NpcY
 CLC
 ADC #$30
 BCS NoLowerFloor
 STA ProbeY
 LDA NpcX
 CLC
 ADC #$08
 STA ProbeX
 LDA NpcPage
 ADC #$00
 STA ProbePage
LowerFloorRow:
 LDA ProbeY
 CMP #$f0
 BCS NoLowerFloor
 JSR ReadPoint
 JSR IsSolid
 BNE LowerFloorFound
 LDA ProbeY
 CLC
 ADC #$10
 BCS NoLowerFloor
 STA ProbeY
 JMP LowerFloorRow
LowerFloorFound:
 RTS
NoLowerFloor:
 LDA #$00
 RTS

GetHeadY:
 LDX RenderSize
 LDA NpcY
 CLC
 ADC HeadYOffset,X
 STA HeadY
 RTS
HeadYOffset:
.byte $00,$10,$08

CeilingAtNpc:
 LDA NpcYHigh
 CMP #$01
 BNE NoCeiling
 JSR GetHeadY
 LDA HeadY
 STA ProbeY
 LDA NpcX
 CLC
 ADC #$08
 STA ProbeX
 LDA NpcPage
 ADC #$00
 STA ProbePage
 JSR ReadPoint
 STA BlockTile
 JSR IsSolid
 BEQ CeilingCarrier
 LDA Stagger
 BNE CeilingSolid
 JSR BumpNativeBlock
CeilingSolid:
 LDA #$01
 RTS
CeilingCarrier:
 LDA HeadOn
 BEQ NoCeiling
 LDA HeadY
 SEC
 SBC #$20
 LDX $0754
 BEQ CarrierTopReady
 CLC
 ADC #$10
CarrierTopReady:
 STA ProbeY
 LDA $86
 CLC
 ADC #$08
 STA ProbeX
 LDA $6d
 ADC #$00
 STA ProbePage
 JSR ReadPoint
 JSR IsSolid
 RTS
NoCeiling:
 LDA #$00
 RTS

DropHead:
 LDA HeadOn
 BEQ HeadDropped
 LDA $1d
 CMP #$03
 BEQ HeadDropped
 LDA $9f
 BMI HeadDropped
 LDA #$02
 STA $1d
HeadDropped:
 LDA #$00
 STA HeadOn
 STA HeadTimer
 RTS

CarryHeadBeforePlayer:
 LDA HeadOn
 BEQ CarryDone
 LDA Stagger
 BNE CarryLost
 LDA NpcYHigh
 CMP #$01
 BNE CarryLost
 JSR GetHeadY
 LDA NpcX
 SEC
 SBC PrevNpcX
 STA Distance
 LDA NpcPage
 SBC PrevNpcPage
 STA TempY
 LDA $86
 CLC
 ADC Distance
 STA $86
 LDA $6d
 ADC TempY
 STA $6d
 LDA HeadY
 CMP #$20
 BCC CarryLost
 SEC
 SBC #$20
 STA $ce
 LDA #$01
 STA $b5
 LDA #$00
 STA $9f
 STA $0433
 STA $0416
 STA $1d
CarryDone:
 RTS
CarryLost:
 JMP DropHead

PlayerTerrainHook:
 JSR $dc64
 PHP
 PHA
 TXA
 PHA
 TYA
 PHA
 JSR AuxTerrainHook
 JSR PlayerHeadContact
 PLA
 TAY
 PLA
 TAX
 PLA
 PLP
 RTS

PlayerHeadContact:
 LDA $0e
 CMP #$08
 BEQ HeadGameplayReady
 RTS
HeadGameplayReady:
 LDA $0716
 BEQ HeadNativeCollisionReady
 JMP DropHead
HeadNativeCollisionReady:
 LDA $1d
 BNE PlayerNotOnTerrain
 LDA HeadOn
 BNE PlayerNotOnTerrain
 LDA $0716
 BNE PlayerNotOnTerrain
 LDA #$00
 STA HeadSpent
PlayerNotOnTerrain:
 LDA Active
 BEQ HeadContactDone
 LDA RenderOK
 BEQ HeadContactDrop
 LDA Stagger
 BNE HeadContactDrop
 LDA HeadOn
 BEQ NewHeadContact
 LDA $1d
 BEQ HeadTouchedTerrain
 CMP #$03
 BEQ HeadContactDrop
 LDA $9f
 BMI PlayerLeftHead
 JSR PlayerHorizontalHead
 BEQ HeadContactDrop
 JSR PlayerHeadRoom
 BEQ HeadContactDrop
 JSR HoldPlayerOnHead
 JMP BufferedHeadJump
HeadTouchedTerrain:
 ; The native collision producer found real terrain under T8 this frame.
 ; Preserve that landing instead of pinning feet back through the metatile.
 LDA #$00
 STA HeadOn
 STA HeadTimer
 STA HeadSpent
 RTS
PlayerLeftHead:
 LDA #$00
 STA HeadOn
 STA HeadTimer
 STA JumpBuffer
 INC HeadJumpCount
 RTS
HeadContactDrop:
 JMP DropHead
HeadContactDone:
 RTS
NewHeadContact:
 LDA HeadSpent
 BNE HeadContactDone
 LDA NpcYHigh
 CMP #$01
 BNE HeadContactDone
 LDA $b5
 CMP #$01
 BNE HeadContactDone
 LDA PrevPlayerHigh
 CMP #$01
 BNE HeadContactDone
 LDA $9f
 BMI HeadContactDone
 BNE PlayerReallyFalling
 LDA $ce
 CMP PrevPlayerY
 BEQ HeadContactDone
 BCC HeadContactDone
PlayerReallyFalling:
 LDA $1d
 CMP #$03
 BEQ HeadContactDone
 JSR GetHeadY
 LDA PrevPlayerY
 CLC
 ADC #$20
 BCS HeadContactDone
 CMP PrevHeadY
 BEQ PreviousAboveHead
 BCS HeadContactDone
PreviousAboveHead:
 LDA $ce
 CLC
 ADC #$20
 BCS HeadContactDone
 CMP HeadY
 BCC HeadContactDone
 JSR PlayerHorizontalHead
 BEQ HeadContactDone
 JSR PlayerHeadRoom
 BEQ HeadContactDone
 LDA #$01
 STA HeadOn
 STA HeadSpent
 LDA #$2a
 STA HeadTimer
 INC HeadLandCount
 JSR HoldPlayerOnHead
BufferedHeadJump:
 LDA JumpBuffer
 BEQ BufferedJumpDone
 JSR $b4a0
 LDA #$00
 STA HeadOn
 STA JumpBuffer
 INC HeadJumpCount
BufferedJumpDone:
 RTS

PlayerHorizontalHead:
 LDA $86
 SEC
 SBC NpcX
 STA Distance
 LDA $6d
 SBC NpcPage
 BEQ HeadPlayerRight
 CMP #$ff
 BNE HeadHorizontalMiss
 LDA Distance
 LDX RenderSize
 CMP HeadLeftLimit,X
 BCC HeadHorizontalMiss
 JMP HeadHorizontalHit
HeadPlayerRight:
 LDA Distance
 LDX RenderSize
 CMP HeadRightLimit,X
 BCS HeadHorizontalMiss
HeadHorizontalHit:
 LDA #$01
 RTS
HeadHorizontalMiss:
 LDA #$00
 RTS
HeadLeftLimit:
.byte $f6,$f3,$f3
HeadRightLimit:
.byte $0b,$0e,$0e

HoldPlayerOnHead:
 JSR GetHeadY
 LDA HeadY
 SEC
 SBC #$20
 STA $ce
 LDA #$00
 STA $9f
 STA $0433
 STA $0416
 STA $1d
 JSR $f180
 JSR $f12a
 LDX #$00
 JSR $e29c
 RTS

PlayerHeadRoom:
 JSR GetHeadY
 LDA HeadY
 CMP #$20
 BCC HeadRoomBlocked
 SEC
 SBC #$20
 LDY $0754
 BNE HeadRoomSmall
 LDY $0714
 BEQ HeadRoomTop
HeadRoomSmall:
 CLC
 ADC #$10
HeadRoomTop:
 STA ProbeY
 LDA $86
 CLC
 ADC #$08
 STA ProbeX
 LDA $6d
 ADC #$00
 STA ProbePage
 JSR ReadPoint
 JSR IsSolid
 BNE HeadRoomBlocked
 LDA #$01
 RTS
HeadRoomBlocked:
 LDA #$00
 RTS
