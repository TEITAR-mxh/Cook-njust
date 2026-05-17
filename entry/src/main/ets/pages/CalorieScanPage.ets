import { cameraPicker } from '@kit.CameraKit'
import { camera } from '@kit.CameraKit'
import { common, abilityAccessCtrl, Permissions } from '@kit.AbilityKit'
import { AppColors, ThemeManager } from '../constants/AppColors'
import { getSystemSafeTopVp } from '../util/StatusBarInset'
import { FoodRecognitionService, FoodRecognitionResult } from '../service/FoodRecognitionService'
import { PhotoPickerHelper } from '../utils/PhotoPickerHelper'
import { CalorieCalculator, NutrientData } from '../utils/CalorieCalculator'
import { DietDatabaseHelper, DietRecord } from '../data/DietDatabaseHelper'
import { ToastView } from '../components/ToastView'

// 取景框专用常量，不随主题变化
const CAMERA_BG     = AppColors.DARK_BG_COLOR   // '#121212'
const CORNER_COLOR  = '#CCFFFFFF'               // L形标线白色 80%透明
const SCAN_OVERLAY  = '#5F000000'               // 扫描蒙层

const enum ScanState { IDLE = 0, PREVIEW = 1, RECOGNIZING = 2, RESULT = 3, MANUAL = 4 }

const MEAL_TYPES:  string[] = ['早餐', '午餐', '晚餐', '加餐']
const MEAL_EMOJIS: string[] = ['🌅', '☀️', '🌙', '🍵']

@Entry
@Component
struct CalorieScanPage {
  @State private safeTopVp: number = 48
  @Watch('onScanStateChange')
  @State private scanState: ScanState = ScanState.IDLE
  @State private capturedUri: string = ''
  @State private recognitionResult: FoodRecognitionResult | null = null

  // 脉冲动画
  @State private pulseScale: number = 1.0
  @State private pulseAlpha: number = 0.6

  // 结果卡浮现动画
  @State private cardOpacity: number = 0
  @State private cardOffset:  number = 20

  // 按钮弹性
  @State private saveBtnScale:  number = 1.0
  @State private qtyMinusSc:    number = 1.0
  @State private qtyPlusSc:     number = 1.0

  // 页面淡入
  @State private pageOpacity: number = 0

  // 结果展示 — 全部 @State 基本类型，proxy 安全
  @State private resultName:    string = ''
  @State private resultTag:     string = '手动'
  @State private dispCalories:  number = 0
  @State private dispProtein:   number = 0
  @State private dispFat:       number = 0
  @State private dispCarbs:     number = 0
  // 每100g 原始数据，只在非 Builder 上下文中读写
  private rawCal:     number = 0
  private rawPro:     number = 0
  private rawFat:     number = 0
  private rawCarbs:   number = 0
  private rawServing: number = 200

  @Watch('onQtyChange')
  @State private quantity:    number = 1.0
  @State private mealType:    string = '加餐'
  @State private manualInput: string = ''
  @State private saving:      boolean = false

  @State private toastMsg:     string = ''
  @State private toastVisible: boolean = false

  // 主题
  @StorageProp('isSystemDarkMode') @Watch('onThemeChange') private isSystemDark: boolean = false
  @StorageProp('currentThemeMode') @Watch('onThemeChange') private themeMode:    string  = '系统默认'
  @State private bgColor:     string  = AppColors.BG_COLOR
  @State private cardBg:      string  = AppColors.CARD_BG
  @State private textColor:   string  = AppColors.GRAY_900
  @State private secondColor: string  = AppColors.GRAY_500
  @State private divColor:    string  = AppColors.GRAY_100
  @State private isDark:      boolean = false
  // 导航栏背景随状态切换，用 @State 变量驱动
  @State private navBg: string = '#00000000'

  private pulseActive: boolean = false

  // ── 生命周期 ──────────────────────────────────────────────────────────

  aboutToAppear(): void {
    this.isDark = this.resolveDark()
    this.syncTheme()
    this.navBg = '#00000000'
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (host) {
      void getSystemSafeTopVp(host).then((v: number) => { this.safeTopVp = v })
    }
    this.getUIContext().animateTo({ duration: 350, curve: Curve.EaseOut }, () => { this.pageOpacity = 1 })
    this.pulseActive = true
    this.pulseLoop()
  }

  aboutToDisappear(): void {
    this.pulseActive = false
  }

  // ── 主题 ─────────────────────────────────────────────────────────────

  private onThemeChange(): void {
    this.isDark = this.resolveDark()
    this.syncTheme()
    this.refreshNavBg()
  }

  private onScanStateChange(): void {
    this.refreshNavBg()
  }

  private resolveDark(): boolean {
    if (this.themeMode === '深色模式') return true
    if (this.themeMode === '浅色模式') return false
    return this.isSystemDark
  }

  private syncTheme(): void {
    this.bgColor     = ThemeManager.getBackgroundColor(this.themeMode)
    this.cardBg      = ThemeManager.getCardBackgroundColor(this.themeMode)
    this.textColor   = ThemeManager.getTextColor(this.themeMode)
    this.secondColor = ThemeManager.getSecondaryTextColor(this.themeMode)
    this.divColor    = ThemeManager.getBorderColor(this.themeMode)
  }

  private refreshNavBg(): void {
    this.navBg = this.scanState === ScanState.IDLE
      ? '#00000000'
      : (this.isDark ? '#DD121212' : '#EEF9FAFB')
  }

  // ── 脉冲动画 ─────────────────────────────────────────────────────────

  private pulseLoop(): void {
    if (!this.pulseActive) return
    this.getUIContext().animateTo({ duration: 780, curve: Curve.EaseOut }, () => {
      this.pulseScale = 1.18
      this.pulseAlpha = 0.0
    })
    setTimeout(() => {
      if (!this.pulseActive) return
      this.pulseScale = 1.0
      this.pulseAlpha = 0.6
      this.pulseLoop()
    }, 800)
  }

  // ── 相机与相册 ────────────────────────────────────────────────────────

  private async requestCamera(): Promise<boolean> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (!host) return false
    try {
      const mgr = abilityAccessCtrl.createAtManager()
      const r = await mgr.requestPermissionsFromUser(host, ['ohos.permission.CAMERA'] as Permissions[])
      return r.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED
    } catch {
      return false
    }
  }

  private async launchCamera(): Promise<void> {
    if (!(await this.requestCamera())) { this.showPermDenied(); return }
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (!host) return
    try {
      const r = await cameraPicker.pick(host, [cameraPicker.PickerMediaType.PHOTO], {
        cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK,
      } as cameraPicker.PickerProfile)
      if (r.resultCode === 0 && r.resultUri.length > 0) {
        this.capturedUri = r.resultUri
        this.scanState   = ScanState.PREVIEW
      }
    } catch (e) {
      console.error('[CalorieScan] camera error:', JSON.stringify(e))
      this.toast('相机启动失败，请重试')
    }
  }

  private async launchPicker(): Promise<void> {
    const uri = await PhotoPickerHelper.selectSinglePhoto()
    if (uri) {
      this.capturedUri = uri
      this.scanState   = ScanState.PREVIEW
    }
  }

  // ── 识别流程 ─────────────────────────────────────────────────────────

  private async startRecognition(): Promise<void> {
    if (this.capturedUri.length === 0) return
    this.scanState = ScanState.RECOGNIZING
    try {
      const r = await FoodRecognitionService.recognize(this.capturedUri)
      this.recognitionResult = r
      this.quantity = 1.0
      if (r.identified) {
        this.applyResult(r)
        this.animateCardIn()
      } else {
        this.scanState = ScanState.MANUAL
        this.toast('未能识别，请手动输入食物名称')
      }
    } catch (e) {
      console.error('[CalorieScan] recognition error:', JSON.stringify(e))
      this.scanState = ScanState.MANUAL
      this.toast('识别服务暂时不可用，请手动输入')
    }
  }

  private animateCardIn(): void {
    this.cardOpacity = 0
    this.cardOffset  = 20
    this.scanState   = ScanState.RESULT
    this.getUIContext().animateTo({ duration: 360, curve: Curve.EaseOut }, () => {
      this.cardOpacity = 1
      this.cardOffset  = 0
    })
  }

  // ── 手动输入 ─────────────────────────────────────────────────────────

  private confirmManual(): void {
    const name = this.manualInput.trim()
    if (name.length === 0) { this.toast('请输入食物名称'); return }
    const n = CalorieCalculator.lookup(name)
      ?? CalorieCalculator.fuzzyMatch([name])?.data
      ?? { calories: 100, protein: 5, fat: 3, carbs: 15, servingWeight: 200 } as NutrientData
    const r: FoodRecognitionResult = { identified: true, foodName: name, nutrient: n, source: 'manual', rawLabels: [] }
    this.recognitionResult = r
    this.applyResult(r)
    this.quantity = 1.0
    this.animateCardIn()
  }

  // ── 保存 ─────────────────────────────────────────────────────────────

  private async save(): Promise<void> {
    if (this.saving || this.recognitionResult === null) return
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (!host) return
    this.saving = true
    this.getUIContext().animateTo({ duration: 90 }, () => { this.saveBtnScale = 0.94 })
    setTimeout(() => { this.getUIContext().animateTo({ duration: 130, curve: Curve.EaseOut }, () => { this.saveBtnScale = 1.0 }) }, 95)
    try {
      const r    = this.recognitionResult
      const calc = CalorieCalculator.calcByQuantity(r.nutrient, this.quantity)
      const rec: DietRecord = {
        date: DietDatabaseHelper.todayDateStr(), mealType: this.mealType,
        foodName: r.foodName, quantity: this.quantity, unit: '份',
        calories: calc.totalCalories, protein: calc.totalProtein,
        fat: calc.totalFat, carbs: calc.totalCarbs,
        imageUri: this.capturedUri, timestamp: Date.now(),
      }
      await DietDatabaseHelper.getInstance().insertRecord(host, rec)
      this.toast(`✅ 已记录：${r.foodName}  ${calc.totalCalories} 千卡`)
      setTimeout(() => {
        this.scanState = ScanState.IDLE
        this.capturedUri = ''
        this.recognitionResult = null
      }, 1500)
    } catch (e) {
      console.error('[CalorieScan] save error:', JSON.stringify(e))
      this.toast('保存失败，请重试')
    } finally {
      this.saving = false
    }
  }

  // ── 结果数据 ──────────────────────────────────────────────────────────

  private applyResult(r: FoodRecognitionResult): void {
    this.resultName  = r.foodName
    this.resultTag   = this.sourceToTag(r.source)
    this.rawCal      = r.nutrient.calories
    this.rawPro      = r.nutrient.protein
    this.rawFat      = r.nutrient.fat
    this.rawCarbs    = r.nutrient.carbs
    this.rawServing  = r.nutrient.servingWeight
    this.recalc()
  }

  private recalc(): void {
    const f = this.rawServing * this.quantity / 100
    this.dispCalories = Math.round(this.rawCal   * f)
    this.dispProtein  = Math.round(this.rawPro   * f * 10) / 10
    this.dispFat      = Math.round(this.rawFat   * f * 10) / 10
    this.dispCarbs    = Math.round(this.rawCarbs * f * 10) / 10
  }

  private onQtyChange(): void { this.recalc() }

  /** 推理来源 → 展示标签 */
  private sourceToTag(source: string): string {
    switch (source) {
      case 'local_npu': return '本地NPU'
      case 'local_cpu': return '本地CPU'
      case 'cloud':     return '云端'
      case 'manual':    return '手动'
      default:          return '未识别'
    }
  }

  /** 推理来源 → 展示颜色 */
  private sourceColor(source: string): string {
    switch (source) {
      case 'local_npu': return '#34D399'  // 绿色：本地NPU最高效
      case 'local_cpu': return '#FBBF24'  // 琥珀：本地CPU
      case 'cloud':     return '#60A5FA'  // 蓝色：云端
      case 'manual':    return '#9CA3AF'  // 灰色：手动
      default:          return '#EF4444'  // 红色：未识别
    }
  }

  // ── Toast & Dialog ────────────────────────────────────────────────────

  private toast(msg: string): void {
    this.toastMsg     = msg
    this.toastVisible = true
    setTimeout(() => { this.toastVisible = false }, 2600)
  }

  private showPermDenied(): void {
    this.getUIContext().showAlertDialog({
      title: '需要相机权限',
      message: '请在系统设置 → 应用管理 → 您吃了么 → 权限 中开启相机权限。',
      primaryButton: { value: '知道了', action: () => {} },
      secondaryButton: {
        value: '退出',
        action: () => {
          const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
          ctx ? ctx.terminateSelf() : this.getUIContext().getRouter().back()
        },
      },
      autoCancel: false,
    })
  }

  // ════════════════════════════════════════════════════════════════════════
  // Builders
  // 规则：所有 @Builder 只读 @State 基本类型变量，禁止 getter 和方法调用
  // ════════════════════════════════════════════════════════════════════════

  // 悬浮导航栏 — 透明(IDLE) / 毛玻璃(其他状态)
  @Builder
  FloatNav() {
    Row() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20)
          .fontColor([this.scanState === ScanState.IDLE ? '#FFFFFF' : this.textColor])
      }
      .width(44).height(44).justifyContent(FlexAlign.Center)
      .onClick(() => this.getUIContext().getRouter().back())

      Text('热量识别')
        .fontSize(16).fontWeight(FontWeight.Medium)
        .fontColor(this.scanState === ScanState.IDLE ? '#FFFFFF' : this.textColor)
        .layoutWeight(1).textAlign(TextAlign.Center)

      if (this.scanState === ScanState.IDLE) {
        Row() {
          SymbolGlyph($r('sys.symbol.picture_fill')).fontSize(18).fontColor(['#FFFFFF'])
        }
        .width(44).height(44).justifyContent(FlexAlign.Center)
        .onClick(() => { void this.launchPicker() })
      } else {
        Blank().width(44)
      }
    }
    .width('100%')
    .height(this.safeTopVp + 48)
    .padding({ top: this.safeTopVp, left: 4, right: 4 })
    .backgroundColor(this.navBg)
    .backgroundBlurStyle(this.scanState === ScanState.IDLE ? BlurStyle.NONE : BlurStyle.Thin)
  }

  // 取景框区（52%屏高，始终深色底）
  @Builder
  CameraFrame() {
    Stack() {
      // 深色底板，不跟随主题
      Column().width('100%').height('100%').backgroundColor(CAMERA_BG)

      // 已选图片
      if (this.capturedUri.length > 0) {
        Image(this.capturedUri)
          .width('100%').height('100%')
          .objectFit(ImageFit.Cover)
      }

      // 空态引导文字
      if (this.scanState === ScanState.IDLE) {
        Column({ space: 14 }) {
          Text('📸').fontSize(60)
          Text('对准食物，轻点拍摄')
            .fontSize(15).fontColor(CORNER_COLOR).fontWeight(FontWeight.Medium)
          Text('识别常见中国家常菜、食材和零食')
            .fontSize(12).fontColor('#80FFFFFF')
        }
        .width('100%').height('100%')
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      }

      // 识别中：蒙层 + 脉冲圆环
      if (this.scanState === ScanState.RECOGNIZING) {
        Stack() {
          Column().width('100%').height('100%').backgroundColor(SCAN_OVERLAY)
          Column({ space: 12 }) {
            Circle()
              .width(110).height(110)
              .fill('transparent')
              .stroke(AppColors.BRAND_COLOR)
              .strokeWidth(2.5)
              .opacity(this.pulseAlpha)
              .scale({ x: this.pulseScale, y: this.pulseScale })
            Text('正在识别…')
              .fontSize(15).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
          }
          .width('100%').height('100%')
          .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        }.width('100%').height('100%')
      }

      // L 形角标（IDLE / PREVIEW），顶部用 margin 避开导航栏
      if (this.scanState === ScanState.IDLE || this.scanState === ScanState.PREVIEW) {
        Column() {
          Row() {
            Column() {
              Row().width(26).height(2.5).backgroundColor(CORNER_COLOR).borderRadius(1.5)
              Row().width(2.5).height(22).backgroundColor(CORNER_COLOR).borderRadius(1.5).margin({ top: -1 })
            }.alignItems(HorizontalAlign.Start)
            Blank()
            Column() {
              Row().width(26).height(2.5).backgroundColor(CORNER_COLOR).borderRadius(1.5)
              Row().width(2.5).height(22).backgroundColor(CORNER_COLOR)
                .borderRadius(1.5).margin({ top: -1 }).alignSelf(ItemAlign.End)
            }.alignItems(HorizontalAlign.End)
          }
          .width('100%').padding({ left: 22, right: 22 })
          .margin({ top: this.safeTopVp + 52 })

          Blank().layoutWeight(1)

          Row() {
            Column() {
              Row().width(2.5).height(22).backgroundColor(CORNER_COLOR).borderRadius(1.5)
              Row().width(26).height(2.5).backgroundColor(CORNER_COLOR).borderRadius(1.5).margin({ top: -1 })
            }.alignItems(HorizontalAlign.Start)
            Blank()
            Column() {
              Row().width(2.5).height(22).backgroundColor(CORNER_COLOR)
                .borderRadius(1.5).alignSelf(ItemAlign.End)
              Row().width(26).height(2.5).backgroundColor(CORNER_COLOR)
                .borderRadius(1.5).margin({ top: -1 }).alignSelf(ItemAlign.End)
            }.alignItems(HorizontalAlign.End)
          }
          .width('100%').padding({ left: 22, right: 22 })
          .margin({ bottom: 16 })
        }.width('100%').height('100%')

        // PREVIEW 右上角"重新拍摄"按钮
        if (this.scanState === ScanState.PREVIEW) {
          Row() {
            Blank()
            Row({ space: 5 }) {
              SymbolGlyph($r('sys.symbol.camera')).fontSize(12).fontColor(['#FFFFFF'])
              Text('重新拍摄').fontSize(11).fontColor('#FFFFFF')
            }
            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .backgroundColor('#60000000').borderRadius(20)
            .onClick(() => { this.capturedUri = ''; this.scanState = ScanState.IDLE })
          }
          .width('100%').padding({ top: this.safeTopVp + 56, right: 16 })
        }
      }
    }
    .width('100%')
    // RESULT 状态：收起取景框，食物图内嵌到 ResultCard 随内容滚动
    .height(this.scanState === ScanState.RESULT ? 0 : '52%')
    .borderRadius({ bottomLeft: 28, bottomRight: 28 })
    .clip(true)
  }

  // 营养素行（色点 + 标签 + 粗体值）
  @Builder
  NutrientRow(dot: string, label: string, value: string) {
    Row({ space: 10 }) {
      Row().width(10).height(10).borderRadius(5).backgroundColor(dot).flexShrink(0)
      Text(label).fontSize(13).fontColor(this.secondColor).layoutWeight(1)
      Text(value).fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.textColor)
    }
    .width('100%').height(44)
  }

  // 份量胶囊选择器
  @Builder
  QtyPill() {
    Row() {
      Text('份量').fontSize(14).fontColor(this.secondColor).layoutWeight(1)
      Row() {
        Text('－')
          .fontSize(20).fontColor(AppColors.BRAND_COLOR)
          .width(44).height(44).textAlign(TextAlign.Center)
          .scale({ x: this.qtyMinusSc, y: this.qtyMinusSc })
          .onClick(() => {
            if (this.quantity <= 0.5) return
            this.getUIContext().animateTo({ duration: 80 }, () => { this.qtyMinusSc = 0.86 })
            setTimeout(() => { this.getUIContext().animateTo({ duration: 120, curve: Curve.EaseOut }, () => { this.qtyMinusSc = 1.0 }) }, 85)
            this.quantity = Math.round((this.quantity - 0.5) * 10) / 10
          })
        Text(`${this.quantity}`)
          .fontSize(19).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          .width(46).textAlign(TextAlign.Center)
        Text('＋')
          .fontSize(20).fontColor(AppColors.BRAND_COLOR)
          .width(44).height(44).textAlign(TextAlign.Center)
          .scale({ x: this.qtyPlusSc, y: this.qtyPlusSc })
          .onClick(() => {
            if (this.quantity >= 10) return
            this.getUIContext().animateTo({ duration: 80 }, () => { this.qtyPlusSc = 0.86 })
            setTimeout(() => { this.getUIContext().animateTo({ duration: 120, curve: Curve.EaseOut }, () => { this.qtyPlusSc = 1.0 }) }, 85)
            this.quantity = Math.round((this.quantity + 0.5) * 10) / 10
          })
      }
      .height(44)
      .backgroundColor(this.isDark ? AppColors.DARK_GRAY_100 : AppColors.GRAY_100)
      .borderRadius(22)
    }.width('100%')
  }

  // 餐次选择（emoji + 文字双行）
  @Builder
  MealRow() {
    Row({ space: 10 }) {
      ForEach(MEAL_TYPES, (meal: string, i: number) => {
        Column({ space: 2 }) {
          Text(MEAL_EMOJIS[i]).fontSize(18)
          Text(meal)
            .fontSize(11)
            .fontColor(this.mealType === meal ? AppColors.BRAND_COLOR : this.secondColor)
            .fontWeight(this.mealType === meal ? FontWeight.Bold : FontWeight.Normal)
        }
        .width(56).height(52).justifyContent(FlexAlign.Center)
        .backgroundColor(
          this.mealType === meal
            ? (this.isDark ? '#2A1215' : AppColors.BRAND_COLOR_LIGHT)
            : 'transparent'
        )
        .borderRadius(12)
        .border({ width: this.mealType === meal ? 1.5 : 0, color: AppColors.BRAND_COLOR })
        .onClick(() => { this.mealType = meal })
      }, (meal: string) => meal)
    }.width('100%')
  }

  // 识别结果卡（有数据才调用）
  @Builder
  ResultCard() {
    Column({ space: 0 }) {
      // 食物图（全宽卡头，随 Scroll 滚动）
      if (this.capturedUri.length > 0) {
        Stack({ alignContent: Alignment.BottomStart }) {
          Image(this.capturedUri)
            .width('100%').height(220)
            .objectFit(ImageFit.Cover)
          // 重拍按钮：内联导航栏已在上方，此处 top:14 即图片右上角
          Row({ space: 5 }) {
            SymbolGlyph($r('sys.symbol.camera')).fontSize(12).fontColor(['#FFFFFF'])
            Text('重新拍摄').fontSize(11).fontColor('#FFFFFF')
          }
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .backgroundColor('#60000000').borderRadius(20)
          .position({ right: 14, top: 14 })
          .onClick(() => {
            this.recognitionResult = null
            this.capturedUri = ''
            this.scanState = ScanState.IDLE
          })
        }.width('100%')
      }

      // 食物名 + 来源标签（颜色随推理来源动态变化）
      Row({ space: 10 }) {
        Text(this.resultName)
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.resultTag)
          .fontSize(11).fontColor(this.sourceColor(this.recognitionResult?.source ?? 'none'))
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .backgroundColor(this.isDark
            ? this.sourceColor(this.recognitionResult?.source ?? 'none') + '20'
            : this.sourceColor(this.recognitionResult?.source ?? 'none') + '18')
          .borderRadius(12)
      }.padding({ left: 20, right: 20, top: 20, bottom: 6 })

      // 热量大字
      Row({ space: 4 }) {
        Text(`${this.dispCalories}`)
          .fontSize(46).fontWeight(FontWeight.Bold).fontColor(AppColors.BRAND_COLOR)
        Column({ space: 2 }) {
          Text('千卡').fontSize(14).fontColor(this.secondColor)
          Text('本份').fontSize(11).fontColor(this.isDark ? AppColors.DARK_GRAY_400 : AppColors.GRAY_400)
        }.margin({ top: 16 }).alignItems(HorizontalAlign.Start)
      }.padding({ left: 20, bottom: 12 })

      Divider().color(this.divColor).margin({ left: 20, right: 20 })

      // 三大营养素
      Column() {
        this.NutrientRow('#22C55E', '蛋白质',    `${this.dispProtein} g`)
        Divider().color(this.divColor)
        this.NutrientRow('#F59E0B', '脂肪',      `${this.dispFat} g`)
        Divider().color(this.divColor)
        this.NutrientRow('#3B82F6', '碳水化合物', `${this.dispCarbs} g`)
      }.padding({ left: 20, right: 20 })

      Divider().color(this.divColor).margin({ left: 20, right: 20 })

      // 份量
      Column() { this.QtyPill() }.padding({ left: 20, right: 20 })

      Divider().color(this.divColor).margin({ left: 20, right: 20 })

      // 餐次
      Column({ space: 8 }) {
        Text('选择餐次').fontSize(12).fontColor(this.secondColor).alignSelf(ItemAlign.Start)
        this.MealRow()
      }.padding({ left: 20, right: 20, top: 12, bottom: 14 })

      Divider().color(this.divColor).margin({ left: 20, right: 20 })

      // 操作按钮
      Column({ space: 10 }) {
        Button(this.saving ? '保存中…' : '✓ 记录今日饮食')
          .width('100%').height(52)
          .backgroundColor(AppColors.BRAND_COLOR)
          .fontColor(Color.White).fontWeight(FontWeight.Bold).fontSize(15)
          .borderRadius(26)
          .scale({ x: this.saveBtnScale, y: this.saveBtnScale })
          .shadow({ radius: 12, color: AppColors.BRAND_COLOR + '44', offsetX: 0, offsetY: 4 })
          .enabled(!this.saving)
          .onClick(() => { void this.save() })
        Button('重新识别')
          .width('100%').height(44)
          .backgroundColor('transparent')
          .fontColor(this.secondColor).fontSize(14)
          .onClick(() => {
            this.recognitionResult = null
            this.capturedUri = ''
            this.scanState = ScanState.IDLE
          })
      }.padding({ left: 20, right: 20, top: 14, bottom: 32 })
    }
    .width('100%')
    .backgroundColor(this.cardBg)
    .opacity(this.cardOpacity)
    .translate({ y: this.cardOffset })
  }

  // 手动输入
  @Builder
  ManualView() {
    Column({ space: 20 }) {
      Column({ space: 6 }) {
        Text('未能自动识别').fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.textColor)
        Text('输入食物名称，从本地库查找营养数据').fontSize(13).fontColor(this.secondColor)
      }.alignItems(HorizontalAlign.Center)

      TextInput({ placeholder: '番茄炒蛋、米饭、苹果…', text: this.manualInput })
        .fontSize(16).fontColor(this.textColor)
        .placeholderColor(this.secondColor)
        .caretColor(AppColors.BRAND_COLOR)
        .backgroundColor(this.isDark ? AppColors.DARK_GRAY_100 : AppColors.GRAY_50)
        .borderRadius(14).height(52)
        .padding({ left: 16, right: 16 })
        .width('100%')
        .border({ width: 1.5, color: AppColors.BRAND_COLOR })
        .onChange((v: string) => { this.manualInput = v })

      Button('查询并继续')
        .width('100%').height(52)
        .backgroundColor(AppColors.BRAND_COLOR).fontColor(Color.White)
        .fontWeight(FontWeight.Bold).borderRadius(26)
        .shadow({ radius: 10, color: AppColors.BRAND_COLOR + '44', offsetX: 0, offsetY: 4 })
        .onClick(() => this.confirmManual())

      Button('返回重新拍照')
        .width('100%').height(48)
        .backgroundColor('transparent').fontColor(this.secondColor)
        .onClick(() => {
          this.capturedUri  = ''
          this.manualInput  = ''
          this.scanState    = ScanState.IDLE
        })
    }
    .width('100%').padding({ left: 24, right: 24, top: 28, bottom: 24 })
    .alignItems(HorizontalAlign.Center)
  }

  // ── 内联导航栏（RESULT / MANUAL 状态专用，参与布局流） ────────────────

  @Builder
  InlineNav(title: string) {
    Row() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20)
          .fontColor([this.textColor])
      }
      .width(44).height(44).justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.recognitionResult = null
        this.capturedUri = ''
        this.scanState = ScanState.IDLE
      })

      Text(title)
        .fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.textColor)
        .layoutWeight(1).textAlign(TextAlign.Center)

      Blank().width(44)
    }
    .width('100%')
    .height(this.safeTopVp + 48)
    .padding({ top: this.safeTopVp, left: 4, right: 4 })
    .backgroundColor(this.cardBg)
    .border({ width: { bottom: 0.5 }, color: this.divColor })
  }

  // ── build ─────────────────────────────────────────────────────────────
  //
  // 布局结构：
  //   Stack（全屏）
  //     ├─ Column（主流）
  //     │    ├─ [RESULT/MANUAL] InlineNav — 参与布局，把内容推到导航栏下方
  //     │    ├─ CameraFrame  height='52%'（RESULT 时 height=0，收起）
  //     │    └─ 内容区       layoutWeight(1)
  //     ├─ [IDLE/PREVIEW/RECOGNIZING] FloatNav — 悬浮在 CameraFrame 顶部
  //     └─ ToastView

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {

        // RESULT / MANUAL 使用内联导航栏，内容从导航栏正下方开始，零遮挡
        if (this.scanState === ScanState.RESULT || this.scanState === ScanState.MANUAL) {
          this.InlineNav('热量识别')
        }

        // 取景框区（RESULT 时 height=0 自动收起）
        this.CameraFrame()

        // 内容区，随状态切换，用 layoutWeight(1) 填满剩余空间
        if (this.scanState === ScanState.IDLE) {
          Column({ space: 16 }) {
            Button() {
              Row({ space: 10 }) {
                SymbolGlyph($r('sys.symbol.camera')).fontSize(22).fontColor([Color.White])
                Text('拍照识别').fontSize(17).fontColor(Color.White).fontWeight(FontWeight.Bold)
              }
            }
            .width('88%').height(56)
            .backgroundColor(AppColors.BRAND_COLOR).borderRadius(28)
            .shadow({ radius: 16, color: AppColors.BRAND_COLOR + '55', offsetX: 0, offsetY: 6 })
            .onClick(() => { void this.launchCamera() })

            Button() {
              Row({ space: 10 }) {
                SymbolGlyph($r('sys.symbol.picture_fill')).fontSize(20).fontColor([AppColors.BRAND_COLOR])
                Text('从相册选图').fontSize(15).fontColor(AppColors.BRAND_COLOR).fontWeight(FontWeight.Medium)
              }
            }
            .width('88%').height(50)
            .backgroundColor(this.isDark ? AppColors.DARK_GRAY_100 : AppColors.BRAND_COLOR_LIGHT)
            .borderRadius(25)
            .onClick(() => { void this.launchPicker() })
          }
          .layoutWeight(1).alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)

        } else if (this.scanState === ScanState.PREVIEW) {
          Row({ space: 14 }) {
            Button('从相册重选')
              .layoutWeight(1).height(52)
              .backgroundColor(this.cardBg).fontColor(this.textColor)
              .borderRadius(26).border({ width: 1, color: this.divColor })
              .onClick(() => { void this.launchPicker() })

            Button('开始识别')
              .layoutWeight(2).height(52)
              .backgroundColor(AppColors.BRAND_COLOR).fontColor(Color.White)
              .fontWeight(FontWeight.Bold).borderRadius(26)
              .shadow({ radius: 10, color: AppColors.BRAND_COLOR + '44', offsetX: 0, offsetY: 4 })
              .onClick(() => { void this.startRecognition() })
          }
          .layoutWeight(1).padding({ left: 20, right: 20 }).alignItems(VerticalAlign.Center)

        } else if (this.scanState === ScanState.RECOGNIZING) {
          Column({ space: 10 }) {
            LoadingProgress().width(38).height(38).color(AppColors.BRAND_COLOR)
            Text('AI 正在识别食物…').fontSize(14).fontColor(this.secondColor)
            Text('通常需要 2 – 5 秒').fontSize(12)
              .fontColor(this.isDark ? AppColors.DARK_GRAY_400 : AppColors.GRAY_400)
          }
          .layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)

        } else if (this.scanState === ScanState.RESULT) {
          Scroll() {
            this.ResultCard()
          }
          .layoutWeight(1).scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)

        } else {
          Scroll() {
            this.ManualView()
          }
          .layoutWeight(1).scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
        }
      }
      .width('100%').height('100%')
      .backgroundColor(this.bgColor)
      .opacity(this.pageOpacity)

      // 悬浮导航栏仅用于拍摄类状态（取景框可见时），RESULT/MANUAL 已改用内联导航栏
      if (this.scanState !== ScanState.RESULT && this.scanState !== ScanState.MANUAL) {
        this.FloatNav()
      }

      ToastView({ message: this.toastMsg, visible: this.toastVisible })
    }
    // 全屏沉浸：TOP 让取景框延伸至状态栏下方，BOTTOM 填满底部手势区
    .width('100%').height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
