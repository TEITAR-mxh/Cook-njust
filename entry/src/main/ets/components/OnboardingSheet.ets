import { AppColors, ThemeManager } from '../constants/AppColors'

// ══════════════════════════════════════════════════════════════════════════════
// 新手引导面板
// 首次启动时展示一次（标志持久化在 CookPreferences），之后可在
// 「餐桌 → 设置 → 使用引导」重新查看。内容只讲四个闭环入口，不堆功能清单。
// ══════════════════════════════════════════════════════════════════════════════

interface OnboardingStep {
  emoji: string
  title: string
  desc: string
}

const ONBOARDING_STEPS: OnboardingStep[] = [
  {
    emoji: '🧺',
    title: '先看看冰箱里有什么',
    desc: '在「冰箱」页勾选家里现有的食材和厨具，菜谱会按你的食材重新排序。'
  },
  {
    emoji: '🔍',
    title: '三种匹配方式',
    desc: '「全部相关」：用到任一已选食材的菜都能看到；「都用上」：只留用上你选的每一种食材的菜；「只看能做」：只留下主料齐备、现在就能下锅的菜。'
  },
  {
    emoji: '🛒',
    title: '缺什么，一眼看清',
    desc: '打开菜谱详情，可一键导出采购清单图片，缺什么食材按分类列清，买菜时照着勾选就行。'
  },
  {
    emoji: '🎯',
    title: '让推荐更懂你',
    desc: '在「餐桌」页点今日饮食卡片上的「每日目标」，填写身高体重与目标，热量和营养建议会按你的情况计算。'
  },
  {
    emoji: '✅',
    title: '看今天吃什么',
    desc: '在菜谱详情点「加入今日餐桌」，餐桌页会汇总今天的热量与营养，并累计这道菜做过的次数。'
  }
]

@Component
export struct OnboardingSheet {
  /** 首次启动时展示，额外提示之后可在设置中重新查看 */
  fromFirstLaunch: boolean = false
  onClose?: () => void

  @StorageProp('currentThemeMode')
  themeMode: string = '系统默认'
  @StorageProp('isSystemDarkMode')
  isSystemDark: boolean = false

  private getSheetBg(): string {
    return ThemeManager.getColor(AppColors.CARD_BG, AppColors.DARK_CARD_BG, this.themeMode)
  }

  private getTextColor(): string {
    return ThemeManager.getColor(AppColors.GRAY_900, AppColors.DARK_GRAY_900, this.themeMode)
  }

  private getSecondaryText(): string {
    return ThemeManager.getColor(AppColors.GRAY_500, AppColors.DARK_GRAY_500, this.themeMode)
  }

  private getDividerColor(): string {
    return ThemeManager.getColor(AppColors.GRAY_100, AppColors.DARK_GRAY_100, this.themeMode)
  }

  private getStepBg(): string {
    return ThemeManager.getColor(AppColors.GRAY_50, AppColors.DARK_GRAY_50, this.themeMode)
  }

  @Builder
  StepRow(step: OnboardingStep) {
    Row({ space: 12 }) {
      Text(step.emoji)
        .fontSize(22)
        .width(44)
        .height(44)
        .textAlign(TextAlign.Center)
        .backgroundColor(AppColors.BRAND_COLOR_LIGHT)
        .borderRadius(12)

      Column({ space: 4 }) {
        Text(step.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getTextColor())
          .textAlign(TextAlign.Start)
        Text(step.desc)
          .fontSize(12)
          .fontColor(this.getSecondaryText())
          .lineHeight(18)
          .textAlign(TextAlign.Start)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor(this.getStepBg())
    .borderRadius(14)
  }

  build() {
    Column({ space: 0 }) {
      Column()
        .width(36)
        .height(4)
        .backgroundColor(this.getDividerColor())
        .borderRadius(2)
        .margin({ top: 10, bottom: 14 })

      // 标题
      Row({ space: 12 }) {
        Text('🍳').fontSize(28)
        Column({ space: 3 }) {
          Text('欢迎使用 AUV 您吃了么')
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getTextColor())
            .textAlign(TextAlign.Start)
          Text('五步，把冰箱变成今晚的菜')
            .fontSize(13)
            .fontColor(this.getSecondaryText())
            .textAlign(TextAlign.Start)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 16 })

      Scroll() {
        Column({ space: 10 }) {
          ForEach(ONBOARDING_STEPS, (step: OnboardingStep) => {
            this.StepRow(step)
          }, (step: OnboardingStep) => step.title)

          if (this.fromFirstLaunch) {
            Text('之后可在「餐桌 → 设置 → 使用引导」重新查看')
              .fontSize(11)
              .fontColor(this.getSecondaryText())
              .textAlign(TextAlign.Center)
              .width('100%')
              .margin({ top: 2 })
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 2, bottom: 8 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      // 底部主按钮
      Column() {
        Divider().color(this.getDividerColor()).strokeWidth(1)
        Text('开始下厨')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .width('88%')
          .height(48)
          .textAlign(TextAlign.Center)
          .backgroundColor(AppColors.BRAND_COLOR)
          .borderRadius(24)
          .margin({ top: 14, bottom: 10 })
          .onClick(() => { if (this.onClose) this.onClose() })
      }
      .width('100%')
      .padding({ left: 20, right: 20 })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getSheetBg())
    .borderRadius({ topLeft: 24, topRight: 24 })
  }
}
