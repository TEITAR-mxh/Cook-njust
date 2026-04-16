import { pasteboard } from '@kit.BasicServicesKit'
import type { RecipeWithId } from '../model/recipe'
import { RecipeDBManager } from '../data/RecipeDBManager'
import { ShoppingListService } from '../service/ShoppingListService'
import { CookingFocusView } from './CookingFocusView'
import { ToastView } from './ToastView'
import { DSColor, DSRadius, DSSpace, DSType, DSShadow, DSSheet, pickTagTone } from '../constants/DesignSystem'
import { AppColors } from '../constants/AppColors'

interface RecipeDetail {
  id: number
  name: string
  emojis: string[]
  difficulty: string
  tags: string[]
  stuff: string[]
  tools: string[]
  steps: string[]
}

const EMPTY_DETAIL: RecipeDetail = {
  id: 0,
  name: '',
  emojis: [],
  difficulty: '',
  tags: [],
  stuff: [],
  tools: [],
  steps: []
}

@Component
export struct RecipeDetailSheet {
  @Prop recipe: RecipeWithId | null = null
  @Prop selectedStuff: string[] = []
  @Prop isFavorite: boolean = false

  onFavoriteToggle?: () => void
  onRequestClose?: () => void

  @State private detail: RecipeDetail = EMPTY_DETAIL
  @State private loadState: 'loading' | 'ok' | 'empty' = 'loading'
  @State private focusModeVisible: boolean = false
  @State private toastMessage: string = ''
  @State private toastVisible: boolean = false

  private readonly contentScroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.syncFromProp()
    void this.loadStepsFromDB()
  }

  private syncFromProp(): void {
    if (!this.recipe) {
      this.detail = EMPTY_DETAIL
      return
    }
    this.detail = {
      id: this.recipe.id,
      name: this.recipe.name,
      emojis: this.recipe.emojis ?? [],
      difficulty: this.recipe.difficulty ?? '',
      tags: this.recipe.tags ?? [],
      stuff: this.recipe.stuff,
      tools: this.recipe.tools,
      steps: []
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
          steps: data.steps
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

  private copyMissingIngredients(): void {
    const diffResult = ShoppingListService.diff(this.selectedStuff, this.detail.stuff)
    if (diffResult.missingItems.length === 0) {
      this.showToast('所有食材均已备好')
      return
    }

    const text = ShoppingListService.toClipboardText(
      this.detail.name,
      diffResult.missingItems,
      diffResult.matchedItems
    )

    try {
      const systemPasteboard = pasteboard.getSystemPasteboard()
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text)
      systemPasteboard.setDataSync(pasteData)
      this.showToast('缺失食材已复制到剪贴板')
    } catch (err) {
      console.error('复制到剪贴板失败', JSON.stringify(err))
      this.showToast('复制失败，请重试')
    }
  }

  private requestClose(): void {
    if (this.onRequestClose) {
      this.onRequestClose()
    }
  }

  // ──────────────────────────────────────────────
  // 拖拽条：视觉引导用户上拉/下拉操作面板
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
  // 头部：菜品大图、名称、难度标签
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
  // 标签组：彩色 # 标签展示
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
  // 通用信息卡片：食材 / 工具
  // copyEnabled = true 时，标题右侧出现「缺失食材」快捷复制按钮
  // ──────────────────────────────────────────────
  @Builder
  private SectionCard(title: string, items: string[], emptyHint: string, copyEnabled: boolean = false) {
    Column({ space: DSSpace.SM }) {
      Row() {
        Text(title)
          .fontSize(DSType.TITLE)
          .fontColor(DSColor.TEXT_PRIMARY)
          .fontWeight(FontWeight.Medium)

        Blank()

        if (copyEnabled) {
          Text('缺失食材')
            .fontSize(DSType.CAPTION)
            .fontColor(DSColor.BRAND_PRIMARY)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor('#FFF2F0')
            .borderRadius(DSRadius.SM)
            .borderWidth(1)
            .borderColor('#FFD6D1')
            .onClick(() => this.copyMissingIngredients())
        }
      }
      .width('100%')

      if (items.length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(items, (item: string) => {
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
        Text(emptyHint)
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
  private StepsSection() {
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
    .backgroundColor(DSColor.BG_ELEVATED)
    .borderRadius(DSRadius.LG)
    .borderWidth(1)
    .borderColor(DSColor.STROKE_SOFT)
    .shadow(DSShadow.CARD)
  }

  // ──────────────────────────────────────────────
  // 底部操作栏：收藏 + 完成
  // 使用 backdropBlur 实现毛玻璃浮层效果
  // ──────────────────────────────────────────────
  @Builder
  private BottomBar() {
    Row({ space: DSSpace.MD }) {
      // 收藏按钮
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

      // 完成按钮
      Text('完成')
        .fontSize(DSType.BODY)
        .fontColor(Color.White)
        .fontWeight(FontWeight.Medium)
        .padding({ left: 30, right: 30, top: 12, bottom: 12 })
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
    // 整体 Stack：内容列 + Toast + 专注模式覆层
    Stack() {
      Column() {
        // 自定义拖拽条（bindSheet 已设置 dragBar:false，此处为精致替代）
        this.DragHandle()

        // 可滚动内容区 - 包含菜品头部信息、标签和所有内容
        // nestedScroll 策略：
        //   - 向下（SELF_FIRST）：列表内容优先滚动，到底后传给父级面板上拉展开
        //   - 向上（PARENT_FIRST）：顶部拉取时先交给面板处理（吸附收起），再由列表响应
        Scroll(this.contentScroller) {
          Column({ space: DSSpace.MD }) {
            // 菜品头部信息（现在可以随内容一起滚动）
            this.HeroSection()
            
            // 标签组
            this.TagsSection()
            
            // 内容卡片
            this.SectionCard('食材', this.detail.stuff, '暂无食材信息', true)
            this.SectionCard('烹饪工具', this.detail.tools, '暂无工具信息')
            this.StepsSection()
            
            // 底部留白
            Row().height(DSSpace.SM)
          }
          .padding({ left: DSSpace.LG, right: DSSpace.LG, bottom: DSSpace.SM })
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .scrollBarColor('#803B4968')
        .scrollBarWidth(3)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false })
        // 阻尼系数：0.78 让手指离开后快速减速，避免过度惯性遮挡内容
        .friction(DSSheet.SCROLL_FRICTION)
        // 核心嵌套滚动配置：解决列表滑动与面板拖拽之间的手势冲突
        .nestedScroll({
          scrollForward: NestedScrollMode.SELF_FIRST,
          scrollBackward: NestedScrollMode.PARENT_FIRST
        })

        // 底部毛玻璃操作栏（固定不随内容滚动）
        this.BottomBar()
      }
      .width('100%')
      .height('100%')

      // Toast 轻提示（浮层，不干扰主内容触控）
      ToastView({ message: this.toastMessage, visible: this.toastVisible })

      // 专注烹饪模式（全屏覆层，步骤卡片轮播）
      CookingFocusView({
        visible: $focusModeVisible,
        recipeName: this.detail.name,
        steps: this.detail.steps
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_COLOR) // 使用应用主题背景色，不透明
  }
}
