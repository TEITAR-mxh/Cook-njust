/**
 * MindSpore Lite — CPU/GPU 推理引擎
 *
 * 作为 HiAI NPU 的兜底方案，支持没有麒麟芯片的设备在 CPU 上运行本地推理。
 * 使用 @ohos.ai.mindSporeLite (MindSpore Lite Kit) 加载 .ms 模型并执行推理。
 *
 * 模型格式：.ms（MindSpore Lite 离线模型）
 * 模型放置路径：entry/src/main/resources/rawfile/food_model.ms
 * 标签文件路径：entry/src/main/resources/rawfile/food_labels.txt
 */
import { resourceManager } from '@kit.LocalizationKit'
import { fileIo } from '@kit.CoreFileKit'
import { util } from '@kit.ArkTS'
import mindSporeLite from '@ohos.ai.mindSporeLite'
import {
  InferenceEngine,
  EngineStatus,
  LocalInferenceResult,
} from './InferenceEngine'
import { ImagePreprocessor } from '../utils/ImagePreprocessor'

/** 模型输入尺寸 */
const MODEL_INPUT_W: number = 224
const MODEL_INPUT_H: number = 224

/** Softmax 解码结果 */
interface DecodeResult {
  topIndex: number
  topConfidence: number
}

/** Top-K 单项 */
interface TopKItem {
  index: number
  confidence: number
}

/** 空解码结果 */
const EMPTY_DECODE_RESULT: DecodeResult = {
  topIndex: -1,
  topConfidence: 0
}

/** 模型/标签文件在 rawfile 中的路径 */
const MODEL_FILE_NAME: string = 'food_model.ms'
const LABEL_FILE_NAME: string = 'food_labels.txt'

export class MindSporeFoodEngine implements InferenceEngine {
  readonly name: string = 'MindSpore CPU'
  readonly source: 'local_cpu' = 'local_cpu'

  private _status: EngineStatus = EngineStatus.UNINITIALIZED
  private labels: string[] = []
  /** MindSpore Lite Model 实例 */
  private msModel: Object | null = null

  get status(): EngineStatus {
    return this._status
  }

  async initialize(): Promise<boolean> {
    if (this._status === EngineStatus.READY) {
      return true
    }
    if (this._status === EngineStatus.INITIALIZING) {
      return false
    }

    this._status = EngineStatus.INITIALIZING

    try {
      // 1. 获取 rawfile 文件描述符
      const ctx = getContext()
      const resMgr: resourceManager.ResourceManager = ctx.resourceManager

      let rawFd: resourceManager.RawFileDescriptor
      try {
        rawFd = await resMgr.getRawFd(MODEL_FILE_NAME)
      } catch (_e) {
        console.info(`[MindSporeFoodEngine] Model file '${MODEL_FILE_NAME}' not found in rawfile, engine unavailable`)
        this._status = EngineStatus.UNAVAILABLE
        return false
      }

      // 2. 加载模型（API 22: loadModelFromFd 仅接受 fd，运行时配置通过 predict 传递）
      this.msModel = await mindSporeLite.loadModelFromFd(rawFd.fd)

      // 关闭 rawfile fd（模型已加载到内存）
      try { await fileIo.close(rawFd.fd) } catch (_e) { /* ignore */ }

      console.info('[MindSporeFoodEngine] Model loaded successfully via MindSpore Lite')

      // 4. 加载标签文件
      try {
        const labelContent: Uint8Array =
          await resMgr.getRawFileContent(LABEL_FILE_NAME)
        this.labels = this.bytesToString(labelContent)
          .split('\n').map((s: string) => s.trim()).filter((s: string) => s.length > 0)
        console.info(`[MindSporeFoodEngine] Loaded ${this.labels.length} labels`)
      } catch (_e) {
        console.info('[MindSporeFoodEngine] Label file not found, using empty label map')
        this.labels = []
      }

      this._status = EngineStatus.READY
      return true
    } catch (e) {
      console.warn('[MindSporeFoodEngine] initialization failed:', JSON.stringify(e))
      this._status = EngineStatus.UNAVAILABLE
      return false
    }
  }

  async infer(imageUri: string): Promise<LocalInferenceResult | null> {
    if (!this.isAvailable() || this.msModel === null) {
      return null
    }

    try {
      // 1. 图片预处理 → Float32Array (CHW, 3×224×224)
      const inputTensor: Float32Array = await ImagePreprocessor.preprocess(
        imageUri, MODEL_INPUT_W, MODEL_INPUT_H
      )

      // 2. 获取模型输入/输出张量（MindSpore Lite 需预分配 outputs）
      const model = this.msModel as Record<string, Function>
      const inputs: Object[] = model['getInputs']() as Object[]
      if (inputs.length === 0) {
        console.error('[MindSporeFoodEngine] No input tensors found')
        return null
      }
      const outputs: Object[] = model['getOutputs']() as Object[]
      if (outputs.length === 0) {
        console.error('[MindSporeFoodEngine] No output tensors found')
        return null
      }
      console.info(`[MindSporeFoodEngine] Model has ${inputs.length} input(s), ${outputs.length} output(s)`)

      // 3. 填充输入数据 (Float32Array → 独立 ArrayBuffer，避免 byteOffset 问题)
      const inputBuffer: ArrayBuffer = inputTensor.buffer.slice(
        inputTensor.byteOffset, inputTensor.byteOffset + inputTensor.byteLength
      )
      const inputTensorObj = inputs[0] as Record<string, Function>
      inputTensorObj['setData'](inputBuffer)

      // 4. 执行推理（predict 将结果写入预分配的 outputs 张量，返回 void）
      await model['predict'](inputs, outputs)
      console.info('[MindSporeFoodEngine] predict() completed')

      // 5. 读取输出数据
      const outputTensorObj = outputs[0] as Record<string, Function>
      const outputBuffer: ArrayBuffer = outputTensorObj['getData']() as ArrayBuffer
      const outputData: Float32Array = new Float32Array(outputBuffer)

      // 6. Softmax + Top-K 解码
      const topK = this.decodeTopK(outputData, 5)
      const decodeResult: DecodeResult = {
        topIndex: topK[0].index,
        topConfidence: topK[0].confidence
      }

      // 诊断：打印 Top-5 预测
      let top5Log: string = ''
      for (let k: number = 0; k < topK.length; k++) {
        const label: string = (topK[k].index >= 0 && topK[k].index < this.labels.length)
          ? this.labels[topK[k].index] : `?`
        top5Log += `\n  #${k + 1}: ${label} (${topK[k].confidence.toFixed(3)})`
      }
      console.info(`[MindSporeFoodEngine] Top-5 predictions:${top5Log}`)

      // 7. 映射到标签名
      const foodName: string = (decodeResult.topIndex >= 0 && decodeResult.topIndex < this.labels.length)
        ? this.labels[decodeResult.topIndex]
        : `unknown_${decodeResult.topIndex}`

      console.info(`[MindSporeFoodEngine] Result: "${foodName}" (${decodeResult.topConfidence.toFixed(3)})`)
      const result: LocalInferenceResult = {
        foodName: foodName,
        confidence: decodeResult.topConfidence
      }
      return result
    } catch (e) {
      console.error('[MindSporeFoodEngine] inference failed:', JSON.stringify(e))
      return null
    }
  }

  isAvailable(): boolean {
    return this._status === EngineStatus.READY && this.msModel !== null
  }

  release(): void {
    this.msModel = null
    this.labels = []
    this._status = EngineStatus.UNINITIALIZED
  }

  /** Softmax + Top-K 解码（用于诊断） */
  private decodeTopK(logits: Float32Array, k: number): TopKItem[] {
    const count: number = logits.length
    if (count === 0) {
      const empty: TopKItem[] = []
      return empty
    }

    // Softmax
    let maxVal: number = logits[0]
    for (let i: number = 1; i < count; i++) {
      if (logits[i] > maxVal) { maxVal = logits[i] }
    }

    let sumExp: number = 0
    const probs: Float32Array = new Float32Array(count)
    for (let i: number = 0; i < count; i++) {
      const expVal: number = Math.exp(logits[i] - maxVal)
      probs[i] = expVal
      sumExp += expVal
    }

    // 收集所有 (index, prob) 并排序取 Top-K
    const items: TopKItem[] = []
    const actualK: number = k < count ? k : count
    for (let i: number = 0; i < count; i++) {
      const item: TopKItem = { index: i, confidence: probs[i] / sumExp }
      items.push(item)
    }
    // 按 confidence 降序排列
    items.sort((a: TopKItem, b: TopKItem) => b.confidence - a.confidence)
    const result: TopKItem[] = []
    for (let i: number = 0; i < actualK; i++) {
      result.push(items[i])
    }
    return result
  }

  /** Softmax + Top-1 */
  private decodeOutput(logits: Float32Array): DecodeResult {
    const count: number = logits.length
    if (count === 0) {
      return EMPTY_DECODE_RESULT
    }

    // Softmax: exp(x - max) / sum(exp(x - max))
    let maxVal: number = logits[0]
    for (let i: number = 1; i < count; i++) {
      if (logits[i] > maxVal) { maxVal = logits[i] }
    }

    let sumExp: number = 0
    const probs: Float32Array = new Float32Array(count)
    for (let i: number = 0; i < count; i++) {
      const expVal: number = Math.exp(logits[i] - maxVal)
      probs[i] = expVal
      sumExp += expVal
    }

    let topIndex: number = 0
    let topConfidence: number = 0
    for (let i: number = 0; i < count; i++) {
      const prob: number = probs[i] / sumExp
      if (prob > topConfidence) {
        topConfidence = prob
        topIndex = i
      }
    }

    const result: DecodeResult = { topIndex: topIndex, topConfidence: topConfidence }
    return result
  }

  /** Uint8Array → UTF-8 字符串（TextDecoder 正确处理多字节中文） */
  private bytesToString(bytes: Uint8Array): string {
    const decoder = new util.TextDecoder('utf-8')
    return decoder.decodeToString(bytes)
  }
}
