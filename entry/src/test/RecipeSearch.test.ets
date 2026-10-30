import { describe, it, expect } from '@ohos/hypium';
import type { RecipeWithId } from '../main/ets/model/recipe';
import { RecipeSearchService } from '../main/ets/service/RecipeSearchService';
import { hasIngredient } from '../main/ets/service/IngredientMatchService';
import { ShoppingListService } from '../main/ets/service/ShoppingListService';

export default function recipeSearchTest() {
  describe('RecipeSearchContract', () => {
    const recipes: RecipeWithId[] = [
      { id: 10, name: '番茄', stuff: ['西红柿'], tools: ['炒锅'] },
      { id: 20, name: '鸡蛋', stuff: ['鸡蛋'], tools: ['煮锅'] },
      { id: 30, name: '番茄鸡蛋', stuff: ['西红柿', '鸡蛋'], tools: ['炒锅'] },
      { id: 40, name: '番茄鸡蛋面', stuff: ['番茄', '鸡蛋', '面条'], tools: ['煮锅'] },
      { id: 50, name: '资料缺失', stuff: [], tools: ['炒锅'] },
    ];

    it('loose matches any selected ingredient and strict matches all', 0, () => {
      const selected = ['番茄', '鸡蛋'];
      expect(RecipeSearchService.search(recipes, selected, '', 'loose').length).assertEqual(4);
      expect(RecipeSearchService.search(recipes, selected, '', 'strict').length).assertEqual(2);
      expect(RecipeSearchService.search(recipes, selected, '', 'survival').length).assertEqual(3);
    });

    it('tools and trimmed keywords remain hard constraints', 0, () => {
      const found = RecipeSearchService.search(recipes, [' 番茄 ', '鸡蛋'], ' 炒锅 ', 'loose', ' 鸡蛋 ');
      expect(found.length).assertEqual(1);
      expect(found[0].id).assertEqual(30);
    });

    it('empty selection browses recipes but never claims survival readiness', 0, () => {
      expect(RecipeSearchService.search(recipes, [], '', 'loose').length).assertEqual(5);
      expect(RecipeSearchService.search(recipes, [], '', 'strict').length).assertEqual(5);
      expect(RecipeSearchService.search(recipes, [' '], '', 'survival').length).assertEqual(0);
      expect(RecipeSearchService.search(recipes, [], '煮锅', 'loose').length).assertEqual(2);
    });

    it('pantry matches real aliases in both directions', 0, () => {
      expect(hasIngredient('西红柿', [' 番茄 '])).assertTrue();
      expect(hasIngredient('土豆', ['马铃薯'])).assertTrue();
      expect(hasIngredient('马铃薯', ['土豆'])).assertTrue();
      expect(hasIngredient('', [''])).assertFalse();
    });

    it('pantry does not confuse substrings categories or raw and cooked food', 0, () => {
      expect(hasIngredient('蚝油', ['油'])).assertFalse();
      expect(hasIngredient('鸡肉', ['肉'])).assertFalse();
      expect(hasIngredient('鸡翅', ['鸡胸肉'])).assertFalse();
      expect(hasIngredient('米饭', ['米'])).assertFalse();
      expect(hasIngredient('西兰花', ['花菜'])).assertFalse();
    });

    it('shopping list and survival agree on every candidate', 0, () => {
      const available = ['番茄', '鸡蛋'];
      const ready = RecipeSearchService.search(recipes, available, '', 'survival');
      for (const recipe of recipes) {
        if (recipe.stuff.length > 0) {
          const missing = ShoppingListService.diff(available, recipe.stuff).missingItems;
          expect(ready.some((item: RecipeWithId): boolean => item.id === recipe.id)).assertEqual(missing.length === 0);
        }
      }
      const shopping = ShoppingListService.diff(['油', '番茄'], ['蚝油', '西红柿'], { '蚝油': '10ml' });
      expect(shopping.missingItems.length).assertEqual(1);
      expect(shopping.missingItems[0].amount).assertEqual('10ml');
      expect(shopping.matchedItems[0]).assertEqual('西红柿');
    });
  });
}
