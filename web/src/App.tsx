import { useCallback, useEffect, useRef, useState } from 'react'
import { Controller, NES, type EmulatorData } from 'jsnes'
import patchUrl from './assets/t8-zhenzhen-v7.bps?url'
import localRomUrl from './超级玛丽.nes?url'
import { applyBps, readBpsInfo, sha256Hex } from './lib/bps'
import { NesAudio } from './lib/audio'
import { loadCartridge } from './lib/cartridge'
import { SAVED_ROM_KEY, SAVE_SLOT_KEY_PREFIX, migrateLegacyV7Storage } from './lib/storage'

const SCREEN_WIDTH = 256
const SCREEN_HEIGHT = 240
const FRAME_DURATION = 1000 / 60.0988
const EXPECTED_SOURCE_SHA256 = '4473b008df230c7dc071a977c26b0b53426aeb9fff2042935f10e8c4c7457225'
const EXPECTED_TARGET_SHA256 = 'c3baec6b9c555cd1b1170e38d9d88f64805c08629144c01f0e8dcf9c5916e315'
// Bundled with the app (hashed asset, same in preview and published builds).
const LOCAL_ROM_NAME = '超级玛丽.nes'
const SAVE_STATE_VERSION = 1
const SAVE_SLOTS = [1, 2, 3] as const

type SaveSlot = (typeof SAVE_SLOTS)[number]

interface SaveRecord {
  version: number
  romSha256: string
  savedAt: number
  state: EmulatorData
}

interface SlotSummary {
  slot: SaveSlot
  savedAt: number
}

const buttonValues = [
  Controller.BUTTON_A,
  Controller.BUTTON_B,
  Controller.BUTTON_SELECT,
  Controller.BUTTON_START,
  Controller.BUTTON_UP,
  Controller.BUTTON_DOWN,
  Controller.BUTTON_LEFT,
  Controller.BUTTON_RIGHT,
] as const

type ButtonName = (typeof buttonValues)[number]
type PlayerButton = { player: 1 | 2; button: ButtonName }
type LoadState = 'idle' | 'loading' | 'ready' | 'error'

const keyboardMap: Record<string, PlayerButton> = {
  ArrowUp: { player: 1, button: Controller.BUTTON_UP },
  ArrowDown: { player: 1, button: Controller.BUTTON_DOWN },
  ArrowLeft: { player: 1, button: Controller.BUTTON_LEFT },
  ArrowRight: { player: 1, button: Controller.BUTTON_RIGHT },
  KeyD: { player: 1, button: Controller.BUTTON_B },
  KeyZ: { player: 1, button: Controller.BUTTON_B },
  KeyJ: { player: 1, button: Controller.BUTTON_B },
  KeyF: { player: 1, button: Controller.BUTTON_A },
  KeyX: { player: 1, button: Controller.BUTTON_A },
  KeyK: { player: 1, button: Controller.BUTTON_A },
  KeyS: { player: 1, button: Controller.BUTTON_SELECT },
  ShiftLeft: { player: 1, button: Controller.BUTTON_SELECT },
  ShiftRight: { player: 1, button: Controller.BUTTON_SELECT },
  Enter: { player: 1, button: Controller.BUTTON_START },
  KeyE: { player: 2, button: Controller.BUTTON_A },
  KeyR: { player: 2, button: Controller.BUTTON_B },
  KeyQ: { player: 2, button: Controller.BUTTON_SELECT },
  KeyW: { player: 2, button: Controller.BUTTON_START },
}

const systemKeys = new Set(['KeyC', 'KeyL'])

const touchButtons: Array<{
  label: string
  sub?: string
  className?: string
  player: 1 | 2
  button: ButtonName
}> = [
  { label: '←', player: 1, button: Controller.BUTTON_LEFT, className: 'dpad-left' },
  { label: '→', player: 1, button: Controller.BUTTON_RIGHT, className: 'dpad-right' },
  { label: '↑', player: 1, button: Controller.BUTTON_UP, className: 'dpad-up' },
  { label: '↓', player: 1, button: Controller.BUTTON_DOWN, className: 'dpad-down' },
  { label: 'SEL', sub: '召唤/搭档', player: 1, button: Controller.BUTTON_SELECT, className: 'small-button' },
  { label: 'START', sub: '开始/暂停', player: 1, button: Controller.BUTTON_START, className: 'small-button' },
  { label: 'B', sub: '加速/火球', player: 1, button: Controller.BUTTON_B },
  { label: 'A', sub: '跳跃', player: 1, button: Controller.BUTTON_A },
  { label: 'E', sub: '搭档互动', player: 2, button: Controller.BUTTON_A },
  { label: 'R', sub: '挥扇/准备', player: 2, button: Controller.BUTTON_B },
  { label: 'Q', sub: '指挥/托举', player: 2, button: Controller.BUTTON_SELECT },
  { label: 'W', sub: '摆帅/缓降', player: 2, button: Controller.BUTTON_START },
]

function readFile(file: File): Promise<Uint8Array> {
  return file.arrayBuffer().then((buffer) => new Uint8Array(buffer))
}

function formatSaveTime(timestamp: number): string {
  return new Date(timestamp).toLocaleString('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  })
}

function readSavedSlots(): SlotSummary[] {
  try {
    migrateLegacyV7Storage(localStorage, EXPECTED_TARGET_SHA256, SAVE_STATE_VERSION)
  } catch {
    // Browsers that block local storage can still start the game.
  }
  const summaries: SlotSummary[] = []
  for (const slot of SAVE_SLOTS) {
    try {
      const raw = localStorage.getItem(SAVE_SLOT_KEY_PREFIX + slot)
      if (!raw) continue
      const parsed = JSON.parse(raw) as Partial<SaveRecord>
      if (
        parsed.version === SAVE_STATE_VERSION &&
        parsed.romSha256 === EXPECTED_TARGET_SHA256 &&
        typeof parsed.savedAt === 'number' &&
        parsed.state &&
        typeof parsed.state === 'object'
      ) {
        summaries.push({ slot, savedAt: parsed.savedAt })
      }
    } catch {
      // Corrupt slot entries are ignored until the player overwrites them.
    }
  }
  return summaries
}

function App() {
  const canvasRef = useRef<HTMLCanvasElement | null>(null)
  const nesRef = useRef<NES | null>(null)
  const rafRef = useRef<number | null>(null)
  const previousTimeRef = useRef(0)
  const accumulatedTimeRef = useRef(0)
  const runningRef = useRef(false)
  const frameCallbackRef = useRef<(time: number) => void>(() => undefined)
  const activeKeyboardRef = useRef(new Set<string>())
  const activeInputsRef = useRef(new Set<string>())
  const inputSourcesRef = useRef(new Map<string, Set<string>>())
  const touchMappingRef = useRef(new Map<string, PlayerButton>())
  const noticeTimerRef = useRef<number | null>(null)
  const saveSlotRef = useRef<(slot: SaveSlot) => void>(() => undefined)
  const loadSlotRef = useRef<(slot: SaveSlot) => void>(() => undefined)
  const imageDataRef = useRef<ImageData | null>(null)
  const romRef = useRef<Uint8Array | null>(null)
  const audioRef = useRef<NesAudio | null>(null)
  const audioEnabledRef = useRef(false)
  const audioSampleRateRef = useRef(48000)

  const [loadState, setLoadState] = useState<LoadState>('idle')
  const [error, setError] = useState('')
  const [running, setRunning] = useState(false)
  const [audioOn, setAudioOn] = useState(false)
  const [sourceName, setSourceName] = useState('')
  const [sourceValid, setSourceValid] = useState(false)
  const [isDragOver, setIsDragOver] = useState(false)
  const [activeTouch, setActiveTouch] = useState<Set<string>>(new Set())
  const [notice, setNotice] = useState('')
  const [saveSlots, setSaveSlots] = useState<SlotSummary[]>(readSavedSlots)

  const flashNotice = useCallback((message: string) => {
    if (noticeTimerRef.current !== null) window.clearTimeout(noticeTimerRef.current)
    setNotice(message)
    noticeTimerRef.current = window.setTimeout(() => {
      setNotice('')
      noticeTimerRef.current = null
    }, 2200)
  }, [])

  const setRunningState = useCallback((value: boolean) => {
    runningRef.current = value
    setRunning(value)
  }, [])

  const drawFrame = useCallback((frame: Uint32Array) => {
    const canvas = canvasRef.current
    if (!canvas) return
    const context = canvas.getContext('2d', { alpha: false })
    if (!context) return
    if (!imageDataRef.current) {
      imageDataRef.current = context.createImageData(SCREEN_WIDTH, SCREEN_HEIGHT)
    }
    const imageData = imageDataRef.current
    const pixels = new Uint32Array(imageData.data.buffer)
    pixels.set(frame)
    for (let i = 0; i < pixels.length; i += 1) pixels[i] |= 0xff000000
    context.putImageData(imageData, 0, 0)
  }, [])

  const clearCanvas = useCallback(() => {
    const canvas = canvasRef.current
    canvas?.getContext('2d', { alpha: false })?.clearRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
  }, [])

  const stopLoop = useCallback(() => {
    if (rafRef.current !== null) cancelAnimationFrame(rafRef.current)
    rafRef.current = null
    accumulatedTimeRef.current = 0
    previousTimeRef.current = 0
    setRunningState(false)
  }, [setRunningState])

  const frameLoop = useCallback(
    (time: number) => {
      if (!runningRef.current || !nesRef.current) return
      if (!previousTimeRef.current) previousTimeRef.current = time
      let elapsed = time - previousTimeRef.current
      previousTimeRef.current = time
      if (elapsed > 120) elapsed = 1000 / 60
      accumulatedTimeRef.current += elapsed

      let safeFrames = 0
      while (accumulatedTimeRef.current >= FRAME_DURATION && safeFrames < 4) {
        try {
          nesRef.current.frame()
        } catch (frameError) {
          stopLoop()
          setLoadState('error')
          setError(frameError instanceof Error ? frameError.message : '模拟器运行出错')
          return
        }
        accumulatedTimeRef.current -= FRAME_DURATION
        safeFrames += 1
      }
      rafRef.current = requestAnimationFrame((time) => frameCallbackRef.current(time))
    },
    [stopLoop],
  )

  const startLoop = useCallback(() => {
    if (!nesRef.current || runningRef.current) return
    previousTimeRef.current = 0
    accumulatedTimeRef.current = 0
    setRunningState(true)
    rafRef.current = requestAnimationFrame((time) => frameCallbackRef.current(time))
  }, [setRunningState])

  useEffect(() => {
    frameCallbackRef.current = frameLoop
  }, [frameLoop])

  const releaseControllerButtons = useCallback(() => {
    const nes = nesRef.current
    if (!nes) return
    for (const player of [1, 2] as const) {
      for (const button of buttonValues) nes.buttonUp(player, button)
    }
  }, [])

  const resetInputSources = useCallback(() => {
    activeInputsRef.current.clear()
    inputSourcesRef.current.clear()
  }, [])

  const releaseAllButtons = useCallback(() => {
    activeKeyboardRef.current.clear()
    touchMappingRef.current.clear()
    setActiveTouch(new Set())
    resetInputSources()
    releaseControllerButtons()
  }, [releaseControllerButtons, resetInputSources])

  const pressInput = (inputKey: string, mapped: PlayerButton) => {
    if (activeInputsRef.current.has(inputKey)) return
    const buttonKey = `${mapped.player}-${mapped.button}`
    const sources = inputSourcesRef.current.get(buttonKey) ?? new Set<string>()
    const wasPressed = sources.size > 0
    sources.add(inputKey)
    inputSourcesRef.current.set(buttonKey, sources)
    activeInputsRef.current.add(inputKey)
    if (!wasPressed) nesRef.current?.buttonDown(mapped.player, mapped.button)
  }

  const releaseInput = (inputKey: string, mapped: PlayerButton) => {
    if (!activeInputsRef.current.delete(inputKey)) return
    const buttonKey = `${mapped.player}-${mapped.button}`
    const sources = inputSourcesRef.current.get(buttonKey)
    if (!sources) return
    sources.delete(inputKey)
    if (sources.size === 0) {
      inputSourcesRef.current.delete(buttonKey)
      nesRef.current?.buttonUp(mapped.player, mapped.button)
    }
  }

  const restoreHeldInputs = useCallback(() => {
    resetInputSources()
    for (const key of activeKeyboardRef.current) {
      const mapped = keyboardMap[key]
      if (mapped) pressInput(key, mapped)
    }
    for (const [key, mapped] of touchMappingRef.current) {
      pressInput(`touch:${key}`, mapped)
    }
  }, [resetInputSources])

  useEffect(() => {
    return () => {
      if (rafRef.current !== null) cancelAnimationFrame(rafRef.current)
      if (noticeTimerRef.current !== null) window.clearTimeout(noticeTimerRef.current)
      releaseAllButtons()
    }
  }, [releaseAllButtons])

  useEffect(() => {
    const down = (event: KeyboardEvent) => {
      if (systemKeys.has(event.code)) {
        event.preventDefault()
        if (event.repeat || activeKeyboardRef.current.has(event.code)) return
        activeKeyboardRef.current.add(event.code)
        if (event.code === 'KeyC') saveSlotRef.current(1)
        if (event.code === 'KeyL') loadSlotRef.current(1)
        return
      }
      const mapped = keyboardMap[event.code]
      if (!mapped) return
      event.preventDefault()
      if (event.repeat || activeKeyboardRef.current.has(event.code)) return
      activeKeyboardRef.current.add(event.code)
      pressInput(event.code, mapped)
    }
    const up = (event: KeyboardEvent) => {
      if (systemKeys.has(event.code)) {
        event.preventDefault()
        activeKeyboardRef.current.delete(event.code)
        return
      }
      const mapped = keyboardMap[event.code]
      if (!mapped) return
      event.preventDefault()
      activeKeyboardRef.current.delete(event.code)
      releaseInput(event.code, mapped)
    }
    const blur = () => releaseAllButtons()
    window.addEventListener('keydown', down)
    window.addEventListener('keyup', up)
    window.addEventListener('blur', blur)
    return () => {
      window.removeEventListener('keydown', down)
      window.removeEventListener('keyup', up)
      window.removeEventListener('blur', blur)
    }
  }, [releaseAllButtons])

  const createNes = useCallback(() => {
    return new NES({
      onFrame: drawFrame,
      emulateSound: true,
      sampleRate: audioSampleRateRef.current,
      onAudioSample: (left, right) => {
        if (audioEnabledRef.current) audioRef.current?.enqueue(left, right)
      },
      onStatusUpdate: () => undefined,
    })
  }, [drawFrame])

  const refreshSaveSlots = useCallback(() => setSaveSlots(readSavedSlots()), [])

  const startRom = useCallback((rom: Uint8Array, name: string) => {
    stopLoop()
    const nes = createNes()
    loadCartridge(nes, rom)
    nesRef.current = nes
    romRef.current = rom
    setSourceName(name)
    setSourceValid(true)
    setError('')
    setNotice('')
    setLoadState('ready')
    try {
      localStorage.setItem(
        SAVED_ROM_KEY,
        JSON.stringify({ name, bytes: Array.from(rom), sha256: EXPECTED_TARGET_SHA256 }),
      )
    } catch {
      // Private-mode or quota failures should not block playing in the current tab.
    }
    requestAnimationFrame(() => {
      try {
        nes.frame()
        startLoop()
      } catch (caught) {
        setLoadState('error')
        setError(caught instanceof Error ? caught.message : '游戏启动失败')
      }
    })
  }, [createNes, startLoop, stopLoop])

  // The v7 BPS targets the original ROM directly (same source CRC as the earlier base patch).
  const buildPatchedRom = useCallback(async (source: Uint8Array) => {
    const patchResponse = await fetch(patchUrl)
    if (!patchResponse.ok) throw new Error('游戏补丁加载失败')
    const patch = new Uint8Array(await patchResponse.arrayBuffer())
    const patchInfo = readBpsInfo(patch)
    const sourceHash = await sha256Hex(source)
    if (sourceHash.toLowerCase() !== EXPECTED_SOURCE_SHA256) {
      throw new Error('VERSION_MISMATCH')
    }
    const rom = applyBps(source, patch)
    const targetHash = await sha256Hex(rom)
    if (targetHash.toLowerCase() !== EXPECTED_TARGET_SHA256 || rom.length !== patchInfo.targetSize) {
      throw new Error('生成结果校验未通过')
    }
    return rom
  }, [])

  const loadRomFile = useCallback(
    async (file: File) => {
      setLoadState('loading')
      setError('')
      setNotice('')
      stopLoop()
      try {
        const source = await readFile(file)
        const rom = await buildPatchedRom(source)
        startRom(rom, file.name)
      } catch (caught) {
        romRef.current = null
        setSourceValid(false)
        setSourceName(file.name)
        setLoadState('error')
        setError(
          caught instanceof Error && caught.message === 'VERSION_MISMATCH'
            ? '请选择补丁要求的那份原版游戏文件；版本不一致时不会开始。'
            : caught instanceof Error
              ? caught.message
              : '游戏载入失败',
        )
      }
    },
    [buildPatchedRom, startRom, stopLoop],
  )

  // Auto-import: the dev environment serves the user's locally provided ROM.
  // It never ships in a production build, where the manual picker remains the fallback.
  const autoLoadTriedRef = useRef(false)
  const loadLocalRom = useCallback(async () => {
    setLoadState('loading')
    setError('')
    stopLoop()
    try {
      const response = await fetch(localRomUrl, { cache: 'no-store' })
      if (!response.ok) throw new Error('local rom unavailable')
      const source = new Uint8Array(await response.arrayBuffer())
      const rom = await buildPatchedRom(source)
      startRom(rom, LOCAL_ROM_NAME)
      return true
    } catch {
      setLoadState('idle')
      return false
    }
  }, [buildPatchedRom, startRom, stopLoop])

  useEffect(() => {
    if (autoLoadTriedRef.current) return
    autoLoadTriedRef.current = true
    let cancelled = false

    const restoreSaved = () => {
      try {
        const saved = localStorage.getItem(SAVED_ROM_KEY)
        if (!saved) return false
        const parsed: { name?: string; bytes?: number[]; sha256?: string } = JSON.parse(saved)
        if (parsed.sha256 !== EXPECTED_TARGET_SHA256 || !Array.isArray(parsed.bytes)) return false
        const rom = new Uint8Array(parsed.bytes)
        void sha256Hex(rom)
          .then((hash) => {
            if (!cancelled && hash.toLowerCase() === EXPECTED_TARGET_SHA256) {
              startRom(rom, parsed.name || '上次载入的游戏')
            } else if (!cancelled) {
              setLoadState('idle')
            }
          })
          .catch(() => {
            if (!cancelled) setLoadState('idle')
          })
        return true
      } catch {
        // A corrupted saved record simply falls back to the upload screen.
        return false
      }
    }

    void loadLocalRom().then((loaded) => {
      if (!cancelled && !loaded) restoreSaved()
    })

    return () => {
      cancelled = true
    }
  }, [loadLocalRom, startRom])

  const onInputChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0]
    if (file) void loadRomFile(file)
    event.target.value = ''
  }

  const onDrop = (event: React.DragEvent<HTMLLabelElement>) => {
    event.preventDefault()
    setIsDragOver(false)
    const file = event.dataTransfer.files?.[0]
    if (file) void loadRomFile(file)
  }

  const fileInputRef = useRef<HTMLInputElement>(null)

  // Pasting a copied .nes file (file manager → Ctrl+V) is the fastest path on desktop.
  useEffect(() => {
    if (loadState === 'ready' || loadState === 'loading') return
    const onPaste = (event: ClipboardEvent) => {
      const file = Array.from(event.clipboardData?.files ?? []).find((item) =>
        item.name.toLowerCase().endsWith('.nes'),
      )
      if (file) {
        event.preventDefault()
        void loadRomFile(file)
      }
    }
    window.addEventListener('paste', onPaste)
    return () => window.removeEventListener('paste', onPaste)
  }, [loadState, loadRomFile])

  const togglePause = () => {
    if (!nesRef.current) return
    if (runningRef.current) stopLoop()
    else startLoop()
  }

  const forgetSavedGame = () => {
    stopLoop()
    releaseAllButtons()
    nesRef.current = null
    romRef.current = null
    try {
      localStorage.removeItem(SAVED_ROM_KEY)
      for (const slot of SAVE_SLOTS) localStorage.removeItem(SAVE_SLOT_KEY_PREFIX + slot)
    } catch {
      // Ignore storage failures; the current session is cleared regardless.
    }
    setSaveSlots([])
    setSourceName('')
    setSourceValid(false)
    setAudioOn(false)
    audioEnabledRef.current = false
    audioRef.current?.stop()
    setLoadState('idle')
    setError('')
    setNotice('')
    if (noticeTimerRef.current !== null) window.clearTimeout(noticeTimerRef.current)
    noticeTimerRef.current = null
    clearCanvas()
  }

  const resetGame = () => {
    const nes = nesRef.current
    const rom = romRef.current
    if (!nes || !rom) return
    stopLoop()
    releaseAllButtons()
    try {
      loadCartridge(nes, rom)
      startLoop()
    } catch (caught) {
      setLoadState('error')
      setError(caught instanceof Error ? caught.message : '重置失败')
    }
  }

  const saveToSlot = useCallback((slot: SaveSlot) => {
    const nes = nesRef.current
    if (!nes || !romRef.current) return
    const wasRunning = runningRef.current
    let state: EmulatorData
    stopLoop()
    try {
      releaseControllerButtons()
      resetInputSources()
      state = nes.toJSON()
      restoreHeldInputs()
    } catch (caught) {
      flashNotice(caught instanceof Error ? caught.message : '存档失败')
      if (wasRunning) startLoop()
      return
    }

    try {
      const record: SaveRecord = {
        version: SAVE_STATE_VERSION,
        romSha256: EXPECTED_TARGET_SHA256,
        savedAt: Date.now(),
        state,
      }
      localStorage.setItem(SAVE_SLOT_KEY_PREFIX + slot, JSON.stringify(record))
      refreshSaveSlots()
      flashNotice(`已保存到存档位 ${slot}`)
    } catch (caught) {
      flashNotice(caught instanceof Error ? caught.message : '存档失败，本机存储空间可能不足')
    } finally {
      if (wasRunning) startLoop()
    }
  }, [flashNotice, refreshSaveSlots, releaseControllerButtons, resetInputSources, restoreHeldInputs, startLoop, stopLoop])

  const loadFromSlot = useCallback((slot: SaveSlot) => {
    const nes = nesRef.current
    const rom = romRef.current
    if (!nes || !rom) return
    try {
      const raw = localStorage.getItem(SAVE_SLOT_KEY_PREFIX + slot)
      if (!raw) {
        flashNotice(`存档位 ${slot} 还是空的`)
        return
      }
      const parsed = JSON.parse(raw) as Partial<SaveRecord>
      if (
        parsed.version !== SAVE_STATE_VERSION ||
        parsed.romSha256 !== EXPECTED_TARGET_SHA256 ||
        typeof parsed.savedAt !== 'number' ||
        !parsed.state ||
        typeof parsed.state !== 'object'
      ) {
        throw new Error('这份存档与当前游戏版本不一致')
      }

      const restored = createNes()
      loadCartridge(restored, rom, parsed.state as EmulatorData)

      const wasRunning = runningRef.current
      stopLoop()
      releaseControllerButtons()
      resetInputSources()
      restored.frame()
      nesRef.current = restored
      restoreHeldInputs()

      if (wasRunning) startLoop()
      flashNotice(`已读取存档位 ${slot}`)
    } catch (caught) {
      flashNotice(caught instanceof Error ? caught.message : '读档失败')
    }
  }, [createNes, flashNotice, releaseControllerButtons, resetInputSources, restoreHeldInputs, startLoop, stopLoop])

  useEffect(() => {
    saveSlotRef.current = saveToSlot
    loadSlotRef.current = loadFromSlot
  }, [loadFromSlot, saveToSlot])

  const toggleAudio = async () => {
    const next = !audioEnabledRef.current
    try {
      if (next) {
        if (!audioRef.current) audioRef.current = new NesAudio()
        const sampleRate = await audioRef.current.start()
        if (sampleRate !== audioSampleRateRef.current) {
          audioSampleRateRef.current = sampleRate
          const rom = romRef.current
          if (rom) {
            const wasRunning = runningRef.current
            stopLoop()
            const nes = createNes()
            loadCartridge(nes, rom)
            nesRef.current = nes
            if (wasRunning) startLoop()
          }
        }
      } else {
        audioRef.current?.stop()
      }
      audioEnabledRef.current = next
      setAudioOn(next)
    } catch (caught) {
      audioEnabledRef.current = false
      setAudioOn(false)
      setNotice(caught instanceof Error ? caught.message : '声音开启失败')
    }
  }

  const pressTouch = (key: string, player: 1 | 2, button: ButtonName) => {
    touchMappingRef.current.set(key, { player, button })
    pressInput(`touch:${key}`, { player, button })
    setActiveTouch((previous) => new Set(previous).add(key))
  }

  const releaseTouch = (key: string, player: 1 | 2, button: ButtonName) => {
    touchMappingRef.current.delete(key)
    releaseInput(`touch:${key}`, { player, button })
    setActiveTouch((previous) => {
      const next = new Set(previous)
      next.delete(key)
      return next
    })
  }

  const touchHandlers = (key: string, player: 1 | 2, button: ButtonName) => ({
    onPointerDown: (event: React.PointerEvent<HTMLButtonElement>) => {
      event.preventDefault()
      event.currentTarget.setPointerCapture(event.pointerId)
      pressTouch(key, player, button)
    },
    onPointerUp: (event: React.PointerEvent<HTMLButtonElement>) => {
      event.preventDefault()
      releaseTouch(key, player, button)
    },
    onPointerCancel: () => releaseTouch(key, player, button),
    onLostPointerCapture: () => releaseTouch(key, player, button),
    onContextMenu: (event: React.MouseEvent) => event.preventDefault(),
  })

  return (
    <main className="game-page">
      <section className="shell">
        <header className="topbar">
          <div>
            <p className="eyebrow">FAMICOM CO-OP · LOCAL PLAY</p>
            <h1>T8与贞贞的马里奥大冒险</h1>
          </div>
          <div className={`status-pill ${loadState}`}>
            <span />
            {loadState === 'ready' ? (running ? '游戏运行中' : '已暂停') : loadState === 'loading' ? '正在生成' : sourceValid ? '就绪' : '等待游戏文件'}
          </div>
        </header>

        <div className="content-grid">
          <section className="cabinet-wrap">
            <div className="cabinet">
              <canvas
                ref={canvasRef}
                width={SCREEN_WIDTH}
                height={SCREEN_HEIGHT}
                className="game-canvas"
                aria-label="游戏画面"
              />
              {loadState !== 'ready' && (
                <div className="screen-overlay">
                  <div className="crt-lines" />
                  {loadState === 'loading' ? (
                    <div className="loading-box">
                      <div className="loading-disk" />
                      <p>正在自动读取游戏并套用改版</p>
                    </div>
                  ) : (
                    <label
                      className={`drop-zone ${isDragOver ? 'is-drag-over' : ''}`}
                      onDragOver={(event) => { event.preventDefault(); setIsDragOver(true) }}
                      onDragLeave={() => setIsDragOver(false)}
                      onDrop={onDrop}
                    >
                      <div className={`cartridge ${isDragOver ? 'active' : ''}`}>
                        <span>GAME</span>
                        <strong>INSERT ROM</strong>
                      </div>
                      <h2>{error ? '载入未成功' : '点一下这里，选择原版游戏即可开始'}</h2>
                      <p>
                        {error || '支持点击选择、把 .nes 文件拖进来，或在文件管理器里复制后按 Ctrl+V 粘贴；页面会自动套用 T8 与贞贞改版补丁，只在本机浏览器中读取，不会上传。'}
                      </p>
                      <span className="upload-button">选择 .nes 文件</span>
                      <input ref={fileInputRef} type="file" accept=".nes,application/octet-stream" onChange={onInputChange} hidden />
                      {sourceName && <small>当前文件：{sourceName}</small>}
                      <small>成功后会保存在这台设备的浏览器里，下次打开直接继续。</small>
                    </label>
                  )}
                </div>
              )}
            </div>

            <div className="screen-actions">
              <button onClick={togglePause} disabled={loadState !== 'ready'}>
                {running ? '暂停' : '继续'}
              </button>
              <button onClick={resetGame} disabled={loadState !== 'ready'}>重新开始</button>
              <button onClick={toggleAudio} disabled={loadState !== 'ready'} className={audioOn ? 'selected' : ''}>
                声音：{audioOn ? '开' : '关'}
              </button>
              <label className="action-file">
                换游戏文件
                <input type="file" accept=".nes,application/octet-stream" onChange={onInputChange} hidden />
              </label>
              <button onClick={forgetSavedGame} disabled={loadState !== 'ready'} className="muted-button">清除本机记录</button>
            </div>
            {notice && <p className="notice" role="status">{notice}</p>}

            <div className="save-panel" aria-label="存档位">
              <div className="save-heading">
                <strong>游戏存档</strong>
                <span>3 个本机存档位 · C 快速存档 · L 快速读档</span>
              </div>
              <div className="save-slots">
                {SAVE_SLOTS.map((slot) => {
                  const summary = saveSlots.find((item) => item.slot === slot)
                  return (
                    <article className={`save-slot ${summary ? 'filled' : ''}`} key={slot}>
                      <div>
                        <strong>存档位 {slot}</strong>
                        <span>{summary ? formatSaveTime(summary.savedAt) : '空存档位'}</span>
                      </div>
                      <div className="slot-actions">
                        <button onClick={() => saveToSlot(slot)} disabled={loadState !== 'ready'}>保存</button>
                        <button onClick={() => loadFromSlot(slot)} disabled={loadState !== 'ready' || !summary}>读取</button>
                      </div>
                    </article>
                  )
                })}
              </div>
            </div>
          </section>

          <aside className="guide-panel">
            <div>
              <p className="eyebrow">CONTROLS</p>
              <h2>键盘操作</h2>
              <ul className="control-list">
                <li><kbd>Enter</kbd><span>开始 / 暂停</span></li>
                <li><kbd>C</kbd> / <kbd>L</kbd><span>快速保存 / 读取存档位 1</span></li>
                <li><kbd>← ↑ → ↓</kbd><span>T8 移动、蹲下、进水管</span></li>
                <li><kbd>F</kbd> / <kbd>X</kbd> / <kbd>K</kbd><span>跳跃（A）</span></li>
                <li><kbd>Z</kbd> / <kbd>J</kbd> / <kbd>D</kbd><span>加速与火球（B）</span></li>
                <li><kbd>S</kbd> 配合方向<span>召唤、前跳、顶砖或跟随</span></li>
                <li><kbd>E</kbd> 配合方向<span>撑台、反踢、拍背、碰拳</span></li>
                <li><kbd>R</kbd> / <kbd>↓R</kbd><span>挥扇推近处怪 / 抱膝准备；背后方向＋E 推球</span></li>
                <li><kbd>↑R</kbd> / <kbd>←R →R</kbd><span>接火球变线 / 空中侧手换线</span></li>
                <li><kbd>Q</kbd><span>切换短指挥：方向控制贞贞，F让她跳；再Q返回T8</span></li>
                <li><kbd>↓Q</kbd> / <kbd>E</kbd><span>近身借扇 / 露头，再E取回</span></li>
                <li><kbd>↑Q</kbd><span>坑边伸手；贴近下降时再按抓住，保持Q＋↑爬回</span></li>
                <li><kbd>←Q →Q</kbd><span>近身托举，保持Q换向，松Q短抛；F/D/S放下</span></li>
                <li><kbd>W</kbd> / <kbd>↓W</kbd><span>真实背靠背摆帅 / 地面伸手，近身再↓W牵手刹车</span></li>
                <li><kbd>↑W</kbd><span>下降时举扇缓降；她落背一起落，S让她离背</span></li>
                <li><kbd>↓S</kbd> / <kbd>S</kbd><span>原生移动台上留座 / 从实际脚点跳离平台</span></li>
              </ul>
            </div>
            <div className="tip-card">
              <strong>开始提示</strong>
              <p>先按 Enter 进入游戏。方向键先按住，再按 E、R、Q 或 W 触发搭档动作。短指挥时F给贞贞，D/S/E/R可退出指挥；普通状态F仍给T8。手机可用下方虚拟按键。</p>
            </div>
          </aside>
        </div>

        <section className="touch-pad" aria-label="触屏控制">
          <div className="dpad">
            {touchButtons.slice(0, 4).map((item) => (
              <button
                key={item.label}
                {...touchHandlers(item.label, item.player, item.button)}
                className={`${item.className ?? ''} ${activeTouch.has(item.label) ? 'pressed' : ''}`}
                aria-label={item.label}
              >
                {item.label}
              </button>
            ))}
          </div>
          <div className="system-buttons">
            {touchButtons.slice(4, 6).map((item) => {
              const key = `${item.player}-${item.button}`
              return (
                <button
                  key={key}
                  {...touchHandlers(key, item.player, item.button)}
                  className={activeTouch.has(key) ? 'pressed' : ''}
                >
                  <strong>{item.label}</strong>
                  {item.sub && <small>{item.sub}</small>}
                </button>
              )
            })}
          </div>
          <div className="round-buttons">
            {touchButtons.slice(6).map((item) => {
              const key = `${item.player}-${item.button}`
              return (
                <button
                  key={key}
                  {...touchHandlers(key, item.player, item.button)}
                  className={activeTouch.has(key) ? 'pressed' : ''}
                >
                  <strong>{item.label}</strong>
                  {item.sub && <small>{item.sub}</small>}
                </button>
              )
            })}
          </div>
        </section>
      </section>
    </main>
  )
}

export default App
