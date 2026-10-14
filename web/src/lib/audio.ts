// Small ring-buffer bridge between the NES sample callback and Web Audio.
export class NesAudio {
  private context: AudioContext | null = null
  private processor: ScriptProcessorNode | null = null
  private buffer = new Float32Array(96000)
  private writeOffset = 0
  private readOffset = 0
  private queuedSamples = 0

  async start(): Promise<number> {
    if (this.context && this.processor) {
      await this.context.resume()
      return this.context.sampleRate
    }

    const AudioContextClass = window.AudioContext ?? (window as typeof window & { webkitAudioContext?: typeof AudioContext }).webkitAudioContext
    if (!AudioContextClass) throw new Error('当前浏览器不支持声音播放')

    let context: AudioContext
    try {
      context = new AudioContextClass({ sampleRate: 48000 })
    } catch {
      context = new AudioContextClass()
    }
    await context.resume()
    this.context = context
    this.writeOffset = 0
    this.readOffset = 0
    this.queuedSamples = 0

    const processor = context.createScriptProcessor(2048, 0, 2)
    processor.onaudioprocess = (event) => {
      const left = event.outputBuffer.getChannelData(0)
      const right = event.outputBuffer.getChannelData(1)
      const amount = Math.min(left.length, this.queuedSamples)
      for (let i = 0; i < amount; i += 1) {
        left[i] = this.buffer[this.readOffset]
        right[i] = this.buffer[(this.readOffset + 1) % this.buffer.length]
        this.readOffset = (this.readOffset + 2) % this.buffer.length
      }
      if (amount < left.length) {
        left.fill(0, amount)
        right.fill(0, amount)
      }
      this.queuedSamples -= amount
    }
    processor.connect(context.destination)
    this.processor = processor
    return context.sampleRate
  }

  enqueue(left: number, right: number): void {
    if (!this.processor) return
    if (this.queuedSamples * 2 >= this.buffer.length - 4) {
      // Drop a stale chunk when the host cannot consume audio promptly.
      this.queuedSamples = Math.floor(this.queuedSamples * 0.75)
      this.readOffset =
        (this.writeOffset - this.queuedSamples * 2 + this.buffer.length) % this.buffer.length
    }
    this.buffer[this.writeOffset] = Math.max(-1, Math.min(1, left))
    this.buffer[(this.writeOffset + 1) % this.buffer.length] = Math.max(-1, Math.min(1, right))
    this.writeOffset = (this.writeOffset + 2) % this.buffer.length
    this.queuedSamples += 1
  }

  stop(): void {
    this.processor?.disconnect()
    this.processor = null
    this.queuedSamples = 0
    this.readOffset = this.writeOffset
    void this.context?.suspend()
  }
}
