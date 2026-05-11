/** 与 Web `useRecipeStore` 一致：生存 / 模糊 / 严格 */
export type SearchMode = 'survival' | 'loose' | 'strict'

export type Difficulty = '简单' | '普通' | '困难'

/** 每道菜的营养成分（单份/整道菜） */
export interface RecipeNutrition {
  calories: number    // 千卡 kcal
  protein: number     // 克 g
  fat: number         // 克 g
  carbs: number       // 克 g
  fiber: number       // 克 g
  sodium: number      // 毫克 mg
}

/** Nutri-Score 等级 A~E */
export type NutriScore = 'A' | 'B' | 'C' | 'D' | 'E'

export interface RecipeItem {
  name: string
  stuff: string[]
  /** 制作步骤纯文本，可为空数组 */
  steps?: string[]
  emojis?: string[]
  difficulty?: Difficulty | ''
  tags?: string[]
  /** 保留 recipe.json 中的完整烹饪方式枚举，避免入库时被硬编码过滤 */
  methods?: string[]
  tools: string[]
  /** 菜谱图片 URI */
  imageUri?: string
  /**
   * 食材用量表，键为食材名，值为用量字符串（如 "2个", "200克"）。
   * 主要用于人数换算功能；没有此字段的菜谱不展示换算。
   */
  stuffAmount?: Record<string, string>
  /** 营养信息（可选，用于 Nutri-Score 评分与今日营养统计） */
  nutrition?: RecipeNutrition
}

export type Recipes = RecipeItem[]

/** 与 Web 端 Dexie 一致：数组下标作为稳定 id，供收藏/历史引用 */
export interface RecipeWithId extends RecipeItem {
  id: number
}

export interface StuffItem {
  name: string
  emoji: string
  image?: string
  alias?: string
  icon?: string
  label?: string
}
