/**
 * 今日饮食概览卡片
 *
 * 布局：
 *   ① 数据仪表区：渐变圆环（左）+ 摄入概览（右）
 *   ② 三大营养素三列迷你仪表（有数据时展示）
 *   ③ 全宽主操作按钮「拍照记录一餐」
 */
import { router } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { AppColors } from '../constants/AppColors'
import { DietDatabaseHelper } from '../data/DietDatabaseHelper'
import { CalorieTargetService } from '../service/CalorieTargetService'
import { CookPreferences } from '../store/CookPreferences'
import { DEFAULT_DIET_PROFILE } from '../model/dietProfile'
import type { CalorieTargets } from '../model/dietProfile'

/** 未设置个人档案时的默认目标，与健康目标页保持一致 */
const DEFAULT_TARGETS: CalorieTargets = CalorieTargetService.calcTargets(DEFAULT_DIET_PROFILE)

/** 圆环尺寸（vp） */
const RING_VP = 116

const COLOR_PROTEIN = '#22C55E'
const COLOR_FAT = '#F59E0B'
const COLOR_CARBS = '#3B82F6'

@Component
export struct DailyDietCircleCard {
  @Prop bgColor:        string  = AppColors.CARD_BG
  @Prop textColor:      string  = AppColors.GRAY_900
  @Prop secondaryColor: string  = AppColors.GRAY_500
  @Prop dividerColor:   string  = AppColors.GRAY_100
  @Prop isDark:         boolean = false

  @Prop @Watch('onRefreshKeyChange') refreshKey:  number = 0
  @Prop @Watch('onThemeChange')      themeSignal: number = 0

  @State private loading:     boolean = true
  @State private totalCal:    number  = 0
  @State private totalPro:    number  = 0
  @State private totalFat:    number  = 0
  @State private totalCarbs:  number  = 0
  @State private recordCount: number  = 0

  // 个性化每日目标（由健康目标页的身高 / 体重 / 目标推算）
  @State private goalCal:   number = DEFAULT_TARGETS.calories
  @State private goalPro:   number = DEFAULT_TARGETS.protein
  @State private goalFat:   number = DEFAULT_TARGETS.fat
  @State private goalCarbs: number = DEFAULT_TARGETS.carbs

  /** 圆环当前绘制进度（0~1），用于入场生长动画 */
  @State @Watch('onRingProgressChange') private ringProgress: number = 0
  /** 数据对应的目标进度，用于决定配色 */
  private targetRatio: number = 0

  // 按钮弹性动画
  @State private btnScale: number = 1.0

  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  private canvasReady: boolean = false

  aboutToAppear(): void { void this.loadData() }
  private onRefreshKeyChange(): void { void this.loadData() }
  private onThemeChange(): void { if (this.canvasReady) this.drawRing() }
  private onRingProgressChange(): void { if (this.canvasReady) this.drawRing() }

  /** 目标入口：进入健康目标设置页调整身高 / 体重 / 减重目标 */
  private openHealthGoal(): void {
    router.pushUrl({ url: 'pages/HealthGoalPage' }).catch((e: Error) => {
      console.error(`[DailyDietCircleCard] 跳转失败: ${e.message}`)
    })
  }

  private async loadData(): Promise<void> {
    this.loading = true
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (!host) { this.loading = false; return }
    try {
      const profile = await CookPreferences.getDietProfile(host)
      const targets: CalorieTargets = CalorieTargetService.calcTargets(profile)
      this.goalCal   = targets.calories
      this.goalPro   = targets.protein
      this.goalFat   = targets.fat
      this.goalCarbs = targets.carbs
    } catch (e) {
      console.error('[DailyDietCircleCard] 目标加载失败:', JSON.stringify(e))
    }
    try {
      const t = await DietDatabaseHelper.getInstance().queryTodayTotal(host)
      this.totalCal    = t.totalCalories
      this.totalPro    = t.totalProtein
      this.totalFat    = t.totalFat
      this.totalCarbs  = t.totalCarbs
      this.recordCount = t.recordCount
    } catch (e) {
      console.error('[DailyDietCircleCard] 加载失败:', JSON.stringify(e))
    }
    this.targetRatio = this.goalCal > 0 ? Math.min(this.totalCal / this.goalCal, 1) : 0
    this.loading = false
    if (this.canvasReady) this.startRingAnimation()
  }

  /** 圆环从 0 生长到当前进度 */
  private startRingAnimation(): void {
    this.ringProgress = 0
    this.getUIContext().animateTo({ duration: 780, curve: Curve.EaseOut }, () => {
      this.ringProgress = this.targetRatio
    })
  }

  // ── 绘制 ──────────────────────────────────────────────────────────────

  private get ringColor(): string {
    if (this.targetRatio < 0.6) return COLOR_PROTEIN
    if (this.targetRatio < 0.9) return AppColors.BRAND_COLOR
    return '#F97316'
  }

  private ringGradientColors(): string[] {
    if (this.targetRatio < 0.6) return ['#34D399', '#16A34A']
    if (this.targetRatio < 0.9) return ['#FF8A95', '#FF4757']
    return ['#FBBF24', '#F97316']
  }

  private drawRing(): void {
    const sz = vp2px(RING_VP)
    const c = this.ctx
    c.clearRect(0, 0, sz, sz)

    const cx = sz / 2
    const cy = sz / 2
    const lw = sz * 0.095
    const rad = sz / 2 - lw / 2 - 1

    // 轨道
    c.beginPath()
    c.arc(cx, cy, rad, 0, Math.PI * 2)
    c.strokeStyle = this.isDark ? '#2C2C2E' : '#EDEFF3'
    c.lineWidth = lw
    c.lineCap = 'round'
    c.stroke()

    const ratio = Math.max(0, Math.min(this.ringProgress, 1))
    if (ratio <= 0.004) return

    const colors = this.ringGradientColors()
    const grad = c.createLinearGradient(cx - rad, cy - rad, cx + rad, cy + rad)
    grad.addColorStop(0, colors[0])
    grad.addColorStop(1, colors[1])

    const endAngle = -Math.PI / 2 + ratio * Math.PI * 2
    c.beginPath()
    c.arc(cx, cy, rad, -Math.PI / 2, endAngle)
    c.strokeStyle = grad
    c.lineWidth = lw
    c.lineCap = 'round'
    c.stroke()

    // 进度头部高光点，让弧线终点更有焦点
    const ex = cx + rad * Math.cos(endAngle)
    const ey = cy + rad * Math.sin(endAngle)
    c.beginPath()
    c.arc(ex, ey, lw * 0.24, 0, Math.PI * 2)
    c.fillStyle = '#FFFFFF'
    c.fill()
  }

  // ── 工具 ──────────────────────────────────────────────────────────────

  private formatNumber(n: number): string {
    const s = `${Math.round(n)}`
    let out = ''
    let count = 0
    for (let i = s.length - 1; i >= 0; i--) {
      out = s.charAt(i) + out
      count++
      if (count % 3 === 0 && i > 0) out = ',' + out
    }
    return out
  }

  private macroPct(value: number, goal: number): number {
    return Math.min(value / Math.max(1, goal) * 100, 100)
  }

  // ── 子视图 ────────────────────────────────────────────────────────────

  /** 单列营养素迷你仪表 */
  @Builder
  private MacroStat(label: string, value: number, goal: number, color: string) {
    Column({ space: 5 }) {
      Row({ space: 5 }) {
        Row()
          .width(6).height(6).borderRadius(3)
          .backgroundColor(color)
        Text(label).fontSize(10).fontColor(this.secondaryColor)
      }
      .alignItems(VerticalAlign.Center)

      Row({ space: 2 }) {
        Text(`${Math.round(value)}`)
          .fontSize(15).fontWeight(FontWeight.Bold).fontColor(this.textColor)
        Text(`/${Math.round(goal)}g`)
          .fontSize(10).fontColor(this.secondaryColor).margin({ bottom: 1 })
      }
      .alignItems(VerticalAlign.Bottom)

      Stack({ alignContent: Alignment.Start }) {
        Row().width('100%').height(4)
          .backgroundColor(this.isDark ? '#2A2A2A' : '#EDEFF3')
          .borderRadius(2)
        Row().width(`${this.macroPct(value, goal)}%`).height(4)
          .backgroundColor(color)
          .borderRadius(2)
      }
      .width('100%')
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Column({ space: 0 }) {

      // ── ① 数据仪表区 ─────────────────────────────────────────────────
      Row({ space: 16 }) {

        Stack() {
          Canvas(this.ctx)
            .width(RING_VP).height(RING_VP)
            .onReady(() => {
              this.canvasReady = true
              if (this.loading) {
                this.drawRing()
              } else {
                this.startRingAnimation()
              }
            })
          Column({ space: 1 }) {
            if (this.loading) {
              LoadingProgress().width(18).height(18).color(AppColors.BRAND_COLOR)
            } else {
              Text(this.formatNumber(this.totalCal))
                .fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.textColor)
              Text('千卡').fontSize(9).fontColor(this.secondaryColor)
            }
          }
          .justifyContent(FlexAlign.Center)
        }
        .width(RING_VP).height(RING_VP)

        Column({ space: 6 }) {
          if (this.loading) {
            Row().width(110).height(12).backgroundColor(this.dividerColor).borderRadius(6)
            Row().width(80).height(26).backgroundColor(this.dividerColor).borderRadius(8)
            Row().width(96).height(12).backgroundColor(this.dividerColor).borderRadius(6)
          } else if (this.recordCount === 0) {
            Row({ space: 2 }) {
              Text(`每日目标 ${this.formatNumber(this.goalCal)} 千卡`)
                .fontSize(11).fontColor(AppColors.BRAND_COLOR)
              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(9).fontColor([AppColors.BRAND_COLOR])
            }
            .padding({ left: 8, right: 5, top: 3, bottom: 3 })
            .backgroundColor(this.isDark ? '#2A1215' : AppColors.BRAND_COLOR_LIGHT)
            .borderRadius(9)
            .onClick(() => { this.openHealthGoal() })

            Text('今天还没记录')
              .fontSize(15).fontWeight(FontWeight.Bold).fontColor(this.textColor)
            Text('拍一拍，自动识别热量与营养素')
              .fontSize(11).fontColor(this.secondaryColor).lineHeight(16)
          } else {
            // 记录条数 + 目标入口
            Row() {
              Text(`今日 ${this.recordCount} 条记录`)
                .fontSize(10).fontColor(this.secondaryColor).layoutWeight(1)
              Row({ space: 2 }) {
                Text(`目标 ${this.formatNumber(this.goalCal)}`)
                  .fontSize(10).fontColor(AppColors.BRAND_COLOR)
                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontSize(8).fontColor([AppColors.BRAND_COLOR])
              }
              .padding({ left: 7, right: 4, top: 2, bottom: 2 })
              .backgroundColor(this.isDark ? '#2A1215' : AppColors.BRAND_COLOR_LIGHT)
              .borderRadius(8)
              .onClick(() => { this.openHealthGoal() })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            Row({ space: 4 }) {
              Text(this.formatNumber(this.totalCal))
                .fontSize(30).fontWeight(FontWeight.Bold).fontColor(this.textColor)
              Text('kcal')
                .fontSize(11).fontColor(this.secondaryColor).margin({ bottom: 5 })
            }
            .alignItems(VerticalAlign.Bottom)

            // 剩余 / 超出：用色块强化状态
            Row({ space: 3 }) {
              Text(this.totalCal < this.goalCal ? '还可摄入' : '已超出')
                .fontSize(11)
                .fontColor(this.totalCal < this.goalCal ? COLOR_PROTEIN : '#F97316')
              Text(`${this.formatNumber(Math.abs(this.goalCal - this.totalCal))} 千卡`)
                .fontSize(11).fontWeight(FontWeight.Medium)
                .fontColor(this.totalCal < this.goalCal ? COLOR_PROTEIN : '#F97316')
            }
            .padding({ left: 9, right: 9, top: 4, bottom: 4 })
            .backgroundColor(this.totalCal < this.goalCal
              ? (this.isDark ? '#12301F' : '#E9F9EF')
              : (this.isDark ? '#3A2417' : '#FFF1E8'))
            .borderRadius(9)
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 18, bottom: 14 })
      .alignItems(VerticalAlign.Center)

      // ── ② 三大营养素 ─────────────────────────────────────────────────
      if (!this.loading && this.recordCount > 0) {
        Divider().color(this.dividerColor).margin({ left: 18, right: 18 })
        Row() {
          this.MacroStat('蛋白质', this.totalPro, this.goalPro, COLOR_PROTEIN)
          Divider()
            .vertical(true).height(30).strokeWidth(0.5)
            .color(this.dividerColor)
            .margin({ left: 6, right: 6 })
          this.MacroStat('脂肪', this.totalFat, this.goalFat, COLOR_FAT)
          Divider()
            .vertical(true).height(30).strokeWidth(0.5)
            .color(this.dividerColor)
            .margin({ left: 6, right: 6 })
          this.MacroStat('碳水', this.totalCarbs, this.goalCarbs, COLOR_CARBS)
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 14, bottom: 14 })
        .alignItems(VerticalAlign.Center)
      }

      // ── ③ 主操作按钮 ─────────────────────────────────────────────────
      Column() {
        Button() {
          Row({ space: 8 }) {
            Text('📸').fontSize(15)
            Text(this.recordCount === 0 ? '拍照记录今日饮食' : '继续记录一餐')
              .fontSize(15).fontColor(Color.White).fontWeight(FontWeight.Bold)
          }
        }
        .width('100%').height(48)
        .backgroundColor(AppColors.BRAND_COLOR)
        .borderRadius(14)
        .scale({ x: this.btnScale, y: this.btnScale })
        .shadow({ radius: 8, color: AppColors.BRAND_COLOR + '44', offsetX: 0, offsetY: 3 })
        .onClick(() => {
          this.getUIContext().animateTo({ duration: 90, curve: Curve.EaseIn }, () => { this.btnScale = 0.95 })
          setTimeout(() => {
            this.getUIContext().animateTo({ duration: 130, curve: Curve.EaseOut }, () => { this.btnScale = 1.0 })
          }, 95)
          router.pushUrl({ url: 'pages/CalorieScanPage' }).catch((e: Error) => {
            console.error(`[DailyDietCircleCard] 跳转失败: ${e.message}`)
          })
        })
      }
      .width('100%')
      .padding({ left: 14, right: 14, bottom: 14 })

    }
    .backgroundColor(this.bgColor)
    .borderRadius(16)
    .border({
      width: this.isDark ? 1 : 0,
      color: this.isDark ? '#28FFFFFF' : 'transparent',
    })
    .shadow({ radius: this.isDark ? 0 : 12, color: '#0C000000', offsetX: 0, offsetY: 2 })
    .clip(true)
  }
}
