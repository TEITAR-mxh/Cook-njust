import { common } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI'
import { RecipeRepository } from '../data/RecipeRepository'
import type { RecipeWithId } from '../model/recipe'
import { CookPreferences, FolderItem } from '../store/CookPreferences'
import { AppColors } from '../constants/AppColors'
import { RecipeCard, RecipeCardMode } from '../components/RecipeCard'
import { RecipeDetailSheet } from '../components/RecipeDetailSheet'
import { getSystemSafeTopVp } from '../util/StatusBarInset'

interface RouterParams {
  folderId: string
}

@Entry
@Component
struct FolderDetailPage {
  @State folder: FolderItem | null = null
  @State recipes: RecipeWithId[] = []
  @State favoriteIds: number[] = []
  @State topInset: number = 48
  @State detailSheetVisible: boolean = false
  @State selectedRecipe: RecipeWithId | null = null

  aboutToAppear() {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (host) {
      void getSystemSafeTopVp(host).then((vp: number) => { this.topInset = vp })
    }
    const params = router.getParams() as RouterParams
    if (params?.folderId) {
      void this.load(params.folderId)
    }
    void this.refreshFavorites()
  }

  onPageShow() {
    if (this.folder) {
      void this.load(this.folder.id)
    }
    void this.refreshFavorites()
  }

  private async load(folderId: string): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (!host) return
    const folders = await CookPreferences.getFolders(host)
    const found = folders.find(f => f.id === folderId)
    if (!found) return
    this.folder = found
    const repo = RecipeRepository.getInstance()
    const list: RecipeWithId[] = []
    for (const id of found.recipeIds) {
      const r = repo.getById(id)
      if (r) list.push(r)
    }
    this.recipes = list
  }

  private async refreshFavorites(): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (!host) return
    try {
      const ids = await CookPreferences.getFavoriteIds(host)
      const n = RecipeRepository.getInstance().getCount()
      this.favoriteIds = ids.filter(id => id >= 0 && id < n)
    } catch { }
  }

  private isRecipeFavorite(id: number): boolean {
    return this.favoriteIds.includes(id)
  }

  private onTapFavorite(recipeId: number): void {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (!host) return
    const wasFavorite = this.isRecipeFavorite(recipeId)
    void CookPreferences.toggleFavoriteId(host, recipeId).then(async () => {
      await this.refreshFavorites()
      // toggleFavoriteId 已内联处理收藏夹移除，这里只需刷新页面列表
      if (wasFavorite && this.folder) {
        await this.load(this.folder.id)
      }
    })
  }

  @Builder
  DetailSheetBuilder() {
    if (this.selectedRecipe) {
      RecipeDetailSheet({
        recipe: this.selectedRecipe,
        selectedStuff: [],
        isFavorite: this.isRecipeFavorite(this.selectedRecipe.id),
        onFavoriteToggle: () => {
          if (this.selectedRecipe) this.onTapFavorite(this.selectedRecipe.id)
        },
        onRequestClose: () => { this.detailSheetVisible = false }
      })
    }
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(20).fontColor([AppColors.GRAY_600])
            Text('返回').fontSize(16).fontColor(AppColors.GRAY_600)
          }
          .padding({ left: 16, right: 12, top: 8, bottom: 8 })
          .onClick(() => this.getUIContext().getRouter().back())

          Text(this.folder?.name ?? '收藏夹')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.GRAY_900)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Row().width(80)
        }
        .width('100%')
        .padding({ top: this.topInset, bottom: 4 })

        if (this.recipes.length === 0) {
          Column({ space: 12 }) {
            Text('📂').fontSize(56)
            Text('收藏夹还是空的').fontSize(16).fontColor(AppColors.GRAY_500)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column({ space: 12 }) {
              Text(`共 ${this.recipes.length} 道菜`)
                .fontSize(13)
                .fontColor(AppColors.GRAY_500)
                .alignSelf(ItemAlign.Start)
                .padding({ left: 16 })

              ForEach(this.recipes, (recipe: RecipeWithId) => {
                RecipeCard({
                  recipe: recipe,
                  mode: RecipeCardMode.SMALL,
                  isFavorite: this.isRecipeFavorite(recipe.id),
                  onCardClick: () => {
                    this.selectedRecipe = recipe
                    this.detailSheetVisible = true
                  },
                  onFavoriteClick: () => this.onTapFavorite(recipe.id)
                })
              }, (r: RecipeWithId) => `folder-recipe-${r.id}`)
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 8, bottom: 100 })
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
