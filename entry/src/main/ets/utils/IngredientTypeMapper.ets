/**
 * 食材类型映射工具 - 将食材名称映射到对应的视觉类型和购物分类
 * 用于 IngredientTag 组件的颜色主题 和 购物清单的分类分组
 */
import { TagType } from '../components/IngredientTag'

// ── 购物清单分类枚举 ──────────────────────────────────────────────────────

export enum ShoppingCategory {
  MEAT = 'meat',
  VEG = 'veg',
  STAPLE = 'staple',
  SEASONING = 'seasoning',
  OTHER = 'other'
}

// ── 分类颜色配置（浅色 / 深色）───────────────────────────────────────────

export interface CategoryColors {
  bg: string
  text: string
  bgDark: string
  textDark: string
}

const CATEGORY_COLORS: Record<ShoppingCategory, CategoryColors> = {
  [ShoppingCategory.MEAT]:    { bg: '#FEF2F2', text: '#DC2626', bgDark: '#2A1A1A', textDark: '#FF6B6B' },
  [ShoppingCategory.VEG]:     { bg: '#F0FDF4', text: '#16A34A', bgDark: '#1A2A1A', textDark: '#4ADE80' },
  [ShoppingCategory.STAPLE]:  { bg: '#FFFBEB', text: '#D97706', bgDark: '#2A2A1A', textDark: '#FBBF24' },
  [ShoppingCategory.SEASONING]: { bg: '#FFF7ED', text: '#EA580C', bgDark: '#2A2018', textDark: '#FB923C' },
  [ShoppingCategory.OTHER]:   { bg: '#F9FAFB', text: '#6B7280', bgDark: '#252525', textDark: '#9CA3AF' }
}

// ── 购物分类完整映射表（覆盖 ShoppingListService 中所有 emoji 映射食材）───

const CATEGORY_MAP: Record<string, ShoppingCategory> = {
  // 肉类/蛋白质
  '猪肉': ShoppingCategory.MEAT, '骨头': ShoppingCategory.MEAT, '排骨': ShoppingCategory.MEAT,
  '牛肉': ShoppingCategory.MEAT, '羊肉': ShoppingCategory.MEAT, '鸡肉': ShoppingCategory.MEAT,
  '鸡胸肉': ShoppingCategory.MEAT, '鱼肉': ShoppingCategory.MEAT, '鱼': ShoppingCategory.MEAT,
  '鱼（Todo）': ShoppingCategory.MEAT, '虾': ShoppingCategory.MEAT, '虾仁': ShoppingCategory.MEAT,
  '鲜虾': ShoppingCategory.MEAT, '鸡蛋': ShoppingCategory.MEAT, '腊肠': ShoppingCategory.MEAT,
  '香肠': ShoppingCategory.MEAT, '午餐肉': ShoppingCategory.MEAT, '培根': ShoppingCategory.MEAT,

  // 蔬菜/菌菇
  '土豆': ShoppingCategory.VEG, '马铃薯': ShoppingCategory.VEG, '番茄': ShoppingCategory.VEG,
  '西红柿': ShoppingCategory.VEG, '洋葱': ShoppingCategory.VEG, '包菜': ShoppingCategory.VEG,
  '白菜': ShoppingCategory.VEG, '胡萝卜': ShoppingCategory.VEG, '白萝卜': ShoppingCategory.VEG,
  '黄瓜': ShoppingCategory.VEG, '西葫芦': ShoppingCategory.VEG, '茄子': ShoppingCategory.VEG,
  '花菜': ShoppingCategory.VEG, '芹菜': ShoppingCategory.VEG, '莴笋': ShoppingCategory.VEG,
  '青椒': ShoppingCategory.VEG, '红椒': ShoppingCategory.VEG, '菌菇': ShoppingCategory.VEG,
  '金针菇': ShoppingCategory.VEG, '木耳': ShoppingCategory.VEG, '蒜薹': ShoppingCategory.VEG,
  '韭菜': ShoppingCategory.VEG,

  // 主食/豆制品
  '米': ShoppingCategory.STAPLE, '米饭': ShoppingCategory.STAPLE, '面食': ShoppingCategory.STAPLE,
  '面条': ShoppingCategory.STAPLE, '方便面': ShoppingCategory.STAPLE, '粉丝': ShoppingCategory.STAPLE,
  '年糕': ShoppingCategory.STAPLE, '面包': ShoppingCategory.STAPLE, '吐司': ShoppingCategory.STAPLE,
  '豆腐': ShoppingCategory.STAPLE, '豆皮': ShoppingCategory.STAPLE, '面粉': ShoppingCategory.STAPLE,
  '淀粉': ShoppingCategory.STAPLE,

  // 调料/香料
  '葱': ShoppingCategory.SEASONING, '姜': ShoppingCategory.SEASONING, '蒜': ShoppingCategory.SEASONING,
  '辣椒': ShoppingCategory.SEASONING, '花椒': ShoppingCategory.SEASONING, '盐': ShoppingCategory.SEASONING,
  '酱油': ShoppingCategory.SEASONING, '醋': ShoppingCategory.SEASONING, '料酒': ShoppingCategory.SEASONING,
  '糖': ShoppingCategory.SEASONING, '油': ShoppingCategory.SEASONING, '生抽': ShoppingCategory.SEASONING,
  '老抽': ShoppingCategory.SEASONING, '蚝油': ShoppingCategory.SEASONING, '豆瓣酱': ShoppingCategory.SEASONING,
  '酵母': ShoppingCategory.SEASONING
}

export class IngredientTypeMapper {
  /**
   * 肉类食材名称集合
   */
  private static readonly MEAT_SET: Set<string> = new Set([
    '午餐肉', '香肠', '腊肠', '鸡肉', '猪肉', '鸡蛋', '虾', '牛肉', '骨头', '鱼', '鱼（Todo）',
    '排骨', '鸡胸肉', '鲜虾' // 原型中的额外肉类
  ])

  /**
   * 碳水/主食类食材名称集合
   */
  private static readonly CARB_SET: Set<string> = new Set([
    '面食', '面包', '米', '方便面',
    '豆腐', '面条', '米饭' // 原型中的额外碳水
  ])

  /**
   * 根据食材名称返回对应的 TagType
   * @param name 食材名称
   * @returns TagType 枚举值
   */
  static getTagType(name: string): TagType {
    if (IngredientTypeMapper.MEAT_SET.has(name)) {
      return TagType.MEAT
    }
    if (IngredientTypeMapper.CARB_SET.has(name)) {
      return TagType.CARB
    }
    // 默认为蔬菜类型(绿色)
    return TagType.VEG
  }

  /**
   * 判断食材是否为厨具(厨具不参与颜色分类)
   * @param name 食材/厨具名称
   * @returns 是否为厨具
   */
  static isTool(name: string): boolean {
    const toolSet = new Set(['烤箱', '空气炸锅', '微波炉', '电饭煲', '一口大锅'])
    return toolSet.has(name)
  }

  // ── 购物清单分类方法 ─────────────────────────────────────────────────

  /** 获取食材的购物分类 */
  static getShoppingCategory(name: string): ShoppingCategory {
    return CATEGORY_MAP[name] ?? ShoppingCategory.OTHER
  }

  /** 获取分类的中文标签 */
  static getCategoryLabel(cat: ShoppingCategory): string {
    switch (cat) {
      case ShoppingCategory.MEAT: return '肉类'
      case ShoppingCategory.VEG: return '蔬菜'
      case ShoppingCategory.STAPLE: return '主食'
      case ShoppingCategory.SEASONING: return '调料'
      default: return '其他'
    }
  }

  /** 获取分类的颜色配置 */
  static getCategoryColors(cat: ShoppingCategory): CategoryColors {
    return CATEGORY_COLORS[cat] ?? CATEGORY_COLORS[ShoppingCategory.OTHER]
  }

  /** 获取分类的 emoji 图标 */
  static getCategoryEmoji(cat: ShoppingCategory): string {
    switch (cat) {
      case ShoppingCategory.MEAT: return '🥩'
      case ShoppingCategory.VEG: return '🥬'
      case ShoppingCategory.STAPLE: return '🍚'
      case ShoppingCategory.SEASONING: return '🧂'
      default: return '📦'
    }
  }

  /** 购物分类的展示顺序 */
  static readonly CATEGORY_ORDER: ShoppingCategory[] = [
    ShoppingCategory.MEAT,
    ShoppingCategory.VEG,
    ShoppingCategory.STAPLE,
    ShoppingCategory.SEASONING,
    ShoppingCategory.OTHER
  ]
}
