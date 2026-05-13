import type { RecipeWithId } from '../model/recipe'
import { RecipeDBManager } from '../data/RecipeDBManager'
import { ShoppingListService } from '../service/ShoppingListService'
import { CookingFocusView } from './CookingFocusView'
import { ToastView } from './ToastView'
import { ExportShoppingListDialog } from './ExportShoppingListDialog'
import { DSColor, DSRadius, DSSpace, DSType, DSShadow, DSSheet, pickTagTone } from '../constants/DesignSystem'
import { AppColors } from '../constants/AppColors'
import { scaleIngredientAmount } from '../service/IngredientAmountService'
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
}

interface NutritionItem {
  label: string
  value: string
  color: string
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
  stuffAmount: {}
}

@Component
export struct RecipeDetailSheet {
  @Prop recipe: RecipeWithId | null = null
  @Prop selectedStuff: string[] = []
  @Prop isFavorite: boolean = false
  /** 是否已在今日餐桌中 */
  @Prop isTodayMenu: boolean = false

  onFavoriteToggle?: () => void
  onRequestClose?: () => void
  /** 切换今日餐桌状态 */
  onTodayMenuToggle?: () => void

  @State private detail: RecipeDetail = EMPTY_DETAIL
  @State private loadState: 'loading' | 'ok' | 'empty' = 'loading'
  @State private focusModeVisible: boolean = false
  @State private focusInitIndex: number = 0
  @State private toastMessage: string = ''
  @State private toastVisible: boolean = false
  // Task3: 图片导出弹窗状态
  @State private exportDialogVisible: boolean = false
  @State private exportMissingItems: string[] = []
  @State private servingCount: number = 1
  @State private nutriScore: string = ''
  @State private nutriScoreBgColor: string = '#9CA3AF'
  @State private nutriScoreTextColor: string = '#FFFFFF'
  @State private nutritionItems: NutritionItem[] = []

  private readonly contentScroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.syncFromProp()
    void this.loadStepsFromDB()
  }

  private syncFromProp(): void {
    if (!this.recipe) {
      this.detail = EMPTY_DETAIL
      this.nutriScore = ''
      return
    }
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
      stuffAmount: amount
    }
    // 计算 Nutri-Score 和营养表格
    if (this.recipe.nutrition !== undefined) {
      const n = this.recipe.nutrition
      const score = calcNutriScore(n, tags)
      const colors = getNutriScoreColors(score)
      this.nutriScore = score
      this.nutriScoreBgColor = colors.bg
      this.nutriScoreTextColor = colors.text
      const item0: NutritionItem = { label: '热量', value: `${n.calories}kcal`, color: '#E85D04' }
      const item1: NutritionItem = { label: '蛋白质', value: `${n.protein}g`, color: '#1A7C3E' }
      const item2: NutritionItem = { label: '脂肪', value: `${n.fat}g`, color: '#F28B0C' }
      const item3: NutritionItem = { label: '碳水', value: `${n.carbs}g`, color: '#3B82F6' }
      const item4: NutritionItem = { label: '纤维', value: `${n.fiber}g`, color: '#56AB2F' }
      const item5: NutritionItem = { label: '钠', value: `${n.sodium}mg`, color: '#9CA3AF' }
      this.nutritionItems = [item0, item1, item2, item3, item4, item5]
    } else {
      this.nutriScore = ''
      this.nutritionItems = []
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
          stuffAmount: this.detail.stuffAmount
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
    const diffResult = ShoppingListService.diff(this.selectedStuff, this.detail.stuff)
    if (diffResult.missingItems.length === 0) {
      this.showToast('所有食材均已备好，无需导出')
      return
    }
    this.exportMissingItems = diffResult.missingItems
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

  /** 获取某食材在当前人数下换算后的用量字符串 */
  private getScaledAmount(ingredient: string): string {
    const raw = this.detail.stuffAmount[ingredient]
    if (raw === undefined || raw.length === 0) return ''
    if (this.servingCount === 1) return raw
    return scaleIngredientAmount(raw, this.servingCount)
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
      Text(this.detail.emojis.length > 0 ? this.detail.emojis.join('') : '🍽️')
        .fontSize(56)

      Text(this.detail.name.length > 0 ? this.detail.name : '未命名菜谱')
        .fontSize(DSType.HERO)
        .fontWeight(FontWeight.Bold)
        .fontColor(DSColor.TEXT_PRIMARY)
        .textAlign(TextAlign.Center)

      // Nutri-Score 徽章（仅当 recipe 非空且有营养数据时展示）
      if (this.nutriScore.length > 0) {
        Text(`Nutri-Score ${this.nutriScore}`)
          .fontSize(12)
          .fontColor(this.nutriScoreTextColor)
          .fontWeight(FontWeight.Bold)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor(this.nutriScoreBgColor)
          .borderRadius(DSRadius.PILL)
      }

      if (this.detail.difficulty.length > 0) {
        Text(this.detail.difficulty)
          .fontSize(DSType.CAPTION)
          .fontColor(DSColor.TEXT_SECONDARY)
          .padding({ left: 12, right: 12, top: 4, bottom: 4 })
          .backgroundColor(DSColor.BG_SOFT)
          .borderRadius(DSRadius.PILL)
          .borderWidth(1)
          .borderColor(DSColor.STROKE_SOFT)
      }
    }
    .width('100%')
    .padding({ left: DSSpace.LG, right: DSSpace.LG, top: DSSpace.MD, bottom: DSSpace.MD })
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
      .padding({ left: DSSpace.LG, right: DSSpace.LG, top: DSSpace.SM, bottom: DSSpace.XS })
    }
  }

  private getTagColor(index: number, type: 'bg' | 'border' | 'text'): string {
    const tone = pickTagTone(index)
    switch (type) {
      case 'bg': return tone.bg
      case 'border': return tone.border
      case 'text': return tone.text
      default: return '#FFFFFF'
    }
  }

  // ──────────────────────────────────────────────
  // 食材卡片（含人数换算）
  // ──────────────────────────────────────────────
  @Builder
  private IngredientsCard() {
    Column({ space: DSSpace.SM }) {
      // 标题行：食材 + 缺失食材按钮 + 人数选择器
      Row() {
        Text('食材')
          .fontSize(DSType.TITLE)
          .fontColor(DSColor.TEXT_PRIMARY)
          .fontWeight(FontWeight.Medium)

        Blank()

        // 人数换算 Counter
        Row({ space: 8 }) {
          Text('人数')
            .fontSize(12)
            .fontColor(DSColor.TEXT_TERTIARY)
          Row({ space: 4 }) {
            Text('−')
              .fontSize(16).fontColor(this.servingCount > 1 ? DSColor.BRAND_PRIMARY : DSColor.TEXT_TERTIARY)
              .width(28).height(28).textAlign(TextAlign.Center)
              .backgroundColor(DSColor.BG_SOFT).borderRadius(DSRadius.PILL)
              .onClick(() => {
                if (this.servingCount > 1) {
                  this.servingCount = this.servingCount - 1
                }
              })
            Text(`${this.servingCount}`)
              .fontSize(14).fontColor(DSColor.TEXT_PRIMARY).fontWeight(FontWeight.Bold)
              .width(24).textAlign(TextAlign.Center)
            Text('+')
              .fontSize(16).fontColor(this.servingCount < 6 ? DSColor.BRAND_PRIMARY : DSColor.TEXT_TERTIARY)
              .width(28).height(28).textAlign(TextAlign.Center)
              .backgroundColor(DSColor.BG_SOFT).borderRadius(DSRadius.PILL)
              .onClick(() => {
                if (this.servingCount < 6) {
                  this.servingCount = this.servingCount + 1
                }
              })
          }

          // 导出图片按钮（取代原复制到剪贴板）
          Text('导出图片')
            .fontSize(DSType.CAPTION)
            .fontColor('#2EC4B6')
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .backgroundColor('#E8F8F5')
            .borderRadius(DSRadius.SM)
            .borderWidth(1)
            .borderColor('#B7E4DD')
            .onClick(() => this.openExportDialog())
        }
      }
      .width('100%')

      if (this.detail.stuff.length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.detail.stuff, (item: string) => {
            Column() {
              Text(item)
                .fontSize(DSType.BODY)
                .fontColor(DSColor.TEXT_SECONDARY)
              if (this.getScaledAmount(item).length > 0) {
                Text(this.getScaledAmount(item))
                  .fontSize(10)
                  .fontColor(DSColor.BRAND_PRIMARY)
                  .margin({ top: 1 })
              }
            }
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .backgroundColor('#FDFEFF')
            .borderRadius(DSRadius.SM)
            .borderWidth(1)
            .borderColor(DSColor.STROKE_SOFT)
            .margin({ right: 8, bottom: 8 })
            .alignItems(HorizontalAlign.Center)
          }, (item: string) => item)
        }
        .width('100%')
      } else {
        Text('暂无食材信息')
          .fontSize(DSType.BODY)
          .fontColor(DSColor.TEXT_TERTIARY)
      }
    }
    .width('100%')
    .padding(DSSpace.MD)
    .backgroundColor(DSColor.BG_ELEVATED)
    .borderRadius(DSRadius.LG)
    .borderWidth(1)
    .borderColor(DSColor.STROKE_SOFT)
    .shadow(DSShadow.CARD)
  }

  @Builder
  private TodayMenuButtonSection() {
    Row({ space: 8 }) {
      Text(this.isTodayMenu ? '✓' : '+')
        .fontSize(16)
        .fontColor(this.isTodayMenu ? Color.White : DSColor.BRAND_PRIMARY)
      Text(this.isTodayMenu ? '已加入今日餐桌' : '加入今日餐桌')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.isTodayMenu ? Color.White : DSColor.BRAND_PRIMARY)
    }
    .width('100%')
    .height(48)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.isTodayMenu ? DSColor.BRAND_PRIMARY : Color.Transparent)
    .borderRadius(DSRadius.MD)
    .borderWidth(this.isTodayMenu ? 0 : 1.5)
    .borderColor(DSColor.BRAND_PRIMARY)
    .onClick(() => {
      if (this.onTodayMenuToggle) this.onTodayMenuToggle()
    })
  }

  // ──────────────────────────────────────────────
  // 通用信息卡片：工具
  // ──────────────────────────────────────────────
  @Builder
  private ToolsCard() {
    Column({ space: DSSpace.SM }) {
      Text('烹饪工具')
        .fontSize(DSType.TITLE)
        .fontColor(DSColor.TEXT_PRIMARY)
        .fontWeight(FontWeight.Medium)

      if (this.detail.tools.length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.detail.tools, (item: string) => {
            Text(item)
              .fontSize(DSType.BODY)
              .fontColor(DSColor.TEXT_SECONDARY)
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .backgroundColor('#FDFEFF')
              .borderRadius(DSRadius.SM)
              .borderWidth(1)
              .borderColor(DSColor.STROKE_SOFT)
              .margin({ right: 8, bottom: 8 })
          }, (item: string) => item)
        }
        .width('100%')
      } else {
        Text('暂无工具信息')
          .fontSize(DSType.BODY)
          .fontColor(DSColor.TEXT_TERTIARY)
      }
    }
    .width('100%')
    .padding(DSSpace.MD)
    .backgroundColor(DSColor.BG_ELEVATED)
    .borderRadius(DSRadius.LG)
    .borderWidth(1)
    .borderColor(DSColor.STROKE_SOFT)
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
          .fontSize(DSType.TITLE)
          .fontColor(DSColor.TEXT_PRIMARY)
          .fontWeight(FontWeight.Medium)

        Blank()

        Text('专注模式')
          .fontSize(DSType.CAPTION)
          .fontColor(DSColor.BRAND_PRIMARY)
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
            .color(DSColor.BRAND_PRIMARY)
          Text('加载步骤中…')
            .fontSize(DSType.BODY)
            .fontColor(DSColor.TEXT_TERTIARY)
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
                .backgroundColor(DSColor.BRAND_PRIMARY)
                .borderRadius(DSRadius.PILL)
                .flexShrink(0)

              Text(step)
                .fontSize(DSType.BODY)
                .fontColor(DSColor.TEXT_SECONDARY)
                .lineHeight(22)
                .layoutWeight(1)
            }
            .padding(DSSpace.SM)
            .backgroundColor(index % 2 === 0 ? '#FCFDFF' : '#F4F7FC')
            .borderRadius(DSRadius.MD)
            .borderWidth(1)
            .borderColor(DSColor.STROKE_SOFT)
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
          .fontColor(DSColor.TEXT_TERTIARY)
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
        Text('营养信息').fontSize(DSType.TITLE).fontColor(DSColor.TEXT_PRIMARY).fontWeight(FontWeight.Medium)
        Text('（每份参考值）').fontSize(10).fontColor(DSColor.TEXT_TERTIARY).alignSelf(ItemAlign.Start)

        GridRow({ columns: 3, gutter: { x: 8, y: 8 } }) {
          ForEach(this.nutritionItems, (item: NutritionItem) => {
            GridCol() {
              Column({ space: 2 }) {
                Text(item.value)
                  .fontSize(14).fontWeight(FontWeight.Bold)
                  .fontColor(item.color)
                Text(item.label)
                  .fontSize(11).fontColor(DSColor.TEXT_TERTIARY)
              }
              .padding({ top: 10, bottom: 10 })
              .width('100%')
              .alignItems(HorizontalAlign.Center)
              .backgroundColor(DSColor.BG_SOFT)
              .borderRadius(DSRadius.SM)
            }
          }, (item: NutritionItem) => item.label)
        }.width('100%')
      }
      .width('100%')
      .padding(DSSpace.MD)
      .backgroundColor(DSColor.BG_ELEVATED)
      .borderRadius(DSRadius.LG)
      .borderWidth(1)
      .borderColor(DSColor.STROKE_SOFT)
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
          .fontColor(this.isFavorite ? '#D97706' : DSColor.TEXT_TERTIARY)

        Text(this.isFavorite ? '已收藏' : '收藏')
          .fontSize(DSType.BODY)
          .fontColor(this.isFavorite ? '#A04E0A' : DSColor.TEXT_SECONDARY)
      }
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .backgroundColor(this.isFavorite ? '#FFF4DE' : '#F4F7FC')
      .borderRadius(DSRadius.MD)
      .borderWidth(1)
      .borderColor(this.isFavorite ? '#FFD7A0' : DSColor.STROKE_SOFT)
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
        .backgroundColor(DSColor.BRAND_PRIMARY)
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
    .backgroundColor('#F8FAFFEE')
    .backdropBlur(16)
    .borderWidth({ top: 1 })
    .borderColor(DSColor.STROKE_SOFT)
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
        visible: this.exportDialogVisible,
        onClose: () => { this.exportDialogVisible = false }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_COLOR)
  }
}
