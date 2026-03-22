import type { StuffItem } from '../model/recipe';

/** 与 Web `cook/app/data/food.ts` 一致 */

export const vegetableItems: StuffItem[] = [
  { name: '土豆', emoji: '🥔' },
  { name: '胡萝卜', emoji: '🥕' },
  { name: '花菜', emoji: '🥦' },
  { name: '白萝卜', emoji: '🥣' },
  { name: '西葫芦', emoji: '🥒' },
  { name: '番茄', emoji: '🍅', alias: '西红柿' },
  { name: '芹菜', emoji: '🥬' },
  { name: '黄瓜', emoji: '🥒' },
  { name: '洋葱', emoji: '🧅' },
  { name: '莴笋', emoji: '🎍' },
  { name: '菌菇', emoji: '🍄' },
  { name: '茄子', emoji: '🍆' },
  { name: '豆腐', emoji: '🍲' },
  { name: '包菜', emoji: '🥗' },
  { name: '白菜', emoji: '🥬' },
];

export const meatItems: StuffItem[] = [
  { name: '午餐肉', emoji: '🥓' },
  { name: '香肠', emoji: '🌭' },
  { name: '腊肠', emoji: '🌭' },
  { name: '鸡肉', emoji: '🐤' },
  { name: '猪肉', emoji: '🐷' },
  { name: '鸡蛋', emoji: '🥚' },
  { name: '虾', emoji: '🦐' },
  { name: '牛肉', emoji: '🐮' },
  { name: '骨头', emoji: '🦴' },
  { name: '鱼（Todo）', emoji: '🐟' },
];

export const stapleItems: StuffItem[] = [
  { name: '面食', emoji: '🍝' },
  { name: '面包', emoji: '🍞' },
  { name: '米', emoji: '🍚' },
  { name: '方便面', emoji: '🍜' },
];

export const toolItems: StuffItem[] = [
  { name: '烤箱', emoji: '🔥' },
  { name: '空气炸锅', emoji: '' },
  { name: '微波炉', emoji: '' },
  { name: '电饭煲', emoji: '' },
  { name: '一口大锅', emoji: '🍳', label: '一口能炒又能煮的大锅' },
];
