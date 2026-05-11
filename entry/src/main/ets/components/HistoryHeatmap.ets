/**
 * 历史足迹日历热力图组件
 * 展示最近 12 周（7行 × 12列）的浏览热力格子。
 * 颜色深浅按当天浏览菜谱数量映射。
 * 支持点击格子查看当天浏览的菜谱列表。
 */
import { RecipeRepository } from '../data/RecipeRepository'
import type { RecipeWithId } from '../model/recipe'

interface DayCell {
  dateStr: string    // YYYY-MM-DD
  count: number
  ids: number[]
}

/** 将颜色等级（0~4）映射到十六进制颜色字符串 */
function heatColor(level: number): string {
  switch (level) {
    case 0: return '#EBEDF0'
    case 1: return '#A8D8C4'
    case 2: return '#3DD6B5'
    case 3: return '#FF9100'
    case 4: return '#E85D04'
    default: return '#EBEDF0'
  }
}

function countToLevel(count: number): number {
  if (count === 0) return 0
  if (count <= 2) return 1
  if (count <= 4) return 2
  if (count <= 7) return 3
  return 4
}

function formatDateStr(d: Date): string {
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}


@Component
export struct HistoryHeatmap {
  /** 带日期的浏览历史，由父组件传入（来自 CookPreferences.getDatedHistory） */
  @Prop datedHistory: string = '{}'
  /** 文字颜色（适配主题） */
  @Prop textColor: string = '#111827'
  @Prop secondaryColor: string = '#6B7280'
  @Prop cardBgColor: string = '#FFFFFF'

  /** 当点击格子时的回调，传入当天菜谱 ID 数组 */
  onDayCellClick?: (dateStr: string, ids: number[]) => void

  @State private cells: DayCell[] = []
  @State private selectedDay: string = ''
  @State private dayRecipes: RecipeWithId[] = []

  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private context2d: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)

  private readonly COLS: number = 12    // 12周
  private readonly ROWS: number = 7     // 7天/周
  private readonly GAP: number = 3
  private readonly PADDING: number = 4

  aboutToAppear(): void {
    this.buildCells()
  }

  /** @Watch 不适用于 @Prop string，在 onDateHistoryChange 中手动调用 */
  private buildCells(): void {
    let parsed: Record<string, number[]> = {}
    try {
      parsed = JSON.parse(this.datedHistory) as Record<string, number[]>
    } catch { }

    const today = new Date()
    today.setHours(0, 0, 0, 0)

    // 从 (12*7 - 1) 天前到今天，共 84 天
    const totalDays = this.COLS * this.ROWS
    const cells: DayCell[] = []
    for (let i = totalDays - 1; i >= 0; i--) {
      const d = new Date(today)
      d.setDate(d.getDate() - i)
      const ds = formatDateStr(d)
      const ids: number[] = parsed[ds] ?? []
      cells.push({ dateStr: ds, count: ids.length, ids })
    }
    this.cells = cells
  }

  private drawHeatmap(): void {
    if (this.cells.length === 0) return

    const ctx = this.context2d
    const totalW = ctx.width
    const cellSize = Math.floor((totalW - this.PADDING * 2 - this.GAP * (this.COLS - 1)) / this.COLS)
    const totalH = cellSize * this.ROWS + this.GAP * (this.ROWS - 1) + this.PADDING * 2

    ctx.clearRect(0, 0, totalW, totalH)

    for (let col = 0; col < this.COLS; col++) {
      for (let row = 0; row < this.ROWS; row++) {
        const idx = col * this.ROWS + row
        if (idx >= this.cells.length) continue

        const cell = this.cells[idx]
        const x = this.PADDING + col * (cellSize + this.GAP)
        const y = this.PADDING + row * (cellSize + this.GAP)
        const level = countToLevel(cell.count)
        const color = heatColor(level)

        ctx.fillStyle = color

        // 圆角矩形（手动绘制）
        const r = 3
        ctx.beginPath()
        ctx.moveTo(x + r, y)
        ctx.lineTo(x + cellSize - r, y)
        ctx.arcTo(x + cellSize, y, x + cellSize, y + r, r)
        ctx.lineTo(x + cellSize, y + cellSize - r)
        ctx.arcTo(x + cellSize, y + cellSize, x + cellSize - r, y + cellSize, r)
        ctx.lineTo(x + r, y + cellSize)
        ctx.arcTo(x, y + cellSize, x, y + cellSize - r, r)
        ctx.lineTo(x, y + r)
        ctx.arcTo(x, y, x + r, y, r)
        ctx.closePath()
        ctx.fill()

        // 选中高亮边框
        if (cell.dateStr === this.selectedDay) {
          ctx.strokeStyle = '#FC4C52'
          ctx.lineWidth = 1.5
          ctx.stroke()
        }
      }
    }
  }

  /** 将点击坐标映射到 cell，返回对应 DayCell 或 null */
  private hitTest(x: number, y: number): DayCell | null {
    const totalW = this.context2d.width
    const cellSize = Math.floor((totalW - this.PADDING * 2 - this.GAP * (this.COLS - 1)) / this.COLS)

    const col = Math.floor((x - this.PADDING) / (cellSize + this.GAP))
    const row = Math.floor((y - this.PADDING) / (cellSize + this.GAP))

    if (col < 0 || col >= this.COLS || row < 0 || row >= this.ROWS) return null

    const idx = col * this.ROWS + row
    if (idx >= this.cells.length) return null
    return this.cells[idx]
  }

  build() {
    Column({ space: 12 }) {
      // 图例
      Row({ space: 6 }) {
        Text('少').fontSize(11).fontColor(this.secondaryColor)
        ForEach([0, 1, 2, 3, 4], (level: number) => {
          Column()
            .width(12).height(12)
            .backgroundColor(heatColor(level))
            .borderRadius(2)
        }, (level: number) => `legend-${level}`)
        Text('多').fontSize(11).fontColor(this.secondaryColor)
        Blank()
        Text('近12周浏览热力').fontSize(11).fontColor(this.secondaryColor)
      }.width('100%')

      // 热力图 Canvas
      Canvas(this.context2d)
        .width('100%')
        .height(120)
        .onReady(() => {
          this.buildCells()
          this.drawHeatmap()
        })
        .onClick((event: ClickEvent) => {
          const cell = this.hitTest(event.x, event.y)
          if (cell === null) return
          this.selectedDay = cell.dateStr
          // 刷新画布（高亮选中）
          this.drawHeatmap()
          // 加载当天菜谱
          if (cell.ids.length > 0) {
            const repo = RecipeRepository.getInstance()
            const recipes: RecipeWithId[] = []
            for (let i = 0; i < cell.ids.length; i++) {
              const r = repo.getById(cell.ids[i])
              if (r !== null) recipes.push(r)
            }
            this.dayRecipes = recipes
          } else {
            this.dayRecipes = []
          }
          if (this.onDayCellClick !== undefined) {
            this.onDayCellClick(cell.dateStr, cell.ids)
          }
        })

      // 选中日详情
      if (this.selectedDay.length > 0) {
        Column({ space: 6 }) {
          Text(this.selectedDay)
            .fontSize(13).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          if (this.dayRecipes.length > 0) {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.dayRecipes, (r: RecipeWithId) => {
                Text(r.name)
                  .fontSize(12).fontColor(this.secondaryColor)
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .backgroundColor(this.cardBgColor)
                  .borderRadius(8)
                  .borderWidth(0.5)
                  .borderColor('#E5E7EB')
                  .margin({ right: 6, bottom: 6 })
              }, (r: RecipeWithId) => `day-${r.id}`)
            }.width('100%')
          } else {
            Text('当天暂无浏览记录')
              .fontSize(12).fontColor(this.secondaryColor)
          }
        }
        .width('100%')
        .padding(12)
        .backgroundColor(this.cardBgColor)
        .borderRadius(12)
        .borderWidth(0.5)
        .borderColor('#E5E7EB')
      }
    }.width('100%')
  }
}
