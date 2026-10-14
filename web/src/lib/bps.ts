// Browser port of the project's bounded BPS reader. ROM bytes never leave the page.
const CRC_TABLE = (() => {
  const table = new Uint32Array(256)
  for (let i = 0; i < 256; i += 1) {
    let value = i
    for (let bit = 0; bit < 8; bit += 1) {
      value = value & 1 ? 0xedb88320 ^ (value >>> 1) : value >>> 1
    }
    table[i] = value >>> 0
  }
  return table
})()

export function crc32(bytes: Uint8Array): number {
  let crc = 0xffffffff
  for (const byte of bytes) {
    crc = CRC_TABLE[(crc ^ byte) & 0xff] ^ (crc >>> 8)
  }
  return (crc ^ 0xffffffff) >>> 0
}

export async function sha256Hex(bytes: Uint8Array): Promise<string> {
  const copy = new Uint8Array(bytes.length)
  copy.set(bytes)
  const digest = await crypto.subtle.digest('SHA-256', copy.buffer)
  return Array.from(new Uint8Array(digest), (byte) =>
    byte.toString(16).padStart(2, '0'),
  ).join('')
}

function makeNumberReader(patch: Uint8Array, footer: number) {
  let cursor = 4

  return {
    get cursor() {
      return cursor
    },
    set cursor(value: number) {
      cursor = value
    },
    number(): number {
      let data = 0
      let shift = 1
      for (let i = 0; i < 10; i += 1) {
        if (cursor >= footer) throw new Error('补丁数据不完整')
        const value = patch[cursor]
        cursor += 1
        data += (value & 0x7f) * shift
        if (value & 0x80) return data
        shift <<= 7
        data += shift
      }
      throw new Error('补丁数据超出可读取范围')
    },
  }
}

export interface BpsInfo {
  sourceSize: number
  targetSize: number
  metadata: string
  sourceCrc: number
  targetCrc: number
}

export function readBpsInfo(patch: Uint8Array): BpsInfo {
  if (patch.length < 19 || patch[0] !== 0x42 || patch[1] !== 0x50 || patch[2] !== 0x53 || patch[3] !== 0x31) {
    throw new Error('这不是完整的 BPS 补丁文件')
  }

  const footer = patch.length - 12
  const sourceCrc = new DataView(patch.buffer, patch.byteOffset + footer, 4).getUint32(0, true)
  const targetCrc = new DataView(patch.buffer, patch.byteOffset + footer + 4, 4).getUint32(0, true)
  const reader = makeNumberReader(patch, footer)
  const sourceSize = reader.number()
  const targetSize = reader.number()
  const metadataSize = reader.number()
  if (metadataSize > footer - reader.cursor) throw new Error('补丁元数据损坏')
  const metadata = new TextDecoder().decode(patch.subarray(reader.cursor, reader.cursor + metadataSize))

  return { sourceSize, targetSize, metadata, sourceCrc, targetCrc }
}

export function applyBps(source: Uint8Array, patch: Uint8Array, maxOutputBytes = 64 * 1024 * 1024): Uint8Array {
  const footer = patch.length - 12
  const expectedSource = new DataView(patch.buffer, patch.byteOffset + footer, 4).getUint32(0, true)
  const expectedTarget = new DataView(patch.buffer, patch.byteOffset + footer + 4, 4).getUint32(0, true)
  const expectedPatch = new DataView(patch.buffer, patch.byteOffset + footer + 8, 4).getUint32(0, true)

  if (crc32(patch.subarray(0, footer + 8)) !== expectedPatch) {
    throw new Error('补丁校验失败，请重新导入补丁')
  }
  if (crc32(source) !== expectedSource) {
    throw new Error('原版游戏文件与补丁要求的版本不一致')
  }

  const reader = makeNumberReader(patch, footer)
  const sourceSize = reader.number()
  const targetSize = reader.number()
  const metadataSize = reader.number()
  if (sourceSize !== source.length) throw new Error('原版游戏文件大小不正确')
  if (targetSize > maxOutputBytes) throw new Error('补丁输出过大，已停止')
  reader.cursor += metadataSize

  const result = new Uint8Array(targetSize)
  let outputOffset = 0
  let sourceRelative = 0
  let targetRelative = 0

  const readRelative = () => {
    const value = reader.number()
    return (value & 1 ? -(value >> 1) : value >> 1)
  }

  while (reader.cursor < footer) {
    const action = reader.number()
    const mode = action & 3
    const length = (action >> 2) + 1
    const position = outputOffset

    if (position + length > targetSize) throw new Error('补丁写入超出目标大小')

    if (mode === 0) {
      if (position + length > source.length) throw new Error('补丁引用了不存在的原始数据')
      result.set(source.subarray(position, position + length), outputOffset)
      outputOffset += length
    } else if (mode === 1) {
      if (reader.cursor + length > footer) throw new Error('补丁字面数据不完整')
      result.set(patch.subarray(reader.cursor, reader.cursor + length), outputOffset)
      reader.cursor += length
      outputOffset += length
    } else if (mode === 2) {
      sourceRelative += readRelative()
      if (sourceRelative < 0 || sourceRelative > source.length - length) {
        throw new Error('补丁源数据偏移无效')
      }
      result.set(source.subarray(sourceRelative, sourceRelative + length), outputOffset)
      sourceRelative += length
      outputOffset += length
    } else {
      targetRelative += readRelative()
      for (let i = 0; i < length; i += 1) {
        if (targetRelative < 0 || targetRelative >= outputOffset) {
          throw new Error('补丁引用了尚未生成的数据')
        }
        result[outputOffset] = result[targetRelative]
        outputOffset += 1
        targetRelative += 1
      }
    }
  }

  if (outputOffset !== targetSize || crc32(result) !== expectedTarget) {
    throw new Error('生成的游戏文件未通过校验')
  }
  return result
}
