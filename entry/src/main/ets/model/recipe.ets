/**
 * 食材匹配范围（三种）：
 * - 'loose'    全部相关（默认），菜谱用到任一已选食材即列出；
 * - 'strict'   都用上，菜谱必须包含全部已选食材；
 * - 'survival' 只看能做：主料齐备，调料按厨房常备处理。
 */
export type SearchMode = 'survival' | 'strict' | 'loose'

export type Difficulty = '简单' | '中等' | '较难'

/** 每道菜的营养成分（单份/整道菜） */
export interface RecipeNutrition {
  calories: number    // 千卡 kcal
  protein: number     // 克 g
  fat: number         // 克 g
  carbs: number       // 克 g
  fiber: number       // 克 g
  sodium: number      // 毫克 mg
  /**
   * 单份成品总重量（克）。Nutri-Score 按每 100g 口径评分时需要用它归一化；
   * 缺失时评分逻辑按 400g 兜底。
   */
  totalWeight?: number
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
  /**
   * 菜系分类（川菜/粤菜/湘菜…，普通家常菜为「家常菜」）。
   * 由 scripts/build_cuisine_tags.py 生成，用于卡片与详情的菜系标签。
   */
  cuisine?: string
  /** 保留 recipe.json 中的完整烹饪方式枚举，避免入库时被硬编码过滤 */
  methods?: string[]
  tools: string[]
  /**
   * 菜谱图片引用。随包图片存 rawfile 基础键（无扩展名，如 `howtocook-disanxian`），
   * 展示层按尺寸变体解析为 `recipe_images/{key}-{thumb|card|detail}.jpg`；
   * 远端图存 HTTPS URL，沙箱图存 `file://` 路径。
   */
  imageUri?: string
  /**
   * 食材用量表，键为食材名，值为用量字符串（如 "2个", "200克"）。
   * 主要用于人数换算功能；没有此字段的菜谱不展示换算。
   */
  stuffAmount?: Record<string, string>
  /** 营养信息（可选，用于 Nutri-Score 评分与今日营养统计） */
  nutrition?: RecipeNutrition
  /**
   * 营养数据是否由食材营养库聚合估算（true）。
   * 精选样例数据为 false/undefined，展示层据此决定是否标注「估算」。
   */
  nutritionEstimated?: boolean
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
