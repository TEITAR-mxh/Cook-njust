/**
 * 设置页面 - 包含账号信息和应用设置
 */
import { router } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { AppColors } from '../constants/AppColors'
import { CookPreferences } from '../store/CookPreferences'
import { RecipeRepository } from '../data/RecipeRepository'

@Entry
@Component
struct SettingsPage {
  @State keepLocalData: boolean = true
  @State recipeCount: number = 0
  @State favoriteCount: number = 0
  @State historyCount: number = 0

  aboutToAppear(): void {
    void this.loadData()
  }

  onPageShow(): void {
    void this.loadData()
  }

  private async loadData(): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (!host) {
      return
    }

    try {
      // 加载基本数据
      this.recipeCount = RecipeRepository.getInstance().getCount()
      const settings = await CookPreferences.getSettings(host)
      this.keepLocalData = settings.keepLocalData

      // 加载收藏和历史数量
      const favoriteIds = await CookPreferences.getFavoriteIds(host)
      const historyIds = await CookPreferences.getHistoryIds(host)
      this.favoriteCount = favoriteIds.length
      this.historyCount = historyIds.length
    } catch (err) {
      console.error('loadData failed', err)
    }
  }

  private async onKeepLocalChange(isOn: boolean): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (!host) {
      return
    }

    this.keepLocalData = isOn
    await CookPreferences.setKeepLocalData(host, isOn)

    if (!isOn) {
      // 清空数据
      await CookPreferences.clearFavorites(host)
      await CookPreferences.clearHistory(host)
      this.favoriteCount = 0
      this.historyCount = 0
    }
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        // 返回按钮 - 增加点击区域和视觉反馈
        Row({ space: 8 }) {
          Text('←')
            .fontSize(24)
            .fontColor(AppColors.GRAY_900)

          Text('返回')
            .fontSize(16)
            .fontColor(AppColors.GRAY_900)
        }
        .padding({ left: 8, right: 12, top: 8, bottom: 8 })
        .borderRadius(8)
        .onClick(() => {
          router.back()
        })

        Text('设置')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.GRAY_900)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .margin({ right: 80 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 12, right: 20 })
      .backgroundColor(Color.White)
      .borderWidth({ bottom: 0.5 })
      .borderColor(AppColors.GRAY_200)

      // 滚动内容区域
      Scroll() {
        Column({ space: 20 }) {
          // 个人信息卡片
          Column({ space: 16 }) {
            Text('账号信息')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.GRAY_800)
              .alignSelf(ItemAlign.Start)

            Row({ space: 12 }) {
              Column() {
                Text('🧑‍🍳')
                  .fontSize(24)
              }
              .width(56)
              .height(56)
              .borderRadius(28)
              .backgroundColor('#FFF5EB')
              .justifyContent(FlexAlign.Center)

              Column({ space: 6 }) {
                Text('美食达人')
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppColors.GRAY_900)

                Text('ID: cook_2024')
                  .fontSize(13)
                  .fontColor(AppColors.GRAY_500)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Text('>')
                .fontSize(20)
                .fontColor(AppColors.GRAY_400)
            }
            .width('100%')
            .padding(16)
            .backgroundColor(Color.White)
            .borderRadius(16)
            .shadow({
              radius: 8,
              color: 'rgba(0,0,0,0.05)',
              offsetX: 0,
              offsetY: 2
            })
            .onClick(() => {
              // 跳转到个人信息编辑
            })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          // 数据统计
          Column({ space: 16 }) {
            Text('数据统计')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.GRAY_800)
              .alignSelf(ItemAlign.Start)

            Row({ space: 16 }) {
              Column({ space: 4 }) {
                Text(`${this.recipeCount}`)
                  .fontSize(28)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppColors.GRAY_900)

                Text('菜谱总数')
                  .fontSize(12)
                  .fontColor(AppColors.GRAY_500)
              }
              .layoutWeight(1)

              Column()
                .width(1)
                .height(50)
                .backgroundColor(AppColors.GRAY_200)

              Column({ space: 4 }) {
                Text(`${this.favoriteCount}`)
                  .fontSize(28)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppColors.BRAND_COLOR)

                Text('收藏数量')
                  .fontSize(12)
                  .fontColor(AppColors.GRAY_500)
              }
              .layoutWeight(1)

              Column()
                .width(1)
                .height(50)
                .backgroundColor(AppColors.GRAY_200)

              Column({ space: 4 }) {
                Text(`${this.historyCount}`)
                  .fontSize(28)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppColors.GRAY_900)

                Text('浏览历史')
                  .fontSize(12)
                  .fontColor(AppColors.GRAY_500)
              }
              .layoutWeight(1)
            }
            .width('100%')
            .padding(24)
            .backgroundColor(Color.White)
            .borderRadius(16)
            .shadow({
              radius: 8,
              color: 'rgba(0,0,0,0.05)',
              offsetX: 0,
              offsetY: 2
            })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          // 应用设置
          Column({ space: 16 }) {
            Text('应用设置')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.GRAY_800)
              .alignSelf(ItemAlign.Start)

            // 数据保留开关
            Row({ space: 12 }) {
              Column({ space: 4 }) {
                Text('保留本地数据')
                  .fontSize(15)
                  .fontColor(AppColors.GRAY_900)

                Text('关闭后将清空历史和收藏')
                  .fontSize(12)
                  .fontColor(AppColors.GRAY_500)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Toggle({ type: ToggleType.Switch, isOn: this.keepLocalData })
                .selectedColor(AppColors.BRAND_COLOR)
                .onChange((isOn: boolean) => {
                  void this.onKeepLocalChange(isOn)
                })
            }
            .width('100%')
            .padding(16)
            .backgroundColor(Color.White)
            .borderRadius(16)
            .shadow({
              radius: 8,
              color: 'rgba(0,0,0,0.05)',
              offsetX: 0,
              offsetY: 2
            })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          // 关于
          Column({ space: 16 }) {
            Text('关于')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.GRAY_800)
              .alignSelf(ItemAlign.Start)

            Column({ space: 1 }) {
              Row({ space: 12 }) {
                Text('ℹ️')
                  .fontSize(20)

                Text('关于灵感厨房')
                  .fontSize(15)
                  .fontColor(AppColors.GRAY_900)
                  .layoutWeight(1)

                Text('v1.0.0')
                  .fontSize(13)
                  .fontColor(AppColors.GRAY_500)

                Text('>')
                  .fontSize(20)
                  .fontColor(AppColors.GRAY_400)
              }
              .width('100%')
              .padding(16)
              .onClick(() => {
                // 关于应用
              })

              Divider()
                .color(AppColors.GRAY_100)

              Row({ space: 12 }) {
                Text('📄')
                  .fontSize(20)

                Text('隐私政策')
                  .fontSize(15)
                  .fontColor(AppColors.GRAY_900)
                  .layoutWeight(1)

                Text('>')
                  .fontSize(20)
                  .fontColor(AppColors.GRAY_400)
              }
              .width('100%')
              .padding(16)
              .onClick(() => {
                // 隐私政策
              })

              Divider()
                .color(AppColors.GRAY_100)

              Row({ space: 12 }) {
                Text('📋')
                  .fontSize(20)

                Text('用户协议')
                  .fontSize(15)
                  .fontColor(AppColors.GRAY_900)
                  .layoutWeight(1)

                Text('>')
                  .fontSize(20)
                  .fontColor(AppColors.GRAY_400)
              }
              .width('100%')
              .padding(16)
              .onClick(() => {
                // 用户协议
              })
            }
            .width('100%')
            .backgroundColor(Color.White)
            .borderRadius(16)
            .shadow({
              radius: 8,
              color: 'rgba(0,0,0,0.05)',
              offsetX: 0,
              offsetY: 2
            })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 20, bottom: 40 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .backgroundColor(AppColors.BG_COLOR)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_COLOR)
  }
}
