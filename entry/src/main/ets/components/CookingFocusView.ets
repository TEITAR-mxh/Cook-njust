import { runningLock } from '@kit.BasicServicesKit'
import { AppColors } from '../constants/AppColors'

@Component
export struct CookingFocusView {
  @Link @Watch('onVisibleChange') visible: boolean
  @Prop recipeName: string = ''
  @Prop steps: string[] = []

  @State private activeIndex: number = 0
  private screenLock: runningLock.RunningLock | null = null
  private lockHeld: boolean = false

  aboutToAppear(): void {
    if (this.visible) {
      void this.acquireScreenLock()
    }
  }

  aboutToDisappear(): void {
    void this.releaseScreenLock()
  }

  private async acquireScreenLock(): Promise<void> {
    try {
      if (this.screenLock === null) {
        this.screenLock = await runningLock.create('cook_focus_mode', runningLock.RunningLockType.BACKGROUND)
      }
      if (this.screenLock !== null && !this.lockHeld) {
        this.screenLock.hold(0)
        this.lockHeld = true
      }
    } catch (err) {
      console.error('acquire screen lock failed', JSON.stringify(err))
    }
  }

  private async releaseScreenLock(): Promise<void> {
    try {
      if (this.screenLock !== null && this.lockHeld) {
        this.screenLock.unhold()
      }
    } catch (err) {
      console.error('release screen lock failed', JSON.stringify(err))
    } finally {
      this.lockHeld = false
      this.screenLock = null
    }
  }

  private close(): void {
    this.visible = false
  }

  onVisibleChange(): void {
    if (this.visible) {
      this.activeIndex = 0
      void this.acquireScreenLock()
    } else {
      void this.releaseScreenLock()
      this.activeIndex = 0
    }
  }

  @Builder
  StepCard(step: string, index: number) {
    Column({ space: 20 }) {
      Text(`步骤 ${index + 1}`)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.BRAND_COLOR)

      Text(step)
        .width('100%')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.GRAY_900)
        .lineHeight(40)
        .textAlign(TextAlign.Start)
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .padding({ left: 28, right: 28, top: 32, bottom: 32 })
    .backgroundColor(Color.White)
    .borderRadius(28)
  }

  build() {
    if (this.visible) {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(17, 24, 39, 0.58)')

        Column({ space: 18 }) {
          Row() {
            Column({ space: 4 }) {
              Text('专注模式')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)

              Text(this.recipeName)
                .fontSize(13)
                .fontColor('rgba(255,255,255,0.76)')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Text('退出')
              .fontSize(14)
              .fontColor(Color.White)
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })
              .backgroundColor('rgba(255,255,255,0.14)')
              .borderRadius(14)
              .onClick(() => this.close())
          }
          .width('100%')

          Swiper() {
            ForEach(this.steps, (step: string, index: number) => {
              this.StepCard(step, index)
            }, (step: string, index: number) => `${index}-${step}`)
          }
          .width('100%')
          .layoutWeight(1)
          .index(this.activeIndex)
          .indicator(true)
          .loop(false)
          .itemSpace(12)
          .onChange((index: number) => {
            this.activeIndex = index
          })

          Row() {
            Text(`${this.activeIndex + 1} / ${this.steps.length}`)
              .fontSize(14)
              .fontColor('rgba(255,255,255,0.82)')

            Blank()

            if (this.activeIndex > 0) {
              Text('上一步')
                .fontSize(14)
                .fontColor(Color.White)
                .padding({ left: 14, right: 14, top: 10, bottom: 10 })
                .backgroundColor('rgba(255,255,255,0.14)')
                .borderRadius(14)
                .onClick(() => {
                  this.activeIndex = this.activeIndex - 1
                })
            }

            if (this.activeIndex < this.steps.length - 1) {
              Text('下一步')
                .fontSize(14)
                .fontColor(Color.White)
                .padding({ left: 14, right: 14, top: 10, bottom: 10 })
                .backgroundColor(AppColors.BRAND_COLOR)
                .borderRadius(14)
                .margin({ left: 10 })
                .onClick(() => {
                  this.activeIndex = this.activeIndex + 1
                })
            }
          }
          .width('100%')
        }
        .width('100%')
        .height('100%')
        .padding({ left: 20, right: 20, top: 56, bottom: 32 })
      }
      .width('100%')
      .height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
  }
}
