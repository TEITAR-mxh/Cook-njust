/**
 * 一餐套餐生成 + 多菜聚合采购清单
 * - 生成：按人数 → 菜数、荤素比 → 荤菜数，厨具约束过滤，随机抽选去重。
 * - 聚合：多道菜 stuff 按 canonical 名去重，分类 + emoji + 用量（有 stuffAmount 才显示）。
 */
import type { RecipeWithId } from '../model/recipe'
import type { MeatRatio } from '../model/mealPlan'
import type { MissingItem } from './ShoppingListService'
import { ShoppingListService } from './ShoppingListService'
import { IngredientTypeMapper } from '../utils/IngredientTypeMapper'
import { canonicalIngredientName } from './IngredientMatchService'
import { DishTypeClassifier } from './DishTypeClassifier'
import { toolItems } from '../data/foodCatalog'

const TOOL_SKIP: Set<string> = new Set()
for (const it of toolItems) {
  TOOL_SKIP.add(canonicalIngredientName(it.name))
}

export class MealPlanService {
  /** 按人数 + 荤素比 + 厨具约束生成一餐（去重、随机） */
  static generateMealPlan(
    recipes: RecipeWithId[],
    people: number,
    meatRatio: MeatRatio,
    availableTools: string[]
  ): RecipeWithId[] {
    const targetCount = Math.max(2, Math.min(6, people + 1))
    let meatCount = Math.ceil(targetCount / 2)
    if (meatRatio === '偏素') {
      meatCount = Math.max(1, Math.floor(targetCount / 3))
    } else if (meatRatio === '偏荤') {
      meatCount = Math.max(1, targetCount - 1)
    }

    // 厨具过滤：无选择 = 不约束；选中后只保留「无厨具要求」或「厨具 ⊆ 已选」的菜
    const filtered: RecipeWithId[] = []
    for (const r of recipes) {
      if (availableTools.length === 0) {
        filtered.push(r)
        continue
      }
      const cw = DishTypeClassifier.getRecipeCookware(r.tools ?? [])
      if (cw.length === 0) {
        filtered.push(r)
        continue
      }
      let allIn = true
      for (const t of cw) {
        if (!availableTools.includes(t)) {
          allIn = false
          break
        }
      }
      if (allIn) {
        filtered.push(r)
      }
    }

    const buckets = DishTypeClassifier.classifyRecipes(filtered)
    const picked: RecipeWithId[] = []
    MealPlanService.pickInto(picked, buckets.meat, meatCount)
    // 余量从「主食 + 素」混合池补齐，保证荤素/主食搭配
    const restPool: RecipeWithId[] = buckets.staple.concat(buckets.veg)
    const remaining = targetCount - picked.length
    if (remaining > 0) {
      MealPlanService.pickInto(picked, restPool, remaining)
    }
    return picked
  }

  /** 多菜聚合采购清单：名称级去重 + 分类 + emoji + 用量 */
  static aggregateIngredients(recipes: RecipeWithId[]): MissingItem[] {
    const map: Map<string, MissingItem> = new Map()
    for (const r of recipes) {
      const stuff = r.stuff ?? []
      const amountMap = r.stuffAmount ?? {}
      for (const raw of stuff) {
        const name = raw.trim()
        if (name.length === 0) {
          continue
        }
        const canonical = canonicalIngredientName(name)
        if (TOOL_SKIP.has(canonical)) {
          continue
        }
        const amount = amountMap[name] ?? ''
        const existing = map.get(canonical)
        if (existing !== undefined) {
          if (existing.amount.length === 0 && amount.length > 0) {
            existing.amount = amount
          } else if (existing.amount.length > 0 && amount.length > 0 && existing.amount !== amount) {
            existing.amount = `${existing.amount}、${amount}`
          }
        } else {
          map.set(canonical, {
            name: canonical,
            amount,
            category: IngredientTypeMapper.getShoppingCategory(name),
            emoji: ShoppingListService.getIngredientEmoji(name)
          })
        }
      }
    }
    const items: MissingItem[] = Array.from(map.values())
    items.sort((a, b) =>
      IngredientTypeMapper.CATEGORY_ORDER.indexOf(a.category) - IngredientTypeMapper.CATEGORY_ORDER.indexOf(b.category))
    return items
  }

  /** 从池中随机抽选 n 个（去重，不足则取尽） */
  private static pickInto(out: RecipeWithId[], pool: RecipeWithId[], n: number): void {
    if (n <= 0 || pool.length === 0) {
      return
    }
    const shuffled = MealPlanService.shuffle(pool)
    const seen: Set<number> = new Set()
    for (const r of out) {
      seen.add(r.id)
    }
    const startCount = out.length
    for (const r of shuffled) {
      if (seen.has(r.id)) {
        continue
      }
      seen.add(r.id)
      out.push(r)
      if (out.length - startCount >= n) {
        break
      }
    }
  }

  private static shuffle<T>(arr: T[]): T[] {
    const a = arr.slice()
    for (let i = a.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1))
      const tmp = a[i]
      a[i] = a[j]
      a[j] = tmp
    }
    return a
  }
}
