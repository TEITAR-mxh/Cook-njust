import { common } from '@kit.AbilityKit';
import type { RecipeWithId } from '../model/recipe';
import { RecipeDBManager } from './RecipeDBManager';
import { IngredientNutritionService } from '../service/IngredientNutritionService';

export class RecipeRepository {
  private static instance: RecipeRepository | null = null;
  private recipes: RecipeWithId[] = [];
  /** id → 菜谱 索引，getById 用 O(1) 查找替代线性扫描 */
  private byId: Map<number, RecipeWithId> = new Map();
  /** 菜名 → 菜谱 索引（同名取第一条），识别/手动输入的营养兜底用 */
  private byName: Map<string, RecipeWithId> = new Map();

  static getInstance(): RecipeRepository {
    if (RecipeRepository.instance === null) {
      RecipeRepository.instance = new RecipeRepository();
    }
    return RecipeRepository.instance;
  }

  /**
   * 同步内置 recipe.json 到 RDB（哈希变更或空库时重导），再载入内存，
   * 统一按食材营养库聚合补全 nutrition（唯一数据源，保证同菜同数），
   * 并按经验份量生成 missing 的 stuffAmount。
   */
  async load(context: common.Context): Promise<void> {
    await RecipeDBManager.getInstance().ensureReady(context);
    this.recipes = await RecipeDBManager.getInstance().readAllRecipes();
    await IngredientNutritionService.getInstance().load(context);
    const nutritionReady: boolean = IngredientNutritionService.getInstance().hasData();
    this.byId = new Map();
    this.byName = new Map();
    for (let i = 0; i < this.recipes.length; i++) {
      const r = this.recipes[i];
      if (nutritionReady && r.nutrition === undefined) {
        r.nutrition = IngredientNutritionService.getInstance().aggregateDishNutrition(r.stuff);
        r.nutritionEstimated = true;
      }
      if (nutritionReady && r.stuffAmount === undefined) {
        const amounts: Record<string, string> = {};
        let hasAmount = false;
        for (let j = 0; j < r.stuff.length; j++) {
          const name = r.stuff[j].trim();
          if (name.length === 0) {
            continue;
          }
          const amount = IngredientNutritionService.getInstance().estimateServingAmount(name);
          if (amount.length > 0) {
            amounts[name] = amount;
            hasAmount = true;
          }
        }
        if (hasAmount) {
          r.stuffAmount = amounts;
        }
      }
      this.byId.set(r.id, r);
      const nameKey = r.name.trim();
      if (nameKey.length > 0 && !this.byName.has(nameKey)) {
        this.byName.set(nameKey, r);
      }
    }
  }

  getAll(): RecipeWithId[] {
    return this.recipes;
  }

  getCount(): number {
    return this.recipes.length;
  }

  getById(id: number): RecipeWithId | null {
    // id 与数组下标并非一致（recipe.json 中 id 从 1 起），故用 Map 索引做 O(1) 查找。
    return this.byId.get(id) ?? null;
  }

  /** 按菜名精确查找（拍照识别 / 手动输入的营养兜底用） */
  getByName(name: string): RecipeWithId | null {
    const key = name.trim();
    if (key.length === 0) {
      return null;
    }
    return this.byName.get(key) ?? null;
  }
}