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
    // 修复：不能直接用 id 当作数组索引访问！
    // 数组索引是从 0 开始的连续数字，而 recipe.json 中的 id 可能是从 1 开始甚至断层的。
    // 这里改用 find 迭代查找真实的 id 属性，彻底解决打开详情页时数据串位或崩溃的问题。
    return this.recipes.find(recipe => recipe.id === id) || null;
  }
}