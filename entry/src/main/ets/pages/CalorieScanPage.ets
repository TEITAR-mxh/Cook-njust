/**
 * 热量识别页面 — Premium UI
 * 沉浸式图片预览 + 玻璃态结果卡片 + 扫描动画
 *
 * !! ArkUI proxy 限制：所有 @Builder 内只读 @State 基本类型，零 getter / 方法调用 !!
 */
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

const enum ScanState { IDLE = 0, PREVIEW = 1, RECOGNIZING = 2, RESULT = 3, MANUAL = 4 }

const MEAL_TYPES: string[] = ['早餐', '午餐', '晚餐', '加餐']
const MEAL_EMOJIS: string[] = ['🌅', '☀️', '🌙', '🍵']

@Entry
@Component
struct CalorieScanPage {

  // ── 页面基础 ────────────────────────────────────────────────────────────
  @State private safeTopVp: number = 48
  @State private scanState: ScanState = ScanState.IDLE
  @State private capturedUri: string = ''
  @State private recognitionResult: FoodRecognitionResult | null = null

  // ── 动画状态（@State 基本类型）──────────────────────────────────────────
  @State private pageOpacity: number = 0
  @State private pulseScale: number = 1.0
  @State private pulseOpacity: number = 0.6
  @State private resultCardOpacity: number = 0
  @State private resultCardOffset: number = 60
  @State private saveBtnScale: number = 1.0
  @State private qtyMinusScale: number = 1.0
  @State private qtyPlusScale: number = 1.0

  // ── 结果展示 @State 基本类型（proxy-safe）──────────────────────────────
  @State private resultFoodName: string = ''
  @State private resultSourceLabel: string = '手动'
  @State private displayCalories: number = 0
  @State private displayProtein: number = 0
  @State private displayFat: number = 0
  @State private displayCarbs: number = 0
  // 每 100g 原始数据（不在 Builder 中使用）
  private resultCalPer100: number = 0
  private resultProteinPer100: number = 0
  private resultFatPer100: number = 0
  private resultCarbsPer100: number = 0
  private resultServingWeight: number = 200

  // ── 交互 ────────────────────────────────────────────────────────────────
  @Watch('onQuantityChange')
  @State private quantity: number = 1.0
  @State private selectedMealType: string = '加餐'
  @State private manualFoodName: string = ''
  @State private saving: boolean = false

  // ── Toast ───────────────────────────────────────────────────────────────
  @State private toastMessage: string = ''
  @State private toastVisible: boolean = false

  // ── 主题 ────────────────────────────────────────────────────────────────
  @StorageProp('isSystemDarkMode')
  @Watch('onThemeChange')
  private isSystemDark: boolean = false

  @StorageProp('currentThemeMode')
  @Watch('onThemeChange')
  private storedThemeMode: string = '系统默认'

  @State private bgColor: string = AppColors.BG_COLOR
  @State private cardBg: string = AppColors.CARD_BG
  @State private textColor: string = AppColors.GRAY_900
  @State private secondaryColor: string = AppColors.GRAY_500
  @State private dividerColor: string = AppColors.GRAY_100
  @State private isDark: boolean = false

  // ── 生命周期 ─────────────────────────────────────────────────────────────

  aboutToAppear(): void {
    this.isDark = this.calcIsDark()
    this.applyTheme()
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (host) {
      void getSystemSafeTopVp(host).then((vp: number) => { this.safeTopVp = vp })
    }
    animateTo({ duration: 380, curve: Curve.EaseOut }, () => { this.pageOpacity = 1 })
    this.loopPulse()
  }

  // ── 主题 ─────────────────────────────────────────────────────────────────

  private onThemeChange(): void {
    this.isDark = this.calcIsDark()
    this.applyTheme()
  }

  private calcIsDark(): boolean {
    if (this.storedThemeMode === '深色模式') return true
    if (this.storedThemeMode === '浅色模式') return false
    return this.isSystemDark
  }

  private applyTheme(): void {
    this.bgColor      = ThemeManager.getBackgroundColor(this.storedThemeMode)
    this.cardBg       = ThemeManager.getCardBackgroundColor(this.storedThemeMode)
    this.textColor    = ThemeManager.getTextColor(this.storedThemeMode)
    this.secondaryColor = ThemeManager.getSecondaryTextColor(this.storedThemeMode)
    this.dividerColor = ThemeManager.getBorderColor(this.storedThemeMode)
  }

  // ── 扫描脉冲动画 ─────────────────────────────────────────────────────────

  private loopPulse(): void {
    animateTo({ duration: 900, curve: Curve.EaseOut }, () => {
      this.pulseScale   = 1.18
      this.pulseOpacity = 0.0
    })
    setTimeout(() => {
      this.pulseScale   = 1.0
      this.pulseOpacity = 0.55
      this.loopPulse()
    }, 940)
  }

  // ── 相机 & 相册 ───────────────────────────────────────────────────────────

  private async requestCameraPermission(): Promise<boolean> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (!host) return false
    try {
      const mgr = abilityAccessCtrl.createAtManager()
      const perms: Permissions[] = ['ohos.permission.CAMERA']
      const res = await mgr.requestPermissionsFromUser(host, perms)
      return res.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED
    } catch (e) {
      console.error('[CalorieScan] 权限请求失败:', JSON.stringify(e))
      return false
    }
  }

  private async launchCamera(): Promise<void> {
    if (!(await this.requestCameraPermission())) {
      this.showPermissionDeniedDialog()
      return
    }
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (!host) return
    try {
      const profile: cameraPicker.PickerProfile = { cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK }
      const res = await cameraPicker.pick(host, [cameraPicker.PickerMediaType.PHOTO], profile)
      if (res.resultCode === 0 && res.resultUri.length > 0) {
        this.capturedUri = res.resultUri
        this.scanState   = ScanState.PREVIEW
      }
    } catch (e) {
      console.error('[CalorieScan] 调起相机失败:', JSON.stringify(e))
      this.showToast('相机启动失败，请重试')
    }
  }

  private async launchPhotoPicker(): Promise<void> {
    const uri = await PhotoPickerHelper.selectSinglePhoto()
    if (uri) {
      this.capturedUri = uri
      this.scanState   = ScanState.PREVIEW
    }
  }

  // ── 识别 ─────────────────────────────────────────────────────────────────

  private async startRecognition(): Promise<void> {
    if (this.capturedUri.length === 0) return
    this.scanState = ScanState.RECOGNIZING
    try {
      const result = await FoodRecognitionService.recognize(this.capturedUri)
      this.recognitionResult = result
      this.quantity = 1.0
      if (result.identified) {
        this.setDisplayResult(result)
        this.showResultCard()
      } else {
        this.scanState = ScanState.MANUAL
        this.showToast('未能自动识别，请手动输入食物名称')
      }
    } catch (e) {
      console.error('[CalorieScan] 识别异常:', JSON.stringify(e))
      this.scanState = ScanState.MANUAL
      this.showToast('识别服务暂时不可用，请手动输入')
    }
  }

  private showResultCard(): void {
    this.resultCardOpacity = 0
    this.resultCardOffset  = 60
    this.scanState = ScanState.RESULT
    animateTo({ duration: 420, curve: Curve.EaseOut }, () => {
      this.resultCardOpacity = 1
      this.resultCardOffset  = 0
    })
  }

  // ── 手动输入 ─────────────────────────────────────────────────────────────

  private applyManualFood(): void {
    const name = this.manualFoodName.trim()
    if (name.length === 0) { this.showToast('请输入食物名称'); return }
    const nutrient = CalorieCalculator.lookup(name)
      ?? CalorieCalculator.fuzzyMatch([name])?.data
      ?? { calories: 100, protein: 5, fat: 3, carbs: 15, servingWeight: 200 } as NutrientData
    const r: FoodRecognitionResult = { identified: true, foodName: name, nutrient, source: 'manual', rawLabels: [] }
    this.recognitionResult = r
    this.setDisplayResult(r)
    this.quantity = 1.0
    this.showResultCard()
  }

  // ── 保存 ─────────────────────────────────────────────────────────────────

  private async saveRecord(): Promise<void> {
    if (this.saving || this.recognitionResult === null) return
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (!host) return
    this.saving = true
    animateTo({ duration: 100, curve: Curve.EaseIn }, () => { this.saveBtnScale = 0.95 })
    setTimeout(() => { animateTo({ duration: 150, curve: Curve.EaseOut }, () => { this.saveBtnScale = 1.0 }) }, 110)
    try {
      const r    = this.recognitionResult
      const calc = CalorieCalculator.calcByQuantity(r.nutrient, this.quantity)
      const record: DietRecord = {
        date:      DietDatabaseHelper.todayDateStr(),
        mealType:  this.selectedMealType,
        foodName:  r.foodName,
        quantity:  this.quantity,
        unit:      '份',
        calories:  calc.totalCalories,
        protein:   calc.totalProtein,
        fat:       calc.totalFat,
        carbs:     calc.totalCarbs,
        imageUri:  this.capturedUri,
        timestamp: Date.now(),
      }
      await DietDatabaseHelper.getInstance().insertRecord(host, record)
      this.showToast(`✅ 已记录：${r.foodName}  ${calc.totalCalories} 千卡`)
      setTimeout(() => {
        this.scanState  = ScanState.IDLE
        this.capturedUri = ''
        this.recognitionResult = null
      }, 1600)
    } catch (e) {
      console.error('[CalorieScan] 保存失败:', JSON.stringify(e))
      this.showToast('保存失败，请重试')
    } finally {
      this.saving = false
    }
  }

  // ── 结果展示辅助（非 Builder 上下文，proxy 安全）─────────────────────────

  private setDisplayResult(r: FoodRecognitionResult): void {
    this.resultFoodName      = r.foodName
    this.resultSourceLabel   = r.source === 'cloud' ? '云端' : r.source === 'local' ? '本地库' : '手动'
    this.resultCalPer100     = r.nutrient.calories
    this.resultProteinPer100 = r.nutrient.protein
    this.resultFatPer100     = r.nutrient.fat
    this.resultCarbsPer100   = r.nutrient.carbs
    this.resultServingWeight = r.nutrient.servingWeight
    this.recalcDisplay()
  }

  private recalcDisplay(): void {
    const f = this.resultServingWeight * this.quantity / 100.0
    this.displayCalories = Math.round(this.resultCalPer100 * f)
    this.displayProtein  = Math.round(this.resultProteinPer100 * f * 10) / 10
    this.displayFat      = Math.round(this.resultFatPer100     * f * 10) / 10
    this.displayCarbs    = Math.round(this.resultCarbsPer100   * f * 10) / 10
  }

  private onQuantityChange(): void { this.recalcDisplay() }

  // ── Toast & Dialog ────────────────────────────────────────────────────────

  private showToast(msg: string): void {
    this.toastMessage = msg
    this.toastVisible = true
    setTimeout(() => { this.toastVisible = false }, 2500)
  }

  private showPermissionDeniedDialog(): void {
    AlertDialog.show({
      title: '需要相机权限',
      message: '热量识别功能需要使用相机拍摄食物照片。\n请在系统设置 → 应用管理 → 您吃了么 → 权限 中开启相机权限。',
      primaryButton: { value: '知道了', action: () => {} },
      secondaryButton: {
        value: '退出功能',
        action: () => {
          const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
          if (ctx) ctx.terminateSelf()
          else this.getUIContext().getRouter().back()
        },
      },
      autoCancel: false,
    })
  }

  // ════════════════════════════════════════════════════════════════════════
  // UI Builders
  // 重要：所有 @Builder 只读 @State 基本类型，零 getter，零方法调用
  // ════════════════════════════════════════════════════════════════════════

  /** 悬浮导航栏（毛玻璃）*/
  @Builder
  FloatNav() {
    Row() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20).fontColor([this.scanState === ScanState.IDLE ? '#FFFFFF' : this.textColor])
      }
      .width(44).height(44).justifyContent(FlexAlign.Center)
      .onClick(() => this.getUIContext().getRouter().back())

      Text('热量识别')
        .fontSize(16).fontWeight(FontWeight.Medium)
        .fontColor(this.scanState === ScanState.IDLE ? '#FFFFFF' : this.textColor)
        .layoutWeight(1).textAlign(TextAlign.Center)

      if (this.scanState === ScanState.IDLE) {
        Row() {
          SymbolGlyph($r('sys.symbol.picture_fill'))
            .fontSize(18).fontColor(['#FFFFFF'])
        }
        .width(44).height(44).justifyContent(FlexAlign.Center)
        .onClick(() => { void this.launchPhotoPicker() })
      } else {
        Blank().width(44)
      }
    }
    .width('100%')
    .height(this.safeTopVp + 48)
    .padding({ top: this.safeTopVp, left: 4, right: 4 })
    .backgroundBlurStyle(this.scanState === ScanState.IDLE ? BlurStyle.NONE : BlurStyle.Thin)
    .backgroundColor(this.scanState === ScanState.IDLE ? '#00000000' : this.cardBg + 'CC')
  }

  /** 图片/占位取景框 */
  @Builder
  CameraFrame() {
    Stack({ alignContent: Alignment.Center }) {

      // ── 背景：已有图片时显示图片，否则深色占位 ──
      if (this.capturedUri.length > 0) {
        Image(this.capturedUri)
          .width('100%').height('100%')
          .objectFit(ImageFit.Cover)
      } else {
        Column()
          .width('100%').height('100%')
          .backgroundColor(this.isDark ? '#0D0D0D' : '#1A1A2E')
      }

      // ── 识别中：脉冲动画叠加 ──
      if (this.scanState === ScanState.RECOGNIZING) {
        Column({ space: 0 }) {
          // 暗化蒙层
          Column()
            .width('100%').height('100%')
            .backgroundColor('#66000000')
            .position({ x: 0, y: 0 })

          // 脉冲圆环
          Circle()
            .width(120).height(120)
            .fill('transparent')
            .strokeWidth(2)
            .stroke(AppColors.BRAND_COLOR)
            .opacity(this.pulseOpacity)
            .scale({ x: this.pulseScale, y: this.pulseScale })

          Text('正在识别…')
            .fontSize(15).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
            .margin({ top: 16 })
            .textShadow({ radius: 6, color: '#80000000', offsetX: 0, offsetY: 2 })
        }
        .width('100%').height('100%')
        .justifyContent(FlexAlign.Center)
        .position({ x: 0, y: 0 })
      }

      // ── 空态：引导文案 ──
      if (this.scanState === ScanState.IDLE) {
        Column({ space: 14 }) {
          Text('📸').fontSize(64)
          Text('对准食物，轻点拍摄')
            .fontSize(16).fontColor('#FFFFFFCC').fontWeight(FontWeight.Medium)
          Text('支持识别常见中国家常菜、食材和零食')
            .fontSize(12).fontColor('#FFFFFF80')
        }
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
      }

      // ── 取景框角标（四个角的 L 形线，仅 IDLE/PREVIEW 态显示）──
      if (this.scanState === ScanState.IDLE || this.scanState === ScanState.PREVIEW) {
        Row() {
          // 左上
          Column() {
            Row().width(28).height(3).backgroundColor('#FFFFFFCC').borderRadius(2)
            Row().width(3).height(28).backgroundColor('#FFFFFFCC').borderRadius(2).margin({ top: -3 })
          }.alignItems(HorizontalAlign.Start)

          Blank()

          // 右上
          Column() {
            Row().width(28).height(3).backgroundColor('#FFFFFFCC').borderRadius(2)
            Row().width(3).height(28).backgroundColor('#FFFFFFCC').borderRadius(2)
              .margin({ top: -3 }).alignSelf(ItemAlign.End)
          }.alignItems(HorizontalAlign.End)
        }
        .width('100%').padding({ left: 24, right: 24 })
        .position({ x: 0, y: 24 })

        Row() {
          // 左下
          Column() {
            Row().width(3).height(28).backgroundColor('#FFFFFFCC').borderRadius(2)
            Row().width(28).height(3).backgroundColor('#FFFFFFCC').borderRadius(2).margin({ top: -3 })
          }.alignItems(HorizontalAlign.Start)

          Blank()

          // 右下
          Column() {
            Row().width(3).height(28).backgroundColor('#FFFFFFCC').borderRadius(2)
              .alignSelf(ItemAlign.End)
            Row().width(28).height(3).backgroundColor('#FFFFFFCC').borderRadius(2)
              .margin({ top: -3 }).alignSelf(ItemAlign.End)
          }.alignItems(HorizontalAlign.End)
        }
        .width('100%').padding({ left: 24, right: 24 })
        .position({ x: 0, y: undefined })
        .margin({ top: '100%' })
        .translate({ y: -80 })
      }

      // ── PREVIEW：右上角"重新拍摄"按钮 ──
      if (this.scanState === ScanState.PREVIEW) {
        Row({ space: 5 }) {
          SymbolGlyph($r('sys.symbol.camera')).fontSize(13).fontColor(['#FFFFFF'])
          Text('重新拍摄').fontSize(12).fontColor('#FFFFFF')
        }
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor('#66000000')
        .borderRadius(20)
        .position({ x: undefined, y: 12 })
        .margin({ right: 12 })
        .onClick(() => {
          this.capturedUri = ''
          this.scanState   = ScanState.IDLE
        })
        .alignSelf(ItemAlign.End)
      }

    }
    .width('100%')
    .height(this.scanState === ScanState.RESULT ? 220 : '52%')
    .borderRadius({ bottomLeft: 28, bottomRight: 28 })
    .clip(true)
  }

  /** 初始态底部操作区 */
  @Builder
  IdleActions() {
    Column({ space: 16 }) {
      Button() {
        Row({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.camera')).fontSize(22).fontColor([Color.White])
          Text('拍照识别').fontSize(17).fontColor(Color.White).fontWeight(FontWeight.Bold)
        }
      }
      .width('88%').height(56)
      .backgroundColor(AppColors.BRAND_COLOR)
      .borderRadius(28)
      .shadow({ radius: 16, color: AppColors.BRAND_COLOR + '55', offsetX: 0, offsetY: 6 })
      .onClick(() => { void this.launchCamera() })

      Button() {
        Row({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.picture_fill')).fontSize(20).fontColor([AppColors.BRAND_COLOR])
          Text('从相册选图').fontSize(15).fontColor(AppColors.BRAND_COLOR).fontWeight(FontWeight.Medium)
        }
      }
      .width('88%').height(48)
      .backgroundColor(this.isDark ? '#1A1A1A' : AppColors.BRAND_COLOR_LIGHT)
      .borderRadius(24)
      .onClick(() => { void this.launchPhotoPicker() })
    }
    .width('100%').alignItems(HorizontalAlign.Center)
    .padding({ top: 28, bottom: 16 })
  }

  /** PREVIEW 态底部操作区 */
  @Builder
  PreviewActions() {
    Row({ space: 14 }) {
      Button('从相册重选')
        .layoutWeight(1).height(52)
        .backgroundColor(this.cardBg).fontColor(this.textColor).borderRadius(26)
        .border({ width: 1, color: this.dividerColor })
        .onClick(() => { void this.launchPhotoPicker() })

      Button('开始识别')
        .layoutWeight(2).height(52)
        .backgroundColor(AppColors.BRAND_COLOR).fontColor(Color.White)
        .fontWeight(FontWeight.Bold).borderRadius(26)
        .shadow({ radius: 12, color: AppColors.BRAND_COLOR + '44', offsetX: 0, offsetY: 4 })
        .onClick(() => { void this.startRecognition() })
    }
    .width('100%').padding({ left: 20, right: 20, top: 24, bottom: 16 })
  }

  /** 营养素指示行（带色点）*/
  @Builder
  NutrientDotRow(dot: string, label: string, value: string, unit: string) {
    Row({ space: 10 }) {
      Row()
        .width(10).height(10).borderRadius(5)
        .backgroundColor(dot)
        .flexShrink(0)
      Text(label)
        .fontSize(13).fontColor(this.secondaryColor)
        .layoutWeight(1)
      Text(value)
        .fontSize(16).fontColor(this.textColor).fontWeight(FontWeight.Bold)
      Text(' ' + unit)
        .fontSize(12).fontColor(this.secondaryColor)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
  }

  /** 份量选择器（胶囊式）*/
  @Builder
  QuantityPill() {
    Row({ space: 0 }) {
      Text('份量').fontSize(14).fontColor(this.secondaryColor).layoutWeight(1)

      Row() {
        // 减号
        Text('－')
          .fontSize(18).fontColor(AppColors.BRAND_COLOR)
          .width(40).height(40).textAlign(TextAlign.Center)
          .scale({ x: this.qtyMinusScale, y: this.qtyMinusScale })
          .onClick(() => {
            if (this.quantity > 0.5) {
              animateTo({ duration: 80, curve: Curve.EaseIn }, () => { this.qtyMinusScale = 0.88 })
              setTimeout(() => {
                animateTo({ duration: 100, curve: Curve.EaseOut }, () => { this.qtyMinusScale = 1.0 })
              }, 85)
              this.quantity = Math.round((this.quantity - 0.5) * 10) / 10
            }
          })

        Text(`${this.quantity}`)
          .fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          .width(44).textAlign(TextAlign.Center)

        // 加号
        Text('＋')
          .fontSize(18).fontColor(AppColors.BRAND_COLOR)
          .width(40).height(40).textAlign(TextAlign.Center)
          .scale({ x: this.qtyPlusScale, y: this.qtyPlusScale })
          .onClick(() => {
            if (this.quantity < 10) {
              animateTo({ duration: 80, curve: Curve.EaseIn }, () => { this.qtyPlusScale = 0.88 })
              setTimeout(() => {
                animateTo({ duration: 100, curve: Curve.EaseOut }, () => { this.qtyPlusScale = 1.0 })
              }, 85)
              this.quantity = Math.round((this.quantity + 0.5) * 10) / 10
            }
          })
      }
      .height(40)
      .backgroundColor(this.isDark ? AppColors.DARK_GRAY_100 : AppColors.GRAY_100)
      .borderRadius(20)
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
  }

  /** 餐次选择（图标+文字胶囊）*/
  @Builder
  MealTypeRow() {
    Row({ space: 8 }) {
      ForEach(MEAL_TYPES, (meal: string, idx: number) => {
        Column({ space: 2 }) {
          Text(MEAL_EMOJIS[idx]).fontSize(16)
          Text(meal)
            .fontSize(11)
            .fontColor(this.selectedMealType === meal ? AppColors.BRAND_COLOR : this.secondaryColor)
            .fontWeight(this.selectedMealType === meal ? FontWeight.Bold : FontWeight.Normal)
        }
        .width(56).height(52).justifyContent(FlexAlign.Center)
        .backgroundColor(
          this.selectedMealType === meal
            ? (this.isDark ? '#2A1215' : AppColors.BRAND_COLOR_LIGHT)
            : 'transparent'
        )
        .borderRadius(12)
        .border({
          width: this.selectedMealType === meal ? 1.5 : 0,
          color: AppColors.BRAND_COLOR,
        })
        .onClick(() => { this.selectedMealType = meal })
      }, (meal: string) => meal)
    }
    .width('100%')
  }

  /** 结果卡片（玻璃态）*/
  @Builder
  ResultCard() {
    Column({ space: 0 }) {

      // 食物名 + 来源标签
      Row({ space: 10 }) {
        Text(this.resultFoodName)
          .fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.resultSourceLabel)
          .fontSize(11).fontColor(AppColors.BRAND_COLOR)
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .backgroundColor(this.isDark ? '#2A1215' : AppColors.BRAND_COLOR_LIGHT)
          .borderRadius(12)
      }
      .width('100%').padding({ left: 20, right: 20, top: 18, bottom: 4 })

      // 热量大字
      Row({ space: 4 }) {
        Text(`${this.displayCalories}`)
          .fontSize(48).fontWeight(FontWeight.Bold).fontColor(AppColors.BRAND_COLOR)
          .fontStyle(FontStyle.Normal)
        Column({ space: 2 }) {
          Text('千卡').fontSize(14).fontColor(this.secondaryColor)
          Text('本份').fontSize(11).fontColor(this.isDark ? AppColors.DARK_GRAY_400 : AppColors.GRAY_400)
        }.margin({ top: 18 }).alignItems(HorizontalAlign.Start)
      }
      .padding({ left: 20, bottom: 12 })

      // 分隔线
      Divider().color(this.dividerColor).margin({ left: 20, right: 20 })

      // 三大营养素
      Column({ space: 0 }) {
        this.NutrientDotRow('#22C55E', '蛋白质', `${this.displayProtein}`, 'g')
        Divider().color(this.dividerColor)
        this.NutrientDotRow('#F59E0B', '脂肪',   `${this.displayFat}`,     'g')
        Divider().color(this.dividerColor)
        this.NutrientDotRow('#3B82F6', '碳水化合物', `${this.displayCarbs}`, 'g')
      }.padding({ left: 20, right: 20, top: 4, bottom: 4 })

      Divider().color(this.dividerColor).margin({ left: 20, right: 20 })

      // 份量
      Column() {
        this.QuantityPill()
      }.padding({ left: 20, right: 20, top: 2, bottom: 2 })

      Divider().color(this.dividerColor).margin({ left: 20, right: 20 })

      // 餐次
      Column({ space: 8 }) {
        Text('选择餐次').fontSize(12).fontColor(this.secondaryColor).alignSelf(ItemAlign.Start)
        this.MealTypeRow()
      }.padding({ left: 20, right: 20, top: 12, bottom: 14 })

      Divider().color(this.dividerColor).margin({ left: 20, right: 20 })

      // 操作按钮行
      Row({ space: 12 }) {
        Button('重新识别')
          .layoutWeight(1).height(50)
          .backgroundColor(this.isDark ? AppColors.DARK_GRAY_100 : AppColors.GRAY_100)
          .fontColor(this.textColor).fontSize(14).borderRadius(25)
          .onClick(() => {
            this.recognitionResult = null
            this.capturedUri       = ''
            this.scanState         = ScanState.IDLE
          })

        Button(this.saving ? '保存中…' : '✓ 记录今日饮食')
          .layoutWeight(2).height(50)
          .backgroundColor(AppColors.BRAND_COLOR)
          .fontColor(Color.White).fontWeight(FontWeight.Bold).fontSize(15)
          .borderRadius(25)
          .scale({ x: this.saveBtnScale, y: this.saveBtnScale })
          .shadow({ radius: 14, color: AppColors.BRAND_COLOR + '44', offsetX: 0, offsetY: 5 })
          .enabled(!this.saving)
          .onClick(() => { void this.saveRecord() })
      }
      .width('100%').padding({ left: 20, right: 20, top: 14, bottom: 20 })
    }
    .width('100%')
    .backgroundColor(this.cardBg)
    .borderRadius({ topLeft: 24, topRight: 24 })
    .shadow({ radius: 20, color: this.isDark ? '#00000080' : '#00000018', offsetX: 0, offsetY: -4 })
    .opacity(this.resultCardOpacity)
    .translate({ y: this.resultCardOffset })
  }

  /** 手动输入态 */
  @Builder
  ManualView() {
    Column({ space: 20 }) {
      Column({ space: 6 }) {
        Text('未能自动识别').fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.textColor)
        Text('请输入食物名称').fontSize(14).fontColor(this.secondaryColor)
      }.alignItems(HorizontalAlign.Center)

      TextInput({ placeholder: '番茄炒蛋、米饭、苹果…', text: this.manualFoodName })
        .fontSize(16).fontColor(this.textColor)
        .placeholderColor(this.secondaryColor)
        .caretColor(AppColors.BRAND_COLOR)
        .backgroundColor(this.isDark ? AppColors.DARK_GRAY_100 : AppColors.GRAY_50)
        .borderRadius(14)
        .padding({ left: 18, right: 18, top: 16, bottom: 16 })
        .width('100%')
        .border({ width: 1.5, color: AppColors.BRAND_COLOR })
        .onChange((v: string) => { this.manualFoodName = v })

      Button('查询并继续')
        .width('88%').height(52)
        .backgroundColor(AppColors.BRAND_COLOR).fontColor(Color.White)
        .fontWeight(FontWeight.Bold).borderRadius(26)
        .shadow({ radius: 12, color: AppColors.BRAND_COLOR + '44', offsetX: 0, offsetY: 4 })
        .onClick(() => this.applyManualFood())

      Button('返回重新拍照')
        .width('88%').height(46)
        .backgroundColor('transparent').fontColor(this.secondaryColor).borderRadius(23)
        .onClick(() => {
          this.capturedUri      = ''
          this.manualFoodName   = ''
          this.scanState        = ScanState.IDLE
        })
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 32, bottom: 24 })
    .alignItems(HorizontalAlign.Center)
  }

  // ── build ──────────────────────────────────────────────────────────────────

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        // ── 图片 / 取景框区 ──
        this.CameraFrame()

        // ── 底部内容区 ──
        if (this.scanState === ScanState.IDLE) {
          this.IdleActions()
        } else if (this.scanState === ScanState.PREVIEW) {
          this.PreviewActions()
        } else if (this.scanState === ScanState.RECOGNIZING) {
          Column({ space: 12 }) {
            LoadingProgress().width(40).height(40).color(AppColors.BRAND_COLOR)
            Text('AI 正在识别食物…').fontSize(14).fontColor(this.secondaryColor)
            Text('通常需要 2 – 5 秒').fontSize(12).fontColor(this.isDark ? AppColors.DARK_GRAY_400 : AppColors.GRAY_400)
          }
          .width('100%').layoutWeight(1)
          .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
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

      // ── 悬浮导航栏 ──
      this.FloatNav()

      // ── Toast ──
      ToastView({ message: this.toastMessage, visible: this.toastVisible })
    }
    .width('100%').height('100%')
  }
}
