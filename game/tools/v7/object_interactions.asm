; Native bounds are produced before the player/enemy gateway. Touch windows
; change the same native object once, never create rewards or duplicate slots.
FootMaterialContact:
 LDA FootWindow
 BEQ FootMaterialNo
 LDA BraceHead
 ORA HeadOn
 ORA Stagger
 BNE FootMaterialNo
 LDA NpcGround
 BEQ FootMaterialNo
 JSR $dc52
 LDA NpcX
 SEC
 SBC $071c
 STA ScreenX
 LDA NpcPage
 SBC $071a
 BNE FootMaterialNo
 LDA ScreenX
 CMP #$08
 BCC FootMaterialNo
 CMP #$e8
 BCS FootMaterialNo
 LDA FootFacing
 CMP #$02
 BEQ FootPointLeft
 LDA ScreenX
 CLC
 ADC #$0d
 BNE FootPointReady
FootPointLeft:
 LDA ScreenX
 CLC
 ADC #$02
FootPointReady:
 STA TouchX
 CLC
 ADC #$02
 CMP $04ac,Y
 BCC FootMaterialNo
 LDA TouchX
 SEC
 SBC #$02
 CMP $04ae,Y
 BCS FootMaterialNo
 LDA NpcY
 CLC
 ADC #$20
 CMP $04ad,Y
 BCC FootMaterialNo
 LDA NpcY
 CLC
 ADC #$1c
 CMP $04af,Y
 BCS FootMaterialNo
 LDA #$01
 RTS
FootMaterialNo:
 LDA #$00
 RTS

FinishFootTouch:
 JSR CoopTouchSound
 LDA #$00
 STA FootWindow
 LDA #$14
 STA FootCooldown
 LDA #$04
 STA MoodKind
 LDA #$06
 STA MoodTimer
 LDA #$01
 RTS

TryShellReturn:
 LDA FootWindow
 BEQ ShellReturnNo
 LDX SkillSlot
 LDA $16,X
 CMP #$00
 BEQ ShellReturnType
 CMP #$02
 BEQ ShellReturnType
 CMP #$03
 BNE ShellReturnNo
ShellReturnType:
 LDA $1e,X
 BPL ShellReturnNo
 AND #$20
 BNE ShellReturnNo
 LDA $58,X
 BEQ ShellReturnNo
 LDA FootFacing
 CMP #$02
 BEQ ShellIncomingLeft
 LDA $58,X
 BPL ShellReturnNo
 JMP ShellTouch
ShellIncomingLeft:
 LDA $58,X
 BMI ShellReturnNo
ShellTouch:
 JSR FootMaterialContact
 BEQ ShellReturnNo
 LDX SkillSlot
 LDA $58,X
 EOR #$ff
 CLC
 ADC #$01
 STA $58,X
 LDA $46,X
 EOR #$03
 STA $46,X
 INC ShellTurnCount
 JMP FinishFootTouch
ShellReturnNo:
 LDA #$00
 RTS

TryMushroomPass:
 LDA FootWindow
 BEQ MushroomPassNo
 LDA MushroomVolley
 BNE MushroomPassNo
 LDA $0e
 CMP #$08
 BNE MushroomPassNo
 LDA $14
 CMP #$01
 BNE MushroomPassNo
 LDA $1b
 CMP #$2e
 BNE MushroomPassNo
 LDA $39
 BNE MushroomPassNo
 LDA $23
 BPL MushroomPassNo
 LDA $bb
 CMP #$01
 BNE MushroomPassNo
 LDX #$05
 JSR FootMaterialContact
 BEQ MushroomPassNo
 LDA #$01
 STA MushroomVolley
 LDA $23
 ORA #$40
 STA $23
 LDA #$fd
 STA $a5
 LDA #$00
 STA $0439
 STA $041c
 LDA FootFacing
 STA $4b
 CMP #$02
 BEQ MushroomPassLeft
 LDA #$18
 BNE MushroomPassVelocity
MushroomPassLeft:
 LDA #$e8
MushroomPassVelocity:
 STA $5d
 INC MushroomPassCount
 JMP FinishFootTouch
MushroomPassNo:
 RTS

PowerupBGHook:
 JSR $dfc1
 PHP
 PHA
 TXA
 PHA
 TYA
 PHA
 JSR SaveNativeScratch
 JSR MushroomRoof
 JSR RestoreNativeScratch
 PLA
 TAY
 PLA
 TAX
 PLA
 PLP
 RTS

MushroomRoof:
 LDA MushroomVolley
 BEQ MushroomRoofDone
 LDA $14
 CMP #$01
 BNE EndMushroomVolley
 LDA $1b
 CMP #$2e
 BNE EndMushroomVolley
 LDA $39
 BNE EndMushroomVolley
 LDA $23
 AND #$40
 BEQ RestoreMushroomWalk
 LDA $a5
 BPL MushroomRoofDone
 LDA $bb
 CMP #$01
 BNE MushroomRoofDone
 LDA $d4
 CMP PrevMushY
 BCS MushroomRoofDone
 CLC
 ADC #$09
 STA ProbeY
 LDA $8c
 CLC
 ADC #$02
 STA ProbeX
 LDA $73
 ADC #$00
 STA ProbePage
 JSR ReadPoint
 JSR IsSolid
 BNE MushroomHitRoof
 LDA $8c
 CLC
 ADC #$0d
 STA ProbeX
 LDA $73
 ADC #$00
 STA ProbePage
 JSR ReadPoint
 JSR IsSolid
 BEQ MushroomRoofDone
MushroomHitRoof:
 LDA ProbeY
 AND #$f0
 CLC
 ADC #$10
 SEC
 SBC #$09
 STA $d4
 LDA #$00
 STA $a5
 STA $0439
 STA $041c
 RTS
EndMushroomVolley:
 LDA #$00
 STA MushroomVolley
MushroomRoofDone:
 RTS
RestoreMushroomWalk:
 LDA $5d
 BMI RestoreMushroomLeft
 LDA #$10
 BNE RestoreMushroomSpeed
RestoreMushroomLeft:
 LDA #$f0
RestoreMushroomSpeed:
 STA $5d
 JMP EndMushroomVolley
