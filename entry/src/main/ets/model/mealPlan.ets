/** 「从一道菜到一餐」套餐相关类型 */

/** 菜品荤素分类（从 stuff 启发式推导） */
export type DishType = '荤' | '素' | '主食'

/** 荤素比约束 */
export type MeatRatio = '均衡' | '偏素' | '偏荤'

/** 一餐套餐（持久化结构） */
export interface MealPlan {
  people: number
  meatRatio: MeatRatio
  /** 可用厨具约束（空数组 = 无约束） */
  tools: string[]
  /** 按槽位顺序的菜谱 id */
  dishIds: number[]
  /** 与 dishIds 对齐的锁定标记 */
  locked: boolean[]
  updatedAt: number
}
