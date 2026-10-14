import type { EmulatorData, NES } from 'jsnes'

/** Load from power-on or restore the caller's complete saved machine state. */
export function loadCartridge(nes: NES, rom: Uint8Array, savedState?: EmulatorData) {
  nes.loadROM(rom)
  if (savedState) {
    nes.fromJSON(savedState)
    return
  }

  // This selected Chinese ROM requires zero-filled2KiB work RAM at power-on.
  // JSNES2.1.0 exposes cpu at runtime but omits it from the public declaration.
  const cpu = (nes as NES & { cpu: { mem: Uint8Array } }).cpu
  if (!(cpu?.mem instanceof Uint8Array) || cpu.mem.length < 0x800) {
    throw new Error('模拟器工作内存初始化失败，请重新加载页面')
  }
  cpu.mem.fill(0, 0, 0x800)
}
