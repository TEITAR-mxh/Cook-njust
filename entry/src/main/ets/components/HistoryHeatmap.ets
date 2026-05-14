/**
 * 历史足迹热力图组件（Native ArkUI 重构版）
 *
 * 展示最近 26 周的浏览热力格子，横向滚动，自动定位到最新一周。
 * 支持点击格子查看当天浏览的菜谱列表。
 * 深色模式通过内部 @StorageProp 自动切换。
 */
import { RecipeRepository } from '../data/RecipeRepository'
import type { RecipeWithId } from '../model/recipe'
import { AppColors } from '../constants/AppColors'

// ─── 数据结构 ─────────────────────────────────────────────────────────────────

interface WeekDay {
  dateStr:  string   // YYYY-MM-DD
  count:    number
  ids:      number[]
  isFuture: boolean
  isToday:  boolean
}

interface WeekData {
  weekIndex:   number   // 0 = 最旧的一周
  days:        WeekDay[]
  monthLabel:  string   // 仅当该周包含月份第1天时非空，如 "5月"
}

// ─── 工具函数 ─────────────────────────────────────────────────────────────────

function formatDateStr(d: Date): string {
  const y   = d.getFullYear()
  const m   = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

function countToLevel(count: number): number {
  if (count === 0) return 0
  if (count <= 2)  return 1
  if (count <= 4)  return 2
  if (count <= 7)  return 3
  return 4
}

// 5 级颜色：0=未浏览  1-4=由浅到深
const HEAT_COLORS_LIGHT: string[] = ['#EBEDF0', '#B3E5C4', '#4CD07D', '#1E8A3C', '#145228']
const HEAT_COLORS_DARK:  string[] = ['#1E1E1E', '#1A3D2B', '#1E6B40', '#22A85A', '#2ECC71']

// 星期标签（行）：只显示一/三/五
const DOW_LABELS: string[] = ['一', '', '三', '', '五', '', '日']

const WEEKS = 26   // 展示最近 26 周

// ─── 组件 ─────────────────────────────────────────────────────────────────────

@Component
export struct HistoryHeatmap {
  /**
   * 带日期的浏览历史（JSON string），父组件异步加载后写入。
   * @Watch 回调不能声明为 private。
   */
  @Prop @Watch('onDatedHistoryChange') datedHistory: string = '{}'

  // 颜色 prop（向后兼容）
  @Prop textColor:      string = '#111827'
  @Prop secondaryColor: string = '#6B7280'
  @Prop cardBgColor:    string = '#FFFFFF'

  // 内部深色模式感知
  @StorageProp('currentThemeMode')
  @Watch('onInternalThemeChange')
  private storedThemeMode: string = '系统默认'

  @StorageProp('isSystemDarkMode')
  @Watch('onInternalThemeChange')
  private isSystemDark: boolean = false

  @State private isDark: boolean = false

  @State private weeks:       WeekData[]   = []
  @State private selectedDay: string       = ''
  @State private dayRecipes:  RecipeWithId[] = []

  private scroller: Scroller = new Scroller()

  // ── 生命周期 ──────────────────────────────────────────────────────────────

  aboutToAppear(): void {
    this.isDark = this.calcIsDark()
    this.buildWeeks()
  }

  onDatedHistoryChange(): void {
    this.buildWeeks()
  }

  onInternalThemeChange(): void {
    this.isDark = this.calcIsDark()
  }

  private calcIsDark(): boolean {
    if (this.storedThemeMode === '深色模式') return true
    if (this.storedThemeMode === '浅色模式') return false
    return this.isSystemDark
  }

  // ── 颜色 Token ────────────────────────────────────────────────────────────

  private get bg(): string       { return this.isDark ? '#1C1C1E' : '#F5F5F7'    }
  private get surface(): string  { return this.isDark ? '#2C2C2E' : '#FFFFFF'     }
  private get t1(): string       { return this.isDark ? '#F2F2F7' : '#111827'     }
  private get t2(): string       { return this.isDark ? '#8E8E93' : '#6B7280'     }
  private get bdColor(): string  { return this.isDark ? '#3A3A3C' : '#E5E7EB'     }

  private heatColor(level: number): string {
    return this.isDark ? HEAT_COLORS_DARK[level] : HEAT_COLORS_LIGHT[level]
  }

  // ── 数据构建 ──────────────────────────────────────────────────────────────

  private buildWeeks(): void {
    let parsed: Record<string, number[]> = {}
    try {
      parsed = JSON.parse(this.datedHistory) as Record<string, number[]>
    } catch { /* 解析失败保持空对象 */ }

    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const todayStr = formatDateStr(today)

    // 起始日：今天所在周的周一，再往前 (WEEKS-1) 周
    const todayDow = today.getDay() === 0 ? 6 : today.getDay() - 1  // 0=周一
    const weekStart = new Date(today)
    weekStart.setDate(weekStart.getDate() - todayDow - (WEEKS - 1) * 7)

    const result: WeekData[] = []
    let prevLabelMonth = -1

    for (let w = 0; w < WEEKS; w++) {
      const days: WeekDay[] = []

      for (let d = 0; d < 7; d++) {
        const cur = new Date(weekStart)
        cur.setDate(cur.getDate() + w * 7 + d)
        const ds  = formatDateStr(cur)
        const ids = parsed[ds] ?? []
        days.push({
          dateStr:  ds,
          count:    ids.length,
          ids,
          isFuture: cur > today,
          isToday:  ds === todayStr,
        })
      }

      // 月份标签：当本周首日的月份与上一次标注的月份不同时显示
      // 这样每个月只在最早出现的列头标注一次
      const weekFirstDate = new Date(weekStart)
      weekFirstDate.setDate(weekFirstDate.getDate() + w * 7)
      const colMonth = weekFirstDate.getMonth()
      let monthLabel = ''
      if (colMonth !== prevLabelMonth) {
        monthLabel    = `${colMonth + 1}月`
        prevLabelMonth = colMonth
      }

      result.push({ weekIndex: w, days, monthLabel })
    }

    this.weeks = result
  }

  // ── 点击格子 ──────────────────────────────────────────────────────────────

  private handleCellTap(day: WeekDay): void {
    if (day.isFuture) return
    this.selectedDay = day.dateStr === this.selectedDay ? '' : day.dateStr

    if (this.selectedDay.length > 0) {
      const repo = RecipeRepository.getInstance()
      const list: RecipeWithId[] = []
      for (let i = 0; i < day.ids.length; i++) {
        const r = repo.getById(day.ids[i])
        if (r !== null) list.push(r)
      }
      this.dayRecipes = list
    } else {
      this.dayRecipes = []
    }
  }

  // ── 格子 ─────────────────────────────────────────────────────────────────

  @Builder
  private Cell(day: WeekDay) {
    Column()
      .width(14).height(14)
      .borderRadius(3)
      .backgroundColor(day.isFuture ? 'transparent' : this.heatColor(countToLevel(day.count)))
      .border({
        width: (day.dateStr === this.selectedDay || day.isToday) ? 1.5 : 0,
        color: day.dateStr === this.selectedDay ? '#FC4C52' : AppColors.BRAND_COLOR,
      })
      .opacity(day.isFuture ? 0.0 : 1.0)
      .onClick(() => { this.handleCellTap(day) })
  }

  // ── 构建 ─────────────────────────────────────────────────────────────────

  build() {
    Column({ space: 12 }) {

      // ── 图例 ────────────────────────────────────────────────────────────
      Row({ space: 6 }) {
        Text('少').fontSize(11).fontColor(this.t2)
        ForEach([0, 1, 2, 3, 4], (lv: number) => {
          Column()
            .width(12).height(12)
            .backgroundColor(this.heatColor(lv))
            .borderRadius(2.5)
        }, (lv: number) => `leg-${lv}`)
        Text('多').fontSize(11).fontColor(this.t2)
        Blank()
        Text('近6个月').fontSize(11).fontColor(this.t2)
      }.width('100%')

      // ── 热力图主体 ───────────────────────────────────────────────────────
      Row({ space: 0 }) {

        // 左侧星期标签列（固定，不滚动）
        Column({ space: 2 }) {
          // 月份标签占位（与右侧对齐）
          Text('').height(16)
          // 7 行星期标签
          ForEach(DOW_LABELS, (label: string, idx: number) => {
            Text(label)
              .fontSize(10)
              .fontColor(this.t2)
              .width(16)
              .height(14)
              .textAlign(TextAlign.Center)
              .opacity(label.length > 0 ? 1.0 : 0.0)
          }, (label: string, idx: number) => `dow-${idx}`)
        }
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Center)
        .flexShrink(0)
        .margin({ right: 4 })

        // 右侧：横向滚动的周列
        Scroll(this.scroller) {
          Row({ space: 3 }) {
            ForEach(this.weeks, (week: WeekData) => {
              Column({ space: 2 }) {
                // 月份标签行（不设宽度，允许向右自然溢出，避免竖排）
                Text(week.monthLabel)
                  .fontSize(10)
                  .fontColor(this.t2)
                  .height(16)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Clip })
                  .fontWeight(week.monthLabel.length > 0 ? FontWeight.Bold : FontWeight.Normal)

                // 7 天格子列
                ForEach(week.days, (day: WeekDay) => {
                  this.Cell(day)
                }, (day: WeekDay) => `cell-${day.dateStr}`)
              }
              .alignItems(HorizontalAlign.Center)
              .justifyContent(FlexAlign.Start)
              .width(14)
            }, (week: WeekData) => `week-${week.weekIndex}`)
          }
          .padding({ right: 4 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .layoutWeight(1)
        .onAppear(() => {
          // 自动滚动到最右（最新一周）
          this.scroller.scrollEdge(Edge.End)
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      // ── 选中日详情面板 ───────────────────────────────────────────────────
      if (this.selectedDay.length > 0) {
        Column({ space: 8 }) {
          Row({ space: 8 }) {
            Text(this.selectedDay)
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.t1)
            Text(this.dayRecipes.length > 0
              ? `浏览了 ${this.dayRecipes.length} 道菜`
              : '当天无记录')
              .fontSize(11)
              .fontColor(this.t2)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor(this.bg)
              .borderRadius(100)
              .border({ width: 0.5, color: this.bdColor })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          if (this.dayRecipes.length > 0) {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.dayRecipes, (r: RecipeWithId) => {
                Text(r.name)
                  .fontSize(12)
                  .fontColor(this.t2)
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .backgroundColor(this.bg)
                  .borderRadius(8)
                  .border({ width: 0.5, color: this.bdColor })
                  .margin({ right: 6, bottom: 6 })
              }, (r: RecipeWithId) => `dr-${r.id}`)
            }.width('100%')
          }
        }
        .width('100%')
        .padding(12)
        .backgroundColor(this.surface)
        .borderRadius(12)
        .border({ width: 0.5, color: this.bdColor })
      }

    }.width('100%')
  }
}
