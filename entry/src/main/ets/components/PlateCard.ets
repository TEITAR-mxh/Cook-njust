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
  onPlateClick?: () => void

  @State scaleValue: number = 1.0
  @State translateY: number = 0

  build() {
    Column({ space: 12 }) {
      // 外层盘子(plate-ui) - 添加默认占位图片
      Stack({ alignContent: Alignment.Center }) {
        // 内层盘沿(plate-inner)
        Column()
          .width('85%')
          .height('85%')
          .borderRadius(1000)
          .backgroundColor(Color.White)
          .borderWidth(1)
          .borderColor('rgba(240, 235, 230, 0.5)')
          .shadow({
            radius: 15,
            color: 'rgba(0,0,0,0.04)',
            offsetX: 0,
            offsetY: 6
          })

        // 默认占位图片区域
        Text('🍽️')
          .fontSize(36)
          .fontColor(AppColors.GRAY_400)
          .opacity(0.3)
      }
      .width(140)
      .height(140)
      .borderRadius(1000)
      .backgroundColor(Color.White)
      .shadow({
        radius: 35,
        color: 'rgba(139, 126, 110, 0.2)',
        offsetX: 0,
        offsetY: 15
      })
      .scale({ x: this.scaleValue, y: this.scaleValue })
      .translate({ y: this.translateY })
      .animation({
        duration: 300,
        curve: Curve.Sharp
      })

      // 菜品标签(plate-label) - 文字居中
      Text(this.dishName)
        .fontSize(13)
        .fontColor('#5C5042')
        .fontWeight(FontWeight.Bold)
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor('rgba(255,255,255,0.85)')
        .borderRadius(100)
        .borderWidth(0.5)
        .borderColor('rgba(255,255,255,0.5)')
        .shadow({
          radius: 12,
          color: 'rgba(139, 126, 110, 0.1)',
          offsetX: 0,
          offsetY: 4
        })
        .backgroundBlurStyle(BlurStyle.Thin)
    }
    .width(140)
    .alignItems(HorizontalAlign.Center)
    .onTouch((event) => {
      if (event.type === TouchType.Down) {
        // 原型中的 :active 效果
        this.scaleValue = 0.92
        this.translateY = 4
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
