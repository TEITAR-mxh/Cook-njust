import { common } from '@kit.AbilityKit'
import { util } from '@kit.ArkTS'
import { RecipeRepository } from '../data/RecipeRepository'
import type { RecipeWithId } from '../model/recipe'
import { CookPreferences } from '../store/CookPreferences'
import { AppColors, ThemeManager } from '../constants/AppColors'
import { RecipeImage, RecipeImageVariant } from '../components/RecipeImage'
import { RecipeDetailSheet } from '../components/RecipeDetailSheet'
import { ToastView } from '../components/ToastView'
import { getRecipeEmoji } from '../data/foodCatalog'
import { getSystemSafeTopVp } from '../util/StatusBarInset'

// ══════════════════════════════════════════════════════════════════════════════
// 菜系经典页
// 数据来自 rawfile/cuisine_classics.json（scripts/build_cuisine_tags.py 生成）：
// 每个菜系一段简介 + 人工排序的 5 道经典菜（id 为 RecipeDBManager 使用的 0 基下标）。
// 左侧为菜系竖向索引，右侧展示当前菜系的简介与经典菜排行；
// 点任意一道菜直接打开菜谱详情，形成「菜系 → 经典菜 → 做法」的浏览闭环。
// ══════════════════════════════════════════════════════════════════════════════

interface CuisineDish {
  id: number
  name: string
}

interface CuisineSection {
  name: string
  emoji: string
  tagline: string
  description: string
  count: number
  dishes: CuisineDish[]
}

interface CuisineFile {
  cuisines: CuisineSection[]
}

const RAW_NAME = 'cuisine_classics.json'

@Entry
@Component
struct CuisinePage {
  @State private sections: CuisineSection[] = []
  @State private selectedIndex: number = 0
  @State private selectedRecipe: RecipeWithId | null = null
  @State private detailSheetVisible: boolean = false
  @State private favoriteIds: number[] = []
  @State private selectedStuff: string[] = []
  @State private toastMessage: string = ''
  @State private toastVisible: boolean = false
  @State private topInset: number = 48

  private rightScroller: Scroller = new Scroller()

  // ── 深色模式响应式订阅 ──────────────────────────────────────────────────────
  @StorageProp('isSystemDarkMode')
  @Watch('onThemeChange')
  private isSystemDark: boolean = false

  @StorageProp('currentThemeMode')
  @Watch('onThemeChange')
  private storedThemeMode: string = '系统默认'

  @State private bgColor: string = AppColors.BG_COLOR
  @State private cardBg: string = AppColors.CARD_BG
  @State private textColor: string = AppColors.GRAY_900
  @State private secondColor: string = AppColors.GRAY_500
  @State private dividerColor: string = AppColors.GRAY_100
  @State private brandTint: string = AppColors.BRAND_COLOR_LIGHT

  private onThemeChange(): void {
    this.applyTheme()
  }

  private applyTheme(): void {
    this.bgColor = ThemeManager.getBackgroundColor(this.storedThemeMode)
    this.cardBg = ThemeManager.getCardBackgroundColor(this.storedThemeMode)
    this.textColor = ThemeManager.getTextColor(this.storedThemeMode)
    this.secondColor = ThemeManager.getSecondaryTextColor(this.storedThemeMode)
    this.dividerColor = ThemeManager.getBorderColor(this.storedThemeMode)
    this.brandTint = ThemeManager.getColor('#FFF1F2', '#241417', this.storedThemeMode)
  }

  aboutToAppear(): void {
    this.applyTheme()
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (host) {
      void getSystemSafeTopVp(host).then((vp: number) => { this.topInset = vp })
    }
    void this.load()
  }

  onPageShow(): void {
    void this.loadUserState()
  }

  private async load(): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (!host) return
    try {
      const repo = RecipeRepository.getInstance()
      if (repo.getCount() === 0) await repo.load(host)

      const raw: Uint8Array | ArrayBuffer = await host.resourceManager.getRawFileContent(RAW_NAME)
      const bytes: Uint8Array = raw instanceof Uint8Array ? raw : new Uint8Array(raw)
      const text: string = new util.TextDecoder('utf-8').decodeToString(bytes)
      const parsed = JSON.parse(text) as CuisineFile
      // 只保留能在仓库中找到的菜，避免旧数据下标失效导致详情打不开
      const valid: CuisineSection[] = []
      for (let i = 0; i < parsed.cuisines.length; i++) {
        const section = parsed.cuisines[i]
        const dishes: CuisineDish[] = []
        for (let j = 0; j < section.dishes.length; j++) {
          if (repo.getById(section.dishes[j].id) !== null) {
            dishes.push(section.dishes[j])
          }
        }
        if (dishes.length > 0) {
          const item: CuisineSection = {
            name: section.name,
            emoji: section.emoji,
            tagline: section.tagline,
            description: section.description,
            count: section.count,
            dishes: dishes
          }
          valid.push(item)
        }
      }
      this.sections = valid
      if (this.selectedIndex >= this.sections.length) {
        this.selectedIndex = 0
      }
      await this.loadUserState()
    } catch (e) {
      console.error(`[CuisinePage] 加载失败: ${JSON.stringify(e)}`)
    }
  }

  private async loadUserState(): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (!host) return
    try {
      this.favoriteIds = await CookPreferences.getFavoriteIds(host)
      this.selectedStuff = await CookPreferences.getSelectedStuff(host)
    } catch (e) {
      console.error(`[CuisinePage] 用户状态加载失败: ${JSON.stringify(e)}`)
    }
  }

  private isFavorite(id: number): boolean {
    return this.favoriteIds.includes(id)
  }

  private onTapFavorite(recipeId: number): void {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (!host) return
    const wasFavorite = this.isFavorite(recipeId)
    void CookPreferences.toggleFavoriteId(host, recipeId).then(() => {
      void this.loadUserState()
      if (wasFavorite) this.showToast('已取消收藏')
    })
  }

  private showToast(msg: string): void {
    this.toastMessage = msg
    this.toastVisible = true
    setTimeout(() => { this.toastVisible = false }, 2000)
  }

  private openDish(dish: CuisineDish): void {
    const recipe = RecipeRepository.getInstance().getById(dish.id)
    if (recipe === null) {
      this.showToast('菜谱数据加载中，请稍后再试')
      return
    }
    this.selectedRecipe = recipe
    this.detailSheetVisible = true
  }

  /** 左侧索引只做锚点跳转，右侧始终是一条连续的全部菜系流 */
  private selectCuisine(index: number): void {
    if (index < 0 || index >= this.sections.length) return
    this.selectedIndex = index
    this.rightScroller.scrollToIndex(index, true, ScrollAlign.START)
  }

  private syncRailWithScroll(start: number): void {
    if (start >= 0 && start < this.sections.length && start !== this.selectedIndex) {
      this.selectedIndex = start
    }
  }

  private dishCalories(id: number): string {
    const r = RecipeRepository.getInstance().getById(id)
    if (r === null || r.nutrition === undefined) return ''
    return `${Math.round(r.nutrition.calories)} kcal`
  }

  private dishDifficulty(id: number): string {
    const r = RecipeRepository.getInstance().getById(id)
    return r?.difficulty ?? ''
  }

  private rankColor(index: number): string {
    if (index === 0) return ThemeManager.getColor('#B45309', '#FBBF24', this.storedThemeMode)
    if (index === 1) return ThemeManager.getColor('#64748B', '#CBD5E1', this.storedThemeMode)
    if (index === 2) return ThemeManager.getColor('#C2410C', '#FDBA74', this.storedThemeMode)
    return this.secondColor
  }

  private rankBg(index: number): string {
    if (index === 0) return ThemeManager.getColor('#FEF3C7', '#3A2A18', this.storedThemeMode)
    if (index === 1) return ThemeManager.getColor('#F1F5F9', '#26303C', this.storedThemeMode)
    if (index === 2) return ThemeManager.getColor('#FFEDD5', '#3A2518', this.storedThemeMode)
    return Color.Transparent.toString()
  }

  // ── 顶部装饰说明 ──────────────────────────────────────────────────────────
  @Builder
  IntroBanner() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Text('🥢')
        .fontSize(74)
        .opacity(0.14)
        .margin({ right: 4, bottom: -16 })

      Column({ space: 5 }) {
        Text('寻味中华')
          .fontSize(19)
          .fontWeight(FontWeight.Bolder)
          .fontColor(this.textColor)
          .letterSpacing(-0.3)
          .textAlign(TextAlign.Center)
        Text('一方水土一味菜，循着菜系挑一道经典')
          .fontSize(11)
          .fontColor(this.secondColor)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    }
    .width('100%')
    .borderRadius(20)
    .clip(true)
    .linearGradient({ angle: 135, colors: [[this.brandTint, 0.0], [this.cardBg, 1.0]] })
    .margin({ left: 24, right: 24, top: 8, bottom: 10 })
  }

  // ── 左侧菜系索引 ──────────────────────────────────────────────────────────
  @Builder
  CuisineRail() {
    List({ space: 3 }) {
      ForEach(this.sections, (section: CuisineSection, index: number) => {
        ListItem() {
          Column({ space: 2 }) {
            Text(section.emoji).fontSize(17)
            Text(section.name)
              .fontSize(10)
              .fontWeight(this.selectedIndex === index ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(this.selectedIndex === index ? Color.White : this.secondColor)
              .maxLines(1)
          }
          .width(48)
          .padding({ top: 7, bottom: 7 })
          .borderRadius(12)
          .backgroundColor(this.selectedIndex === index ? AppColors.BRAND_COLOR : Color.Transparent)
          .onClick(() => { this.selectCuisine(index) })
        }
      }, (section: CuisineSection) => `rail-${section.name}`)
    }
    .width(52)
    .height('100%')
    .padding({ left: 2, right: 2, top: 4 })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  // ── 右侧菜系内容：简介 + 经典菜排行 ──────────────────────────────────────
  @Builder
  CuisineBlock(section: CuisineSection) {
    Column({ space: 12 }) {
      Column({ space: 3 }) {
        Row({ space: 8 }) {
          Text(section.emoji).fontSize(24)
          Text(section.name)
            .fontSize(23)
            .fontWeight(FontWeight.Bolder)
            .fontColor(this.textColor)
            .letterSpacing(-0.4)
          Text(`经典 ${section.dishes.length} 道`)
            .fontSize(10)
            .fontColor(AppColors.BRAND_COLOR)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor(this.isSystemDark || this.storedThemeMode === '深色模式'
              ? '#2A1215' : AppColors.BRAND_COLOR_LIGHT)
            .borderRadius(20)
        }
        .alignItems(VerticalAlign.Center)

        Text(section.tagline)
          .fontSize(12)
          .fontColor(this.secondColor)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Text(section.description)
        .fontSize(12)
        .lineHeight(19)
        .fontColor(this.secondColor)
        .width('100%')

      Column({ space: 10 }) {
        ForEach(section.dishes, (dish: CuisineDish, index: number) => {
          this.DishCard(dish, index)
        }, (dish: CuisineDish) => `dish-${dish.id}`)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // ── 经典菜卡片 ────────────────────────────────────────────────────────────
  @Builder
  DishCard(dish: CuisineDish, index: number) {
    Row({ space: 12 }) {
      Text(`${index + 1}`)
        .fontSize(index < 3 ? 14 : 13)
        .fontWeight(index < 3 ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.rankColor(index))
        .width(28)
        .height(28)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.rankBg(index))
        .borderRadius(14)
        .flexShrink(0)

      RecipeImage({
        imageKey: RecipeRepository.getInstance().getById(dish.id)?.imageUri ?? '',
        emoji: getRecipeEmoji(RecipeRepository.getInstance().getById(dish.id)?.stuff ?? []),
        variant: RecipeImageVariant.THUMB,
        placeholderBg: this.dividerColor,
        cornerRadius: 10
      })
      .width(54)
      .height(54)
      .flexShrink(0)

      Column({ space: 4 }) {
        Text(dish.name)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.textColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row({ space: 8 }) {
          if (this.dishDifficulty(dish.id).length > 0) {
            Text(this.dishDifficulty(dish.id))
              .fontSize(11)
              .fontColor(this.secondColor)
          }
          if (this.dishCalories(dish.id).length > 0) {
            Text(this.dishCalories(dish.id))
              .fontSize(11)
              .fontColor(this.rankColor(index))
          }
        }
        .alignItems(VerticalAlign.Center)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(13)
        .fontColor([this.secondColor])
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .backgroundColor(this.cardBg)
    .borderRadius(16)
    .shadow({ radius: 8, color: 'rgba(0,0,0,0.04)', offsetX: 0, offsetY: 2 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => { this.openDish(dish) })
  }

  @Builder
  DetailSheetBuilder() {
    if (this.selectedRecipe) {
      RecipeDetailSheet({
        recipe: this.selectedRecipe,
        selectedStuff: this.selectedStuff,
        isFavorite: this.isFavorite(this.selectedRecipe.id),
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

          Text('菜系经典')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Blank().width(64)
        }
        .width('100%')
        .padding({ top: this.topInset, bottom: 4 })

        if (this.sections.length === 0) {
          Column({ space: 12 }) {
            Text('🍽').fontSize(48)
            Text('菜系数据加载中…')
              .fontSize(14)
              .fontColor(this.secondColor)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          this.IntroBanner()

          Row() {
            this.CuisineRail()

            Column()
              .width(0.5)
              .height('100%')
              .backgroundColor(this.dividerColor)
              .margin({ top: 8, bottom: 8 })

            List({ space: 16, scroller: this.rightScroller }) {
              ForEach(this.sections, (section: CuisineSection) => {
                ListItem() {
                  this.CuisineBlock(section)
                }
              }, (section: CuisineSection) => `panel-${section.name}`)

              ListItem() {
                Text('经典排序为人工整理，更多菜谱可在「菜谱」页按菜系标签查找')
                  .fontSize(11)
                  .fontColor(this.secondColor)
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .padding({ top: 4, bottom: 28 })
              }
            }
            .layoutWeight(1)
            .height('100%')
            .padding({ left: 10, right: 16, top: 8 })
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
            .onScrollIndex((start: number) => { this.syncRailWithScroll(start) })
          }
          .width('100%')
          .layoutWeight(1)
          .alignItems(VerticalAlign.Top)
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
      height: SheetSize.LARGE,
      dragBar: false,
      backgroundColor: Color.Transparent,
      showClose: false,
      preferType: SheetType.BOTTOM
    })
  }
}
