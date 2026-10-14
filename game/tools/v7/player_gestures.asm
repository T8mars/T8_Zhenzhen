; Replace only the current native player's designated row before companion
; OAM allocation. Blank/offscreen/blinking native rows stay untouched.
DrawPlayerGesture:
 LDA BraceOn
 BEQ PlayerGestureBody
 LDA $0754
 BEQ GestureBigHead
 LDY #$04
 LDX #$02
 BNE GestureRowReady
GestureBigHead:
 LDY #$00
 LDX #$00
 BEQ GestureRowReady
PlayerGestureBody:
 LDA AuxState
 CMP #FAN_HIDE
 BEQ GestureUseBody
 CMP #LIFT_HOLD
 BEQ GestureUseBody
 CMP #BRAKE_ON
 BEQ GestureUseBody
 LDA AuxPlayerPose
 ORA AuxFanTimer
 ORA AuxGlideTimer
 BNE GestureUseBody
 LDA MoodTimer
 BEQ PlayerGestureHand
 LDA MoodKind
 CMP #$02
 BEQ GestureUseBody
 CMP #$05
 BNE PlayerGestureHand
 LDA HandKind
 CMP #$02
 BEQ GestureUseBody
PlayerGestureHand:
 LDA HandWindow
 BEQ PlayerGestureDash
 LDA HandKind
 CMP #$02
 BEQ GestureUseBody
PlayerGestureDash:
 LDA DashTimer
 CMP #$0e
 BCS GestureUseBody
 RTS
GestureUseBody:
 LDA $0754
 BEQ GestureBigBody
 LDY #$06
 BNE GestureBodyIndex
GestureBigBody:
 LDY #$04
GestureBodyIndex:
 LDX #$04
GestureRowReady:
 STX GlyphOffset
 TYA
 ASL A
 ASL A
 CLC
 ADC $06e4
 STA GlyphIndex
 LDA $33
 CMP #$02
 BEQ GestureLeftFacing
 LDA #$00
 BEQ GestureFacingReady
GestureLeftFacing:
 LDA #$01
GestureFacingReady:
 STA GlyphSwap
 LDX #$00
GestureHalfLoop:
 TXA
 ASL A
 ASL A
 CLC
 ADC GlyphIndex
 TAY
 LDA $0200,Y
 CMP #$f0
 BCS GestureHalfNext
 LDA $0201,Y
 CMP #$fc
 BEQ GestureHalfNext
 TXA
 EOR GlyphSwap
 CLC
 ADC GlyphOffset
 STX GlyphHalf
 TAX
 LDA PlayerGestureTiles,X
 STA $0201,Y
 LDX GlyphHalf
 LDA $0202,Y
 AND #$bf
 PHA
 LDA GlyphSwap
 BEQ GestureNoMirror
 PLA
 ORA #$40
 BNE GestureAttribute
GestureNoMirror:
 PLA
GestureAttribute:
 STA $0202,Y
GestureHalfNext:
 INX
 CPX #$02
 BCC GestureHalfLoop
 RTS
