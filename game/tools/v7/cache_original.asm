AuxOriginalCache:
 LDA CacheValid
 BEQ RebuildTemplate
 LDA NpcPose
 CMP CachePose
 BNE RebuildTemplate
 LDA NpcDir
 CMP CacheDir
 BNE RebuildTemplate
 LDA RenderDir
 CMP CacheHeadDir
 BNE RebuildTemplate
 LDA RenderSize
 CMP CacheSize
 BNE RebuildTemplate
 RTS
RebuildTemplate:
 LDA NpcPose
 STA CachePose
 ASL A
 LDX RenderSize
 CLC
 ADC SizePointerOffsets,X
 TAY
 LDA $00
 STA SaveZp0
 LDA $01
 STA SaveZp1
 LDA TemplatePointers,Y
 STA $00
 LDA TemplatePointers+1,Y
 STA $01
 LDY #$00
 LDX #$00
BuildPackedTemplate:
 TYA
 LSR A
 ASL A
 ASL A
 ASL A
 SEC
 SBC #$01
 STA $6040,X
 LDA ($00),Y
 STA $6041,X
 LDA #$00
 CPY #$02
 BCC PackedPalette
 LDA RenderSize
 BNE PackedBody
 CPY #$04
 BCC PackedHead
PackedBody:
 LDA #$02
 BNE PackedPalette
PackedHead:
 LDA #$00
PackedPalette:
 STA $6042,X
 TYA
 AND #$01
 ASL A
 ASL A
 ASL A
 STA $6043,X
 LDA $6042,X
 BEQ PackedHeadFacing
 LDA NpcDir
 JMP PackedFacingReady
PackedHeadFacing:
 LDA RenderDir
PackedFacingReady:
 CMP #$02
 BNE PackedNext
 LDA $6042,X
 ORA #$40
 STA $6042,X
 LDA $6043,X
 EOR #$08
 STA $6043,X
PackedNext:
 INX
 INX
 INX
 INX
 INY
 CPY SpriteCount
 BCC BuildPackedTemplate
 LDA SaveZp0
 STA $00
 LDA SaveZp1
 STA $01
 LDA NpcDir
 STA CacheDir
 LDA RenderDir
 STA CacheHeadDir
 LDA RenderSize
 STA CacheSize
 LDA #$01
 STA CacheValid
 RTS
