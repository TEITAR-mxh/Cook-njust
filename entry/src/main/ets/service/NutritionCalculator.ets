/**
 * 营养评价系统 - 纯函数服务。
 * 实现简化版 Nutri-Score（参考 Ofcom 模型）与 DRI 进度计算。
 */
import type { RecipeNutrition, NutriScore } from '../model/recipe'
import type { DietProfile } from '../model/dietProfile'
import { CalorieTargetService } from './CalorieTargetService'

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

/**
 * 按用户健康目标档案推导每日 DRI。
 * 热量/蛋白质/脂肪/碳水复用 CalorieTargetService（Mifflin-St Jeor + 活动系数 + 目标增减），
 * 纤维与钠沿用《中国居民膳食营养素参考摄入量（2023 版）》的成人推荐值。
 */
export function getDriForProfile(profile: DietProfile): DailyDRI {
  const t = CalorieTargetService.calcTargets(profile)
  return {
    calories: t.calories,
    protein: t.protein,
    fat: t.fat,
    carbs: t.carbs,
    fiber: profile.gender === 'male' ? 30 : 25,
    sodium: 2000,
  }
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

/** 缺少 totalWeight 时的兜底单份重量（克） */
const DEFAULT_DISH_WEIGHT_G: number = 400

/**
 * 将整份菜营养归一化到每 100g。
 * Ofcom 的评分阈值本就是 per 100g 口径，直接用整份数据评分会让所有菜挤在高分段，
 * 失去区分度（此前实测全库几乎都是 C/D）。
 */
function toPer100g(n: RecipeNutrition): RecipeNutrition {
  const w: number = (n.totalWeight !== undefined && n.totalWeight > 0)
    ? n.totalWeight
    : DEFAULT_DISH_WEIGHT_G
  const f: number = 100 / w
  return {
    calories: n.calories * f,
    protein: n.protein * f,
    fat: n.fat * f,
    carbs: n.carbs * f,
    fiber: n.fiber * f,
    sodium: n.sodium * f,
    totalWeight: 100,
  }
}

/**
 * 负面营养点（能量/脂肪/糖/钠），每项 0~10 分，按每 100g 口径计算。
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

  const per100 = toPer100g(n)
  const neg = calcNegativePoints(per100, hasVegTag)
  const pos = calcPositivePoints(per100, hasVegTag)
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
