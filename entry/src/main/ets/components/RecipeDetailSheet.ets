import type { RecipeWithId } from '../model/recipe'
import { RecipeDBManager } from '../data/RecipeDBManager'
import { ShoppingListService, type MissingItem } from '../service/ShoppingListService'
import { CookingFocusView } from './CookingFocusView'
import { ToastView } from './ToastView'
import { ExportShoppingListDialog } from './ExportShoppingListDialog'
import { ImageContributeSheet } from './ImageContributeSheet'
import { RecipeImage, RecipeImageVariant } from './RecipeImage'
import { getRecipeEmoji } from '../data/foodCatalog'
import { DSRadius, DSSpace, DSType, DSShadow, DSSheet, pickTagTone } from '../constants/DesignSystem'
import { AppColors, ThemeManager } from '../constants/AppColors'
import { calcNutriScore, getNutriScoreColors } from '../service/NutritionCalculator'
import type { NutriScore } from '../model/recipe'

interface RecipeDetail {
  id: number
  name: string
  emojis: string[]
  difficulty: string
  tags: string[]
  stuff: string[]
  tools: string[]
  steps: string[]
  stuffAmount: Record<string, string>
  imageUri: string
}

interface NutritionItem {
  label: string
  value: string
  color: string
  colorDark: string
}

const EMPTY_DETAIL: RecipeDetail = {
  id: 0,
  name: '',
  emojis: [],
  difficulty: '',
  tags: [],
  stuff: [],
  tools: [],
  steps: [],
  stuffAmount: {},
  imageUri: ''
}

@Component
export struct RecipeDetailSheet {
  @Prop recipe: RecipeWithId | null = null
  @Prop selectedStuff: string[] = []
  @Prop isFavorite: boolean = false
  /** 是否已在今日餐桌中 */
  @Prop isTodayMenu: boolean = false
  /** 累计做过的天数（同一天只记一次） */
  @Prop cookedCount: number = 0
  /** 最近一次下厨的相对时间文案（今天 / 昨天 / 3 天前 / 10月12日） */
  @Prop lastCookedLabel: string = ''

  onFavoriteToggle?: () => void
  onRequestClose?: () => void
  /** 切换今日餐桌状态（同时记入当天做过） */
  onTodayMenuToggle?: () => void

  @State private detail: RecipeDetail = EMPTY_DETAIL
  @State private loadState: 'loading' | 'ok' | 'empty' = 'loading'
  @State private focusModeVisible: boolean = false
  @State private focusInitIndex: number = 0
  @State private toastMessage: string = ''
  @State private toastVisible: boolean = false
  // Task3: 图片导出弹窗状态
  @State private exportDialogVisible: boolean = false
  @State private exportMissingItems: MissingItem[] = []
  @State private exportTotalStuff: number = 0
  @State private contributeVisible: boolean = false
  /** 菜系分类（川菜/粤菜/湘菜…），空则不展示 */
  @State private cuisine: string = ''
  @State private nutriScore: string = ''
  @State private nutriScoreBgColor: string = '#9CA3AF'
  @State private nutriScoreTextColor: string = '#FFFFFF'
  @State private nutritionItems: NutritionItem[] = []
  /** 营养值是否由食材营养库估算（true 时卡片标注来源） */
  @State private nutritionEstimated: boolean = false

  // ── 深色模式响应式订阅 ──────────────────────────────────────────────────────
  @StorageProp('isSystemDarkMode')
  @Watch('onThemeChange')
  private isSystemDark: boolean = false

  @StorageProp('currentThemeMode')
  @Watch('onThemeChange')
  private storedThemeMode: string = '系统默认'

  @State private bgCanvas: string = AppColors.BG_COLOR
  @State private cardBg: string = AppColors.CARD_BG
  @State private softBg: string = AppColors.GRAY_100
  @State private textPrimary: string = AppColors.GRAY_900
  @State private textSecondary: string = AppColors.GRAY_500
  @State private textTertiary: string = AppColors.GRAY_400
  @State private strokeSoft: string = AppColors.GRAY_100
  @State private brandPrimary: string = AppColors.BRAND_COLOR
  @State private bottomBarBg: string = '#F8FAFFEE'

  private onThemeChange(): void {
    this.applyTheme()
  }

  private applyTheme(): void {
    this.bgCanvas = ThemeManager.getBackgroundColor(this.storedThemeMode)
    this.cardBg = ThemeManager.getCardBackgroundColor(this.storedThemeMode)
    this.softBg = ThemeManager.getBorderColor(this.storedThemeMode)
    this.textPrimary = ThemeManager.getTextColor(this.storedThemeMode)
    this.textSecondary = ThemeManager.getSecondaryTextColor(this.storedThemeMode)
    this.textTertiary = ThemeManager.getColor(AppColors.GRAY_400, AppColors.DARK_GRAY_400, this.storedThemeMode)
    this.strokeSoft = ThemeManager.getBorderColor(this.storedThemeMode)
    this.bottomBarBg = ThemeManager.getColor('#F8FAFFEE', '#1E1E1EEE', this.storedThemeMode)
  }

  private readonly contentScroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.applyTheme()
    this.syncFromProp()
    void this.loadStepsFromDB()
  }

  private syncFromProp(): void {
    if (!this.recipe) {
      this.detail = EMPTY_DETAIL
      this.cuisine = ''
      this.nutriScore = ''
      return
    }
    this.cuisine = this.recipe.cuisine ?? ''
    const rawAmount = this.recipe.stuffAmount
    const amount: Record<string, string> = rawAmount !== undefined ? rawAmount : {}
    const tags = this.recipe.tags ?? []
    this.detail = {
      id: this.recipe.id,
      name: this.recipe.name,
      emojis: this.recipe.emojis ?? [],
      difficulty: this.recipe.difficulty ?? '',
      tags: tags,
      stuff: this.recipe.stuff,
      tools: this.recipe.tools,
      steps: [],
      stuffAmount: amount,
      imageUri: this.recipe.imageUri ?? ''
    }
    // 计算 Nutri-Score 和营养表格
    if (this.recipe.nutrition !== undefined) {
      this.nutritionEstimated = this.recipe.nutritionEstimated === true
      const n = this.recipe.nutrition
      const score = calcNutriScore(n, tags)
      const colors = getNutriScoreColors(score)
      this.nutriScore = score
      this.nutriScoreBgColor = colors.bg
      this.nutriScoreTextColor = colors.text
      const item0: NutritionItem = { label: '热量', value: `${n.calories}kcal`, color: '#E85D04', colorDark: '#FB923C' }
      const item1: NutritionItem = { label: '蛋白质', value: `${n.protein}g`, color: '#1A7C3E', colorDark: '#4ADE80' }
      const item2: NutritionItem = { label: '脂肪', value: `${n.fat}g`, color: '#F28B0C', colorDark: '#FBBF24' }
      const item3: NutritionItem = { label: '碳水', value: `${n.carbs}g`, color: '#3B82F6', colorDark: '#60A5FA' }
      const item4: NutritionItem = { label: '纤维', value: `${n.fiber}g`, color: '#56AB2F', colorDark: '#86EFAC' }
      const item5: NutritionItem = { label: '钠', value: `${n.sodium}mg`, color: '#9CA3AF', colorDark: '#D1D5DB' }
      this.nutritionItems = [item0, item1, item2, item3, item4, item5]
    } else {
      this.nutriScore = ''
      this.nutritionItems = []
      this.nutritionEstimated = false
    }
  }

  private async loadStepsFromDB(): Promise<void> {
    const id = this.recipe?.id
    if (id === undefined || id < 0) {
      this.loadState = 'empty'
      return
    }

    this.loadState = 'loading'
    try {
      const data = await RecipeDBManager.getInstance().getRecipeDetail(id)
      if (data !== null && data.steps !== undefined && data.steps.length > 0) {
        this.detail = {
          id: this.detail.id,
          name: this.detail.name,
          emojis: this.detail.emojis,
          difficulty: this.detail.difficulty,
          tags: this.detail.tags,
          stuff: this.detail.stuff,
          tools: this.detail.tools,
          steps: data.steps,
          stuffAmount: this.detail.stuffAmount,
          imageUri: this.detail.imageUri
        }
        this.loadState = 'ok'
      } else {
        this.loadState = 'empty'
      }
    } catch {
      this.loadState = 'empty'
    }
  }

  private showToast(message: string): void {
    this.toastMessage = message
    this.toastVisible = false
    setTimeout(() => {
      this.toastVisible = true
    }, 0)
  }

  /** 打开图片导出弹窗（先计算缺料 diff） */
  private openExportDialog(): void {
    const amounts: Record<string, string> = {}
    for (const ing of this.detail.stuff) {
      const amount = this.getAmount(ing)
      if (amount.length > 0) {
        amounts[ing] = amount
      }
    }
    const diffResult = ShoppingListService.diff(this.selectedStuff, this.detail.stuff, amounts)
    if (diffResult.missingItems.length === 0) {
      this.showToast('所有食材均已备好，无需导出')
      return
    }
    this.exportMissingItems = diffResult.missingItems
    this.exportTotalStuff = diffResult.totalStuff
    this.exportDialogVisible = true
  }

  private getStepDuration(step: string): string {
    const match = step.match(/(\d+\s*(秒|分钟|小时|min|mins|h))/i)
    return match !== null && match.length > 0 ? match[0] : ''
  }

  private requestClose(): void {
    if (this.onRequestClose) {
      this.onRequestClose()
    }
  }

  /** 获取某食材的用量字符串（原谱用量） */
  private getAmount(ingredient: string): string {
    const raw = this.detail.stuffAmount[ingredient]
    return raw === undefined ? '' : raw
  }

  // ──────────────────────────────────────────────
  // 拖拽条
  // ──────────────────────────────────────────────
  @Builder
  private DragHandle() {
    Column() {
      Column()
        .width(44)
        .height(5)
        .backgroundColor('#99B6C1D4')
        .borderRadius(DSRadius.PILL)
    }
    .width('100%')
    .padding({ top: DSSpace.SM, bottom: DSSpace.SM })
    .alignItems(HorizontalAlign.Center)
  }

  // ──────────────────────────────────────────────
  // 头部
  // ──────────────────────────────────────────────
  @Builder
  private HeroSection() {
    Column({ space: DSSpace.SM }) {
      // 详情封面：有图显示大图，无图回退 emoji/中性空盘占位
      RecipeImage({
        imageKey: this.detail.imageUri,
        emoji: getRecipeEmoji(this.detail.stuff ?? []),
        variant: RecipeImageVariant.DETAIL,
        placeholderBg: this.softBg,
        cornerRadius: 20
      })
      .width('100%')
      .height(280)

      // 无图菜谱：给一个开源补充入口
      if (this.detail.imageUri.length === 0) {
        Text('帮助补充成品图 ›')
          .fontSize(DSType.CAPTION)
          .fontColor(this.brandPrimary)
          .padding({ left: 12, right: 12, top: 5, bottom: 5 })
          .backgroundColor(AppColors.BRAND_COLOR_LIGHT)
          .borderRadius(DSRadius.PILL)
          .onClick(() => { this.contributeVisible = true })
      }

      Text(this.detail.name.length > 0 ? this.detail.name : '未命名菜谱')
        .fontSize(DSType.HERO)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.textPrimary)
        .textAlign(TextAlign.Center)

      // 菜系 / Nutri-Score / 难度同一行，窄屏自动换行
      if (this.cuisine.length > 0 || this.nutriScore.length > 0 || this.detail.difficulty.length > 0) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
          if (this.cuisine.length > 0) {
            Text(this.cuisine)
              .fontSize(DSType.CAPTION)
              .fontColor(ThemeManager.getColor('#B45309', '#FBBF24', this.storedThemeMode))
              .fontWeight(FontWeight.Medium)
              .padding({ left: 12, right: 12, top: 4, bottom: 4 })
              .backgroundColor(ThemeManager.getColor('#FDF3E3', '#3A2A18', this.storedThemeMode))
              .borderRadius(DSRadius.PILL)
              .margin({ right: 8, bottom: 4 })
          }
          // Nutri-Score 徽章（仅当 recipe 非空且有营养数据时展示）
          if (this.nutriScore.length > 0) {
            Text(`Nutri-Score ${this.nutriScore}`)
              .fontSize(12)
              .fontColor(this.nutriScoreTextColor)
              .fontWeight(FontWeight.Bold)
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .backgroundColor(this.nutriScoreBgColor)
              .borderRadius(DSRadius.PILL)
              .margin({ right: 8, bottom: 4 })
          }
          if (this.detail.difficulty.length > 0) {
            Text(this.detail.difficulty)
              .fontSize(DSType.CAPTION)
              .fontColor(this.textSecondary)
              .padding({ left: 12, right: 12, top: 4, bottom: 4 })
              .backgroundColor(this.softBg)
              .borderRadius(DSRadius.PILL)
              .borderWidth(1)
              .borderColor(this.strokeSoft)
              .margin({ bottom: 4 })
          }
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding({ top: DSSpace.MD, bottom: 4 })
    .alignItems(HorizontalAlign.Center)
  }

  // ──────────────────────────────────────────────
  // 标签组
  // ──────────────────────────────────────────────
  @Builder
  private TagsSection() {
    if (this.detail.tags.length > 0) {
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.detail.tags, (tag: string, index: number) => {
          Text(`# ${tag}`)
            .fontSize(DSType.CAPTION)
            .fontColor(this.getTagColor(index, 'text'))
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .backgroundColor(this.getTagColor(index, 'bg'))
            .borderRadius(DSRadius.PILL)
            .borderWidth(1)
            .borderColor(this.getTagColor(index, 'border'))
            .margin({ right: 8, bottom: 8 })
        }, (tag: string) => tag)
      }
      .width('100%')
      .padding({ left: DSSpace.LG, right: DSSpace.LG, top: 0, bottom: DSSpace.XS })
    }
  }

  private getTagColor(index: number, type: 'bg' | 'border' | 'text'): string {
    const tone = pickTagTone(index)
    switch (type) {
      case 'bg': return ThemeManager.getColor(tone.bg, tone.bgDark, this.storedThemeMode)
      case 'border': return ThemeManager.getColor(tone.border, tone.borderDark, this.storedThemeMode)
      case 'text': return ThemeManager.getColor(tone.text, tone.textDark, this.storedThemeMode)
      default: return '#FFFFFF'
    }
  }

  // ──────────────────────────────────────────────
  // 食材卡片（含人数换算）
  // ──────────────────────────────────────────────
  @Builder
  private IngredientsCard() {
    Column({ space: DSSpace.SM }) {
      // 标题行：食材 + 导出图片按钮
      Row() {
        Text('食材')
          .fontSize(16)
          .fontColor(this.textPrimary)
          .fontWeight(FontWeight.Bold)

        Blank()

        // 导出图片按钮（取代原复制到剪贴板）
        Text('导出图片')
          .fontSize(DSType.CAPTION)
          .fontColor(this.brandPrimary)
          .padding({ left: 14, right: 14, top: 6, bottom: 6 })
          .backgroundColor(AppColors.BRAND_COLOR_LIGHT)
          .borderRadius(DSRadius.SM)
          .borderWidth(1)
          .borderColor('#FFD6D1')
          .onClick(() => this.openExportDialog())
      }
      .width('100%')

      if (this.detail.stuff.length > 0) {
        Text('用量为单份参考量')
          .fontSize(10)
          .fontColor(this.textTertiary)
          .margin({ bottom: 6 })
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.detail.stuff, (item: string) => {
            Column() {
              Text(item)
                .fontSize(DSType.BODY)
                .fontColor(this.textSecondary)
              if (this.getAmount(item).length > 0) {
                Text(this.getAmount(item))
                  .fontSize(10)
                  .fontColor(this.brandPrimary)
                  .margin({ top: 1 })
              }
            }
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .backgroundColor(this.softBg)
            .borderRadius(DSRadius.SM)
            .borderWidth(1)
            .borderColor(this.strokeSoft)
            .margin({ right: 8, bottom: 8 })
            .alignItems(HorizontalAlign.Center)
          }, (item: string) => item)
        }
        .width('100%')
      } else {
        Text('暂无食材信息')
          .fontSize(DSType.BODY)
          .fontColor(this.textTertiary)
      }
    }
    .width('100%')
    .padding(DSSpace.MD)
    .backgroundColor(this.cardBg)
    .borderRadius(20)
    .borderWidth(1)
    .borderColor(this.strokeSoft)
    .shadow(DSShadow.CARD)
  }

  /**
   * 今日餐桌按钮：合并了「今天我做了这道菜」。
   * 加入即视为今天做过，餐桌页统一展示今日菜单与累计下厨次数。
   */
  @Builder
  private TodayMenuButtonSection() {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Text(this.isTodayMenu ? '✓' : '+')
          .fontSize(16)
          .fontColor(this.isTodayMenu ? Color.White : this.brandPrimary)
        Text(this.isTodayMenu ? '已加入今日餐桌' : '加入今日餐桌')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isTodayMenu ? Color.White : this.brandPrimary)
      }
      .width('100%')
      .height(48)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.isTodayMenu ? this.brandPrimary : Color.Transparent)
      .borderRadius(DSRadius.MD)
      .borderWidth(this.isTodayMenu ? 0 : 1.5)
      .borderColor(this.brandPrimary)
      .onClick(() => {
        if (this.onTodayMenuToggle) this.onTodayMenuToggle()
      })

      if (this.cookedCount > 0) {
        Text(`已做过 ${this.cookedCount} 次${this.lastCookedLabel.length > 0 ? ` · 最近 ${this.lastCookedLabel}` : ''}`)
          .fontSize(11)
          .fontColor(this.textTertiary)
          .textAlign(TextAlign.Center)
          .width('100%')
      }
    }
    .width('100%')
  }

  // ──────────────────────────────────────────────
  // 通用信息卡片：工具
  // ──────────────────────────────────────────────
  @Builder
  private ToolsCard() {
    Column({ space: DSSpace.SM }) {
      Text('烹饪工具')
        .fontSize(16)
        .fontColor(this.textPrimary)
        .fontWeight(FontWeight.Bold)

      if (this.detail.tools.length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.detail.tools, (item: string) => {
            Text(item)
              .fontSize(DSType.BODY)
              .fontColor(this.textSecondary)
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .backgroundColor(this.softBg)
              .borderRadius(DSRadius.SM)
              .borderWidth(1)
              .borderColor(this.strokeSoft)
              .margin({ right: 8, bottom: 8 })
          }, (item: string) => item)
        }
        .width('100%')
      } else {
        Text('暂无工具信息')
          .fontSize(DSType.BODY)
          .fontColor(this.textTertiary)
      }
    }
    .width('100%')
    .padding(DSSpace.MD)
    .backgroundColor(this.cardBg)
    .borderRadius(20)
    .borderWidth(1)
    .borderColor(this.strokeSoft)
    .shadow(DSShadow.CARD)
  }

  // ──────────────────────────────────────────────
  // 步骤卡片：编号气泡 + 步骤文本，支持专注模式
  // ──────────────────────────────────────────────
  @Builder
  private TimelineStepsSection() {
    Column({ space: DSSpace.SM }) {
      Row() {
        Text('步骤')
          .fontSize(16)
          .fontColor(this.textPrimary)
          .fontWeight(FontWeight.Bold)

        Blank()

        Text('专注模式')
          .fontSize(DSType.CAPTION)
          .fontColor(this.brandPrimary)
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor('#FFF2F0')
          .borderRadius(DSRadius.SM)
          .borderWidth(1)
          .borderColor('#FFD6D1')
          .onClick(() => {
            if (this.detail.steps.length > 0) {
              this.focusInitIndex = 0
              this.focusModeVisible = true
            } else {
              this.showToast('暂无步骤数据')
            }
          })
      }
      .width('100%')

      if (this.loadState === 'loading') {
        Row({ space: 8 }) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color(this.brandPrimary)
          Text('加载步骤中…')
            .fontSize(DSType.BODY)
            .fontColor(this.textTertiary)
        }
        .padding({ top: DSSpace.SM, bottom: DSSpace.SM })
      } else if (this.loadState === 'ok' && this.detail.steps.length > 0) {
        Column({ space: 8 }) {
          ForEach(this.detail.steps, (step: string, index: number) => {
            Row({ space: 12 }) {
              // 步骤编号气泡
              Text(`${index + 1}`)
                .fontSize(DSType.CAPTION)
                .fontColor(Color.White)
                .fontWeight(FontWeight.Bold)
                .width(24)
                .height(24)
                .textAlign(TextAlign.Center)
                .backgroundColor(this.brandPrimary)
                .borderRadius(DSRadius.PILL)
                .flexShrink(0)

              Text(step)
                .fontSize(DSType.BODY)
                .fontColor(this.textSecondary)
                .lineHeight(22)
                .layoutWeight(1)
            }
            .padding(DSSpace.SM)
            .backgroundColor(index % 2 === 0 ? this.cardBg : this.softBg)
            .borderRadius(DSRadius.MD)
            .borderWidth(1)
            .borderColor(this.strokeSoft)
            .alignItems(VerticalAlign.Top)
            .onClick(() => {
              // 点击步骤卡片，从该步骤进入全屏 Swiper
              this.focusInitIndex = index
              this.focusModeVisible = true
            })
          }, (step: string, index: number) => `${index}-${step}`)
        }
        .width('100%')
      } else {
        Text('暂无步骤信息')
          .fontSize(DSType.BODY)
          .fontColor(this.textTertiary)
      }
    }
    .width('100%')
    .padding(DSSpace.MD)
  }

  // ──────────────────────────────────────────────
  // 营养信息卡片（Feature 8）
  // ──────────────────────────────────────────────
  @Builder
  private NutritionCard() {
    if (this.nutritionItems.length > 0) {
      Column({ space: DSSpace.SM }) {
        Text('营养信息').fontSize(16).fontColor(this.textPrimary).fontWeight(FontWeight.Bold)
        Text(this.nutritionEstimated
          ? '（单份估算值 · 由食材营养库聚合推算，仅供参考）'
          : '（每份参考值 · 预置营养数据）')
          .fontSize(10).fontColor(this.textTertiary).alignSelf(ItemAlign.Start)
        if (this.nutriScore.length > 0) {
          Text(`Nutri-Score ${this.nutriScore}：综合热量、脂肪、钠等指标评级，A 最均衡，E 建议少吃`)
            .fontSize(10).fontColor(this.textTertiary).alignSelf(ItemAlign.Start)
        }

        GridRow({ columns: 3, gutter: { x: 8, y: 8 } }) {
          ForEach(this.nutritionItems, (item: NutritionItem) => {
            GridCol() {
              Column({ space: 2 }) {
                Text(item.value)
                  .fontSize(14).fontWeight(FontWeight.Bold)
                  .fontColor(ThemeManager.getColor(item.color, item.colorDark, this.storedThemeMode))
                Text(item.label)
                  .fontSize(11).fontColor(this.textTertiary)
              }
              .padding({ top: 10, bottom: 10 })
              .width('100%')
              .alignItems(HorizontalAlign.Center)
              .backgroundColor(this.softBg)
              .borderRadius(DSRadius.SM)
            }
          }, (item: NutritionItem) => item.label)
        }.width('100%')
      }
      .width('100%')
      .padding(DSSpace.MD)
      .backgroundColor(this.cardBg)
      .borderRadius(20)
      .borderWidth(1)
      .borderColor(this.strokeSoft)
      .shadow(DSShadow.CARD)
    }
  }

  // ──────────────────────────────────────────────
  // 底部操作栏
  // ──────────────────────────────────────────────
  @Builder
  private BottomBar() {
    Row({ space: DSSpace.MD }) {
      Row({ space: 6 }) {
        Text(this.isFavorite ? '★' : '☆')
          .fontSize(18)
          .fontColor(this.isFavorite ? AppColors.FAVORITE_ACTIVE : this.textTertiary)

        Text(this.isFavorite ? '已收藏' : '收藏')
          .fontSize(DSType.BODY)
          .fontColor(this.isFavorite ? '#A04E0A' : this.textSecondary)
      }
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .backgroundColor(this.isFavorite ? '#FFF4DE' : this.softBg)
      .borderRadius(DSRadius.MD)
      .borderWidth(1)
      .borderColor(this.isFavorite ? '#FFD7A0' : this.strokeSoft)
      .onClick(() => {
        if (this.onFavoriteToggle) {
          this.onFavoriteToggle()
        }
      })

      Blank()

      Text('完成')
        .fontSize(DSType.BODY)
        .fontColor(Color.White)
        .fontWeight(FontWeight.Medium)
        .padding({ left: 24, right: 24, top: 12, bottom: 12 })
        .backgroundColor(this.brandPrimary)
        .borderRadius(DSRadius.MD)
        .shadow({
          radius: 10,
          color: '#332D3B66',
          offsetX: 0,
          offsetY: 4
        })
        .onClick(() => this.requestClose())
    }
    .width('100%')
    .padding({ left: DSSpace.LG, right: DSSpace.LG, top: DSSpace.SM, bottom: DSSpace.SM })
    .backgroundColor(this.bottomBarBg)
    .backdropBlur(16)
    .borderWidth({ top: 1 })
    .borderColor(this.strokeSoft)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  build() {
    Stack() {
      Column() {
        this.DragHandle()

        Scroll(this.contentScroller) {
          Column({ space: DSSpace.MD }) {
            this.HeroSection()
            this.TagsSection()
            this.IngredientsCard()
            this.ToolsCard()
            this.TodayMenuButtonSection()
            this.TimelineStepsSection()
            this.NutritionCard()
            // Task1: 增加底部留白，避免 BottomBar 遮挡最后一张卡片内容
            Row().height(80)
          }
          .padding({ left: DSSpace.LG, right: DSSpace.LG, bottom: DSSpace.SM })
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .scrollBarColor('#803B4968')
        .scrollBarWidth(3)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false })
        .friction(DSSheet.SCROLL_FRICTION)
        .nestedScroll({
          scrollForward: NestedScrollMode.SELF_FIRST,
          scrollBackward: NestedScrollMode.SELF_FIRST
        })

        this.BottomBar()
      }
      .width('100%')
      .height('100%')

      ToastView({ message: this.toastMessage, visible: this.toastVisible })

      // 专注烹饪模式（支持初始步骤索引）
      CookingFocusView({
        visible: $focusModeVisible,
        recipeName: this.detail.name,
        steps: this.detail.steps,
        initialIndex: this.focusInitIndex
      })

      // Task3: 图片导出弹窗
      ExportShoppingListDialog({
        missingItems: this.exportMissingItems,
        recipeName: this.detail.name,
        totalStuff: this.exportTotalStuff,
        visible: this.exportDialogVisible,
        onClose: () => { this.exportDialogVisible = false }
      })

      // 无图菜谱的配图补充入口
      ImageContributeSheet({
        recipeName: this.detail.name,
        recipeId: this.detail.id,
        visible: this.contributeVisible,
        onClose: () => { this.contributeVisible = false }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bgCanvas)
  }
}
