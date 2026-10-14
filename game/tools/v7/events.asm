; Native producers own object transitions, rewards and VRAM block updates.
; Scratch and temporary actor coordinates are restored at this boundary.
SaveNativeScratch:
 LDX #$08
SaveScratchLoop:
 LDA $00,X
 STA ScratchBackup,X
 DEX
 BPL SaveScratchLoop
 RTS
RestoreNativeScratch:
 LDX #$08
RestoreScratchLoop:
 LDA ScratchBackup,X
 STA $00,X
 DEX
 BPL RestoreScratchLoop
 RTS

BumpNativeBlock:
 LDA $0784
 BNE BumpRejected
 LDA $074e
 BEQ BumpRejected
 JSR SaveNativeScratch
 LDA BlockTile
 JSR $df8f
 BCC BumpAccepted
 JSR RestoreNativeScratch
BumpRejected:
 RTS
BumpAccepted:
 LDA MoveSteps
 STA SavedSteps
 LDA MoveDirection
 STA SavedMoveDirection
 LDA ProbeY
 STA SavedProbeY
 LDA $86
 STA ActorBackup
 LDA $6d
 STA ActorBackup+1
 LDA $ce
 STA ActorBackup+2
 LDA $b5
 STA ActorBackup+3
 LDA $9f
 STA ActorBackup+4
 LDA $0714
 STA ActorBackup+5
 LDA #$00
 STA $0714
 LDA NpcX
 STA $86
 LDA NpcPage
 STA $6d
 LDA #$01
 STA $b5
 LDA SavedProbeY
 AND #$f0
 STA TempY
 LDY $0754
 LDA TempY
 SEC
 SBC $bceb,Y
BlockActorYReady:
 STA $ce
 ; Block buffer pointer uses exactly the collision's world page and column.
 LDA ProbeX
 LSR A
 LSR A
 LSR A
 LSR A
 STA $06
 LDA ProbePage
 AND #$01
 BEQ BlockBufferEven
 LDA $06
 CLC
 ADC #$d0
 STA $06
BlockBufferEven:
 LDA #$05
 STA $07
 LDA SavedProbeY
 SEC
 SBC #$20
 AND #$f0
 STA $02
 LDA BlockTile
 JSR $bced
 INC BrickCount
 LDA ActorBackup
 STA $86
 LDA ActorBackup+1
 STA $6d
 LDA ActorBackup+2
 STA $ce
 LDA ActorBackup+3
 STA $b5
 LDA ActorBackup+4
 STA $9f
 LDA ActorBackup+5
 STA $0714
 JSR RestoreNativeScratch
 LDA SavedSteps
 STA MoveSteps
 LDA SavedMoveDirection
 STA MoveDirection
BumpDone:
 RTS

PlayerEnemyHook:
 JSR OriginalPlayerEnemy
 PHP
 PHA
 TXA
 PHA
 TYA
 PHA
 JSR CompanionEnemyContact
 PLA
 TAY
 PLA
 TAX
 PLA
 PLP
 RTS
OriginalPlayerEnemy:
 LDA $09
 LSR A
 JMP $d856

CompanionEnemyContact:
 LDA Active
 BEQ EnemyRejected
 LDA Stagger
 BNE EnemyRejected
 LDA $0e
 CMP #$08
 BNE EnemyRejected
 LDA $074e
 BEQ EnemyRejected
 LDX $08
 CPX #$05
 BNE CompanionRegularEnemy
 JSR TryMushroomPass
 RTS
CompanionRegularEnemy:
 CPX #$05
 BCS EnemyRejected
 STX SkillSlot
 LDA $0f,X
 CMP #$01
 BNE EnemyRejected
 LDA $b6,X
 CMP #$01
 BNE EnemyRejected
 LDA $03d8,X
 BNE EnemyRejected
 LDA $16,X
 CMP #$33
 BEQ EnemyTypeAccepted
 CMP #$15
 BCS EnemyRejected
EnemyTypeAccepted:
 LDA $1e,X
 AND #$20
 BNE EnemyRejected
 LDA $1e,X
 BMI EnemyContactLive
 AND #$07
 CMP #$02
 BCS EnemyRejected
 JMP EnemyContactLive
EnemyRejected:
 RTS
EnemyContactLive:
 JSR AuxEnemyHook
 LDA AuxHandled
 BEQ AuxEnemyLegacy
 RTS
AuxEnemyLegacy:
 JSR $dc52
 LDA NpcX
 SEC
 SBC $071c
 STA ScreenX
 LDA NpcPage
 SBC $071a
 BNE EnemyBoundsMiss
 LDA ScreenX
 CLC
 ADC #$0d
 CMP $04ac,Y
 BCC EnemyBoundsMiss
 LDA ScreenX
 CLC
 ADC #$02
 CMP $04ae,Y
 BCS EnemyBoundsMiss
 LDA $04ad,Y
 STA EnemyTop
 LDA NpcY
 CLC
 ADC #$20
 CMP EnemyTop
 BCC EnemyBoundsMiss
 LDX RenderSize
 LDA NpcY
 CLC
 ADC HeadYOffset,X
 CMP $04af,Y
 BCS EnemyBoundsMiss
 JMP EnemyBoundsHit
EnemyBoundsMiss:
 RTS
EnemyBoundsHit:
 JSR TryShellReturn
 BEQ EnemyNoReturn
 RTS
EnemyNoReturn:
 LDA NpcVY
 BMI EnemySideHit
 LDA NpcY
 CMP PrevNpcY
 BEQ EnemySideHit
 BCC EnemySideHit
 LDA PrevNpcY
 CLC
 ADC #$20
 CMP EnemyTop
 BEQ EnemyCanStomp
 BCS EnemySideHit
EnemyCanStomp:
 LDX SkillSlot
 LDA $16,X
 CMP #$12
 BEQ EnemySideHit
 CMP #$0d
 BEQ EnemySideHit
 CMP #$0c
 BEQ EnemySideHit
 JSR StompNativeEnemy
 RTS
EnemySideHit:
 JSR StopNpcCooperation
 LDA #$12
 STA Stagger
 LDA #$00
 STA NpcVX
 INC StaggerCount
 JSR DropHead
EnemyContactDone:
 RTS

StompNativeEnemy:
 JSR SaveNativeScratch
 LDA $9f
 STA ActorBackup
 LDA $0484
 STA ActorBackup+1
 LDA $0791
 STA ActorBackup+2
 LDA NpcChain
 STA $0484
 LDA NpcChainTimer
 STA $0791
 LDX SkillSlot
 STX $08
 JSR $d969
 LDA $9f
 ASL A
 ASL A
 ASL A
 ASL A
 STA NpcVY
 LDA $0484
 STA NpcChain
 LDA $0791
 STA NpcChainTimer
 LDA ActorBackup
 STA $9f
 LDA ActorBackup+1
 STA $0484
 LDA ActorBackup+2
 STA $0791
 JSR RestoreNativeScratch
 LDA #$00
 STA NpcGround
 STA NpcYFrac
 STA Recovery
 ; Stomp contact ends the commanded forward lunge. Rebound is vertical,
 ; leaving the second target and the handoff timing to the human player.
 STA NpcVX
 LDA #$03
 STA NpcJumpKind
 INC StompCount
 RTS
