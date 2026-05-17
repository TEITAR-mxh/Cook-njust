/**
 * 菜谱分类分组服务
 * 将烹饪方式(methods)归纳为8个用户友好的分类，支持分类筛选和分区展示
 */
import type { RecipeWithId } from '../model/recipe'

/** 分类组定义（含计数） */
export interface CategoryGroup {
  key: string
  label: string
  emoji: string
  methods: string[]
  count: number
}

/** 分类元信息（不含计数） */
interface CategoryGroupMeta {
  key: string
  label: string
  emoji: string
  methods: string[]
}

/**
 * 方法→分类映射表（按首个 method 分配主分类）
 */
const METHOD_TO_GROUP: Record<string, string> = {
  '炒':   'stir_fry',
  '滑炒': 'stir_fry',
  '煸':   'stir_fry',
  '溜':   'stir_fry',

  '炖':   'braise',
  '烧':   'braise',
  '红烧': 'braise',
  '焖':   'braise',

  '蒸':   'steam',

  '煮':   'boil',
  '焯':   'boil',
  '煲':   'boil',

  '凉拌': 'cold_mix',
  '拌':   'cold_mix',
  '腌制': 'cold_mix',
  '泡':   'cold_mix',
  '浇汁': 'cold_mix',

  '煎':   'fry',
  '炸':   'fry',

  '烤':   'roast',
  '焗':   'roast',

  '卤':   'marinate',
}

/** 分类元信息（不含数量） */
function getGroupMetaList(): CategoryGroupMeta[] {
  let list: CategoryGroupMeta[] = []
  list.push({ key: 'stir_fry',  label: '炒',   emoji: '🔥', methods: ['炒', '滑炒', '煸', '溜'] })
  list.push({ key: 'braise',    label: '炖烧', emoji: '🍲', methods: ['炖', '烧', '红烧', '焖'] })
  list.push({ key: 'steam',     label: '蒸',   emoji: '♨️', methods: ['蒸'] })
  list.push({ key: 'boil',      label: '煮',   emoji: '🫧', methods: ['煮', '焯', '煲'] })
  list.push({ key: 'cold_mix',  label: '凉拌', emoji: '🥒', methods: ['凉拌', '拌', '腌制', '泡', '浇汁'] })
  list.push({ key: 'fry',       label: '煎炸', emoji: '🍳', methods: ['煎', '炸'] })
  list.push({ key: 'roast',     label: '烤',   emoji: '🍖', methods: ['烤', '焗'] })
  list.push({ key: 'marinate',  label: '卤',   emoji: '🧆', methods: ['卤'] })
  list.push({ key: 'other',     label: '其他', emoji: '📋', methods: [] })
  return list
}

/**
 * 获取菜谱的主分类键。
 * 取 recipes.methods[0] 映射到分类；若 method 未被映射则返回 'other'。
 */
function getPrimaryGroupKey(recipe: RecipeWithId): string {
  if (recipe.methods && recipe.methods.length > 0) {
    const primary: string = recipe.methods[0]
    const group: string | undefined = METHOD_TO_GROUP[primary]
    if (group !== undefined) {
      return group
    }
  }
  return 'other'
}

export class CategoryGroupingService {
  /**
   * 构建带计数的分类组列表。
   * 仅返回有菜谱的分类（count > 0），按内置顺序排列。
   */
  static buildGroups(all: RecipeWithId[]): CategoryGroup[] {
    const metaList: CategoryGroupMeta[] = getGroupMetaList()
    const countMap: Map<string, number> = new Map()
    for (let i: number = 0; i < metaList.length; i++) {
      countMap.set(metaList[i].key, 0)
    }

    for (let i: number = 0; i < all.length; i++) {
      const key: string = getPrimaryGroupKey(all[i])
      const prev: number | undefined = countMap.get(key)
      countMap.set(key, (prev !== undefined ? prev : 0) + 1)
    }

    const result: CategoryGroup[] = []
    for (let i: number = 0; i < metaList.length; i++) {
      const meta: CategoryGroupMeta = metaList[i]
      const cnt: number | undefined = countMap.get(meta.key)
      const count: number = cnt !== undefined ? cnt : 0
      if (count > 0) {
        result.push({
          key: meta.key,
          label: meta.label,
          emoji: meta.emoji,
          methods: meta.methods,
          count: count,
        })
      }
    }
    return result
  }

  /**
   * 按分类过滤菜谱列表。
   * 菜谱只要匹配分类组内任一 method 即视为归入该分类。
   */
  static filterByGroup(recipes: RecipeWithId[], groupKey: string): RecipeWithId[] {
    const metaList: CategoryGroupMeta[] = getGroupMetaList()
    let targetMeta: CategoryGroupMeta | null = null
    for (let i: number = 0; i < metaList.length; i++) {
      if (metaList[i].key === groupKey) {
        targetMeta = metaList[i]
        break
      }
    }
    if (targetMeta === null) {
      return recipes
    }
    const methodSet: Set<string> = new Set()
    for (let i: number = 0; i < targetMeta.methods.length; i++) {
      methodSet.add(targetMeta.methods[i])
    }

    const result: RecipeWithId[] = []
    for (let i: number = 0; i < recipes.length; i++) {
      const recipe: RecipeWithId = recipes[i]
      if (recipe.methods && recipe.methods.length > 0) {
        let matched: boolean = false
        for (let j: number = 0; j < recipe.methods.length; j++) {
          if (methodSet.has(recipe.methods[j])) {
            matched = true
            break
          }
        }
        if (matched) {
          result.push(recipe)
        }
      } else if (groupKey === 'other') {
        result.push(recipe)
      }
    }
    return result
  }

  /**
   * 按分类将菜谱分区，返回 Map<groupKey, RecipeWithId[]>。
   */
  static partitionByGroups(recipes: RecipeWithId[]): Map<string, RecipeWithId[]> {
    const metaList: CategoryGroupMeta[] = getGroupMetaList()
    const result: Map<string, RecipeWithId[]> = new Map()
    for (let i: number = 0; i < metaList.length; i++) {
      result.set(metaList[i].key, [])
    }

    for (let i: number = 0; i < recipes.length; i++) {
      const recipe: RecipeWithId = recipes[i]
      const key: string = getPrimaryGroupKey(recipe)
      const arr: RecipeWithId[] | undefined = result.get(key)
      if (arr !== undefined) {
        arr.push(recipe)
      }
    }

    const filtered: Map<string, RecipeWithId[]> = new Map()
    for (let i: number = 0; i < metaList.length; i++) {
      const key: string = metaList[i].key
      const items: RecipeWithId[] | undefined = result.get(key)
      if (items !== undefined && items.length > 0) {
        filtered.set(key, items)
      }
    }
    return filtered
  }

  /**
   * 根据 key 获取分类元信息
   */
  static getGroupMeta(key: string): CategoryGroupMeta | null {
    const metaList: CategoryGroupMeta[] = getGroupMetaList()
    for (let i: number = 0; i < metaList.length; i++) {
      if (metaList[i].key === key) {
        return metaList[i]
      }
    }
    return null
  }
}
