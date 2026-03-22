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
        const stuffFlag: boolean = selectedStuff.some((stuff: string): boolean => item.stuff.includes(stuff));
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
}
