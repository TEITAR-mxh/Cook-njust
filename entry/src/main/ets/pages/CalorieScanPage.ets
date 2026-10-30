import { camera } from '@kit.CameraKit'
import { common, abilityAccessCtrl, Permissions } from '@kit.AbilityKit'
import { AppColors, ThemeManager } from '../constants/AppColors'
import { getSystemSafeTopVp } from '../util/StatusBarInset'
import { FoodRecognitionService, FoodRecognitionResult } from '../service/FoodRecognitionService'
import { PhotoPickerHelper } from '../utils/PhotoPickerHelper'
import { CalorieCalculator, NutrientData } from '../utils/CalorieCalculator'
import { DietDatabaseHelper, DietRecord } from '../data/DietDatabaseHelper'
import { ToastView } from '../components/ToastView'
import { CameraPreview, CameraPreviewController } from '../components/CameraPreview'
import { calcNutriScore, getNutriScoreColors } from '../service/NutritionCalculator'
import { CalorieTargetService } from '../service/CalorieTargetService'
import { CookPreferences } from '../store/CookPreferences'
import { RecipeRepository } from '../data/RecipeRepository'
import type { RecipeNutrition } from '../model/recipe'

// 取景框专用常量，不随主题变化
const CAMERA_BG     = AppColors.DARK_BG_COLOR   // '#121212'
const CORNER_COLOR  = '#CCFFFFFF'               // L形标线白色 80%透明
const SCAN_OVERLAY  = '#5F000000'               // 扫描蒙层

const enum ScanState { IDLE = 0, PREVIEW = 1, RECOGNIZING = 2, RESULT = 3, MANUAL = 4, NOT_FOOD = 5, UNSURE = 6 }

const MEAL_TYPES:  string[] = ['早餐', '午餐', '晚餐', '加餐']
const MEAL_EMOJIS: string[] = ['🌅', '☀️', '🌙', '🍵']

// 闪光模式循环顺序（与 CameraPreview 默认 CLOSE 一致）
const FLASH_MODES: camera.FlashMode[] = [
  camera.FlashMode.FLASH_MODE_CLOSE,
  camera.FlashMode.FLASH_MODE_AUTO,
  camera.FlashMode.FLASH_MODE_OPEN,
]
const FLASH_LABELS: string[] = ['关', '自动', '开']

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

  // 非菜品提示动画
  @State private notFoodOpacity: number = 0
  @State private notFoodScale:   number = 0.94
  @State private notFoodTilt:    number = -6

  // 识别不确定提示动画（识别到名称，但营养数据对不上）
  @State private unsureOpacity:    number = 0
  @State private unsureScale:      number = 0.92
  @State private unsureOffset:     number = 14
  @State private unsureRingAngle:  number = 0
  @State private unsureBadgeScale: number = 1.0
  @State private unsureName:       string = ''

  // 页面淡入
  @State private pageOpacity: number = 0

  // 结果展示 — 全部 @State 基本类型，proxy 安全
  @State private resultName:    string = ''
  @State private resultTag:     string = '手动'
  @State private isEstimated:   boolean = false
  @State private nutriScore:       string = ''
  @State private nutriScoreBg:     string = '#9CA3AF'
  @State private nutriScoreText:   string = '#FFFFFF'
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

  // 相机预览控制器 + 闪光状态（IDLE 实时取景用）
  private previewController: CameraPreviewController = new CameraPreviewController()
  @State private flashIndex: number = 0
  // 相机权限授予后才挂载 CameraPreview，避免「初始化早于授权」竞态导致黑屏
  @State private cameraGranted: boolean = false
  // 实际预览缓冲的竖屏宽高比（由 CameraPreview 上报），用于设置 XComponent 比例避免拉伸
  @State private previewAspect: number = 3 / 4

  private pulseActive: boolean = false
  /** 识别被用户取消标记（异步识别返回后据此丢弃结果） */
  private recognitionAborted: boolean = false

  // ── 生命周期 ──────────────────────────────────────────────────────────

  aboutToAppear(): void {
    this.isDark = this.resolveDark()
    this.syncTheme()
    this.navBg = '#00000000'
    void this.ensureCameraPermission()
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

  /** 系统返回手势/键：RESULT 态先确认，避免静默丢弃识别结果 */
  onBackPress(): boolean {
    if (this.scanState === ScanState.RESULT) {
      this.confirmDiscardResult()
      return true
    }
    if (this.scanState === ScanState.NOT_FOOD || this.scanState === ScanState.UNSURE) {
      this.resetToIdle()
      return true
    }
    return false
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
    // 全屏取景/预览/识别态：悬浮导航栏透明(IDLE)或深色半透明，白字保证可读
    this.navBg = this.scanState === ScanState.IDLE ? '#00000000' : '#99000000'
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

  /** 页面进入时请求相机权限（IDLE 实时取景需要） */
  private async ensureCameraPermission(): Promise<void> {
    if (await this.requestCamera()) {
      this.cameraGranted = true
    } else {
      this.toast('未获得相机权限，可从相册选图')
    }
  }

  /** CameraPreview 拍照成功回调：进入预览确认态 */
  private handlePhotoCaptured(uri: string): void {
    if (uri.length === 0) return
    this.capturedUri = uri
    this.scanState   = ScanState.PREVIEW
  }

  /** CameraPreview 初始化/运行错误回调 */
  private handleCameraError(msg: string): void {
    console.error('[CalorieScan] camera error:', msg)
    this.toast(msg)
  }

  /** 快门按下：触发实时取景拍照 */
  private onShutterTap(): void {
    void this.previewController.takePhoto().then((uri: string | null) => {
      if (uri) this.handlePhotoCaptured(uri)
    })
  }

  /** 循环切换闪光：关 → 自动 → 开 */
  private cycleFlash(): void {
    this.flashIndex = (this.flashIndex + 1) % FLASH_MODES.length
    this.previewController.setFlashMode(FLASH_MODES[this.flashIndex])
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
    this.recognitionAborted = false

    const r = await this.runRecognitionWithTimeout(this.capturedUri)
    // 用户在等待期间点了取消 → 丢弃结果
    if (this.recognitionAborted) return

    if (r === 'timeout') {
      this.scanState = ScanState.PREVIEW
      this.toast('识别超时，请重试')
      return
    }
    if (r === 'error') {
      this.scanState = ScanState.PREVIEW
      this.toast('识别失败，请重试')
      return
    }

    this.recognitionResult = r
    this.quantity = 1.0
    if (!r.identified) {
      // 非菜品 / 没认出来：不生成任何记录，给出友好反馈
      this.enterNotFood()
      return
    }

    // 营养是占位估算时，先尝试用菜谱库中同名菜的食材聚合数据替换
    if (r.isEstimated) {
      const resolved = this.resolveNutrientFromRepository(r.foodName)
      if (resolved !== null) {
        const upgraded: FoodRecognitionResult = {
          identified: true,
          foodName: r.foodName,
          nutrient: resolved,
          source: r.source,
          rawLabels: r.rawLabels,
          isEstimated: false,
        }
        if (r.confidence !== undefined) {
          upgraded.confidence = r.confidence
        }
        this.recognitionResult = upgraded
        // 食材聚合值仍是估算口径，结果卡保留「估算」标注
        this.applyResult(upgraded, true)
        this.animateCardIn()
        return
      }
      // 名称对不上可靠营养数据：不估算热量，避免把错数字记进饮食
      this.enterUnsure(r)
      return
    }

    this.applyResult(r)
    this.animateCardIn()
  }

  /**
   * 菜谱库兜底：识别/手动的菜名能精确命中菜谱时，
   * 用食材聚合营养（整份）换算成每 100g 数据，替代 150 kcal 占位估算。
   */
  private resolveNutrientFromRepository(name: string): NutrientData | null {
    const repo = RecipeRepository.getInstance()
    if (repo.getCount() === 0) return null
    const recipe = repo.getByName(name)
    if (recipe === null || recipe.nutrition === undefined) return null
    const total = recipe.nutrition.totalWeight ?? 0
    if (total <= 0 || recipe.nutrition.calories <= 0) return null
    const f = 100 / total
    const data: NutrientData = {
      calories: Math.round(recipe.nutrition.calories * f),
      protein: Math.round(recipe.nutrition.protein * f * 10) / 10,
      fat: Math.round(recipe.nutrition.fat * f * 10) / 10,
      carbs: Math.round(recipe.nutrition.carbs * f * 10) / 10,
      servingWeight: Math.round(total),
    }
    return data
  }

  /** 识别到名称但营养数据不可靠：不算热量，用「没认准」动画说明原因 */
  private enterUnsure(r: FoodRecognitionResult): void {
    this.recognitionResult = r
    this.unsureName = r.foodName.trim()
    this.scanState = ScanState.UNSURE
    this.unsureOpacity = 0
    this.unsureScale = 0.92
    this.unsureOffset = 14
    this.unsureRingAngle = 0
    this.unsureBadgeScale = 1.0
    this.getUIContext().animateTo({ duration: 360, curve: Curve.Friction }, () => {
      this.unsureOpacity = 1
      this.unsureScale = 1
      this.unsureOffset = 0
    })
    setTimeout(() => {
      if (this.scanState !== ScanState.UNSURE) return
      // 虚线环持续旋转 + “?” 徽章呼吸，表达「还在确认」的语气
      this.getUIContext().animateTo({ duration: 4200, curve: Curve.Linear, iterations: -1 }, () => {
        this.unsureRingAngle = 360
      })
      this.getUIContext().animateTo({
        duration: 1000,
        curve: Curve.EaseInOut,
        iterations: -1,
        playMode: PlayMode.Alternate
      }, () => {
        this.unsureBadgeScale = 1.14
      })
    }, 240)
  }

  /** 未识别到食物：进入「对不起，没认出来」提示态 */
  private enterNotFood(): void {
    this.scanState = ScanState.NOT_FOOD
    this.notFoodOpacity = 0
    this.notFoodScale = 0.94
    this.notFoodTilt = -6
    this.getUIContext().animateTo({ duration: 320, curve: Curve.EaseOut }, () => {
      this.notFoodOpacity = 1
      this.notFoodScale = 1
    })
    // 图标左右轻摆两下，表达“抱歉”的语气
    setTimeout(() => {
      this.getUIContext().animateTo({
        duration: 420,
        curve: Curve.EaseInOut,
        iterations: 4,
        playMode: PlayMode.Alternate
      }, () => { this.notFoodTilt = 6 })
    }, 220)
  }

  /** 识别 + 15 秒超时（避免云端最长 40s 无反馈） */
  private async runRecognitionWithTimeout(uri: string): Promise<FoodRecognitionResult | 'timeout' | 'error'> {
    const timeoutMs = 15000
    try {
      return await Promise.race<FoodRecognitionResult | 'timeout'>([
        FoodRecognitionService.recognize(uri),
        new Promise<'timeout'>((resolve) => { setTimeout(() => resolve('timeout'), timeoutMs) })
      ])
    } catch (e) {
      console.error('[CalorieScan] recognition error:', JSON.stringify(e))
      return 'error'
    }
  }

  /** 取消进行中的识别，回到预览态可重试 */
  private cancelRecognition(): void {
    this.recognitionAborted = true
    this.scanState = ScanState.PREVIEW
    this.toast('已取消识别')
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
    let n: NutrientData | null = CalorieCalculator.lookup(name)
    if (n === null) {
      const fuzzy = CalorieCalculator.fuzzyMatch([name])
      if (fuzzy !== null && fuzzy.data !== undefined) {
        n = fuzzy.data
      }
    }
    let approximated = false
    if (n === null) {
      n = this.resolveNutrientFromRepository(name)
      approximated = n !== null
    }
    // 查不到可靠营养就不硬编数字，避免把错的热量记进饮食
    if (n === null) {
      this.toast(`营养库暂未收录「${name}」，换个常见菜名试试`)
      return
    }
    const r: FoodRecognitionResult = { identified: true, foodName: name, nutrient: n, source: 'manual', rawLabels: [], isEstimated: false }
    this.recognitionResult = r
    this.applyResult(r, approximated)
    this.quantity = 1.0
    this.animateCardIn()
  }

  // ── 保存 ─────────────────────────────────────────────────────────────

  private async save(): Promise<void> {
    // 未识别（非菜品）或结果异常时一律不写库
    if (this.saving || this.recognitionResult === null || !this.recognitionResult.identified) return
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
      // 结合个性化目标提示今日剩余热量
      let goalSuffix: string = ''
      try {
        const profile = await CookPreferences.getDietProfile(host)
        const targets = CalorieTargetService.calcTargets(profile)
        const today = await DietDatabaseHelper.getInstance().queryTodayTotal(host)
        const remaining: number = Math.round(targets.calories - today.totalCalories)
        goalSuffix = remaining >= 0 ? ` · 今日还剩 ${remaining} 千卡` : ` · 今日超出 ${-remaining} 千卡`
      } catch (e) {
        console.error('[CalorieScan] goal hint error:', JSON.stringify(e))
      }
      this.toast(`✅ 已记录：${r.foodName}  ${calc.totalCalories} 千卡${goalSuffix}`)
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

  private applyResult(r: FoodRecognitionResult, estimated: boolean = false): void {
    this.resultName  = r.foodName
    this.resultTag   = this.sourceToTag(r.source)
    this.isEstimated = estimated || r.isEstimated === true
    this.rawCal      = r.nutrient.calories
    this.rawPro      = r.nutrient.protein
    this.rawFat      = r.nutrient.fat
    this.rawCarbs    = r.nutrient.carbs
    this.rawServing  = r.nutrient.servingWeight
    this.recalc()

    // 计算 Nutri-Score：nutrient 数据是每 100g 口径，故 totalWeight 固定 100。
    // 识别结果缺少纤维/钠实测值（置 0），评级偏乐观，UI 需明确标注。
    const recipeNutri: RecipeNutrition = {
      calories: r.nutrient.calories,
      protein: r.nutrient.protein,
      fat: r.nutrient.fat,
      carbs: r.nutrient.carbs,
      fiber: 0,
      sodium: 0,
      totalWeight: 100,
    }
    const score = calcNutriScore(recipeNutri, [])
    const colors = getNutriScoreColors(score)
    this.nutriScore = score
    this.nutriScoreBg = colors.bg
    this.nutriScoreText = colors.text
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

  /** 丢弃当前结果/取景，回到相机（IDLE） */
  private resetToIdle(): void {
    this.recognitionResult = null
    this.capturedUri = ''
    this.scanState = ScanState.IDLE
  }

  /** RESULT 态返回：识别结果尚未保存，二次确认后丢弃 */
  private confirmDiscardResult(): void {
    this.getUIContext().showAlertDialog({
      title: '丢弃识别结果',
      message: '识别结果尚未保存，返回后将丢弃该结果。确定继续吗？',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '丢弃',
        fontColor: AppColors.BRAND_COLOR,
        action: () => { this.resetToIdle() }
      },
      autoCancel: true
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
          .fontColor(['#FFFFFF'])
      }
      .width(44).height(44).justifyContent(FlexAlign.Center)
      .onClick(() => {
        // 非菜品 / 没认准提示态：先回到取景，而不是直接退出页面
        if (this.scanState === ScanState.NOT_FOOD || this.scanState === ScanState.UNSURE) {
          this.resetToIdle()
        } else {
          this.getUIContext().getRouter().back()
        }
      })

      Text('热量识别')
        .fontSize(16).fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .layoutWeight(1).textAlign(TextAlign.Center)

      Blank().width(44)
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
    Stack({ alignContent: Alignment.Top }) {
      // 深色底板，不跟随主题（相机未就绪/失败时兜底）
      Column().width('100%').height('100%').backgroundColor(CAMERA_BG)

      // 顶部渐隐遮罩：保证导航/提示在明亮场景下依旧可读
      if (this.scanState === ScanState.IDLE || this.scanState === ScanState.PREVIEW) {
        Column()
          .width('100%')
          .height(this.safeTopVp + 96)
          .linearGradient({
            direction: GradientDirection.Bottom,
            colors: [['#99000000', 0], ['#00000000', 1]]
          })
      }

      // IDLE：应用内实时取景（权限授予后才挂载，避免「初始化早于授权」竞态黑屏）
      if (this.scanState === ScanState.IDLE && this.cameraGranted) {
        CameraPreview({
          controller: this.previewController,
          onPhotoCaptured: (uri: string) => { this.handlePhotoCaptured(uri) },
          onCameraError: (msg: string) => { this.handleCameraError(msg) },
          onPreviewAspect: (a: number) => { this.previewAspect = a },
        })
          // 全屏 cover-crop：按真实预览比例撑满屏高，宽度溢出由外层 clip 裁切。
          // 比例必须跟随相机缓冲（而非固定 3:4），否则 SURFACE 会拉伸画面导致变形。
          .height('100%')
          .aspectRatio(this.previewAspect)
      }

      // 已选图片（PREVIEW / RECOGNIZING / 提示态用）：保持原图横宽比，不拉伸裁切
      if (this.capturedUri.length > 0 && this.scanState !== ScanState.IDLE) {
        Image(this.capturedUri)
          .width('100%').height('100%')
          .objectFit(ImageFit.Contain)
          // 没认准时虚化照片，把注意力让给提示卡
          .blur(this.scanState === ScanState.UNSURE ? 16 : 0)
      }

      // 识别中：蒙层 + 脉冲圆环 + 取消
      if (this.scanState === ScanState.RECOGNIZING) {
        Stack() {
          Column().width('100%').height('100%').backgroundColor(SCAN_OVERLAY)
          Column({ space: 16 }) {
            Column()
              .width(110).height(110)
              .borderRadius(55)
              .border({ width: 2.5, color: AppColors.BRAND_COLOR })
              .opacity(this.pulseAlpha)
              .scale({ x: this.pulseScale, y: this.pulseScale })
            Column({ space: 6 }) {
              Text('正在识别…')
                .fontSize(15).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
              Text('本地约几秒，云端较慢时最长 15 秒')
                .fontSize(12).fontColor('#80FFFFFF')
            }
            Text('取消')
              .fontSize(13).fontColor('#FFFFFF')
              .padding({ left: 24, right: 24, top: 8, bottom: 8 })
              .backgroundColor('#60000000')
              .borderRadius(20)
              .onClick(() => { this.cancelRecognition() })
          }
          .width('100%').height('100%')
          .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        }.width('100%').height('100%')
      }

      // IDLE：居中取景引导框（填充画面空白，并为构图提供参照）
      if (this.scanState === ScanState.IDLE) {
        this.ScanGuide()
      }

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

      // IDLE：右上角闪光开关
      if (this.scanState === ScanState.IDLE) {
        Row({ space: 4 }) {
          Text('⚡').fontSize(14)
          Text(FLASH_LABELS[this.flashIndex]).fontSize(12).fontColor('#FFFFFF')
        }
        .padding({ left: 12, right: 12, top: 7, bottom: 7 })
        .backgroundColor('#60000000').borderRadius(20)
        .onClick(() => { this.cycleFlash() })
        .position({ right: 16, top: this.safeTopVp + 56 })
      }

    }
    .width('100%')
    .height('100%')
    .clip(true) // 裁切超出屏宽的预览，实现全屏取景
  }

  // IDLE 居中取景引导框：填充中部空白 + 构图参考 + 一句话提示
  @Builder
  ScanGuide() {
    Column() {
      Column().layoutWeight(4)

      Stack() {
        // 半透明底 + 圆角描边
        Column()
          .width('100%').height('100%')
          .backgroundColor('#14000000')
          .borderRadius(24)
          .border({ width: 1.5, color: '#52FFFFFF' })

        // 四角 L 形标线
        Column() {
          Row().width(24).height(3).backgroundColor(CORNER_COLOR).borderRadius(1.5)
          Row().width(3).height(20).backgroundColor(CORNER_COLOR).borderRadius(1.5).margin({ top: -1 })
        }
        .alignItems(HorizontalAlign.Start)
        .position({ top: 16, left: 16 })

        Column() {
          Row().width(24).height(3).backgroundColor(CORNER_COLOR).borderRadius(1.5)
          Row().width(3).height(20).backgroundColor(CORNER_COLOR).borderRadius(1.5)
            .margin({ top: -1 }).alignSelf(ItemAlign.End)
        }
        .alignItems(HorizontalAlign.End)
        .position({ top: 16, right: 16 })

        Column() {
          Row().width(3).height(20).backgroundColor(CORNER_COLOR).borderRadius(1.5)
          Row().width(24).height(3).backgroundColor(CORNER_COLOR).borderRadius(1.5).margin({ top: -1 })
        }
        .alignItems(HorizontalAlign.Start)
        .position({ bottom: 16, left: 16 })

        Column() {
          Row().width(3).height(20).backgroundColor(CORNER_COLOR).borderRadius(1.5).alignSelf(ItemAlign.End)
          Row().width(24).height(3).backgroundColor(CORNER_COLOR).borderRadius(1.5)
            .margin({ top: -1 }).alignSelf(ItemAlign.End)
        }
        .alignItems(HorizontalAlign.End)
        .position({ bottom: 16, right: 16 })

        // 中央提示
        Column({ space: 8 }) {
          Text('🍽️').fontSize(36)
          Text('将食物放入框内')
            .fontSize(15).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
          Text('拍全整盘 · 光线充足，识别更准')
            .fontSize(12).fontColor('#B3FFFFFF')
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
      .width('82%')
      .aspectRatio(1.08)

      Column().layoutWeight(5)
    }
    .width('100%').height('100%')
  }

  // 营养素单元格（等宽三列，色块 + 数值 + 标签）
  @Builder
  MacroCell(label: string, value: string, accentLight: string, accentDark: string,
            bgLight: string, bgDark: string) {
    Column({ space: 3 }) {
      Text(value)
        .fontSize(17).fontWeight(FontWeight.Bold)
        .fontColor(this.isDark ? accentDark : accentLight)
      Text(label)
        .fontSize(11).fontColor(this.secondColor)
    }
    .layoutWeight(1)
    .padding({ top: 12, bottom: 12 })
    .backgroundColor(this.isDark ? bgDark : bgLight)
    .borderRadius(14)
    .alignItems(HorizontalAlign.Center)
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

  // 餐次选择（emoji + 文字双行，整体居中）
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
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
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

        if (this.isEstimated) {
          Text('估算')
            .fontSize(11).fontColor(this.isDark ? '#FBBF24' : '#B45309').fontWeight(FontWeight.Medium)
            .padding({ left: 9, right: 9, top: 4, bottom: 4 })
            .backgroundColor(this.isDark ? '#F59E0B22' : '#FEF3C7')
            .borderRadius(12)
        }

        if (this.nutriScore.length > 0) {
          Text(`Nutri-Score ${this.nutriScore}*`)
            .fontSize(11).fontColor(this.nutriScoreText).fontWeight(FontWeight.Bold)
            .padding({ left: 9, right: 9, top: 4, bottom: 4 })
            .backgroundColor(this.nutriScoreBg)
            .borderRadius(12)
        }
      }.padding({ left: 20, right: 20, top: 20, bottom: 6 })

      if (this.nutriScore.length > 0) {
        Text('* 未含钠与膳食纤维，评级仅供参考')
          .fontSize(10).fontColor(this.secondColor)
          .padding({ left: 20, right: 20, bottom: 6 })
      }

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

      // 三大营养素（等宽三列色块）
      Row({ space: 10 }) {
        this.MacroCell('蛋白质', `${this.dispProtein} g`,
          '#22C55E', '#4ADE80', '#F0FDF4', '#1A2A1A')
        this.MacroCell('脂肪',   `${this.dispFat} g`,
          '#F59E0B', '#FBBF24', '#FFFBEB', '#2A2A1A')
        this.MacroCell('碳水',   `${this.dispCarbs} g`,
          '#3B82F6', '#60A5FA', '#EFF6FF', '#1A1A2A')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 14, bottom: 14 })

      Divider().color(this.divColor).margin({ left: 20, right: 20 })

      // 份量
      Column() { this.QtyPill() }.padding({ left: 20, right: 20 })

      Divider().color(this.divColor).margin({ left: 20, right: 20 })

      // 餐次
      Column({ space: 8 }) {
        Text('选择餐次')
          .fontSize(12).fontColor(this.secondColor)
          .width('100%').textAlign(TextAlign.Center)
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
    .borderRadius(22)
    .clip(true)
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

  // 非菜品提示：道歉动画 + 重拍 / 手动填写 两个出口
  @Builder
  NotFoodView() {
    Column() {
      Column({ space: 0 }) {
        Column() {
          Text('🥲').fontSize(48).rotate({ angle: this.notFoodTilt })
        }
        .width(104).height(104).borderRadius(52)
        .backgroundColor('#1FFFFFFF')
        .border({ width: 1.5, color: '#33FFFFFF' })
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)

        Text('对不起，没认出来')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .margin({ top: 18 })
        Text('这张照片里好像不是一道菜')
          .fontSize(13).fontColor('#B3FFFFFF').margin({ top: 8 })
        Text('换个角度重拍，或手动填写食物名称')
          .fontSize(12).fontColor('#80FFFFFF').margin({ top: 3 })

        Row({ space: 12 }) {
          Button('重新拍摄')
            .layoutWeight(1).height(46)
            .backgroundColor(Color.White).fontColor(AppColors.BRAND_COLOR)
            .fontWeight(FontWeight.Bold).fontSize(15).borderRadius(23)
            .onClick(() => { this.resetToIdle() })
          Button('手动填写')
            .layoutWeight(1).height(46)
            .backgroundColor('#1AFFFFFF').fontColor(Color.White)
            .fontSize(15).borderRadius(23)
            .border({ width: 1, color: '#4DFFFFFF' })
            .onClick(() => {
              this.manualInput = ''
              this.scanState = ScanState.MANUAL
            })
        }
        .width('100%').margin({ top: 24 })
      }
      .width('100%')
      .padding({ left: 22, right: 22, top: 30, bottom: 22 })
      .borderRadius(24)
      .backgroundColor('#E6141414')
      .border({ width: 1, color: '#26FFFFFF' })
      .scale({ x: this.notFoodScale, y: this.notFoodScale })
    }
    .width('100%').height('100%')
    .padding({ left: 28, right: 28 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#80000000')
    .opacity(this.notFoodOpacity)
  }

  // 识别不确定提示：照片 + 旋转虚线环 + “?” 徽章，说明为什么这次不算热量
  @Builder
  UnsureView() {
    Column() {
      Column({ space: 0 }) {
        Stack() {
          Image(this.capturedUri)
            .width(104).height(104)
            .borderRadius(52)
            .objectFit(ImageFit.Cover)
            .border({ width: 2, color: '#33FFFFFF' })
          Column()
            .width(104).height(104)
            .borderRadius(52)
            .backgroundColor('#40000000')
          Column()
            .width(124).height(124)
            .borderRadius(62)
            .border({ width: 1.5, color: '#59FBBF24', style: BorderStyle.Dashed })
            .rotate({ angle: this.unsureRingAngle })
          Text('?')
            .fontSize(17).fontWeight(FontWeight.Bold).fontColor('#1A1205')
            .width(32).height(32)
            .textAlign(TextAlign.Center)
            .backgroundColor('#FBBF24')
            .borderRadius(16)
            .border({ width: 2, color: '#1A1A1A' })
            .scale({ x: this.unsureBadgeScale, y: this.unsureBadgeScale })
            .position({ x: '100%', y: '100%' })
            .markAnchor({ x: '100%', y: '100%' })
            .translate({ x: -4, y: -4 })
        }
        .width(124).height(124)

        Text('这道菜没认准')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .margin({ top: 20 })

        if (this.unsureName.length > 0) {
          Text(`识别为「${this.unsureName}」`)
            .fontSize(12).fontColor('#FBBF24')
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor('#26FBBF24')
            .borderRadius(12)
            .margin({ top: 10 })
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        Text('但没匹配到可靠的营养数据')
          .fontSize(13).fontColor('#B3FFFFFF').margin({ top: 12 })
        Text('为避免记错，这道菜先不算热量')
          .fontSize(12).fontColor('#80FFFFFF').margin({ top: 4 })

        Row({ space: 12 }) {
          Button('重新拍摄')
            .layoutWeight(1).height(46)
            .backgroundColor(Color.White).fontColor(AppColors.BRAND_COLOR)
            .fontWeight(FontWeight.Bold).fontSize(15).borderRadius(23)
            .onClick(() => { this.resetToIdle() })
          Button('手动填写')
            .layoutWeight(1).height(46)
            .backgroundColor('#1AFFFFFF').fontColor(Color.White)
            .fontSize(15).borderRadius(23)
            .border({ width: 1, color: '#4DFFFFFF' })
            .onClick(() => {
              this.manualInput = ''
              this.scanState = ScanState.MANUAL
            })
        }
        .width('100%').margin({ top: 24 })
      }
      .width('100%')
      .padding({ left: 22, right: 22, top: 28, bottom: 22 })
      .borderRadius(24)
      .backgroundColor('#E6141414')
      .border({ width: 1, color: '#26FFFFFF' })
      .scale({ x: this.unsureScale, y: this.unsureScale })
      .translate({ y: this.unsureOffset })
    }
    .width('100%').height('100%')
    .padding({ left: 28, right: 28 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#A6000000')
    .opacity(this.unsureOpacity)
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
        if (this.scanState === ScanState.RESULT) {
          this.confirmDiscardResult()
        } else {
          this.resetToIdle()
        }
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
      // 全屏取景层：IDLE/PREVIEW/RECOGNIZING 铺满整屏，控件浮于其上（RESULT/MANUAL 收起）
      if (this.scanState !== ScanState.RESULT && this.scanState !== ScanState.MANUAL) {
        this.CameraFrame()
      }

      Column() {

        // RESULT / MANUAL 使用内联导航栏，内容从导航栏正下方开始，零遮挡
        if (this.scanState === ScanState.RESULT || this.scanState === ScanState.MANUAL) {
          this.InlineNav('热量识别')
        }

        // 内容区：拍照类状态浮于全屏取景之上；结果/手动态展示内容
        if (this.scanState === ScanState.IDLE) {
          Column() {
            Column().layoutWeight(1)

            // 底部控制坞：渐变遮罩把控件"压"在画面上，避免悬浮感
            Column({ space: 18 }) {
              Row({ space: 6 }) {
                Text('💡').fontSize(12)
                Text('轻点快门 · 或从相册选择').fontSize(13).fontColor('#E6FFFFFF')
              }
              .padding({ left: 14, right: 14, top: 7, bottom: 7 })
              .backgroundColor('#59000000')
              .borderRadius(16)

              // 相册 / 快门 / 翻转
              Row({ space: 40 }) {
                // 相册
                Column({ space: 6 }) {
                  Column() {
                    SymbolGlyph($r('sys.symbol.picture_fill')).fontSize(20).fontColor(['#FFFFFF'])
                  }
                  .width(48).height(48).borderRadius(24)
                  .backgroundColor('#59000000')
                  .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
                  .onClick(() => { void this.launchPicker() })
                  Text('相册').fontSize(11).fontColor('#CCFFFFFF')
                }

                // 快门
                Column() {
                  Column().width(62).height(62).borderRadius(31).backgroundColor(Color.White)
                }
                .width(76).height(76).borderRadius(38)
                .border({ width: 3, color: '#FFFFFF' })
                .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
                .onClick(() => { this.onShutterTap() })

                // 翻转
                Column({ space: 6 }) {
                  Column() {
                    Text('🔄').fontSize(19)
                  }
                  .width(48).height(48).borderRadius(24)
                  .backgroundColor('#59000000')
                  .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
                  .onClick(() => { this.previewController.switchCamera() })
                  Text('翻转').fontSize(11).fontColor('#CCFFFFFF')
                }
              }
              .width('100%').justifyContent(FlexAlign.Center)
            }
            .width('100%')
            .padding({ left: 24, right: 24, top: 44, bottom: 30 })
            .linearGradient({
              direction: GradientDirection.Bottom,
              colors: [['#00000000', 0], ['#A6000000', 0.6], ['#E6000000', 1]]
            })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.End)

        } else if (this.scanState === ScanState.PREVIEW) {
          Column() {
            Column().layoutWeight(1)

            Column({ space: 14 }) {
              Text('确认画面后开始识别')
                .fontSize(12).fontColor('#CCFFFFFF')

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
              .width('100%')
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 40, bottom: 28 })
            .linearGradient({
              direction: GradientDirection.Bottom,
              colors: [['#00000000', 0], ['#B3000000', 1]]
            })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.End)

        } else if (this.scanState === ScanState.RECOGNIZING) {
          // 识别态由全屏取景层的蒙层 + 脉冲动画承载，内容区仅占位避免重复展示
          Column().layoutWeight(1)

        } else if (this.scanState === ScanState.NOT_FOOD) {
          this.NotFoodView()

        } else if (this.scanState === ScanState.UNSURE) {
          this.UnsureView()

        } else if (this.scanState === ScanState.RESULT) {
          Scroll() {
            Column() {
              this.ResultCard()
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 24 })
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
      // 拍摄类状态透明背景以露出全屏取景；结果/手动输入态用页面底色
      .backgroundColor(this.scanState === ScanState.RESULT || this.scanState === ScanState.MANUAL
        ? this.bgColor : Color.Transparent)

      // 悬浮导航栏仅用于拍摄类状态（取景框可见时），RESULT/MANUAL 已改用内联导航栏
      if (this.scanState !== ScanState.RESULT && this.scanState !== ScanState.MANUAL) {
        this.FloatNav()
      }

      ToastView({ message: this.toastMsg, visible: this.toastVisible })
    }
    // 全屏沉浸：TOP 让取景框延伸至状态栏下方，BOTTOM 填满底部手势区
    .width('100%').height('100%')
    .opacity(this.pageOpacity)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
