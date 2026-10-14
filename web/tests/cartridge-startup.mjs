import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs'
import { createHash } from 'node:crypto'
import { NES, Controller } from 'jsnes'
import { applyBps } from '../src/lib/bps.ts'
import { loadCartridge } from '../src/lib/cartridge.ts'

const source = new Uint8Array(readFileSync(new URL('../src/超级玛丽.nes', import.meta.url)))
const patch = new Uint8Array(readFileSync(new URL('../src/assets/t8-zhenzhen-v7.bps', import.meta.url)))
const rom = applyBps(source, patch)
const sha = (data) => createHash('sha256').update(data).digest('hex')
assert.equal(sha(source), '4473b008df230c7dc071a977c26b0b53426aeb9fff2042935f10e8c4c7457225')
assert.equal(sha(rom), 'c3baec6b9c555cd1b1170e38d9d88f64805c08629144c01f0e8dcf9c5916e315')

function create() { return new NES({ emulateSound: false }) }
function enterFirstLevel(nes) {
  for (let frame = 1; frame <= 310; frame++) {
    if (frame === 121) nes.buttonDown(1, Controller.BUTTON_START)
    if (frame === 123) nes.buttonUp(1, Controller.BUTTON_START)
    nes.frame()
  }
  const memory = nes.cpu.mem
  return { world: memory[0x75f], level: memory[0x75c], mode: memory[0xe], life: memory[0x75a] + 1 }
}

const observations = []
test('reproduces deployed default-RAM0-1 and fixes genuine cold1-1', () => {
  const before = create(); before.loadROM(rom)
  const faulty = enterFirstLevel(before)
  const after = create(); loadCartridge(after, rom)
  const corrected = enterFirstLevel(after)
  assert.equal(faulty.world, 255)
  assert.equal(faulty.level, 0)
  assert.deepEqual(corrected, { world: 0, level: 0, mode: 8, life: 30 })
  observations.push({ case: 'cold-boot', before: faulty, after: corrected })
})

test('restart returns to normal1-1 with30 actual lives', () => {
  const nes = create(); loadCartridge(nes, rom); enterFirstLevel(nes)
  nes.buttonDown(1, Controller.BUTTON_RIGHT)
  for (let i = 0; i < 35; i++) nes.frame()
  assert.ok(nes.cpu.mem[0x86] > 40)
  nes.buttonUp(1, Controller.BUTTON_RIGHT)
  loadCartridge(nes, rom)
  const restarted = enterFirstLevel(nes)
  assert.deepEqual(restarted, { world: 0, level: 0, mode: 8, life: 30 })
  observations.push({ case: 'restart', after: restarted })
})

test('saved state restores the exact work RAM and continues the same game', () => {
  const original = create(); loadCartridge(original, rom); enterFirstLevel(original)
  original.buttonDown(1, Controller.BUTTON_RIGHT)
  for (let i = 0; i < 28; i++) original.frame()
  original.buttonUp(1, Controller.BUTTON_RIGHT)
  const saved = JSON.parse(JSON.stringify(original.toJSON()))
  const restored = create(); loadCartridge(restored, rom, saved)
  assert.deepEqual(restored.cpu.mem.slice(0, 0x800), original.cpu.mem.slice(0, 0x800))
  original.frame(); restored.frame()
  assert.deepEqual(restored.cpu.mem.slice(0, 0x800), original.cpu.mem.slice(0, 0x800))
  observations.push({ case: 'saved-state', ram_exact: true, next_frame_exact: true })
})

test('zero initialization leaves cartridge ROM and extension RAM untouched', () => {
  const reference = create(); reference.loadROM(rom)
  const patched = create(); loadCartridge(patched, rom)
  assert.deepEqual(patched.cpu.mem.slice(0x6000), reference.cpu.mem.slice(0x6000))
  assert.ok(patched.cpu.mem.slice(0, 0x800).every(byte => byte === 0))
  observations.push({ case: 'memory-boundary', cleared_bytes: 2048, cartridge_bytes_unchanged: true })
})

test.after(() => {
  const output = new URL('./output/', import.meta.url)
  mkdirSync(output, { recursive: true })
  writeFileSync(new URL('startup-verification.json', output), JSON.stringify({
    producer: 'Actual pinned JSNES2.1.0 cartridge execution using the changed source loader',
    source_sha256: sha(source), target_sha256: sha(rom), observations,
  }, null, 2))
})
