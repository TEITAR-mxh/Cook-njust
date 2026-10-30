import localUnitTest from './LocalUnit.test';
import recipeDataGovernanceTest from './RecipeDataGovernance.test';
import recipeSearchTest from './RecipeSearch.test';

export default function testsuite() {
  localUnitTest();
  recipeDataGovernanceTest();
  recipeSearchTest();
}
