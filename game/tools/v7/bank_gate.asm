; Sole MMC1 PRG owner. All callbacks are inside the original NMI-disabled frame;
; restore bank0 before native817E reenables NMI. No PPUCTRL side effects.
AuxOp = $7e80
AuxHandled = $7e81
AuxNativePtr = $7e84
AuxLive = $7e86
AuxPrevExtra = $7e87
AuxPose = $7e88
AuxRawPad2 = $7edf

RawPartnerPadHook:
 PHP
 STA $06fc,X
 CPX #$01
 BNE RawPartnerPadDone
 STA AuxRawPad2
RawPartnerPadDone:
 PLP
 RTS

AuxCall:
 PHP
 PHA
 TXA
 PHA
 TYA
 PHA
 JSR SelectAuxBank
 JSR $8000
 JSR SelectNativeBank
 PLA
 TAY
 PLA
 TAX
 PLA
 PLP
 RTS

SelectAuxBank:
 LDA #$00
 STA $e000
 LDA #$01
 STA $e000
 LDA #$00
 STA $e000
 STA $e000
 STA $e000
 RTS
SelectNativeBank:
 LDA #$00
 STA $e000
 STA $e000
 STA $e000
 STA $e000
 STA $e000
 RTS

; Stack-owned register/flag preservation; native RTS returns to RAM.
AuxNativeCall:
 PHP
 PHA
 TXA
 PHA
 TYA
 PHA
 JSR SelectNativeBank
 PLA
 TAY
 PLA
 TAX
 PLA
 PLP
 JSR AuxNativeJump
 PHP
 PHA
 TXA
 PHA
 TYA
 PHA
 JSR SelectAuxBank
 PLA
 TAY
 PLA
 TAX
 PLA
 PLP
 RTS
AuxNativeJump:
 JMP (AuxNativePtr)

AuxInputHook:
 LDA AuxRawPad2
 AND #$f0
 ORA AuxPrevExtra
 ORA AuxLive
 BNE AuxInputWork
 RTS
AuxInputWork:
 LDA #$00
 STA AuxOp
 JMP AuxCall
AuxPreHook:
 LDA AuxLive
 BNE AuxPreWork
 RTS
AuxPreWork:
 LDA #$01
 STA AuxOp
 JMP AuxCall
AuxSteerHook:
 LDA AuxLive
 BNE AuxSteerWork
 JMP ChooseFollowVelocity
AuxSteerWork:
 LDA #$02
 STA AuxOp
 JSR AuxCall
 LDA AuxHandled
 BEQ AuxLegacySteer
 RTS
AuxLegacySteer:
 JMP ChooseFollowVelocity
AuxPhysicsHook:
 LDA AuxLive
 ORA AuxPlatformWatch
 ORA AuxPlatformOn
 BNE AuxPhysicsWork
 JMP NpcPhysics
AuxPhysicsWork:
 LDA #$03
 STA AuxOp
 JSR AuxCall
 LDA AuxHandled
 BEQ AuxLegacyPhysics
 RTS
AuxLegacyPhysics:
 JMP NpcPhysics
AuxPostHook:
 LDA AuxLive
 ORA AuxPlatformWatch
 ORA AuxPlatformOn
 BNE AuxPostWork
 RTS
AuxPostWork:
 LDA #$04
 STA AuxOp
 JMP AuxCall
AuxEnemyHook:
 LDA #$00
 STA AuxHandled
 LDA AuxLive
 BNE AuxEnemyWork
 RTS
AuxEnemyWork:
 LDA #$05
 STA AuxOp
 JMP AuxCall
CacheSpriteTemplate:
 LDA AuxChrPage
 BNE AuxCacheWork
 LDA AuxPose
 BNE AuxCacheWork
 LDA CacheValid
 BEQ AuxCacheWork
 LDA NpcPose
 CMP CachePose
 BNE AuxCacheWork
 LDA NpcDir
 CMP CacheDir
 BNE AuxCacheWork
 LDA RenderDir
 CMP CacheHeadDir
 BNE AuxCacheWork
 LDA RenderSize
 CMP CacheSize
 BNE AuxCacheWork
 RTS
AuxCacheWork:
 LDA #$06
 STA AuxOp
 JMP AuxCall
AuxTerrainHook:
 LDA AuxLive
 BNE AuxTerrainWork
 RTS
AuxTerrainWork:
 LDA #$07
 STA AuxOp
 JMP AuxCall
AuxPauseHook:
 LDA #$08
 STA AuxOp
 JMP AuxCall
