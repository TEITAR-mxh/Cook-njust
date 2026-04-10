import type { RecipeWithId, SearchMode } from '../model/recipe';

/**
 * 菜谱匹配逻辑，与 Web `cook/app/composables/store/recipe.ts` 中 `searchRecipes` 对齐。
 * 纯函数、无 IO，入参为已加载的全量列表。
 */
export class RecipeSearchService {
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
        const stuffFlag: boolean = selectedStuff.every((stuff: string): boolean => item.stuff.includes(stuff));
        const toolFlag: boolean = item.tools.includes(curTool);
        return hasTool ? (stuffFlag && toolFlag) : stuffFlag;
      });
    } else if (mode === 'loose') {
      result = all.filter((item: RecipeWithId): boolean => {
        const stuffFlag: boolean = selectedStuff.every((stuff: string): boolean => item.stuff.includes(stuff));
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
      // survival
      result = all.filter((item: RecipeWithId): boolean => {
        const stuffFlag: boolean = item.stuff.every((stuff: string): boolean => selectedStuff.includes(stuff));
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

