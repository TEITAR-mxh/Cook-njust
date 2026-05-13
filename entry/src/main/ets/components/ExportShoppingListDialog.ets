/**
 * 采购清单图片导出弹窗（重构版）
 * - Swiper 实现卡片式样式滑动切换
 * - SaveButton 安全控件合规保存到相册
 * - Canvas 绘制 3 种视觉模板（唯美便签 / 极简白卡 / 暗黑柔光）
 */
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { image } from '@kit.ImageKit'
import { fileIo } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'
import { AppColors } from '../constants/AppColors'
import { ShoppingListService } from '../service/ShoppingListService'

// ── Canvas 尺寸常量（9:16，超大字清晰版）────────────────────────────────
const CANVAS_W: number = 1080
const CANVAS_H: number = 1920
const ROW_H: number = 170        // 大行高，容纳 80px 字体
const PAD_X: number = 68         // 内边距
const APP_NAME_Y: number = 88    // App 名称基线
const HEADER_Y: number = 240     // 主标题基线
const LIST_START_Y: number = 430 // 清单起始 Y
const FOOTER_START_Y: number = 1710 // 底部区域起始 Y

// ── 样式模板定义 ──────────────────────────────────────────────────────────

interface StyleDef {
  key: string
  label: string
  /** 预览色块快速辨识 */
  previewBg: string
  previewBgDark: string
  previewAccent: string
  previewAccentDark: string
}

const STYLES: StyleDef[] = [
  { key: 'note', label: '唯美便签', previewBg: '#FEFEFE', previewBgDark: '#2C2C2C', previewAccent: '#F5A623', previewAccentDark: '#FFB347' },
  { key: 'card', label: '极简白卡', previewBg: '#FFFFFF', previewBgDark: '#1A1A1A', previewAccent: '#1A1A1A', previewAccentDark: '#F0F0F0' },
  { key: 'dark', label: '暗黑柔光', previewBg: '#F5F0E0', previewBgDark: '#1E1E1E', previewAccent: '#8B4513', previewAccentDark: '#D4A574' }
]

// ── 颜色辅助：根据浅色/深色返回对应色值 ──────────────────────────────────

function pickColor(light: string, dark: string, isDark: boolean): string {
  return isDark ? dark : light
}

@Component
export struct ExportShoppingListDialog {
  @Prop missingItems: string[] = []
  @Prop recipeName: string = ''
  @Prop @Watch('onVisibleChange') visible: boolean = false
  onClose?: () => void

  @State private selectedIdx: number = 0
  @State private saving: boolean = false
  @State private toastMsg: string = ''
  @State private toastVisible: boolean = false
  @State private saveSuccess: boolean = false // 成功动画标志
  @State private swiperKey: number = 0
  @StorageProp('isSystemDarkMode') private sysDark: boolean = false
  @StorageProp('currentThemeMode') private themeMode: string = '系统默认'

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
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // Canvas 绘制 — 3 种样式
  // ══════════════════════════════════════════════════════════════════════

  // ── 样式一：唯美便签 ─────────────────────────────────────────────────────
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
    ctx.fillRect(0, 0, CANVAS_W, CANVAS_H)

    // 顶部粗色条
    ctx.fillStyle = accent
    ctx.fillRect(0, 0, CANVAS_W, 18)

    // App 名称 — 右上角
    ctx.font = '46px sans-serif'
    ctx.fillStyle = accent
    ctx.globalAlpha = 0.75
    ctx.textAlign = 'end'
    ctx.fillText('AUV 您吃了么', CANVAS_W - PAD_X, APP_NAME_Y)
    ctx.globalAlpha = 1.0

    // 主标题
    ctx.font = 'bold 130px sans-serif'
    ctx.fillStyle = titleC
    ctx.textAlign = 'center'
    ctx.fillText('今日采购清单', CANVAS_W / 2, HEADER_Y)

    // 菜名副标题
    if (this.recipeName.length > 0) {
      ctx.font = '56px sans-serif'
      ctx.fillStyle = subC
      ctx.fillText(`为「${this.recipeName}」准备`, CANVAS_W / 2, HEADER_Y + 84)
    }

    // 双横线分隔
    ctx.strokeStyle = lineC
    ctx.lineWidth = 3
    ctx.beginPath()
    ctx.moveTo(PAD_X, LIST_START_Y - 36)
    ctx.lineTo(CANVAS_W - PAD_X, LIST_START_Y - 36)
    ctx.stroke()
    ctx.lineWidth = 1
    ctx.beginPath()
    ctx.moveTo(PAD_X + 20, LIST_START_Y - 26)
    ctx.lineTo(CANVAS_W - PAD_X - 20, LIST_START_Y - 26)
    ctx.stroke()

    this.drawIngredientList(ctx, textC, accent, lineC, true)
    this.drawFooter(ctx, subC, lineC, accent)
  }

  // ── 样式二：极简白卡 ─────────────────────────────────────────────────────
  private drawStyleCard(): void {
    const dark = this.isDark()
    const bg     = pickColor('#FFFFFF', '#181818', dark)
    const titleC = pickColor('#111111', '#F2F2F2', dark)
    const textC  = pickColor('#444444', '#AAAAAA', dark)
    const accent = pickColor('#E8333A', '#FF5A5A', dark)
    const lineC  = pickColor('#EEEEEE', '#2A2A2A', dark)
    const tagC   = pickColor('#F5F5F5', '#242424', dark)
    const ctx = this.drawCtx

    ctx.reset()
    ctx.fillStyle = bg
    ctx.fillRect(0, 0, CANVAS_W, CANVAS_H)

    // 左侧粗竖条装饰
    ctx.fillStyle = accent
    ctx.fillRect(0, 0, 16, CANVAS_H)

    // App 名称 — 左对齐小字，紧贴顶部
    ctx.font = '44px sans-serif'
    ctx.fillStyle = accent
    ctx.textAlign = 'start'
    ctx.fillText('AUV 您吃了么', PAD_X + 16, APP_NAME_Y)

    // 主标题
    ctx.font = 'bold 130px sans-serif'
    ctx.fillStyle = titleC
    ctx.fillText('采购清单', PAD_X + 16, HEADER_Y)

    // 标题下红色粗线
    ctx.fillStyle = accent
    ctx.fillRect(PAD_X + 16, HEADER_Y + 18, 200, 8)

    // 菜名右对齐
    if (this.recipeName.length > 0) {
      ctx.font = '50px sans-serif'
      ctx.fillStyle = textC
      ctx.textAlign = 'end'
      ctx.fillText(`为「${this.recipeName}」`, CANVAS_W - PAD_X, HEADER_Y)
    }

    // 分隔线
    ctx.strokeStyle = lineC
    ctx.lineWidth = 2
    ctx.beginPath()
    ctx.moveTo(PAD_X + 16, LIST_START_Y - 28)
    ctx.lineTo(CANVAS_W - PAD_X, LIST_START_Y - 28)
    ctx.stroke()

    // 清单项 — 圆角标签卡片
    ctx.textAlign = 'start'
    const maxC = Math.floor((FOOTER_START_Y - LIST_START_Y) / ROW_H)
    const cnt  = Math.min(this.missingItems.length, maxC)
    for (let i = 0; i < cnt; i++) {
      const rowY  = LIST_START_Y + i * ROW_H
      const textY = rowY + 110
      const emoji = ShoppingListService.getIngredientEmoji(this.missingItems[i])

      // 卡片背景
      ctx.fillStyle = tagC
      ctx.beginPath()
      this.roundRect(ctx, PAD_X + 16, rowY + 6, CANVAS_W - PAD_X * 2 - 16, ROW_H - 12, 20)
      ctx.fill()

      // 左侧小色块
      ctx.fillStyle = accent
      ctx.beginPath()
      this.roundRect(ctx, PAD_X + 16, rowY + 6, 10, ROW_H - 12, 5)
      ctx.fill()

      ctx.font = '80px sans-serif'
      ctx.fillStyle = titleC
      ctx.fillText(emoji, PAD_X + 52, textY)

      ctx.font = 'bold 68px sans-serif'
      ctx.fillStyle = textC
      ctx.fillText(this.missingItems[i], PAD_X + 162, textY)
    }

    this.drawFooter(ctx, textC, lineC, accent)
  }

  // ── 样式三：牛皮纸温暖 ───────────────────────────────────────────────────
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

    // 纸张纹理：随机细点
    ctx.fillStyle = pickColor('rgba(100,60,20,0.05)', 'rgba(255,220,150,0.03)', dark)
    for (let d = 0; d < 120; d++) {
      ctx.beginPath()
      ctx.arc((d * 197 + 31) % CANVAS_W, (d * 113 + 57) % CANVAS_H, 1.8, 0, Math.PI * 2)
      ctx.fill()
    }

    // 顶部双条纹
    ctx.fillStyle = accent
    ctx.fillRect(0, 0, CANVAS_W, 12)
    ctx.fillStyle = pickColor('rgba(181,84,28,0.3)', 'rgba(212,121,58,0.3)', dark)
    ctx.fillRect(0, 12, CANVAS_W, 6)

    // App 名称 — 居中小字
    ctx.font = '46px sans-serif'
    ctx.fillStyle = subC
    ctx.globalAlpha = 0.8
    ctx.textAlign = 'center'
    ctx.fillText('AUV 您吃了么', CANVAS_W / 2, APP_NAME_Y)
    ctx.globalAlpha = 1.0

    // 主标题
    ctx.font = 'bold 118px sans-serif'
    ctx.fillStyle = titleC
    ctx.fillText('✦ 采购清单 ✦', CANVAS_W / 2, HEADER_Y)

    // 标题上下装饰线
    ctx.strokeStyle = accent
    ctx.lineWidth = 4
    ctx.beginPath()
    ctx.moveTo(CANVAS_W / 2 - 320, HEADER_Y + 20)
    ctx.lineTo(CANVAS_W / 2 + 320, HEADER_Y + 20)
    ctx.stroke()

    // 菜名
    if (this.recipeName.length > 0) {
      ctx.font = '54px sans-serif'
      ctx.fillStyle = subC
      ctx.fillText(`为「${this.recipeName}」准备`, CANVAS_W / 2, HEADER_Y + 96)
    }

    // 双横线
    ctx.strokeStyle = lineC
    ctx.lineWidth = 3
    ctx.beginPath()
    ctx.moveTo(PAD_X, LIST_START_Y - 34)
    ctx.lineTo(CANVAS_W - PAD_X, LIST_START_Y - 34)
    ctx.stroke()
    ctx.lineWidth = 1
    ctx.beginPath()
    ctx.moveTo(PAD_X + 16, LIST_START_Y - 24)
    ctx.lineTo(CANVAS_W - PAD_X - 16, LIST_START_Y - 24)
    ctx.stroke()

    this.drawIngredientList(ctx, textC, accent, lineC, false)
    this.drawFooter(ctx, subC, lineC, accent)
  }

  // ── 清单项公共绘制 ────────────────────────────────────────────────────────
  private drawIngredientList(ctx: CanvasRenderingContext2D, textC: string, accent: string, lineC: string, showDots: boolean): void {
    const maxRows = Math.floor((FOOTER_START_Y - LIST_START_Y) / ROW_H)
    const count = Math.min(this.missingItems.length, maxRows)
    for (let i = 0; i < count; i++) {
      const rowY  = LIST_START_Y + i * ROW_H
      const textY = rowY + 110   // 垂直居中于 ROW_H=170
      const emoji = ShoppingListService.getIngredientEmoji(this.missingItems[i])

      // 交替行淡背景
      if (i % 2 === 0) {
        ctx.fillStyle = this.isDark() ? 'rgba(255,255,255,0.03)' : 'rgba(0,0,0,0.025)'
        ctx.fillRect(PAD_X, rowY, CANVAS_W - PAD_X * 2, ROW_H)
      }

      if (showDots) {
        // 实心圆点
        ctx.fillStyle = accent
        ctx.beginPath()
        ctx.arc(PAD_X + 38, textY - 10, 16, 0, Math.PI * 2)
        ctx.fill()
      }

      // emoji
      ctx.font = '82px sans-serif'
      ctx.fillStyle = textC
      ctx.textAlign = 'start'
      ctx.fillText(emoji, showDots ? PAD_X + 76 : PAD_X + 26, textY)

      // 食材名
      ctx.font = 'bold 72px sans-serif'
      ctx.fillStyle = textC
      ctx.fillText(this.missingItems[i], showDots ? PAD_X + 178 : PAD_X + 122, textY)

      // 行分隔线
      ctx.strokeStyle = lineC
      ctx.lineWidth = 1.5
      ctx.beginPath()
      ctx.moveTo(PAD_X + 26, rowY + ROW_H - 1)
      ctx.lineTo(CANVAS_W - PAD_X, rowY + ROW_H - 1)
      ctx.stroke()
    }
  }

  // ── 底部：App 名 + 日期 + 数量 ───────────────────────────────────────────
  private drawFooter(ctx: CanvasRenderingContext2D, textC: string, lineC: string, accent: string): void {
    const today = new Date()
    const dateStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`

    // 分隔线
    ctx.strokeStyle = lineC
    ctx.lineWidth = 2
    ctx.beginPath()
    ctx.moveTo(PAD_X, FOOTER_START_Y)
    ctx.lineTo(CANVAS_W - PAD_X, FOOTER_START_Y)
    ctx.stroke()

    // 第一行：App 名
    ctx.font = 'bold 52px sans-serif'
    ctx.fillStyle = accent
    ctx.globalAlpha = 0.9
    ctx.textAlign = 'center'
    ctx.fillText('AUV 您吃了么', CANVAS_W / 2, FOOTER_START_Y + 74)

    // 第二行：日期 + 数量
    ctx.font = '42px sans-serif'
    ctx.fillStyle = textC
    ctx.globalAlpha = 0.55
    ctx.fillText(`${dateStr}  ·  共 ${this.missingItems.length} 项`, CANVAS_W / 2, FOOTER_START_Y + 136)
    ctx.globalAlpha = 1.0

    // 底边粗色条
    ctx.fillStyle = accent
    ctx.fillRect(0, CANVAS_H - 14, CANVAS_W, 14)
  }

  /** 圆角矩形路径 */
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
  // 保存到相册（SaveButton onClick 回调）
  // ══════════════════════════════════════════════════════════════════════

  async saveToAlbum(): Promise<void> {
    if (this.saving) return
    this.saving = true
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
      if (!ctx) { this.showToast('无法获取应用上下文'); this.saving = false; return }

      // 确保 Canvas 内容已绘制
      this.drawCurrentStyle()

      // 直接从 CanvasRenderingContext2D 读取像素（无需组件可见，不依赖 componentSnapshot）
      const pm: image.PixelMap = this.drawCtx.getPixelMap(0, 0, CANVAS_W, CANVAS_H)
      if (pm === null || pm === undefined) {
        this.showToast('Canvas 读取失败'); this.saving = false; return
      }

      // 编码为 JPEG
      const packer = image.createImagePacker()
      const packed: ArrayBuffer = await packer.packing(pm, { format: 'image/jpeg', quality: 98 } as image.PackingOption)
      packer.release()
      pm.release()

      // 写入应用临时目录（沙箱内，无需权限）
      const tempPath: string = ctx.tempDir + '/shopping_' + Date.now() + '.jpg'
      const tmpFile = await fileIo.open(tempPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE)
      await fileIo.write(tmpFile.fd, packed)
      await fileIo.close(tmpFile.fd)

      // 通过 photoAccessHelper 写入系统相册（SaveButton.onClick 回调内已临时授权，有效 1 分钟）
      const helper = photoAccessHelper.getPhotoAccessHelper(ctx)
      const uri: string = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'jpg')
      const destFile = await fileIo.open(uri, fileIo.OpenMode.READ_WRITE)
      await fileIo.write(destFile.fd, packed)
      await fileIo.close(destFile.fd)

      // 清理临时文件
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
  // Builders
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

        // 全尺寸 Canvas（position 移出屏幕但保持挂载，供 getPixelMap 读取像素）
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
            .fontSize(17).fontWeight(FontWeight.Bold).fontColor('#1F2937')
            .margin({ bottom: 12 })

          // ── Swiper 样式滑动选择 ──
          Swiper() {
            ForEach(STYLES, (style: StyleDef, idx: number) => {
              Column() {
                // 样式一：便签风
                // 样式二：极简白卡（左侧色条）
                // 样式三：牛皮纸
                Stack({ alignContent: Alignment.TopStart }) {
                  // 背景
                  Column()
                    .width('100%').height('100%')
                    .backgroundColor(this.isDark() ? style.previewBgDark : style.previewBg)
                    .borderRadius(14)

                  // 样式二：左侧竖条
                  if (idx === 1) {
                    Column()
                      .width(5).height('100%')
                      .backgroundColor(this.isDark() ? style.previewAccentDark : style.previewAccent)
                      .borderRadius({ topLeft: 14, bottomLeft: 14 })
                  }

                  // 内容
                  Column({ space: 8 }) {
                    // 顶部条（样式一/三）
                    if (idx !== 1) {
                      Row()
                        .width('100%').height(5)
                        .backgroundColor(this.isDark() ? style.previewAccentDark : style.previewAccent)
                        .borderRadius({ topLeft: 14, topRight: 14 })
                        .margin({ bottom: 2 })
                    }

                    // App 名
                    Text('AUV 您吃了么')
                      .fontSize(11)
                      .fontColor(this.isDark() ? style.previewAccentDark : style.previewAccent)
                      .opacity(0.8)
                      .alignSelf(idx === 1 ? ItemAlign.Start : ItemAlign.Center)
                      .padding({ left: idx === 1 ? 10 : 0 })

                    // 主标题
                    Text(idx === 2 ? '✦ 采购清单 ✦' : '采购清单')
                      .fontSize(22).fontWeight(FontWeight.Bold)
                      .fontColor(this.isDark()
                        ? (idx === 0 ? '#FF9A3C' : idx === 1 ? '#F2F2F2' : '#E8C88A')
                        : (idx === 0 ? '#D94F00' : idx === 1 ? '#111111' : '#7A3B10'))
                      .alignSelf(idx === 1 ? ItemAlign.Start : ItemAlign.Center)
                      .padding({ left: idx === 1 ? 10 : 0 })

                    // 清单项预览
                    Column({ space: 4 }) {
                      ForEach(
                        (this.missingItems.length > 0 ? this.missingItems : ['番茄', '猪肉', '白菜']).slice(0, 3),
                        (item: string) => {
                          Row({ space: 5 }) {
                            Text(ShoppingListService.getIngredientEmoji(item)).fontSize(14)
                            Text(item).fontSize(13)
                              .fontColor(this.isDark() ? '#999' : '#666')
                              .fontWeight(FontWeight.Medium)
                          }.alignSelf(idx === 1 ? ItemAlign.Start : ItemAlign.Center)
                          .padding({ left: idx === 1 ? 10 : 0 })
                        }, (item: string) => `pv-${idx}-${item}`)
                      if ((this.missingItems.length > 3)) {
                        Text(`+ ${this.missingItems.length - 3} 项…`)
                          .fontSize(11).fontColor('#AAAAAA')
                          .alignSelf(idx === 1 ? ItemAlign.Start : ItemAlign.Center)
                          .padding({ left: idx === 1 ? 10 : 0 })
                      }
                    }
                  }
                  .width('100%').height('100%')
                  .padding({ top: 0, left: 0, right: 12, bottom: 10 })
                  .justifyContent(FlexAlign.Center)
                  .alignItems(idx === 1 ? HorizontalAlign.Start : HorizontalAlign.Center)
                }
                .width('100%').height('100%')
                .clip(true)
                .borderRadius(14)
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
              .itemWidth(6).itemHeight(6)
              .selectedItemWidth(18).selectedItemHeight(6)
          )
          .onChange((index: number) => {
            this.selectedIdx = index
            this.swiperKey++
            this.getUIContext().animateTo({ duration: 200, curve: Curve.EaseInOut }, () => {})
          })
          .width('100%')
          .height(280)
          .margin({ left: 16, right: 16, bottom: 12 })

          // 当前样式标签
          Text(STYLES[this.selectedIdx]?.label ?? '')
            .fontSize(13).fontWeight(FontWeight.Medium)
            .fontColor(AppColors.BRAND_COLOR)
            .margin({ bottom: 10 })


          // ── SaveButton + 提示文字 ──
          Text('选择精美模板，保存为图片')
            .fontSize(12).fontColor('#9CA3AF')
            .margin({ bottom: 10 })

          SaveButton()
            .width('88%').height(52)
            .borderRadius(26)
            .fontSize(16).fontWeight(FontWeight.Bold)
            .onClick(async (_event: ClickEvent, result: SaveButtonOnClickResult) => {
              if (result === SaveButtonOnClickResult.SUCCESS) {
                void this.saveToAlbum()
              } else {
                this.showToast('保存已取消')
              }
            })

          // 取消
          Text('取消')
            .fontSize(14).fontColor('#9CA3AF')
            .width('100%').textAlign(TextAlign.Center)
            .padding({ top: 12, bottom: 12 })
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
