import type { StuffItem } from '../model/recipe';
import { canonicalIngredientName } from '../service/IngredientMatchService';
import { getIngredientAliases } from './IngredientSynonyms';

/**
 * 扩展后的食材与厨具全库
 * 与 recipe.json 中的数据完全对齐，提供更丰富的图文匹配
 *
 * 素菜子分类：菌菇类 / 叶菜类 / 根茎笋类 / 瓜茄类 / 豆类及制品 / 其他
 * 荤菜子分类：蛋类 / 猪肉类 / 牛羊类 / 禽类 / 鱼类 / 虾蟹头足类 / 贝类
 */

// ── 素菜子分类 ──────────────────────────────────────────────────────────────

export const mushroomItems: StuffItem[] = [
  { name: '木耳', emoji: '🍄' },
  { name: '香菇', emoji: '🍄' },
  { name: '茶树菇', emoji: '🍄' },
  { name: '金针菇', emoji: '🍄' },
  { name: '杏鲍菇', emoji: '🍄' },
  { name: '平菇', emoji: '🍄' },
  { name: '蟹味菇', emoji: '🍄' },
  { name: '白玉菇', emoji: '🍄' },
];

export const leafyVegItems: StuffItem[] = [
  { name: '香菜', emoji: '🌿' },
  { name: '豆苗', emoji: '🌱' },
  { name: '芹菜', emoji: '🥬' },
  { name: '菠菜', emoji: '🥬' },
  { name: '韭菜', emoji: '🥬' },
  { name: '韭黄', emoji: '🥬' },
  { name: '生菜', emoji: '🥬' },
  { name: '上海青', emoji: '🥬' },
  { name: '娃娃菜', emoji: '🥬' },
  { name: '空心菜', emoji: '🥬' },
  { name: '茼蒿', emoji: '🥬' },
  { name: '油麦菜', emoji: '🥬' },
  { name: '莴笋', emoji: '🥬' },
  { name: '菜心', emoji: '🥬' },
  { name: '包菜', emoji: '🥬' },
  { name: '大白菜', emoji: '🥬' },
  { name: '紫甘蓝', emoji: '🟣' },
  { name: '红菜苔', emoji: '🥬' },
  { name: '蒜苔', emoji: '🥬' },
  { name: '青菜', emoji: '🥬' },
];

export const rootVegItems: StuffItem[] = [
  { name: '胡萝卜', emoji: '🥕' },
  { name: '洋葱', emoji: '🧅' },
  { name: '白萝卜', emoji: '🥕' },
  { name: '萝卜干', emoji: '🥕' },
  { name: '土豆', emoji: '🥔' },
  { name: '小芋头', emoji: '🍠' },
  { name: '山药', emoji: '🍠' },
  { name: '铁棍山药', emoji: '🍠' },
  { name: '莲藕', emoji: '🪷' },
  { name: '茭白', emoji: '🌾' },
  { name: '竹笋', emoji: '🎋' },
  { name: '芦笋', emoji: '🌱' },
  { name: '笋干', emoji: '🎋' },
];

export const gourdItems: StuffItem[] = [
  { name: '干辣椒', emoji: '🌶️' },
  { name: '红椒', emoji: '🌶️' },
  { name: '青椒', emoji: '🫑' },
  { name: '黄椒', emoji: '🫑' },
  { name: '秋葵', emoji: '🌱' },
  { name: '茄子', emoji: '🍆' },
  { name: '黄瓜', emoji: '🥒' },
  { name: '苦瓜', emoji: '🥒' },
  { name: '丝瓜', emoji: '🥒' },
  { name: '西葫芦', emoji: '🥒' },
  { name: '冬瓜', emoji: '🍈' },
  { name: '南瓜', emoji: '🎃' },
  { name: '西兰花', emoji: '🥦' },
  { name: '菜花', emoji: '🥦' },
  { name: '玉米', emoji: '🌽' },
  { name: '甜玉米粒', emoji: '🌽' },
  { name: '玉米笋', emoji: '🌽' },
  { name: '西红柿', emoji: '🍅' },
  { name: '圣女果', emoji: '🍅' },
];

export const beanItems: StuffItem[] = [
  { name: '扁豆', emoji: '🟢' },
  { name: '四季豆', emoji: '🟢' },
  { name: '荷兰豆', emoji: '🟢' },
  { name: '毛豆', emoji: '🟢' },
  { name: '青豆', emoji: '🟢' },
  { name: '豆角', emoji: '🟢' },
  { name: '干豆角', emoji: '🟢' },
  { name: '豆芽', emoji: '🌱' },
  { name: '绿豆芽', emoji: '🌱' },
  { name: '黄豆芽', emoji: '🌱' },
  { name: '腐竹', emoji: '🥢' },
  { name: '粉丝', emoji: '🍜' },
  { name: '粉条', emoji: '🍜' },
  { name: '春卷皮', emoji: '🥟' },
  { name: '豆腐', emoji: '⬜' },
  { name: '香干', emoji: '🧈' },
  { name: '干豆腐', emoji: '🧈' },
  { name: '豆皮', emoji: '🧈' },
  { name: '豆干', emoji: '🧈' },
  { name: '豆腐皮', emoji: '🧈' },
  { name: '千张', emoji: '🧈' },
  { name: '油豆皮', emoji: '🧈' },
  { name: '油豆腐', emoji: '🧈' },
];

export const otherVegItems: StuffItem[] = [
  { name: '紫菜', emoji: '🌊' },
  { name: '海带', emoji: '🌊' },
  { name: '番茄酱', emoji: '🥫' },
  { name: '柠檬', emoji: '🍋' },
  { name: '百香果', emoji: '🟡' },
  { name: '松仁', emoji: '🌰' },
  { name: '花生米', emoji: '🥜' },
  { name: '红枣', emoji: '🔴' },
  { name: '鸡蛋干', emoji: '🥚' },
  { name: '酸菜', emoji: '🥫' },
  { name: '雪菜', emoji: '🥬' },
  { name: '梅干菜', emoji: '🥬' },
  { name: '榨菜', emoji: '🥫' },
];

// ── 素菜总表（向后兼容 IndexV2 等） ──────────────────────────────────────
export const vegetableItems: StuffItem[] = [
  ...leafyVegItems,
  ...rootVegItems,
  ...gourdItems,
  ...mushroomItems,
  ...beanItems,
  ...otherVegItems,
];

// ── 荤菜子分类 ──────────────────────────────────────────────────────────────

export const eggItems: StuffItem[] = [
  { name: '鸡蛋', emoji: '🥚' },
  { name: '皮蛋', emoji: '🥚' },
  { name: '鹌鹑蛋', emoji: '🥚' },
  { name: '咸鸭蛋', emoji: '🥚' },
  { name: '鸭血', emoji: '🩸' },
];

export const porkItems: StuffItem[] = [
  { name: '猪肉', emoji: '🥩' },
  { name: '五花肉', emoji: '🥩' },
  { name: '猪里脊肉', emoji: '🥩' },
  { name: '猪瘦肉', emoji: '🥩' },
  { name: '猪绞肉', emoji: '🥩' },
  { name: '猪梅花肉', emoji: '🥩' },
  { name: '猪肋排', emoji: '🍖' },
  { name: '猪大排', emoji: '🍖' },
  { name: '猪前肘', emoji: '🍖' },
  { name: '猪蹄', emoji: '🐷' },
  { name: '猪尾', emoji: '🐷' },
  { name: '猪皮', emoji: '🍖' },
  { name: '猪肚', emoji: '🥩' },
  { name: '猪大肠', emoji: '🥩' },
  { name: '猪肥肠', emoji: '🥩' },
  { name: '卤肥肠', emoji: '🥩' },
  { name: '猪心', emoji: '❤️' },
  { name: '猪肝', emoji: '🥩' },
  { name: '猪腰', emoji: '🥩' },
  { name: '猪舌', emoji: '👅' },
  { name: '猪耳朵', emoji: '👂' },
  { name: '猪血肠', emoji: '🌭' },
  { name: '腊肉', emoji: '🥓' },
  { name: '广式腊肠', emoji: '🌭' },
  { name: '风干肉', emoji: '🥩' },
  { name: '酱肉', emoji: '🥩' },
  { name: '火腿', emoji: '🍖' },
];

export const beefLambItems: StuffItem[] = [
  { name: '牛肉', emoji: '🥩' },
  { name: '牛里脊肉', emoji: '🥩' },
  { name: '牛腩', emoji: '🥩' },
  { name: '牛绞肉', emoji: '🥩' },
  { name: '牛腱子肉', emoji: '🥩' },
  { name: '牛排', emoji: '🥩' },
  { name: '牛尾', emoji: '🍖' },
  { name: '牛筋', emoji: '🦴' },
  { name: '牛肚', emoji: '🥩' },
  { name: '牛百叶', emoji: '🥩' },
  { name: '牛心', emoji: '❤️' },
  { name: '牛肝', emoji: '🥩' },
  { name: '牛腰', emoji: '🥩' },
  { name: '牛舌', emoji: '👅' },
  { name: '羊肉', emoji: '🥩' },
  { name: '羊排', emoji: '🍖' },
  { name: '羊绞肉', emoji: '🥩' },
  { name: '羊蹄', emoji: '🍖' },
  { name: '羊筋', emoji: '🦴' },
  { name: '羊肚', emoji: '🥩' },
  { name: '羊腰', emoji: '🥩' },
  { name: '羊杂', emoji: '🥘' },
  { name: '兔肉', emoji: '🐇' },
];

export const poultryItems: StuffItem[] = [
  { name: '鸡肉', emoji: '🍗' },
  { name: '土鸡', emoji: '🐔' },
  { name: '老母鸡', emoji: '🐔' },
  { name: '乌鸡', emoji: '🐔' },
  { name: '鸡腿', emoji: '🍗' },
  { name: '鸡翅中', emoji: '🍗' },
  { name: '鸡胸肉', emoji: '🍗' },
  { name: '鸡肉末', emoji: '🍗' },
  { name: '鸡爪', emoji: '🐔' },
  { name: '鸡脖', emoji: '🐔' },
  { name: '鸡心', emoji: '❤️' },
  { name: '鸡肝', emoji: '🥩' },
  { name: '鸡胗', emoji: '🥩' },
  { name: '鸭子', emoji: '🦆' },
  { name: '老鸭', emoji: '🦆' },
  { name: '鸭腿', emoji: '🍗' },
  { name: '鸭胸肉', emoji: '🍗' },
  { name: '鸭肉末', emoji: '🦆' },
  { name: '鸭翅', emoji: '🦆' },
  { name: '鸭脖', emoji: '🦆' },
  { name: '鸭头', emoji: '🦆' },
  { name: '鸭掌', emoji: '🦆' },
  { name: '鸭心', emoji: '❤️' },
  { name: '鸭肝', emoji: '🥩' },
  { name: '鸭胗', emoji: '🥩' },
  { name: '鹅肉', emoji: '🦢' },
  { name: '鹅胸肉', emoji: '🦢' },
  { name: '老鹅', emoji: '🦢' },
];

export const fishItems: StuffItem[] = [
  { name: '草鱼', emoji: '🐟' },
  { name: '草鱼块', emoji: '🐟' },
  { name: '鲫鱼', emoji: '🐟' },
  { name: '鲤鱼', emoji: '🐟' },
  { name: '鲈鱼', emoji: '🐟' },
  { name: '武昌鱼', emoji: '🐟' },
  { name: '鳊鱼', emoji: '🐟' },
  { name: '罗非鱼', emoji: '🐟' },
  { name: '鲶鱼', emoji: '🐟' },
  { name: '带鱼', emoji: '🐟' },
  { name: '小黄鱼', emoji: '🐟' },
  { name: '梅鱼', emoji: '🐟' },
  { name: '马头鱼', emoji: '🐟' },
  { name: '秋刀鱼', emoji: '🐟' },
  { name: '沙丁鱼', emoji: '🐟' },
  { name: '银鱼', emoji: '🐟' },
  { name: '小杂鱼', emoji: '🐟' },
  { name: '鱼籽', emoji: '🥚' },
  { name: '鱼泡', emoji: '🐟' },
  { name: '鱼肝', emoji: '🥩' },
  { name: '泥鳅', emoji: '🐟' },
  { name: '黄鳝', emoji: '🐍' },
];

export const shrimpCrabItems: StuffItem[] = [
  { name: '虾', emoji: '🦐' },
  { name: '虾仁', emoji: '🍤' },
  { name: '大虾', emoji: '🦐' },
  { name: '河虾', emoji: '🦐' },
  { name: '小龙虾', emoji: '🦞' },
  { name: '小龙虾尾', emoji: '🦞' },
  { name: '虾皮', emoji: '🦐' },
  { name: '螃蟹', emoji: '🦀' },
  { name: '大闸蟹', emoji: '🦀' },
  { name: '蟹粉', emoji: '🦀' },
  { name: '蟹棒', emoji: '🦀' },
  { name: '鱿鱼', emoji: '🦑' },
  { name: '墨鱼', emoji: '🦑' },
];

export const shellfishItems: StuffItem[] = [
  { name: '花甲', emoji: '🐚' },
  { name: '花蛤', emoji: '🐚' },
  { name: '蛤蜊', emoji: '🐚' },
  { name: '蛏子', emoji: '🐚' },
  { name: '田螺', emoji: '🐚' },
  { name: '田螺肉', emoji: '🐚' },
  { name: '螺蛳', emoji: '🐚' },
  { name: '螺蛳肉', emoji: '🐚' },
  { name: '扇贝', emoji: '🐚' },
  { name: '扇贝肉', emoji: '🐚' },
  { name: '生蚝', emoji: '🦪' },
  { name: '生蚝肉', emoji: '🦪' },
  { name: '干贝', emoji: '🐚' },
];

// ── 荤菜总表（向后兼容 IndexV2 等） ──────────────────────────────────────
export const meatItems: StuffItem[] = [
  ...eggItems,
  ...porkItems,
  ...beefLambItems,
  ...poultryItems,
  ...fishItems,
  ...shrimpCrabItems,
  ...shellfishItems,
];

// 碳水/主食库（仅保留在 recipe.json 中有实际覆盖的食材）
export const stapleItems: StuffItem[] = [
  { name: '米饭', emoji: '🍚' },
  { name: '面条', emoji: '🍜' },
  { name: '粉丝', emoji: '🍥' },
  { name: '米线', emoji: '🍜' },
  { name: '河粉', emoji: '🍜' },
  { name: '面食', emoji: '🫓' }
];

export const toolItems: StuffItem[] = [
  { name: '炒锅', emoji: '🍳' },
  { name: '炖锅', emoji: '🥘' },
  { name: '煮锅', emoji: '🫕' },
  { name: '蒸锅', emoji: '♨️' },
  { name: '微波炉', emoji: '⏲️' },
  { name: '平底锅', emoji: '🥞' },
  { name: '砂锅', emoji: '🏺' },
  { name: '烤箱', emoji: '🕋' },
  { name: '电饭煲', emoji: '🍲' },
];

/** 全量食材名 → emoji 扁平映射（懒构建一次，用于无图菜谱的 emoji 占位）。 */
const ingredientEmojiMap: Map<string, string> = (() => {
  const map = new Map<string, string>();
  const all: StuffItem[] = [...vegetableItems, ...meatItems, ...stapleItems];
  for (let i = 0; i < all.length; i++) {
    if (!map.has(all[i].name)) {
      map.set(all[i].name, all[i].emoji);
    }
  }
  return map;
})();

/** 按名称查询食材库中的 emoji，未收录时返回 undefined（供购物清单兜底使用） */
export function findIngredientEmoji(name: string): string | undefined {
  return ingredientEmojiMap.get(name);
}

/** 冰箱选料目录的全量名称（去重），用于把菜谱原始食材名归一化到可勾选的目录名。 */
const catalogNames: string[] = (() => {
  const names: string[] = [];
  const all: StuffItem[] = [...vegetableItems, ...meatItems, ...stapleItems];
  for (let i = 0; i < all.length; i++) {
    if (!names.includes(all[i].name)) {
      names.push(all[i].name);
    }
  }
  return names;
})();

/** 目录名的规范形式预计算：避免每次解析都对整个目录重算一遍同义词归并 */
const catalogCanonicalNames: string[] = (() => {
  const out: string[] = [];
  for (let i = 0; i < catalogNames.length; i++) {
    out.push(canonicalIngredientName(catalogNames[i]));
  }
  return out;
})();

interface CatalogFallbackRule {
  key: string
  target: string
}

/**
 * 关键词兜底（顺序即优先级）：处理「三黄鸡1只 / 鸭半只 / 猪排骨」这类
 * 带品种、数量或部位说法、无法直接命中的名称。
 */
const CATALOG_FALLBACK_RULES: CatalogFallbackRule[] = [
  { key: '排骨', target: '猪肋排' },
  { key: '五花', target: '五花肉' },
  { key: '里脊', target: '猪里脊肉' },
  { key: '鸡腿', target: '鸡腿' },
  { key: '鸡胸', target: '鸡胸肉' },
  { key: '鸡翅', target: '鸡翅中' },
  { key: '鸡爪', target: '鸡爪' },
  { key: '鸡', target: '鸡肉' },
  { key: '鸭', target: '鸭子' },
  { key: '鹅', target: '鹅肉' },
  { key: '牛', target: '牛肉' },
  { key: '羊', target: '羊肉' },
  { key: '猪', target: '猪肉' },
  { key: '虾仁', target: '虾仁' },
  { key: '虾', target: '虾' },
  { key: '蟹', target: '螃蟹' },
  { key: '笋', target: '竹笋' }
]

/**
 * 属于「同类不同物」的名称：子串/关键词匹配会误判为目录食材
 * （淀粉→土豆、牛奶→牛肉、鸡油→鸡肉、黄豆→黄豆芽），必须直接跳过。
 * 仅在「目录同名」之后判断，保证黄豆芽等目录食材本身不受影响。
 */
const CATALOG_SKIP_TERMS: string[] = [
  '淀粉', '面粉', '酸豆', '木耳菜', '盐焗鸡粉', '鸡油', '鸭油',
  '牛奶', '奶油', '牛油果', '鸡杂', '鸭杂', '黄豆'
]

/** 无法通过子串/同义词推出的定向别名（键为菜谱原始名，值为目录名）。 */
const CATALOG_DIRECT_ALIASES: Record<string, string> = {
  '鸭肉': '鸭子',
  '萝卜': '白萝卜'
}

/**
 * 归一化结果缓存。菜谱食材名在每次勾选搜索中会被反复解析上万次，
 * 而目录与同义词表是静态的，缓存后重复解析退化为一次 Map 查找。
 * 键为 trim 后的原始名，值可能是 null（目录未收录），需用 has 语义区分。
 */
const resolveCatalogNameCache: Map<string, string | null> = new Map();

/**
 * 把任意食材名映射到冰箱选料目录中的规范名（采购清单补货与匹配共用）。
 * 顺序：目录同名 → 排除项 → 别名等价 → 定向别名 → 目录名被包含 →
 * 同义词库 → 食材名被包含 → 关键词兜底。
 * 返回 null 表示目录未收录（多为调料、厨具或稀有食材），调用方应跳过。
 */
export function resolveCatalogName(name: string): string | null {
  const trimmed = name.trim();
  if (trimmed.length === 0) {
    return null;
  }
  const cached = resolveCatalogNameCache.get(trimmed);
  if (cached !== undefined) {
    return cached;
  }
  const resolved = resolveCatalogNameUncached(trimmed);
  resolveCatalogNameCache.set(trimmed, resolved);
  return resolved;
}

function resolveCatalogNameUncached(trimmed: string): string | null {
  if (ingredientEmojiMap.has(trimmed)) {
    return trimmed;
  }
  for (let i = 0; i < CATALOG_SKIP_TERMS.length; i++) {
    if (trimmed.includes(CATALOG_SKIP_TERMS[i])) {
      return null;
    }
  }
  const canonical = canonicalIngredientName(trimmed);
  for (let i = 0; i < catalogNames.length; i++) {
    if (catalogCanonicalNames[i] === canonical) {
      return catalogNames[i];
    }
  }
  const direct = CATALOG_DIRECT_ALIASES[trimmed];
  if (direct !== undefined && ingredientEmojiMap.has(direct)) {
    return direct;
  }
  // 目录名被完整包含（草鱼片 → 草鱼、猪五花肉 → 五花肉），取最长者，避免过粗匹配
  let contained: string | null = null;
  for (let i = 0; i < catalogNames.length; i++) {
    const candidate = catalogNames[i];
    if (candidate.length >= 2 && trimmed.includes(candidate)) {
      if (contained === null || candidate.length > contained.length) {
        contained = candidate;
      }
    }
  }
  if (contained !== null) {
    return contained;
  }
  // 同义词库（萝卜 → 白萝卜、大米 → 米饭、整鸡 → 鸡肉）
  const aliases = getIngredientAliases(trimmed);
  for (let i = 1; i < aliases.length; i++) {
    if (ingredientEmojiMap.has(aliases[i])) {
      return aliases[i];
    }
  }
  // 食材名是目录名的片段（里脊肉 → 猪里脊肉、白菜 → 大白菜），取最短者
  let fragment: string | null = null;
  for (let i = 0; i < catalogNames.length; i++) {
    const candidate = catalogNames[i];
    if (trimmed.length >= 2 && candidate.includes(trimmed)) {
      if (fragment === null || candidate.length < fragment.length) {
        fragment = candidate;
      }
    }
  }
  if (fragment !== null) {
    return fragment;
  }
  for (let i = 0; i < CATALOG_FALLBACK_RULES.length; i++) {
    const rule = CATALOG_FALLBACK_RULES[i];
    if (trimmed.includes(rule.key) && ingredientEmojiMap.has(rule.target)) {
      return rule.target;
    }
  }
  return null;
}

/**
 * 两个食材名是否指向冰箱选料目录中的同一项。
 * 供采购清单与搜索复用，保证「补货入冰箱」后同一个菜谱的缺料判断与推荐一致。
 * 任一名称无法归一化（调料、厨具、稀有食材）时返回 false。
 */
export function sameCatalogIngredient(a: string, b: string): boolean {
  const ta = a.trim();
  const tb = b.trim();
  if (ta.length > 0 && ta === tb) {
    return true;
  }
  const resolvedA = resolveCatalogName(ta);
  if (resolvedA === null) {
    return false;
  }
  return resolvedA === resolveCatalogName(tb);
}

/** 冰箱选料（目录名）里是否已有该食材（按目录归一化比较）。 */
export function isCatalogIngredientAvailable(required: string, selected: string[]): boolean {
  for (let i = 0; i < selected.length; i++) {
    if (sameCatalogIngredient(required, selected[i])) {
      return true;
    }
  }
  return false;
}

/**
 * 依据菜谱食材推导一个代表性 emoji（用于无图占位）。
 * 按食材出现顺序取第一个命中的食材 emoji，无命中则返回通用餐具 emoji。
 */
export function getRecipeEmoji(stuff: string[]): string {
  for (let i = 0; i < stuff.length; i++) {
    const e = ingredientEmojiMap.get(stuff[i]);
    if (e !== undefined) {
      return e;
    }
  }
  return '🍽️';
}
