/**
 * 菜谱卡片组件 - 支持大图和小图两种模式
 * 对应原型中的菜谱卡片样式
 */
import { AppColors, ThemeManager } from '../constants/AppColors'
import type { RecipeWithId } from '../model/recipe'
import type { Difficulty, NutriScore } from '../model/recipe'
import { RecipeImage, RecipeImageVariant } from './RecipeImage'
import { getRecipeEmoji } from '../data/foodCatalog'
import { calcNutriScore, getNutriScoreColors } from '../service/NutritionCalculator'
import type { NutriScoreColors } from '../service/NutritionCalculator'

export enum RecipeCardMode {
  LARGE = 'large',  // 大图模式(原型中的第一张卡片)
  SMALL = 'small'   // 小图模式(原型中的第二张卡片)
}

/** 难度标签颜色映射 */
function difficultyColor(d: Difficulty | '' | undefined, themeMode: string): string {
  if (d === '简单') return ThemeManager.getColor('#22C55E', AppColors.DARK_VEG_TEXT, themeMode)
  if (d === '中等') return ThemeManager.getColor('#F59E0B', AppColors.DARK_CARB_TEXT, themeMode)
  if (d === '较难') return ThemeManager.getColor('#EF4444', AppColors.DARK_MEAT_TEXT, themeMode)
  return ThemeManager.getColor(AppColors.GRAY_400, AppColors.DARK_GRAY_400, themeMode)
}

function difficultyBg(d: Difficulty | '' | undefined, themeMode: string): string {
  if (d === '简单') return ThemeManager.getColor('#F0FDF4', AppColors.DARK_VEG_BG, themeMode)
  if (d === '中等') return ThemeManager.getColor('#FFFBEB', AppColors.DARK_CARB_BG, themeMode)
  if (d === '较难') return ThemeManager.getColor('#FEF2F2', AppColors.DARK_MEAT_BG, themeMode)
  return ThemeManager.getColor(AppColors.GRAY_100, AppColors.DARK_GRAY_100, themeMode)
}

@Component
export struct RecipeCard {
  @Prop recipe: RecipeWithId
  @Prop mode: RecipeCardMode = RecipeCardMode.LARGE
  @Prop isFavorite: boolean = false

  onCardClick?: () => void
  onFavoriteClick?: () => void

  @State scaleValue: number = 1.0
  @State favoriteScaleValue: number = 1.0

  // ── 深色模式响应式订阅 ──────────────────────────────────────────────────────
  @StorageProp('isSystemDarkMode')
  @Watch('onThemeChange')
  private isSystemDark: boolean = false

  @StorageProp('currentThemeMode')
  @Watch('onThemeChange')
  private storedThemeMode: string = '系统默认'

  @State private cardBg: string = AppColors.CARD_BG
  @State private textPrimary: string = AppColors.GRAY_900
  @State private textSecondary: string = AppColors.GRAY_500
  @State private textTertiary: string = AppColors.GRAY_400
  @State private softBg: string = AppColors.GRAY_100

  private onThemeChange(): void {
    this.applyTheme()
  }

  private applyTheme(): void {
    this.cardBg = ThemeManager.getCardBackgroundColor(this.storedThemeMode)
    this.textPrimary = ThemeManager.getTextColor(this.storedThemeMode)
    this.textSecondary = ThemeManager.getSecondaryTextColor(this.storedThemeMode)
    this.textTertiary = ThemeManager.getColor(AppColors.GRAY_400, AppColors.DARK_GRAY_400, this.storedThemeMode)
    this.softBg = ThemeManager.getBorderColor(this.storedThemeMode)
  }

  aboutToAppear(): void {
    this.applyTheme()
  }

  private pulseFavorite(): void {
    this.favoriteScaleValue = 1.2
    setTimeout(() => {
      this.favoriteScaleValue = 1.0
    }, 100)
  }

  /** 是否有营养数据（仓库加载后所有菜谱都应命中估算或预置值） */
  private hasNutriScore(): boolean {
    return this.recipe.nutrition !== undefined
  }

  private nutriScoreText(): string {
    if (this.recipe.nutrition === undefined) {
      return ''
    }
    return calcNutriScore(this.recipe.nutrition, this.recipe.tags ?? [])
  }

  private nutriScoreColors(): NutriScoreColors {
    return getNutriScoreColors(this.nutriScoreText() as NutriScore)
  }

  /**
   * 大图模式卡片
   */
  @Builder
  buildLargeCard() {
    Column() {
      // 顶部大图区域
      Stack() {
        // 图片显示区域（有图显示图片，无图/坏图回退 emoji）
        RecipeImage({
          imageKey: this.recipe.imageUri ?? '',
          emoji: getRecipeEmoji(this.recipe.stuff ?? []),
          variant: RecipeImageVariant.CARD,
          placeholderBg: this.softBg
        })

        // 收藏按钮 (右上角)
        Column() {
          Text(this.isFavorite ? '★' : '☆')
            .fontSize(22)
            .fontColor(this.isFavorite ? AppColors.FAVORITE_ACTIVE : this.textTertiary)
            .scale({ x: this.favoriteScaleValue, y: this.favoriteScaleValue })
            .animation({ duration: 100, curve: Curve.EaseOut })
        }
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor(this.cardBg)
        .justifyContent(FlexAlign.Center)
        .shadow({
          radius: 4,
          color: 'rgba(0,0,0,0.08)',
          offsetX: 0,
          offsetY: 2
        })
        .position({ x: '100%', y: 0 })
        .markAnchor({ x: '100%', y: 0 })
        .translate({ x: -12, y: 12 })
        .hitTestBehavior(HitTestMode.Block)
        .zIndex(100)
        .onClick(() => {
          this.pulseFavorite()
          if (this.onFavoriteClick) {
            this.onFavoriteClick()
          }
        })

        // 营养评级（左下角，不遮挡收藏按钮）
        if (this.hasNutriScore()) {
          Text(`Nutri-Score ${this.nutriScoreText()}`)
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.nutriScoreColors().text)
            .backgroundColor(this.nutriScoreColors().bg)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .borderRadius(9)
            .position({ x: 0, y: '100%' })
            .markAnchor({ x: 0, y: '100%' })
            .translate({ x: 12, y: -12 })
            .zIndex(99)
        }
      }
      .width('100%')
      .height(160)
      .backgroundColor(Color.Transparent) // 背景由 RecipeImage 占位层提供
      .borderRadius({ topLeft: 20, topRight: 20 })
      .clip(true) // 裁切图片顶角，与卡片圆角对齐

      // 底部信息区域
      Column({ space: 8 }) {
        Text(this.recipe.name)
          .fontSize(18)
          .fontColor(this.textPrimary)
          .fontWeight(FontWeight.Bold)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        // 菜系 + 难度 + 烹饪方式标签行
        Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
          // 菜系标签（经典菜更有辨识度，暖色与难度/做法区分）
          if (this.recipe.cuisine) {
            Text(this.recipe.cuisine)
              .fontSize(11)
              .fontColor(ThemeManager.getColor('#B45309', '#FBBF24', this.storedThemeMode))
              .fontWeight(FontWeight.Medium)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor(ThemeManager.getColor('#FDF3E3', '#3A2A18', this.storedThemeMode))
              .borderRadius(6)
              .margin({ right: 6 })
          }
          // 难度标签（有值才显示）
          if (this.recipe.difficulty) {
            Text(this.recipe.difficulty)
              .fontSize(11)
              .fontColor(difficultyColor(this.recipe.difficulty, this.storedThemeMode))
              .fontWeight(FontWeight.Medium)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor(difficultyBg(this.recipe.difficulty, this.storedThemeMode))
              .borderRadius(6)
              .margin({ right: 6 })
          }
          // 烹饪方式标签（有值才显示，最多展示3个）
          if (this.recipe.methods && this.recipe.methods.length > 0) {
            ForEach(this.recipe.methods.slice(0, 3), (method: string) => {
              Text(method)
                .fontSize(11)
                .fontColor(ThemeManager.getColor('#6366F1', '#A5B4FC', this.storedThemeMode))
                .fontWeight(FontWeight.Medium)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .backgroundColor(this.softBg)
                .borderRadius(6)
                .margin({ right: 6 })
            })
          }
        }
        .width('100%')
      }
      .width('100%')
      .padding(16)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .backgroundColor(this.cardBg)
    .borderRadius(20)
    .shadow({
      radius: 8,
      color: 'rgba(0,0,0,0.05)',
      offsetX: 0,
      offsetY: 2
    })
    .scale({ x: this.scaleValue, y: this.scaleValue })
    .animation({
      duration: 150,
      curve: Curve.EaseOut
    })
  }

  /**
   * 小图模式卡片
   */
  @Builder
  buildSmallCard() {
    Row({ space: 12 }) {
      // 左侧图片/Emoji
      RecipeImage({
        imageKey: this.recipe.imageUri ?? '',
        emoji: getRecipeEmoji(this.recipe.stuff ?? []),
        variant: RecipeImageVariant.THUMB,
        placeholderBg: this.softBg,
        cornerRadius: 12
      })
      .width(72)
      .height(72)
      .flexShrink(0)

      // 中间信息区
      Column({ space: 6 }) {
        Text(this.recipe.name)
          .fontSize(15)
          .fontColor(this.textPrimary)
          .fontWeight(FontWeight.Bold)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        // 菜系 + 难度 + 烹饪方式标签行
        Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
          if (this.recipe.cuisine) {
            Text(this.recipe.cuisine)
              .fontSize(11)
              .fontColor(ThemeManager.getColor('#B45309', '#FBBF24', this.storedThemeMode))
              .fontWeight(FontWeight.Medium)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor(ThemeManager.getColor('#FDF3E3', '#3A2A18', this.storedThemeMode))
              .borderRadius(4)
              .margin({ right: 6, bottom: 4 })
          }
          if (this.recipe.difficulty) {
            Text(this.recipe.difficulty)
              .fontSize(11)
              .fontColor(difficultyColor(this.recipe.difficulty, this.storedThemeMode))
              .fontWeight(FontWeight.Medium)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor(difficultyBg(this.recipe.difficulty, this.storedThemeMode))
              .borderRadius(4)
              .margin({ right: 6, bottom: 4 })
          }
          if (this.recipe.methods && this.recipe.methods.length > 0) {
            ForEach(this.recipe.methods.slice(0, 2), (method: string) => {
              Text(method)
                .fontSize(11)
                .fontColor(ThemeManager.getColor('#6366F1', '#A5B4FC', this.storedThemeMode))
                .fontWeight(FontWeight.Medium)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor(this.softBg)
                .borderRadius(4)
                .margin({ right: 6, bottom: 4 })
            })
          }
          if (!this.recipe.difficulty && (!this.recipe.methods || this.recipe.methods.length === 0)) {
            Text(`${this.recipe.stuff.length} 种食材`)
              .fontSize(11)
              .fontColor(this.textSecondary)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor(this.softBg)
              .borderRadius(4)
          }
          // 小图卡片同样给出营养评级，避免要点进详情才知道
          if (this.hasNutriScore()) {
            Text(`Nutri-Score ${this.nutriScoreText()}`)
              .fontSize(10)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.nutriScoreColors().text)
              .backgroundColor(this.nutriScoreColors().bg)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(4)
              .margin({ right: 6, bottom: 4 })
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)

      // 右侧收藏按钮（in-flow，不遮挡文字）
      Column() {
        Text(this.isFavorite ? '★' : '☆')
          .fontSize(20)
          .fontColor(this.isFavorite ? AppColors.FAVORITE_ACTIVE : this.textTertiary)
          .scale({ x: this.favoriteScaleValue, y: this.favoriteScaleValue })
          .animation({ duration: 100, curve: Curve.EaseOut })
      }
      .width(36)
      .height(36)
      .borderRadius(18)
      .backgroundColor(this.softBg)
      .justifyContent(FlexAlign.Center)
      .flexShrink(0)
      .hitTestBehavior(HitTestMode.Block)
      .onClick(() => {
        this.pulseFavorite()
        if (this.onFavoriteClick) {
          this.onFavoriteClick()
        }
      })
    }
    .width('100%')
    .padding(12)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.cardBg)
    .borderRadius(16)
    .shadow({
      radius: 4,
      color: 'rgba(0,0,0,0.05)',
      offsetX: 0,
      offsetY: 2
    })
    .scale({ x: this.scaleValue, y: this.scaleValue })
    .animation({
      duration: 150,
      curve: Curve.EaseOut
    })
  }

  build() {
    Column() {
      if (this.mode === RecipeCardMode.LARGE) {
        this.buildLargeCard()
      } else {
        this.buildSmallCard()
      }
    }
    .width('100%')
    // 打开详情改用内置 onClick：它参与 List/Scroll 的手势仲裁，
    // 列表滑动过程中不会触发点击；此前手写 onTouch 判定滑距，
    // 与滚动容器抢事件，导致列表滑动时误开菜品详情。
    .onClick(() => {
      if (this.onCardClick) {
        this.onCardClick()
      }
    })
    .onTouch((event) => {
      if (event.type === TouchType.Down) {
        this.scaleValue = 0.98
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.scaleValue = 1.0
      }
    })
    .hitTestBehavior(HitTestMode.Default) // 确保整个卡片区域都可点击
  }
}

