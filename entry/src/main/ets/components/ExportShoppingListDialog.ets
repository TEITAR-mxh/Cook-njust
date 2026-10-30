/**
 * 采购清单图片导出弹窗
 * - 3 种视觉模板：唯美便签 / 极简白卡 / 暗黑柔光
 * - 食材分类分组 + 勾选圆圈 + 用量显示
 * - SaveButton 安全控件保存到相册
 */
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { image } from '@kit.ImageKit'
import { fileIo } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'
import { LengthMetricsUnit } from '@kit.ArkUI'
import { AppColors, ThemeManager } from '../constants/AppColors'
import type { MissingItem } from '../service/ShoppingListService'
import { ShoppingCategory, IngredientTypeMapper } from '../utils/IngredientTypeMapper'

// ── Canvas 尺寸常量（1080 宽，高度随内容自适应）──────────────────────
// 说明：Canvas 以 PX 单位模式绘制（见 drawCtx 的 LengthMetricsUnit.PX）。
// 默认 vp 模式下 font 的 px 是物理像素，与 vp 布局坐标混用会导致导出的
// 文字相对版面小得多（手机上几乎看不清），因此这里统一用物理像素坐标。
const CANVAS_W: number = 1080
const PAD_X: number = 76
const CONTENT_W: number = CANVAS_W - PAD_X * 2
const ITEM_H: number = 140                // 食材行高：字号更小、行距更松，留出高级感
const CAT_HEADER_H: number = 96           // 分类标题高度
const CAT_BLOCK_PAD: number = 14          // 分类卡片底部内边距
const CAT_GAP: number = 30                // 分类卡片之间的间距
const FOOTER_H: number = 220              // 页脚区域高度
const MIN_CANVAS_H: number = 1680         // 内容很少时保持竖版比例
const MAX_CANVAS_H: number = 6000         // 超长清单上限，超出时给出提示
const LIST_FOOT_RESERVE: number = 72      // 列表与页脚之间的留白 / 溢出提示空间

// 页头内部基线（textBaseline = middle）
const BRAND_Y: number = 72
const TITLE_Y: number = 178
const SUB_Y: number = 262
const META_Y: number = 312
const META_PILL_H: number = 38
const DIVIDER_Y: number = 394
const LIST_START_Y: number = 430

// ── 样式模板定义 ──────────────────────────────────────────────────────────

interface StyleDef {
  key: string
  label: string
  previewBg: string
  previewBgDark: string
  previewAccent: string
  previewAccentDark: string
}

const STYLES: StyleDef[] = [
  { key: 'note', label: '唯美便签', previewBg: '#FEFCF5', previewBgDark: '#2C2820', previewAccent: '#F5A623', previewAccentDark: '#FFB347' },
  { key: 'card', label: '极简白卡', previewBg: '#FFFFFF', previewBgDark: '#1A1A1A', previewAccent: '#FF4757', previewAccentDark: '#FF5A5A' },
  { key: 'dark', label: '暗黑柔光', previewBg: '#F5F0E0', previewBgDark: '#1E1C18', previewAccent: '#8B4513', previewAccentDark: '#D4A574' }
]

// ── 颜色辅助 ──────────────────────────────────────────────────────────────

function pickColor(light: string, dark: string, isDark: boolean): string {
  return isDark ? dark : light
}

@Component
export struct ExportShoppingListDialog {
  @Prop missingItems: MissingItem[] = []
  @Prop recipeName: string = ''
  @Prop totalStuff: number = 0
  @Prop @Watch('onVisibleChange') visible: boolean = false
  onClose?: () => void

  @State private selectedIdx: number = 0
  @State private saving: boolean = false
  @State private toastMsg: string = ''
  @State private toastVisible: boolean = false
  @State private saveSuccess: boolean = false
  @State private swiperKey: number = 0
  @StorageProp('isSystemDarkMode') @Watch('onThemeChange') private sysDark: boolean = false
  @StorageProp('currentThemeMode') @Watch('onThemeChange') private themeMode: string = '系统默认'

  // 深色模式弹窗 UI 颜色
  @State private sheetBg: string = AppColors.CARD_BG
  @State private titleColor: string = AppColors.GRAY_900
  @State private cancelColor: string = AppColors.GRAY_400
  @State private dotColor: string = AppColors.GRAY_300

  // 预计算预览数据（@Builder 不允许 const / 方法调用）
  @State private previewDark: boolean = false
  @State private previewShowItems: MissingItem[] = []
  @State private previewOverflow: number = 0
  // 导出画布高度随清单内容自适应，避免长清单被截断
  @State private canvasH: number = 1920

  private onThemeChange(): void {
    this.applyTheme()
  }

  private applyTheme(): void {
    this.sheetBg = ThemeManager.getCardBackgroundColor(this.themeMode)
    this.titleColor = ThemeManager.getTextColor(this.themeMode)
    this.cancelColor = ThemeManager.getColor(AppColors.GRAY_400, AppColors.DARK_GRAY_400, this.themeMode)
    this.dotColor = ThemeManager.getColor(AppColors.GRAY_300, AppColors.DARK_GRAY_300, this.themeMode)
  }

  // PX 单位模式：绘制坐标、字体、getPixelMap 全部以物理像素为单位，
  // 避免 font 的 px 与布局的 vp 混用导致文字过小、导出画布尺寸过大的问题。
  private drawCtx: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(new RenderingContextSettings(true), LengthMetricsUnit.PX)

  private isDark(): boolean {
    if (this.themeMode === '深色模式') return true
    if (this.themeMode === '浅色模式') return false
    return this.sysDark
  }

  private onVisibleChange(): void {
    if (this.visible) {
      this.applyTheme()
      this.selectedIdx = 0
      this.saveSuccess = false
      this.swiperKey++
      this.previewDark = this.isDark()
      this.previewShowItems = this.missingItems.slice(0, 4)
      this.previewOverflow = Math.max(0, this.missingItems.length - 4)
      this.canvasH = this.calcCanvasHeight(this.groupByCategory(this.missingItems))
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // 分类分组
  // ══════════════════════════════════════════════════════════════════════

  private groupByCategory(items: MissingItem[]): Map<ShoppingCategory, MissingItem[]> {
    const map = new Map<ShoppingCategory, MissingItem[]>()
    for (const cat of IngredientTypeMapper.CATEGORY_ORDER) {
      map.set(cat, [])
    }
    for (const item of items) {
      const list = map.get(item.category)
      if (list) {
        list.push(item)
      } else {
        map.get(ShoppingCategory.OTHER)!.push(item)
      }
    }
    return map
  }

  // ══════════════════════════════════════════════════════════════════════
  // Canvas 共享绘制
  // ══════════════════════════════════════════════════════════════════════

  /** 按内容计算画布高度：内容少时保持竖版，内容多时自动加长，避免截断 */
  private calcCanvasHeight(grouped: Map<ShoppingCategory, MissingItem[]>): number {
    let h = LIST_START_Y + 8
    for (const cat of IngredientTypeMapper.CATEGORY_ORDER) {
      const items = grouped.get(cat)
      if (items && items.length > 0) {
        h += CAT_HEADER_H + items.length * ITEM_H + CAT_BLOCK_PAD + CAT_GAP
      }
    }
    h += LIST_FOOT_RESERVE + FOOTER_H
    return Math.max(MIN_CANVAS_H, Math.min(MAX_CANVAS_H, h))
  }

  /** 列表可用区域的下边界（给页脚与溢出提示留白） */
  private listBottom(): number {
    return this.canvasH - FOOTER_H - LIST_FOOT_RESERVE
  }

  /** 绘制全部分类列表，返回未能展示的条目数 */
  private drawList(
    ctx: CanvasRenderingContext2D, grouped: Map<ShoppingCategory, MissingItem[]>,
    textC: string, subC: string, lineC: string, isDark: boolean
  ): number {
    const limit = this.listBottom()

    if (this.missingItems.length === 0) {
      ctx.font = '30px sans-serif'
      ctx.fillStyle = subC
      ctx.textAlign = 'center'
      ctx.textBaseline = 'middle'
      ctx.fillText('暂无需要采购的食材', CANVAS_W / 2, LIST_START_Y + 200)
      return 0
    }

    let y = LIST_START_Y
    let skipped = 0

    for (const cat of IngredientTypeMapper.CATEGORY_ORDER) {
      const items = grouped.get(cat)
      if (!items || items.length === 0) continue

      let shown = items.length
      if (y + CAT_HEADER_H + items.length * ITEM_H + CAT_BLOCK_PAD > limit) {
        shown = Math.floor((limit - y - CAT_HEADER_H - CAT_BLOCK_PAD) / ITEM_H)
        if (shown < 1) {
          skipped += items.length
          continue
        }
        shown = Math.min(shown, items.length)
      }

      const colors = IngredientTypeMapper.getCategoryColors(cat)
      const catTextC = pickColor(colors.text, colors.textDark, isDark)
      const catBg = pickColor(colors.bg, colors.bgDark, isDark)

      this.drawCategoryHeader(ctx, cat, items.length, y, catTextC, catBg, lineC, isDark, shown * ITEM_H)

      let rowY = y + CAT_HEADER_H
      for (let i = 0; i < shown; i++) {
        this.drawItemRow(ctx, items[i], rowY, textC, catTextC, catBg, lineC, isDark, i === shown - 1)
        rowY += ITEM_H
      }

      skipped += items.length - shown
      y = rowY + CAT_BLOCK_PAD + CAT_GAP
      if (y >= limit) break
    }
    return skipped
  }

  /** 分类卡片：圆角容器 + 分类色标题条 + 项数胶囊 */
  private drawCategoryHeader(
    ctx: CanvasRenderingContext2D, cat: ShoppingCategory, count: number,
    topY: number, catTextC: string, catBg: string, lineC: string,
    isDark: boolean, bodyH: number
  ): void {
    const blockH = CAT_HEADER_H + bodyH + CAT_BLOCK_PAD

    // 分类卡片容器
    ctx.fillStyle = isDark ? 'rgba(255,255,255,0.05)' : 'rgba(255,255,255,0.62)'
    ctx.beginPath()
    this.roundRect(ctx, PAD_X, topY, CONTENT_W, blockH, 22)
    ctx.fill()
    ctx.strokeStyle = lineC
    ctx.lineWidth = 1.5
    ctx.beginPath()
    this.roundRect(ctx, PAD_X, topY, CONTENT_W, blockH, 22)
    ctx.stroke()

    // 分类色标题条（卡片内嵌，四周留出呼吸空间）
    const chipX = PAD_X + 12
    const chipY = topY + 12
    const chipW = CONTENT_W - 24
    const chipH = 64
    ctx.fillStyle = catBg
    ctx.beginPath()
    this.roundRect(ctx, chipX, chipY, chipW, chipH, 16)
    ctx.fill()

    const cy = chipY + chipH / 2

    // 左侧强调条
    ctx.fillStyle = catTextC
    ctx.beginPath()
    this.roundRect(ctx, chipX + 18, cy - 13, 3, 26, 1.5)
    ctx.fill()

    ctx.textBaseline = 'middle'
    ctx.textAlign = 'start'

    // emoji 图标（固定起点，保证分类视觉一致）
    ctx.font = '32px sans-serif'
    ctx.fillStyle = catTextC
    ctx.fillText(IngredientTypeMapper.getCategoryEmoji(cat), chipX + 34, cy + 1)

    // 分类名
    ctx.font = 'bold 32px sans-serif'
    ctx.fillText(IngredientTypeMapper.getCategoryLabel(cat), chipX + 78, cy + 1)

    // 项数胶囊
    const txt = `${count} 项`
    ctx.font = '20px sans-serif'
    const pw = ctx.measureText(txt).width + 20
    const ph = 30
    const px = chipX + chipW - pw - 14
    const py = cy - ph / 2
    ctx.fillStyle = isDark ? 'rgba(255,255,255,0.12)' : 'rgba(255,255,255,0.75)'
    ctx.beginPath()
    this.roundRect(ctx, px, py, pw, ph, ph / 2)
    ctx.fill()
    ctx.fillStyle = catTextC
    ctx.textAlign = 'center'
    ctx.fillText(txt, px + pw / 2, cy + 1)
  }

  /** 单个食材行：分类色勾选圈 + emoji + 名称 + 用量胶囊 */
  private drawItemRow(
    ctx: CanvasRenderingContext2D, item: MissingItem, rowY: number,
    textC: string, catTextC: string, catBg: string, lineC: string,
    isDark: boolean, isLast: boolean
  ): void {
    const cy = rowY + ITEM_H / 2
    const inset = 24
    const ringX = PAD_X + inset + 14
    const ringR = 14
    const rightLimit = PAD_X + CONTENT_W - inset

    // 勾选圈：分类色描边 + 浅色底
    ctx.fillStyle = isDark ? 'rgba(255,255,255,0.10)' : 'rgba(255,255,255,0.9)'
    ctx.beginPath()
    ctx.arc(ringX, cy, ringR, 0, Math.PI * 2)
    ctx.fill()
    ctx.strokeStyle = catTextC
    ctx.lineWidth = 2.5
    ctx.beginPath()
    ctx.arc(ringX, cy, ringR, 0, Math.PI * 2)
    ctx.stroke()

    ctx.textBaseline = 'middle'

    // emoji：固定中心点，不同字符宽度不会造成名称错位
    const emojiCx = ringX + 44
    ctx.font = '38px sans-serif'
    ctx.fillStyle = textC
    ctx.textAlign = 'center'
    ctx.fillText(item.emoji, emojiCx, cy + 2)

    const nameX = emojiCx + 38

    // 用量：先测量再画胶囊，右侧对齐更整齐
    let pillW = 0
    let pillText = ''
    if (item.amount.length > 0) {
      ctx.font = '24px sans-serif'
      pillText = this.fitText(ctx, item.amount, CONTENT_W * 0.3)
      pillW = ctx.measureText(pillText).width + 20
    }

    // 名称
    const nameMaxW = rightLimit - nameX - (pillW > 0 ? pillW + 12 : 0)
    ctx.font = 'bold 34px sans-serif'
    ctx.fillStyle = textC
    ctx.textAlign = 'start'
    ctx.fillText(this.fitText(ctx, item.name, nameMaxW), nameX, cy + 1)

    // 用量胶囊
    if (pillW > 0) {
      const ph = 30
      const px = rightLimit - pillW
      const py = cy - ph / 2
      ctx.fillStyle = catBg
      ctx.beginPath()
      this.roundRect(ctx, px, py, pillW, ph, ph / 2)
      ctx.fill()
      ctx.fillStyle = catTextC
      ctx.font = '24px sans-serif'
      ctx.textAlign = 'center'
      ctx.fillText(pillText, px + pillW / 2, cy + 1)
    }

    // 行分隔线（从名称处起，避开勾选圈与 emoji）
    if (!isLast) {
      ctx.strokeStyle = lineC
      ctx.lineWidth = 1
      ctx.beginPath()
      ctx.moveTo(nameX, rowY + ITEM_H - 1)
      ctx.lineTo(rightLimit, rowY + ITEM_H - 1)
      ctx.stroke()
    }
  }

  /** 文本超宽时截断并加省略号（调用前需设置 ctx.font） */
  private fitText(ctx: CanvasRenderingContext2D, text: string, maxW: number): string {
    if (maxW <= 0 || ctx.measureText(text).width <= maxW) return text
    let t = text
    while (t.length > 1 && ctx.measureText(`${t}…`).width > maxW) {
      t = t.substring(0, t.length - 1)
    }
    return `${t}…`
  }

  /** 页头信息胶囊宽度 */
  private metaPillWidth(ctx: CanvasRenderingContext2D, text: string): number {
    ctx.font = '20px sans-serif'
    return ctx.measureText(text).width + 30
  }

  /** 页头信息胶囊：日期 · 项数 */
  private drawMetaPill(
    ctx: CanvasRenderingContext2D, leftX: number, topY: number,
    text: string, textC: string, isDark: boolean
  ): void {
    const pw = this.metaPillWidth(ctx, text)
    const ph = META_PILL_H

    ctx.fillStyle = isDark ? 'rgba(255,255,255,0.07)' : 'rgba(0,0,0,0.045)'
    ctx.beginPath()
    this.roundRect(ctx, leftX, topY, pw, ph, ph / 2)
    ctx.fill()

    ctx.strokeStyle = isDark ? 'rgba(255,255,255,0.09)' : 'rgba(0,0,0,0.05)'
    ctx.lineWidth = 1.5
    ctx.beginPath()
    this.roundRect(ctx, leftX, topY, pw, ph, ph / 2)
    ctx.stroke()

    ctx.fillStyle = textC
    ctx.font = '20px sans-serif'
    ctx.textAlign = 'center'
    ctx.textBaseline = 'middle'
    ctx.fillText(text, leftX + pw / 2, topY + ph / 2 + 1)
  }

  /** 超长清单未能完整展示时的提示 */
  private drawSkippedHint(ctx: CanvasRenderingContext2D, skipped: number, color: string): void {
    if (skipped <= 0) return
    ctx.font = '22px sans-serif'
    ctx.fillStyle = color
    ctx.textAlign = 'center'
    ctx.textBaseline = 'middle'
    ctx.globalAlpha = 0.8
    ctx.fillText(`另有 ${skipped} 项未展示，请在 App 内查看`, CANVAS_W / 2, this.canvasH - FOOTER_H - 40)
    ctx.globalAlpha = 1.0
  }

  /** 页脚：品牌 + 日期与总项数 */
  private drawFooter(
    ctx: CanvasRenderingContext2D, brandC: string, subC: string, lineC: string
  ): void {
    const top = this.canvasH - FOOTER_H

    ctx.strokeStyle = lineC
    ctx.lineWidth = 2
    ctx.beginPath()
    ctx.moveTo(PAD_X, top)
    ctx.lineTo(CANVAS_W - PAD_X, top)
    ctx.stroke()

    ctx.textBaseline = 'middle'
    ctx.textAlign = 'center'

    ctx.font = 'bold 36px sans-serif'
    ctx.fillStyle = brandC
    ctx.fillText('AUV您吃了么', CANVAS_W / 2, top + 86)

    ctx.font = '24px sans-serif'
    ctx.fillStyle = subC
    ctx.globalAlpha = 0.7
    ctx.fillText(`${this.dateStr()}  ·  共 ${this.missingItems.length} 项`, CANVAS_W / 2, top + 150)
    ctx.globalAlpha = 1.0
  }

  private dateStr(): string {
    const today = new Date()
    return `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`
  }

  /** 圆角矩形 */
  private roundRect(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number): void {
    ctx.moveTo(x + r, y)
    ctx.lineTo(x + w - r, y)
    ctx.arcTo(x + w, y, x + w, y + r, r)
    ctx.lineTo(x + w, y + h - r)
    ctx.arcTo(x + w, y + h, x + w - r, y + h, r)
    ctx.lineTo(x + r, y + h)
    ctx.arcTo(x, y + h, x, y + h - r, r)
    ctx.lineTo(x, y + r)
    ctx.arcTo(x, y, x + r, y, r)
    ctx.closePath()
  }

  // ══════════════════════════════════════════════════════════════════════
  // 风格一：唯美便签
  // ══════════════════════════════════════════════════════════════════════

  private drawStyleNote(): void {
    const dark = this.isDark()
    const bg     = pickColor('#FFFBF5', '#272320', dark)
    const titleC = pickColor('#D94F00', '#FF9A3C', dark)
    const textC  = pickColor('#3D2B1F', '#D9C5B0', dark)
    const accent = pickColor('#FF6B35', '#FF8C55', dark)
    const subC   = pickColor('#9B6A4A', '#B89070', dark)
    const lineC  = pickColor('#EDD9C8', '#3A2E28', dark)

    const ctx = this.drawCtx

    ctx.reset()
    ctx.fillStyle = bg
    ctx.fillRect(0, 0, CANVAS_W, this.canvasH)

    // 顶部粗色条
    ctx.fillStyle = accent
    ctx.fillRect(0, 0, CANVAS_W, 12)

    // 品牌名 — 右上角
    ctx.globalAlpha = 0.8
    ctx.font = 'bold 28px sans-serif'
    ctx.fillStyle = accent
    ctx.textAlign = 'end'
    ctx.textBaseline = 'middle'
    ctx.fillText('AUV您吃了么', CANVAS_W - PAD_X, BRAND_Y)
    ctx.globalAlpha = 1.0

    // 主标题
    ctx.font = 'bold 76px sans-serif'
    ctx.fillStyle = titleC
    ctx.textAlign = 'center'
    ctx.fillText('今日采购清单', CANVAS_W / 2, TITLE_Y)

    // 菜名副标题
    if (this.recipeName.length > 0) {
      ctx.font = '30px sans-serif'
      ctx.fillStyle = subC
      ctx.fillText(this.fitText(ctx, `为「${this.recipeName}」准备`, CONTENT_W), CANVAS_W / 2, SUB_Y)
    }

    // 日期 / 项数胶囊
    const meta = `${this.dateStr()}  ·  共 ${this.missingItems.length} 项`
    const pw = this.metaPillWidth(ctx, meta)
    this.drawMetaPill(ctx, (CANVAS_W - pw) / 2, META_Y, meta, subC, dark)

    // 双横线分隔
    ctx.strokeStyle = lineC
    ctx.lineWidth = 3
    ctx.beginPath(); ctx.moveTo(PAD_X, DIVIDER_Y); ctx.lineTo(CANVAS_W - PAD_X, DIVIDER_Y); ctx.stroke()
    ctx.lineWidth = 1
    ctx.beginPath(); ctx.moveTo(PAD_X + 24, DIVIDER_Y + 10); ctx.lineTo(CANVAS_W - PAD_X - 24, DIVIDER_Y + 10); ctx.stroke()

    // 分类清单
    const skipped = this.drawList(ctx, this.groupByCategory(this.missingItems), textC, subC, lineC, dark)
    this.drawSkippedHint(ctx, skipped, subC)
    this.drawFooter(ctx, accent, subC, lineC)

    // 底边粗色条
    ctx.fillStyle = accent
    ctx.fillRect(0, this.canvasH - 12, CANVAS_W, 12)
  }

  // ══════════════════════════════════════════════════════════════════════
  // 风格二：极简白卡
  // ══════════════════════════════════════════════════════════════════════

  private drawStyleCard(): void {
    const dark = this.isDark()
    const bg     = pickColor('#FFFFFF', '#181818', dark)
    const titleC = pickColor('#111111', '#F2F2F2', dark)
    const textC  = pickColor('#444444', '#AAAAAA', dark)
    const accent = pickColor('#FF4757', '#FF5A5A', dark)
    const subC   = pickColor('#9CA3AF', '#7A7A7A', dark)
    const lineC  = pickColor('#EEEEEE', '#2A2A2A', dark)
    const ctx = this.drawCtx
    const left = PAD_X

    ctx.reset()
    ctx.fillStyle = bg
    ctx.fillRect(0, 0, CANVAS_W, this.canvasH)

    // 左侧粗竖条
    ctx.fillStyle = accent
    ctx.fillRect(0, 0, 14, this.canvasH)

    // 品牌名
    ctx.font = 'bold 28px sans-serif'
    ctx.fillStyle = accent
    ctx.textAlign = 'start'
    ctx.textBaseline = 'middle'
    ctx.fillText('AUV您吃了么', left, BRAND_Y)

    // 主标题
    ctx.font = 'bold 74px sans-serif'
    ctx.fillStyle = titleC
    ctx.fillText('采购清单', left, TITLE_Y)

    // 标题下色块
    ctx.fillStyle = accent
    ctx.beginPath()
    this.roundRect(ctx, left, TITLE_Y + 48, 172, 7, 3.5)
    ctx.fill()

    // 菜名
    if (this.recipeName.length > 0) {
      ctx.font = '30px sans-serif'
      ctx.fillStyle = textC
      ctx.fillText(this.fitText(ctx, `为「${this.recipeName}」准备`, CONTENT_W), left, SUB_Y)
    }

    // 日期 / 项数胶囊
    const meta = `${this.dateStr()}  ·  共 ${this.missingItems.length} 项`
    this.drawMetaPill(ctx, left, META_Y, meta, subC, dark)

    // 分隔线
    ctx.strokeStyle = lineC
    ctx.lineWidth = 2
    ctx.beginPath()
    ctx.moveTo(left, DIVIDER_Y)
    ctx.lineTo(CANVAS_W - PAD_X, DIVIDER_Y)
    ctx.stroke()

    // 分类清单
    const skipped = this.drawList(ctx, this.groupByCategory(this.missingItems), textC, subC, lineC, dark)
    this.drawSkippedHint(ctx, skipped, subC)
    this.drawFooter(ctx, accent, subC, lineC)

    // 底边
    ctx.fillStyle = accent
    ctx.fillRect(0, this.canvasH - 12, CANVAS_W, 12)
  }

  // ══════════════════════════════════════════════════════════════════════
  // 风格三：暗黑柔光
  // ══════════════════════════════════════════════════════════════════════

  private drawStyleDark(): void {
    const dark = this.isDark()
    const bg     = pickColor('#F2E8D5', '#1C1812', dark)
    const titleC = pickColor('#7A3B10', '#E8C88A', dark)
    const textC  = pickColor('#4E3420', '#C8B090', dark)
    const accent = pickColor('#B5541C', '#D4793A', dark)
    const subC   = pickColor('#8C6040', '#A8845C', dark)
    const lineC  = pickColor('#D0BCA0', '#382C20', dark)
    const ctx = this.drawCtx

    ctx.reset()
    ctx.fillStyle = bg
    ctx.fillRect(0, 0, CANVAS_W, this.canvasH)

    // 纸张纹理
    ctx.fillStyle = pickColor('rgba(100,60,20,0.05)', 'rgba(255,220,150,0.03)', dark)
    for (let d = 0; d < 200; d++) {
      ctx.beginPath()
      ctx.arc((d * 197 + 31) % CANVAS_W, (d * 113 + 57) % this.canvasH, 2, 0, Math.PI * 2)
      ctx.fill()
    }

    // 顶部双条纹
    ctx.fillStyle = accent
    ctx.fillRect(0, 0, CANVAS_W, 12)
    ctx.fillStyle = pickColor('rgba(181,84,28,0.3)', 'rgba(212,121,58,0.3)', dark)
    ctx.fillRect(0, 12, CANVAS_W, 7)

    // 品牌名 — 居中
    ctx.globalAlpha = 0.85
    ctx.font = 'bold 28px sans-serif'
    ctx.fillStyle = accent
    ctx.textAlign = 'center'
    ctx.textBaseline = 'middle'
    ctx.fillText('AUV您吃了么', CANVAS_W / 2, BRAND_Y)
    ctx.globalAlpha = 1.0

    // 主标题
    ctx.font = 'bold 72px sans-serif'
    ctx.fillStyle = titleC
    ctx.fillText('✦ 采购清单 ✦', CANVAS_W / 2, TITLE_Y)

    // 装饰线
    ctx.strokeStyle = accent
    ctx.lineWidth = 3
    ctx.beginPath()
    ctx.moveTo(CANVAS_W / 2 - 220, TITLE_Y + 50)
    ctx.lineTo(CANVAS_W / 2 + 220, TITLE_Y + 50)
    ctx.stroke()

    // 菜名
    if (this.recipeName.length > 0) {
      ctx.font = '30px sans-serif'
      ctx.fillStyle = subC
      ctx.fillText(this.fitText(ctx, `为「${this.recipeName}」准备`, CONTENT_W), CANVAS_W / 2, SUB_Y)
    }

    // 日期 / 项数胶囊
    const meta = `${this.dateStr()}  ·  共 ${this.missingItems.length} 项`
    const pw = this.metaPillWidth(ctx, meta)
    this.drawMetaPill(ctx, (CANVAS_W - pw) / 2, META_Y, meta, subC, dark)

    // 双横线
    ctx.strokeStyle = lineC
    ctx.lineWidth = 3
    ctx.beginPath(); ctx.moveTo(PAD_X, DIVIDER_Y); ctx.lineTo(CANVAS_W - PAD_X, DIVIDER_Y); ctx.stroke()
    ctx.lineWidth = 1
    ctx.beginPath(); ctx.moveTo(PAD_X + 20, DIVIDER_Y + 10); ctx.lineTo(CANVAS_W - PAD_X - 20, DIVIDER_Y + 10); ctx.stroke()

    // 分类清单
    const skipped = this.drawList(ctx, this.groupByCategory(this.missingItems), textC, subC, lineC, dark)
    this.drawSkippedHint(ctx, skipped, subC)
    this.drawFooter(ctx, accent, subC, lineC)

    // 底边色条
    ctx.fillStyle = accent
    ctx.fillRect(0, this.canvasH - 12, CANVAS_W, 12)
  }

  // ══════════════════════════════════════════════════════════════════════
  // 保存到相册
  // ══════════════════════════════════════════════════════════════════════

  async saveToAlbum(): Promise<void> {
    if (this.saving) return
    this.saving = true
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
      if (!ctx) { this.showToast('无法获取应用上下文'); this.saving = false; return }

      this.drawCurrentStyle()

      const pm: image.PixelMap = this.drawCtx.getPixelMap(0, 0, CANVAS_W, this.canvasH)
      if (pm === null || pm === undefined) {
        this.showToast('Canvas 读取失败'); this.saving = false; return
      }

      const packer = image.createImagePacker()
      const packed: ArrayBuffer = await packer.packing(pm, { format: 'image/jpeg', quality: 98 } as image.PackingOption)
      packer.release()
      pm.release()

      const tempPath: string = ctx.tempDir + '/shopping_' + Date.now() + '.jpg'
      const tmpFile = await fileIo.open(tempPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE)
      await fileIo.write(tmpFile.fd, packed)
      await fileIo.close(tmpFile.fd)

      const helper = photoAccessHelper.getPhotoAccessHelper(ctx)
      const uri: string = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'jpg')
      const destFile = await fileIo.open(uri, fileIo.OpenMode.READ_WRITE)
      await fileIo.write(destFile.fd, packed)
      await fileIo.close(destFile.fd)

      try { fileIo.unlinkSync(tempPath) } catch (_) { /* ignore */ }

      this.saveSuccess = true
      setTimeout(() => { this.saveSuccess = false }, 1200)
      this.showToast('已保存到系统相册')
      setTimeout(() => { if (this.onClose) this.onClose() }, 1500)
    } catch (e) {
      console.error('[ExportShopping] save error:', JSON.stringify(e))
      this.showToast('保存失败，请重试')
    } finally { this.saving = false }
  }

  private drawCurrentStyle(): void {
    switch (this.selectedIdx) {
      case 0: this.drawStyleNote(); break
      case 1: this.drawStyleCard(); break
      case 2: this.drawStyleDark(); break
      default: this.drawStyleNote(); break
    }
  }

  private showToast(msg: string): void {
    this.toastMsg = msg
    this.toastVisible = true
    setTimeout(() => { this.toastVisible = false }, 2600)
  }

  // ══════════════════════════════════════════════════════════════════════
  // 预览卡片
  // ══════════════════════════════════════════════════════════════════════

  @Builder
  PreviewCard(style: StyleDef) {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%').height('100%')
        .backgroundColor(this.previewDark ? style.previewBgDark : style.previewBg)
        .borderRadius(14)

      // 左侧色条（风格二）
      if (style.key === 'card') {
        Column()
          .width(5).height('100%')
          .backgroundColor(this.previewDark ? style.previewAccentDark : style.previewAccent)
          .borderRadius({ topLeft: 14, bottomLeft: 14 })
      }

      // 顶部色条（风格一/三）
      if (style.key !== 'card') {
        Column()
          .width('100%').height(5)
          .backgroundColor(this.previewDark ? style.previewAccentDark : style.previewAccent)
          .borderRadius({ topLeft: 14, topRight: 14 })
      }

      Column({ space: 10 }) {
        // 品牌名
        Text('AUV您吃了么')
          .fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor(this.previewDark ? style.previewAccentDark : style.previewAccent)
          .opacity(0.85)
          .alignSelf(style.key === 'card' ? ItemAlign.Start : ItemAlign.Center)
          .padding({ left: style.key === 'card' ? 10 : 0 })

        // 标题
        Text(style.key === 'dark' ? '✦ 采购清单 ✦' : '采购清单')
          .fontSize(32).fontWeight(FontWeight.Bold)
          .fontColor(this.previewDark
            ? (style.key === 'note' ? '#FF9A3C' : style.key === 'card' ? '#F2F2F2' : '#E8C88A')
            : (style.key === 'note' ? '#D94F00' : style.key === 'card' ? '#111111' : '#7A3B10'))
          .alignSelf(style.key === 'card' ? ItemAlign.Start : ItemAlign.Center)
          .padding({ left: style.key === 'card' ? 10 : 0 })

        // 菜名
        if (this.recipeName.length > 0) {
          Text(`为「${this.recipeName}」准备`)
            .fontSize(18)
            .fontColor(this.previewDark ? '#999' : '#666')
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .alignSelf(style.key === 'card' ? ItemAlign.Start : ItemAlign.Center)
            .padding({ left: style.key === 'card' ? 10 : 0 })
        }

        // 清单项预览
        Column({ space: 6 }) {
          ForEach(this.previewShowItems, (item: MissingItem) => {
            Row({ space: 8 }) {
              Circle({ width: 14, height: 14 })
                .fill(Color.Transparent)
                .stroke(this.previewDark ? '#4D4D4D' : '#D1D5DB')
              Text(item.emoji).fontSize(20)
              Text(item.name)
                .fontSize(19).fontWeight(FontWeight.Medium)
                .fontColor(this.previewDark ? '#AAA' : '#444')
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
              if (item.amount.length > 0) {
                Text(item.amount)
                  .fontSize(16)
                  .fontColor(this.previewDark ? '#4D4D4D' : '#9CA3AF')
              }
            }
            .alignSelf(style.key === 'card' ? ItemAlign.Start : ItemAlign.Center)
            .padding({ left: style.key === 'card' ? 10 : 0 })
          }, (item: MissingItem) => `pv-${item.name}`)

          if (this.previewOverflow > 0) {
            Text(`+ ${this.previewOverflow} 项…`)
              .fontSize(15).fontColor('#AAAAAA')
              .alignSelf(style.key === 'card' ? ItemAlign.Start : ItemAlign.Center)
              .padding({ left: style.key === 'card' ? 10 : 0 })
          }
        }
      }
      .width('100%').height('100%')
      .padding({ top: style.key === 'card' ? 12 : 15, left: style.key === 'card' ? 0 : 14, right: 14, bottom: 12 })
      .justifyContent(FlexAlign.Center)
      .alignItems(style.key === 'card' ? HorizontalAlign.Start : HorizontalAlign.Center)
    }
    .width('100%').height('100%')
    .clip(true)
    .borderRadius(14)
  }

  // ══════════════════════════════════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════════════════════════════════

  build() {
    if (!this.visible) {
      Column().width(0).height(0)
    } else {
      Stack({ alignContent: Alignment.Bottom }) {
        // 遮罩
        Column()
          .width('100%').height('100%')
          .backgroundColor('rgba(0,0,0,0.45)')
          .onClick(() => { if (this.onClose) this.onClose() })

        // Canvas（移出屏幕但保持挂载；尺寸用 px，与 PX 单位模式的绘制坐标一致）
        Canvas(this.drawCtx)
          .width(`${CANVAS_W}px`)
          .height(`${this.canvasH}px`)
          .key(`canvas_${this.swiperKey}`)
          .position({ x: -CANVAS_W, y: 0 })
          .onReady(() => { this.drawCurrentStyle() })

        // 底部弹窗
        Column({ space: 0 }) {
          // 拖拽条
          Column()
            .width(44).height(5)
            .backgroundColor('#99B6C1D4')
            .borderRadius(999)
            .margin({ top: 12, bottom: 12 })

          Text('选择模板样式')
            .fontSize(18).fontWeight(FontWeight.Bold)
            .fontColor(this.titleColor)
            .margin({ bottom: 14 })

          // ── Swiper 样式选择 ──
          Swiper() {
            ForEach(STYLES, (style: StyleDef) => {
              Column() {
                this.PreviewCard(style)
              }
              .width('100%').height('100%')
              .padding({ left: 6, right: 6 })
            }, (s: StyleDef) => s.key)
          }
          .autoPlay(false)
          .loop(false)
          .disableSwipe(false)
          .indicator(
            Indicator.dot()
              .color(this.dotColor)
              .selectedColor(AppColors.BRAND_COLOR)
              .itemWidth(8).itemHeight(8)
              .selectedItemWidth(22).selectedItemHeight(8)
          )
          .onChange((index: number) => {
            this.selectedIdx = index
            this.swiperKey++
            this.getUIContext().animateTo({ duration: 200, curve: Curve.EaseInOut }, () => {})
          })
          .width('100%')
          .height(340)
          .margin({ left: 20, right: 20, bottom: 14 })

          // 当前样式标签
          Text(STYLES[this.selectedIdx]?.label ?? '')
            .fontSize(16).fontWeight(FontWeight.Medium)
            .fontColor(AppColors.BRAND_COLOR)
            .margin({ bottom: 16 })

          // ── SaveButton ──
          SaveButton()
            .width('88%').height(56)
            .borderRadius(28)
            .fontSize(18).fontWeight(FontWeight.Bold)
            .onClick(async (_event: ClickEvent, result: SaveButtonOnClickResult) => {
              if (result === SaveButtonOnClickResult.SUCCESS) {
                void this.saveToAlbum()
              } else {
                this.showToast('保存已取消')
              }
            })

          // 取消
          Text('取消')
            .fontSize(16).fontColor(this.cancelColor)
            .width('100%').textAlign(TextAlign.Center)
            .padding({ top: 16, bottom: 16 })
            .onClick(() => { if (this.onClose) this.onClose() })
        }
        .width('100%')
        .backgroundColor(this.sheetBg)
        .backdropBlur(22)
        .borderRadius({ topLeft: 24, topRight: 24 })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])

        // 成功扫光动画
        if (this.saveSuccess) {
          Column()
            .width('100%').height(4)
            .position({ x: 0, y: 0 })
            .linearGradient({
              direction: GradientDirection.Right,
              colors: [['#00000000', 0], ['#40FFFFFF', 0.3], ['#80FFFFFF', 0.5], ['#40FFFFFF', 0.7], ['#00000000', 1]]
            })
            .animation({ duration: 800, curve: Curve.EaseInOut, iterations: 2 })
        }

        // Toast
        if (this.toastVisible) {
          Row() {
            Text(this.toastMsg)
              .fontSize(14).fontColor(Color.White)
              .padding({ left: 20, right: 20, top: 10, bottom: 10 })
          }
          .backgroundColor('#DD333333')
          .borderRadius(20).backdropBlur(12)
          .position({ x: '50%', y: '35%' })
          .translate({ x: '-50%', y: '-50%' })
        }
      }
      .width('100%').height('100%')
    }
  }
}
