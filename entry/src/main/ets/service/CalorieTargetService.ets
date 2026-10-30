/**
 * 个性化热量目标计算
 *
 * 基础代谢：Mifflin-St Jeor 公式（男性 +5，女性 -161）
 *   男：10 × 体重(kg) + 6.25 × 身高(cm) − 5 × 年龄 + 5
 *   女：10 × 体重(kg) + 6.25 × 身高(cm) − 5 × 年龄 − 161
 * 每日消耗：基础代谢 × 活动系数（1.2 ~ 1.9）
 * 热量目标：按每周目标变化量换算（1 kg 脂肪 ≈ 7700 千卡），并设置安全下限。
 * 宏量分配：蛋白质按体重与目标取值，脂肪占总热量约 27%，碳水为剩余热量。
 */
import type { ActivityLevel, CalorieTargets, DietProfile } from '../model/dietProfile'

/** 1 kg 脂肪约等于 7700 千卡 */
const KCAL_PER_KG_FAT: number = 7700
/** 女性 / 男性每日摄入安全下限 */
const MIN_CALORIES_FEMALE: number = 1200
const MIN_CALORIES_MALE: number = 1500
/** 极端值保护 */
const MAX_CALORIES: number = 5000

export class CalorieTargetService {

  /** 活动水平 → TDEE 系数 */
  static activityFactor(level: ActivityLevel): number {
    switch (level) {
      case 'sedentary': return 1.2
      case 'light': return 1.375
      case 'moderate': return 1.55
      case 'active': return 1.725
      case 'veryActive': return 1.9
      default: return 1.375
    }
  }

  static calcBmr(p: DietProfile): number {
    const base: number = 10 * p.weightKg + 6.25 * p.heightCm - 5 * p.age
    return p.gender === 'male' ? base + 5 : base - 161
  }

  static calcTdee(p: DietProfile): number {
    return CalorieTargetService.calcBmr(p) * CalorieTargetService.activityFactor(p.activity)
  }

  static calcTargets(p: DietProfile): CalorieTargets {
    const bmr: number = Math.round(CalorieTargetService.calcBmr(p))
    const tdee: number = Math.round(CalorieTargetService.calcTdee(p))

    // 每周目标变化量换算到每天；保持体重时不做增减
    const dailyDelta: number = p.weeklyRateKg * KCAL_PER_KG_FAT / 7
    let calories: number = tdee
    if (p.goal === 'lose') {
      calories = tdee - dailyDelta
    } else if (p.goal === 'gain') {
      calories = tdee + dailyDelta
    }

    // 减脂不得低于安全下限，但下限本身高于消耗时以消耗为准（避免反向增重）
    const floor: number = p.gender === 'male' ? MIN_CALORIES_MALE : MIN_CALORIES_FEMALE
    if (p.goal === 'lose' && tdee > floor && calories < floor) {
      calories = floor
    }
    calories = Math.round(Math.max(0, Math.min(MAX_CALORIES, calories)))

    // 蛋白质：减脂期提高摄入以保留肌肉，增肌期略高于维持
    const proteinPerKg: number = p.goal === 'lose' ? 1.6 : (p.goal === 'gain' ? 1.8 : 1.2)
    let protein: number = Math.round(p.weightKg * proteinPerKg)
    // 蛋白质不超过总热量 35%
    const maxProtein: number = Math.round(calories * 0.35 / 4)
    protein = Math.max(0, Math.min(protein, maxProtein))

    // 脂肪约占总热量 27%，碳水补足剩余热量
    const fat: number = Math.round(calories * 0.27 / 9)
    let carbs: number = Math.round((calories - protein * 4 - fat * 9) / 4)
    if (carbs < 0) {
      carbs = 0
    }

    return { bmr, tdee, calories, protein, fat, carbs }
  }
}
