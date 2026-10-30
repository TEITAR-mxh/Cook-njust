import type { RecipeWithId, SearchMode } from '../model/recipe';
import { getIngredientAliases } from '../data/IngredientSynonyms';
import { isCatalogIngredientAvailable, sameCatalogIngredient } from '../data/foodCatalog';
import { IngredientTypeMapper } from '../utils/IngredientTypeMapper';
import { hasIngredient, normalizeIngredientName } from './IngredientMatchService';

/**
 * 菜谱匹配逻辑，与 Web `cook/app/composables/store/recipe.ts` 中 `searchRecipes` 对齐。
 * 纯函数、无 IO，入参为已加载的全量列表。
 * 支持同义词扩展：用户选"番茄"能匹配包含"西红柿"的菜谱。
 */
export class RecipeSearchService {
  /**
   * 检查菜谱的 stuff 数组中是否包含目标食材（考虑同义词扩展）。
   * @param recipeStuff 菜谱食材列表
   * @param target 单个目标食材（用户所选）
   */
  private static recipeHasStuff(recipeStuff: string[], target: string): boolean {
    if (hasIngredient(target, recipeStuff)) {
      return true;
    }
    const aliases = getIngredientAliases(normalizeIngredientName(target));
    for (let i = 0; i < recipeStuff.length; i++) {
      for (let j = 0; j < aliases.length; j++) {
        if (normalizeIngredientName(recipeStuff[i]) === aliases[j]) {
          return true;
        }
      }
      // 菜谱原始名常带品种/数量（猪五花肉、土鸡半只），按冰箱选料目录归一后比较
      if (sameCatalogIngredient(recipeStuff[i], target)) {
        return true;
      }
    }
    return false;
  }

  /**
   * @param all 全量菜谱（含 id）
   * @param selectedStuff 已选食材名
   * @param curTool 当前选中的单个厨具名，未选则为 ''
   * @param mode 匹配模式
   * @param keyword 菜名关键字，空字符串则不过滤
   */
  static search(
    all: RecipeWithId[],
    selectedStuff: string[],
    curTool: string,
    mode: SearchMode,
    keyword: string = '',
  ): RecipeWithId[] {
    const selected = selectedStuff.map(normalizeIngredientName).filter((name: string): boolean => name.length > 0);
    const tool = curTool.trim();
    const query = keyword.trim();
    return all.filter((item: RecipeWithId): boolean => {
      if (tool.length > 0 && !item.tools.includes(tool)) {
        return false;
      }
      if (query.length > 0 && !item.name.includes(query)) {
        return false;
      }
      if (mode === 'survival') {
        // 空库存/缺少食材资料均不能声称“现在能做”。
        // 葱姜蒜、生抽、香料等厨房常备项不在冰箱选料里，需视为可用，
        // 否则任何带调料的菜都会被判定为做不了（冰箱目录只收主料）。
        return selected.length > 0 && item.stuff.length > 0 && item.stuff.every(
          (ingredient: string): boolean =>
            IngredientTypeMapper.isPantryItem(ingredient) ||
            hasIngredient(ingredient, selectedStuff) ||
            isCatalogIngredientAvailable(ingredient, selectedStuff));
      }
      if (selected.length === 0) {
        return true;
      }
      if (mode === 'strict') {
        // 都用上：菜谱必须同时包含所有已选食材
        return selected.every((ingredient: string): boolean =>
          RecipeSearchService.recipeHasStuff(item.stuff, ingredient));
      }
      return selected.some((ingredient: string): boolean => RecipeSearchService.recipeHasStuff(item.stuff, ingredient));
    });
  }

  /**
   * 全库按菜名关键字筛选（不依赖选料/模式）；keyword 为空则返回全量。
   * 与做菜页在「有选料」时的 search 不同，此处专门用于菜谱 Tab。
   */
  static filterLibraryByName(all: RecipeWithId[], keyword: string): RecipeWithId[] {
    const k = keyword.trim();
    if (k.length === 0) {
      return all;
    }
    const out: RecipeWithId[] = [];
    for (let i = 0; i < all.length; i++) {
      const item = all[i];
      if (item.name.includes(k)) {
        out.push(item);
      }
    }
    return out;
  }

  /**
   * 按难度筛选；difficulty 为空字符串则不过滤。
   */
  static filterByDifficulty(list: RecipeWithId[], difficulty: string): RecipeWithId[] {
    if (difficulty.length === 0) {
      return list;
    }
    const out: RecipeWithId[] = [];
    for (let i = 0; i < list.length; i++) {
      if (list[i].difficulty === difficulty) {
        out.push(list[i]);
      }
    }
    return out;
  }

  /**
   * 按 tag 筛选；tag 为空字符串则不过滤。
   * 支持特殊 tag 映射：'今日推荐' → 无额外过滤（返回全量），'减脂餐' → tags 含 '减脂' 或 '减脂餐'，
   * '快手早餐' → tags 含 '早餐' 或 '早饭' 或 '快手菜'。
   */
  static filterByTag(list: RecipeWithId[], tag: string): RecipeWithId[] {
    if (tag.length === 0 || tag === '今日推荐') {
      return list;
    }
    let matchTags: string[] = [];
    if (tag === '减脂餐') {
      matchTags = ['减脂', '减脂餐', '健康餐', '健康'];
    } else if (tag === '快手早餐') {
      matchTags = ['早餐', '早饭', '快手菜'];
    } else {
      matchTags = [tag];
    }
    const out: RecipeWithId[] = [];
    for (let i = 0; i < list.length; i++) {
      const item = list[i];
      const itemTags = item.tags ?? [];
      let matched = false;
      for (let j = 0; j < matchTags.length; j++) {
        if (itemTags.includes(matchTags[j])) {
          matched = true;
          break;
        }
      }
      if (matched) {
        out.push(item);
      }
    }
    return out;
  }
}

