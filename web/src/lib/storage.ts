/** Versioned storage belongs here; original v6 entries remain available. */
export const SAVED_ROM_KEY = 't8-zhenzhen-rom-v7'
export const SAVE_SLOT_KEY_PREFIX = 't8-zhenzhen-save-v7-'
export const MIGRATION_DONE_KEY = 't8-zhenzhen-migration-v7'

type LocalStore = Pick<Storage, 'getItem' | 'setItem'>
type MigrationEntry = {
  from: string
  to: string
  status: 'copied' | 'missing' | 'different_rom' | 'destination_exists' |
    'invalid_data' | 'read_failed' | 'write_failed'
}
export type MigrationResult = {
  status: 'complete' | 'already_done' | 'partial' | 'unavailable'
  entries: MigrationEntry[]
}

function record(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
}

/** Copy only records identifying this v7 ROM that an earlier build wrote under
 * v6 names. Keep originals, preserve existing destinations and retry failures.
 */
export function migrateLegacyV7Storage(
  storage: LocalStore, targetHash: string, saveVersion: number,
): MigrationResult {
  try {
    if (storage.getItem(MIGRATION_DONE_KEY) === targetHash) {
      return { status: 'already_done', entries: [] }
    }
  } catch {
    return { status: 'unavailable', entries: [] }
  }
  const sources = [
    { from: 't8-zhenzhen-rom-v6', to: SAVED_ROM_KEY, kind: 'rom' },
    ...[1, 2, 3].map(slot => ({
      from: 't8-zhenzhen-save-v6-' + slot,
      to: SAVE_SLOT_KEY_PREFIX + slot, kind: 'save',
    })),
  ]
  const entries: MigrationEntry[] = []
  for (const source of sources) {
    const entry: MigrationEntry = { from: source.from, to: source.to, status: 'missing' }
    entries.push(entry)
    let raw: string | null
    try {
      if (storage.getItem(source.to) !== null) {
        entry.status = 'destination_exists'
        continue
      }
      raw = storage.getItem(source.from)
    } catch {
      entry.status = 'read_failed'
      continue
    }
    if (raw === null) continue
    let value: unknown
    try {
      value = JSON.parse(raw)
    } catch {
      entry.status = 'invalid_data'
      continue
    }
    if (!record(value)) { entry.status = 'invalid_data'; continue }
    const hash = source.kind === 'rom' ? value.sha256 : value.romSha256
    if (hash !== targetHash) { entry.status = 'different_rom'; continue }
    const valid = source.kind === 'rom' ? Array.isArray(value.bytes) :
      value.version === saveVersion && record(value.state)
    if (!valid) { entry.status = 'invalid_data'; continue }
    try {
      storage.setItem(source.to, raw)
      entry.status = 'copied'
    } catch {
      entry.status = 'write_failed'
    }
  }
  if (entries.some(entry => entry.status === 'read_failed' || entry.status === 'write_failed')) {
    return { status: 'partial', entries }
  }
  try {
    // Keep this marker when the player clears v7 data, so old copies do not
    // resurrect a game the player deliberately removed.
    storage.setItem(MIGRATION_DONE_KEY, targetHash)
    return { status: 'complete', entries }
  } catch {
    return { status: 'partial', entries }
  }
}
