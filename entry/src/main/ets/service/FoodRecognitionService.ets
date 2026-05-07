/**
 * 食物识别服务
 * 识别链路：端侧 VisionKit objectDetection → 本地库 fuzzyMatch → 云端 API
 * 任一环节成功则返回结果，全部失败则返回 identified=false 让用户手动输入。
 */
import { objectDetection } from '@kit.VisionKit'
import { visionBase } from '@kit.VisionKit'
import { image } from '@kit.ImageKit'
import { fileIo } from '@kit.CoreFileKit'
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
  /** 端侧检测到的原始标签（调试用） */
  rawLabels: string[]
}

/** objectDetection 单条结果结构（API 22） */
interface DetectionItem {
  type: string
  probability?: number
}

/** 端侧置信度阈值 */
const CONFIDENCE_THRESHOLD = 0.4

/** 默认兜底营养数据（未识别时展示） */
const DEFAULT_NUTRIENT: NutrientData = {
  calories: 100, protein: 5, fat: 3, carbs: 15, servingWeight: 200
}

export class FoodRecognitionService {
  /**
   * 对图片文件（URI）执行完整识别链路。
   * @param imageUri 本地图片 URI（file:// 路径）
   */
  static async recognize(imageUri: string): Promise<FoodRecognitionResult> {
    // ── Step 1：加载图片为 PixelMap ──────────────────────────────────
    let pixelMap: image.PixelMap | null = null
    try {
      pixelMap = await FoodRecognitionService.loadPixelMap(imageUri)
    } catch (e) {
      console.warn('[FoodRecognition] PixelMap 加载失败，跳转云端', JSON.stringify(e))
    }

    // ── Step 2：端侧 VisionKit objectDetection ───────────────────────
    const rawLabels: string[] = []
    if (pixelMap !== null) {
      try {
        const localResult = await FoodRecognitionService.detectLocal(pixelMap, rawLabels)
        if (localResult !== null) {
          return {
            identified: true,
            foodName: localResult.name,
            nutrient: localResult.data,
            source: 'local',
            rawLabels,
          }
        }
      } catch (e) {
        console.warn('[FoodRecognition] 端侧识别异常，降级云端:', JSON.stringify(e))
      } finally {
        pixelMap.release()
      }
    }

    // ── Step 3：云端深度识别 ─────────────────────────────────────────
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
          foodName: cloudResult.foodName,
          nutrient,
          source: 'cloud',
          rawLabels,
        }
      }
    } catch (e) {
      console.error('[FoodRecognition] 云端识别异常:', JSON.stringify(e))
    }

    // ── Step 4：全部失败，提示用户手动输入 ──────────────────────────
    return {
      identified: false,
      foodName: '',
      nutrient: DEFAULT_NUTRIENT,
      source: 'none',
      rawLabels,
    }
  }

  // ── 私有：加载 PixelMap ─────────────────────────────────────────────

  private static async loadPixelMap(uri: string): Promise<image.PixelMap> {
    const filePath = uri.startsWith('file://') ? uri.substring(7) : uri
    const file = await fileIo.open(filePath, fileIo.OpenMode.READ_ONLY)
    try {
      const src = image.createImageSource(file.fd)
      const pm = await src.createPixelMap({ editable: false })
      src.release()
      return pm
    } finally {
      await fileIo.close(file.fd)
    }
  }

  // ── 私有：端侧检测 + 本地库匹配 ──────────────────────────────────

  private static async detectLocal(
    pixelMap: image.PixelMap,
    labelsOut: string[]
  ): Promise<{ name: string; data: NutrientData } | null> {
    const detector = objectDetection.createObjectDetector({
      conf: CONFIDENCE_THRESHOLD,
    })

    const visionInfo: visionBase.VisionInfo = { pixelMap }
    const results = await detector.detect(visionInfo) as DetectionItem[]

    // 收集置信度满足阈值的标签
    const candidates: string[] = []
    for (const item of results) {
      if (item.type && item.type.length > 0) {
        candidates.push(item.type)
        labelsOut.push(item.type)
      }
    }

    if (candidates.length === 0) return null

    // 本地库模糊匹配
    return CalorieCalculator.fuzzyMatch(candidates)
  }
}
