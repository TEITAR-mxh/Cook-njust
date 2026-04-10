/**
 * 菜谱卡片组件 - 支持大图和小图两种模式
 * 对应原型中的菜谱卡片样式
 */
import { AppColors } from '../constants/AppColors'
import type { RecipeWithId } from '../model/recipe'
import type { Difficulty } from '../model/recipe'

export enum RecipeCardMode {
  LARGE = 'large',  // 大图模式(原型中的第一张卡片)
  SMALL = 'small'   // 小图模式(原型中的第二张卡片)
}

/** 难度标签颜色映射 */
function difficultyColor(d: Difficulty | '' | undefined): string {
  if (d === '简单') return '#22C55E'
  if (d === '普通') return '#F59E0B'
  if (d === '困难') return '#EF4444'
  return AppColors.GRAY_400
}

function difficultyBg(d: Difficulty | '' | undefined): string {
  if (d === '简单') return '#F0FDF4'
  if (d === '普通') return '#FFFBEB'
  if (d === '困难') return '#FEF2F2'
  return AppColors.GRAY_100
}

@Component
export struct RecipeCard {
  @Prop recipe: RecipeWithId
  @Prop mode: RecipeCardMode = RecipeCardMode.LARGE
  @Prop isFavorite: boolean = false

  onCardClick?: () => void
  onFavoriteClick?: () => void

  @State scaleValue: number = 1.0

  /**
   * 获取菜品 Emoji(如果有)
   */
  private getEmoji(): string {
    if (this.recipe.emojis && this.recipe.emojis.length > 0) {
      return this.recipe.emojis.join('')
    }
    return '🍽️'
  }

  /**
   * 大图模式卡片
   */
  @Builder
  buildLargeCard() {
    Column() {
      // 顶部大图区域
      Stack() {
        Column() {
          Text(this.getEmoji())
            .fontSize(60)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)

        // 收藏按钮 (右上角)
        Column() {
          Text(this.isFavorite ? '★' : '☆')
            .fontSize(24)
            .fontColor(this.isFavorite ? '#FFB020' : AppColors.GRAY_400)
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor('rgba(255, 255, 255, 0.95)')
        .backdropBlur(8)
        .justifyContent(FlexAlign.Center)
        .shadow({
          radius: 4,
          color: 'rgba(0,0,0,0.08)',
          offsetX: 0,
          offsetY: 2
        })
        .position({ x: '100%', y: 0 })
        .markAnchor({ x: '100%', y: 0 })
        .translate({ x: -8, y: 8 })
        .hitTestBehavior(HitTestMode.Block)
        .onClick(() => {
          if (this.onFavoriteClick) {
            this.onFavoriteClick()
          }
        })
      }
      .width('100%')
      .height(160)
      .backgroundColor('#FFF5EB') // bg-orange-50
      .borderRadius({ topLeft: 24, topRight: 24 })

      // 底部信息区域
      Column({ space: 8 }) {
        Text(this.recipe.name)
          .fontSize(18)
          .fontColor(AppColors.GRAY_900)
          .fontWeight(FontWeight.Bold)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        // 难度 + 烹饪方式标签行
        Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
          // 难度标签（有值才显示）
          if (this.recipe.difficulty) {
            Text(this.recipe.difficulty)
              .fontSize(11)
              .fontColor(difficultyColor(this.recipe.difficulty))
              .fontWeight(FontWeight.Medium)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor(difficultyBg(this.recipe.difficulty))
              .borderRadius(6)
              .margin({ right: 6 })
          }
          // 烹饪方式标签（有值才显示，最多展示3个）
          if (this.recipe.methods && this.recipe.methods.length > 0) {
            ForEach(this.recipe.methods.slice(0, 3), (method: string) => {
              Text(method)
                .fontSize(11)
                .fontColor('#6366F1')
                .fontWeight(FontWeight.Medium)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .backgroundColor('#EEF2FF')
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
    .backgroundColor(Color.White)
    .borderRadius(24)
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
    Stack() {
      Row({ space: 16 }) {
        // 左侧图标
        Column() {
          Text(this.getEmoji())
            .fontSize(40)
        }
        .width(96)
        .height(96)
        .borderRadius(14)
        .backgroundColor('#F0FDF4') // bg-green-50
        .justifyContent(FlexAlign.Center)

        // 右侧信息
        Column({ space: 6 }) {
          Text(this.recipe.name)
            .fontSize(16)
            .fontColor(AppColors.GRAY_900)
            .fontWeight(FontWeight.Bold)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          // 难度 + 烹饪方式标签行
          Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
            // 难度标签
            if (this.recipe.difficulty) {
              Text(this.recipe.difficulty)
                .fontSize(11)
                .fontColor(difficultyColor(this.recipe.difficulty))
                .fontWeight(FontWeight.Medium)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor(difficultyBg(this.recipe.difficulty))
                .borderRadius(4)
                .margin({ right: 6 })
            }
            // 烹饪方式标签（最多2个）
            if (this.recipe.methods && this.recipe.methods.length > 0) {
              ForEach(this.recipe.methods.slice(0, 2), (method: string) => {
                Text(method)
                  .fontSize(11)
                  .fontColor('#6366F1')
                  .fontWeight(FontWeight.Medium)
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .backgroundColor('#EEF2FF')
                  .borderRadius(4)
                  .margin({ right: 6 })
              })
            }
            // 无难度也无方式时显示食材数量作为补充信息
            if (!this.recipe.difficulty && (!this.recipe.methods || this.recipe.methods.length === 0)) {
              Text(`${this.recipe.stuff.length} 种食材`)
                .fontSize(11)
                .fontColor(AppColors.GRAY_500)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor(AppColors.GRAY_100)
                .borderRadius(4)
            }
          }
          .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .padding(12)

      // 收藏按钮 (右上角)
      Column() {
        Text(this.isFavorite ? '★' : '☆')
          .fontSize(20)
          .fontColor(this.isFavorite ? '#FFB020' : AppColors.GRAY_400)
      }
      .width(32)
      .height(32)
      .borderRadius(16)
      .backgroundColor('rgba(255, 255, 255, 0.95)')
      .backdropBlur(8)
      .justifyContent(FlexAlign.Center)
      .shadow({
        radius: 4,
        color: 'rgba(0,0,0,0.08)',
        offsetX: 0,
        offsetY: 2
      })
      .position({ x: '100%', y: 0 })
      .markAnchor({ x: '100%', y: 0 })
      .translate({ x: -8, y: 8 })
      .hitTestBehavior(HitTestMode.Block)
      .onClick(() => {
        if (this.onFavoriteClick) {
          this.onFavoriteClick()
        }
      })
    }
    .width('100%')
    .backgroundColor(Color.White)
    .borderRadius(20)
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
    .onTouch((event) => {
      if (event.type === TouchType.Down) {
        this.scaleValue = 0.98
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.scaleValue = 1.0
        if (event.type === TouchType.Up && this.onCardClick) {
          this.onCardClick()
        }
      }
    })
  }
}
