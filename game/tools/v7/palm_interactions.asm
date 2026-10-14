; Fireball lifetime identity is reset at the native spawn producer, including
; destruction and immediate reuse of the same slot in one frame.
FireballSpawnHook:
 STY $0711
 PHP
 PHA
 LDA FireTurnMask
 AND FireBitClear,X
 STA FireTurnMask
 PLA
 PLP
 RTS
FireBit:
.byte $01,$02
FireBitClear:
.byte $fe,$fd
HandYOffset:
.byte $14,$1b,$14

FireHandYOffset:
.byte $18,$1e,$18

GetPalmPoint:
 LDX RenderSize
 LDA HandKind
 CMP #$01
 BNE GetAirPalmY
 LDA NpcY
 CLC
 ADC FireHandYOffset,X
 JMP PalmYReady
GetAirPalmY:
 LDA NpcY
 CLC
 ADC HandYOffset,X
PalmYReady:
 STA TouchY
 LDA FootFacing
 CMP #$02
 BEQ PalmPointLeft
 LDA NpcX
 CLC
 ADC #$0e
 JMP PalmPointX
PalmPointLeft:
 LDA NpcX
 CLC
 ADC #$01
PalmPointX:
 STA TouchX
 LDA NpcPage
 ADC #$00
 STA TouchPage
 RTS

PalmContacts:
 LDA HandWindow
 BEQ PalmContactDone
 LDA Stagger
 ORA HeadOn
 ORA BraceHead
 BNE PalmContactDone
 JSR CompanionContactVisible
 BEQ PalmContactDone
 JSR GetPalmPoint
 LDA HandKind
 CMP #$01
 BNE AirPalmContact
 LDX #$00
FirePalmLoop:
 LDA FireTurnMask
 AND FireBit,X
 BNE FirePalmNext
 LDA $24,X
 CMP #$01
 BNE FirePalmNext
 LDA $bc,X
 CMP #$01
 BNE FirePalmNext
 LDA TouchX
 SEC
 SBC $8d,X
 STA Distance
 LDA TouchPage
 SBC $74,X
 BNE FirePalmNext
 LDA Distance
 CMP #$08
 BCS FirePalmNext
 LDA TouchY
 SEC
 SBC $d5,X
 CMP #$08
 BCS FirePalmNext
 LDA #$fc
 STA $a6,X
 LDA #$00
 STA $043a,X
 STA $041d,X
 LDA FireTurnMask
 ORA FireBit,X
 STA FireTurnMask
 INC FireTurnCount
 JMP FinishPalmTouch
FirePalmNext:
 INX
 CPX #$02
 BCC FirePalmLoop
PalmContactDone:
 RTS

AirPalmContact:
 LDA AirSpent
 BNE PalmContactDone
 LDA $1d
 CMP #$01
 BCC PalmContactDone
 CMP #$03
 BCS PalmContactDone
 LDA $9f
 BMI PalmContactDone
 LDA $b5
 CMP #$01
 BNE PalmContactDone
 LDA $ce
 CMP PrevPlayerY
 BCC PalmContactDone
 BEQ PalmContactDone
 LDA $ce
 LDY $0754
 BEQ AirPalmBig
 CLC
 ADC #$1b
 BNE AirPalmY
AirPalmBig:
 CLC
 ADC #$14
AirPalmY:
 SEC
 SBC TouchY
 CLC
 ADC #$04
 CMP #$09
 BCS AirPalmDone
 JSR GetPartnerDelta
 LDA TempY
 BEQ AirPalmPlayerRight
 CMP #$ff
 BNE AirPalmDone
 LDA FootFacing
 CMP #$02
 BNE AirPalmDone
 LDA Distance
 CMP #$f0
 BCC AirPalmDone
 CMP #$f7
 BCS AirPalmDone
 JMP AirPalmVelocity
AirPalmPlayerRight:
 LDA FootFacing
 CMP #$01
 BNE AirPalmDone
 LDA Distance
 CMP #$0a
 BCC AirPalmDone
 CMP #$11
 BCS AirPalmDone
AirPalmVelocity:
 LDA HandDirection
 CMP #$02
 BEQ AirPalmLeft
 LDA #$28
 BNE AirPalmSpeed
AirPalmLeft:
 LDA #$d8
AirPalmSpeed:
 STA $57
 LDA #$01
 STA AirSpent
 INC AirTurnCount
FinishPalmTouch:
 JSR CoopTouchSound
 LDA #$00
 STA HandWindow
 LDA #$05
 STA MoodKind
 LDA #$06
 STA MoodTimer
AirPalmDone:
 RTS
