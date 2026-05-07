/**
 * 热量计算工具类
 * 内置 60+ 种常见食物的营养数据，支持本地查询、模糊匹配与份量换算。
 * 数据来源：《中国食物成分表（第6版）》，每 100g 可食部分计。
 */

/** 每 100g 可食部分的营养素含量 */
export interface NutrientData {
  /** 热量（千卡） */
  calories: number
  /** 蛋白质（g） */
  protein: number
  /** 脂肪（g） */
  fat: number
  /** 碳水化合物（g） */
  carbs: number
  /** 默认单份重量（g），用于份量换算 */
  servingWeight: number
}

/** 识别+计算后的食物营养结果 */
export interface FoodNutrition {
  foodName: string
  quantity: number
  unit: string
  /** 总热量（千卡） */
  totalCalories: number
  /** 总蛋白质（g） */
  totalProtein: number
  /** 总脂肪（g） */
  totalFat: number
  /** 总碳水（g） */
  totalCarbs: number
  /** 来源：'local' = 本地库，'cloud' = 云端，'manual' = 手动输入 */
  source: 'local' | 'cloud' | 'manual'
}

export class CalorieCalculator {
  /**
   * 本地营养数据库（60+ 种常见中国食材与菜肴）
   * Key：食物标准名称（中文）
   */
  private static readonly DB: Map<string, NutrientData> = new Map<string, NutrientData>([
    // ── 主食与谷物 ───────────────────────────────────────────────────
    ['米饭',    { calories: 116, protein: 2.6,  fat: 0.3,  carbs: 25.6, servingWeight: 200 }],
    ['糙米饭',  { calories: 111, protein: 2.8,  fat: 0.9,  carbs: 22.8, servingWeight: 200 }],
    ['面条',    { calories: 137, protein: 4.8,  fat: 0.7,  carbs: 28.2, servingWeight: 200 }],
    ['馒头',    { calories: 221, protein: 7.0,  fat: 1.1,  carbs: 47.0, servingWeight: 100 }],
    ['白粥',    { calories:  46, protein: 1.1,  fat: 0.3,  carbs:  9.8, servingWeight: 250 }],
    ['包子',    { calories: 236, protein: 8.0,  fat: 5.6,  carbs: 38.0, servingWeight: 100 }],
    ['饺子',    { calories: 239, protein: 9.5,  fat: 6.3,  carbs: 35.5, servingWeight: 150 }],
    ['面包',    { calories: 265, protein: 8.3,  fat: 3.2,  carbs: 51.5, servingWeight: 100 }],
    ['玉米',    { calories: 112, protein: 4.0,  fat: 1.2,  carbs: 22.8, servingWeight: 150 }],
    ['燕麦',    { calories: 389, protein: 16.9, fat: 6.9,  carbs: 66.3, servingWeight:  80 }],
    ['红薯',    { calories:  86, protein: 1.6,  fat: 0.2,  carbs: 19.7, servingWeight: 150 }],
    ['土豆',    { calories:  77, protein: 2.0,  fat: 0.2,  carbs: 17.2, servingWeight: 200 }],
    // ── 肉禽蛋水产 ───────────────────────────────────────────────────
    ['猪肉',    { calories: 143, protein: 20.3, fat:  6.2, carbs:  1.5, servingWeight: 100 }],
    ['猪排骨',  { calories: 278, protein: 18.3, fat: 22.6, carbs:  0.0, servingWeight: 150 }],
    ['猪肝',    { calories: 129, protein: 19.3, fat:  3.5, carbs:  5.0, servingWeight: 100 }],
    ['牛肉',    { calories: 106, protein: 20.2, fat:  2.3, carbs:  1.2, servingWeight: 100 }],
    ['羊肉',    { calories: 203, protein: 19.0, fat: 14.0, carbs:  0.0, servingWeight: 100 }],
    ['鸡胸肉',  { calories: 133, protein: 19.4, fat:  5.0, carbs:  2.5, servingWeight: 150 }],
    ['鸡腿',    { calories: 181, protein: 16.0, fat: 11.6, carbs:  3.0, servingWeight: 150 }],
    ['鸡翅',    { calories: 240, protein: 17.4, fat: 19.0, carbs:  0.0, servingWeight: 100 }],
    ['三文鱼',  { calories: 208, protein: 20.0, fat: 13.0, carbs:  0.0, servingWeight: 150 }],
    ['草鱼',    { calories: 113, protein: 16.6, fat:  5.2, carbs:  0.0, servingWeight: 150 }],
    ['对虾',    { calories:  93, protein: 18.6, fat:  0.8, carbs:  2.8, servingWeight: 100 }],
    ['螃蟹',    { calories: 103, protein: 17.5, fat:  2.6, carbs:  2.3, servingWeight: 150 }],
    ['鸡蛋',    { calories: 144, protein: 13.3, fat:  8.8, carbs:  2.8, servingWeight:  60 }],
    // ── 蔬菜 ─────────────────────────────────────────────────────────
    ['西红柿',  { calories:  19, protein: 0.9,  fat: 0.2,  carbs:  4.0, servingWeight: 200 }],
    ['番茄',    { calories:  19, protein: 0.9,  fat: 0.2,  carbs:  4.0, servingWeight: 200 }],
    ['黄瓜',    { calories:  15, protein: 0.8,  fat: 0.2,  carbs:  2.9, servingWeight: 200 }],
    ['白菜',    { calories:  17, protein: 1.5,  fat: 0.1,  carbs:  3.2, servingWeight: 200 }],
    ['菠菜',    { calories:  28, protein: 2.6,  fat: 0.3,  carbs:  4.5, servingWeight: 200 }],
    ['胡萝卜',  { calories:  37, protein: 1.0,  fat: 0.2,  carbs:  8.8, servingWeight: 100 }],
    ['茄子',    { calories:  21, protein: 1.1,  fat: 0.2,  carbs:  4.9, servingWeight: 200 }],
    ['豆腐',    { calories:  76, protein: 8.1,  fat: 3.7,  carbs:  4.2, servingWeight: 150 }],
    ['木耳',    { calories:  21, protein: 1.5,  fat: 0.2,  carbs:  5.3, servingWeight: 100 }],
    ['香菇',    { calories:  19, protein: 2.2,  fat: 0.3,  carbs:  5.2, servingWeight: 100 }],
    ['洋葱',    { calories:  40, protein: 1.1,  fat: 0.2,  carbs:  9.0, servingWeight: 100 }],
    ['青椒',    { calories:  23, protein: 1.0,  fat: 0.2,  carbs:  5.5, servingWeight: 100 }],
    ['豆芽',    { calories:  18, protein: 2.1,  fat: 0.1,  carbs:  3.8, servingWeight: 100 }],
    ['西兰花',  { calories:  33, protein: 4.2,  fat: 0.6,  carbs:  6.6, servingWeight: 200 }],
    ['冬瓜',    { calories:  10, protein: 0.4,  fat: 0.2,  carbs:  2.6, servingWeight: 300 }],
    ['芹菜',    { calories:  14, protein: 0.6,  fat: 0.1,  carbs:  3.3, servingWeight: 150 }],
    // ── 水果 ─────────────────────────────────────────────────────────
    ['苹果',    { calories:  52, protein: 0.3,  fat: 0.2,  carbs: 13.8, servingWeight: 200 }],
    ['香蕉',    { calories:  89, protein: 1.1,  fat: 0.3,  carbs: 22.8, servingWeight: 120 }],
    ['橙子',    { calories:  47, protein: 0.9,  fat: 0.1,  carbs: 11.8, servingWeight: 200 }],
    ['葡萄',    { calories:  67, protein: 0.6,  fat: 0.4,  carbs: 17.2, servingWeight: 200 }],
    ['西瓜',    { calories:  30, protein: 0.6,  fat: 0.3,  carbs:  7.6, servingWeight: 300 }],
    // ── 乳制品与豆制品 ───────────────────────────────────────────────
    ['牛奶',    { calories:  65, protein: 3.3,  fat: 3.6,  carbs:  4.8, servingWeight: 250 }],
    ['酸奶',    { calories:  72, protein: 2.5,  fat: 2.7,  carbs:  9.3, servingWeight: 200 }],
    ['豆浆',    { calories:  33, protein: 3.0,  fat: 1.6,  carbs:  2.0, servingWeight: 300 }],
    // ── 常见家常菜 ───────────────────────────────────────────────────
    ['番茄炒蛋', { calories: 120, protein: 7.2, fat: 7.3,  carbs:  6.8, servingWeight: 200 }],
    ['西红柿炒鸡蛋', { calories: 120, protein: 7.2, fat: 7.3, carbs: 6.8, servingWeight: 200 }],
    ['红烧肉',  { calories: 508, protein: 7.7,  fat: 50.6, carbs:  7.5, servingWeight: 150 }],
    ['麻婆豆腐', { calories:  95, protein: 6.0, fat: 6.2,  carbs:  4.5, servingWeight: 200 }],
    ['蒸蛋',    { calories:  65, protein: 7.5,  fat: 3.4,  carbs:  2.0, servingWeight: 150 }],
    ['水煮鱼',  { calories: 150, protein: 15.0, fat: 8.5,  carbs:  3.0, servingWeight: 300 }],
    ['宫保鸡丁', { calories: 180, protein: 14.0, fat: 9.5, carbs:  8.0, servingWeight: 200 }],
    ['炒青菜',  { calories:  45, protein: 2.0,  fat: 2.5,  carbs:  5.0, servingWeight: 200 }],
    ['蛋炒饭',  { calories: 200, protein: 5.5,  fat: 6.0,  carbs: 31.0, servingWeight: 250 }],
    ['糖醋里脊', { calories: 260, protein: 12.0, fat: 12.0, carbs: 27.0, servingWeight: 200 }],
    ['清蒸鱼',  { calories: 100, protein: 18.0, fat: 2.5,  carbs:  0.0, servingWeight: 300 }],
    ['回锅肉',  { calories: 395, protein: 12.0, fat: 37.0, carbs:  5.0, servingWeight: 150 }],
    ['拌黄瓜',  { calories:  25, protein: 0.8,  fat: 0.5,  carbs:  4.5, servingWeight: 200 }],
    ['酸辣土豆丝', { calories: 80, protein: 1.8, fat: 2.5, carbs: 14.0, servingWeight: 200 }],
    // ── 坚果零食 ─────────────────────────────────────────────────────
    ['花生',    { calories: 567, protein: 25.8, fat: 49.2, carbs: 16.1, servingWeight:  30 }],
    ['腰果',    { calories: 553, protein: 18.2, fat: 43.8, carbs: 30.2, servingWeight:  30 }],
    ['核桃',    { calories: 654, protein: 15.2, fat: 65.2, carbs: 13.7, servingWeight:  20 }],
    ['白砂糖',  { calories: 400, protein:  0.0, fat:  0.0, carbs: 100.0, servingWeight: 10 }],
  ])

  /** 查询食物营养数据（精确匹配）。查不到返回 null。 */
  static lookup(foodName: string): NutrientData | null {
    return CalorieCalculator.DB.get(foodName) ?? null
  }

  /**
   * 模糊匹配：从候选名称列表中找最接近的食物。
   * 先尝试"候选项是否包含数据库 key"或"数据库 key 是否包含候选项"；
   * 再用字符级 Jaccard 相似度降序排列，取得分 > 0.3 的最高项。
   * @param candidates 端侧或云端返回的候选名称（中英文均可）
   * @returns 匹配到的食物名 + 数据，或 null
   */
  static fuzzyMatch(candidates: string[]): { name: string; data: NutrientData } | null {
    let bestName: string = ''
    let bestScore: number = 0
    let bestData: NutrientData | null = null

    const dbKeys = Array.from(CalorieCalculator.DB.keys())

    for (const candidate of candidates) {
      const c = candidate.trim()
      if (c.length === 0) continue

      for (const key of dbKeys) {
        // 直接包含优先
        if (c.includes(key) || key.includes(c)) {
          const data = CalorieCalculator.DB.get(key)
          if (data !== undefined) {
            return { name: key, data }
          }
        }
        // Jaccard 字符集相似度
        const score = CalorieCalculator.jaccardSimilarity(c, key)
        if (score > bestScore) {
          bestScore = score
          bestName = key
          bestData = CalorieCalculator.DB.get(key) ?? null
        }
      }
    }

    if (bestScore >= 0.3 && bestData !== null) {
      return { name: bestName, data: bestData }
    }
    return null
  }

  /**
   * 按份量计算总营养素。
   * @param data   每 100g 营养数据
   * @param quantity  份数（如 1.5 份）
   * @param servingWeightOverride  可选：覆盖默认单份重量（g）
   */
  static calcByQuantity(
    data: NutrientData,
    quantity: number,
    servingWeightOverride?: number
  ): Pick<FoodNutrition, 'totalCalories' | 'totalProtein' | 'totalFat' | 'totalCarbs'> {
    const grams = (servingWeightOverride ?? data.servingWeight) * quantity
    const factor = grams / 100.0
    return {
      totalCalories: Math.round(data.calories * factor),
      totalProtein:  Math.round(data.protein  * factor * 10) / 10,
      totalFat:      Math.round(data.fat       * factor * 10) / 10,
      totalCarbs:    Math.round(data.carbs     * factor * 10) / 10,
    }
  }

  /** 返回数据库中所有食物名称列表（供 UI 手动选择用） */
  static getAllFoodNames(): string[] {
    return Array.from(CalorieCalculator.DB.keys())
  }

  // ── 内部：Jaccard 字符集相似度 ──────────────────────────────────────

  private static jaccardSimilarity(a: string, b: string): number {
    const setA = new Set<string>(a.split(''))
    const setB = new Set<string>(b.split(''))
    let intersection = 0
    setA.forEach((ch: string) => {
      if (setB.has(ch)) intersection++
    })
    const union = setA.size + setB.size - intersection
    return union === 0 ? 0 : intersection / union
  }
}
