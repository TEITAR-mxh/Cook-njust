/**
 * 营养评价系统 - 纯函数服务。
 * 实现简化版 Nutri-Score（参考 Ofcom 模型）与 DRI 进度计算。
 */
import type { RecipeNutrition, NutriScore } from '../model/recipe'

/**
 * 中国居民膳食营养素参考摄入量（18~49 岁轻体力成年男性，每日）
 * 来源：《中国居民膳食营养素参考摄入量（2023 版）》
 */
export interface DailyDRI {
  calories: number  // 千卡
  protein: number   // 克
  fat: number       // 克
  carbs: number     // 克
  fiber: number     // 克
  sodium: number    // 毫克
}

export const ADULT_MALE_DRI: DailyDRI = {
  calories: 2250,
  protein: 65,
  fat: 60,
  carbs: 300,
  fiber: 25,
  sodium: 2000,
}

/** 营养总和：将多份菜谱的营养数据汇总 */
export function aggregateNutrition(items: RecipeNutrition[]): RecipeNutrition {
  const result: RecipeNutrition = { calories: 0, protein: 0, fat: 0, carbs: 0, fiber: 0, sodium: 0 }
  for (let i = 0; i < items.length; i++) {
    result.calories += items[i].calories
    result.protein += items[i].protein
    result.fat += items[i].fat
    result.carbs += items[i].carbs
    result.fiber += items[i].fiber
    result.sodium += items[i].sodium
  }
  return result
}

/**
 * 计算各营养素相对 DRI 的百分比（0~100+），保留 1 位小数。
 */
export interface NutritionProgress {
  caloriesPct: number
  proteinPct: number
  fatPct: number
  carbsPct: number
  fiberPct: number
  sodiumPct: number
}

export function calcNutritionProgress(total: RecipeNutrition, dri: DailyDRI): NutritionProgress {
  return {
    caloriesPct: Math.round((total.calories / dri.calories) * 1000) / 10,
    proteinPct: Math.round((total.protein / dri.protein) * 1000) / 10,
    fatPct: Math.round((total.fat / dri.fat) * 1000) / 10,
    carbsPct: Math.round((total.carbs / dri.carbs) * 1000) / 10,
    fiberPct: Math.round((total.fiber / dri.fiber) * 1000) / 10,
    sodiumPct: Math.round((total.sodium / dri.sodium) * 1000) / 10,
  }
}

/**
 * 生成营养摄入评价文字。
 */
export function generateNutritionTip(progress: NutritionProgress): string {
  const tips: string[] = []
  if (progress.caloriesPct > 110) {
    tips.push('今日能量摄入偏多，建议减少高油菜肴')
  } else if (progress.caloriesPct < 60) {
    tips.push('今日能量摄入偏少，注意补充主食')
  }
  if (progress.proteinPct < 70) {
    tips.push('蛋白质摄入不足，可增加肉蛋豆制品')
  }
  if (progress.sodiumPct > 100) {
    tips.push('钠摄入已超标，注意低盐饮食')
  }
  if (progress.fiberPct < 60) {
    tips.push('膳食纤维偏少，多吃蔬菜水果')
  }
  if (tips.length === 0) {
    return '营养均衡，继续保持！'
  }
  return tips.join('；') + '。'
}

// ─── Nutri-Score 简化版 ───────────────────────────────────────────────────

/**
 * 负面营养点（能量/脂肪/糖/钠），每项 0~10 分。
 * 此处基于整份菜谱热量估算（非严格 per 100g），适用于横向比较。
 */
function calcNegativePoints(n: RecipeNutrition, hasVegetableTag: boolean): number {
  // 能量：以 kcal 计，每 225kcal 1 分，最高 10
  const ePoints = Math.min(10, Math.floor(n.calories / 225))
  // 脂肪（假设 40% 为饱和脂肪）：每 2g 1 分，最高 10
  const satFat = n.fat * 0.4
  const fPoints = Math.min(10, Math.floor(satFat / 2))
  // 糖（假设碳水中 35% 为糖）：每 9g 1 分，最高 10
  const sugars = n.carbs * 0.35
  const sPoints = Math.min(10, Math.floor(sugars / 9))
  // 钠：每 200mg 1 分，最高 10
  const nPoints = Math.min(10, Math.floor(n.sodium / 200))
  return ePoints + fPoints + sPoints + nPoints
}

/**
 * 正面营养点（蛋白质/纤维/蔬果），每项 0~5 分。
 */
function calcPositivePoints(n: RecipeNutrition, hasVegetableTag: boolean): number {
  // 蛋白质：每 5g 1 分，最高 5
  const pPoints = Math.min(5, Math.floor(n.protein / 5))
  // 膳食纤维：每 3g 1 分，最高 5
  const fPoints = Math.min(5, Math.floor(n.fiber / 3))
  // 蔬果坚果比例（简化）：有蔬菜标签 +2
  const vPoints = hasVegetableTag ? 2 : 0
  return pPoints + fPoints + vPoints
}

/**
 * 计算 Nutri-Score 等级（A~E）。
 * @param n 营养数据
 * @param tags 菜谱标签（用于判断是否含蔬菜）
 */
export function calcNutriScore(n: RecipeNutrition, tags: string[]): NutriScore {
  const vegetableKeywords = ['蔬菜', '素', '轻食', '减脂', '健康', '清淡', '素食']
  let hasVegTag = false
  for (let i = 0; i < tags.length; i++) {
    for (let j = 0; j < vegetableKeywords.length; j++) {
      if (tags[i].includes(vegetableKeywords[j])) {
        hasVegTag = true
        break
      }
    }
    if (hasVegTag) break
  }

  const neg = calcNegativePoints(n, hasVegTag)
  const pos = calcPositivePoints(n, hasVegTag)
  const score = neg - pos

  if (score <= -1) return 'A'
  if (score <= 2) return 'B'
  if (score <= 10) return 'C'
  if (score <= 18) return 'D'
  return 'E'
}

/** Nutri-Score 徽章颜色（前景色、背景色） */
export interface NutriScoreColors {
  bg: string
  text: string
}

export function getNutriScoreColors(score: NutriScore): NutriScoreColors {
  switch (score) {
    case 'A': return { bg: '#1A7C3E', text: '#FFFFFF' }
    case 'B': return { bg: '#56AB2F', text: '#FFFFFF' }
    case 'C': return { bg: '#F5BE0B', text: '#1F2937' }
    case 'D': return { bg: '#F28B0C', text: '#FFFFFF' }
    case 'E': return { bg: '#E3001B', text: '#FFFFFF' }
    default: return { bg: '#9CA3AF', text: '#FFFFFF' }
  }
}

/**
 * 内置的示例营养数据（约 20 道常见菜）。
 * 键为菜谱名称，值为 RecipeNutrition。
 * RecipeRepository 加载后由外部按名称注入。
 */
export const SAMPLE_NUTRITION_DATA: Map<string, RecipeNutrition> = new Map<string, RecipeNutrition>([
  ['番茄炒蛋', { calories: 280, protein: 14, fat: 18, carbs: 12, fiber: 2, sodium: 680 }],
  ['红烧肉', { calories: 560, protein: 22, fat: 42, carbs: 18, fiber: 0.5, sodium: 1200 }],
  ['清炒土豆丝', { calories: 210, protein: 4, fat: 8, carbs: 32, fiber: 3, sodium: 520 }],
  ['麻婆豆腐', { calories: 320, protein: 18, fat: 20, carbs: 14, fiber: 2, sodium: 1100 }],
  ['宫保鸡丁', { calories: 400, protein: 28, fat: 22, carbs: 20, fiber: 2, sodium: 900 }],
  ['蒜蓉炒青菜', { calories: 120, protein: 4, fat: 7, carbs: 12, fiber: 4, sodium: 480 }],
  ['糖醋排骨', { calories: 480, protein: 20, fat: 28, carbs: 36, fiber: 0, sodium: 800 }],
  ['鸡蛋炒饭', { calories: 420, protein: 16, fat: 14, carbs: 58, fiber: 1, sodium: 750 }],
  ['酸辣汤', { calories: 180, protein: 12, fat: 8, carbs: 16, fiber: 2, sodium: 1000 }],
  ['水煮鱼', { calories: 380, protein: 32, fat: 22, carbs: 8, fiber: 1, sodium: 1300 }],
  ['白灼虾', { calories: 220, protein: 30, fat: 4, carbs: 2, fiber: 0, sodium: 600 }],
  ['蒸蛋', { calories: 160, protein: 12, fat: 10, carbs: 4, fiber: 0, sodium: 400 }],
  ['鱼香肉丝', { calories: 350, protein: 22, fat: 18, carbs: 22, fiber: 2, sodium: 1050 }],
  ['土豆烧牛肉', { calories: 440, protein: 26, fat: 20, carbs: 38, fiber: 3, sodium: 850 }],
  ['凉拌黄瓜', { calories: 80, protein: 2, fat: 4, carbs: 10, fiber: 2, sodium: 450 }],
  ['蒜苗炒腊肉', { calories: 460, protein: 18, fat: 36, carbs: 10, fiber: 2, sodium: 1400 }],
  ['红烧茄子', { calories: 260, protein: 4, fat: 14, carbs: 28, fiber: 4, sodium: 700 }],
  ['葱油拌面', { calories: 380, protein: 10, fat: 12, carbs: 58, fiber: 2, sodium: 850 }],
  ['韭菜炒鸡蛋', { calories: 240, protein: 14, fat: 16, carbs: 8, fiber: 2, sodium: 560 }],
  ['清蒸鱼', { calories: 200, protein: 28, fat: 6, carbs: 4, fiber: 0, sodium: 700 }],
])
