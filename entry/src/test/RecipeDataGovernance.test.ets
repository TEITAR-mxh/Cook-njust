import { describe, it, expect } from '@ohos/hypium';
import { sanitizeStringArray, sha256HexOfBytes } from '../main/ets/data/RecipeDBManager';
import { sliceRecipeIds } from '../main/ets/store/CookPreferences';

export default function recipeDataGovernanceTest() {
  describe('RecipeDataGovernanceTest', () => {
    it('sanitizeStringArray preserves full cooking methods', 0, () => {
      const methods = sanitizeStringArray([' 炒 ', '', '蒸', '炸/煎', 1 as Object as string]);
      expect(methods.length).assertEqual(3);
      expect(methods[0]).assertEqual('炒');
      expect(methods[1]).assertEqual('蒸');
      expect(methods[2]).assertEqual('炸/煎');
    });

    it('sliceRecipeIds supports paged favorites queries', 0, () => {
      const page = sliceRecipeIds([9, 8, 7, 6, 5], 1, 3);
      expect(page.length).assertEqual(3);
      expect(page[0]).assertEqual(8);
      expect(page[2]).assertEqual(6);
      expect(sliceRecipeIds([1, 2], 5, 2).length).assertEqual(0);
    });

    it('sha256HexOfBytes is stable for bundle diff checks', 0, async () => {
      const bytes = new Uint8Array([65, 85, 86, 45, 67, 79, 79, 75]);
      const first = await sha256HexOfBytes(bytes);
      const second = await sha256HexOfBytes(bytes);
      expect(first.length > 0).assertTrue();
      expect(first).assertEqual(second);
    });
  });
}
