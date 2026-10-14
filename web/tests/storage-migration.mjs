import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { NES, Controller } from 'jsnes'
import { applyBps } from '../src/lib/bps.ts'
import { loadCartridge } from '../src/lib/cartridge.ts'
import { SAVED_ROM_KEY, SAVE_SLOT_KEY_PREFIX, MIGRATION_DONE_KEY, migrateLegacyV7Storage } from '../src/lib/storage.ts'

const targetHash = 'c3baec6b9c555cd1b1170e38d9d88f64805c08629144c01f0e8dcf9c5916e315'
const legacyRom = 't8-zhenzhen-rom-v6', legacySave = 't8-zhenzhen-save-v6-1'
const source = new Uint8Array(readFileSync(new URL('../src/超级玛丽.nes', import.meta.url)))
const rom = applyBps(source, new Uint8Array(readFileSync(new URL('../src/assets/t8-zhenzhen-v7.bps', import.meta.url))))
class Store {
  constructor(entries = []) { this.values = new Map(entries); this.failedKey = null }
  getItem(key) { return this.values.get(key) ?? null }
  setItem(key, value) { if (key === this.failedKey) throw new Error('quota'); this.values.set(key, value) }
}

test('genuine v6 progress remains byte-identical when v7 saves and clears its own slot', () => {
  const old = JSON.stringify({ version: 1, romSha256: '05531d4215e2d77a55237b73e5937f35235a0405ee4dcd4d846019c9cac63216', savedAt: 42, state: { playerProgress: 'original v6' } })
  const store = new Store([[legacySave, old]])
  assert.equal(migrateLegacyV7Storage(store, targetHash, 1).status, 'complete')
  assert.equal(store.getItem(SAVE_SLOT_KEY_PREFIX + 1), null)
  store.setItem(SAVE_SLOT_KEY_PREFIX + 1, JSON.stringify({ version: 1, romSha256: targetHash, state: {} }))
  store.values.delete(SAVE_SLOT_KEY_PREFIX + 1)
  assert.equal(store.getItem(legacySave), old)
})

test('actual v7 saved machine wrongly stored under v6 moves exactly and restores the same game', () => {
  const original = new NES({ emulateSound: false }); loadCartridge(original, rom)
  for (let frame = 1; frame <= 340; frame++) {
    frame === 121 ? original.buttonDown(1, Controller.BUTTON_START) : original.buttonUp(1, Controller.BUTTON_START)
    frame === 300 ? original.buttonDown(1, Controller.BUTTON_SELECT) : original.buttonUp(1, Controller.BUTTON_SELECT)
    frame === 320 ? original.buttonDown(2, Controller.BUTTON_SELECT) : original.buttonUp(2, Controller.BUTTON_SELECT)
    original.frame()
  }
  assert.equal(original.cpu.mem[0x7e8c], 1)
  const state = JSON.parse(JSON.stringify(original.toJSON()))
  const rawSave = JSON.stringify({ version: 1, romSha256: targetHash, savedAt: 123, state })
  const rawRom = JSON.stringify({ name: 'T8', sha256: targetHash, bytes: Array.from(rom) })
  const store = new Store([[legacySave, rawSave], [legacyRom, rawRom]])
  const result = migrateLegacyV7Storage(store, targetHash, 1)
  assert.equal(result.status, 'complete')
  assert.equal(result.entries.filter(entry => entry.status === 'copied').length, 2)
  assert.equal(store.getItem(SAVE_SLOT_KEY_PREFIX + 1), rawSave)
  assert.equal(store.getItem(SAVED_ROM_KEY), rawRom)
  assert.equal(store.getItem(legacySave), rawSave)
  assert.equal(store.getItem(legacyRom), rawRom)
  const restored = new NES({ emulateSound: false })
  loadCartridge(restored, rom, JSON.parse(store.getItem(SAVE_SLOT_KEY_PREFIX + 1)).state)
  assert.deepEqual(restored.cpu.mem, original.cpu.mem)
  original.frame(); restored.frame()
  assert.deepEqual(restored.cpu.mem, original.cpu.mem)
})

test('a pre-existing v7 destination is retained even if its contents are malformed', () => {
  const old = JSON.stringify({ version: 1, romSha256: targetHash, state: {} })
  const store = new Store([[legacySave, old], [SAVE_SLOT_KEY_PREFIX + 1, 'retain this existing value']])
  migrateLegacyV7Storage(store, targetHash, 1)
  assert.equal(store.getItem(SAVE_SLOT_KEY_PREFIX + 1), 'retain this existing value')
  assert.equal(store.getItem(legacySave), old)
})

test('invalid JSON, wrong schema version and a different ROM are retained without copying', () => {
  const entries = [[legacySave, '{bad'], ['t8-zhenzhen-save-v6-2', JSON.stringify({ version: 99, romSha256: targetHash, state: {} })], ['t8-zhenzhen-save-v6-3', JSON.stringify({ version: 1, romSha256: 'other', state: {} })]]
  const store = new Store(entries); migrateLegacyV7Storage(store, targetHash, 1)
  for (const [key, value] of entries) assert.equal(store.getItem(key), value)
  for (const slot of [1, 2, 3]) assert.equal(store.getItem(SAVE_SLOT_KEY_PREFIX + slot), null)
})

test('quota failure keeps the source, leaves migration retryable and then recovers', () => {
  const raw = JSON.stringify({ version: 1, romSha256: targetHash, state: {} })
  const store = new Store([[legacySave, raw]]); store.failedKey = SAVE_SLOT_KEY_PREFIX + 1
  assert.equal(migrateLegacyV7Storage(store, targetHash, 1).status, 'partial')
  assert.equal(store.getItem(legacySave), raw)
  assert.equal(store.getItem(MIGRATION_DONE_KEY), null)
  store.failedKey = null
  assert.equal(migrateLegacyV7Storage(store, targetHash, 1).status, 'complete')
  assert.equal(store.getItem(SAVE_SLOT_KEY_PREFIX + 1), raw)
})

test('deliberately cleared v7 data is not resurrected from an earlier misplaced copy', () => {
  const raw = JSON.stringify({ version: 1, romSha256: targetHash, state: {} })
  const store = new Store([[legacySave, raw]]); migrateLegacyV7Storage(store, targetHash, 1)
  store.values.delete(SAVE_SLOT_KEY_PREFIX + 1)
  assert.equal(migrateLegacyV7Storage(store, targetHash, 1).status, 'already_done')
  assert.equal(store.getItem(SAVE_SLOT_KEY_PREFIX + 1), null)
  assert.equal(store.getItem(legacySave), raw)
})

test('blocked storage yields an explicit unavailable result without writing', () => {
  let writes = 0
  const result = migrateLegacyV7Storage({ getItem() { throw new Error('blocked') }, setItem() { writes++ } }, targetHash, 1)
  assert.equal(result.status, 'unavailable')
  assert.equal(writes, 0)
})
