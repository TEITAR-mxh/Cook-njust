import type { RecipeWithId, SearchMode } from '../model/recipe';
import { getIngredientAliases } from '../data/IngredientSynonyms';

/**
 * 菜谱匹配逻辑，与 Web `cook/app/composables/store/recipe.ts` 中 `searchRecipes` 对齐。
 * 纯函数、无 IO，入参为已加载的全量列表。
 * 支持同义词扩展：用户选"番茄"能匹配包含"西红柿"的菜谱。
 */
export class RecipeSearchService {
  /**
   * 将一组食材名各自展开同义词，返回扁平化的等价名集合。
   */
  private static expandWithSynonyms(stuff: string[]): string[] {
    const expanded: string[] = [];
    for (let i = 0; i < stuff.length; i++) {
      const aliases = getIngredientAliases(stuff[i]);
      for (let j = 0; j < aliases.length; j++) {
        let found = false;
        for (let k = 0; k < expanded.length; k++) {
          if (expanded[k] === aliases[j]) { found = true; break; }
        }
        if (!found) { expanded.push(aliases[j]); }
      }
    }
    return expanded;
  }

  /**
   * 检查菜谱的 stuff 数组中是否包含目标食材（考虑同义词扩展）。
   * @param recipeStuff 菜谱食材列表
   * @param target 单个目标食材（用户所选）
   */
  private static recipeHasStuff(recipeStuff: string[], target: string): boolean {
    const aliases = getIngredientAliases(target);
    for (let i = 0; i < recipeStuff.length; i++) {
      for (let j = 0; j < aliases.length; j++) {
        if (recipeStuff[i] === aliases[j]) {
          return true;
        }
      }
    }
    return false;
  }

  /**
   * 检查用户选择的食材集中是否包含某个菜谱食材（生存模式用）。
   * @param selectedExpanded 用户所选食材（已展开同义词）
   * @param ingredient 菜谱中某个食材名
   */
  private static selectedCoversIngredient(selectedExpanded: string[], ingredient: string): boolean {
    const aliases = getIngredientAliases(ingredient);
    for (let i = 0; i < aliases.length; i++) {
      for (let j = 0; j < selectedExpanded.length; j++) {
        if (selectedExpanded[j] === aliases[i]) {
          return true;
        }
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
    let result: RecipeWithId[] = [];
    const hasTool: boolean = curTool.length > 0;
    const stuffCount: number = selectedStuff.length;

    if (mode === 'strict') {
      result = all.filter((item: RecipeWithId): boolean => {
        const stuffFlag: boolean = selectedStuff.every(
          (stuff: string): boolean => RecipeSearchService.recipeHasStuff(item.stuff, stuff)
        );
        const toolFlag: boolean = item.tools.includes(curTool);
        return hasTool ? (stuffFlag && toolFlag) : stuffFlag;
      });
    } else if (mode === 'loose') {
      result = all.filter((item: RecipeWithId): boolean => {
        const stuffFlag: boolean = selectedStuff.every(
          (stuff: string): boolean => RecipeSearchService.recipeHasStuff(item.stuff, stuff)
        );
        const toolFlag: boolean = Boolean(item.tools?.includes(curTool));

        if (hasTool && stuffCount > 0) {
          return stuffFlag && toolFlag;
        }
        if (stuffCount > 0) {
          return stuffFlag;
        }
        if (hasTool) {
          return toolFlag;
        }
        return false;
      });
    } else {
      // survival：菜谱所有食材均在用户所选食材（含同义词）中
      const selectedExpanded = RecipeSearchService.expandWithSynonyms(selectedStuff);
      result = all.filter((item: RecipeWithId): boolean => {
        const stuffFlag: boolean = item.stuff.every(
          (ingredient: string): boolean =>
            RecipeSearchService.selectedCoversIngredient(selectedExpanded, ingredient)
        );
        const toolFlag: boolean = item.tools?.includes(curTool) ?? false;
        return Boolean(hasTool ? (stuffFlag && toolFlag) : stuffFlag);
      });
    }

    if (keyword.length > 0) {
      result = result.filter((item: RecipeWithId): boolean => item.name.includes(keyword));
    }
    return result;
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

