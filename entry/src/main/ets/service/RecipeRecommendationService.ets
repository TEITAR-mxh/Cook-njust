/**
 * 个性化推荐引擎（Item-based 协同过滤）
 * 纯函数，无副作用，无 IO。
 *
 * 算法：
 *  1. 菜谱特征向量 = tags ∪ stuff ∪ methods（字符串集合）
 *  2. 两道菜相似度 = Jaccard(A, B) = |A ∩ B| / |A ∪ B|
 *  3. 候选菜谱得分 = 所有历史/收藏菜谱与候选菜谱 Jaccard 均值
 *  4. 返回得分最高的 TopN 且用户未交互过的菜谱
 */
import type { RecipeWithId } from '../model/recipe'

/**
 * 构建菜谱的特征集合（tags + stuff + methods）
 */
function buildFeatureSet(recipe: RecipeWithId): Set<string> {
  const s = new Set<string>()
  const tags = recipe.tags ?? []
  const stuff = recipe.stuff
  const methods = recipe.methods ?? []
  for (let i = 0; i < tags.length; i++) { s.add(tags[i]) }
  for (let i = 0; i < stuff.length; i++) { s.add(stuff[i]) }
  for (let i = 0; i < methods.length; i++) { s.add(methods[i]) }
  return s
}

/**
 * Jaccard 相似度
 */
function jaccardSimilarity(a: Set<string>, b: Set<string>): number {
  if (a.size === 0 && b.size === 0) { return 0 }
  let intersect = 0
  a.forEach((v: string) => {
    if (b.has(v)) { intersect++ }
  })
  const union = a.size + b.size - intersect
  if (union === 0) { return 0 }
  return intersect / union
}

/**
 * 生成推荐菜谱列表。
 *
 * @param all 全量菜谱（来自 RecipeRepository.getAll()）
 * @param interactedIds 用户已收藏或浏览过的菜谱 ID（最多取最近 10 条）
 * @param topN 返回的推荐数量（默认 10）
 * @returns 推荐菜谱列表（得分从高到低），不包含 interactedIds 中的菜谱
 */
export function generateRecommendations(
  all: RecipeWithId[],
  interactedIds: number[],
  topN: number = 10,
): RecipeWithId[] {
  if (interactedIds.length === 0 || all.length === 0) {
    return []
  }

  // 取最近 10 条互动记录
  const seedIds: number[] = interactedIds.slice(0, 10)
  const interactedSet = new Set<number>(interactedIds)

  // 构建 seed 菜谱的特征集合
  const seedFeatures: Set<string>[] = []
  for (let i = 0; i < seedIds.length; i++) {
    let found: RecipeWithId | null = null
    for (let j = 0; j < all.length; j++) {
      if (all[j].id === seedIds[i]) { found = all[j]; break }
    }
    if (found !== null) {
      seedFeatures.push(buildFeatureSet(found))
    }
  }

  if (seedFeatures.length === 0) {
    return []
  }

  // 对每道非交互菜谱计算平均相似度
  interface ScoredRecipe {
    recipe: RecipeWithId
    score: number
  }
  const candidates: ScoredRecipe[] = []

  for (let i = 0; i < all.length; i++) {
    const r = all[i]
    if (interactedSet.has(r.id)) { continue }

    const featureB = buildFeatureSet(r)
    if (featureB.size === 0) { continue }

    let totalSim = 0
    for (let j = 0; j < seedFeatures.length; j++) {
      totalSim += jaccardSimilarity(seedFeatures[j], featureB)
    }
    const avgSim = totalSim / seedFeatures.length

    if (avgSim > 0) {
      candidates.push({ recipe: r, score: avgSim })
    }
  }

  // 按得分降序排列
  candidates.sort((a: ScoredRecipe, b: ScoredRecipe): number => b.score - a.score)

  const result: RecipeWithId[] = []
  const limit = Math.min(topN, candidates.length)
  for (let i = 0; i < limit; i++) {
    result.push(candidates[i].recipe)
  }
  return result
}
