import { ShoppingCategory, IngredientTypeMapper } from '../utils/IngredientTypeMapper'
import { hasIngredient } from './IngredientMatchService'
import { findIngredientEmoji, isCatalogIngredientAvailable } from '../data/foodCatalog'

// ── 接口定义 ──────────────────────────────────────────────────────────────────

export interface MissingItem {
  name: string
  amount: string
  category: ShoppingCategory
  emoji: string
}

export interface ShoppingListResult {
  missingItems: MissingItem[]
  matchedItems: string[]
  totalStuff: number
}

// ── 食材名称 → emoji 映射表（与 foodCatalog 数据对齐）──────────────────────────

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
  // 食材库中部分抽象色块 emoji 替换为可辨识的实物
  '腐竹': '🧈', '紫甘蓝': '🥬', '百香果': '🍈', '红枣': '🌰',
  '紫菜': '🌿', '海带': '🌿', '蒜苔': '🥬',
  '扁豆': '🌱', '四季豆': '🌱', '荷兰豆': '🌱', '毛豆': '🌱',
  '青豆': '🌱', '豆角': '🌱', '干豆角': '🌱',
}

// ── 名称关键词 → emoji 兜底规则（顺序即优先级）──────────────────────────────

interface EmojiRule {
  key: string
  emoji: string
}

const EMOJI_RULES: EmojiRule[] = [
  { key: '排骨', emoji: '🍖' }, { key: '肋排', emoji: '🍖' }, { key: '骨头', emoji: '🍖' },
  { key: '培根', emoji: '🥓' }, { key: '腊肉', emoji: '🥓' },
  { key: '腊肠', emoji: '🌭' }, { key: '香肠', emoji: '🌭' }, { key: '火腿', emoji: '🍖' },
  { key: '鸡', emoji: '🍗' }, { key: '鸭', emoji: '🦆' }, { key: '鹅', emoji: '🍗' },
  { key: '羊', emoji: '🥩' }, { key: '牛', emoji: '🥩' }, { key: '猪', emoji: '🥩' },
  { key: '肉', emoji: '🥩' },
  { key: '鱼', emoji: '🐟' }, { key: '虾', emoji: '🦐' }, { key: '蟹', emoji: '🦀' },
  { key: '贝', emoji: '🐚' }, { key: '蛤', emoji: '🐚' }, { key: '蚝', emoji: '🦪' },
  { key: '螺', emoji: '🐚' }, { key: '蛏', emoji: '🐚' },
  { key: '鱿', emoji: '🦑' }, { key: '墨鱼', emoji: '🦑' }, { key: '章鱼', emoji: '🦑' },
  { key: '蛋', emoji: '🥚' }, { key: '奶', emoji: '🥛' },
  { key: '菇', emoji: '🍄' }, { key: '菌', emoji: '🍄' },
  { key: '菜', emoji: '🥬' }, { key: '苗', emoji: '🌱' }, { key: '苔', emoji: '🥬' },
  { key: '瓜', emoji: '🥒' }, { key: '萝卜', emoji: '🥕' }, { key: '薯', emoji: '🍠' },
  { key: '芋', emoji: '🍠' }, { key: '山药', emoji: '🍠' }, { key: '笋', emoji: '🎋' },
  { key: '茄', emoji: '🍆' }, { key: '玉米', emoji: '🌽' }, { key: '藕', emoji: '🪷' },
  { key: '豆', emoji: '🫘' }, { key: '辣椒', emoji: '🌶️' }, { key: '椒', emoji: '🫑' },
  { key: '番茄', emoji: '🍅' }, { key: '西红柿', emoji: '🍅' }, { key: '柠檬', emoji: '🍋' },
  { key: '葱', emoji: '🧅' }, { key: '姜', emoji: '🫚' }, { key: '蒜', emoji: '🧄' },
  { key: '面', emoji: '🍜' }, { key: '粉', emoji: '🍜' }, { key: '米', emoji: '🍚' },
  { key: '饭', emoji: '🍚' }, { key: '包', emoji: '🍞' }, { key: '吐司', emoji: '🍞' },
  { key: '饺', emoji: '🥟' }, { key: '馄饨', emoji: '🥟' },
  { key: '盐', emoji: '🧂' }, { key: '糖', emoji: '🍬' },
  { key: '油', emoji: '🫗' }, { key: '酱', emoji: '🫗' }, { key: '醋', emoji: '🫗' },
  { key: '酒', emoji: '🫗' }
]

export class ShoppingListService {
  /**
   * 根据食材名称获取 emoji：静态表 → 食材库 → 关键词 → 分类兜底。
   * 兜底必须按分类给图标，避免肉被统一画成 🥬。
   */
  static getIngredientEmoji(name: string): string {
    const exact = INGREDIENT_EMOJI_MAP[name]
    if (exact !== undefined) return exact
    const inCatalog = findIngredientEmoji(name)
    if (inCatalog !== undefined) return inCatalog
    for (let i = 0; i < EMOJI_RULES.length; i++) {
      if (name.includes(EMOJI_RULES[i].key)) {
        return EMOJI_RULES[i].emoji
      }
    }
    return ShoppingListService.getCategoryEmojiFallback(IngredientTypeMapper.getShoppingCategory(name))
  }

  private static getCategoryEmojiFallback(cat: ShoppingCategory): string {
    switch (cat) {
      case ShoppingCategory.MEAT: return '🍖'
      case ShoppingCategory.VEG: return '🥬'
      case ShoppingCategory.STAPLE: return '🍚'
      case ShoppingCategory.SEASONING: return '🧂'
      default: return '🛒'
    }
  }

  /** Task3: 获取所有已知食材名称 */
  static getKnownIngredientNames(): string[] {
    return Object.keys(INGREDIENT_EMOJI_MAP)
  }

  /**
   * 冰箱里是否有该食材：先按等价名精确判断，再按选料目录归一化判断。
   * 后者保证菜谱里的细分别名（猪五花肉 → 五花肉）也能对上冰箱里选的食材。
   */
  private static inFridge(ingredient: string, selectedStuff: string[]): boolean {
    return hasIngredient(ingredient, selectedStuff) ||
      isCatalogIngredientAvailable(ingredient, selectedStuff)
  }

  static diff(selectedStuff: string[], recipeStuff: string[], stuffAmount?: Record<string, string>): ShoppingListResult {
    const missingItems: MissingItem[] = []
    const matchedItems: string[] = []
    const amountMap = stuffAmount ?? {}

    for (let i = 0; i < recipeStuff.length; i++) {
      const item = recipeStuff[i]
      if (ShoppingListService.inFridge(item, selectedStuff)) {
        matchedItems.push(item)
      } else {
        missingItems.push({
          name: item,
          amount: amountMap[item] ?? '',
          category: IngredientTypeMapper.getShoppingCategory(item),
          emoji: ShoppingListService.getIngredientEmoji(item)
        })
      }
    }

    return {
      missingItems,
      matchedItems,
      totalStuff: recipeStuff.length
    }
  }
}
