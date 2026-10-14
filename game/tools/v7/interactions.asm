; The second controller is sampled at the same cartridge-owned input boundary.
; E is pad2 A and R is pad2 B. No emulator-only runtime patches.
ReadPartnerInput:
 LDA $06fd
 AND #$c0
 STA PartnerInput
 LDA PrevPartnerInput
 EOR #$ff
 AND PartnerInput
 STA NewPartnerInput
 LDA PartnerInput
 STA PrevPartnerInput
 RTS
