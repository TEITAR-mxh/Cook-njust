/**
 * Toast 毛玻璃提示组件 - 基于原型中的 #toast 样式
 * 原生感提示,带毛玻璃效果和弹性动画
 */
import { AppColors } from '../constants/AppColors'

@Component
export struct ToastView {
  @Prop message: string = ''
  @Prop @Watch('onVisibleChange') visible: boolean = false
  @State translateY: number = -100
  @State opacityValue: number = 0

  onVisibleChange() {
    if (this.visible) {
      // 显示动画:从上方滑入
      animateTo({
        duration: 400,
        curve: Curve.Sharp
      }, () => {
        this.translateY = 0
        this.opacityValue = 1
      })

      // 2秒后自动隐藏
      setTimeout(() => {
        this.hideToast()
      }, 2000)
    }
  }

  private hideToast() {
    animateTo({
      duration: 300,
      curve: Curve.EaseOut
    }, () => {
      this.translateY = -100
      this.opacityValue = 0
    })
  }

  build() {
    if (this.message.length > 0) {
      Text(this.message)
        .fontSize(14)
        .fontColor(Color.White)
        .fontWeight(FontWeight.Medium)
        .padding({ left: 24, right: 24, top: 12, bottom: 12 })
        .backgroundColor('rgba(17, 24, 39, 0.9)') // 原型中的 rgba(17, 24, 39, 0.9)
        .borderRadius(100) // rounded-full
        .shadow({
          radius: 30,
          color: 'rgba(0,0,0,0.2)',
          offsetX: 0,
          offsetY: 10
        })
        .backgroundBlurStyle(BlurStyle.Thick) // 毛玻璃效果 backdrop-filter: blur(8px)
        .translate({ y: this.translateY })
        .opacity(this.opacityValue)
        .zIndex(9999)
        .position({ x: '50%', y: 50 })
        .markAnchor({ x: '50%', y: 0 }) // 实现水平居中
    }
  }
}
