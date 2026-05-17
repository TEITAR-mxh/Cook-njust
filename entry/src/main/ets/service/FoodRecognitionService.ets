/**
 * 食物识别服务
 * 识别链路：HiAI NPU → MindSpore Lite CPU → 云端 API → 失败返回 identified=false。
 * 本地引擎自动检测可用性，模型文件缺失时自动降级到云端。
 */
import { CalorieCalculator, NutrientData } from '../utils/CalorieCalculator'
import { CloudFoodAnalyzer } from './CloudFoodAnalyzer'
import { HybridRecognizer } from './HybridRecognizer'

/** 统一的识别结果接口 */
export interface FoodRecognitionResult {
  /** 是否成功识别 */
  identified: boolean
  /** 食物名称 */
  foodName: string
  /** 每 100g 营养数据 */
  nutrient: NutrientData
  /** 数据来源 */
  source: 'local_npu' | 'local_cpu' | 'cloud' | 'manual' | 'none'
  /** 原始识别标签（调试用，云端时为空） */
  rawLabels: string[]
}

/** 默认兜底营养数据（未识别时展示） */
const DEFAULT_NUTRIENT: NutrientData = {
  calories: 100, protein: 5, fat: 3, carbs: 15, servingWeight: 200
}

export class FoodRecognitionService {
  /** 混合识别器单例（懒初始化） */
  private static hybrid: HybridRecognizer | null = null

  /**
   * 对图片文件（URI）执行混合识别链路。
   * 优先本地 NPU/CPU → 云端 API 兜底 → 失败返回 identified=false。
   * @param imageUri 本地图片 URI（file:// 路径）
   */
  static async recognize(imageUri: string): Promise<FoodRecognitionResult> {
    // ── 混合识别链路（HiAI NPU → MindSpore CPU → Cloud） ──
    try {
      if (FoodRecognitionService.hybrid === null) {
        FoodRecognitionService.hybrid = new HybridRecognizer()
      }
      const result = await FoodRecognitionService.hybrid.recognize(imageUri)
      // 如果混合链路返回了有效结果（identified=true 或至少尝试了），直接返回
      if (result.identified || result.source !== 'none') {
        return result
      }
    } catch (e) {
      console.error('[FoodRecognition] 混合识别链路异常:', JSON.stringify(e))
    }

    // ── 兜底：直接走云端（HybridRecognizer 内部异常时） ──
    try {
      const cloudResult = await CloudFoodAnalyzer.analyze(imageUri)
      if (cloudResult !== null) {
        const nutrient: NutrientData = {
          calories:      cloudResult.calories,
          protein:       cloudResult.protein,
          fat:           cloudResult.fat,
          carbs:         cloudResult.carbs,
          servingWeight: cloudResult.servingWeight,
        }
        return {
          identified: true,
          foodName:   cloudResult.foodName,
          nutrient,
          source:     'cloud',
          rawLabels:  [],
        }
      }
    } catch (e) {
      console.error('[FoodRecognition] 云端识别异常:', JSON.stringify(e))
    }

    return {
      identified: false,
      foodName:   '',
      nutrient:   DEFAULT_NUTRIENT,
      source:     'none',
      rawLabels:  [],
    }
  }
}
