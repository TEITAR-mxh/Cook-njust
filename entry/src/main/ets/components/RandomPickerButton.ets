/**
 * 随机搭配按钮组件 - 原型中的"盲盒随机引擎"
 * 功能:点击后随机闪烁食材标签,最后定格在随机选中的食材组合
 * 对应原型中的 startRandomizer() 函数
 */
import { AppColors } from '../constants/AppColors'

@Component
export struct RandomPickerButton {
  @Prop disabled: boolean = false
  onRandomComplete?: (selectedIngredients: string[]) => void

  @State isAnimating: boolean = false
  @State buttonScale: number = 1.0

  /**
   * 开始随机搭配动画
   */
  private startRandomPicker() {
    if (this.isAnimating || this.disabled) {
      return
    }

    this.isAnimating = true

    // 触发父组件的随机逻辑
    if (this.onRandomComplete) {
      // 模拟盲盒动画(0.75s * 10轮 = 7.5秒)
      setTimeout(() => {
        // 这里应该由父组件提供随机逻辑
        // 父组件 IndexV2：一荤一素随机搭配
        this.isAnimating = false
        this.onRandomComplete!([])
      }, 750) // 简化版:直接完成
    }
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        // 骰子图标背景
        Column() {
          Text('🎲')
            .fontSize(20)
        }
        .width(40)
        .height(40)
        .backgroundColor('rgba(255,255,255,0.2)')
        .borderRadius(20)
        .justifyContent(FlexAlign.Center)
        .backgroundBlurStyle(BlurStyle.Thin)

        Column({ space: 2 }) {
          Text('没有灵感?')
            .fontSize(15)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Bold)

          Text('帮我随机搭配一餐')
            .fontSize(12)
            .fontColor('rgba(255,255,255,0.8)')
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height(64)
      .padding(16)
      .linearGradient({
        angle: 135,
        colors: [
          ['#FF6B6B', 0.0], // from-orange-400 to-red-400 的近似值
          ['#FF4757', 1.0]
        ]
      })
      .borderRadius(20)
      .shadow({
        radius: 8,
        color: 'rgba(255, 71, 87, 0.3)',
        offsetX: 0,
        offsetY: 4
      })
      .justifyContent(FlexAlign.SpaceBetween)
      .scale({ x: this.buttonScale, y: this.buttonScale })
      .animation({
        duration: 150,
        curve: Curve.EaseOut
      })
      .onTouch((event) => {
        if (event.type === TouchType.Down) {
          this.buttonScale = 0.98
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.buttonScale = 1.0
          if (event.type === TouchType.Up) {
            this.startRandomPicker()
          }
        }
      })

      // 右侧箭头(通过 Row 的 SpaceBetween 实现)
      Text('›')
        .fontSize(24)
        .fontColor(Color.White)
        .fontWeight(FontWeight.Bold)
        .opacity(0.7)
        .position({ x: '92%', y: '50%' })
        .markAnchor({ x: '50%', y: '50%' })
    }
    .width('100%')
    .margin({ bottom: 6 })
  }
}
