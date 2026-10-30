import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { RecipeRepository } from '../data/RecipeRepository';
import type { RecipeWithId } from '../model/recipe';
import { CookPreferences } from '../store/CookPreferences';
import { AppColors, ThemeManager } from '../constants/AppColors';
import { RecipeCard, RecipeCardMode } from '../components/RecipeCard';
import { RecipeDetailSheet } from '../components/RecipeDetailSheet';
import { ToastView } from '../components/ToastView';
import { getSystemSafeTopVp } from '../util/StatusBarInset';

@Entry
@Component
struct FavoritesPage {
  @State recipes: RecipeWithId[] = []
  @State favoriteIds: number[] = []
  @State selectedStuff: string[] = []
  @State topInset: number = 48
  @State detailSheetVisible: boolean = false
  @State selectedRecipe: RecipeWithId | null = null
  @State toastMessage: string = ''
  @State toastVisible: boolean = false

  // ── 深色模式响应式订阅 ──────────────────────────────────────────────────────
  @StorageProp('isSystemDarkMode')
  @Watch('onThemeChange')
  private isSystemDark: boolean = false

  @StorageProp('currentThemeMode')
  @Watch('onThemeChange')
  private storedThemeMode: string = '系统默认'

  @State private bgColor: string = AppColors.BG_COLOR
  @State private textColor: string = AppColors.GRAY_900
  @State private secondColor: string = AppColors.GRAY_500

  private onThemeChange(): void {
    this.applyTheme()
  }

  private applyTheme(): void {
    this.bgColor = ThemeManager.getBackgroundColor(this.storedThemeMode)
    this.textColor = ThemeManager.getTextColor(this.storedThemeMode)
    this.secondColor = ThemeManager.getSecondaryTextColor(this.storedThemeMode)
  }

  aboutToAppear() {
    this.applyTheme()
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
      this.selectedStuff = await CookPreferences.getSelectedStuff(host);
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

  private confirmClearAll(): void {
    this.getUIContext().showAlertDialog({
      title: '清空收藏',
      message: '确定要移除全部收藏吗？此操作无法撤销。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '清空',
        fontColor: AppColors.BRAND_COLOR,
        action: () => { void this.clearAll() }
      },
      autoCancel: true
    })
  }

  private isRecipeFavorite(id: number): boolean {
    return this.favoriteIds.includes(id);
  }

  private onTapFavorite(recipeId: number): void {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!host) return;
    const wasFavorite = this.isRecipeFavorite(recipeId);
    void CookPreferences.toggleFavoriteId(host, recipeId).then(() => {
      void this.load();
      if (wasFavorite) this.showToast('已取消收藏');
    });
  }

  private showToast(msg: string): void {
    this.toastMessage = msg;
    this.toastVisible = true;
    setTimeout(() => { this.toastVisible = false }, 2000);
  }

  @Builder
  DetailSheetBuilder() {
    if (this.selectedRecipe) {
      RecipeDetailSheet({
        recipe: this.selectedRecipe,
        selectedStuff: this.selectedStuff,
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
              .fontColor([this.secondColor])
            Text('返回')
              .fontSize(16)
              .fontColor(this.secondColor)
          }
          .padding({ left: 16, right: 12, top: 8, bottom: 8 })
          .onClick(() => this.getUIContext().getRouter().back())

          Text('收藏')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Row() {
            if (this.recipes.length > 0) {
              Text('清空')
                .fontSize(15)
                .fontColor(AppColors.BRAND_COLOR)
                .onClick(() => { this.confirmClearAll() })
            }
          }.width(56).justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .padding({ top: this.topInset, bottom: 4 })

        // 内容区
        if (this.recipes.length === 0) {
          Column({ space: 12 }) {
            Text('☆')
              .fontSize(56)
              .fontColor(this.secondColor)
            Text('还没有收藏')
              .fontSize(16)
              .fontColor(this.secondColor)
            Button('去发现菜谱')
              .fontSize(14)
              .fontColor(Color.White)
              .backgroundColor(AppColors.BRAND_COLOR)
              .borderRadius(20)
              .height(40)
              .padding({ left: 24, right: 24 })
              .margin({ top: 8 })
              .onClick(() => this.getUIContext().getRouter().back())
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
            .padding({ left: 20, right: 20, top: 8, bottom: 40 })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.bgColor)

      ToastView({ message: this.toastMessage, visible: this.toastVisible })
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.detailSheetVisible, this.DetailSheetBuilder(), {
      // 固定单档全屏高度，避免上滑切档时整页淡出
      height: SheetSize.LARGE,
      dragBar: false,
      backgroundColor: Color.Transparent,
      showClose: false,
      preferType: SheetType.BOTTOM
    })
  }
}
