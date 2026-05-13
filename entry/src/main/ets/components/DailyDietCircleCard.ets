/**
 * 今日饮食圆环卡片 — 紧凑版
 *
 * 布局：横排（圆环左 + 数据右），宏量三栏紧接其下，全宽记录按钮收底。
 * 相比 v2 版本显著降低卡片高度。
 */
import { router } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { AppColors } from '../constants/AppColors'
import { DietDatabaseHelper } from '../data/DietDatabaseHelper'

const DAILY_GOAL_KCAL = 2000
const GOAL_PROTEIN_G  = 75
const GOAL_FAT_G      = 55
const GOAL_CARBS_G    = 300

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

  @State private proBarW:  number = 0
  @State private fatBarW:  number = 0
  @State private carbBarW: number = 0

  @State private btnScale: number = 1.0

  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  private canvasReady: boolean = false

  aboutToAppear(): void { void this.loadData() }
  private onRefreshKeyChange(): void { void this.loadData() }
  private onThemeChange(): void { if (this.canvasReady) this.drawRing() }

  private async loadData(): Promise<void> {
    this.loading = true
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (!host) { this.loading = false; return }
    try {
      const t = await DietDatabaseHelper.getInstance().queryTodayTotal(host)
      this.totalCal    = t.totalCalories
      this.totalPro    = t.totalProtein
      this.totalFat    = t.totalFat
      this.totalCarbs  = t.totalCarbs
      this.recordCount = t.recordCount
      this.proBarW  = Math.min(this.totalPro   / GOAL_PROTEIN_G * 100, 100)
      this.fatBarW  = Math.min(this.totalFat   / GOAL_FAT_G     * 100, 100)
      this.carbBarW = Math.min(this.totalCarbs / GOAL_CARBS_G   * 100, 100)
    } catch (e) {
      console.error('[DailyDietCircleCard] 加载失败:', JSON.stringify(e))
    }
    this.loading = false
    if (this.canvasReady) this.drawRing()
  }

  private drawRing(): void {
    const VP = 100
    const sz  = vp2px(VP)
    const c   = this.ctx
    c.clearRect(0, 0, sz, sz)

    const cx    = sz / 2
    const cy    = sz / 2
    const rad   = sz * 0.37
    const lw    = sz * 0.115
    const ratio = this.totalCal <= 0 ? 0 : Math.min(this.totalCal / DAILY_GOAL_KCAL, 1.0)

    // 轨道
    c.beginPath()
    c.arc(cx, cy, rad, 0, Math.PI * 2)
    c.strokeStyle = this.isDark ? '#252525' : '#EBEBEB'
    c.lineWidth   = lw
    c.lineCap     = 'butt'
    c.stroke()

    if (ratio <= 0.005) return

    const arcColor = ratio < 0.6
      ? '#22C55E'
      : ratio < 0.9
        ? AppColors.BRAND_COLOR
        : '#F97316'

    c.beginPath()
    c.arc(cx, cy, rad, -Math.PI / 2, -Math.PI / 2 + ratio * Math.PI * 2)
    c.strokeStyle = arcColor
    c.lineWidth   = lw
    c.lineCap     = 'round'
    c.stroke()

    // 起始端补圆头
    const sx = cx + rad * Math.cos(-Math.PI / 2)
    const sy = cy + rad * Math.sin(-Math.PI / 2)
    c.beginPath()
    c.arc(sx, sy, lw / 2 - 0.5, 0, Math.PI * 2)
    c.fillStyle = arcColor
    c.fill()
  }

  /** 宏量进度条行 */
  @Builder
  MacroBar(label: string, valStr: string, barColor: string, widthPct: number) {
    Column({ space: 3 }) {
      Row() {
        Text(label).fontSize(10).fontColor(this.secondaryColor).layoutWeight(1)
        Text(valStr).fontSize(10).fontWeight(FontWeight.Bold).fontColor(this.textColor)
      }
      Stack({ alignContent: Alignment.Start }) {
        Row().width('100%').height(4)
          .backgroundColor(this.isDark ? '#252525' : '#EBEBEB')
          .borderRadius(2)
        Row().width(`${widthPct}%`).height(4)
          .backgroundColor(barColor)
          .borderRadius(2)
      }.width('100%')
    }
  }

  build() {
    Column({ space: 0 }) {

      // ── 主体：圆环（左）+ 信息（右）────────────────────────────────────
      Row({ space: 14 }) {

        // 圆环
        Stack() {
          Canvas(this.ctx)
            .width(100).height(100)
            .onReady(() => {
              this.canvasReady = true
              this.drawRing()
            })
          Column({ space: 1 }) {
            if (this.loading) {
              LoadingProgress().width(20).height(20).color(AppColors.BRAND_COLOR)
            } else {
              Text(`${Math.round(this.totalCal)}`)
                .fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.textColor)
              Text('千卡').fontSize(9).fontColor(this.secondaryColor)
            }
          }.justifyContent(FlexAlign.Center)
        }.width(100).height(100)

        // 右侧信息
        Column({ space: 6 }) {
          if (this.loading) {
            Row().width(80).height(12).backgroundColor(this.dividerColor).borderRadius(6)
            Row().width(56).height(10).backgroundColor(this.dividerColor).borderRadius(5)
          } else if (this.recordCount === 0) {
            Text('今天还没有记录')
              .fontSize(13).fontColor(this.textColor).fontWeight(FontWeight.Medium)
            Text('拍一餐开始追踪今日热量')
              .fontSize(11).fontColor(this.secondaryColor)
          } else {
            Row({ space: 3 }) {
              Text(`${Math.round(this.totalCal)}`)
                .fontSize(26).fontColor(AppColors.BRAND_COLOR).fontWeight(FontWeight.Bold)
              Text('kcal').fontSize(11).fontColor(this.secondaryColor).margin({ top: 10 })
            }
            Row({ space: 6 }) {
              Text(`目标 ${DAILY_GOAL_KCAL}`).fontSize(11).fontColor(this.secondaryColor)
              Text('·').fontSize(11).fontColor(this.dividerColor)
              Text(this.totalCal < DAILY_GOAL_KCAL
                ? `还剩 ${DAILY_GOAL_KCAL - Math.round(this.totalCal)}`
                : '已达标 🎉')
                .fontSize(11)
                .fontColor(this.totalCal < DAILY_GOAL_KCAL ? '#22C55E' : '#F97316')
                .fontWeight(FontWeight.Medium)
            }
            if (this.recordCount > 0) {
              Text(`${this.recordCount} 条饮食记录`)
                .fontSize(10).fontColor(this.secondaryColor)
            }
          }

          // 记录按钮
          Row({ space: 5 }) {
            Text('📸').fontSize(12)
            Text('记录一餐').fontSize(12).fontColor(Color.White).fontWeight(FontWeight.Bold)
          }
          .padding({ left: 14, right: 14, top: 7, bottom: 7 })
          .backgroundColor(AppColors.BRAND_COLOR)
          .borderRadius(18)
          .scale({ x: this.btnScale, y: this.btnScale })
          .shadow({ radius: 6, color: AppColors.BRAND_COLOR + '44', offsetX: 0, offsetY: 2 })
          .onClick(() => {
            animateTo({ duration: 90, curve: Curve.EaseIn }, () => { this.btnScale = 0.92 })
            setTimeout(() => {
              animateTo({ duration: 130, curve: Curve.EaseOut }, () => { this.btnScale = 1.0 })
            }, 95)
            router.pushUrl({ url: 'pages/CalorieScanPage' }).catch((e: Error) => {
              console.error(`[DailyDietCircleCard] 跳转失败: ${e.message}`)
            })
          })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 16, bottom: 14 })
      .alignItems(VerticalAlign.Center)

      // ── 宏量进度条（有数据时）──────────────────────────────────────────
      if (!this.loading && this.recordCount > 0) {
        Divider().color(this.dividerColor).margin({ left: 18, right: 18 })
        Column({ space: 8 }) {
          this.MacroBar('蛋白质', `${Math.round(this.totalPro)}g / ${GOAL_PROTEIN_G}g`,  '#22C55E', this.proBarW)
          this.MacroBar('脂肪',   `${Math.round(this.totalFat)}g / ${GOAL_FAT_G}g`,      '#F59E0B', this.fatBarW)
          this.MacroBar('碳水',   `${Math.round(this.totalCarbs)}g / ${GOAL_CARBS_G}g`,  '#3B82F6', this.carbBarW)
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 10, bottom: 14 })
      }

      // ── 底部跳转链接 ───────────────────────────────────────────────────
      Divider().color(this.dividerColor).margin({ left: 18, right: 18 })
      Row({ space: 4 }) {
        Text('查看饮食结构建议').fontSize(12).fontColor(this.secondaryColor)
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(11).fontColor([this.secondaryColor])
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 10, bottom: 12 })
      .onClick(() => {
        router.pushUrl({ url: 'pages/DietaryStructurePage' }).catch((e: Error) => {
          console.error(`[DailyDietCircleCard] 跳转失败: ${e.message}`)
        })
      })
    }
    .backgroundColor(this.bgColor)
    .borderRadius(20)
    .border({
      width: this.isDark ? 1 : 0,
      color: this.isDark ? '#28FFFFFF' : 'transparent',
    })
    .shadow({ radius: this.isDark ? 0 : 10, color: '#0A000000', offsetX: 0, offsetY: 2 })
    .clip(true)
  }
}
