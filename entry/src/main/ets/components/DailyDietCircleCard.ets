/**
 * 今日饮食圆环卡片 — Premium UI
 *
 * 升级点：
 * - 渐变色进度弧（绿→品牌红→橙，按摄入比例切换）
 * - 圆环下方三条宏量营养素进度条（蛋白/脂肪/碳水）
 * - 深色模式下 1px 半透明白色描边
 * - 记录按钮：轻弹缩放动效
 * 父组件通过递增 refreshKey 触发数据刷新（如 onPageShow）。
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
  // ── 父组件注入 ────────────────────────────────────────────────────────
  @Prop bgColor:        string  = AppColors.CARD_BG
  @Prop textColor:      string  = AppColors.GRAY_900
  @Prop secondaryColor: string  = AppColors.GRAY_500
  @Prop dividerColor:   string  = AppColors.GRAY_100
  @Prop isDark:         boolean = false

  @Prop @Watch('onRefreshKeyChange') refreshKey:  number = 0
  @Prop @Watch('onThemeChange')      themeSignal: number = 0

  // ── 数据 ─────────────────────────────────────────────────────────────
  @State private loading:     boolean = true
  @State private totalCal:    number  = 0
  @State private totalPro:    number  = 0
  @State private totalFat:    number  = 0
  @State private totalCarbs:  number  = 0
  @State private recordCount: number  = 0

  // ── 宏量进度条宽度（0-100，@State 基本类型，proxy 安全）───────────────
  @State private proBarW:  number = 0
  @State private fatBarW:  number = 0
  @State private carbBarW: number = 0

  // ── 按钮动效 ──────────────────────────────────────────────────────────
  @State private btnScale: number = 1.0

  // ── Canvas ────────────────────────────────────────────────────────────
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  private canvasReady: boolean = false

  // ── 生命周期 ──────────────────────────────────────────────────────────

  aboutToAppear(): void { void this.loadData() }
  private onRefreshKeyChange(): void { void this.loadData() }
  private onThemeChange(): void { if (this.canvasReady) this.drawRing() }

  // ── 数据加载 ──────────────────────────────────────────────────────────

  private async loadData(): Promise<void> {
    this.loading = true
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (!host) { this.loading = false; return }
    try {
      const t = await DietDatabaseHelper.getInstance().queryTodayTotal(host)
      this.totalCal   = t.totalCalories
      this.totalPro   = t.totalProtein
      this.totalFat   = t.totalFat
      this.totalCarbs = t.totalCarbs
      this.recordCount = t.recordCount
      // 更新进度条宽度（@State 基本类型）
      this.proBarW  = Math.min(this.totalPro   / GOAL_PROTEIN_G * 100, 100)
      this.fatBarW  = Math.min(this.totalFat   / GOAL_FAT_G     * 100, 100)
      this.carbBarW = Math.min(this.totalCarbs / GOAL_CARBS_G   * 100, 100)
    } catch (e) {
      console.error('[DailyDietCircleCard] 加载失败:', JSON.stringify(e))
    }
    this.loading = false
    if (this.canvasReady) this.drawRing()
  }

  // ── Canvas 圆环 ────────────────────────────────────────────────────────

  private drawRing(): void {
    const VP = 116
    const sz = vp2px(VP)
    const c  = this.ctx
    c.clearRect(0, 0, sz, sz)

    const cx    = sz / 2
    const cy    = sz / 2
    const rad   = sz * 0.36
    const lw    = sz * 0.10
    const ratio = this.totalCal <= 0 ? 0 : Math.min(this.totalCal / DAILY_GOAL_KCAL, 1.0)

    // 轨道
    c.beginPath()
    c.arc(cx, cy, rad, 0, Math.PI * 2)
    c.strokeStyle = this.isDark ? '#252525' : '#EBEBEB'
    c.lineWidth   = lw
    c.lineCap     = 'butt'
    c.stroke()

    // 进度弧
    if (ratio > 0.005) {
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

      // 补绘起始端圆头
      const sx = cx + rad * Math.cos(-Math.PI / 2)
      const sy = cy + rad * Math.sin(-Math.PI / 2)
      c.beginPath()
      c.arc(sx, sy, lw / 2 - 0.5, 0, Math.PI * 2)
      c.fillStyle = arcColor
      c.fill()
    }
  }

  // ── Builders ──────────────────────────────────────────────────────────

  /** 骨架占位行 */
  @Builder
  SkeletonRow(w: number) {
    Row().width(w).height(12).backgroundColor(this.dividerColor).borderRadius(6)
  }

  /** 宏量营养素进度条（widthPct 为 @State 基本类型）*/
  @Builder
  MacroBar(label: string, valStr: string, barColor: string, widthPct: number) {
    Column({ space: 4 }) {
      Row() {
        Text(label).fontSize(11).fontColor(this.secondaryColor).layoutWeight(1)
        Text(valStr).fontSize(11).fontWeight(FontWeight.Bold).fontColor(this.textColor)
      }
      Stack({ alignContent: Alignment.Start }) {
        Row().width('100%').height(5)
          .backgroundColor(this.isDark ? '#252525' : '#EBEBEB')
          .borderRadius(3)
        Row().width(`${widthPct}%`).height(5)
          .backgroundColor(barColor)
          .borderRadius(3)
      }.width('100%')
    }
  }

  build() {
    Column({ space: 0 }) {

      // ── 主体：圆环 + 右侧信息 ─────────────────────────────────────────
      Row({ space: 16 }) {

        // 圆环 + 中心文字
        Stack() {
          Canvas(this.ctx)
            .width(116).height(116)
            .onReady(() => {
              this.canvasReady = true
              this.drawRing()
            })

          Column({ space: 2 }) {
            if (this.loading) {
              LoadingProgress().width(22).height(22).color(AppColors.BRAND_COLOR)
            } else {
              Text(`${Math.round(this.totalCal)}`)
                .fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.textColor)
              Text('千卡').fontSize(10).fontColor(this.secondaryColor)
            }
          }.justifyContent(FlexAlign.Center)
        }.width(116).height(116)

        // 右侧文字 + 按钮
        Column({ space: 10 }) {
          if (this.loading) {
            this.SkeletonRow(88)
            this.SkeletonRow(60)
          } else if (this.recordCount === 0) {
            Column({ space: 5 }) {
              Text('今天还没有记录')
                .fontSize(14).fontColor(this.textColor).fontWeight(FontWeight.Medium)
              Text('来拍第一餐，追踪今日热量')
                .fontSize(12).fontColor(this.secondaryColor)
            }.alignItems(HorizontalAlign.Start)
          } else {
            Column({ space: 3 }) {
              Text('今日已摄入').fontSize(12).fontColor(this.secondaryColor)
              Row({ space: 2 }) {
                Text(`${Math.round(this.totalCal)}`)
                  .fontSize(28).fontColor(AppColors.BRAND_COLOR).fontWeight(FontWeight.Bold)
                Text('kcal').fontSize(12).fontColor(this.secondaryColor).margin({ top: 10 })
              }
              Text(`还剩 ${Math.max(DAILY_GOAL_KCAL - Math.round(this.totalCal), 0)} kcal`)
                .fontSize(12).fontColor(this.secondaryColor)
            }.alignItems(HorizontalAlign.Start)
          }

          // 记录按钮
          Row({ space: 5 }) {
            Text('📸').fontSize(13)
            Text('记录一餐').fontSize(13).fontColor(Color.White).fontWeight(FontWeight.Bold)
          }
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor(AppColors.BRAND_COLOR)
          .borderRadius(20)
          .scale({ x: this.btnScale, y: this.btnScale })
          .shadow({ radius: 8, color: AppColors.BRAND_COLOR + '44', offsetX: 0, offsetY: 3 })
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
      .padding({ left: 20, right: 20, top: 18, bottom: 14 })
      .alignItems(VerticalAlign.Center)

      // ── 宏量营养素进度条（有数据时显示）─────────────────────────────────
      if (!this.loading && this.recordCount > 0) {
        Divider().color(this.dividerColor).margin({ left: 20, right: 20 })

        Column({ space: 10 }) {
          this.MacroBar('蛋白质', `${Math.round(this.totalPro)}g`,   '#22C55E', this.proBarW)
          this.MacroBar('脂肪',   `${Math.round(this.totalFat)}g`,   '#F59E0B', this.fatBarW)
          this.MacroBar('碳水',   `${Math.round(this.totalCarbs)}g`, '#3B82F6', this.carbBarW)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 12, bottom: 6 })
      }

      Divider().color(this.dividerColor).margin({ left: 20, right: 20 })

      // ── 底部入口 ─────────────────────────────────────────────────────
      Row({ space: 4 }) {
        Text('查看饮食结构建议').fontSize(13).fontColor(this.secondaryColor)
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(12).fontColor([this.secondaryColor])
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 16 })
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
