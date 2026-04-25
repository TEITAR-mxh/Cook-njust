/**
 * 餐桌瓷盘卡片组件 - 新拟态(Neo-skeuomorphism)设计
 * 对应原型中的 .plate-ui 和 .plate-inner 样式
 * 通过复合阴影实现高级的3D凹陷效果
 */
import { AppColors } from '../constants/AppColors'

@Component
export struct PlateCard {
  @Prop dishName: string = ''
  @Prop emoji: string = '🍽️'
  @Prop isFavorite: boolean = true
  onPlateClick?: () => void
  onFavoriteClick?: () => void

  @State scaleValue: number = 1.0
  @State translateY: number = 0

  build() {
    Column({ space: 10 }) {
      // 盘子主体
      Stack({ alignContent: Alignment.Center }) {
        // 内层盘沿
        Column()
          .width('82%')
          .height('82%')
          .borderRadius(1000)
          .backgroundColor(Color.White)
          .borderWidth(1)
          .borderColor('rgba(240, 235, 230, 0.6)')
          .shadow({ radius: 12, color: 'rgba(0,0,0,0.05)', offsetX: 0, offsetY: 4 })

        // 菜品 emoji
        Text(this.emoji)
          .fontSize(48)

        // 收藏星标（右上角）
        Text(this.isFavorite ? '★' : '☆')
          .fontSize(14)
          .fontColor(this.isFavorite ? '#F59E0B' : AppColors.GRAY_300)
          .backgroundColor('rgba(255,255,255,0.9)')
          .borderRadius(100)
          .padding(4)
          .position({ x: '62%', y: '4%' })
          .hitTestBehavior(HitTestMode.Block)
          .onClick(() => {
            if (this.onFavoriteClick) this.onFavoriteClick()
          })
      }
      .width(130)
      .height(130)
      .borderRadius(1000)
      .backgroundColor(Color.White)
      .shadow({ radius: 30, color: 'rgba(139, 126, 110, 0.18)', offsetX: 0, offsetY: 12 })
      .scale({ x: this.scaleValue, y: this.scaleValue })
      .translate({ y: this.translateY })
      .animation({ duration: 280, curve: Curve.Sharp })

      // 菜名标签
      Text(this.dishName)
        .fontSize(12)
        .fontColor('#5C5042')
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(120)
    }
    .width(130)
    .alignItems(HorizontalAlign.Center)
    .onTouch((event) => {
      if (event.type === TouchType.Down) {
        this.scaleValue = 0.93
        this.translateY = 3
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.scaleValue = 1.0
        this.translateY = 0
        if (event.type === TouchType.Up && this.onPlateClick) {
          this.onPlateClick()
        }
      }
    })
  }
}
