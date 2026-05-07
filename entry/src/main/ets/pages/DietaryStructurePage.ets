/**
 * 饮食结构建议页
 * 数据来源：《中国居民膳食指南（2022）》
 */
import { common } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI'
import { AppColors } from '../constants/AppColors'
import { getSystemSafeTopVp } from '../util/StatusBarInset'
import { DietDatabaseHelper, DailyTotal } from '../data/DietDatabaseHelper'

// ─── 数据结构 ─────────────────────────────────────────────────────────────────

interface MacroItem {
  label: string
  range: string
  color: string
  darkColor: string
  ratio: number
}

interface FoodItem {
  emoji: string
  name: string
  amount: string
}

// ─── 静态数据 ─────────────────────────────────────────────────────────────────

const MACROS: MacroItem[] = [
  { label: '碳水化合物', range: '50 – 65%', color: AppColors.CARB_TEXT,  darkColor: AppColors.DARK_CARB_TEXT,  ratio: 0.60 },
  { label: '蛋白质',    range: '10 – 20%', color: AppColors.BRAND_COLOR, darkColor: AppColors.BRAND_COLOR,     ratio: 0.15 },
  { label: '脂肪',     range: '20 – 30%', color: AppColors.TOOL_TEXT,   darkColor: AppColors.DARK_TOOL_TEXT,  ratio: 0.25 }
]

const FOOD_ITEMS: FoodItem[] = [
  { emoji: '🌾', name: '谷薯类（主食）', amount: '250 – 400 g' },
  { emoji: '🥦', name: '蔬菜类',        amount: '300 – 500 g' },
  { emoji: '🍎', name: '新鲜水果',      amount: '200 – 350 g' },
  { emoji: '🥩', name: '畜禽肉类',      amount: '40 – 75 g'   },
  { emoji: '🐟', name: '鱼虾水产',      amount: '40 – 75 g'   },
  { emoji: '🥚', name: '鸡蛋',          amount: '约 1 个 / 天' },
  { emoji: '🥛', name: '奶及奶制品',    amount: '300 g'        },
  { emoji: '🫘', name: '大豆及坚果',    amount: '25 – 35 g'   },
  { emoji: '🫙', name: '烹调油',        amount: '25 – 30 g'   },
  { emoji: '🧂', name: '食盐',          amount: '< 5 g'        },
  { emoji: '💧', name: '饮水',          amount: '1500 – 1700 ml' }
]

const TIPS: string[] = [
  '食物多样，谷类为主，粗细搭配',
  '多吃蔬果、奶类、大豆，保证微量营养素摄入',
  '适量吃鱼、禽、蛋，优先选择鱼虾和禽肉',
  '少盐少油少糖，控制烹调用量与在外就餐频率',
  '足量饮水，少喝含糖饮料，首选白开水',
  '吃动平衡，维持健康体重，减少久坐时间'
]

// ─── 页面 ─────────────────────────────────────────────────────────────────────

@Entry
@Component
struct DietaryStructurePage {
  @State private safeTopVp: number = 48
  @State private todayTotal: DailyTotal = {
    totalCalories: 0, totalProtein: 0, totalFat: 0, totalCarbs: 0, recordCount: 0
  }

  @StorageProp('currentThemeMode')
  @Watch('onThemeChange')
  private storedThemeMode: string = '系统默认'

  @StorageProp('isSystemDarkMode')
  @Watch('onThemeChange')
  private isSystemDark: boolean = false

  @State private isDark: boolean = false

  // ── 生命周期 ──────────────────────────────────────────────────────────────

  aboutToAppear(): void {
    this.isDark = this.calcIsDark()
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (ctx !== undefined) {
      getSystemSafeTopVp(ctx).then((vp: number) => { this.safeTopVp = vp }).catch(() => {})
      void this.loadTodayTotal(ctx)
    }
  }

  private async loadTodayTotal(ctx: common.UIAbilityContext): Promise<void> {
    try {
      const helper = DietDatabaseHelper.getInstance()
      await helper.ensureReady(ctx)
      this.todayTotal = await helper.queryTodayTotal(ctx)
    } catch (e) {
      console.warn('[DietaryStructurePage] 加载今日摄入失败:', JSON.stringify(e))
    }
  }

  private onThemeChange(): void { this.isDark = this.calcIsDark() }

  private calcIsDark(): boolean {
    if (this.storedThemeMode === '深色模式') return true
    if (this.storedThemeMode === '浅色模式') return false
    return this.isSystemDark
  }

  // ── 颜色 Token ────────────────────────────────────────────────────────────

  private get bg(): string      { return this.isDark ? AppColors.DARK_BG_COLOR : AppColors.BG_COLOR }
  private get surface(): string { return this.isDark ? AppColors.DARK_CARD_BG  : AppColors.CARD_BG  }
  private get divider(): string { return this.isDark ? AppColors.DARK_GRAY_200 : '#E8E8EA'           }
  private get track(): string   { return this.isDark ? AppColors.DARK_GRAY_200 : AppColors.GRAY_200  }
  private get t1(): string      { return this.isDark ? AppColors.DARK_GRAY_900 : AppColors.GRAY_900  }
  private get t2(): string      { return this.isDark ? AppColors.DARK_GRAY_500 : AppColors.GRAY_500  }
  private get t3(): string      { return this.isDark ? AppColors.DARK_GRAY_400 : AppColors.GRAY_400  }
  private get brandBg(): string { return this.isDark ? '#2A1215' : AppColors.BRAND_COLOR_LIGHT       }

  private get intakeRatio(): number {
    return Math.min(this.todayTotal.totalCalories / 2000, 1.0)
  }

  private get intakeBarColor(): string {
    const r = this.intakeRatio
    return r < 0.6 ? '#22C55E' : (r < 0.9 ? AppColors.BRAND_COLOR : '#F97316')
  }

  // ── 今日已摄入进度卡片 ────────────────────────────────────────────────────

  @Builder
  private TodayIntakeCard() {
    Column({ space: 0 }) {
      // 标题行
      Row() {
        Text('今日已摄入').fontSize(15).fontWeight(FontWeight.Bold).fontColor(this.t1).layoutWeight(1)
        Text('去记录')
          .fontSize(13).fontColor(AppColors.BRAND_COLOR)
          .onClick(() => {
            router.pushUrl({ url: 'pages/CalorieScanPage' }).catch((e: Error) => {
              console.error(`跳转 CalorieScanPage 失败: ${e.message}`)
            })
          })
      }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 10 })

      // 热量大字 + 目标
      Row({ space: 4 }) {
        Text(`${Math.round(this.todayTotal.totalCalories)}`)
          .fontSize(36).fontWeight(FontWeight.Bold).fontColor(this.intakeBarColor)
        Text('/ 2000 千卡').fontSize(14).fontColor(this.t2).margin({ top: 12 })
      }.padding({ left: 20, right: 20 }).alignSelf(ItemAlign.Start)

      // 进度条
      Stack({ alignContent: Alignment.Start }) {
        Row().width('100%').height(8).backgroundColor(this.track).borderRadius(4)
        Row().width(`${this.intakeRatio * 100}%`).height(8).backgroundColor(this.intakeBarColor).borderRadius(4)
      }.width('100%').padding({ left: 20, right: 20, top: 10, bottom: 12 })

      Divider().color(this.divider).margin({ left: 20, right: 20 })

      // 三大营养素摘要
      Row() {
        Column({ space: 4 }) {
          Text(`${Math.round(this.todayTotal.totalProtein)} g`).fontSize(15).fontWeight(FontWeight.Bold).fontColor('#22C55E')
          Text('蛋白质').fontSize(12).fontColor(this.t3)
        }.layoutWeight(1).alignItems(HorizontalAlign.Center)

        Column({ space: 4 }) {
          Text(`${Math.round(this.todayTotal.totalFat)} g`).fontSize(15).fontWeight(FontWeight.Bold).fontColor('#F59E0B')
          Text('脂肪').fontSize(12).fontColor(this.t3)
        }.layoutWeight(1).alignItems(HorizontalAlign.Center)

        Column({ space: 4 }) {
          Text(`${Math.round(this.todayTotal.totalCarbs)} g`).fontSize(15).fontWeight(FontWeight.Bold).fontColor('#3B82F6')
          Text('碳水').fontSize(12).fontColor(this.t3)
        }.layoutWeight(1).alignItems(HorizontalAlign.Center)

        Column({ space: 4 }) {
          Text(`${this.todayTotal.recordCount}`).fontSize(15).fontWeight(FontWeight.Bold).fontColor(this.t1)
          Text('记录条数').fontSize(12).fontColor(this.t3)
        }.layoutWeight(1).alignItems(HorizontalAlign.Center)
      }.width('100%').padding({ top: 12, bottom: 16 })
    }
    .width('100%')
    .backgroundColor(this.surface)
    .borderRadius(16)
    .margin({ left: 16, right: 16 })
    .clip(true)
  }

  // ── 导航栏 ────────────────────────────────────────────────────────────────

  @Builder
  private NavBar() {
    Row() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20)
          .fontColor([this.t1])
      }
      .width(44).height(44)
      .justifyContent(FlexAlign.Center)
      .onClick(() => { this.getUIContext().getRouter().back() })

      Text('饮食结构建议')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.t1)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Blank().width(44)
    }
    .width('100%')
    .height(this.safeTopVp + 48)
    .padding({ top: this.safeTopVp, left: 4, right: 4 })
    .backgroundColor(this.surface)
    .border({ width: { bottom: 0.5 }, color: this.divider })
  }

  // ── 区块标题（SettingsPage 风格）────────────────────────────────────────

  @Builder
  private SectionTitle(title: string) {
    Text(title)
      .fontSize(13)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.t2)
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 8 })
  }

  // ── 膳食宝塔图 ────────────────────────────────────────────────────────────

  @Builder
  private ImageCard() {
    Column({ space: 0 }) {
      Image($r('app.media.diet_structure_ref'))
        .width('100%')
        .aspectRatio(0.75)
        .objectFit(ImageFit.Contain)

      Text('中国居民平衡膳食宝塔示意图')
        .fontSize(12)
        .fontColor(this.t3)
        .textAlign(TextAlign.Center)
        .width('100%')
        .padding({ top: 0, bottom: 1, left: 16, right: 16 })
    }
    .backgroundColor(this.surface)
    .borderRadius(16)
    .clip(true)
    .margin({ left: 16, right: 16 })
  }

  // ── 三大营养素卡片 ────────────────────────────────────────────────────────

  @Builder
  private MacroCard() {
    Column({ space: 0 }) {
      ForEach(
        MACROS,
        (item: MacroItem, index: number) => {
          this.MacroRow(item, index < MACROS.length - 1)
        },
        (item: MacroItem) => item.label
      )
    }
    .backgroundColor(this.surface)
    .borderRadius(16)
    .clip(true)
    .margin({ left: 16, right: 16 })
  }

  @Builder
  private MacroRow(item: MacroItem, showDivider: boolean) {
    Column({ space: 0 }) {
      Column({ space: 8 }) {
        Row() {
          Text(item.label)
            .fontSize(15)
            .fontColor(this.t1)
            .layoutWeight(1)
          Text(item.range)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.isDark ? item.darkColor : item.color)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row() {
          Row()
            .width(`${item.ratio * 100}%`)
            .height(5)
            .backgroundColor(this.isDark ? item.darkColor : item.color)
            .borderRadius(3)
        }
        .width('100%')
        .height(5)
        .backgroundColor(this.track)
        .borderRadius(3)
        .clip(true)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 16 })

      if (showDivider) {
        Divider().color(this.divider)
      }
    }
    .width('100%')
  }

  // ── 每日推荐量卡片 ────────────────────────────────────────────────────────

  @Builder
  private FoodCard() {
    Column({ space: 0 }) {
      ForEach(
        FOOD_ITEMS,
        (item: FoodItem, index: number) => {
          this.FoodRow(item, index < FOOD_ITEMS.length - 1)
        },
        (item: FoodItem) => item.name
      )
    }
    .backgroundColor(this.surface)
    .borderRadius(16)
    .clip(true)
    .margin({ left: 16, right: 16 })
  }

  @Builder
  private FoodRow(item: FoodItem, showDivider: boolean) {
    Column({ space: 0 }) {
      Row() {
        Text(item.emoji)
          .fontSize(18)
          .width(28)
          .textAlign(TextAlign.Center)
          .flexShrink(0)
        Text(item.name)
          .fontSize(15)
          .fontColor(this.t1)
          .layoutWeight(1)
          .margin({ left: 12 })
        Text(item.amount)
          .fontSize(13)
          .fontColor(this.t3)
          .margin({ left: 8 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 20, right: 16, top: 14, bottom: 14 })

      if (showDivider) {
        Divider().color(this.divider).margin({ left: 60 })
      }
    }
    .width('100%')
  }

  // ── 核心建议卡片 ──────────────────────────────────────────────────────────

  @Builder
  private TipsCard() {
    Column({ space: 0 }) {
      ForEach(
        TIPS,
        (tip: string, index: number) => {
          this.TipRow(tip, index, index < TIPS.length - 1)
        },
        (tip: string) => tip
      )
    }
    .backgroundColor(this.surface)
    .borderRadius(16)
    .clip(true)
    .margin({ left: 16, right: 16 })
  }

  @Builder
  private TipRow(tip: string, index: number, showDivider: boolean) {
    Column({ space: 0 }) {
      Row({ space: 14 }) {
        Text(`${index + 1}`)
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.BRAND_COLOR)
          .width(20).height(20)
          .textAlign(TextAlign.Center)
          .lineHeight(20)
          .backgroundColor(this.brandBg)
          .borderRadius(10)
          .flexShrink(0)
        Text(tip)
          .fontSize(15)
          .fontColor(this.t1)
          .lineHeight(22)
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 20, right: 20, top: 15, bottom: 15 })

      if (showDivider) {
        Divider().color(this.divider).margin({ left: 54 })
      }
    }
    .width('100%')
  }

  // ── 页脚 ──────────────────────────────────────────────────────────────────

  @Builder
  private Footer() {
    Column({ space: 5 }) {
      Text('数据来源：《中国居民膳食指南（2022）》')
        .fontSize(12)
        .fontColor(this.t3)
        .textAlign(TextAlign.Center)
      Text('仅供烹饪参考，请遵循医师或营养师的个性化建议')
        .fontSize(11)
        .fontColor(this.t3)
        .textAlign(TextAlign.Center)
        .lineHeight(18)
    }
    .width('100%')
    .padding({ top: 24, bottom: 52, left: 20, right: 20 })
  }

  // ── 构建入口 ──────────────────────────────────────────────────────────────

  build() {
    Column() {
      this.NavBar()

      Scroll() {
        Column({ space: 0 }) {
          this.SectionTitle('今日饮食追踪')
          this.TodayIntakeCard()

          this.ImageCard()

          this.SectionTitle('三大营养素供能比（占总热量）')
          this.MacroCard()

          this.SectionTitle('每日推荐摄入量')
          this.FoodCard()

          this.SectionTitle('膳食核心建议')
          this.TipsCard()

          this.Footer()
        }
        .width('100%')
        .padding({ top: 6, bottom: 0 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bg)
  }
}
