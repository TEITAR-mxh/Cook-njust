/**
 * 从「一道菜」到「一餐」：由入口选定人数，一键生成可编辑套餐，多菜聚合采购清单。
 */
import { common } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI'
import { AppColors, ThemeManager } from '../constants/AppColors'
import { RecipeRepository } from '../data/RecipeRepository'
import { CookPreferences } from '../store/CookPreferences'
import type { MealPlan, DishType, MeatRatio } from '../model/mealPlan'
import type { RecipeWithId, StuffItem } from '../model/recipe'
import type { MissingItem } from '../service/ShoppingListService'
import { MealPlanService } from '../service/MealPlanService'
import { DishTypeClassifier } from '../service/DishTypeClassifier'
import { ExportShoppingListDialog } from '../components/ExportShoppingListDialog'
import { RecipeImage, RecipeImageVariant } from '../components/RecipeImage'
import { getRecipeEmoji, toolItems } from '../data/foodCatalog'
import { getSystemSafeTopVp } from '../util/StatusBarInset'

interface Slot {
  recipe: RecipeWithId
  locked: boolean
}

interface MealPlanParams {
  people: number
}

@Entry
@Component
struct MealPlanPage {
  @State people: number = 2
  @State meatRatio: MeatRatio = '均衡'
  @State availableTools: string[] = []
  @State slots: Slot[] = []
  @State aggregated: MissingItem[] = []
  @State dialogVisible: boolean = false
  @State toastMsg: string = ''
  @State toastVisible: boolean = false

  @StorageProp('isSystemDarkMode')
  @Watch('onThemeChange')
  isSystemDark: boolean = false

  @StorageProp('currentThemeMode')
  @Watch('onThemeChange')
  storedThemeMode: string = '系统默认'

  @State themeMode: string = '系统默认'
  @State currentBgColor: string = AppColors.BG_COLOR
  @State currentCardBgColor: string = AppColors.CARD_BG
  @State currentTextColor: string = AppColors.GRAY_900
  @State currentSecondaryTextColor: string = AppColors.GRAY_500
  @State currentBorderColor: string = AppColors.GRAY_100
  @State safeTopVp: number = 48

  private getHostContext(): common.UIAbilityContext | undefined {
    return this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
  }

  aboutToAppear(): void {
    this.updateThemeColors()
    const params = router.getParams() as MealPlanParams
    if (params?.people && params.people >= 1 && params.people <= 6) {
      this.people = params.people
    }
    void this.init()
  }

  onPageShow(): void {
    this.updateThemeColors()
  }

  private onThemeChange(): void {
    this.updateThemeColors()
  }

  private updateThemeColors(): void {
    this.themeMode = this.storedThemeMode
    this.currentBgColor = ThemeManager.getBackgroundColor(this.themeMode)
    this.currentCardBgColor = ThemeManager.getCardBackgroundColor(this.themeMode)
    this.currentTextColor = ThemeManager.getTextColor(this.themeMode)
    this.currentSecondaryTextColor = ThemeManager.getSecondaryTextColor(this.themeMode)
    this.currentBorderColor = ThemeManager.getBorderColor(this.themeMode)
  }

  private async init(): Promise<void> {
    const host = this.getHostContext()
    if (!host) {
      return
    }
    this.safeTopVp = await getSystemSafeTopVp(host)
    if (RecipeRepository.getInstance().getAll().length === 0) {
      try {
        await RecipeRepository.getInstance().load(host)
      } catch (_e) {
        // ignore
      }
    }
    const saved = await CookPreferences.getMealPlan(host)
    if (saved !== null) {
      this.meatRatio = saved.meatRatio
      this.availableTools = saved.tools
      if (saved.people === this.people) {
        this.slots = this.rebuildSlots(saved.dishIds, saved.locked)
      } else {
        this.generateFull()
      }
    } else {
      this.generateFull()
    }
    this.refreshAggregated()
  }

  private rebuildSlots(ids: number[], locked: boolean[]): Slot[] {
    const out: Slot[] = []
    for (let i = 0; i < ids.length; i++) {
      const r = RecipeRepository.getInstance().getById(ids[i])
      if (r !== null) {
        out.push({ recipe: r, locked: locked[i] === true })
      }
    }
    return out
  }

  private refreshAggregated(): void {
    const recipes: RecipeWithId[] = []
    for (const s of this.slots) {
      recipes.push(s.recipe)
    }
    this.aggregated = MealPlanService.aggregateIngredients(recipes)
  }

  private generateFull(): void {
    const recipes = RecipeRepository.getInstance().getAll()
    const picked = MealPlanService.generateMealPlan(recipes, this.people, this.meatRatio, this.availableTools)
    const next: Slot[] = []
    for (const r of picked) {
      next.push({ recipe: r, locked: false })
    }
    this.slots = next
    this.refreshAggregated()
  }

  private regenerateUnlocked(): void {
    const lockedSlots = this.slots.filter((s: Slot) => s.locked)
    const lockedIds = new Set<number>()
    for (const s of lockedSlots) {
      lockedIds.add(s.recipe.id)
    }
    const targetCount = Math.max(2, Math.min(6, this.people + 1))
    const recipes = RecipeRepository.getInstance().getAll()
    const picked = MealPlanService.generateMealPlan(recipes, this.people, this.meatRatio, this.availableTools)
    const next: Slot[] = lockedSlots.slice()
    for (const r of picked) {
      if (next.length >= targetCount) {
        break
      }
      if (lockedIds.has(r.id)) {
        continue
      }
      next.push({ recipe: r, locked: false })
    }
    this.slots = next
    this.refreshAggregated()
  }

  private rerollSlot(index: number): void {
    if (this.slots[index].locked) {
      return
    }
    const exclude = new Set<number>()
    for (const s of this.slots) {
      exclude.add(s.recipe.id)
    }
    const recipes = RecipeRepository.getInstance().getAll()
    const pool: RecipeWithId[] = []
    for (const r of recipes) {
      if (!exclude.has(r.id)) {
        pool.push(r)
      }
    }
    if (pool.length === 0) {
      return
    }
    const r = pool[Math.floor(Math.random() * pool.length)]
    this.slots[index] = { recipe: r, locked: false }
    this.slots = this.slots.slice()
    this.refreshAggregated()
  }

  private removeSlot(index: number): void {
    this.slots.splice(index, 1)
    this.slots = this.slots.slice()
    this.refreshAggregated()
  }

  private toggleLock(index: number): void {
    const s = this.slots[index]
    this.slots[index] = { recipe: s.recipe, locked: !s.locked }
    this.slots = this.slots.slice()
  }

  private toggleTool(name: string): void {
    const idx = this.availableTools.indexOf(name)
    if (idx >= 0) {
      this.availableTools.splice(idx, 1)
    } else {
      this.availableTools.push(name)
    }
    this.availableTools = this.availableTools.slice()
  }

  private changePeople(delta: number): void {
    const next = this.people + delta
    if (next < 1 || next > 6) {
      return
    }
    this.people = next
  }

  private relaxTools(): void {
    this.availableTools = []
    this.regenerateUnlocked()
  }

  private async savePlan(): Promise<void> {
    const host = this.getHostContext()
    if (!host) {
      return
    }
    const plan: MealPlan = {
      people: this.people,
      meatRatio: this.meatRatio,
      tools: this.availableTools,
      dishIds: this.slots.map((s: Slot) => s.recipe.id),
      locked: this.slots.map((s: Slot) => s.locked),
      updatedAt: Date.now()
    }
    await CookPreferences.setMealPlan(host, plan)
    this.showToast('套餐已保存')
  }

  private showToast(msg: string): void {
    this.toastMsg = msg
    this.toastVisible = true
    setTimeout(() => {
      this.toastVisible = false
    }, 2000)
  }

  private dishTypeOf(r: RecipeWithId): DishType {
    return DishTypeClassifier.classifyDish(r.stuff ?? [])
  }

  private dishTypeText(t: DishType): string {
    if (t === '荤') {
      return ThemeManager.getColor(AppColors.MEAT_TEXT, AppColors.DARK_MEAT_TEXT, this.themeMode)
    }
    if (t === '主食') {
      return ThemeManager.getColor(AppColors.CARB_TEXT, AppColors.DARK_CARB_TEXT, this.themeMode)
    }
    return ThemeManager.getColor(AppColors.VEG_TEXT, AppColors.DARK_VEG_TEXT, this.themeMode)
  }

  private dishTypeBg(t: DishType): string {
    if (t === '荤') {
      return ThemeManager.getColor(AppColors.MEAT_BG, AppColors.DARK_MEAT_BG, this.themeMode)
    }
    if (t === '主食') {
      return ThemeManager.getColor(AppColors.CARB_BG, AppColors.DARK_CARB_BG, this.themeMode)
    }
    return ThemeManager.getColor(AppColors.VEG_BG, AppColors.DARK_VEG_BG, this.themeMode)
  }

  @Builder
  meatRatioChip(label: MeatRatio) {
    Text(label)
      .fontSize(13)
      .fontColor(this.meatRatio === label ? Color.White : this.currentTextColor)
      .padding({ left: 16, right: 16, top: 7, bottom: 7 })
      .backgroundColor(this.meatRatio === label ? AppColors.BRAND_COLOR : this.currentBorderColor)
      .borderRadius(100)
      .onClick(() => { this.meatRatio = label })
  }

  @Builder
  toolChip(item: StuffItem) {
    Text(`${item.emoji} ${item.name}`)
      .fontSize(12)
      .fontColor(this.availableTools.includes(item.name) ? AppColors.BRAND_COLOR : this.currentTextColor)
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .backgroundColor(this.availableTools.includes(item.name) ? AppColors.BRAND_COLOR_LIGHT : this.currentBorderColor)
      .borderWidth(this.availableTools.includes(item.name) ? 1 : 0)
      .borderColor(AppColors.BRAND_COLOR)
      .borderRadius(100)
      .margin({ right: 8, bottom: 8 })
      .onClick(() => { this.toggleTool(item.name) })
  }

  @Builder
  buildSlot(slot: Slot, index: number) {
    Row({ space: 12 }) {
      RecipeImage({
        imageKey: slot.recipe.imageUri ?? '',
        emoji: getRecipeEmoji(slot.recipe.stuff ?? []),
        variant: RecipeImageVariant.THUMB,
        placeholderBg: this.currentBorderColor,
        cornerRadius: 10
      })
      .width(48)
      .height(48)
      .flexShrink(0)

      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text(slot.recipe.name)
            .fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.currentTextColor)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          Text(this.dishTypeOf(slot.recipe))
            .fontSize(10)
            .fontColor(this.dishTypeText(this.dishTypeOf(slot.recipe)))
            .padding({ left: 6, right: 6, top: 1, bottom: 1 })
            .backgroundColor(this.dishTypeBg(this.dishTypeOf(slot.recipe)))
            .borderRadius(100)
            .flexShrink(0)
        }.width('100%')
        Text(`${slot.recipe.stuff.length} 种食材`)
          .fontSize(11).fontColor(this.currentSecondaryTextColor)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)

      // 锁定 / 换一道 / 移除（统一圆底，锁定态用品牌色强调）
      Column() {
        Text(slot.locked ? '🔒' : '🔓').fontSize(14)
      }
      .width(34).height(34).borderRadius(17)
      .backgroundColor(slot.locked ? AppColors.BRAND_COLOR_LIGHT : this.currentBorderColor)
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .onClick(() => { this.toggleLock(index) })
      .flexShrink(0)

      Column() {
        Text('🔄').fontSize(14)
      }
      .width(34).height(34).borderRadius(17)
      .backgroundColor(this.currentBorderColor)
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .opacity(slot.locked ? 0.35 : 1)
      .onClick(() => { this.rerollSlot(index) })
      .flexShrink(0)

      Column() {
        Text('✕').fontSize(14).fontColor(this.currentSecondaryTextColor)
      }
      .width(34).height(34).borderRadius(17)
      .backgroundColor(this.currentBorderColor)
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .onClick(() => { this.removeSlot(index) })
      .flexShrink(0)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor(this.currentCardBgColor)
    .borderWidth(0.5)
    .borderColor(this.currentBorderColor)
    .borderRadius(16)
    .shadow({ radius: 8, color: '#08000000', offsetX: 0, offsetY: 2 })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Stack() {
      Column() {
        // 顶部导航栏
        Row() {
          Row() {
            SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([this.currentTextColor])
          }
          .width(48).height(48).justifyContent(FlexAlign.Center)
          .onClick(() => {
            try {
              this.getUIContext().getRouter().back()
            } catch (_e) {
              // ignore
            }
          })
          Text(`${this.people} 人一餐`)
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.currentTextColor)
            .layoutWeight(1).textAlign(TextAlign.Center).padding({ right: 48 })
        }
        .width('100%')
        .padding({ top: this.safeTopVp, bottom: 4 })
        .backgroundColor(this.currentBgColor)

        Scroll() {
          Column({ space: 12 }) {
            // ── 生成配置卡 ──
            Column({ space: 12 }) {
              // 用餐人数
              Row() {
                Column({ space: 3 }) {
                  Text('用餐人数')
                    .fontSize(15).fontColor(this.currentTextColor)
                  Text('按人数自动决定菜数')
                    .fontSize(11).fontColor(this.currentSecondaryTextColor)
                }
                .alignItems(HorizontalAlign.Start)
                Blank()
                Row({ space: 10 }) {
                  Column() {
                    Text('－').fontSize(16).fontColor(this.currentTextColor)
                  }
                  .width(30).height(30).borderRadius(15)
                  .backgroundColor(this.currentBorderColor)
                  .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
                  .onClick(() => { this.changePeople(-1) })

                  Text(`${this.people}`)
                    .fontSize(17).fontWeight(FontWeight.Bold).fontColor(this.currentTextColor)
                    .width(36).textAlign(TextAlign.Center)

                  Column() {
                    Text('＋').fontSize(16).fontColor(this.currentTextColor)
                  }
                  .width(30).height(30).borderRadius(15)
                  .backgroundColor(this.currentBorderColor)
                  .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
                  .onClick(() => { this.changePeople(1) })
                }
              }
              .width('100%')

              Divider().color(this.currentBorderColor)

              // 荤素搭配
              Column({ space: 8 }) {
                Text('荤素搭配')
                  .fontSize(15).fontColor(this.currentTextColor)
                Row({ space: 8 }) {
                  this.meatRatioChip('均衡')
                  this.meatRatioChip('偏素')
                  this.meatRatioChip('偏荤')
                }
                .width('100%')
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)

              Divider().color(this.currentBorderColor)

              // 可用厨具
              Column({ space: 8 }) {
                Text('可用厨具')
                  .fontSize(15).fontColor(this.currentTextColor)
                Text('可选，选中后只推荐能做的菜')
                  .fontSize(11).fontColor(this.currentSecondaryTextColor)
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(toolItems, (it: StuffItem) => {
                    this.toolChip(it)
                  }, (it: StuffItem) => `tool-${it.name}`)
                }
                .width('100%')
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)

              Button('生成一餐')
                .width('100%').height(46)
                .fontSize(15).fontWeight(FontWeight.Bold).fontColor(Color.White)
                .backgroundColor(AppColors.BRAND_COLOR).borderRadius(23)
                .onClick(() => { this.regenerateUnlocked() })
            }
            .width('100%')
            .padding(16)
            .backgroundColor(this.currentCardBgColor)
            .borderWidth(0.5).borderColor(this.currentBorderColor).borderRadius(16)
            .shadow({ radius: 8, color: '#08000000', offsetX: 0, offsetY: 2 })

            // ── 套餐列表 ──
            if (this.slots.length > 0) {
              Column({ space: 12 }) {
                Row() {
                  Text('套餐')
                    .fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.currentTextColor)
                  Text(`${this.slots.length} 道`).fontSize(11).fontColor(AppColors.BRAND_COLOR)
                    .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                    .backgroundColor(AppColors.BRAND_COLOR_LIGHT).borderRadius(100)
                  Blank()
                  Text('重新生成').fontSize(13).fontColor(AppColors.BRAND_COLOR)
                    .onClick(() => { this.regenerateUnlocked() })
                }.width('100%')

                ForEach(this.slots, (slot: Slot, index: number) => {
                  this.buildSlot(slot, index)
                }, (slot: Slot, index: number) => `slot-${slot.recipe.id}-${index}`)

                Text('🔒 锁定后「重新生成」不会替换该道菜')
                  .fontSize(11).fontColor(this.currentSecondaryTextColor)
                  .width('100%')
                  .padding({ left: 2 })
              }
              .width('100%')
            } else {
              // ── 空态 ──
              Column({ space: 12 }) {
                Text('🍽️').fontSize(48)
                Text('还没有生成套餐')
                  .fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.currentTextColor)
                Text(this.availableTools.length > 0
                  ? '当前厨具约束下没有可做的菜，可放宽约束重试'
                  : '点击上方「生成一餐」开始搭配')
                  .fontSize(13).fontColor(this.currentSecondaryTextColor)
                  .textAlign(TextAlign.Center)
                if (this.availableTools.length > 0) {
                  Button('放宽厨具约束')
                    .fontSize(14).fontColor(AppColors.BRAND_COLOR)
                    .backgroundColor(AppColors.BRAND_COLOR_LIGHT)
                    .borderRadius(20).height(40).padding({ left: 20, right: 20 })
                    .onClick(() => { this.relaxTools() })
                }
              }
              .width('100%')
              .padding({ top: 36, bottom: 36 })
              .alignItems(HorizontalAlign.Center)
            }

            // 底部留白
            Column().height(28)
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 12 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
        .align(Alignment.Top)

        // ── 底部操作栏 ──
        Row({ space: 12 }) {
          Button('保存套餐')
            .layoutWeight(1).height(50)
            .fontSize(15).fontWeight(FontWeight.Medium)
            .fontColor(this.currentTextColor)
            .backgroundColor(this.currentBorderColor)
            .borderRadius(25)
            .onClick(() => { void this.savePlan() })
          Button('聚合采购清单')
            .layoutWeight(1).height(50)
            .fontSize(15).fontWeight(FontWeight.Bold).fontColor(Color.White)
            .backgroundColor(AppColors.BRAND_COLOR)
            .borderRadius(25)
            .enabled(this.slots.length > 0)
            .onClick(() => { this.dialogVisible = true })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 10, bottom: 12 })
        .backgroundColor(this.currentCardBgColor)
      }
      .width('100%').height('100%')
      .backgroundColor(this.currentBgColor)

      // ── 采购清单弹窗 ──
      ExportShoppingListDialog({
        missingItems: this.aggregated,
        recipeName: `${this.people} 人一餐`,
        totalStuff: this.aggregated.length,
        visible: this.dialogVisible,
        onClose: () => { this.dialogVisible = false }
      })

      // ── Toast ──
      if (this.toastVisible) {
        Row() {
          Text(this.toastMsg)
            .fontSize(14).fontColor(Color.White)
            .padding({ left: 20, right: 20, top: 10, bottom: 10 })
        }
        .backgroundColor('#DD333333')
        .borderRadius(20).backdropBlur(12)
        .position({ x: '50%', y: '40%' })
        .translate({ x: '-50%', y: '-50%' })
      }
    }
    .width('100%').height('100%')
  }
}
