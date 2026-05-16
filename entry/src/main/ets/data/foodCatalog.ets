import type { StuffItem } from '../model/recipe';

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
  { name: '长茄子', emoji: '🍆' },
  { name: '茄子干', emoji: '🍆' },
  { name: '黄瓜', emoji: '🥒' },
  { name: '苦瓜', emoji: '🥒' },
  { name: '丝瓜', emoji: '🥒' },
  { name: '西葫芦', emoji: '🥒' },
  { name: '冬瓜', emoji: '🍈' },
  { name: '南瓜', emoji: '🎃' },
  { name: '老南瓜', emoji: '🎃' },
  { name: '嫩南瓜', emoji: '🎃' },
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
  { name: '粉丝', emoji: '🍜' },
  { name: '面食', emoji: '🫓' },
  { name: '米饭', emoji: '🍚' }
];

export const toolItems: StuffItem[] = [
  { name: '炒锅', emoji: '🍳' },
  { name: '炖锅', emoji: '🥘' },
  { name: '煮锅', emoji: '🫕' },
  { name: '蒸锅', emoji: '♨️' },
  { name: '平底锅', emoji: '🥞' },
  { name: '砂锅', emoji: '🏺' },
  { name: '烤箱', emoji: '🕋' },
  { name: '电饭煲', emoji: '🍲' },
];
