/**
 * 菜品荤素分类 + 厨具归一化
 * - 数据无「荤/素/主食」字段，从 stuff 启发式推导。
 * - tools 含「炒锅或平底锅」复合写法与「菜刀/筷子」等非厨具，需归一化为 8 个规范厨具。
 */
import type { RecipeWithId } from '../model/recipe'
import type { DishType } from '../model/mealPlan'
import { canonicalIngredientName } from './IngredientMatchService'
import { ShoppingCategory, IngredientTypeMapper } from '../utils/IngredientTypeMapper'
import { meatItems, stapleItems, toolItems } from '../data/foodCatalog'

/** 荤 / 主食 / 素 分桶结果 */
export interface DishBuckets {
  meat: RecipeWithId[]
  staple: RecipeWithId[]
  veg: RecipeWithId[]
}

const MEAT_NAMES: Set<string> = new Set()
const STAPLE_NAMES: Set<string> = new Set()
const TOOL_NAMES: Set<string> = new Set()

for (const it of meatItems) {
  MEAT_NAMES.add(canonicalIngredientName(it.name))
}
for (const it of stapleItems) {
  STAPLE_NAMES.add(canonicalIngredientName(it.name))
}
for (const it of toolItems) {
  TOOL_NAMES.add(canonicalIngredientName(it.name))
}

export class DishTypeClassifier {
  /** 单个菜品分类：命中荤 → 荤；否则命中主食 → 主食；否则素 */
  static classifyDish(stuff: string[]): DishType {
    let hasMeat = false
    let hasStaple = false
    for (const raw of stuff) {
      const name = raw.trim()
      if (name.length === 0) {
        continue
      }
      const canonical = canonicalIngredientName(name)
      const cat = IngredientTypeMapper.getShoppingCategory(name)
      if (MEAT_NAMES.has(canonical) || cat === ShoppingCategory.MEAT) {
        hasMeat = true
      }
      if (STAPLE_NAMES.has(canonical) || cat === ShoppingCategory.STAPLE) {
        hasStaple = true
      }
    }
    if (hasMeat) {
      return '荤'
    }
    if (hasStaple) {
      return '主食'
    }
    return '素'
  }

  /** 从 tools 中提取 8 个规范厨具（拆分复合写法、忽略菜刀/筷子等） */
  static getRecipeCookware(tools: string[]): string[] {
    const out: string[] = []
    const seen: Set<string> = new Set()
    for (const tool of tools) {
      const parts = tool.split(/[或、，,\/]+/)
      for (const part of parts) {
        const t = part.trim()
        if (t.length === 0) {
          continue
        }
        const canonical = canonicalIngredientName(t)
        if (TOOL_NAMES.has(canonical) && !seen.has(canonical)) {
          seen.add(canonical)
          out.push(canonical)
        }
      }
    }
    return out
  }

  /** 将菜谱分桶为 荤 / 主食 / 素 */
  static classifyRecipes(recipes: RecipeWithId[]): DishBuckets {
    const meat: RecipeWithId[] = []
    const staple: RecipeWithId[] = []
    const veg: RecipeWithId[] = []
    for (const r of recipes) {
      const t = DishTypeClassifier.classifyDish(r.stuff ?? [])
      if (t === '荤') {
        meat.push(r)
      } else if (t === '主食') {
        staple.push(r)
      } else {
        veg.push(r)
      }
    }
    const buckets: DishBuckets = { meat, staple, veg }
    return buckets
  }
}
