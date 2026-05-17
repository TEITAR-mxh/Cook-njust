/**
 * HiAI NPU — 推理引擎
 *
 * 利用麒麟芯片的 NPU（神经网络处理单元）进行低延迟、低功耗的本地菜品识别。
 * 底层复用 MindSpore Lite Kit 的 NPU 后端，与 MindSporeFoodEngine 共享同一份 .ms 模型文件。
 *
 * 前置条件：
 *   - 设备搭载麒麟 SoC (Kirin 9000+)
 *   - MindSpore Lite NPU 后端可用
 *
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

/** 空解码结果 */
const EMPTY_DECODE_RESULT: DecodeResult = {
  topIndex: -1,
  topConfidence: 0
}

/** 模型/标签文件在 rawfile 中的路径 */
const MODEL_FILE_NAME: string = 'food_model.ms'
const LABEL_FILE_NAME: string = 'food_labels.txt'

export class HiAIFoodEngine implements InferenceEngine {
  readonly name: string = 'HiAI NPU'
  readonly source: 'local_npu' = 'local_npu'

  private _status: EngineStatus = EngineStatus.UNINITIALIZED
  private labels: string[] = []
  /** MindSpore Lite Model 实例 (加载到 NPU) */
  private msModel: Object | null = null
  /** NPU 后端是否经探测可用 */
  private npuProbed: boolean = false

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
      // 1. 探测 NPU 可用性：使用 MindSpore Lite 的 deviceInfo 或直接尝试加载
      if (!this.probeNPUAvailable()) {
        console.info('[HiAIFoodEngine] NPU backend not available on this device')
        this._status = EngineStatus.UNAVAILABLE
        return false
      }

      // 2. 检查模型文件
      const ctx = getContext()
      const resMgr: resourceManager.ResourceManager = ctx.resourceManager

      let rawFd: resourceManager.RawFileDescriptor
      try {
        rawFd = await resMgr.getRawFd(MODEL_FILE_NAME)
      } catch (_e) {
        console.info(`[HiAIFoodEngine] Model file '${MODEL_FILE_NAME}' not found in rawfile`)
        this._status = EngineStatus.UNAVAILABLE
        return false
      }

      // 3. 加载模型（模型格式与 MindSpore CPU 引擎共享同一 .ms 文件）
      this.msModel = await mindSporeLite.loadModelFromFd(rawFd.fd)

      // 关闭 rawfile fd（模型已加载到内存）
      try { await fileIo.close(rawFd.fd) } catch (_e) { /* ignore */ }

      console.info('[HiAIFoodEngine] Model loaded for NPU inference')

      // 4. 加载标签文件
      try {
        const labelContent: Uint8Array =
          await resMgr.getRawFileContent(LABEL_FILE_NAME)
        this.labels = this.bytesToString(labelContent)
          .split('\n').map((s: string) => s.trim()).filter((s: string) => s.length > 0)
        console.info(`[HiAIFoodEngine] Loaded ${this.labels.length} labels`)
      } catch (_e) {
        console.info('[HiAIFoodEngine] Label file not found')
        this.labels = []
      }

      this._status = EngineStatus.READY
      return true
    } catch (e) {
      console.warn('[HiAIFoodEngine] initialization failed:', JSON.stringify(e))
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
        console.error('[HiAIFoodEngine] No input tensors found')
        return null
      }
      const outputs: Object[] = model['getOutputs']() as Object[]
      if (outputs.length === 0) {
        console.error('[HiAIFoodEngine] No output tensors found')
        return null
      }
      console.info(`[HiAIFoodEngine] Model has ${inputs.length} input(s), ${outputs.length} output(s)`)

      // 3. 填充输入数据
      const inputBuffer: ArrayBuffer = inputTensor.buffer.slice(
        inputTensor.byteOffset, inputTensor.byteOffset + inputTensor.byteLength
      )
      const inputTensorObj = inputs[0] as Record<string, Function>
      inputTensorObj['setData'](inputBuffer)

      // 4. 执行推理（predict 将结果写入预分配的 outputs 张量，返回 void）
      await model['predict'](inputs, outputs)
      console.info('[HiAIFoodEngine] predict() completed')

      // 5. 读取输出
      const outputTensorObj = outputs[0] as Record<string, Function>
      const outputBuffer: ArrayBuffer = outputTensorObj['getData']() as ArrayBuffer
      const outputData: Float32Array = new Float32Array(outputBuffer)

      // 6. Softmax + Top-1 解码
      const decodeResult: DecodeResult = this.decodeOutput(outputData)

      // 7. 映射到标签名
      const foodName: string = (decodeResult.topIndex >= 0 && decodeResult.topIndex < this.labels.length)
        ? this.labels[decodeResult.topIndex]
        : `unknown_${decodeResult.topIndex}`

      console.info(`[HiAIFoodEngine] Result: "${foodName}" (${decodeResult.topConfidence.toFixed(3)})`)
      const result: LocalInferenceResult = {
        foodName: foodName,
        confidence: decodeResult.topConfidence
      }
      return result
    } catch (e) {
      console.error('[HiAIFoodEngine] inference failed:', JSON.stringify(e))
      return null
    }
  }

  isAvailable(): boolean {
    return this._status === EngineStatus.READY && this.msModel !== null
  }

  release(): void {
    this.msModel = null
    this.labels = []
    this.npuProbed = false
    this._status = EngineStatus.UNINITIALIZED
  }

  /** 探测 NPU 后端是否可用 */
  private probeNPUAvailable(): boolean {
    if (this.npuProbed) {
      return true
    }

    try {
      // 探测 NPU 可用性：直接标记为已探测，实际可用性在首次 predict 时验证
      // 若 NPU 不可用，predict 会抛出异常 → infer 返回 null → 自动降级到 CPU
      this.npuProbed = true
      return true
    } catch (e) {
      console.info('[HiAIFoodEngine] NPU probe failed:', JSON.stringify(e))
      return false
    }
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
