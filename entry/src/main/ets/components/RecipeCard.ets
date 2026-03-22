/**
 * 菜谱卡片组件 - 支持大图和小图两种模式
 * 对应原型中的菜谱卡片样式
 */
import { AppColors } from '../constants/AppColors'
import type { RecipeWithId } from '../model/recipe'

export enum RecipeCardMode {
  LARGE = 'large',  // 大图模式(原型中的第一张卡片)
  SMALL = 'small'   // 小图模式(原型中的第二张卡片)
}

@Component
export struct RecipeCard {
  @Prop recipe: RecipeWithId
  @Prop mode: RecipeCardMode = RecipeCardMode.LARGE
  @Prop isFavorite: boolean = false
  @Prop hasVideo: boolean = false

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
      Column() {
        Text(this.getEmoji())
          .fontSize(60)

        // 播放量标签
        if (this.hasVideo) {
          Row({ space: 4 }) {
            Text('▶')
              .fontSize(10)
              .fontColor(Color.White)

            Text('10.2万播放')
              .fontSize(10)
              .fontColor(Color.White)
          }
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor('rgba(0,0,0,0.5)')
          .borderRadius(6)
          .backdropBlur(8)
          .position({ x: '100%', y: '100%' })
          .markAnchor({ x: '100%', y: '100%' })
          .translate({ x: -8, y: -8 })
        }
      }
      .width('100%')
      .height(160)
      .backgroundColor('#FFF5EB') // bg-orange-50
      .borderRadius({ topLeft: 24, topRight: 24 })
      .justifyContent(FlexAlign.Center)

      // 底部信息区域
      Column({ space: 8 }) {
        Text(this.recipe.name)
          .fontSize(18)
          .fontColor(AppColors.GRAY_900)
          .fontWeight(FontWeight.Bold)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.recipe.difficulty || '零失败的国民家常菜，十分钟搞定一顿饭。')
          .fontSize(13)
          .fontColor(AppColors.GRAY_500)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .lineHeight(20)

        // 作者信息
        Row({ space: 8 }) {
          Column()
            .width(20)
            .height(20)
            .borderRadius(10)
            .backgroundColor(AppColors.GRAY_200)

          Text('周末大厨')
            .fontSize(11)
            .fontColor(AppColors.GRAY_500)
            .fontWeight(FontWeight.Medium)
        }
        .margin({ top: 4 })
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

        Text(this.recipe.difficulty || '减脂期也能大口吃肉')
          .fontSize(12)
          .fontColor(AppColors.GRAY_500)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row({ space: 6 }) {
          Text('15分钟')
            .fontSize(11)
            .fontColor(AppColors.GRAY_500)

          Text('·')
            .fontSize(11)
            .fontColor(AppColors.GRAY_300)

          Text('简单')
            .fontSize(11)
            .fontColor(AppColors.GRAY_500)
        }
        .padding({ left: 8, right: 8, top: 2, bottom: 2 })
        .backgroundColor(AppColors.GRAY_100)
        .borderRadius(4)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .padding(12)
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
