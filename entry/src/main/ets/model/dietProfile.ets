/** 个性化健康目标 —— 用于按身高 / 体重 / 目标推算每日热量与三大营养素 */

export type Gender = 'male' | 'female'

/** 活动水平（对应 TDEE 系数 1.2 / 1.375 / 1.55 / 1.725 / 1.9） */
export type ActivityLevel = 'sedentary' | 'light' | 'moderate' | 'active' | 'veryActive'

/** 目标类型：减脂 / 保持 / 增肌 */
export type GoalType = 'lose' | 'maintain' | 'gain'

export interface DietProfile {
  gender: Gender
  age: number
  heightCm: number
  weightKg: number
  activity: ActivityLevel
  goal: GoalType
  /** 目标速度（kg/周）；goal 为 maintain 时不参与计算 */
  weeklyRateKg: number
}

/** 由个人资料推导出的每日目标 */
export interface CalorieTargets {
  /** 基础代谢（千卡） */
  bmr: number
  /** 每日总消耗（千卡） */
  tdee: number
  /** 每日热量目标（千卡） */
  calories: number
  /** 蛋白质目标（克） */
  protein: number
  /** 脂肪目标（克） */
  fat: number
  /** 碳水目标（克） */
  carbs: number
}

/** 首次使用时的默认档案：保持体重，结果接近常见 1800~2000 千卡区间 */
export const DEFAULT_DIET_PROFILE: DietProfile = {
  gender: 'female',
  age: 28,
  heightCm: 163,
  weightKg: 58,
  activity: 'light',
  goal: 'maintain',
  weeklyRateKg: 0.5
}
