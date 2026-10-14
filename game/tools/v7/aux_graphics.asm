AuxCache:
 LDA AuxPose
 BEQ AuxCacheNormal
 CLC
 ADC #$01
 JSR AuxSelectChr
 LDA NpcPose
 STA AuxOldPose
 LDA AuxPose
 CLC
 ADC #$0a
 STA NpcPose
 JSR AuxOriginalCache
 LDA AuxOldPose
 STA NpcPose
 RTS
AuxCacheNormal:
 LDA #$00
 JSR AuxSelectChr
 JMP AuxOriginalCache
AuxSelectChr:
 CMP AuxChrPage
 BEQ AuxChrDone
 STA AuxChrPage
 STA $a000
 LSR A
 STA $a000
 LSR A
 STA $a000
 LSR A
 STA $a000
 LSR A
 STA $a000
AuxChrDone:
 RTS
