import { AppColors } from '../constants/AppColors'

@Component
export struct FavoriteToast {
  @Prop @Watch('onVisibleChange') visible: boolean = false
  onAddToFolder?: () => void
  /** 动画完全结束后回调，父组件应在此将 visible 置 false 以释放 hitTestBehavior */
  onHide?: () => void

  @State translateY: number = 120
  @State opacityValue: number = 0

  onVisibleChange() {
    if (this.visible) {
      animateTo({ duration: 350, curve: Curve.EaseOut }, () => {
        this.translateY = 0
        this.opacityValue = 1
      })
      setTimeout(() => { this.hide() }, 3500)
    }
  }

  private hide() {
    animateTo({ duration: 280, curve: Curve.EaseIn }, () => {
      this.translateY = 120
      this.opacityValue = 0
    })
    // 动画结束后通知父组件释放 hitTestBehavior，避免透明遮层持续拦截底部导航触摸事件
    setTimeout(() => {
      if (this.onHide) {
        this.onHide()
      }
    }, 300)
  }

  build() {
    Row() {
      // 左侧：成功图标 + 文字
      Row({ space: 8 }) {
        Text('✓')
          .fontSize(16)
          .fontColor('#22C55E')
          .fontWeight(FontWeight.Bold)
        Text('收藏成功')
          .fontSize(15)
          .fontColor('#1F2937')
          .fontWeight(FontWeight.Medium)
      }.layoutWeight(1)

      // 右侧：加入收藏夹按钮
      Row({ space: 4 }) {
        Text('加入收藏夹')
          .fontSize(14)
          .fontColor(AppColors.BRAND_COLOR)
          .fontWeight(FontWeight.Medium)
        Text('›')
          .fontSize(16)
          .fontColor(AppColors.BRAND_COLOR)
          .fontWeight(FontWeight.Bold)
      }
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor('#18FF4757')
      .borderRadius(20)
      .onClick(() => {
        this.hide()
        if (this.onAddToFolder) {
          this.onAddToFolder()
        }
      })
    }
    .width('100%')
    .padding({ left: 20, right: 16, top: 14, bottom: 14 })
    .backgroundColor('#FFFFFFEE')
    .backdropBlur(20)
    .borderRadius(16)
    .shadow({ radius: 20, color: 'rgba(0,0,0,0.12)', offsetX: 0, offsetY: -4 })
    .translate({ y: this.translateY })
    .opacity(this.opacityValue)
    .zIndex(9998)
  }
}
