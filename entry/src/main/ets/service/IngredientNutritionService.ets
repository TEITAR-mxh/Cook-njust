/**
 * 食材营养库服务 - 加载 ingredient_nutrition.json，提供菜品级营养聚合估算。
 *
 * 数据来源：《中国食物成分表（第6版）》+ 类别估算（scripts/build_ingredient_nutrition.py 生成）。
 * 每 100g 营养 + 经验份量（servingWeight，克），aggregateDishNutrition 按食材聚合出整份菜营养。
 */
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import type { RecipeNutrition } from '../model/recipe';

/** 每 100g 营养 + 经验份量（克）+ 数据来源标记 */
export interface IngredientNutrition {
  calories: number
  protein: number
  fat: number
  carbs: number
  fiber: number
  sodium: number
  servingWeight: number
  source: string
}

const RAW_NAME = 'ingredient_nutrition.json';

export class IngredientNutritionService {
  private static instance: IngredientNutritionService | null = null;
  private map: Map<string, IngredientNutrition> = new Map();

  static getInstance(): IngredientNutritionService {
    if (IngredientNutritionService.instance === null) {
      IngredientNutritionService.instance = new IngredientNutritionService();
    }
    return IngredientNutritionService.instance;
  }

  /**
   * 加载 rawfile 营养库（幂等，仅首次加载）。
   */
  async load(context: common.Context): Promise<void> {
    if (this.map.size > 0) {
      return;
    }
    let raw: Uint8Array | ArrayBuffer;
    try {
      raw = await context.resourceManager.getRawFileContent(RAW_NAME);
    } catch (_e) {
      const ctx = context as common.UIAbilityContext;
      if (typeof ctx.createModuleContext === 'function') {
        const moduleCtx = ctx.createModuleContext('entry');
        raw = await moduleCtx.resourceManager.getRawFileContent(RAW_NAME);
      } else {
        return;
      }
    }
    const bytes: Uint8Array = raw instanceof Uint8Array ? raw : new Uint8Array(raw);
    const decoder = new util.TextDecoder('utf-8');
    const text = decoder.decodeToString(bytes);
    const parsed = JSON.parse(text) as Record<string, IngredientNutrition>;
    const keys = Object.keys(parsed);
    for (let i = 0; i < keys.length; i++) {
      this.map.set(keys[i], parsed[keys[i]]);
    }
  }

  /**
   * 按食材聚合整份菜营养（单份经验估算）。
   * 每样食材取每 100g 营养 × (经验份量/100) 累加；未收录的食材（厨具/水等）跳过。
   * recipe.json 的 stuff 是「买菜清单」，多数炒菜不含油、部分不含盐/酱油，
   * 故对缺失的油、钠做「烹饪增量」补齐，避免炒菜热量被系统性低估、评级失真。
   */
  aggregateDishNutrition(stuff: string[]): RecipeNutrition {
    const result: RecipeNutrition = { calories: 0, protein: 0, fat: 0, carbs: 0, fiber: 0, sodium: 0 };
    let hasOil = false;
    let hasSodium = false;
    let weight = 0;
    for (let i = 0; i < stuff.length; i++) {
      const name = stuff[i].trim();
      if (IngredientNutritionService.isOilName(name)) {
        hasOil = true;
      }
      if (IngredientNutritionService.isSodiumName(name)) {
        hasSodium = true;
      }
      const data = this.map.get(name);
      if (data === undefined) {
        continue;
      }
      const factor = data.servingWeight / 100;
      result.calories += data.calories * factor;
      result.protein += data.protein * factor;
      result.fat += data.fat * factor;
      result.carbs += data.carbs * factor;
      result.fiber += data.fiber * factor;
      result.sodium += data.sodium * factor;
      weight += data.servingWeight;
    }
    // 烹饪增量：缺油补 10g 炒菜油，缺钠补 3g 盐
    if (!hasOil) {
      result.calories += 90;
      result.fat += 10;
      weight += 10;
    }
    if (!hasSodium) {
      result.sodium += 1180;
      weight += 3;
    }
    result.calories = Math.round(result.calories);
    result.protein = Math.round(result.protein * 10) / 10;
    result.fat = Math.round(result.fat * 10) / 10;
    result.carbs = Math.round(result.carbs * 10) / 10;
    result.fiber = Math.round(result.fiber * 10) / 10;
    result.sodium = Math.round(result.sodium);
    result.totalWeight = Math.max(1, Math.round(weight));
    return result;
  }

  /** 营养库是否已成功加载；未加载时调用方应跳过营养/用量补全，避免拿空表估算。 */
  hasData(): boolean {
    return this.map.size > 0;
  }

  /**
   * 单份经验用量（克），用于给菜谱生成食材用量表。
   * 未收录的食材返回空串（如厨具、水）。
   */
  estimateServingAmount(name: string): string {
    const data = this.map.get(name.trim());
    if (data === undefined || data.servingWeight <= 0) {
      return '';
    }
    return `${Math.round(data.servingWeight)}g`;
  }

  /**
   * 是否为烹调用油（含「植物油」等变体）。
   * 排除酱油/蚝油等含「油」字但非油类的调料，以及油条/油菜等含「油」字的食材。
   */
  private static isOilName(name: string): boolean {
    const nonOils: string[] = ['酱油', '蚝油', '油条', '油菜', '油麦菜', '油豆腐', '油面筋', '油饼'];
    for (let i = 0; i < nonOils.length; i++) {
      if (name.includes(nonOils[i])) {
        return false;
      }
    }
    return name.includes('油');
  }

  /** 是否为高钠调料（含盐/酱/豉/腌渍等，用于判断是否需补基础盐） */
  private static isSodiumName(name: string): boolean {
    const keys: string[] = ['盐', '酱', '豉', '腐乳', '榨菜', '酸菜', '雪菜', '梅干菜', '剁椒', '泡椒', '蚝油', '生抽', '老抽', '酱油', '火锅底料', '腌料'];
    for (let i = 0; i < keys.length; i++) {
      if (name.includes(keys[i])) {
        return true;
      }
    }
    return false;
  }
}
