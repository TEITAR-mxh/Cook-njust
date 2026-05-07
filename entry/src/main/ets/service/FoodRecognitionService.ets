/**
 * 食物识别服务
 * 识别链路：云端 API → 失败时返回 identified=false 让用户手动输入。
 * 注：VisionKit objectDetection 在当前 SDK 版本中不可用，已移除端侧识别步骤。
 */
import { CalorieCalculator, NutrientData } from '../utils/CalorieCalculator'
import { CloudFoodAnalyzer } from './CloudFoodAnalyzer'

/** 统一的识别结果接口 */
export interface FoodRecognitionResult {
  /** 是否成功识别 */
  identified: boolean
  /** 食物名称 */
  foodName: string
  /** 每 100g 营养数据 */
  nutrient: NutrientData
  /** 数据来源 */
  source: 'local' | 'cloud' | 'manual' | 'none'
  /** 原始识别标签（调试用，云端时为空） */
  rawLabels: string[]
}

/** 默认兜底营养数据（未识别时展示） */
const DEFAULT_NUTRIENT: NutrientData = {
  calories: 100, protein: 5, fat: 3, carbs: 15, servingWeight: 200
}

export class FoodRecognitionService {
  /**
   * 对图片文件（URI）执行识别链路：云端 API → 失败则返回 identified=false。
   * @param imageUri 本地图片 URI（file:// 路径）
   */
  static async recognize(imageUri: string): Promise<FoodRecognitionResult> {
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
