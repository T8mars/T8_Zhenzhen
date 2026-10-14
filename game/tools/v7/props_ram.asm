DrawAuxFan:
 LDA AuxFanTimer
 ORA AuxGlideTimer
 BNE DrawFanActive
 RTS
DrawFanActive:
 LDA OwnedCount
 CMP #$0e
 BCS DrawFanDone
 LDX $06e4
 LDA $0754
 BEQ DrawFanHeadReady
 TXA
 CLC
 ADC #$10
 TAX
DrawFanHeadReady:
 LDA AuxState
 CMP #BACK_LOAD
 BNE DrawFanPlayerTop
 LDA ActorTop
 JMP DrawFanTopChosen
DrawFanPlayerTop:
 LDA $0200,X
DrawFanTopChosen:
 CMP #$20
 BCC DrawFanDone
 CMP #$e0
 BCS DrawFanDone
 SEC
 SBC #$08
 STA GlyphOffset
 LDA $0203,X
 STA GlyphIndex
 LDA #$00
 STA GlyphHalf
 LDX #$04
DrawFanFindSlot:
 LDA $0200,X
 CMP #$f0
 BCC DrawFanNextSlot
 LDY OwnedCount
 TXA
 STA OwnedSlots,Y
 LDA GlyphOffset
 STA $0200,X
 LDY GlyphHalf
 LDA FanPropTiles,Y
 STA $0201,X
 LDA #$00
 STA $0202,X
 LDA GlyphIndex
 STA $0203,X
 CLC
 ADC #$08
 STA GlyphIndex
 INC OwnedCount
 INC GlyphHalf
 LDA GlyphHalf
 CMP #$02
 BCS DrawFanDone
DrawFanNextSlot:
 INX
 INX
 INX
 INX
 BNE DrawFanFindSlot
DrawFanDone:
 RTS
