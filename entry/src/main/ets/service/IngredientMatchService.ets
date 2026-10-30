/** 库存等价关系。搜索分类（例如鸡肉/鸡翅）不代表库存可互换。 */
const EQUIVALENT_NAMES: string[][] = [
  ['番茄', '西红柿'],
  ['圣女果', '樱桃番茄', '小番茄'],
  ['土豆', '马铃薯', '洋芋', '薯仔'],
  ['包菜', '卷心菜', '圆白菜', '莲花白', '洋白菜'],
  ['胡萝卜', '红萝卜', '黄萝卜'],
  ['木耳', '黑木耳', '云耳', '树耳'],
  ['洋葱', '圆葱'],
  ['花菜', '菜花', '白花椰菜', '花椰菜'],
  ['西兰花', '绿花椰菜'],
  ['香菇', '冬菇', '椎茸'],
  ['米', '大米'],
  ['米饭', '白饭', '白米饭', '大米饭'],
  ['鸡蛋', '鸡子', '鸡卵'],
  ['蒜', '大蒜', '蒜头', '蒜瓣'],
  ['姜', '生姜'],
  ['油', '食用油'],
  ['盐', '食盐'],
]

export function normalizeIngredientName(name: string): string {
  return name.trim().replace(/\s+/g, '').toLowerCase()
}

export function canonicalIngredientName(name: string): string {
  const normalized = normalizeIngredientName(name)
  for (const group of EQUIVALENT_NAMES) {
    if (group.includes(normalized)) {
      return group[0]
    }
  }
  return normalized
}

/** 只接受名称相同或明确别名；不使用子串、类别或替代食材推断。 */
export function hasIngredient(required: string, available: string[]): boolean {
  const canonical = canonicalIngredientName(required)
  return canonical.length > 0 && available.some((name: string): boolean =>
    canonicalIngredientName(name) === canonical)
}
