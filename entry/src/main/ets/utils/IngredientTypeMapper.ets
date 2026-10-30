/**
 * 食材类型映射工具 - 将食材名称映射到对应的视觉类型和购物分类
 * 用于 IngredientTag 组件的颜色主题 和 购物清单的分类分组
 */
import { TagType } from '../model/ingredient'
import type { StuffItem } from '../model/recipe'
import { meatItems, vegetableItems, stapleItems } from '../data/foodCatalog'

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

// ── 全库成员集合：静态映射表未覆盖时，用食材库兜底分类 ──────────────────

const CATALOG_MEAT: Set<string> = new Set(meatItems.map((it: StuffItem) => it.name))
const CATALOG_VEG: Set<string> = new Set(vegetableItems.map((it: StuffItem) => it.name))
const CATALOG_STAPLE: Set<string> = new Set(stapleItems.map((it: StuffItem) => it.name))

// ── 关键词兜底规则（顺序即优先级）────────────────────────────────────────

const CATEGORY_KEYWORDS: Record<ShoppingCategory, string[]> = {
  [ShoppingCategory.MEAT]: [
    '肉', '排骨', '骨', '鸡', '鸭', '鹅', '鱼', '虾', '蟹', '贝', '蛤', '蚝',
    '螺', '蛏', '鱿', '墨鱼', '章鱼', '肠', '火腿', '培根', '肚', '蹄', '翅',
    '肝', '腰', '舌', '筋', '血'
  ],
  [ShoppingCategory.VEG]: [
    '菜', '瓜', '菇', '菌', '笋', '茄', '萝卜', '薯', '芋', '藕', '豆', '苗',
    '苔', '蒿', '椒', '兰', '玉米', '番茄', '西红柿', '柠檬', '果'
  ],
  [ShoppingCategory.STAPLE]: ['面', '粉', '米', '饭', '吐司', '面包', '饺', '馄饨', '年糕'],
  [ShoppingCategory.SEASONING]: [
    '盐', '糖', '油', '酱', '醋', '酒', '椒粉', '香料', '八角', '桂皮', '孜然',
    '味精', '鸡精', '蜂蜜', '葱', '姜', '蒜', '十三香', '五香', '咖喱'
  ],
  [ShoppingCategory.OTHER]: []
}

function containsAny(name: string, keys: string[]): boolean {
  for (let i = 0; i < keys.length; i++) {
    if (name.includes(keys[i])) return true
  }
  return false
}

/**
 * 「厨房常备」辅料关键词：调料、香料、干制增香物与水/高汤。
 * 评估「现在能做」时视为现成可用，不要求出现在冰箱选料里。
 * 面粉、面包糠等会决定菜能否成立的原料不在此列。
 */
const PANTRY_KEYWORDS: string[] = [
  '淀粉', '酵母', '泡打粉', '小苏打',
  '胡椒', '花椒', '孜然', '香叶', '八角', '桂皮', '五香', '十三香', '咖喱',
  '豆豉', '腐乳', '泡椒', '剁椒',
  '枸杞', '芝麻', '党参', '当归', '黄芪', '高汤', '温水'
]

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

  /**
   * 是否为「厨房常备」的调料/辅料。
   * 用于「只看能做」筛选：菜谱里的葱姜蒜、生抽、香料等默认家里有，
   * 不因冰箱选料里无法勾选这些项，就把整道菜判为「做不了」。
   */
  static isPantryItem(name: string): boolean {
    if (IngredientTypeMapper.getShoppingCategory(name) === ShoppingCategory.SEASONING) {
      return true
    }
    return containsAny(name, PANTRY_KEYWORDS)
  }

  /** 获取食材的购物分类：静态表 → 食材库 → 关键词兜底，尽量避免「肉菜混在其它」 */
  static getShoppingCategory(name: string): ShoppingCategory {
    const mapped = CATEGORY_MAP[name]
    if (mapped !== undefined) return mapped
    if (CATALOG_MEAT.has(name)) return ShoppingCategory.MEAT
    if (CATALOG_STAPLE.has(name)) return ShoppingCategory.STAPLE
    if (CATALOG_VEG.has(name)) return ShoppingCategory.VEG
    // 调料关键词优先于肉类判断，避免「花椒」被当成肉、「葱姜蒜」落入其它
    if (containsAny(name, CATEGORY_KEYWORDS[ShoppingCategory.SEASONING])) {
      return ShoppingCategory.SEASONING
    }
    if (containsAny(name, CATEGORY_KEYWORDS[ShoppingCategory.MEAT])) return ShoppingCategory.MEAT
    if (containsAny(name, CATEGORY_KEYWORDS[ShoppingCategory.VEG])) return ShoppingCategory.VEG
    if (containsAny(name, CATEGORY_KEYWORDS[ShoppingCategory.STAPLE])) return ShoppingCategory.STAPLE
    return ShoppingCategory.OTHER
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
