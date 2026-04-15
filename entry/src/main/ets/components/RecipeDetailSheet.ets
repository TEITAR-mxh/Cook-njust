/**
 * 菜谱详情半模态弹窗组件（重构版）
 * - 移除全部视频跳转相关逻辑
 * - 新增标签行、分类食材/工具区、烹饪步骤区
 * - Scroll 容器保证内容超屏可滚动
 * - aboutToAppear 预留 RecipeDBManager 接口位置
 */
import { pasteboard } from '@kit.BasicServicesKit'
import { AppColors } from '../constants/AppColors'
import type { RecipeWithId } from '../model/recipe'
import { RecipeDBManager } from '../data/RecipeDBManager'
import { ShoppingListService } from '../service/ShoppingListService'
import { CookingFocusView } from './CookingFocusView'
import { ToastView } from './ToastView'

// ─────────────────────────────────────────────────────────────
// 数据接口
// ─────────────────────────────────────────────────────────────

/** 详情页专用模型：在 RecipeWithId 基础上扩展 steps */
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

// ─────────────────────────────────────────────────────────────
// Mock 数据（DB 接口就绪前用于 UI 预览）
// ─────────────────────────────────────────────────────────────

const MOCK_DETAIL: RecipeDetail = {
  id: 0,
  name: '番茄炒鸡蛋',
  emojis: ['🍅', '🥚'],
  difficulty: '简单',
  tags: ['家常菜', '快手', '下饭', '素食可选'],
  stuff: ['番茄', '鸡蛋', '葱', '食盐', '食用油', '白糖'],
  tools: ['炒锅', '锅铲'],
  steps: [
    '鸡蛋打入碗中，加少许盐，用筷子充分打散备用。',
    '番茄洗净后切成滚刀块，葱洗净后切末备用。',
    '锅中倒入食用油，大火烧至七成热，倒入蛋液，用锅铲划散炒至金黄后盛出。',
    '锅中再加少许油，下葱末爆香，放入番茄块翻炒约 1 分钟，炒出番茄汁。',
    '加入炒好的鸡蛋，翻炒均匀，根据口味加盐和少量白糖提鲜调味。',
    '出锅装盘，趁热享用。',
  ],
}

// ─────────────────────────────────────────────────────────────
// 标签颜色池
// ─────────────────────────────────────────────────────────────

interface TagColor {
  bg: string
  text: string
}

const TAG_PALETTE: TagColor[] = [
  { bg: '#FEF2F2', text: '#DC2626' },
  { bg: '#F0FDF4', text: '#16A34A' },
  { bg: '#FFFBEB', text: '#D97706' },
  { bg: '#EFF6FF', text: '#2563EB' },
  { bg: '#F5F3FF', text: '#7C3AED' },
]

function pickTagColor(index: number): TagColor {
  return TAG_PALETTE[index % TAG_PALETTE.length]
}

// ─────────────────────────────────────────────────────────────
// 组件
// ─────────────────────────────────────────────────────────────

@Component
export struct RecipeDetailSheet {
  @Link @Watch('onVisibleChange') isVisible: boolean
  @Prop recipe: RecipeWithId | null = null
  @Prop selectedStuff: string[] = []
  @Prop isFavorite: boolean = false

  onFavoriteToggle?: () => void

  @State private translateY: number = 1000
  @State private opacityValue: number = 0
  @State private detail: RecipeDetail = MOCK_DETAIL
  @State private loadState: string = 'loading'  // 'loading' | 'ok' | 'empty'
  @State private focusModeVisible: boolean = false
  @State private toastMessage: string = ''
  @State private toastVisible: boolean = false

  // ── 生命周期 ────────────────────────────────────────────────

  aboutToAppear(): void {
    this.syncFromProp()
    // 组件始终在 isVisible 已为 true 时才被创建（父级条件渲染）。
    // ArkUI 的 @Watch 对 @Link 初始值不触发，onVisibleChange 不会自动调用，
    // 因此在此手动触发入场动画。
    animateTo({ duration: 400, curve: Curve.Friction }, () => {
      this.translateY = 0
      this.opacityValue = 1
    })
    void this.loadStepsFromDB()
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
        }
        this.loadState = 'ok'
      } else {
        this.loadState = 'empty'
      }
    } catch {
      this.loadState = 'empty'
    }
  }

  // ── 私有方法 ─────────────────────────────────────────────────

  /** 将 @Prop recipe 映射到本地 detail（steps 等待 DB 填充） */
  private syncFromProp(): void {
    if (!this.recipe) {
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
      steps: [],
    }
  }

  private showToast(message: string): void {
    this.toastMessage = message
    this.toastVisible = false
    setTimeout(() => {
      this.toastVisible = true
    }, 0)
  }

  private handleCopyMissingItems(): void {
    const diffResult = ShoppingListService.diff(this.selectedStuff, this.detail.stuff)
    if (diffResult.missingItems.length === 0) {
      this.showToast('食材已齐，可以开做了！')
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
      console.error('Copy to clipboard failed', JSON.stringify(err))
      this.showToast('复制失败，请稍后重试')
    }
  }

  private closeSheet(): void {
    this.isVisible = false
  }

  onVisibleChange(): void {
    if (this.isVisible) {
      // 重新打开（组件已挂载但 isVisible 从 false 变 true）时刷新数据并播放入场。
      // 首次打开的入场动画由 aboutToAppear 负责，此处处理重复打开场景。
      this.syncFromProp()
      void this.loadStepsFromDB()
      animateTo({ duration: 400, curve: Curve.Friction }, () => {
        this.translateY = 0
        this.opacityValue = 1
      })
    } else {
      // 关闭动画
      animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
        this.translateY = 1000
        this.opacityValue = 0
      })
    }
  }

  // ── @Builder：拖拽指示器 ────────────────────────────────────

  @Builder
  DragHandle() {
    Column() {
      Column()
        .width(40)
        .height(5)
        .backgroundColor('rgba(0,0,0,0.15)')
        .borderRadius(10)
        .margin({ top: 12, bottom: 10 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#FFF5EB')
    .borderRadius({ topLeft: 28, topRight: 28 })
    .onClick(() => this.closeSheet())
  }

  // ── @Builder：Hero 区（Emoji + 菜名 + 难度） ────────────────

  @Builder
  HeroSection() {
    Column({ space: 8 }) {
      Text(this.detail.emojis.length > 0 ? this.detail.emojis.join('') : '🍽️')
        .fontSize(72)

      Text(this.detail.name)
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.GRAY_900)
        .textAlign(TextAlign.Center)

      if (this.detail.difficulty.length > 0) {
        Text(this.detail.difficulty)
          .fontSize(12)
          .fontColor(AppColors.GRAY_500)
          .padding({ left: 12, right: 12, top: 4, bottom: 4 })
          .backgroundColor(AppColors.GRAY_100)
          .borderRadius(20)
      }
    }
    .width('100%')
    .padding({ top: 16, bottom: 20 })
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#FFF5EB')
  }

  // ── @Builder：标签行 ────────────────────────────────────────

  @Builder
  TagsSection() {
    if (this.detail.tags.length > 0) {
      Column({ space: 0 }) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.detail.tags, (tag: string, index: number) => {
            Text(`# ${tag}`)
              .fontSize(12)
              .fontColor(pickTagColor(index).text)
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .backgroundColor(pickTagColor(index).bg)
              .borderRadius(20)
              .margin({ right: 8, bottom: 8 })
          }, (tag: string) => tag)
        }
        .width('100%')
        .padding({ left: 20, right: 12, top: 16, bottom: 8 })

        Divider()
          .color(AppColors.GRAY_100)
          .margin({ left: 20, right: 20 })
      }
    }
  }

  // ── @Builder：分类列表区（食材 / 工具） ─────────────────────

  @Builder
  ItemListSection(title: string, items: string[], emptyHint: string, allowCopyAction: boolean = false) {
    Column({ space: 10 }) {
      Row() {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.GRAY_800)

        Blank()

        if (allowCopyAction) {
          Text('复制缺料')
            .fontSize(12)
            .fontColor(AppColors.BRAND_COLOR)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(AppColors.GRAY_100)
            .borderRadius(10)
            .onClick(() => {
              this.handleCopyMissingItems()
            })
        }
      }
      .width('100%')

      if (items.length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(items, (item: string) => {
            Text(item)
              .fontSize(13)
              .fontColor(AppColors.GRAY_600)
              .padding({ left: 12, right: 12, top: 5, bottom: 5 })
              .backgroundColor(AppColors.GRAY_50)
              .borderRadius(8)
              .borderWidth(1)
              .borderColor(AppColors.GRAY_200)
              .margin({ right: 8, bottom: 8 })
          }, (item: string) => item)
        }
        .width('100%')
      } else {
        Text(emptyHint)
          .fontSize(13)
          .fontColor(AppColors.GRAY_400)
          .padding({ top: 8, bottom: 16 })
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  // ── @Builder：烹饪步骤区 ────────────────────────────────────

  @Builder
  StepsSection() {
    Column({ space: 0 }) {
      Row() {
        Text('烹饪步骤')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.GRAY_800)

        Blank()

        Text('专注模式')
          .fontSize(12)
          .fontColor(AppColors.BRAND_COLOR)
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor(AppColors.GRAY_100)
          .borderRadius(10)
          .onClick(() => {
            if (this.detail.steps.length > 0) {
              this.focusModeVisible = true
            } else {
              this.showToast('暂无烹饪步骤信息')
            }
          })
      }
      .padding({ left: 20, right: 20, top: 16, bottom: 12 })
      .width('100%')

      if (this.loadState === 'loading') {
        Row({ space: 8 }) {
          LoadingProgress()
            .width(20)
            .height(20)
            .color(AppColors.BRAND_COLOR)
          Text('加载中')
            .fontSize(13)
            .fontColor(AppColors.GRAY_400)
        }
        .padding({ left: 20, top: 8, bottom: 20 })
      } else if (this.loadState === 'ok' && this.detail.steps.length > 0) {
        ForEach(this.detail.steps, (step: string, index: number) => {
          Row({ space: 12 }) {
            Text(`${index + 1}`)
              .fontSize(12)
              .fontColor(Color.White)
              .fontWeight(FontWeight.Bold)
              .width(24)
              .height(24)
              .textAlign(TextAlign.Center)
              .backgroundColor(AppColors.BRAND_COLOR)
              .borderRadius(12)

            Text(step)
              .fontSize(14)
              .fontColor(AppColors.GRAY_600)
              .lineHeight(22)
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 12, bottom: 12 })
          .alignItems(VerticalAlign.Top)
          .backgroundColor(index % 2 === 0 ? Color.White : AppColors.GRAY_50)
        }, (step: string, index: number) => `${index}-${step}`)
      } else {
        Text('暂无烹饪步骤信息')
          .fontSize(13)
          .fontColor(AppColors.GRAY_400)
          .padding({ left: 20, right: 20, top: 8, bottom: 16 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // ── @Builder：底部操作栏 ────────────────────────────────────

  @Builder
  BottomBar() {
    Row() {
      // 收藏按钮
      Row({ space: 6 }) {
        Text(this.isFavorite ? '★' : '☆')
          .fontSize(20)
          .fontColor(this.isFavorite ? '#FFB020' : AppColors.GRAY_400)

        Text(this.isFavorite ? '已收藏' : '收藏')
          .fontSize(14)
          .fontColor(this.isFavorite ? '#D97706' : AppColors.GRAY_500)
      }
      .padding({ left: 20, right: 20, top: 11, bottom: 11 })
      .backgroundColor(this.isFavorite ? '#FFFBEB' : AppColors.GRAY_50)
      .borderRadius(14)
      .borderWidth(1)
      .borderColor(this.isFavorite ? '#FDE047' : AppColors.GRAY_200)
      .onClick(() => {
        if (this.onFavoriteToggle) {
          this.onFavoriteToggle()
        }
      })

      Blank()

      // 完成按钮
      Text('完成')
        .fontSize(14)
        .fontColor(Color.White)
        .fontWeight(FontWeight.Medium)
        .padding({ left: 32, right: 32, top: 12, bottom: 12 })
        .backgroundColor(AppColors.BRAND_COLOR)
        .borderRadius(14)
        .onClick(() => this.closeSheet())
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 24 })
    .backgroundColor(Color.White)
    .borderWidth({ top: 1 })
    .borderColor(AppColors.GRAY_100)
  }

  // ── 主 build ─────────────────────────────────────────────────

  build() {
    if (this.recipe) {
      Stack() {
        // 背景遮罩
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0.35)')
          .opacity(this.opacityValue)
          .onClick(() => this.closeSheet())

        // 弹窗面板
        Column() {
          // 拖拽指示器
          this.DragHandle()

          // Hero 头部
          this.HeroSection()

          // 可滚动内容区
          Scroll() {
            Column({ space: 0 }) {
              // 标签行（无标签时自动隐藏）
              this.TagsSection()

              // 食材
              this.ItemListSection('🧂 食材', this.detail.stuff, '暂无食材信息', true)

              Divider()
                .color(AppColors.GRAY_100)
                .margin({ left: 20, right: 20 })

              // 工具
              this.ItemListSection('🍳 工具', this.detail.tools, '暂无工具信息')

              Divider()
                .color(AppColors.GRAY_100)
                .margin({ left: 20, right: 20 })

              // 烹饪步骤
              this.StepsSection()
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .backgroundColor(Color.White)

          // 底部操作栏
          this.BottomBar()
        }
        .width('100%')
        .height('92%')
        .backgroundColor(Color.White)
        .borderRadius({ topLeft: 28, topRight: 28 })
        .shadow({ radius: 40, color: 'rgba(0,0,0,0.12)', offsetX: 0, offsetY: -10 })
        .translate({ y: this.translateY })
        .alignSelf(ItemAlign.End)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])

        ToastView({ message: this.toastMessage, visible: this.toastVisible })

        CookingFocusView({
          visible: $focusModeVisible,
          recipeName: this.detail.name,
          steps: this.detail.steps
        })
      }
      .width('100%')
      .height('100%')
    }
  }
}