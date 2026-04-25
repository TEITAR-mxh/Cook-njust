import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { RecipeRepository } from '../data/RecipeRepository';
import type { RecipeWithId } from '../model/recipe';
import { CookPreferences } from '../store/CookPreferences';
import { AppColors } from '../constants/AppColors';
import { RecipeCard, RecipeCardMode } from '../components/RecipeCard';
import { RecipeDetailSheet } from '../components/RecipeDetailSheet';
import { getSystemSafeTopVp } from '../util/StatusBarInset';

@Entry
@Component
struct FavoritesPage {
  @State recipes: RecipeWithId[] = []
  @State favoriteIds: number[] = []
  @State topInset: number = 48
  @State detailSheetVisible: boolean = false
  @State selectedRecipe: RecipeWithId | null = null

  aboutToAppear() {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (host) {
      void getSystemSafeTopVp(host).then((vp: number) => { this.topInset = vp });
    }
    void this.load();
  }

  onPageShow() {
    void this.load();
  }

  private async load(): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!host) return;
    try {
      const repo = RecipeRepository.getInstance();
      if (repo.getCount() === 0) await repo.load(host);
      const ids = await CookPreferences.getFavoriteIds(host);
      const n = repo.getCount();
      const valid = ids.filter(id => id >= 0 && id < n);
      this.favoriteIds = valid;
      const recipeList: RecipeWithId[] = [];
      for (let i = 0; i < valid.length; i++) {
        const r = repo.getById(valid[i]);
        if (r !== null) recipeList.push(r);
      }
      this.recipes = recipeList;
    } catch { }
  }

  private async clearAll(): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!host) return;
    await CookPreferences.clearFavorites(host);
    this.recipes = [];
    this.favoriteIds = [];
  }

  private isRecipeFavorite(id: number): boolean {
    return this.favoriteIds.includes(id);
  }

  private onTapFavorite(recipeId: number): void {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!host) return;
    void CookPreferences.toggleFavoriteId(host, recipeId).then(() => {
      void this.load();
    });
  }

  @Builder
  DetailSheetBuilder() {
    if (this.selectedRecipe) {
      RecipeDetailSheet({
        recipe: this.selectedRecipe,
        selectedStuff: [],
        isFavorite: this.isRecipeFavorite(this.selectedRecipe.id),
        onFavoriteToggle: () => {
          if (this.selectedRecipe) this.onTapFavorite(this.selectedRecipe.id);
        },
        onRequestClose: () => { this.detailSheetVisible = false }
      })
    }
  }

  build() {
    Stack() {
      Column() {
        // 顶部导航
        Row() {
          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(20)
              .fontColor([AppColors.GRAY_600])
            Text('返回')
              .fontSize(16)
              .fontColor(AppColors.GRAY_600)
          }
          .padding({ left: 16, right: 12, top: 8, bottom: 8 })
          .onClick(() => this.getUIContext().getRouter().back())

          Text('收藏')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.GRAY_900)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Row() {
            if (this.recipes.length > 0) {
              Text('清空')
                .fontSize(15)
                .fontColor(AppColors.GRAY_400)
                .onClick(() => { void this.clearAll() })
            }
          }.width(56).justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .padding({ top: this.topInset, bottom: 4 })

        // 内容区
        if (this.recipes.length === 0) {
          Column({ space: 12 }) {
            Text('☆').fontSize(56)
            Text('还没有收藏').fontSize(16).fontColor(AppColors.GRAY_400)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column({ space: 12 }) {
              ForEach(this.recipes, (recipe: RecipeWithId) => {
                RecipeCard({
                  recipe: recipe,
                  mode: RecipeCardMode.SMALL,
                  isFavorite: this.isRecipeFavorite(recipe.id),
                  onCardClick: () => {
                    this.selectedRecipe = recipe;
                    this.detailSheetVisible = true;
                  },
                  onFavoriteClick: () => this.onTapFavorite(recipe.id)
                })
              }, (r: RecipeWithId) => `fav-${r.id}`)
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 8, bottom: 40 })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.BG_COLOR)
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.detailSheetVisible, this.DetailSheetBuilder(), {
      height: SheetSize.LARGE,
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      dragBar: false,
      backgroundColor: Color.Transparent,
      showClose: false,
      preferType: SheetType.BOTTOM
    })
  }
}
