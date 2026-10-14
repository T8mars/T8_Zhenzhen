AuxPlatformBefore:
 LDA AuxPlatformOn
 BEQ AuxPlatformBeforeDone
 LDA NpcVY
 BMI AuxPlatformDetach
 JSR AuxPlatformGroundContact
 BEQ AuxPlatformDetach
 LDA #$01
 STA NpcGround
AuxPlatformBeforeDone:
 RTS
AuxPlatformDetach:
 LDA #$00
 STA AuxPlatformOn
 STA NpcGround
 RTS

AuxPlatformAfter:
 LDA AuxPlatformOn
 BEQ AuxPlatformFind
 LDX AuxPlatformSlot
 LDA $0f,X
 CMP #$01
 BNE AuxPlatformDetach
 LDA $16,X
 CMP AuxPlatformId
 BNE AuxPlatformDetach
 LDA NpcVY
 BMI AuxPlatformDetach
 LDA $87,X
 SEC
 SBC AuxPlatformX
 STA DeltaX
 CLC
 ADC #$04
 CMP #$09
 BCS AuxPlatformDetach
 LDA $cf,X
 SEC
 SBC AuxPlatformY
 STA DeltaY
 CLC
 ADC #$04
 CMP #$09
 BCS AuxPlatformDetach
 LDA Stance
 STA AuxCarryStance
 LDA #$01
 STA Stance
 JSR AuxMoveHorizontal
 LDA AuxCarryStance
 STA Stance
 ; Move through the entire swept vertical interval with native terrain checks.
 ; Support movement is not a new landing or a recovery event.
 LDA #$01
 STA AuxCarryMotion
 JSR AuxMoveVertical
 LDA #$00
 STA AuxCarryMotion
 LDX AuxPlatformSlot
 JSR AuxStorePlatform
 JSR AuxPlatformGroundContact
 BEQ AuxPlatformDetach
 JMP AuxSavePlatforms
AuxPlatformFind:
 LDA NpcVY
 BMI AuxSavePlatforms
 LDA NpcYHigh
 CMP #$01
 BNE AuxSavePlatforms
 LDX #$04
AuxPlatformFindLoop:
 STX AuxIndex
 LDA $0f,X
 CMP #$01
 BNE AuxPlatformFindNext
 LDA $16,X
 CMP #$25
 BCC AuxPlatformFindNext
 CMP #$2d
 BCS AuxPlatformFindNext
 CMP AuxOldPlatId,X
 BNE AuxPlatformFindNext
 LDA $b6,X
 CMP #$01
 BNE AuxPlatformFindNext
 JSR AuxPlatformSetWidth
 LDA NpcX
 CLC
 ADC #$08
 STA AuxTemp
 LDA NpcPage
 ADC #$00
 STA AuxTempPage
 LDA AuxTemp
 SEC
 SBC $87,X
 STA AuxTemp
 LDA AuxTempPage
 SBC $6e,X
 BNE AuxPlatformFindNext
 LDA AuxTemp
 CMP AuxPlatformWidth
 BCS AuxPlatformFindNext
 LDA PrevNpcY
 CLC
 ADC #$20
 CMP AuxOldPlatY,X
 BCC AuxPlatformPreviousAbove
 BEQ AuxPlatformPreviousAbove
 BCS AuxPlatformFindNext
AuxPlatformPreviousAbove:
 LDA NpcY
 CLC
 ADC #$20
 CMP $cf,X
 BCC AuxPlatformFindNext
 SEC
 SBC $cf,X
 CMP #$08
 BCS AuxPlatformFindNext
 LDA $cf,X
 SEC
 SBC #$20
 STA NpcY
 LDA #$01
 STA NpcGround
 STA AuxPlatformOn
 STX AuxPlatformSlot
 LDA $16,X
 STA AuxPlatformId
 JSR AuxStorePlatform
 LDA #$00
 STA NpcVY
 STA NpcYFrac
 STA NpcJumpKind
 INC PlatformLandCount
 JMP AuxSavePlatforms
AuxPlatformFindNext:
 DEX
 BPL AuxPlatformFindLoop
AuxSavePlatforms:
 LDX #$04
AuxSavePlatformsLoop:
 LDA $87,X
 STA AuxOldPlatX,X
 LDA $6e,X
 STA AuxOldPlatPage,X
 LDA $cf,X
 STA AuxOldPlatY,X
 LDA $16,X
 STA AuxOldPlatId,X
 DEX
 BPL AuxSavePlatformsLoop
 RTS
AuxPlatformSetWidth:
 LDA #$30
 LDY $074e
 CPY #$03
 BEQ AuxPlatformNarrow
 LDY $06cc
 BNE AuxPlatformNarrow
 LDY $16,X
 CPY #$2b
 BCC AuxPlatformWidthStore
AuxPlatformNarrow:
 LDA #$20
AuxPlatformWidthStore:
 STA AuxPlatformWidth
 RTS
AuxStorePlatform:
 LDA $87,X
 STA AuxPlatformX
 LDA $6e,X
 STA AuxPlatformPage
 LDA $cf,X
 STA AuxPlatformY
 RTS
