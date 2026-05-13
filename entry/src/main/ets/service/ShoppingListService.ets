export interface ShoppingListResult {
  missingItems: string[]
  matchedItems: string[]
}

// Task3: 食材名称 → emoji 映射表（与 foodCatalog 数据对齐）
const INGREDIENT_EMOJI_MAP: Record<string, string> = {
  '土豆': '🥔', '马铃薯': '🥔', '番茄': '🍅', '西红柿': '🍅', '洋葱': '🧅',
  '包菜': '🥗', '白菜': '🥬', '胡萝卜': '🥕', '白萝卜': '🥣', '黄瓜': '🥒',
  '西葫芦': '🥒', '茄子': '🍆', '花菜': '🥦', '芹菜': '🥬', '莴笋': '🎍',
  '青椒': '🫑', '红椒': '🌶️', '菌菇': '🍄', '金针菇': '🍄', '木耳': '🍄‍🟫',
  '豆腐': '🍲', '豆皮': '🫔', '蒜薹': '🥬', '韭菜': '🥬',
  '猪肉': '🥩', '骨头': '🍖', '排骨': '🍖', '牛肉': '🥩', '羊肉': '🥩',
  '鸡肉': '🍗', '鱼肉': '🐟', '虾': '🦐', '虾仁': '🍤', '鸡蛋': '🥚',
  '腊肠': '🌭', '香肠': '🌭', '午餐肉': '🥓', '培根': '🥓',
  '米': '🍚', '米饭': '🍚', '面食': '🍜', '面条': '🍜', '方便面': '🍜',
  '粉丝': '🍜', '年糕': '🍡', '面包': '🍞', '吐司': '🍞',
  '葱': '🧅', '姜': '🫚', '蒜': '🧄', '辣椒': '🌶️', '花椒': '🫑',
  '盐': '🧂', '酱油': '🫗', '醋': '🫗', '料酒': '🫗', '糖': '🍬',
  '油': '🫗', '生抽': '🫗', '老抽': '🫗', '蚝油': '🫗', '豆瓣酱': '🫙',
  '淀粉': '🍚', '面粉': '🌾', '酵母': '🫧',
}

export class ShoppingListService {
  private static normalize(value: string): string {
    return value.trim().replace(/\s+/g, '').toLowerCase()
  }

  /** Task3: 根据食材名称获取对应 emoji，无匹配时返回默认值 */
  static getIngredientEmoji(name: string): string {
    return INGREDIENT_EMOJI_MAP[name] ?? '🥬'
  }

  /** Task3: 获取所有已知食材名称 */
  static getKnownIngredientNames(): string[] {
    return Object.keys(INGREDIENT_EMOJI_MAP)
  }

  private static isMatched(required: string, selected: string[]): boolean {
    const requiredNormalized = ShoppingListService.normalize(required)
    for (let i = 0; i < selected.length; i++) {
      const selectedNormalized = ShoppingListService.normalize(selected[i])
      if (selectedNormalized.length === 0) {
        continue
      }
      if (selectedNormalized === requiredNormalized) {
        return true
      }
      if (requiredNormalized.includes(selectedNormalized) || selectedNormalized.includes(requiredNormalized)) {
        return true
      }
    }
    return false
  }

  static diff(selectedStuff: string[], recipeStuff: string[]): ShoppingListResult {
    const missingItems: string[] = []
    const matchedItems: string[] = []

    for (let i = 0; i < recipeStuff.length; i++) {
      const item = recipeStuff[i]
      if (ShoppingListService.isMatched(item, selectedStuff)) {
        matchedItems.push(item)
      } else {
        missingItems.push(item)
      }
    }

    return {
      missingItems,
      matchedItems
    }
  }
}