/**
 * 健康目标设置页
 * 通过性别 / 年龄 / 身高 / 体重 / 活动量 / 减重目标推算每日热量与三大营养素目标。
 * 计算结果保存在 CookPreferences，供首页饮食圆环与拍照记录使用。
 */
import { common } from '@kit.AbilityKit'
import { AppColors } from '../constants/AppColors'
import { CalorieTargetService } from '../service/CalorieTargetService'
import { CookPreferences } from '../store/CookPreferences'
import type { ActivityLevel, CalorieTargets, DietProfile, Gender, GoalType } from '../model/dietProfile'
import { DEFAULT_DIET_PROFILE } from '../model/dietProfile'
import { getSystemSafeTopVp } from '../util/StatusBarInset'
import { ToastView } from '../components/ToastView'

// ─── 选项数据 ─────────────────────────────────────────────────────────────────

interface ActivityOption {
  value: ActivityLevel
  label: string
  desc: string
  emoji: string
}

interface GoalOption {
  value: GoalType
  label: string
  desc: string
  emoji: string
}

const ACTIVITY_OPTIONS: ActivityOption[] = [
  { value: 'sedentary', label: '久坐少动', desc: '办公室工作，几乎不运动', emoji: '🪑' },
  { value: 'light', label: '轻度活动', desc: '每周运动 1–3 次', emoji: '🚶' },
  { value: 'moderate', label: '中度活动', desc: '每周运动 3–5 次', emoji: '🏃' },
  { value: 'active', label: '高度活动', desc: '每周运动 6–7 次', emoji: '🏋️' },
  { value: 'veryActive', label: '极高活动', desc: '体力劳动或每天高强度训练', emoji: '🔥' }
]

const GOAL_OPTIONS: GoalOption[] = [
  { value: 'lose', label: '减脂', desc: '控制热量缺口', emoji: '📉' },
  { value: 'maintain', label: '保持', desc: '维持当前体重', emoji: '⚖️' },
  { value: 'gain', label: '增肌', desc: '热量小幅盈余', emoji: '📈' }
]

const WEEKLY_RATES: number[] = [0.25, 0.5, 0.75, 1.0]
const WEEK_LABELS: string[] = ['今天', '+1周', '+2周', '+3周', '+4周']
const MACRO_COLORS: string[] = ['#22C55E', '#F59E0B', '#3B82F6']

const DEFAULT_TARGETS: CalorieTargets = CalorieTargetService.calcTargets(DEFAULT_DIET_PROFILE)

// ─── 页面 ─────────────────────────────────────────────────────────────────────

@Entry
@Component
struct HealthGoalPage {
  @State private safeTopVp: number = 48

  @StorageProp('currentThemeMode')
  @Watch('onThemeChange')
  private storedThemeMode: string = '系统默认'

  @StorageProp('isSystemDarkMode')
  @Watch('onThemeChange')
  private isSystemDark: boolean = false

  @State private isDark: boolean = false

  // 表单状态
  @State private gender: Gender = DEFAULT_DIET_PROFILE.gender
  @State private ageStr: string = `${DEFAULT_DIET_PROFILE.age}`
  @State private heightStr: string = `${DEFAULT_DIET_PROFILE.heightCm}`
  @State private weightStr: string = `${DEFAULT_DIET_PROFILE.weightKg}`
  @State private activity: ActivityLevel = DEFAULT_DIET_PROFILE.activity
  @State private goal: GoalType = DEFAULT_DIET_PROFILE.goal
  @State private weeklyRate: number = DEFAULT_DIET_PROFILE.weeklyRateKg

  // 实时预览结果
  @State private tBmr: number = DEFAULT_TARGETS.bmr
  @State private tTdee: number = DEFAULT_TARGETS.tdee
  @State private tCal: number = DEFAULT_TARGETS.calories
  @State private tPro: number = DEFAULT_TARGETS.protein
  @State private tFat: number = DEFAULT_TARGETS.fat
  @State private tCarbs: number = DEFAULT_TARGETS.carbs
  @State private proPct: number = 0
  @State private fatPct: number = 0
  @State private carbPct: number = 0
  @State private goalHint: string = '保持当前体重'

  // 可视化：宏量营养素环图（按千卡占比）+ 4 周体重趋势柱
  @State private macroValues: number[] = [0, 0, 0]
  @State private trendWeights: number[] = [60, 60, 60, 60, 60]
  @State private trendBars: number[] = [40, 40, 40, 40, 40]
  @State private projectedWeight: string = '60'

  // 入场动画
  @State private pageOpacity: number = 0
  @State private pageOffset: number = 16

  @State private toastMsg: string = ''
  @State private toastVisible: boolean = false
  @State private saving: boolean = false

  // ── 生命周期 ──────────────────────────────────────────────────────────────

  aboutToAppear(): void {
    this.isDark = this.calcIsDark()
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (ctx !== undefined) {
      getSystemSafeTopVp(ctx).then((vp: number) => { this.safeTopVp = vp }).catch(() => {})
    }
    void this.loadProfile()
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 360, curve: Curve.EaseOut }, () => {
        this.pageOpacity = 1
        this.pageOffset = 0
      })
    }, 30)
  }

  private async loadProfile(): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (!host) {
      this.recalc()
      return
    }
    try {
      const p = await CookPreferences.getDietProfile(host)
      this.gender = p.gender
      this.ageStr = `${p.age}`
      this.heightStr = `${p.heightCm}`
      this.weightStr = `${p.weightKg}`
      this.activity = p.activity
      this.goal = p.goal
      this.weeklyRate = p.weeklyRateKg
    } catch (e) {
      console.error('[HealthGoalPage] load error:', JSON.stringify(e))
    }
    this.recalc()
  }

  private onThemeChange(): void { this.isDark = this.calcIsDark() }

  private calcIsDark(): boolean {
    if (this.storedThemeMode === '深色模式') return true
    if (this.storedThemeMode === '浅色模式') return false
    return this.isSystemDark
  }

  // ── 计算 ──────────────────────────────────────────────────────────────────

  private parseNumber(text: string, fallback: number): number {
    if (text.trim().length === 0) return fallback
    const n: number = Number(text)
    return Number.isNaN(n) ? fallback : n
  }

  private buildProfile(): DietProfile {
    return {
      gender: this.gender,
      age: Math.max(14, Math.min(90, Math.round(this.parseNumber(this.ageStr, DEFAULT_DIET_PROFILE.age)))),
      heightCm: Math.max(120, Math.min(220, Math.round(this.parseNumber(this.heightStr, DEFAULT_DIET_PROFILE.heightCm)))),
      weightKg: Math.max(30, Math.min(200, this.parseNumber(this.weightStr, DEFAULT_DIET_PROFILE.weightKg))),
      activity: this.activity,
      goal: this.goal,
      weeklyRateKg: this.weeklyRate
    }
  }

  private recalc(): void {
    const t: CalorieTargets = CalorieTargetService.calcTargets(this.buildProfile())
    this.tBmr = t.bmr
    this.tTdee = t.tdee
    this.tCal = t.calories
    this.tPro = t.protein
    this.tFat = t.fat
    this.tCarbs = t.carbs
    const kcal = Math.max(1, t.calories)
    this.proPct = Math.round(t.protein * 4 / kcal * 100)
    this.fatPct = Math.round(t.fat * 9 / kcal * 100)
    this.carbPct = Math.max(0, 100 - this.proPct - this.fatPct)
    this.macroValues = [t.protein * 4, t.fat * 9, t.carbs * 4]
    this.recalcTrend()
    if (this.goal === 'lose') {
      this.goalHint = `减脂 · 每周约减 ${this.weeklyRate} kg`
    } else if (this.goal === 'gain') {
      this.goalHint = `增肌 · 每周约增 ${this.weeklyRate} kg`
    } else {
      this.goalHint = '保持当前体重'
    }
  }

  /**
   * 4 周体重趋势：按当前体重与每周目标变化量外推。
   * 柱高使用固定比例（8vp/kg）而不是按本次跨度归一化，
   * 否则不同速度会被拉伸成同样的形状，看不出与所选速度的对应关系。
   */
  private recalcTrend(): void {
    const TREND_BASE_H: number = 54
    const TREND_PX_PER_KG: number = 8
    const w: number = Math.max(30, Math.min(200,
      this.parseNumber(this.weightStr, DEFAULT_DIET_PROFILE.weightKg)))
    const dir: number = this.goal === 'lose' ? -1 : (this.goal === 'gain' ? 1 : 0)
    const weights: number[] = []
    const bars: number[] = []
    for (let i = 0; i < 5; i++) {
      weights.push(Math.round((w + dir * this.weeklyRate * i) * 10) / 10)
      bars.push(Math.round(TREND_BASE_H + dir * this.weeklyRate * i * TREND_PX_PER_KG))
    }
    this.trendWeights = weights
    this.trendBars = bars
    this.projectedWeight = `${weights[weights.length - 1]}`
  }

  private onNumberChange(kind: number, value: string): void {
    if (kind === 0) {
      this.ageStr = value
    } else if (kind === 1) {
      this.heightStr = value
    } else {
      this.weightStr = value
    }
    this.recalc()
  }

  // ── 保存 ──────────────────────────────────────────────────────────────────

  private isValidInput(): boolean {
    const age: number = this.parseNumber(this.ageStr, -1)
    const h: number = this.parseNumber(this.heightStr, -1)
    const w: number = this.parseNumber(this.weightStr, -1)
    return age >= 14 && age <= 90 && h >= 120 && h <= 220 && w >= 30 && w <= 200
  }

  private async save(): Promise<void> {
    if (this.saving) return
    if (!this.isValidInput()) {
      this.toast('请填写有效的年龄 / 身高 / 体重')
      return
    }
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (!host) return
    this.saving = true
    try {
      await CookPreferences.setDietProfile(host, this.buildProfile())
      this.toast('已保存，每日目标已更新')
      setTimeout(() => { this.getUIContext().getRouter().back() }, 900)
    } catch (e) {
      console.error('[HealthGoalPage] save error:', JSON.stringify(e))
      this.toast('保存失败，请重试')
      this.saving = false
    }
  }

  private toast(msg: string): void {
    this.toastMsg = msg
    this.toastVisible = true
    setTimeout(() => { this.toastVisible = false }, 2400)
  }

  // ── 颜色 Token ────────────────────────────────────────────────────────────

  private get bg(): string      { return this.isDark ? AppColors.DARK_BG_COLOR : AppColors.BG_COLOR }
  private get surface(): string { return this.isDark ? AppColors.DARK_CARD_BG  : AppColors.CARD_BG  }
  private get divider(): string { return this.isDark ? AppColors.DARK_GRAY_200 : '#E8E8EA'           }
  private get track(): string   { return this.isDark ? AppColors.DARK_GRAY_200 : AppColors.GRAY_200  }
  private get t1(): string      { return this.isDark ? AppColors.DARK_GRAY_900 : AppColors.GRAY_900  }
  private get t2(): string      { return this.isDark ? AppColors.DARK_GRAY_500 : AppColors.GRAY_500  }
  private get t3(): string      { return this.isDark ? AppColors.DARK_GRAY_400 : AppColors.GRAY_400  }
  private get inputBg(): string { return this.isDark ? AppColors.DARK_GRAY_100 : '#F5F6F8'           }
  private get brandBg(): string { return this.isDark ? '#2A1215' : AppColors.BRAND_COLOR_LIGHT       }
  private get cardBorder(): string { return this.isDark ? '#1FFFFFFF' : '#F0F0F2'                   }

  // ── 导航栏 ────────────────────────────────────────────────────────────────

  @Builder
  private NavBar() {
    Row() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20)
          .fontColor([this.t1])
      }
      .width(44).height(44)
      .justifyContent(FlexAlign.Center)
      .onClick(() => { this.getUIContext().getRouter().back() })

      Text('健康目标')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.t1)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Blank().width(44)
    }
    .width('100%')
    .height(this.safeTopVp + 48)
    .padding({ top: this.safeTopVp, left: 4, right: 4 })
    .backgroundColor(this.surface)
    .border({ width: { bottom: 0.5 }, color: this.divider })
  }

  @Builder
  private SectionTitle(title: string) {
    Row({ space: 8 }) {
      Row()
        .width(3).height(14)
        .borderRadius(2)
        .backgroundColor(AppColors.BRAND_COLOR)
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.t1)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 20, bottom: 10 })
  }

  // ── 目标预览 ──────────────────────────────────────────────────────────────

  /** 三大营养素小卡片：色点 + 克数 + 热量占比微进度条，三块等宽并排 */
  @Builder
  private MacroMini(label: string, value: string, pct: number, color: string, bg: string) {
    Column({ space: 7 }) {
      Row({ space: 4 }) {
        Row().width(5).height(5).borderRadius(2.5).backgroundColor(color)
        Text(label).fontSize(10).fontColor(this.t3)
        Blank()
        Text(`${pct}%`).fontSize(10).fontWeight(FontWeight.Medium).fontColor(color)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 2 }) {
        Text(value).fontSize(18).fontWeight(FontWeight.Bold).fontColor(color)
        Text('g').fontSize(9).fontColor(this.t3).margin({ bottom: 3 })
      }
      .alignItems(VerticalAlign.Bottom)

      // 热量占比微进度条，比纯文字更直观
      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%').height(3).borderRadius(2)
          .backgroundColor(this.isDark ? '#26FFFFFF' : '#FFFFFF')
        Row()
          .width(`${Math.max(0, Math.min(100, pct))}%`).height(3).borderRadius(2)
          .backgroundColor(color)
          .animation({ duration: 260, curve: Curve.EaseOut })
      }
      .width('100%')
    }
    .layoutWeight(1)
    .padding({ left: 10, right: 10, top: 9, bottom: 9 })
    .backgroundColor(bg)
    .borderRadius(11)
  }

  @Builder
  private HeroCard() {
    Column({ space: 14 }) {
      Row({ space: 6 }) {
        Text('每日热量目标')
          .fontSize(11)
          .fontColor(AppColors.BRAND_COLOR)
          .fontWeight(FontWeight.Medium)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(this.brandBg)
          .borderRadius(8)
        Text(this.goalHint)
          .fontSize(11)
          .fontColor(this.t2)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(VerticalAlign.Center)

      Row({ space: 10 }) {
        Column({ space: 5 }) {
          Row({ space: 5 }) {
            Text(`${this.tCal}`)
              .fontSize(38).fontWeight(FontWeight.Bold).fontColor(AppColors.BRAND_COLOR)
            Text('千卡 / 天').fontSize(12).fontColor(this.t2).margin({ top: 18 })
          }
          .alignItems(VerticalAlign.Bottom)

          Text(`基础代谢 ${this.tBmr} · 活动消耗 ${Math.max(0, this.tTdee - this.tBmr)} 千卡`)
            .fontSize(11)
            .fontColor(this.t3)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        // 三大营养素热量占比环图（DataPanel 自带数值过渡动效）
        Stack({ alignContent: Alignment.Center }) {
          DataPanel({
            values: this.macroValues,
            max: this.tCal,
            type: DataPanelType.Circle
          })
            .width(96).height(96)
            .valueColors(MACRO_COLORS)
            .trackBackgroundColor(this.isDark ? '#33FFFFFF' : '#FFE4E6')
            .strokeWidth(10)

          Column({ space: 1 }) {
            Text(this.goal === 'lose' ? '📉' : (this.goal === 'gain' ? '📈' : '⚖️'))
              .fontSize(18)
            Text(this.goal === 'lose' ? '减脂' : (this.goal === 'gain' ? '增肌' : '保持'))
              .fontSize(9)
              .fontColor(this.t3)
          }
          .alignItems(HorizontalAlign.Center)
        }
        .width(96).height(96)
        .flexShrink(0)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Divider().color(this.divider)

      // 三大营养素：等宽小卡片并排，展示克数与热量占比
      Row({ space: 8 }) {
        this.MacroMini('蛋白质', `${this.tPro}`, this.proPct, MACRO_COLORS[0],
          this.isDark ? '#16291D' : '#F0FDF4')
        this.MacroMini('脂肪', `${this.tFat}`, this.fatPct, MACRO_COLORS[1],
          this.isDark ? '#2A2415' : '#FFFBEB')
        this.MacroMini('碳水', `${this.tCarbs}`, this.carbPct, MACRO_COLORS[2],
          this.isDark ? '#16202E' : '#EFF6FF')
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(18)
    .borderRadius(16)
    .linearGradient({
      angle: 145,
      colors: this.isDark
        ? [['#2A1215', 0], ['#1F1F21', 1]]
        : [['#FFF1F2', 0], ['#FFFFFF', 1]]
    })
    .border({
      width: this.isDark ? 1 : 0.5,
      color: this.isDark ? '#28FFFFFF' : '#FFE4E6'
    })
    .shadow({ radius: 14, color: 'rgba(255,71,87,0.10)', offsetX: 0, offsetY: 4 })
  }

  // ── 基本信息 ──────────────────────────────────────────────────────────────

  @Builder
  private GenderCell(label: string, value: Gender, icon: string) {
    Row({ space: 3 }) {
      Text(icon)
        .fontSize(13)
        .fontColor(this.gender === value ? Color.White : this.t2)
      Text(label)
        .fontSize(13)
        .fontWeight(this.gender === value ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.gender === value ? Color.White : this.t1)
    }
    .width(56).height(32)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.gender === value ? AppColors.BRAND_COLOR : Color.Transparent)
    .borderRadius(8)
    .shadow({
      radius: this.gender === value ? 6 : 0,
      color: 'rgba(255,71,87,0.28)',
      offsetX: 0,
      offsetY: 2
    })
    .animation({ duration: 180, curve: Curve.EaseOut })
    .onClick(() => {
      this.gender = value
      this.recalc()
    })
  }

  @Builder
  private NumberRow(label: string, unit: string, value: string, kind: number) {
    Row({ space: 8 }) {
      Text(label)
        .fontSize(15)
        .fontColor(this.t1)
        .layoutWeight(1)

      TextInput({ text: value })
        .type(InputType.Number)
        .width(88)
        .height(34)
        .fontSize(15)
        .fontColor(this.t1)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.inputBg)
        .borderRadius(8)
        .padding({ left: 8, right: 8 })
        .caretColor(AppColors.BRAND_COLOR)
        .maxLength(5)
        .onChange((v: string) => { this.onNumberChange(kind, v) })

      Text(unit)
        .fontSize(13)
        .fontColor(this.t2)
        .width(22)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 12 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private BasicCard() {
    Column({ space: 0 }) {
      Row({ space: 8 }) {
        Text('性别')
          .fontSize(15)
          .fontColor(this.t1)
          .layoutWeight(1)
        Row({ space: 2 }) {
          this.GenderCell('男', 'male', '♂')
          this.GenderCell('女', 'female', '♀')
        }
        .padding(3)
        .backgroundColor(this.inputBg)
        .borderRadius(10)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 12 })
      .alignItems(VerticalAlign.Center)

      Divider().color(this.divider).margin({ left: 20, right: 20 })
      this.NumberRow('年龄', '岁', this.ageStr, 0)
      Divider().color(this.divider).margin({ left: 20, right: 20 })
      this.NumberRow('身高', 'cm', this.heightStr, 1)
      Divider().color(this.divider).margin({ left: 20, right: 20 })
      this.NumberRow('体重', 'kg', this.weightStr, 2)
    }
    .backgroundColor(this.surface)
    .borderRadius(16)
    .border({ width: 0.5, color: this.cardBorder })
    .clip(true)
    .margin({ left: 20, right: 20 })
  }

  // ── 活动水平 ──────────────────────────────────────────────────────────────

  @Builder
  private ActivityRow(opt: ActivityOption, showDivider: boolean) {
    Column({ space: 0 }) {
      Row({ space: 12 }) {
        Column() {
          Text(opt.emoji).fontSize(16)
        }
        .width(36).height(36).borderRadius(11)
        .backgroundColor(this.activity === opt.value
          ? (this.isDark ? '#3A1D21' : '#FFE4E6')
          : this.inputBg)
        .animation({ duration: 180, curve: Curve.EaseOut })
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .flexShrink(0)

        Column({ space: 2 }) {
          Text(opt.label).fontSize(15).fontColor(this.t1)
          Text(opt.desc).fontSize(11).fontColor(this.t2)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Stack({ alignContent: Alignment.Center }) {
          Row()
            .width(18).height(18)
            .borderRadius(9)
            .backgroundColor(this.activity === opt.value ? AppColors.BRAND_COLOR : Color.Transparent)
            .border({ width: this.activity === opt.value ? 0 : 1.5, color: this.track })
            .animation({ duration: 180, curve: Curve.EaseOut })
          if (this.activity === opt.value) {
            Text('✓').fontSize(11).fontColor(Color.White)
          }
        }
        .width(18).height(18)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 12 })
      .alignItems(VerticalAlign.Center)

      if (showDivider) {
        Divider().color(this.divider).margin({ left: 20, right: 20 })
      }
    }
    .width('100%')
    // 选中行整行浅色高亮，比只有右侧小圆点更容易扫读
    .backgroundColor(this.activity === opt.value ? this.brandBg : Color.Transparent)
    .animation({ duration: 180, curve: Curve.EaseOut })
    .onClick(() => {
      this.activity = opt.value
      this.recalc()
    })
  }

  @Builder
  private ActivityCard() {
    Column({ space: 0 }) {
      ForEach(
        ACTIVITY_OPTIONS,
        (opt: ActivityOption, index: number) => {
          this.ActivityRow(opt, index < ACTIVITY_OPTIONS.length - 1)
        },
        (opt: ActivityOption) => opt.value
      )
    }
    .backgroundColor(this.surface)
    .borderRadius(16)
    .border({ width: 0.5, color: this.cardBorder })
    .clip(true)
    .margin({ left: 20, right: 20 })
  }

  // ── 目标与速度 ────────────────────────────────────────────────────────────

  @Builder
  private GoalCell(opt: GoalOption) {
    Column({ space: 4 }) {
      Text(opt.emoji).fontSize(20)
      Text(opt.label)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.goal === opt.value ? AppColors.BRAND_COLOR : this.t1)
      Text(opt.desc)
        .fontSize(10)
        .fontColor(this.t2)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .padding({ top: 12, bottom: 12, left: 6, right: 6 })
    .backgroundColor(this.goal === opt.value ? this.brandBg : this.inputBg)
    .borderRadius(12)
    .border({
      width: this.goal === opt.value ? 1.5 : 1,
      color: this.goal === opt.value ? AppColors.BRAND_COLOR : 'transparent'
    })
    .animation({ duration: 180, curve: Curve.EaseOut })
    .onClick(() => {
      this.goal = opt.value
      this.recalc()
    })
  }

  @Builder
  private RateChip(rate: number) {
    // 用 Stack 居中文本：避免 lineHeight 在不同字号下造成红底上下留白不均
    Stack({ alignContent: Alignment.Center }) {
      Text(`${rate} kg`)
        .fontSize(13)
        .fontColor(this.weeklyRate === rate ? Color.White : this.t1)
        .fontWeight(this.weeklyRate === rate ? FontWeight.Medium : FontWeight.Normal)
    }
    .layoutWeight(1)
    .height(34)
    .backgroundColor(this.weeklyRate === rate ? AppColors.BRAND_COLOR : this.inputBg)
    .borderRadius(9)
    .shadow({
      radius: this.weeklyRate === rate ? 6 : 0,
      color: 'rgba(255,71,87,0.24)',
      offsetX: 0,
      offsetY: 2
    })
    .animation({ duration: 220, curve: Curve.EaseOut })
    .onClick(() => {
      this.weeklyRate = rate
      this.recalc()
    })
  }

  @Builder
  private GoalCard() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        ForEach(
          GOAL_OPTIONS,
          (opt: GoalOption) => { this.GoalCell(opt) },
          (opt: GoalOption) => opt.value
        )
      }
      .width('100%')

      if (this.goal !== 'maintain') {
        Divider().color(this.divider)
        Column({ space: 12 }) {
          Row() {
            Text(this.goal === 'gain' ? '增重速度' : '减重速度')
              .fontSize(12)
              .fontColor(this.t2)
              .layoutWeight(1)
            Text(`${this.weeklyRate} kg / 周`)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.BRAND_COLOR)
          }
          .width('100%')

          Row({ space: 8 }) {
            ForEach(
              WEEKLY_RATES,
              (rate: number) => { this.RateChip(rate) },
              (rate: number) => `${rate}`
            )
          }
          .width('100%')

          // 4 周体重趋势：柱高随速度变化做补间动画
          Column({ space: 8 }) {
            Row() {
              Text('体重变化预估')
                .fontSize(12)
                .fontColor(this.t2)
                .layoutWeight(1)
              Text(`4 周后约 ${this.projectedWeight} kg`)
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColors.BRAND_COLOR)
            }
            .width('100%')

            Row({ space: 10 }) {
              ForEach(this.trendWeights, (w: number, i: number) => {
                Column({ space: 5 }) {
                  Text(`${w}`)
                    .fontSize(9)
                    .fontColor(i === 0 || i === this.trendWeights.length - 1 ? this.t2 : this.t3)
                  Column()
                    .width('100%')
                    .height(this.trendBars[i])
                    .borderRadius({ topLeft: 5, topRight: 5 })
                    .linearGradient({
                      angle: 180,
                      // 终点（4 周后）用品牌色强调，其余周次用浅色对比趋势
                      colors: i === this.trendWeights.length - 1
                        ? [[AppColors.BRAND_COLOR, 0], ['#FF7A86', 1]]
                        : [['#FFADB4', 0], ['#FFD9DC', 1]]
                    })
                    // 与速度按钮使用同一时长/曲线，切换速度时两者同步过渡
                    .animation({ duration: 220, curve: Curve.EaseOut })
                  Text(WEEK_LABELS[i])
                    .fontSize(9)
                    .fontColor(this.t3)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Center)
              }, (w: number, i: number) => `trend-${i}-${w}`)
            }
            .width('100%')
            .alignItems(VerticalAlign.Bottom)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    // 左右 20vp 与「基本信息」「活动水平」卡片内部行对齐
    .padding({ left: 20, right: 20, top: 16, bottom: 12 })
    .backgroundColor(this.surface)
    .borderRadius(16)
    .border({ width: 0.5, color: this.cardBorder })
  }

  @Builder
  private Notice() {
    Row({ space: 10 }) {
      Text('ℹ️').fontSize(14).flexShrink(0)
      Text('结果基于 Mifflin-St Jeor 公式与每周目标变化量估算，仅供日常参考。孕期、哺乳期或患有慢性疾病时，请遵医嘱或咨询营养师。')
        .fontSize(11)
        .fontColor(this.t3)
        .lineHeight(18)
        .layoutWeight(1)
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.surface)
    .borderRadius(16)
    .margin({ top: 16, bottom: 28 })
    .alignItems(VerticalAlign.Top)
  }

  // ── 底部保存 ──────────────────────────────────────────────────────────────

  @Builder
  private BottomBar() {
    Column() {
      Button() {
        Text(this.saving ? '保存中…' : `保存目标 · ${this.tCal} 千卡`)
          .fontSize(15)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .height(48)
      .backgroundColor(AppColors.BRAND_COLOR)
      .borderRadius(14)
      .enabled(!this.saving)
      .opacity(this.saving ? 0.6 : 1)
      .shadow({ radius: 10, color: 'rgba(255,71,87,0.30)', offsetX: 0, offsetY: 4 })
      .onClick(() => { void this.save() })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 16 })
    .backgroundColor(this.surface)
    .border({ width: { top: 0.5 }, color: this.divider })
    .shadow({ radius: 12, color: 'rgba(0,0,0,0.05)', offsetX: 0, offsetY: -2 })
  }

  // ── 构建入口 ──────────────────────────────────────────────────────────────

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column() {
        this.NavBar()

        Scroll() {
          Column({ space: 0 }) {
            // 用外层 padding 控制左右留白：width('100%') + margin 会让卡片溢出成通栏
            Column() {
              this.HeroCard()
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 12 })

            this.SectionTitle('基本信息')
            this.BasicCard()
            this.SectionTitle('活动水平')
            this.ActivityCard()
            this.SectionTitle('目标')
            // 与上方卡片同宽：用外层 padding 控制留白，避免 width('100%') + margin 溢出
            Column() {
              this.GoalCard()
            }
            .width('100%')
            .padding({ left: 20, right: 20 })

            Column() {
              this.Notice()
            }
            .width('100%')
            .padding({ left: 20, right: 20 })
          }
          .width('100%')
          .opacity(this.pageOpacity)
          .translate({ y: this.pageOffset })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)

        this.BottomBar()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.bg)

      ToastView({ message: this.toastMsg, visible: this.toastVisible })
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
