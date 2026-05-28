/**
 * 混合识别编排器 — 智能降级链路
 *
 * 推理链路（按优先级）：
 *   1. HiAI NPU（本地，置信度阈值 ≥ 0.55）
 *   2. MindSpore Lite CPU（本地，置信度阈值 ≥ 0.20）
 *   3. Baidu 云端 API（远端，无阈值要求）
 *
 * 每级失败或置信度不足时自动降级到下一级。
 * 模型文件缺失时，本地引擎自动标记为 UNAVAILABLE 并跳过，直接走云端。
 *
 * 设计原则：
 *   - 本地推理优先（隐私、离线可用、低延迟）
 *   - 云端兜底（高准确率、覆盖更多场景）
 *   - 优雅降级（任何一级失败不影响整体可用性）
 */
import { CalorieCalculator, NutrientData } from '../utils/CalorieCalculator'
import { CloudFoodAnalyzer } from './CloudFoodAnalyzer'
import { InferenceEngine, LocalInferenceResult } from './InferenceEngine'
import { HiAIFoodEngine } from './HiAIFoodEngine'
import { MindSporeFoodEngine } from './MindSporeFoodEngine'
import type { FoodRecognitionResult } from './FoodRecognitionService'

/** 默认兜底营养（所有引擎均失败时使用） */
const DEFAULT_NUTRIENT: NutrientData = {
  calories: 100, protein: 5, fat: 3, carbs: 15, servingWeight: 200
}

/** 置信度阈值 */
const HI_AI_CONFIDENCE_THRESHOLD: number = 0.55
const MINDSPORE_CONFIDENCE_THRESHOLD: number = 0.20

export class HybridRecognizer {
  private engines: InferenceEngine[] = []
  private initialized: boolean = false

  constructor() {
    this.engines = [
      new HiAIFoodEngine(),
      new MindSporeFoodEngine(),
    ]
  }

  /**
   * 懒初始化：在首次调用 recognize() 时并行初始化所有本地引擎。
   * 任一引擎初始化失败不影响其他引擎。
   */
  private async ensureInitialized(): Promise<void> {
    if (this.initialized) {
      return
    }

    // 并行初始化所有引擎（互不依赖）
    console.info(`[HybridRecognizer] Initializing ${this.engines.length} local engine(s) in parallel...`)
    const results: boolean[] = await Promise.all(
      this.engines.map(e => {
        console.info(`[HybridRecognizer] Starting ${e.name} initialization...`)
        return e.initialize().then((ok: boolean) => {
          console.info(`[HybridRecognizer] ${e.name} initialize() → ${ok}`)
          return ok
        }).catch((err: Object) => {
          console.error(`[HybridRecognizer] ${e.name} initialize() exception:`, JSON.stringify(err))
          return false
        })
      })
    )

    const availableEngines: string[] = this.engines
      .filter((_e, i) => results[i])
      .map(e => e.name)
    const unavailableEngines: string[] = this.engines
      .filter((_e, i) => !results[i])
      .map(e => e.name)

    console.info(`[HybridRecognizer] Init complete. Available: [${availableEngines.join(', ') || 'none'}], Unavailable: [${unavailableEngines.join(', ') || 'none'}]`)
    this.initialized = true
  }

  /**
   * 执行完整的混合识别链路。
   *
   * @param imageUri 本地图片 URI (file:// 路径)
   * @returns 识别结果，含来源追踪
   */
  async recognize(imageUri: string): Promise<FoodRecognitionResult> {
    await this.ensureInitialized()

    // ── Stage 1 + 2: 本地引擎（HiAI NPU → MindSpore CPU） ──
    console.info(`[HybridRecognizer] Starting local inference chain, ${this.engines.length} engine(s) registered`)

    for (const engine of this.engines) {
      console.info(`[HybridRecognizer] Trying ${engine.name} (source=${engine.source})...`)

      if (!engine.isAvailable()) {
        console.warn(`[HybridRecognizer] ${engine.name} NOT available (status=EngineStatus), skipping`)
        continue
      }

      console.info(`[HybridRecognizer] ${engine.name} is available, calling infer()`)
      try {
        const result: LocalInferenceResult | null = await engine.infer(imageUri)
        if (result !== null) {
          const threshold: number = engine.source === 'local_npu'
            ? HI_AI_CONFIDENCE_THRESHOLD
            : MINDSPORE_CONFIDENCE_THRESHOLD

          console.info(
            `[HybridRecognizer] ${engine.name} result: "${result.foodName}" confidence=${result.confidence.toFixed(4)}, threshold=${threshold}`
          )

          if (result.confidence >= threshold) {
            // 本地推理成功，映射营养数据
            const nutrient: NutrientData = this.mapNutrient(result.foodName)
            console.info(`[HybridRecognizer] ${engine.name} ACCEPTED → source="${engine.source}"`)
            return {
              identified: true,
              foodName: result.foodName,
              nutrient,
              source: engine.source,
              rawLabels: [],
            }
          }

          console.info(
            `[HybridRecognizer] ${engine.name} confidence ${result.confidence.toFixed(3)} ` +
            `below threshold ${threshold}, falling back to next engine`
          )
        } else {
          console.warn(`[HybridRecognizer] ${engine.name} infer() returned null`)
        }
      } catch (e) {
        console.error(`[HybridRecognizer] ${engine.name} inference exception:`, JSON.stringify(e))
      }
    }
    console.info('[HybridRecognizer] All local engines exhausted, falling back to cloud')

    // ── Stage 3: 云端兜底（Baidu API） ──
    try {
      const cloudResult = await CloudFoodAnalyzer.analyze(imageUri)
      if (cloudResult !== null) {
        console.info('[HybridRecognizer] Cloud API succeeded')
        return {
          identified: true,
          foodName: cloudResult.foodName,
          nutrient: {
            calories: cloudResult.calories,
            protein: cloudResult.protein,
            fat: cloudResult.fat,
            carbs: cloudResult.carbs,
            servingWeight: cloudResult.servingWeight,
          },
          source: 'cloud',
          rawLabels: [],
        }
      }
    } catch (e) {
      console.error('[HybridRecognizer] Cloud API exception:', JSON.stringify(e))
    }

    // ── 全部失败 ──
    console.warn('[HybridRecognizer] All stages failed, returning unidentified result')
    return {
      identified: false,
      foodName: '',
      nutrient: DEFAULT_NUTRIENT,
      source: 'none',
      rawLabels: [],
    }
  }

  /** 释放所有引擎资源 */
  release(): void {
    for (const engine of this.engines) {
      try { engine.release() } catch (_e) { /* ignore */ }
    }
  }

  /** 将食物名称映射为营养数据（优先精确匹配，兜底模糊匹配 + 默认值） */
  private mapNutrient(foodName: string): NutrientData {
    // 精确匹配
    const exact: NutrientData | null = CalorieCalculator.lookup(foodName)
    if (exact !== null) {
      return exact
    }

    // 模糊匹配
    const fuzzy = CalorieCalculator.fuzzyMatch([foodName])
    if (fuzzy !== null && fuzzy.data !== undefined) {
      return fuzzy.data
    }

    // 兜底默认值
    return {
      calories: 150,
      protein: 6,
      fat: 5,
      carbs: 20,
      servingWeight: 200,
    }
  }
}
