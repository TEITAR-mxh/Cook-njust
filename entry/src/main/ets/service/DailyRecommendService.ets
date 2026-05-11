/**
 * 每日菜谱推荐算法
 * 优先级：冰箱食材全匹配 → 冰箱食材任意匹配 → 精选标签 → 全局随机
 * 自动排除近 7 天已推荐过的菜谱
 */
import { RecipeWithId } from '../model/recipe'

export interface RecommendResult {
  recipe: RecipeWithId
  reason: string
}

export class DailyRecommendService {
  /**
   * 从全部菜谱中挑选一道今日推荐。
   * @param allRecipes     全量菜谱（已加载）
   * @param selectedStuff  用户冰箱中选中的食材列表
   * @param excludeIds     近期已推荐的菜谱 ID（排除重复）
   */
  static pickRecipe(
    allRecipes: RecipeWithId[],
    selectedStuff: string[],
    excludeIds: number[]
  ): RecommendResult | null {
    if (allRecipes.length === 0) {
      return null;
    }

    // 排除近期已推荐的
    const excludeSet: Set<number> = new Set<number>(excludeIds);
    const candidates: RecipeWithId[] = allRecipes.filter(
      (r: RecipeWithId) => !excludeSet.has(r.id)
    );

    // 若全部排除则重置（所有菜都推过了就重新开始）
    const pool: RecipeWithId[] = candidates.length > 0 ? candidates : allRecipes;

    // 阶段一：冰箱食材全匹配（所有选中食材都在菜谱 stuff 中）
    if (selectedStuff.length > 0) {
      const fridgeAll: RecipeWithId[] = pool.filter((r: RecipeWithId) => {
        const stuffList: string[] = r.stuff ?? [];
        return selectedStuff.every((s: string) => stuffList.includes(s));
      });
      if (fridgeAll.length > 0) {
        const picked = fridgeAll[Math.floor(Math.random() * fridgeAll.length)];
        return { recipe: picked, reason: '冰箱食材完美匹配' };
      }

      // 阶段二：冰箱食材任意匹配（至少有一种选中食材）
      const fridgeAny: RecipeWithId[] = pool.filter((r: RecipeWithId) => {
        const stuffList: string[] = r.stuff ?? [];
        return selectedStuff.some((s: string) => stuffList.includes(s));
      });
      if (fridgeAny.length > 0) {
        const picked = fridgeAny[Math.floor(Math.random() * fridgeAny.length)];
        return { recipe: picked, reason: '用上冰箱里的食材' };
      }
    }

    // 阶段三：有标签的精选菜谱（今日推荐 / 减脂餐 / 快手早餐 等）
    const priorityTags: string[] = ['今日推荐', '减脂餐', '快手早餐'];
    const tagged: RecipeWithId[] = pool.filter((r: RecipeWithId) => {
      const tags: string[] = r.tags ?? [];
      return tags.some((t: string) => priorityTags.includes(t));
    });
    if (tagged.length > 0) {
      const picked = tagged[Math.floor(Math.random() * tagged.length)];
      return { recipe: picked, reason: '今日精选推荐' };
    }

    // 阶段四：全局随机
    const picked = pool[Math.floor(Math.random() * pool.length)];
    return { recipe: picked, reason: '今日随机灵感' };
  }
}
