import type { StuffItem } from '../model/recipe';

/** * 扩展后的食材与厨具全库
 * 与 recipe.json 中的数据完全对齐，提供更丰富的图文匹配
 */

export const vegetableItems: StuffItem[] = [
  { name: '青椒', emoji: '🫑' },
  { name: '红椒', emoji: '🌶️' },
  { name: '胡萝卜', emoji: '🥕' },
  { name: '土豆', emoji: '🥔' },
  { name: '木耳', emoji: '🍄‍🟫' },
  { name: '黄瓜', emoji: '🥒' },
  { name: '菌菇', emoji: '🍄' },
  { name: '豆腐', emoji: '🫕' },
  { name: '韭菜', emoji: '🥬' },
  { name: '洋葱', emoji: '🧅' },
  { name: '花菜', emoji: '🥦' },
  { name: '白萝卜', emoji: '🥣' },
  { name: '芹菜', emoji: '🥬' },
  { name: '番茄', emoji: '🍅', alias: '西红柿' },
  { name: '包菜', emoji: '🥗' },
  { name: '冬瓜', emoji: '🍈' },
  { name: '酸菜', emoji: '🥬' },
  { name: '山药', emoji: '🌿' },
  { name: '豆角', emoji: '🫘' },
  { name: '豆芽', emoji: '🌱' },
  { name: '莴笋', emoji: '🎍' },
  { name: '茄子', emoji: '🍆' }
];

export const meatItems: StuffItem[] = [
  { name: '鸡蛋', emoji: '🥚' },
  { name: '猪五花肉', emoji: '🥩' },
  { name: '猪肉', emoji: '🥩' },
  { name: '鸡肉', emoji: '🍗' },
  { name: '牛肉', emoji: '🥩' },
  { name: '虾仁', emoji: '🍤' },
  { name: '草鱼块', emoji: '🐟' },
  { name: '猪肋排', emoji: '🍖' },
  { name: '羊肉', emoji: '🥩' },
  { name: '鱿鱼', emoji: '🦑' },
  { name: '花甲', emoji: '🦪' },
  { name: '虾', emoji: '🦐' }
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
  { name: '电饭煲', emoji: '🍲' }
];