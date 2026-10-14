AuxPlatformWatch = $7ed9
AuxPlatformOn = $7eda
AuxPlatformWidth = $7edb
AuxGroundSurface = $7edc
AuxCarryStance = $7edd

WatchNativePlatforms:
 LDA #$00
 STA AuxPlatformWatch
 LDX #$04
WatchPlatformLoop:
 LDA $16,X
 CMP #$25
 BCC WatchPlatformNext
 CMP #$2d
 BCS WatchPlatformNext
 LDA $0f,X
 CMP #$01
 BNE WatchPlatformNext
 LDA #$01
 STA AuxPlatformWatch
 RTS
WatchPlatformNext:
 DEX
 BPL WatchPlatformLoop
 RTS

PlatformGroundContact:
 LDA AuxPlatformOn
 BEQ PlatformGroundNo
 LDA NpcYHigh
 CMP #$01
 BNE PlatformGroundNo
 LDX AuxPlatformSlot
 CPX #$05
 BCS PlatformGroundNo
 LDA $0f,X
 CMP #$01
 BNE PlatformGroundNo
 LDA $16,X
 CMP AuxPlatformId
 BNE PlatformGroundNo
 LDA $b6,X
 CMP #$01
 BNE PlatformGroundNo
 LDA NpcY
 CLC
 ADC #$20
 SEC
 SBC $cf,X
 CMP #$02
 BCS PlatformGroundNo
 LDA NpcX
 CLC
 ADC #$08
 STA ProbeX
 LDA NpcPage
 ADC #$00
 STA ProbePage
 LDA ProbeX
 SEC
 SBC $87,X
 STA ProbeX
 LDA ProbePage
 SBC $6e,X
 BNE PlatformGroundNo
 LDA ProbeX
 CMP AuxPlatformWidth
 BCS PlatformGroundNo
 LDA #$01
 RTS
PlatformGroundNo:
 LDA #$00
 RTS
