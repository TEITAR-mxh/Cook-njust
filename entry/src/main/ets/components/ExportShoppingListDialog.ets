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
import { AppColors } from '../constants/AppColors'
import type { MissingItem } from '../service/ShoppingListService'
import { ShoppingCategory, IngredientTypeMapper } from '../utils/IngredientTypeMapper'

// ── Canvas 尺寸常量（9:16，大字清晰版）────────────────────────────────
const CANVAS_W: number = 1080
const CANVAS_H: number = 1920
const PAD_X: number = 68
const ITEM_H: number = 180                // 食材行高（适配大字体）
const CAT_HEADER_H: number = 100          // 分类标题高度
const HEADER_Y: number = 200              // 主标题基线（下调以适配大标题）
const LIST_START_Y: number = 500          // 清单起始 Y
const FOOTER_START_Y: number = 1680       // 底部区域起始 Y

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
  { key: 'card', label: '极简白卡', previewBg: '#FFFFFF', previewBgDark: '#1A1A1A', previewAccent: '#E8333A', previewAccentDark: '#FF5A5A' },
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
  @StorageProp('isSystemDarkMode') private sysDark: boolean = false
  @StorageProp('currentThemeMode') private themeMode: string = '系统默认'

  // 预计算预览数据（@Builder 不允许 const / 方法调用）
  @State private previewDark: boolean = false
  @State private previewShowItems: MissingItem[] = []
  @State private previewOverflow: number = 0

  private drawCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D()

  private isDark(): boolean {
    if (this.themeMode === '深色模式') return true
    if (this.themeMode === '浅色模式') return false
    return this.sysDark
  }

  private onVisibleChange(): void {
    if (this.visible) {
      this.selectedIdx = 0
      this.saveSuccess = false
      this.swiperKey++
      this.previewDark = this.isDark()
      this.previewShowItems = this.missingItems.slice(0, 4)
      this.previewOverflow = Math.max(0, this.missingItems.length - 4)
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

  /** 绘制分类区块 */
  private drawCategoryBlock(
    ctx: CanvasRenderingContext2D, cat: ShoppingCategory, items: MissingItem[],
    startY: number, textC: string, subC: string, lineC: string, accent: string,
    isDark: boolean, inCard: boolean
  ): number {
    if (items.length === 0) return startY

    const colors = IngredientTypeMapper.getCategoryColors(cat)
    const catTextC = pickColor(colors.text, colors.textDark, isDark)
    const catBg = pickColor(colors.bg, colors.bgDark, isDark)
    const x0 = inCard ? PAD_X + 24 : PAD_X
    const w = inCard ? CANVAS_W - PAD_X * 2 - 48 : CANVAS_W - PAD_X * 2

    // 分类标题背景
    ctx.fillStyle = catBg
    ctx.fillRect(x0, startY, w, CAT_HEADER_H)

    // 左侧小色条
    ctx.fillStyle = catTextC
    ctx.beginPath()
    this.roundRect(ctx, x0 - (inCard ? 0 : 0), startY + 18, 8, CAT_HEADER_H - 36, 4)
    ctx.fill()

    // 分类名称
    ctx.font = '64px sans-serif'
    ctx.fillStyle = catTextC
    ctx.textAlign = 'start'
    ctx.fillText(`${IngredientTypeMapper.getCategoryEmoji(cat)} ${IngredientTypeMapper.getCategoryLabel(cat)}`,
      x0 + 28, startY + 64)

    // 项数
    ctx.font = '52px sans-serif'
    ctx.fillStyle = pickColor('#9CA3AF', '#8D8D8D', isDark)
    ctx.textAlign = 'end'
    ctx.fillText(`${items.length}项`, CANVAS_W - PAD_X - (inCard ? 16 : 0), startY + 64)

    // 物品
    let y = startY + CAT_HEADER_H
    for (let i = 0; i < items.length; i++) {
      if (y + ITEM_H > FOOTER_START_Y) break
      this.drawItemRow(ctx, items[i], y, textC, subC, catTextC, lineC, x0, w)
      y += ITEM_H
    }

    // 分类间分隔
    return y + (inCard ? 24 : 12)
  }

  /** 绘制单个物品行 */
  private drawItemRow(
    ctx: CanvasRenderingContext2D, item: MissingItem,
    rowY: number, textC: string, subC: string, checkC: string, lineC: string,
    x0: number, rowW: number
  ): void {
    const cx = x0 + 44
    const cy = rowY + ITEM_H / 2
    const checkR = 28

    // 勾选圆圈
    ctx.strokeStyle = checkC
    ctx.lineWidth = 4
    ctx.beginPath()
    ctx.arc(cx, cy, checkR, 0, Math.PI * 2)
    ctx.stroke()

    // Emoji
    ctx.font = '90px sans-serif'
    ctx.fillStyle = textC
    ctx.textAlign = 'start'
    ctx.fillText(item.emoji, cx + 56, cy + 28)

    // 食材名
    ctx.font = 'bold 76px sans-serif'
    ctx.fillStyle = textC
    ctx.fillText(item.name, cx + 158, cy + 26)

    // 用量
    if (item.amount.length > 0) {
      ctx.font = '56px sans-serif'
      ctx.fillStyle = subC
      ctx.textAlign = 'end'
      ctx.fillText(item.amount, CANVAS_W - PAD_X, cy + 22)
    }

    // 行分隔线
    ctx.strokeStyle = lineC
    ctx.lineWidth = 1.5
    ctx.beginPath()
    ctx.moveTo(x0 + 20, rowY + ITEM_H - 2)
    ctx.lineTo(x0 + rowW, rowY + ITEM_H - 2)
    ctx.stroke()
  }

  /** 页脚：App 品牌名 + 日期 */
  private drawFooter(ctx: CanvasRenderingContext2D, textC: string, lineC: string, accent: string, brandC: string): void {
    const today = new Date()
    const dateStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`

    // 分隔线
    ctx.strokeStyle = lineC
    ctx.lineWidth = 3
    ctx.beginPath()
    ctx.moveTo(PAD_X, FOOTER_START_Y)
    ctx.lineTo(CANVAS_W - PAD_X, FOOTER_START_Y)
    ctx.stroke()

    // 品牌名 — 大字醒目
    ctx.font = 'bold 68px sans-serif'
    ctx.fillStyle = brandC
    ctx.textAlign = 'center'
    ctx.fillText('AUV 您吃了么', CANVAS_W / 2, FOOTER_START_Y + 80)

    // 日期 + 数量
    ctx.font = '50px sans-serif'
    ctx.fillStyle = textC
    ctx.globalAlpha = 0.5
    ctx.fillText(`${dateStr}  ·  共 ${this.missingItems.length} 项`, CANVAS_W / 2, FOOTER_START_Y + 154)
    ctx.globalAlpha = 1.0
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
    const appNameY = 100

    ctx.reset()
    ctx.fillStyle = bg
    ctx.fillRect(0, 0, CANVAS_W, CANVAS_H)

    // 顶部粗色条
    ctx.fillStyle = accent
    ctx.fillRect(0, 0, CANVAS_W, 14)

    // 品牌名 — 右上角突出
    ctx.font = 'bold 58px sans-serif'
    ctx.fillStyle = accent
    ctx.globalAlpha = 0.85
    ctx.textAlign = 'end'
    ctx.fillText('AUV 您吃了么', CANVAS_W - PAD_X, appNameY)
    ctx.globalAlpha = 1.0

    // 主标题
    ctx.font = 'bold 150px sans-serif'
    ctx.fillStyle = titleC
    ctx.textAlign = 'center'
    ctx.fillText('今日采购清单', CANVAS_W / 2, HEADER_Y)

    // 菜名副标题
    if (this.recipeName.length > 0) {
      ctx.font = '64px sans-serif'
      ctx.fillStyle = subC
      ctx.fillText(`为「${this.recipeName}」准备`, CANVAS_W / 2, HEADER_Y + 90)
    }

    // 双横线分隔
    const sepY = LIST_START_Y - 48
    ctx.strokeStyle = lineC
    ctx.lineWidth = 3
    ctx.beginPath(); ctx.moveTo(PAD_X, sepY); ctx.lineTo(CANVAS_W - PAD_X, sepY); ctx.stroke()
    ctx.lineWidth = 1
    ctx.beginPath(); ctx.moveTo(PAD_X + 20, sepY + 12); ctx.lineTo(CANVAS_W - PAD_X - 20, sepY + 12); ctx.stroke()

    // 分类区块
    const grouped = this.groupByCategory(this.missingItems)
    let y = LIST_START_Y
    for (const cat of IngredientTypeMapper.CATEGORY_ORDER) {
      const items = grouped.get(cat)
      if (items && items.length > 0) {
        y = this.drawCategoryBlock(ctx, cat, items, y, textC, subC, lineC, accent, dark, false)
        if (y >= FOOTER_START_Y) break
      }
    }

    this.drawFooter(ctx, subC, lineC, accent, accent)

    // 底边粗色条
    ctx.fillStyle = accent
    ctx.fillRect(0, CANVAS_H - 14, CANVAS_W, 14)
  }

  // ══════════════════════════════════════════════════════════════════════
  // 风格二：极简白卡
  // ══════════════════════════════════════════════════════════════════════

  private drawStyleCard(): void {
    const dark = this.isDark()
    const bg     = pickColor('#FFFFFF', '#181818', dark)
    const titleC = pickColor('#111111', '#F2F2F2', dark)
    const textC  = pickColor('#444444', '#AAAAAA', dark)
    const accent = pickColor('#E8333A', '#FF5A5A', dark)
    const lineC  = pickColor('#EEEEEE', '#2A2A2A', dark)
    const ctx = this.drawCtx

    ctx.reset()
    ctx.fillStyle = bg
    ctx.fillRect(0, 0, CANVAS_W, CANVAS_H)

    // 左侧粗竖条
    ctx.fillStyle = accent
    ctx.fillRect(0, 0, 16, CANVAS_H)

    // 品牌名 — 左上角突出
    ctx.font = 'bold 58px sans-serif'
    ctx.fillStyle = accent
    ctx.textAlign = 'start'
    ctx.fillText('AUV 您吃了么', PAD_X + 16, 100)

    // 主标题
    ctx.font = 'bold 150px sans-serif'
    ctx.fillStyle = titleC
    ctx.textAlign = 'start'
    ctx.fillText('采购清单', PAD_X + 16, HEADER_Y)

    // 标题下粗线
    ctx.fillStyle = accent
    ctx.fillRect(PAD_X + 16, HEADER_Y + 20, 240, 10)

    // 菜名
    if (this.recipeName.length > 0) {
      ctx.font = '58px sans-serif'
      ctx.fillStyle = textC
      ctx.textAlign = 'end'
      ctx.fillText(`为「${this.recipeName}」`, CANVAS_W - PAD_X, HEADER_Y - 20)
    }

    // 分隔线
    ctx.strokeStyle = lineC
    ctx.lineWidth = 2
    ctx.beginPath()
    ctx.moveTo(PAD_X + 16, LIST_START_Y - 32)
    ctx.lineTo(CANVAS_W - PAD_X, LIST_START_Y - 32)
    ctx.stroke()

    // 分类区块
    const grouped = this.groupByCategory(this.missingItems)
    let y = LIST_START_Y
    for (const cat of IngredientTypeMapper.CATEGORY_ORDER) {
      const items = grouped.get(cat)
      if (items && items.length > 0) {
        y = this.drawCategoryBlock(ctx, cat, items, y, textC, textC, lineC, accent, dark, false)
        if (y >= FOOTER_START_Y) break
      }
    }

    this.drawFooter(ctx, textC, lineC, accent, accent)

    // 底边
    ctx.fillStyle = accent
    ctx.fillRect(0, CANVAS_H - 14, CANVAS_W, 14)
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
    ctx.fillRect(0, 0, CANVAS_W, CANVAS_H)

    // 纸张纹理
    ctx.fillStyle = pickColor('rgba(100,60,20,0.05)', 'rgba(255,220,150,0.03)', dark)
    for (let d = 0; d < 150; d++) {
      ctx.beginPath()
      ctx.arc((d * 197 + 31) % CANVAS_W, (d * 113 + 57) % CANVAS_H, 2, 0, Math.PI * 2)
      ctx.fill()
    }

    // 顶部双条纹
    ctx.fillStyle = accent
    ctx.fillRect(0, 0, CANVAS_W, 14)
    ctx.fillStyle = pickColor('rgba(181,84,28,0.3)', 'rgba(212,121,58,0.3)', dark)
    ctx.fillRect(0, 14, CANVAS_W, 8)

    // 品牌名 — 居中突出
    ctx.font = 'bold 58px sans-serif'
    ctx.fillStyle = accent
    ctx.globalAlpha = 0.85
    ctx.textAlign = 'center'
    ctx.fillText('AUV 您吃了么', CANVAS_W / 2, 100)
    ctx.globalAlpha = 1.0

    // 主标题
    ctx.font = 'bold 140px sans-serif'
    ctx.fillStyle = titleC
    ctx.textAlign = 'center'
    ctx.fillText('✦ 采购清单 ✦', CANVAS_W / 2, HEADER_Y)

    // 装饰线
    ctx.strokeStyle = accent
    ctx.lineWidth = 5
    ctx.beginPath()
    ctx.moveTo(CANVAS_W / 2 - 360, HEADER_Y + 24)
    ctx.lineTo(CANVAS_W / 2 + 360, HEADER_Y + 24)
    ctx.stroke()

    // 菜名
    if (this.recipeName.length > 0) {
      ctx.font = '62px sans-serif'
      ctx.fillStyle = subC
      ctx.fillText(`为「${this.recipeName}」准备`, CANVAS_W / 2, HEADER_Y + 104)
    }

    // 双横线
    const sepY = LIST_START_Y - 48
    ctx.strokeStyle = lineC
    ctx.lineWidth = 3
    ctx.beginPath(); ctx.moveTo(PAD_X, sepY); ctx.lineTo(CANVAS_W - PAD_X, sepY); ctx.stroke()
    ctx.lineWidth = 1
    ctx.beginPath(); ctx.moveTo(PAD_X + 16, sepY + 12); ctx.lineTo(CANVAS_W - PAD_X - 16, sepY + 12); ctx.stroke()

    // 分类区块
    const grouped = this.groupByCategory(this.missingItems)
    let y = LIST_START_Y
    for (const cat of IngredientTypeMapper.CATEGORY_ORDER) {
      const items = grouped.get(cat)
      if (items && items.length > 0) {
        y = this.drawCategoryBlock(ctx, cat, items, y, textC, subC, lineC, accent, dark, false)
        if (y >= FOOTER_START_Y) break
      }
    }

    this.drawFooter(ctx, subC, lineC, accent, accent)

    // 底边色条
    ctx.fillStyle = accent
    ctx.fillRect(0, CANVAS_H - 14, CANVAS_W, 14)
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

      const pm: image.PixelMap = this.drawCtx.getPixelMap(0, 0, CANVAS_W, CANVAS_H)
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
        Text('AUV 您吃了么')
          .fontSize(14).fontWeight(FontWeight.Medium)
          .fontColor(this.previewDark ? style.previewAccentDark : style.previewAccent)
          .opacity(0.85)
          .alignSelf(style.key === 'card' ? ItemAlign.Start : ItemAlign.Center)
          .padding({ left: style.key === 'card' ? 10 : 0 })

        // 标题
        Text(style.key === 'dark' ? '✦ 采购清单 ✦' : '采购清单')
          .fontSize(28).fontWeight(FontWeight.Bold)
          .fontColor(this.previewDark
            ? (style.key === 'note' ? '#FF9A3C' : style.key === 'card' ? '#F2F2F2' : '#E8C88A')
            : (style.key === 'note' ? '#D94F00' : style.key === 'card' ? '#111111' : '#7A3B10'))
          .alignSelf(style.key === 'card' ? ItemAlign.Start : ItemAlign.Center)
          .padding({ left: style.key === 'card' ? 10 : 0 })

        // 菜名
        if (this.recipeName.length > 0) {
          Text(`为「${this.recipeName}」准备`)
            .fontSize(16)
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
              Text(item.emoji).fontSize(18)
              Text(item.name)
                .fontSize(16).fontWeight(FontWeight.Medium)
                .fontColor(this.previewDark ? '#AAA' : '#444')
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
              if (item.amount.length > 0) {
                Text(item.amount)
                  .fontSize(14)
                  .fontColor(this.previewDark ? '#4D4D4D' : '#9CA3AF')
              }
            }
            .alignSelf(style.key === 'card' ? ItemAlign.Start : ItemAlign.Center)
            .padding({ left: style.key === 'card' ? 10 : 0 })
          }, (item: MissingItem) => `pv-${item.name}`)

          if (this.previewOverflow > 0) {
            Text(`+ ${this.previewOverflow} 项…`)
              .fontSize(14).fontColor('#AAAAAA')
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

        // Canvas（移出屏幕但保持挂载）
        Canvas(this.drawCtx)
          .width(CANVAS_W)
          .height(CANVAS_H)
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
            .fontColor('#1F2937')
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
              .color('#CCCCCC')
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
          .height(320)
          .margin({ left: 16, right: 16, bottom: 14 })

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
            .fontSize(16).fontColor('#9CA3AF')
            .width('100%').textAlign(TextAlign.Center)
            .padding({ top: 16, bottom: 16 })
            .onClick(() => { if (this.onClose) this.onClose() })
        }
        .width('100%')
        .backgroundColor('#F8FAFF')
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
