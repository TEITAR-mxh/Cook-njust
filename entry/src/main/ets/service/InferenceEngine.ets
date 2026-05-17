/**
 * 本地推理引擎抽象接口
 * 为 HiAI NPU / MindSpore Lite 等多引擎提供统一抽象，
 * 便于 HybridRecognizer 进行通用编排。
 */
import type { NutrientData } from '../utils/CalorieCalculator'

/** 引擎初始化状态 */
export enum EngineStatus {
  UNINITIALIZED = 0,
  INITIALIZING  = 1,
  READY         = 2,
  FAILED        = 3,
  UNAVAILABLE   = 4,
}

/** 本地推理输出 */
export interface LocalInferenceResult {
  /** 识别出的食物名称（Top-1） */
  foodName: string
  /** 置信度 (0.0 - 1.0) */
  confidence: number
}

/** 带营养映射的最终结果 */
export interface MappedInferenceResult {
  foodName: string
  confidence: number
  nutrient: NutrientData
}

/** 推理引擎统一接口 */
export interface InferenceEngine {
  /** 引擎可读名称，例如 'HiAI NPU' */
  readonly name: string

  /** 数据溯源标识 */
  readonly source: 'local_npu' | 'local_cpu'

  /** 当前状态 */
  readonly status: EngineStatus

  /**
   * 初始化引擎：加载模型、分配资源。
   * @returns true 表示引擎就绪可用
   */
  initialize(): Promise<boolean>

  /**
   * 对本地图片执行推理。
   * @param imageUri 图片文件 URI (file:// 路径)
   * @returns 识别结果；失败或不可用时返回 null
   */
  infer(imageUri: string): Promise<LocalInferenceResult | null>

  /** 引擎是否处于就绪状态 */
  isAvailable(): boolean

  /** 释放引擎资源 */
  release(): void
}
