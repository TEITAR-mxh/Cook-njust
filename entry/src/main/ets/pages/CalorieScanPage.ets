/**
 * 热量识别页面
 * 流程：拍照/选图 → 识别 → 结果展示+份量调整 → 记录到饮食数据库
 * 相机方案：系统 cameraPicker（无需自定义 XComponent 取景框）
 */
import { cameraPicker } from '@kit.CameraKit'
import { camera } from '@kit.CameraKit'
import { common, abilityAccessCtrl, Permissions } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI'
import { AppColors, ThemeManager } from '../constants/AppColors'
import { getSystemSafeTopVp } from '../util/StatusBarInset'
import { FoodRecognitionService, FoodRecognitionResult } from '../service/FoodRecognitionService'
import { PhotoPickerHelper } from '../utils/PhotoPickerHelper'
import { CalorieCalculator, NutrientData } from '../utils/CalorieCalculator'
import { DietDatabaseHelper, DietRecord } from '../data/DietDatabaseHelper'
import { ToastView } from '../components/ToastView'

/** 页面状态枚举 */
const enum ScanState {
  /** 初始态：展示拍照/选图按钮 */
  IDLE = 0,
  /** 已获取图片，等待用户确认 */
  PREVIEW = 1,
  /** 识别进行中 */
  RECOGNIZING = 2,
  /** 展示识别结果 */
  RESULT = 3,
  /** 识别失败，手动输入 */
  MANUAL = 4,
}

const MEAL_TYPES: string[] = ['早餐', '午餐', '晚餐', '加餐']
/** 推荐每日总热量（千卡） */
const DAILY_GOAL_KCAL = 2000

@Entry
@Component
struct CalorieScanPage {
  @State private safeTopVp: number = 48
  @State private scanState: ScanState = ScanState.IDLE
  @State private capturedUri: string = ''
  @State private recognitionResult: FoodRecognitionResult | null = null

  /** 用户调整的份量（步长 0.5） */
  @State private quantity: number = 1.0
  /** 当前所选餐次 */
  @State private selectedMealType: string = '加餐'
  /** 手动输入的食物名称 */
  @State private manualFoodName: string = ''

  // ── 结果展示用扁平 @State（避免 ArkUI proxy 对 nullable @State getter 返回 undefined） ──
  @State private resultFoodName: string = ''
  @State private resultSourceLabel: string = '手动'
  @State private resultCalPer100: number = 0
  @State private resultProteinPer100: number = 0
  @State private resultFatPer100: number = 0
  @State private resultCarbsPer100: number = 0
  @State private resultServingWeight: number = 200

  @State private toastMessage: string = ''
  @State private toastVisible: boolean = false
  @State private saving: boolean = false

  // ── 主题适配 ─────────────────────────────────────────────────────────
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

  private onThemeChange(): void { this.applyTheme() }

  private applyTheme(): void {
    this.bgColor       = ThemeManager.getBackgroundColor(this.storedThemeMode)
    this.cardBg        = ThemeManager.getCardBackgroundColor(this.storedThemeMode)
    this.textColor     = ThemeManager.getTextColor(this.storedThemeMode)
    this.secondaryColor = ThemeManager.getSecondaryTextColor(this.storedThemeMode)
    this.dividerColor  = ThemeManager.getBorderColor(this.storedThemeMode)
  }

  // ── 生命周期 ──────────────────────────────────────────────────────────

  aboutToAppear(): void {
    this.applyTheme()
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (host) {
      void getSystemSafeTopVp(host).then((vp: number) => { this.safeTopVp = vp })
    }
  }

  // ── 权限与相机 ────────────────────────────────────────────────────────

  private async requestCameraPermission(): Promise<boolean> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (!host) return false
    try {
      const atManager = abilityAccessCtrl.createAtManager()
      const permissions: Permissions[] = ['ohos.permission.CAMERA']
      const result = await atManager.requestPermissionsFromUser(host, permissions)
      return result.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED
    } catch (e) {
      console.error('[CalorieScan] 权限请求失败:', JSON.stringify(e))
      return false
    }
  }

  private async launchCamera(): Promise<void> {
    const granted = await this.requestCameraPermission()
    if (!granted) {
      this.showPermissionDeniedDialog()
      return
    }
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (!host) return
    try {
      const profile: cameraPicker.PickerProfile = {
        cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK,
      }
      const result = await cameraPicker.pick(
        host,
        [cameraPicker.PickerMediaType.PHOTO],
        profile,
      )
      if (result.resultCode === 0 && result.resultUri.length > 0) {
        this.capturedUri = result.resultUri
        this.scanState = ScanState.PREVIEW
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
      this.scanState = ScanState.PREVIEW
    }
  }

  // ── 识别逻辑 ──────────────────────────────────────────────────────────

  private async startRecognition(): Promise<void> {
    if (this.capturedUri.length === 0) return
    this.scanState = ScanState.RECOGNIZING

    try {
      const result = await FoodRecognitionService.recognize(this.capturedUri)
      this.recognitionResult = result
      this.quantity = 1.0

      if (result.identified) {
        this.setDisplayResult(result)
        this.scanState = ScanState.RESULT
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

  // ── 手动食物查询（MANUAL 状态） ───────────────────────────────────────

  private applyManualFood(): void {
    const name = this.manualFoodName.trim()
    if (name.length === 0) { this.showToast('请输入食物名称'); return }
    const nutrient = CalorieCalculator.lookup(name)
      ?? CalorieCalculator.fuzzyMatch([name])?.data
      ?? { calories: 100, protein: 5, fat: 3, carbs: 15, servingWeight: 200 } as NutrientData
    this.recognitionResult = {
      identified: true,
      foodName: name,
      nutrient,
      source: 'manual',
      rawLabels: [],
    }
    this.setDisplayResult(this.recognitionResult)
    this.quantity = 1.0
    this.scanState = ScanState.RESULT
  }

  // ── 保存记录 ──────────────────────────────────────────────────────────

  private async saveRecord(): Promise<void> {
    if (this.saving || this.recognitionResult === null) return
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (!host) return

    this.saving = true
    try {
      const r = this.recognitionResult
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
      this.showToast(`✅ 已记录：${r.foodName} ${calc.totalCalories} 千卡`)
      // 延迟后重置到初始态
      setTimeout(() => {
        this.scanState = ScanState.IDLE
        this.capturedUri = ''
        this.recognitionResult = null
      }, 1500)
    } catch (e) {
      console.error('[CalorieScan] 保存失败:', JSON.stringify(e))
      this.showToast('保存失败，请重试')
    } finally {
      this.saving = false
    }
  }

  // ── Toast & Dialog ────────────────────────────────────────────────────

  private showToast(msg: string): void {
    this.toastMessage = msg
    this.toastVisible = true
    setTimeout(() => { this.toastVisible = false }, 2500)
  }

  private showPermissionDeniedDialog(): void {
    AlertDialog.show({
      title: '需要相机权限',
      message: '热量识别功能需要使用相机拍摄食物照片。\n请在系统设置 → 应用管理 → 您吃了么 → 权限 中开启相机权限。',
      primaryButton: {
        value: '去设置',
        action: () => {
          // 引导用户跳转系统权限设置（HarmonyOS 不支持直接跳转，只能提示）
          this.showToast('请在系统设置中手动开启相机权限')
        },
      },
      secondaryButton: {
        value: '退出',
        action: () => {
          const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
          if (ctx) ctx.terminateSelf()
          else this.getUIContext().getRouter().back()
        },
      },
      autoCancel: false,
    })
  }

  // ── 结果展示辅助 ─────────────────────────────────────────────────────

  /** 将识别结果写入扁平 @State，避免 ArkUI proxy 在 ResultView 中返回 undefined */
  private setDisplayResult(r: FoodRecognitionResult): void {
    this.resultFoodName      = r.foodName
    this.resultSourceLabel   = r.source === 'cloud' ? '云端' : r.source === 'local' ? '本地库' : '手动'
    this.resultCalPer100     = r.nutrient.calories
    this.resultProteinPer100 = r.nutrient.protein
    this.resultFatPer100     = r.nutrient.fat
    this.resultCarbsPer100   = r.nutrient.carbs
    this.resultServingWeight = r.nutrient.servingWeight
  }

  /** 由扁平 @State 还原 NutrientData（仅用于 CalorieCalculator，全为基本类型，proxy 安全） */
  private get flatNutrient(): NutrientData {
    return {
      calories:      this.resultCalPer100,
      protein:       this.resultProteinPer100,
      fat:           this.resultFatPer100,
      carbs:         this.resultCarbsPer100,
      servingWeight: this.resultServingWeight,
    }
  }

  private get currentCalories(): number {
    if (this.resultFoodName.length === 0) return 0
    return CalorieCalculator.calcByQuantity(this.flatNutrient, this.quantity).totalCalories
  }

  // ── UI Builders ───────────────────────────────────────────────────────

  @Builder
  NavBar() {
    Row() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20).fontColor([this.textColor])
      }
      .width(44).height(44).justifyContent(FlexAlign.Center)
      .onClick(() => this.getUIContext().getRouter().back())

      Text('热量识别')
        .fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.textColor)
        .layoutWeight(1).textAlign(TextAlign.Center)

      Blank().width(44)
    }
    .width('100%')
    .height(this.safeTopVp + 48)
    .padding({ top: this.safeTopVp, left: 4, right: 4 })
    .backgroundColor(this.cardBg)
    .border({ width: { bottom: 0.5 }, color: this.dividerColor })
  }

  /** 初始态：拍照 / 从相册选择 */
  @Builder
  IdleView() {
    Column({ space: 24 }) {
      Column({ space: 12 }) {
        Text('📸').fontSize(72)
        Text('拍摄或选择食物照片').fontSize(16).fontColor(this.secondaryColor)
        Text('支持识别常见中国家常菜、食材和零食').fontSize(13).fontColor(this.dividerColor)
      }.width('100%').padding({ top: 60, bottom: 40 })

      Button() {
        Row({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.camera')).fontSize(20).fontColor([Color.White])
          Text('拍照识别').fontSize(16).fontColor(Color.White).fontWeight(FontWeight.Bold)
        }
      }
      .width('80%').height(52).backgroundColor(AppColors.BRAND_COLOR).borderRadius(16)
      .onClick(() => { void this.launchCamera() })

      Button() {
        Row({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.picture_fill')).fontSize(20).fontColor([AppColors.BRAND_COLOR])
          Text('从相册选图').fontSize(16).fontColor(AppColors.BRAND_COLOR).fontWeight(FontWeight.Medium)
        }
      }
      .width('80%').height(52)
      .backgroundColor(this.cardBg)
      .borderRadius(16)
      .border({ width: 1.5, color: AppColors.BRAND_COLOR })
      .onClick(() => { void this.launchPhotoPicker() })
    }
    .width('100%').alignItems(HorizontalAlign.Center)
  }

  /** 预览态：展示照片，确认/重拍 */
  @Builder
  PreviewView() {
    Column({ space: 20 }) {
      Image(this.capturedUri)
        .width('100%').aspectRatio(1)
        .objectFit(ImageFit.Cover)
        .borderRadius(20)
        .margin({ left: 20, right: 20 })

      Row({ space: 16 }) {
        Button('重拍')
          .layoutWeight(1).height(48)
          .backgroundColor(this.cardBg)
          .fontColor(this.textColor).borderRadius(14)
          .border({ width: 1, color: this.dividerColor })
          .onClick(() => {
            this.capturedUri = ''
            this.scanState = ScanState.IDLE
          })

        Button('开始识别')
          .layoutWeight(1).height(48)
          .backgroundColor(AppColors.BRAND_COLOR)
          .fontColor(Color.White).fontWeight(FontWeight.Bold).borderRadius(14)
          .onClick(() => { void this.startRecognition() })
      }.width('100%').padding({ left: 20, right: 20 })
    }.width('100%').padding({ top: 24 })
  }

  /** 识别中：加载动画 */
  @Builder
  RecognizingView() {
    Column({ space: 20 }) {
      if (this.capturedUri.length > 0) {
        Image(this.capturedUri)
          .width('100%').aspectRatio(1)
          .objectFit(ImageFit.Cover)
          .borderRadius(20)
          .opacity(0.5)
          .margin({ left: 20, right: 20 })
      }
      LoadingProgress().width(48).height(48).color(AppColors.BRAND_COLOR)
      Text('正在识别食物…').fontSize(15).fontColor(this.secondaryColor)
    }.width('100%').padding({ top: 24 }).alignItems(HorizontalAlign.Center)
  }

  /** 营养素行（复用 Builder） */
  @Builder
  NutrientRow(label: string, value: string, unit: string, color: string) {
    Row() {
      Text(label).fontSize(14).fontColor(this.secondaryColor).layoutWeight(1)
      Text(value).fontSize(16).fontColor(color).fontWeight(FontWeight.Bold)
      Text(' ' + unit).fontSize(12).fontColor(this.secondaryColor)
    }.width('100%').padding({ top: 8, bottom: 8 })
  }

  /** 份量选择器 */
  @Builder
  QuantitySelector() {
    Row({ space: 20 }) {
      Text('份量').fontSize(14).fontColor(this.secondaryColor).layoutWeight(1)

      Row({ space: 16 }) {
        Button('-')
          .width(36).height(36).borderRadius(18)
          .backgroundColor(this.dividerColor).fontColor(this.textColor).fontSize(20)
          .onClick(() => { if (this.quantity > 0.5) this.quantity = Math.round((this.quantity - 0.5) * 10) / 10 })

        Text(`${this.quantity} 份`)
          .fontSize(16).fontColor(this.textColor).fontWeight(FontWeight.Bold)
          .width(60).textAlign(TextAlign.Center)

        Button('+')
          .width(36).height(36).borderRadius(18)
          .backgroundColor(AppColors.BRAND_COLOR_LIGHT).fontColor(AppColors.BRAND_COLOR).fontSize(20)
          .onClick(() => { if (this.quantity < 10) this.quantity = Math.round((this.quantity + 0.5) * 10) / 10 })
      }
    }.width('100%').padding({ top: 8, bottom: 8 })
  }

  /** 餐次选择 */
  @Builder
  MealTypeSelector() {
    Row({ space: 8 }) {
      ForEach(MEAL_TYPES, (meal: string) => {
        Text(meal)
          .fontSize(13)
          .fontColor(this.selectedMealType === meal ? Color.White : this.secondaryColor)
          .padding({ left: 14, right: 14, top: 6, bottom: 6 })
          .backgroundColor(this.selectedMealType === meal ? AppColors.BRAND_COLOR : this.cardBg)
          .borderRadius(20)
          .border({ width: 1, color: this.selectedMealType === meal ? AppColors.BRAND_COLOR : this.dividerColor })
          .onClick(() => { this.selectedMealType = meal })
      }, (meal: string) => meal)
    }.width('100%')
  }

  /** 结果态：展示营养信息 + 份量调整 + 保存 */
  @Builder
  ResultView() {
    Column({ space: 0 }) {
      // 图片小缩略图
      if (this.capturedUri.length > 0) {
        Image(this.capturedUri)
          .width('100%').height(180)
          .objectFit(ImageFit.Cover)
          .borderRadius({ topLeft: 16, topRight: 16 })
      }

      Column({ space: 0 }) {
        // 食物名称 + 来源标签
        Row({ space: 8 }) {
          Text(this.resultFoodName)
            .fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.textColor).layoutWeight(1)
          Text(this.resultSourceLabel)
            .fontSize(11).fontColor(AppColors.BRAND_COLOR)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor(AppColors.BRAND_COLOR_LIGHT).borderRadius(10)
        }.padding({ left: 20, right: 20, top: 16, bottom: 8 })

        // 热量大字
        Row({ space: 4 }) {
          Text(`${this.currentCalories}`).fontSize(40).fontColor(AppColors.BRAND_COLOR).fontWeight(FontWeight.Bold)
          Text('千卡').fontSize(16).fontColor(this.secondaryColor).margin({ top: 16 })
        }.padding({ left: 20, bottom: 8 })

        Divider().color(this.dividerColor).margin({ left: 20, right: 20 })

        // 三大营养素
        Column() {
          this.NutrientRow(
            '蛋白质',
            `${CalorieCalculator.calcByQuantity(this.flatNutrient, this.quantity).totalProtein}`,
            'g', '#22C55E'
          )
          Divider().color(this.dividerColor)
          this.NutrientRow(
            '脂肪',
            `${CalorieCalculator.calcByQuantity(this.flatNutrient, this.quantity).totalFat}`,
            'g', '#F59E0B'
          )
          Divider().color(this.dividerColor)
          this.NutrientRow(
            '碳水化合物',
            `${CalorieCalculator.calcByQuantity(this.flatNutrient, this.quantity).totalCarbs}`,
            'g', '#3B82F6'
          )
        }.padding({ left: 20, right: 20, top: 8, bottom: 8 })

        Divider().color(this.dividerColor).margin({ left: 20, right: 20 })

        // 份量选择器
        Column() {
          this.QuantitySelector()
        }.padding({ left: 20, right: 20, top: 4, bottom: 4 })

        Divider().color(this.dividerColor).margin({ left: 20, right: 20 })

        // 餐次选择
        Column({ space: 8 }) {
          Text('选择餐次').fontSize(13).fontColor(this.secondaryColor).alignSelf(ItemAlign.Start)
          this.MealTypeSelector()
        }.padding({ left: 20, right: 20, top: 12, bottom: 12 })
      }
      .backgroundColor(this.cardBg).borderRadius(16).margin({ left: 16, right: 16 })

      // 操作按钮区
      Row({ space: 12 }) {
        Button('重新识别')
          .layoutWeight(1).height(52)
          .backgroundColor(this.cardBg).fontColor(this.textColor).borderRadius(16)
          .border({ width: 1, color: this.dividerColor })
          .onClick(() => {
            this.recognitionResult = null
            this.scanState = ScanState.IDLE
            this.capturedUri = ''
          })

        Button(this.saving ? '保存中…' : '记录到今日饮食')
          .layoutWeight(2).height(52)
          .backgroundColor(AppColors.BRAND_COLOR).fontColor(Color.White)
          .fontWeight(FontWeight.Bold).borderRadius(16)
          .enabled(!this.saving)
          .onClick(() => { void this.saveRecord() })
      }.width('100%').padding({ left: 16, right: 16, top: 20 })
    }.width('100%')
  }

  /** 手动输入态 */
  @Builder
  ManualView() {
    Column({ space: 20 }) {
      Text('未能自动识别').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.textColor)
      Text('请输入食物名称，我们将从本地数据库查找营养数据').fontSize(13).fontColor(this.secondaryColor).textAlign(TextAlign.Center)

      TextInput({ placeholder: '例如：番茄炒蛋、米饭、苹果…', text: this.manualFoodName })
        .fontSize(16).fontColor(this.textColor).placeholderColor(this.secondaryColor)
        .caretColor(AppColors.BRAND_COLOR).backgroundColor(this.cardBg)
        .borderRadius(12).padding({ left: 16, right: 16, top: 14, bottom: 14 })
        .width('100%')
        .onChange((v: string) => { this.manualFoodName = v })

      Button('查询并继续')
        .width('80%').height(52)
        .backgroundColor(AppColors.BRAND_COLOR).fontColor(Color.White)
        .fontWeight(FontWeight.Bold).borderRadius(16)
        .onClick(() => this.applyManualFood())

      Button('返回重新拍照')
        .width('80%').height(48)
        .backgroundColor(this.cardBg).fontColor(this.textColor).borderRadius(16)
        .border({ width: 1, color: this.dividerColor })
        .onClick(() => {
          this.capturedUri = ''
          this.manualFoodName = ''
          this.scanState = ScanState.IDLE
        })
    }
    .width('100%').padding({ left: 20, right: 20, top: 40 }).alignItems(HorizontalAlign.Center)
  }

  // ── build ─────────────────────────────────────────────────────────────

  build() {
    Stack() {
      Column() {
        this.NavBar()

        Scroll() {
          Column() {
            if (this.scanState === ScanState.IDLE) {
              this.IdleView()
            } else if (this.scanState === ScanState.PREVIEW) {
              this.PreviewView()
            } else if (this.scanState === ScanState.RECOGNIZING) {
              this.RecognizingView()
            } else if (this.scanState === ScanState.RESULT && this.recognitionResult !== null) {
              this.ResultView()
            } else {
              this.ManualView()
            }
          }.width('100%').padding({ bottom: 40 })
        }
        .layoutWeight(1).scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
      }
      .width('100%').height('100%').backgroundColor(this.bgColor)

      ToastView({ message: this.toastMessage, visible: this.toastVisible })
    }
    .width('100%').height('100%')
  }
}
