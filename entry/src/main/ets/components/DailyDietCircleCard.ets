/**
 * 今日饮食圆环卡片
 * 通过 DietDatabaseHelper 加载今日摄入数据，绘制华为健康风格圆环进度，
 * 提供「记录一餐」和「饮食建议」入口。
 * 父组件通过递增 refreshKey 来触发数据刷新（如 onPageShow）。
 */
import { router } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { AppColors } from '../constants/AppColors'
import { DietDatabaseHelper } from '../data/DietDatabaseHelper'

/** 每日目标热量（千卡） */
const DAILY_GOAL_KCAL = 2000

@Component
export struct DailyDietCircleCard {
  // ── 主题颜色（由父组件注入）──
  @Prop bgColor: string = AppColors.CARD_BG
  @Prop textColor: string = AppColors.GRAY_900
  @Prop secondaryColor: string = AppColors.GRAY_500
  @Prop dividerColor: string = AppColors.GRAY_100
  @Prop isDark: boolean = false

  /** 父组件在 onPageShow 中递增此值来触发数据刷新 */
  @Prop
  @Watch('onRefreshKeyChange')
  refreshKey: number = 0

  /** 主题切换时重绘圆环 */
  @Prop
  @Watch('onThemeChange')
  themeSignal: number = 0

  // ── 内部数据状态 ──
  @State private loading: boolean = true
  @State private totalCalories: number = 0
  @State private totalProtein: number = 0
  @State private totalFat: number = 0
  @State private totalCarbs: number = 0
  @State private recordCount: number = 0

  // ── Canvas ──
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  private canvasReady: boolean = false

  // ── 生命周期 ──

  aboutToAppear(): void {
    void this.loadData()
  }

  // ── 监听回调 ──

  private onRefreshKeyChange(): void {
    void this.loadData()
  }

  private onThemeChange(): void {
    if (this.canvasReady) this.drawRing()
  }

  // ── 数据加载 ──

  private async loadData(): Promise<void> {
    this.loading = true
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (!host) {
      this.loading = false
      return
    }
    try {
      const total = await DietDatabaseHelper.getInstance().queryTodayTotal(host)
      this.totalCalories = total.totalCalories
      this.totalProtein  = total.totalProtein
      this.totalFat      = total.totalFat
      this.totalCarbs    = total.totalCarbs
      this.recordCount   = total.recordCount
    } catch (e) {
      console.error('[DailyDietCircleCard] 加载今日摄入失败:', JSON.stringify(e))
    }
    this.loading = false
    if (this.canvasReady) this.drawRing()
  }

  // ── 计算属性 ──

  private get ratio(): number {
    if (this.totalCalories <= 0) return 0
    return Math.min(this.totalCalories / DAILY_GOAL_KCAL, 1.0)
  }

  private get consumed(): number {
    return Math.round(this.totalCalories)
  }

  private get remaining(): number {
    return Math.max(DAILY_GOAL_KCAL - this.consumed, 0)
  }

  /** 圆环进度颜色：< 90% 品牌色，>= 90% 橙色警示 */
  private get ringProgressColor(): string {
    return this.ratio >= 0.9 ? '#F97316' : AppColors.BRAND_COLOR
  }

  // ── Canvas 绘制 ──

  private drawRing(): void {
    const CANVAS_VP = 112
    const size = vp2px(CANVAS_VP)
    const ctx  = this.context
    ctx.clearRect(0, 0, size, size)

    const cx        = size / 2
    const cy        = size / 2
    const radius    = size * 0.36
    const lineWidth = size * 0.105

    // 轨道（灰色背景环）
    ctx.beginPath()
    ctx.arc(cx, cy, radius, 0, Math.PI * 2)
    ctx.strokeStyle = this.isDark ? '#2D2D2D' : '#E5E7EB'
    ctx.lineWidth   = lineWidth
    ctx.lineCap     = 'butt'
    ctx.stroke()

    // 进度弧
    const r = this.ratio
    if (r > 0.01) {
      const start = -Math.PI / 2
      const end   = start + r * Math.PI * 2
      ctx.beginPath()
      ctx.arc(cx, cy, radius, start, end)
      ctx.strokeStyle = this.ringProgressColor
      ctx.lineWidth   = lineWidth
      ctx.lineCap     = 'round'
      ctx.stroke()
    }
  }

  // ── build ──

  build() {
    Column({ space: 0 }) {

      // 主体区：圆环 + 文字 + 按钮
      Row({ space: 16 }) {

        // 左：圆环 + 数字叠加
        Stack() {
          Canvas(this.context)
            .width(112).height(112)
            .onReady(() => {
              this.canvasReady = true
              this.drawRing()
            })

          // 圆环中心文字
          Column({ space: 1 }) {
            if (this.loading) {
              LoadingProgress().width(22).height(22).color(AppColors.BRAND_COLOR)
            } else {
              Text(`${this.consumed}`)
                .fontSize(20)
                .fontColor(this.textColor)
                .fontWeight(FontWeight.Bold)
              Text('千卡')
                .fontSize(10)
                .fontColor(this.secondaryColor)
            }
          }.justifyContent(FlexAlign.Center)
        }.width(112).height(112)

        // 右：信息文字 + 记录按钮
        Column({ space: 12 }) {

          if (this.loading) {
            // 骨架屏
            Column({ space: 8 }) {
              Row().width(80).height(14).backgroundColor(this.dividerColor).borderRadius(7)
              Row().width(60).height(11).backgroundColor(this.dividerColor).borderRadius(6)
            }
          } else if (this.recordCount === 0) {
            // 空状态
            Column({ space: 5 }) {
              Text('今天还没有记录').fontSize(14).fontColor(this.textColor).fontWeight(FontWeight.Medium)
              Text('来拍第一餐吧 👆').fontSize(12).fontColor(this.secondaryColor)
            }.alignItems(HorizontalAlign.Start)
          } else {
            // 有数据
            Column({ space: 4 }) {
              Text('今日已摄入').fontSize(12).fontColor(this.secondaryColor)
              Row({ space: 3 }) {
                Text(`${this.consumed}`)
                  .fontSize(26)
                  .fontColor(AppColors.BRAND_COLOR)
                  .fontWeight(FontWeight.Bold)
                Text('kcal')
                  .fontSize(12)
                  .fontColor(this.secondaryColor)
                  .margin({ top: 9 })
              }
              Text(`剩余 ${this.remaining} kcal`)
                .fontSize(12)
                .fontColor(this.secondaryColor)
            }.alignItems(HorizontalAlign.Start)
          }

          // 记录按钮
          Button() {
            Row({ space: 5 }) {
              Text('📸').fontSize(14)
              Text('记录一餐')
                .fontSize(13)
                .fontColor(Color.White)
                .fontWeight(FontWeight.Bold)
            }
          }
          .height(38)
          .padding({ left: 18, right: 18 })
          .backgroundColor(AppColors.BRAND_COLOR)
          .borderRadius(12)
          .onClick(() => {
            router.pushUrl({ url: 'pages/CalorieScanPage' }).catch((e: Error) => {
              console.error(`[DailyDietCircleCard] 跳转 CalorieScanPage 失败: ${e.message}`)
            })
          })

        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 14 })
      .alignItems(VerticalAlign.Center)

      Divider().color(this.dividerColor).margin({ left: 20, right: 20 })

      // 底部：饮食建议链接
      Row({ space: 4 }) {
        Text('饮食结构建议')
          .fontSize(13)
          .fontColor(this.secondaryColor)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(12)
          .fontColor([this.secondaryColor])
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 16 })
      .onClick(() => {
        router.pushUrl({ url: 'pages/DietaryStructurePage' }).catch((e: Error) => {
          console.error(`[DailyDietCircleCard] 跳转 DietaryStructurePage 失败: ${e.message}`)
        })
      })
    }
    .backgroundColor(this.bgColor)
    .borderRadius(20)
  }
}
