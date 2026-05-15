import type { StuffItem } from '../model/recipe';

/** * 扩展后的食材与厨具全库
 * 与 recipe.json 中的数据完全对齐，提供更丰富的图文匹配
 */

export const vegetableItems: StuffItem[] = [
  { name: '土豆', emoji: '🥔' },
  { name: '番茄', emoji: '🍅', alias: '西红柿' },
  { name: '洋葱', emoji: '🧅' },
  { name: '包菜', emoji: '🥗' },
  { name: '白菜', emoji: '🥬' },
  { name: '胡萝卜', emoji: '🥕' },
  { name: '白萝卜', emoji: '🥣' },
  { name: '黄瓜', emoji: '🥒' },
  { name: '西葫芦', emoji: '🥒' },
  { name: '茄子', emoji: '🍆' },
  { name: '花菜', emoji: '🥦' },
  { name: '芹菜', emoji: '🥬' },
  { name: '莴笋', emoji: '🎍' },
  { name: '青椒', emoji: '🫑' },
  { name: '红椒', emoji: '🌶️' },
  { name: '菌菇', emoji: '🍄' },
  { name: '金针菇', emoji: '🍄' },
  { name: '木耳', emoji: '🍄‍🟫' },
  { name: '豆腐', emoji: '🍲' },
  { name: '豆皮', emoji: '🫔' },
  { name: '蒜薹', emoji: '🥬' },
  { name: '韭菜', emoji: '🥬' }
];

export const meatItems: StuffItem[] = [
  { name: '猪肉', emoji: '🥩' },
  { name: '骨头', emoji: '🍖' },
  { name: '排骨', emoji: '🍖' },
  { name: '牛肉', emoji: '🥩' },
  { name: '羊肉', emoji: '🥩' },
  { name: '鸡肉', emoji: '🍗' },
  { name: '鱼肉', emoji: '🐟' },
  { name: '虾', emoji: '🦐' },
  { name: '虾仁', emoji: '🍤' },
  { name: '鸡蛋', emoji: '🥚' },
  { name: '腊肠', emoji: '🌭' },
  { name: '香肠', emoji: '🌭' },
  { name: '午餐肉', emoji: '🥓' },
  { name: '培根', emoji: '🥓' }
];

// 新增：分离出的碳水/主食库
export const stapleItems: StuffItem[] = [
  { name: '米', emoji: '🍚' },
  { name: '米饭', emoji: '🍚' },
  { name: '面食', emoji: '🍜' },
  { name: '面条', emoji: '🍜' },
  { name: '方便面', emoji: '🍜' },
  { name: '粉丝', emoji: '🍜' },
  { name: '年糕', emoji: '🍡' },
  { name: '面包', emoji: '🍞' },
  { name: '吐司', emoji: '🍞' }
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