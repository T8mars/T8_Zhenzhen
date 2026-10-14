; Cartridge-owned lifecycle, input and rendering schedule. No emulator patches.
FrameCount = $6000
TextRequest = $6001
LifeOnes = $6002
LifeTens = $6003
HudSeen = $6004
Wanted = $6008
Active = $6009
NpcX = $600a
NpcPage = $600b
NpcY = $600c
NpcDir = $600d
NpcPose = $600e
RenderOK = $6012
ActionTimer = $6015
BlockedFrames = $601a
PrevNpcX = $601b
PrevNpcY = $601c
PrevNpcPage = $601d
SpriteCount = $601f
SpriteIndex = $6022
ScreenX = $6024
PaletteColor = $6029
ActorTop = $602b
OwnedCount = $602c
LastSlotCount = $602d
ProbeX = $6030
ProbePage = $6031
ProbeY = $6032
ProbeRow = $6033
ProbeColumn = $6034
SkillSlot = $6035
Distance = $6036
TempIndex = $6020
RenderSize = $603e
SourceNeedsRed = $603f
SpawnCount = $6021
CacheValid = $6013
CachePose = $6014
CacheDir = $6016
CacheSize = $6017
SaveZp0 = $6019
SaveZp1 = $6023
OwnedSlots = $6080
NpcVX = $6090
NpcVY = $6091
NpcXFrac = $6092
NpcYFrac = $6093
NpcGround = $6094
NpcJumpKind = $6095
Stance = $6096
Stagger = $6097
Recovery = $6098
RawInput = $6099
PrevInput = $609a
NewInput = $609b
HeadSpent = $609c
HeadOn = $609d
HeadTimer = $609e
JumpBuffer = $609f
PrevPlayerY = $60a0
PrevHeadY = $60a1
HeadY = $60a2
NpcYHigh = $60a3
PrevPlayerHigh = $60a4
LastSize = $60a5
DeltaX = $60a6
DeltaY = $60a7
MoveSteps = $60a8
MoveDirection = $60a9
FixedSpeed = $60aa
FixedLow = $60ab
FixedHigh = $60ac
FixedRemainder = $60ad
BlockTile = $60ae
StompCount = $60af
HeadLandCount = $60b0
HeadJumpCount = $60b1
BrickCount = $60b2
StaggerCount = $60b3
JumpCount = $60b4
RocketCount = $60b5
RecallNeeded = $60b6
TempY = $60b7
NpcChain = $60b8
NpcChainTimer = $60b9
WorldHit = $60ba
SavedSteps = $60bb
SavedMoveDirection = $60bc
EnemyTop = $60bd
SavedProbeY = $60be
SpawnSavedX = $60bf
SpawnSavedPage = $60c0
SpawnSavedY = $60c1
SpawnSavedHigh = $60c2
NpcAnimationTick = $60c3
NpcFloorY = $60c4
NpcAirVX = $60c5
PartnerInput = $60c6
PrevPartnerInput = $60c7
NewPartnerInput = $60c8
BraceOn = $60c9
BraceHead = $60ca
BraceTimer = $60cb
BraceSpent = $60cc
FootWindow = $60cd
FootCooldown = $60ce
FootFacing = $60cf
DashTimer = $60d0
DashDirection = $60d1
MoodTimer = $60d2
MoodKind = $60d3
IdleTicks = $60d4
IdleDone = $60d5
HandWindow = $60d6
HandKind = $60d7
HandDirection = $60d8
AirSpent = $60d9
FireTurnMask = $60da
MushroomVolley = $60db
PrevMushY = $60dc
RenderDir = $60df
BraceLandCount = $60e0
BraceJumpCount = $60e1
ShellTurnCount = $60e2
MushroomPassCount = $60e3
ClapCount = $60e4
LookCount = $60e5
TapCount = $60e6
FireTurnCount = $60e7
AirTurnCount = $60e8
DashCount = $60e9
FootAttemptCount = $60ea
SupportTop = $60eb
TouchX = $60ed
TouchPage = $60ee
TouchY = $60ef
BracePlayerX = $60f1
BracePlayerPage = $60f2
BracePlayerY = $60f3
CoopDirection = $60f4
ContactSavedY = $60f5
CacheHeadDir = $60f6
GlyphIndex = $60f8
GlyphOffset = $60f9
GlyphSwap = $60fa
GlyphHalf = $60fb
WasPaused = $60fc
ActorBackup = $7f90
ScratchBackup = $7f80

.org $6100
PauseCooperationHook:
 JSR $8182
 PHP
 PHA
 LDA $0776
 AND #$01
 BNE CooperationPaused
 LDA WasPaused
 BEQ PauseCooperationDone
 LDA #$00
 STA WasPaused
 JMP ConsumePausedControls
CooperationPaused:
 LDA #$01
 STA WasPaused
ConsumePausedControls:
 TXA
 PHA
 TYA
 PHA
 JSR AuxPauseHook
 JSR StopCooperation
 LDX $0753
 LDA $06fc,X
 STA PrevInput
 LDA $06fd
 AND #$c0
 STA PrevPartnerInput
 LDA #$00
 STA NewPartnerInput
 PLA
 TAY
 PLA
 TAX
PauseCooperationDone:
 PLA
 PLP
 RTS

FrameHook:
 PHP
 PHA
 TXA
 PHA
 TYA
 PHA
 JSR ClearOwnedSprites
 PLA
 TAY
 PLA
 TAX
 PLA
 PLP
 JSR $8212
 PHP
 PHA
 TXA
 PHA
 TYA
 PHA
 INC FrameCount
 JSR WatchNativePlatforms
 JSR HudRefresh
 LDA #$16
 STA PaletteColor
 JSR CompanionPost
 PLA
 TAY
 PLA
 TAX
 PLA
 PLP
 RTS

RamStart:
 LDA #$00
 STA $e000
 STA $e000
 STA $e000
 STA $e000
 STA $e000
 JMP $7f00

PreCompanionHook:
 JSR $81c6
 PHP
 PHA
 TXA
 PHA
 TYA
 PHA
 JSR CompanionPre
 PLA
 TAY
 PLA
 TAX
 PLA
 PLP
 RTS

CompanionPre:
 JSR ReadPartnerInput
 JSR AuxInputHook
 LDX $0753
 LDA $06fc,X
 STA RawInput
 ; New edges are current AND NOT previous, including unfiltered A.
 LDA PrevInput
 EOR #$ff
 AND RawInput
 STA NewInput
 LDA RawInput
 STA PrevInput
 LDA $0776
 AND #$01
 BEQ PreUnpaused
 JSR StopCooperation
 RTS
PreUnpaused:
 LDA $0770
 CMP #$01
 BEQ PreGame
 CMP #$02
 BEQ PreHide
 JMP ClearCompanion
PreGame:
 LDA $0e
 CMP #$0b
 BEQ PreDeath
 CMP #$06
 BEQ PreDeath
 CMP #$08
 BEQ PrePlaying
 CMP #$09
 BEQ PreFreeze
 CMP #$0a
 BEQ PreFreeze
 CMP #$0c
 BEQ PreFreeze
PreHide:
 JSR StopCooperation
 JSR DropHead
 LDA #$00
 STA Active
 STA Stance
 STA RecallNeeded
 RTS
PreDeath:
 JMP ClearCompanion
PreFreeze:
 JSR StopCooperation
 JSR DropHead
 LDA #$00
 STA JumpBuffer
 STA NpcPose
 RTS
PrePlaying:
 LDA $d4
 STA PrevMushY
 LDA $ce
 STA PrevPlayerY
 LDA $b5
 STA PrevPlayerHigh
 LDA JumpBuffer
 BEQ BufferReady
 DEC JumpBuffer
BufferReady:
 LDA NewInput
 AND #$80
 BEQ NoNewJump
 LDA #$08
 STA JumpBuffer
NoNewJump:
 LDA HeadTimer
 BEQ HeadTimerReady
 DEC HeadTimer
HeadTimerReady:
 LDA HeadOn
 BEQ PreHeadReady
 LDA HeadTimer
 BNE PreHeadReady
 JSR DropHead
PreHeadReady:
 LDA Active
 BNE PreActive
 JSR StopCooperation
 LDA Wanted
 BEQ PreNeedsSummon
 LDA RecallNeeded
 BEQ PreSpawn
 LDA NewInput
 AND #$20
 BEQ PreInactiveDone
 JMP PreSpawn
PreNeedsSummon:
 LDA NewInput
 AND #$20
 BEQ PreInactiveDone
 LDA #$01
 STA Wanted
PreSpawn:
 JSR SpawnCompanion
PreInactiveDone:
 RTS
PreActive:
 INC NpcAnimationTick
 JSR SyncRenderSize
 LDA RenderSize
 CMP LastSize
 BEQ SameBodySize
 JSR DropHead
 LDA RenderSize
 STA LastSize
SameBodySize:
 JSR AuxPreHook
 JSR CooperationPre
 LDA NpcX
 STA PrevNpcX
 LDA NpcPage
 STA PrevNpcPage
 LDA NpcY
 STA PrevNpcY
 JSR GetHeadY
 LDA HeadY
 STA PrevHeadY
 LDA Stagger
 BEQ StaggerReady
 DEC Stagger
StaggerReady:
 LDA Recovery
 BEQ RecoveryReady
 DEC Recovery
RecoveryReady:
 LDA NpcChainTimer
 BEQ ChainExpired
 DEC NpcChainTimer
 JMP ChainReady
ChainExpired:
 LDA #$00
 STA NpcChain
ChainReady:
 JSR CommandInput
 JSR AuxSteerHook
 JSR AuxPhysicsHook
 JSR CarryHeadBeforePlayer
 JSR ChooseNpcPose
 JSR SafeFollowReturn
 RTS

ClearCompanion:
 JSR StopCooperation
 LDA #$00
 STA AirSpent
 STA BraceSpent
 STA FootCooldown
 STA MushroomVolley
 JSR DropHead
 LDA #$00
 STA Wanted
 STA Active
 STA Stance
 STA Stagger
 STA Recovery
 STA RecallNeeded
 STA JumpBuffer
 STA HeadSpent
 STA AuxPlatformOn
 RTS

CompanionPost:
 LDA $0770
 CMP #$01
 BNE PostHide
 LDA $0e
 CMP #$08
 BEQ PostDraw
 CMP #$09
 BEQ PostDraw
 CMP #$0a
 BEQ PostDraw
 CMP #$0c
 BEQ PostDraw
PostHide:
 LDA $0e
 CMP #$0b
 BEQ PostDeath
 CMP #$06
 BEQ PostDeath
 JSR DropHead
 LDA #$00
 STA Active
 STA Stance
 RTS
PostDeath:
 JMP ClearCompanion
PostDraw:
 LDA Active
 BEQ PostDone
 LDA NpcYHigh
 CMP #$01
 BNE PostDone
 JSR CooperationPost
 JSR AuxPostHook
 JSR DrawPlayerGesture
 JSR DrawCompanion
 JSR DrawAuxFan
 LDA RenderOK
 BNE PostDone
 JSR DropHead
PostDone:
 RTS

SpawnCompanion:
 LDA $1d
 BNE SpawnRejected
 LDA $b5
 CMP #$01
 BNE SpawnRejected
 LDA $ce
 CMP #$d0
 BCS SpawnRejected
 JMP SpawnReady
SpawnRejected:
 RTS
SpawnReady:
 LDA NpcX
 STA SpawnSavedX
 LDA NpcPage
 STA SpawnSavedPage
 LDA NpcY
 STA SpawnSavedY
 LDA NpcYHigh
 STA SpawnSavedHigh
 LDA $ce
 STA NpcY
 LDA #$01
 STA NpcYHigh
 LDA $33
 STA NpcDir
 CMP #$02
 BEQ SpawnRight
 LDA $86
 SEC
 SBC #$14
 STA NpcX
 LDA $6d
 SBC #$00
 BMI SpawnInvalid
 STA NpcPage
 JMP SpawnSpace
SpawnRight:
 LDA $86
 CLC
 ADC #$14
 STA NpcX
 LDA $6d
 ADC #$00
 STA NpcPage
SpawnSpace:
 JSR GroundAtNpc
 BEQ SpawnInvalid
 JSR BodyClear
 BEQ SpawnInvalid
 JSR SpawnEnemyClear
 BEQ SpawnInvalid
 JSR StopCooperation
 LDA #$01
 STA Active
 STA NpcGround
 INC SpawnCount
 LDA #$00
 STA NpcVX
 STA NpcVY
 STA NpcXFrac
 STA NpcYFrac
 STA Stance
 STA Stagger
 STA Recovery
 STA RecallNeeded
 STA BlockedFrames
 STA NpcJumpKind
 STA NpcPose
 STA NpcAnimationTick
 JSR SyncRenderSize
 LDA RenderSize
 STA LastSize
 LDA NpcX
 STA PrevNpcX
 LDA NpcPage
 STA PrevNpcPage
 LDA NpcY
 STA PrevNpcY
 STA NpcFloorY
SpawnDone:
 RTS
SpawnInvalid:
 LDA SpawnSavedX
 STA NpcX
 LDA SpawnSavedPage
 STA NpcPage
 LDA SpawnSavedY
 STA NpcY
 LDA SpawnSavedHigh
 STA NpcYHigh
 RTS

CommandInput:
 LDA NewInput
 AND #$20
 BNE CommandNew
 RTS
CommandNew:
 LDA HeadOn
 BNE CommandNormal
 LDA Stance
 BNE CommandNormal
 LDA BlockedFrames
 CMP #$20
 BCC CommandNormal
 ; This press requests safe arrival only; it never also attacks.
 JSR SpawnCompanion
 RTS
CommandNormal:
 LDA Stagger
 ORA Recovery
 BNE CommandDone
 LDA NpcGround
 BEQ CommandDone
 LDA RawInput
 AND #$0c
 CMP #$04
 BEQ CommandStance
 CMP #$08
 BEQ CommandVertical
 LDA HeadOn
 BNE CommandDone
 LDA RawInput
 AND #$03
 BEQ CommandFacing
 CMP #$03
 BEQ CommandFacing
 STA NpcDir
CommandFacing:
 LDA NpcDir
 CMP #$02
 BEQ CommandLeft
 LDA #$20
 BNE CommandForward
CommandLeft:
 LDA #$e0
CommandForward:
 STA NpcVX
 LDA #$01
 STA NpcJumpKind
 LDA #$a0
 JMP BeginNpcJump
CommandVertical:
 LDA #$00
 STA NpcVX
 LDA #$02
 STA NpcJumpKind
 LDA HeadOn
 BEQ VerticalAlone
 INC RocketCount
VerticalAlone:
 LDA #$90
 JMP BeginNpcJump
CommandStance:
 LDA HeadOn
 BNE CommandDone
 LDA Stance
 EOR #$01
 STA Stance
 LDA #$00
 STA NpcVX
CommandDone:
 RTS

BeginNpcJump:
 STA NpcVY
 LDA BraceHead
 BEQ BeginNpcUnloaded
 INC BraceJumpCount
 LDA #$00
 STA BraceHead
 STA BraceTimer
BeginNpcUnloaded:
 LDA NpcVX
 STA NpcAirVX
 LDA #$00
 STA NpcGround
 STA NpcXFrac
 STA NpcYFrac
 STA Stance
 INC JumpCount
 LDA #$01
 STA $ff
 RTS

ChooseNpcPose:
 LDA Stagger
 BEQ PoseHealthy
 LDA #$07
 STA NpcPose
 RTS
PoseHealthy:
 LDA NpcGround
 BNE PoseGrounded
 LDA #$03
 STA NpcPose
 RTS
PoseGrounded:
 LDA NpcX
 CMP PrevNpcX
 BNE PoseWalking
 LDA #$00
 STA NpcPose
 RTS
PoseWalking:
 LDA NpcAnimationTick
 AND #$08
 BEQ PoseWalk1
 LDA #$02
 BNE PoseStore
PoseWalk1:
 LDA #$01
PoseStore:
 STA NpcPose
 RTS

SafeFollowReturn:
 LDA Active
 BNE ReturnActive
 RTS
ReturnActive:
 LDA HeadOn
 ORA BraceHead
 BEQ ReturnUnloaded
 RTS
ReturnUnloaded:
 LDA Stance
 BEQ ReturnTrack
 LDA NpcX
 SEC
 SBC $071c
 LDA NpcPage
 SBC $071a
 BMI ReturnStanceOff
 RTS
ReturnStanceOff:
 LDA #$00
 STA Stance
 JMP ReturnDistance
ReturnTrack:
 LDA NpcX
 CMP PrevNpcX
 BNE ReturnMoved
 LDA NpcPage
 CMP PrevNpcPage
 BNE ReturnMoved
 LDA $86
 SEC
 SBC NpcX
 STA Distance
 LDA $6d
 SBC NpcPage
 BEQ ReturnNearbyRight
 CMP #$ff
 BNE ReturnBlocked
 LDA Distance
 CMP #$e8
 BCC ReturnBlocked
 JMP ReturnCheckHeight
ReturnNearbyRight:
 LDA Distance
 CMP #$18
 BCS ReturnBlocked
ReturnCheckHeight:
 ; Compare the last actual support surface, not a transient jump apex.
 LDA $ce
 SEC
 SBC NpcFloorY
 CLC
 ADC #$10
 CMP #$21
 BCS ReturnBlocked
ReturnMoved:
 LDA #$00
 STA BlockedFrames
 JMP ReturnDistance
ReturnBlocked:
 LDA BlockedFrames
 CMP #$ff
 BEQ ReturnBlockedReady
 INC BlockedFrames
ReturnBlockedReady:
 LDA BlockedFrames
 CMP #$60
 BCC ReturnDistance
 LDA $1d
 BNE ReturnDone
 JSR SpawnCompanion
 RTS
ReturnDistance:
 LDA $1d
 BNE ReturnDone
 LDA NpcX
 SEC
 SBC $071c
 LDA NpcPage
 SBC $071a
 BPL ReturnDone
 JSR SpawnCompanion
ReturnDone:
 RTS

SpawnEnemyClear:
 LDX #$00
SpawnEnemyLoop:
 LDA $0f,X
 BEQ SpawnEnemyNext
 LDA $87,X
 SEC
 SBC NpcX
 STA Distance
 LDA $6e,X
 SBC NpcPage
 BEQ SpawnEnemyRight
 CMP #$ff
 BNE SpawnEnemyNext
 LDA Distance
 CMP #$f1
 BCC SpawnEnemyNext
 JMP SpawnEnemyY
SpawnEnemyRight:
 LDA Distance
 CMP #$10
 BCS SpawnEnemyNext
SpawnEnemyY:
 LDA $cf,X
 SEC
 SBC NpcY
 CLC
 ADC #$18
 CMP #$38
 BCC SpawnOccupied
SpawnEnemyNext:
 INX
 CPX #$05
 BCC SpawnEnemyLoop
 LDA #$01
 RTS
SpawnOccupied:
 LDA #$00
 RTS
