/**
 * 菜谱详情半模态弹窗组件
 * 对应原型中的 #page-detail modal-layer
 * 从底部弹出,带拖拽指示器和毛玻璃效果
 */
import { AppColors } from '../constants/AppColors'
import type { RecipeWithId } from '../model/recipe'

@Component
export struct RecipeDetailSheet {
  @Link @Watch('onVisibleChange') isVisible: boolean
  @Prop recipe: RecipeWithId | null = null
  @Prop isFavorite: boolean = false

  onFavoriteToggle?: () => void

  @State translateY: number = 1000
  @State opacityValue: number = 0

  onVisibleChange() {
    if (this.isVisible) {
      // 显示动画
      animateTo({
        duration: 400,
        curve: Curve.Friction
      }, () => {
        this.translateY = 0
        this.opacityValue = 1
      })
    } else {
      // 隐藏动画
      animateTo({
        duration: 300,
        curve: Curve.EaseOut
      }, () => {
        this.translateY = 1000
        this.opacityValue = 0
      })
    }
  }

  /**
   * 关闭弹窗
   */
  private closeSheet() {
    this.isVisible = false
  }

  private formatStepsText(steps: string[]): string {
    const lines: string[] = []
    for (let i = 0; i < steps.length; i++) {
      lines.push(`${i + 1}. ${steps[i]}`)
    }
    return lines.join('\n\n')
  }

  build() {
    if (this.recipe) {
      Stack() {
        // 背景遮罩
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0.3)')
          .opacity(this.opacityValue)
          .onClick(() => {
            this.closeSheet()
          })

        // 弹窗内容
        Column() {
          // 拖拽指示器区域
          Column() {
            Column()
              .width(40)
              .height(5)
              .backgroundColor('rgba(0,0,0,0.2)')
              .borderRadius(10)
              .margin({ top: 12, bottom: 12 })
          }
          .width('100%')
          .backgroundColor('#FFF5EB') // 原型中的 bg-orange-50
          .borderRadius({ topLeft: 32, topRight: 32 })
          .onClick(() => {
            this.closeSheet()
          })

          // 大图标区域
          Column() {
            Text(this.recipe.emojis && this.recipe.emojis.length > 0 ? this.recipe.emojis.join('') : '🍽️')
              .fontSize(80)
          }
          .width('100%')
          .height(240)
          .backgroundColor('#FFF5EB')
          .justifyContent(FlexAlign.Center)

          // 详情内容区域
          Scroll() {
            Column({ space: 16 }) {
              // 标题栏
              Row() {
                Column({ space: 4 }) {
                  Text(this.recipe.name)
                    .fontSize(24)
                    .fontColor(AppColors.GRAY_900)
                    .fontWeight(FontWeight.Bold)

                  Text(`${this.recipe.difficulty || '简单'} · 家常菜`)
                    .fontSize(13)
                    .fontColor(AppColors.GRAY_500)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                // 收藏按钮
                Column() {
                  Text(this.isFavorite ? '★' : '☆')
                    .fontSize(28)
                    .fontColor(this.isFavorite ? '#FFB020' : AppColors.GRAY_400)
                }
                .width(40)
                .height(40)
                .backgroundColor(AppColors.GRAY_50)
                .borderRadius(20)
                .justifyContent(FlexAlign.Center)
                .onClick(() => {
                  if (this.onFavoriteToggle) {
                    this.onFavoriteToggle()
                  }
                })
              }
              .width('100%')
              .padding({ left: 24, right: 24, top: 24 })

              // 核心公式卡片
              Column({ space: 12 }) {
                Text('核心公式')
                  .fontSize(16)
                  .fontColor(AppColors.GRAY_900)
                  .fontWeight(FontWeight.Bold)

                Row({ space: 8 }) {
                  ForEach(this.recipe.stuff.slice(0, 3), (item: string) => {
                    Text(item)
                      .fontSize(13)
                      .fontColor(AppColors.GRAY_800)
                      .fontWeight(FontWeight.Bold)
                      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                      .backgroundColor(Color.White)
                      .borderRadius(8)
                      .shadow({
                        radius: 2,
                        color: 'rgba(0,0,0,0.05)',
                        offsetX: 0,
                        offsetY: 1
                      })
                  }, (item: string) => item)

                  if (this.recipe.stuff.length > 3) {
                    Text(`+${this.recipe.stuff.length - 3}`)
                      .fontSize(13)
                      .fontColor(AppColors.GRAY_500)
                  }
                }
                .width('100%')
                .justifyContent(FlexAlign.Center)
              }
              .width('100%')
              .padding(16)
              .backgroundColor(AppColors.BG_COLOR)
              .borderRadius(16)
              .margin({ left: 24, right: 24 })

              if (this.recipe.steps !== undefined && this.recipe.steps.length > 0) {
                Column({ space: 10 }) {
                  Text('制作步骤')
                    .fontSize(16)
                    .fontColor(AppColors.GRAY_900)
                    .fontWeight(FontWeight.Bold)
                    .alignSelf(ItemAlign.Start)

                  Text(this.formatStepsText(this.recipe.steps))
                    .fontSize(14)
                    .fontColor(AppColors.GRAY_800)
                    .lineHeight(24)
                    .width('100%')
                }
                .width('100%')
                .padding(16)
                .backgroundColor(AppColors.BG_COLOR)
                .borderRadius(16)
                .margin({ left: 24, right: 24 })
                .alignItems(HorizontalAlign.Start)
              } else {
                Text('💡 步骤尚未收录，可在后续版本数据中查看。')
                  .fontSize(14)
                  .fontColor(AppColors.GRAY_600)
                  .lineHeight(22)
                  .padding(16)
                  .backgroundColor('rgba(255, 245, 235, 0.5)')
                  .borderRadius(12)
                  .margin({ left: 24, right: 24 })
              }
            }
            .width('100%')
            .padding({ bottom: 32 })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .backgroundColor(Color.White)
        }
        .width('100%')
        .height('95%')
        .backgroundColor(Color.White)
        .borderRadius({ topLeft: 32, topRight: 32 })
        .shadow({
          radius: 40,
          color: 'rgba(0,0,0,0.1)',
          offsetX: 0,
          offsetY: -10
        })
        .translate({ y: this.translateY })
        .alignSelf(ItemAlign.End)
      }
      .width('100%')
      .height('100%')
    }
  }
}
