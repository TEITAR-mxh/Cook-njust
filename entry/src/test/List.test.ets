import localUnitTest from './LocalUnit.test';
import recipeDataGovernanceTest from './RecipeDataGovernance.test';

export default function testsuite() {
  localUnitTest();
  recipeDataGovernanceTest();
}
