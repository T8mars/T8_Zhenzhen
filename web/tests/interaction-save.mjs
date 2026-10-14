import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { NES, Controller } from 'jsnes'
import { applyBps } from '../src/lib/bps.ts'
import { loadCartridge } from '../src/lib/cartridge.ts'
const rom = applyBps(new Uint8Array(readFileSync(new URL('../src/超级玛丽.nes', import.meta.url))),
  new Uint8Array(readFileSync(new URL('../src/assets/t8-zhenzhen-v7.bps', import.meta.url))))
const names = ['natural-v7-manual-control-and-return', 'natural-v7-fan-descent-with-real-partner-5-7']
const buttons = { A: 0, B: 1, select: 2, start: 3, up: 4, down: 5, left: 6, right: 7 }
function set(nes, b) {
  for (const [name, value] of Object.entries(buttons)) b[name] ? nes.buttonDown(1, value) : nes.buttonUp(1, value)
  for (const [name, value] of Object.entries({ E: Controller.BUTTON_A, R: Controller.BUTTON_B, Q: Controller.BUTTON_SELECT, W: Controller.BUTTON_START }))
    b[name] ? nes.buttonDown(2, value) : nes.buttonUp(2, value)
}
for (const name of names) test('actual v7 interaction save survives restore: ' + name, () => {
  const record = JSON.parse(readFileSync(new URL('./fixtures/' + name + '.json', import.meta.url)))
  const frame = name.includes('manual') ? 375 : 370
  const original = new NES({ emulateSound: false }); loadCartridge(original, rom)
  for (let i = 0; i < frame; i++) { set(original, record.input_schedule[i]); original.frame() }
  assert.equal(original.cpu.mem[0x7e8c], name.includes('manual') ? 1 : 0)
  if (!name.includes('manual')) assert.equal(original.cpu.mem[0x7e89], 11)
  const saved = JSON.parse(JSON.stringify(original.toJSON()))
  const restored = new NES({ emulateSound: false }); loadCartridge(restored, rom, saved)
  assert.deepEqual(restored.cpu.mem, original.cpu.mem)
  assert.deepEqual(restored.mmap.toJSON(), original.mmap.toJSON())
  for (let i = frame; i < frame + 25; i++) {
    set(original, record.input_schedule[i]); set(restored, record.input_schedule[i]); original.frame(); restored.frame()
    assert.deepEqual(restored.cpu.mem, original.cpu.mem)
  }
})
