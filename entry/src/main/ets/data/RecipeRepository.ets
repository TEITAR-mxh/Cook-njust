import { common } from '@kit.AbilityKit';
import type { RecipeWithId } from '../model/recipe';
import { RecipeDBManager } from './RecipeDBManager';

export class RecipeRepository {
  private static instance: RecipeRepository | null = null;
  private recipes: RecipeWithId[] = [];

  static getInstance(): RecipeRepository {
    if (RecipeRepository.instance === null) {
      RecipeRepository.instance = new RecipeRepository();
    }
    return RecipeRepository.instance;
  }

  /**
   * 同步内置 recipe.json 到 RDB（哈希变更或空库时重导），再载入内存。
   */
  async load(context: common.Context): Promise<void> {
    await RecipeDBManager.getInstance().ensureReady(context);
    this.recipes = await RecipeDBManager.getInstance().readAllRecipes();
  }

  getAll(): RecipeWithId[] {
    return this.recipes;
  }

  getCount(): number {
    return this.recipes.length;
  }

  getById(id: number): RecipeWithId | null {
    if (id < 0 || id >= this.recipes.length) {
      return null;
    }
    return this.recipes[id];
  }
}
