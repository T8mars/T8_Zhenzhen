; Preserved native-palette and exact authored-pose renderer from v4.
GameTextHook:
 STA TextRequest
 JSR OriginalText
 PHP
 PHA
 TXA
 PHA
 TYA
 PHA
 LDA TextRequest
 CMP #$01
 BEQ FixIntro
 CMP #$00
 BNE TextDone
 JSR DecimalLives
 STA $0308
 STX $0307
 JMP TextDone
FixIntro:
 JSR DecimalLives
 STA $0309
 STX $0308
TextDone:
 PLA
 TAY
 PLA
 TAX
 PLA
 PLP
 RTS
OriginalText:
 ; Displaced original entry, preserving its own balanced PHA/PLA.
 PHA
 ASL A
 TAY
 JMP $880b

DecimalLives:
 LDA $075a
 CLC
 ADC #$01
 CMP #$64
 BCC LivesBounded
 LDA #$63
LivesBounded:
 LDX #$00
DecimalLoop:
 CMP #$0a
 BCC DecimalDone
 SBC #$0a
 INX
 JMP DecimalLoop
DecimalDone:
 RTS

HudRefresh:
 LDA $0770
 CMP #$01
 BNE HudDone
 LDA $0e
 CMP #$08
 BNE HudDone
 LDA $075a
 CMP HudSeen
 BEQ HudDone
 LDA $0773
 BNE HudDone
 LDY $0300
 ; Buffer1 data is0301..033F;0340 belongs to Buffer2's offset.
 ; Append five command bytes plus one terminating byte without crossing it.
 CPY #$3a
 BCS HudDone
 JSR DecimalLives
 STA LifeOnes
 STX LifeTens
 LDA #$20
 STA $0301,Y
 INY
 LDA #$46
 STA $0301,Y
 INY
 LDA #$02
 STA $0301,Y
 INY
 LDA LifeTens
 STA $0301,Y
 INY
 LDA LifeOnes
 STA $0301,Y
 INY
 LDA #$00
 STA $0301,Y
 STY $0300
 LDA $075a
 STA HudSeen
HudDone:
 RTS

VblankHook:
 JSR $8edd
 PHP
 PHA
 TXA
 PHA
 TYA
 PHA
 JSR PaletteWrite
 PLA
 TAY
 PLA
 TAX
 PLA
 PLP
 RTS
PaletteWrite:
 LDA $2002
 LDA #$3f
 STA $2006
 LDA #$19
 STA $2006
 LDA PaletteColor
 STA $2007
 LDA #$00
 STA $2006
 STA $2006
 RTS

ClearOwnedSprites:
 ; Original object drawing has not run yet. Only our previous buffer slots
 ; may remain here; the earlier source clear can already have hidden them.
 LDX #$00
 LDA OwnedCount
 STA LastSlotCount
 BEQ ClearOwnedDone
ClearOwnedLoop:
 LDY OwnedSlots,X
 LDA #$f8
 STA $0200,Y
 INX
 CPX OwnedCount
 BCC ClearOwnedLoop
 LDA #$00
 STA OwnedCount
ClearOwnedDone:
 RTS

GetSourceRed:
 ; Check the source object's actual current OAM before choosing blue/red.
 LDX #$00
SourceColorLoop:
 LDA $0202,X
 AND #$03
 CMP #$02
 BNE SourceNext0
 LDA $0200,X
 CMP #$f0
 BCC SourceRedFound
SourceNext0:
 LDA $0206,X
 AND #$03
 CMP #$02
 BNE SourceNext1
 LDA $0204,X
 CMP #$f0
 BCC SourceRedFound
SourceNext1:
 LDA $020a,X
 AND #$03
 CMP #$02
 BNE SourceNext2
 LDA $0208,X
 CMP #$f0
 BCC SourceRedFound
SourceNext2:
 LDA $020e,X
 AND #$03
 CMP #$02
 BNE SourceNext3
 LDA $020c,X
 CMP #$f0
 BCC SourceRedFound
SourceNext3:
 TXA
 CLC
 ADC #$10
 TAX
 BNE SourceColorLoop
 LDA #$00
 RTS
SourceRedFound:
 LDA #$01
 RTS


DrawCompanion:
 LDA #$00
 STA RenderOK
 LDA NpcX
 SEC
 SBC $071c
 STA ScreenX
 LDA NpcPage
 SBC $071a
 BEQ DrawOnPage
 RTS
DrawOnPage:
 LDA ScreenX
 CMP #$f0
 BCC DrawVisibleX
 RTS
DrawVisibleX:
 LDA NpcY
 CMP #$d0
 BCC DrawVisibleY
 RTS
DrawVisibleY:
 JSR SyncRenderSize
 LDA #$08
 STA SpriteCount
 LDA NpcY
 STA ActorTop
 LDA RenderSize
 BEQ DrawSizeReady
 CMP #$02
 BEQ DrawMedium
 LDA #$04
 STA SpriteCount
 LDA ActorTop
 CLC
 ADC #$10
 STA ActorTop
 JMP DrawSizeReady
DrawMedium:
 LDA #$06
 STA SpriteCount
 LDA ActorTop
 CLC
 ADC #$08
 STA ActorTop
DrawSizeReady:
 LDA LastSlotCount
 CMP SpriteCount
 BCC AllocateFresh
 LDX #$00
ValidateCachedSlot:
 LDY OwnedSlots,X
 LDA $0200,Y
 CMP #$f0
 BCC AllocateFresh
 INX
 CPX SpriteCount
 BCC ValidateCachedSlot
 JSR GetSourceRed
 STA SourceNeedsRed
 JMP HaveEnough
AllocateFresh:
 LDA #$00
 STA SourceNeedsRed
 LDX #$04
 LDY #$00
CountFree:
 LDA $0200,X
 CMP #$f0
 BCS RecordFree
 LDA $0202,X
 AND #$03
 CMP #$02
 BNE CountNext
 LDA #$01
 STA SourceNeedsRed
 CPY SpriteCount
 BCS HaveEnough
 JMP CountNext
RecordFree:
 CPY SpriteCount
 BCS CountNext
 TXA
 STA OwnedSlots,Y
 INY
 CPY SpriteCount
 BCC CountNext
 LDA SourceNeedsRed
 BNE HaveEnough
CountNext:
 INX
 INX
 INX
 INX
 BNE CountFree
 CPY SpriteCount
 BCS HaveEnough
 RTS
HaveEnough:
 LDA SourceNeedsRed
 BNE FreePaletteReady
 LDA #$01
 STA PaletteColor
FreePaletteReady:
 JSR CacheSpriteTemplate
 LDA #$00
 STA SpriteIndex
PlotSprite:
 LDX SpriteIndex
 LDY OwnedSlots,X
 TXA
 ASL A
 ASL A
 TAX
 LDA $6040,X
 CLC
 ADC ActorTop
 STA $0200,Y
 LDA $6041,X
 STA $0201,Y
 LDA $6042,X
 STA $0202,Y
 LDA $6043,X
 CLC
 ADC ScreenX
 STA $0203,Y
 INC SpriteIndex
 LDA SpriteIndex
 CMP SpriteCount
 BCC PlotSprite
 LDA #$01
 STA RenderOK
 LDA SpriteCount
 STA OwnedCount
 RTS

SyncRenderSize:
 LDA $0754
 STA RenderSize
 LDA $0e
 CMP #$09
 BEQ SyncChangeSize
 CMP #$0a
 BNE SyncSizeDone
SyncChangeSize:
 LDA $06d5
 CMP #$c0
 BEQ SyncMedium
 CMP #$c8
 BCS SyncBig
 CMP #$60
 BCC SyncBig
 LDA #$01
 BNE SyncStore
SyncMedium:
 LDA #$02
 BNE SyncStore
SyncBig:
 LDA #$00
SyncStore:
 STA RenderSize
SyncSizeDone:
 RTS


ReadPoint:
 ; Block-buffer collision coordinates, preserving parsed world page parity.
 LDA ProbeY
 CMP #$20
 BCC PointEmpty
 CMP #$f0
 BCS PointEmpty
 SEC
 SBC #$20
 AND #$f0
 STA ProbeRow
 LDA ProbeX
 LSR A
 LSR A
 LSR A
 LSR A
 ORA ProbeRow
 TAY
 LDA ProbePage
 AND #$01
 BNE PointOdd
 LDA $0500,Y
 RTS
PointOdd:
 LDA $05d0,Y
 RTS
PointEmpty:
 LDA #$00
 RTS

IsSolid:
 BEQ SolidNo
 JSR $e1b5
 BEQ SolidNo
 ; Native climb upper extents:24,6D,8A,C6 are pass-through.
 CMP #$c0
 BCS SolidGroup3
 CMP #$80
 BCS SolidGroup2
 CMP #$40
 BCS SolidGroup1
 CMP #$24
 BCS SolidNo
 JMP SolidYes
SolidGroup1:
 CMP #$6d
 BCS SolidNo
 JMP SolidYes
SolidGroup2:
 CMP #$8a
 BCS SolidNo
 JMP SolidYes
SolidGroup3:
 CMP #$c6
 BCS SolidNo
SolidYes:
 LDA #$01
 RTS
SolidNo:
 LDA #$00
 RTS

BodyClear:
 LDA NpcY
 CLC
 ADC #$02
 LDY $0754
 BEQ BodyTopReady
 CLC
 ADC #$10
BodyTopReady:
 STA ProbeY
 LDA NpcY
 CLC
 ADC #$1d
 AND #$f0
 STA ProbeColumn
BodyRowLoop:
 JSR NpcRowClear
 BEQ BodyNotClear
 LDA ProbeY
 AND #$f0
 CMP ProbeColumn
 BEQ BodyAllClear
 LDA ProbeY
 CLC
 ADC #$10
 STA ProbeY
 JMP BodyRowLoop
BodyAllClear:
 LDA #$01
 RTS
BodyNotClear:
 RTS
NpcRowClear:
 LDA NpcX
 CLC
 ADC #$02
 STA ProbeX
 LDA NpcPage
 ADC #$00
 STA ProbePage
 JSR ReadPoint
 JSR IsSolid
 BNE RowBlocked
 LDA NpcX
 CLC
 ADC #$0d
 TAX
 EOR ProbeX
 AND #$f0
 BEQ RowAlreadyClear
 TXA
 STA ProbeX
 LDA NpcX
 CLC
 ADC #$0d
 LDA NpcPage
 ADC #$00
 STA ProbePage
 JSR ReadPoint
 JSR IsSolid
 BNE RowBlocked
RowAlreadyClear:
 LDA #$01
 RTS
RowBlocked:
 LDA #$00
 RTS
