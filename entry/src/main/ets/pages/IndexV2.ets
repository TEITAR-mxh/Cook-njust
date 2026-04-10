/**
 * 您吃了么 - 主页面
 * 保留原 Index.ets 的所有业务逻辑,应用原型的视觉设计
 * 新增功能:
 * - 毛玻璃底部导航
 * - 食材标签彩色分类
 * - 随机搭配动画
 * - 半模态菜谱详情
 * - 餐桌瓷盘3D效果
 */
import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { meatItems, stapleItems, toolItems, vegetableItems } from '../data/foodCatalog';
import { RecipeRepository } from '../data/RecipeRepository';
import type { RecipeWithId, SearchMode, StuffItem } from '../model/recipe';
import { RecipeSearchService } from '../service/RecipeSearchService';
import { CookPreferences } from '../store/CookPreferences';
import { getSystemSafeTopVp } from '../util/StatusBarInset';
import { AppColors } from '../constants/AppColors';
import { IngredientTag, TagType } from '../components/IngredientTag';
import { IngredientTypeMapper } from '../utils/IngredientTypeMapper';
import { ToastView } from '../components/ToastView';
import { RandomPickerButton } from '../components/RandomPickerButton';
import { RecipeDetailSheet } from '../components/RecipeDetailSheet';
import { PlateCard } from '../components/PlateCard';
import { RecipeCard, RecipeCardMode } from '../components/RecipeCard';

@Entry
@Component
struct IndexV2 {
  // ===== 保留原有的所有状态变量 =====
  @State mainTabIndex: number = 0
  @State status: string = '加载中…'
  @State recipeCount: number = 0
  @State errHint: string = ''
  @State keepLocalData: boolean = true
  @State selectedStuff: string[] = []
  @State curTool: string = ''
  @State searchMode: SearchMode = 'loose'
  @State keyword: string = ''
  @State searchHits: RecipeWithId[] = []
  @State libraryKeyword: string = ''
  @State libraryHits: RecipeWithId[] = []
  @State libraryActiveTag: string = '今日推荐'   // 当前激活的分类标签
  @State libraryActiveDifficulty: string = ''    // 当前激活的难度筛选，空字符串表示不筛选
  @State discoverPick: RecipeWithId = { id: -1, name: '', stuff: [], tools: [], steps: [] }
  @State historyIds: number[] = []
  @State favoriteIds: number[] = []
  @State mainNavTopInsetVp: number = 48

  // ===== 新增的 UI 状态 =====
  @State toastMessage: string = ''
  @State toastVisible: boolean = false
  @State detailSheetVisible: boolean = false
  @State selectedRecipe: RecipeWithId | null = null
  @State isRandomizing: boolean = false
  @State highlightedTags: Set<string> = new Set()
  @State tabOpacity: number = 1.0  // 页面切换动效

  // ===== 随机动画相关状态 =====
  @State randomAnimationNames: string[] = []  // 滚动显示的菜名列表
  @State currentRandomIndex: number = 0  // 当前显示的菜名索引
  @State showRandomAnimation: boolean = false  // 是否显示滚动动画

  // ===== 保留原有的所有生命周期方法(不变) =====
  aboutToAppear(): void {
    void this.bootstrapData();
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (ctx !== undefined) {
      void getSystemSafeTopVp(ctx).then((vp: number) => {
        this.mainNavTopInsetVp = vp;
      });
    }
  }

  onPageShow(): void {
    void this.refreshHistory();
    void this.refreshFavorites();
    const ctx2 = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (ctx2 !== undefined) {
      void getSystemSafeTopVp(ctx2).then((vp: number) => {
        this.mainNavTopInsetVp = vp;
      });
    }
  }

  // ===== 保留原有的所有业务逻辑方法(完全不变) =====
  private async bootstrapData(): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!host) {
      this.status = '加载失败';
      this.errHint = '无法获取 UIAbility 上下文';
      return;
    }
    try {
      this.mainNavTopInsetVp = await getSystemSafeTopVp(host);
    } catch {
      // 保持默认 mainNavTopInsetVp
    }
    try {
      await RecipeRepository.getInstance().load(host);
      this.recipeCount = RecipeRepository.getInstance().getCount();
      this.status = '菜谱已加载';
      this.errHint = '';
    } catch {
      this.status = '加载失败';
      this.recipeCount = 0;
      this.errHint = '菜谱数据加载失败';
      console.error('RecipeRepository.load failed');
      return;
    }
    // RecipeRepository.load() 内部已 await DB 初始化，getAll() 直接返回含 difficulty/methods 的完整数据

    try {
      const settings = await CookPreferences.getSettings(host);
      this.keepLocalData = settings.keepLocalData;
      if (this.keepLocalData) {
        this.selectedStuff = await CookPreferences.getSelectedStuff(host);
        this.curTool = await CookPreferences.getCurTool(host);
        this.searchMode = await CookPreferences.getSearchMode(host);
      }
    } catch {
      this.keepLocalData = true;
      console.error('CookPreferences.getSettings failed');
    }
    this.runSearch();
    this.runLibrarySearch();
    await this.refreshHistory();
    await this.refreshFavorites();
  }

  private isRecipeFavorite(recipeId: number): boolean {
    for (let i = 0; i < this.favoriteIds.length; i++) {
      if (this.favoriteIds[i] === recipeId) {
        return true;
      }
    }
    return false;
  }

  private async refreshFavorites(): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (host === undefined) {
      return;
    }
    if (!this.keepLocalData) {
      this.favoriteIds = [];
      return;
    }
    try {
      const raw = await CookPreferences.getFavoriteIds(host);
      const n = RecipeRepository.getInstance().getCount();
      const next: number[] = [];
      for (let i = 0; i < raw.length; i++) {
        const id = raw[i];
        if (id >= 0 && id < n) {
          next.push(id);
        }
      }
      this.favoriteIds = next;
    } catch {
      console.error('refreshFavorites failed');
    }
  }

  private onTapFavorite(recipeId: number): void {
    if (!this.keepLocalData) {
      return;
    }
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (host === undefined) {
      return;
    }
    void CookPreferences.toggleFavoriteId(host, recipeId).then(async () => {
      await this.refreshFavorites();
      // 显示 Toast 提示
      const isFav = this.isRecipeFavorite(recipeId);
      this.showToast(isFav ? '已添加至收藏' : '已取消收藏');
    });
  }

  private async refreshHistory(): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (host === undefined) {
      return;
    }
    if (!this.keepLocalData) {
      this.historyIds = [];
      return;
    }
    try {
      const raw = await CookPreferences.getHistoryIds(host);
      const n = RecipeRepository.getInstance().getCount();
      const next: number[] = [];
      for (let i = 0; i < raw.length; i++) {
        const id = raw[i];
        if (id >= 0 && id < n) {
          next.push(id);
        }
      }
      this.historyIds = next;
    } catch {
      console.error('refreshHistory failed');
    }
  }

  private runSearch(): void {
    const all = RecipeRepository.getInstance().getAll();
    this.searchHits = RecipeSearchService.search(all, this.selectedStuff, this.curTool, this.searchMode, this.keyword.trim());
  }

  private runLibrarySearch(): void {
    let result: RecipeWithId[];
    if (this.libraryActiveTag === '搜索结果') {
      // 搜索结果页：以冰箱筛选结果为基础，仅叠加难度过滤
      result = RecipeSearchService.filterByDifficulty(this.searchHits, this.libraryActiveDifficulty);
    } else {
      const all = RecipeRepository.getInstance().getAll();
      result = RecipeSearchService.filterLibraryByName(all, this.libraryKeyword);
      result = RecipeSearchService.filterByTag(result, this.libraryActiveTag);
      result = RecipeSearchService.filterByDifficulty(result, this.libraryActiveDifficulty);
    }
    this.libraryHits = result;
  }

  private emptyDiscoverPick(): RecipeWithId {
    const r: RecipeWithId = { id: -1, name: '', stuff: [], tools: [], steps: [] };
    return r;
  }

  private cloneRecipeForDiscoverState(source: RecipeWithId): RecipeWithId {
    const stuffCopy: string[] = [];
    for (let i = 0; i < source.stuff.length; i++) {
      stuffCopy.push(source.stuff[i]);
    }
    const toolsCopy: string[] = [];
    for (let i = 0; i < source.tools.length; i++) {
      toolsCopy.push(source.tools[i]);
    }
    const r: RecipeWithId = {
      id: source.id,
      name: source.name,
      stuff: stuffCopy,
      tools: toolsCopy,
    };
    if (source.steps !== undefined) {
      const st: string[] = [];
      for (let k = 0; k < source.steps.length; k++) {
        st.push(source.steps[k]);
      }
      r.steps = st;
    }
    if (source.emojis !== undefined) {
      const em: string[] = [];
      for (let j = 0; j < source.emojis.length; j++) {
        em.push(source.emojis[j]);
      }
      r.emojis = em;
    }
    if (source.difficulty !== undefined) {
      r.difficulty = source.difficulty;
    }
    if (source.tags !== undefined) {
      const tg: string[] = [];
      for (let j = 0; j < source.tags.length; j++) {
        tg.push(source.tags[j]);
      }
      r.tags = tg;
    }
    if (source.methods !== undefined) {
      const mh: string[] = [];
      for (let j = 0; j < source.methods.length; j++) {
        mh.push(source.methods[j]);
      }
      r.methods = mh;
    }
    return r;
  }

  private pickRandomDiscover(): void {
    const all = RecipeRepository.getInstance().getAll();
    const candidates: RecipeWithId[] = [];
    for (let i = 0; i < all.length; i++) {
      candidates.push(all[i]);
    }
    if (candidates.length === 0) {
      this.discoverPick = this.emptyDiscoverPick();
      return;
    }

    let pool: RecipeWithId[] = candidates;
    const curId = this.discoverPick.id;
    if (curId >= 0 && candidates.length > 1) {
      const filtered: RecipeWithId[] = [];
      for (let k = 0; k < candidates.length; k++) {
        if (candidates[k].id !== curId) {
          filtered.push(candidates[k]);
        }
      }
      if (filtered.length > 0) {
        pool = filtered;
      }
    }

    const idx = Math.floor(Math.random() * pool.length);
    this.discoverPick = this.cloneRecipeForDiscoverState(pool[idx]);
  }

  /**
   * 带Fancy滚动动画的随机选择
   */
  private pickRandomDiscoverWithAnimation(): void {
    if (this.isRandomizing) {
      return;
    }

    this.isRandomizing = true;
    this.showRandomAnimation = true;

    const all = RecipeRepository.getInstance().getAll();
    const candidates: RecipeWithId[] = [];
    for (let i = 0; i < all.length; i++) {
      candidates.push(all[i]);
    }

    if (candidates.length === 0) {
      this.showRandomAnimation = false;
      this.isRandomizing = false;
      this.pickRandomDiscover();
      return;
    }

    // 准备滚动动画的菜名列表 (随机打乱顺序)
    const shuffled = [...candidates].sort(() => Math.random() - 0.5);
    this.randomAnimationNames = shuffled.slice(0, Math.min(20, shuffled.length)).map(r => r.name);
    this.currentRandomIndex = 0;

    // 滚动动画: 每50ms切换一个菜名,持续1.5秒
    let counter = 0;
    const maxCount = 30;
    const interval = setInterval(() => {
      this.currentRandomIndex = (this.currentRandomIndex + 1) % this.randomAnimationNames.length;
      counter++;

      if (counter >= maxCount) {
        clearInterval(interval);
        // 动画结束,显示最终结果
        setTimeout(() => {
          this.showRandomAnimation = false;
          this.pickRandomDiscover();

          animateTo({
            duration: 400,
            curve: Curve.EaseOut
          }, () => {
            this.tabOpacity = 1.0;
          });

          this.isRandomizing = false;
        }, 200);
      }
    }, 50);

    // 淡出当前卡片
    animateTo({
      duration: 200,
      curve: Curve.EaseOut
    }, () => {
      this.tabOpacity = 0.3;
    });
  }

  private async persistCookIfNeeded(): Promise<void> {
    if (!this.keepLocalData) {
      return;
    }
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!host) {
      return;
    }
    await CookPreferences.setSelectedStuff(host, this.selectedStuff);
    await CookPreferences.setCurTool(host, this.curTool);
    await CookPreferences.setSearchMode(host, this.searchMode);
  }

  private chipLabel(item: StuffItem): string {
    const em = item.emoji;
    if (em.length > 0) {
      return `${em} ${item.name}`;
    }
    return item.name;
  }

  private toggleStuff(name: string): void {
    if (this.isRandomizing) {
      return;
    }
    const idx = this.selectedStuff.indexOf(name);
    if (idx >= 0) {
      const next: string[] = [];
      for (let i = 0; i < this.selectedStuff.length; i++) {
        if (i !== idx) {
          next.push(this.selectedStuff[i]);
        }
      }
      this.selectedStuff = next;
    } else {
      this.selectedStuff = this.selectedStuff.concat([name]);
    }
    this.runSearch();
    void this.persistCookIfNeeded();
  }

  private toggleTool(name: string): void {
    if (this.isRandomizing) {
      return;
    }
    this.curTool = this.curTool === name ? '' : name;
    this.runSearch();
    void this.persistCookIfNeeded();
  }

  private applySearchMode(mode: SearchMode): void {
    this.searchMode = mode;
    this.runSearch();
    void this.persistCookIfNeeded();
  }

  private resetSelection(): void {
    if (this.isRandomizing) {
      return;
    }
    if (this.selectedStuff.length > 0 || this.curTool.length > 0) {
      this.selectedStuff = [];
      this.curTool = '';
      this.runSearch();
      void this.persistCookIfNeeded();
      this.showToast('已清空冰箱已选食材');
    }
  }

  private async onKeepLocalChange(isOn: boolean): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!host) {
      return;
    }
    try {
      await CookPreferences.setKeepLocalData(host, isOn);
      this.keepLocalData = isOn;
      if (!isOn) {
        await CookPreferences.clearCookPersisted(host);
        this.historyIds = [];
        this.favoriteIds = [];
      } else {
        this.selectedStuff = await CookPreferences.getSelectedStuff(host);
        this.curTool = await CookPreferences.getCurTool(host);
        this.searchMode = await CookPreferences.getSearchMode(host);
        await this.refreshHistory();
        await this.refreshFavorites();
      }
      this.runSearch();
    } catch {
      console.error('CookPreferences.setKeepLocalData failed');
    }
  }

  // ===== 新增的 UI 辅助方法 =====
  private showToast(message: string): void {
    this.toastMessage = message;
    this.toastVisible = true;
    setTimeout(() => {
      this.toastVisible = false;
    }, 2500);
  }

  private openDetailSheet(recipe: RecipeWithId): void {
    this.selectedRecipe = recipe;
    this.detailSheetVisible = true;
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (host !== undefined && this.keepLocalData) {
      void CookPreferences.recordHistoryVisit(host, recipe.id).then(() => {
        void this.refreshHistory();
      });
    }
  }

  private getBackgroundColor(): string {
    // 餐桌页面使用特殊色调
    return this.mainTabIndex === 3 ? AppColors.TABLE_BG : AppColors.BG_COLOR;
  }

  /**
   * 随机搭配动画 - 盲盒闪烁效果
   * 对应原型中的 startRandomizer() 函数
   */
  private startRandomAnimation(): void {
    if (this.isRandomizing) {
      return;
    }

    this.isRandomizing = true;
    this.selectedStuff = [];
    this.curTool = '';
    this.highlightedTags = new Set();

    // 合并所有食材
    const allIngredients: string[] = [];
    meatItems.forEach(item => allIngredients.push(item.name));
    vegetableItems.forEach(item => allIngredients.push(item.name));
    stapleItems.forEach(item => allIngredients.push(item.name));

    let round = 0;
    const maxRounds = 10;

    const animationInterval = setInterval(() => {
      // 清除上一轮高亮
      this.highlightedTags = new Set();

      // 随机选3个食材高亮
      const randomIndexes: number[] = [];
      for (let i = 0; i < 3; i++) {
        randomIndexes.push(Math.floor(Math.random() * allIngredients.length));
      }
      randomIndexes.forEach(idx => {
        this.highlightedTags.add(allIngredients[idx]);
      });

      round++;

      if (round >= maxRounds) {
        clearInterval(animationInterval);
        this.highlightedTags = new Set();

        // 最终结果: 1个肉类 + 2个蔬菜
        const meatSelection = meatItems[Math.floor(Math.random() * meatItems.length)].name;
        const vegSelection1 = vegetableItems[Math.floor(Math.random() * vegetableItems.length)].name;
        let vegSelection2 = vegetableItems[Math.floor(Math.random() * vegetableItems.length)].name;

        // 确保两个蔬菜不重复
        while (vegSelection2 === vegSelection1 && vegetableItems.length > 1) {
          vegSelection2 = vegetableItems[Math.floor(Math.random() * vegetableItems.length)].name;
        }

        this.selectedStuff = [meatSelection, vegSelection1, vegSelection2];
        this.isRandomizing = false;
        this.runSearch();
        void this.persistCookIfNeeded();

        this.showToast('✨ 搭配完成，去看看做法吧！');
      }
    }, 75); // 75ms 一轮,总共 750ms
  }

  // ===== UI 构建器方法 =====

  /**
   * 「做菜」Tab - 对应原型中的 #tab-home
   */
  @Builder
  buildCookTab() {
    Stack() {
      Scroll() {
        Column({ space: 0 }) {
          // 顶部标题区域
          Row() {
            Column({ space: 4 }) {
              Text('准备做点什么？')
                .fontSize(28)
                .fontColor(AppColors.GRAY_900)
                .fontWeight(FontWeight.Bolder)
                .letterSpacing(-0.5)

              Text('点选食材，匹配最佳做法')
                .fontSize(14)
                .fontColor(AppColors.GRAY_500)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            // 清空按钮
            Text('清空')
              .fontSize(13)
              .fontColor(AppColors.GRAY_500)
              .fontWeight(FontWeight.Medium)
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
              .backgroundColor(Color.White)
              .borderRadius(100)
              .shadow({
                radius: 4,
                color: 'rgba(0,0,0,0.05)',
                offsetX: 0,
                offsetY: 2
              })
              .onClick(() => {
                this.resetSelection();
              })
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 16, bottom: 24 })
          .alignItems(VerticalAlign.Bottom)

          // 随机搭配按钮
          RandomPickerButton({
            disabled: this.isRandomizing,
            onRandomComplete: (selected: string[]) => {
              this.startRandomAnimation();
            }
          })
            .padding({ left: 20, right: 20 })

          // 食材分类区域
          Column({ space: 32 }) {
            // 🥩 肉蛋水产
            Column({ space: 12 }) {
              Text('🥩 肉蛋水产')
                .fontSize(15)
                .fontColor(AppColors.GRAY_800)
                .fontWeight(FontWeight.Bold)
                .alignSelf(ItemAlign.Start)

              Flex({
                direction: FlexDirection.Row,
                wrap: FlexWrap.Wrap,
                alignItems: ItemAlign.Center
              }) {
                ForEach(meatItems, (item: StuffItem) => {
                  IngredientTag({
                    label: item.name,
                    emoji: item.emoji,
                    tagType: TagType.MEAT,
                    isActive: this.selectedStuff.includes(item.name),
                    isHighlighted: this.highlightedTags.has(item.name),
                    onTagClick: () => {
                      this.toggleStuff(item.name);
                    }
                  })
                    .margin({ right: 10, bottom: 10 })
                }, (item: StuffItem) => item.name)
              }
              .width('100%')
            }

            // 🥬 新鲜蔬菜
            Column({ space: 12 }) {
              Text('🥬 新鲜蔬菜')
                .fontSize(15)
                .fontColor(AppColors.GRAY_800)
                .fontWeight(FontWeight.Bold)
                .alignSelf(ItemAlign.Start)

              Flex({
                direction: FlexDirection.Row,
                wrap: FlexWrap.Wrap,
                alignItems: ItemAlign.Center
              }) {
                ForEach(vegetableItems, (item: StuffItem) => {
                  IngredientTag({
                    label: item.name,
                    emoji: item.emoji,
                    tagType: TagType.VEG,
                    isActive: this.selectedStuff.includes(item.name),
                    isHighlighted: this.highlightedTags.has(item.name),
                    onTagClick: () => {
                      this.toggleStuff(item.name);
                    }
                  })
                    .margin({ right: 10, bottom: 10 })
                }, (item: StuffItem) => item.name)
              }
              .width('100%')
            }

            // 🍚 碳水辅料
            Column({ space: 12 }) {
              Text('🍚 碳水辅料')
                .fontSize(15)
                .fontColor(AppColors.GRAY_800)
                .fontWeight(FontWeight.Bold)
                .alignSelf(ItemAlign.Start)

              Flex({
                direction: FlexDirection.Row,
                wrap: FlexWrap.Wrap,
                alignItems: ItemAlign.Center
              }) {
                ForEach(stapleItems, (item: StuffItem) => {
                  IngredientTag({
                    label: item.name,
                    emoji: item.emoji,
                    tagType: TagType.CARB,
                    isActive: this.selectedStuff.includes(item.name),
                    isHighlighted: this.highlightedTags.has(item.name),
                    onTagClick: () => {
                      this.toggleStuff(item.name);
                    }
                  })
                    .margin({ right: 10, bottom: 10 })
                }, (item: StuffItem) => item.name)
              }
              .width('100%')
            }
            // 🍳 厨具
            Column({ space: 12 }) {
              Text('🍳 厨具')
                .fontSize(15)
                .fontColor(AppColors.GRAY_800)
                .fontWeight(FontWeight.Bold)
                .alignSelf(ItemAlign.Start)

              Flex({
                direction: FlexDirection.Row,
                wrap: FlexWrap.Wrap,
                alignItems: ItemAlign.Center
              }) {
                ForEach(toolItems, (item: StuffItem) => {
                  IngredientTag({
                    label: item.label ?? item.name,
                    emoji: item.emoji,
                    tagType: TagType.TOOL,
                    isActive: this.curTool === item.name,
                    isHighlighted: false,
                    onTagClick: () => {
                      this.toggleTool(item.name);
                    }
                  })
                    .margin({ right: 10, bottom: 10 })
                }, (item: StuffItem) => item.name)
              }
              .width('100%')
            }
          }
          .width('100%')
          .padding({ left: 20, right: 20 })
        }
        .width('100%')
        .padding({ bottom: 200 }) // 为底部悬浮按钮预留空间
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      // 底部悬浮生成按钮区域
      Column() {
        Button() {
          Text(this.selectedStuff.length > 0 ?
          `查看这 ${this.selectedStuff.length} 种食材能做什么` :
          '请先选择食材')
            .fontSize(15)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .height(56)
        .backgroundColor(this.selectedStuff.length > 0 ?
        AppColors.BRAND_COLOR :
        AppColors.GRAY_200)
        .borderRadius(16)
        .shadow(this.selectedStuff.length > 0 ? {
          radius: 24,
          color: 'rgba(255, 71, 87, 0.5)',
          offsetX: 0,
          offsetY: 8
        } : undefined)
        .enabled(this.selectedStuff.length > 0)
        .onClick(() => {
          if (this.selectedStuff.length > 0) {
            this.libraryActiveTag = '搜索结果';
            this.libraryActiveDifficulty = '';
            this.runLibrarySearch();
            this.mainTabIndex = 1; // 跳转到菜谱Tab
          }
        })
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 20 })
      .position({ x: 0, y: '100%' })
      .markAnchor({ y: '100%' })
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 「菜谱」Tab - 对应原型中的 #tab-discover
   */
  @Builder
  buildLibraryTab() {
    Column() {
      // 顶部固定区域(搜索栏)
      Column() {
        Text('探索')
          .fontSize(24)
          .fontColor(AppColors.GRAY_900)
          .fontWeight(FontWeight.Bolder)
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 16 })

        // 搜索栏
        Row({ space: 8 }) {
          Text('🔍')
            .fontSize(18)

          TextInput({ placeholder: '搜索菜谱、食材或 UP 主', text: this.libraryKeyword })
            .backgroundColor(Color.Transparent)
            .layoutWeight(1)
            .fontSize(15)
            .placeholderColor(AppColors.GRAY_400)
            .onChange((value: string) => {
              this.libraryKeyword = value;
              this.runLibrarySearch();
            })
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
        .backgroundColor(Color.White)
        .borderRadius(16)
        .shadow({
          radius: 10,
          color: 'rgba(0,0,0,0.03)',
          offsetX: 0,
          offsetY: 2
        })

        // 分类标签
        Scroll() {
          Row({ space: 8 }) {
            // 搜索结果标签（有冰箱筛选结果时显示）
            if (this.searchHits.length > 0) {
              Text(`🔎 搜索结果 ${this.searchHits.length}`)
                .fontSize(12)
                .fontColor(this.libraryActiveTag === '搜索结果' ? Color.White : AppColors.BRAND_COLOR)
                .fontWeight(FontWeight.Medium)
                .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                .backgroundColor(this.libraryActiveTag === '搜索结果' ? AppColors.BRAND_COLOR : '#FFF0F1')
                .borderRadius(8)
                .shadow({
                  radius: 2,
                  color: 'rgba(0,0,0,0.05)',
                  offsetX: 0,
                  offsetY: 1
                })
                .onClick(() => {
                  this.libraryActiveTag = '搜索结果';
                  this.libraryActiveDifficulty = '';
                  this.runLibrarySearch();
                })
            }

            ForEach(['今日推荐', '减脂餐', '快手早餐'], (tag: string) => {
              Text(tag === '今日推荐' ? '🔥 今日推荐' : tag)
                .fontSize(12)
                .fontColor(this.libraryActiveTag === tag ? Color.White : AppColors.GRAY_600)
                .fontWeight(FontWeight.Medium)
                .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                .backgroundColor(this.libraryActiveTag === tag ? AppColors.GRAY_900 : Color.White)
                .borderRadius(8)
                .shadow({
                  radius: 2,
                  color: 'rgba(0,0,0,0.05)',
                  offsetX: 0,
                  offsetY: 1
                })
                .onClick(() => {
                  this.libraryActiveTag = this.libraryActiveTag === tag ? '' : tag;
                  this.runLibrarySearch();
                })
            }, (tag: string) => tag)

            // 难度筛选标签
            ForEach(['简单', '普通', '困难'], (diff: string) => {
              Text(diff)
                .fontSize(12)
                .fontColor(this.libraryActiveDifficulty === diff ? Color.White : AppColors.GRAY_600)
                .fontWeight(FontWeight.Medium)
                .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                .backgroundColor(this.libraryActiveDifficulty === diff ?
                  (diff === '简单' ? '#22C55E' : diff === '普通' ? '#F59E0B' : '#EF4444') :
                  Color.White)
                .borderRadius(8)
                .shadow({
                  radius: 2,
                  color: 'rgba(0,0,0,0.05)',
                  offsetX: 0,
                  offsetY: 1
                })
                .onClick(() => {
                  this.libraryActiveDifficulty = this.libraryActiveDifficulty === diff ? '' : diff;
                  this.runLibrarySearch();
                })
            }, (diff: string) => diff)
          }
          .padding({ right: 4 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .margin({ top: 16 })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 12 })
      .backgroundColor('rgba(244, 245, 247, 0.95)')
      .backdropBlur(20)

      // 滚动内容区域
      Scroll() {
        Column({ space: 20 }) {
          // 搜索结果模式：显示已选食材提示条
          if (this.libraryActiveTag === '搜索结果') {
            Row({ space: 6 }) {
              Text('🧊')
                .fontSize(14)
              Text(`已选：${this.selectedStuff.join('、')}${this.curTool.length > 0 ? ' · ' + this.curTool : ''}`)
                .fontSize(13)
                .fontColor(AppColors.GRAY_600)
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .backgroundColor('#FFF0F1')
            .borderRadius(10)
          }

          // 如果有搜索结果,显示卡片列表(统一使用小图模式)
          if (this.libraryHits.length > 0) {
            ForEach(this.libraryHits, (item: RecipeWithId) => {
              RecipeCard({
                recipe: item,
                mode: RecipeCardMode.SMALL,
                isFavorite: this.isRecipeFavorite(item.id),
                onCardClick: () => {
                  this.openDetailSheet(item);
                },
                onFavoriteClick: () => {
                  this.onTapFavorite(item.id);
                }
              })
            }, (item: RecipeWithId) => `recipe-${item.id}`)
          } else {
            // 空状态
            Column({ space: 12 }) {
              Text('📖')
                .fontSize(48)
                .opacity(0.3)

              Text(this.recipeCount === 0 ? '暂无菜谱数据' : '暂无匹配的菜谱')
                .fontSize(14)
                .fontColor(AppColors.GRAY_500)
            }
            .width('100%')
            .margin({ top: 60 })
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 8, bottom: 120 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 「发现」Tab - 随机推荐
   */
  @Builder
  buildDiscoverTab() {
    Column() {
      Scroll() {
        Column({ space: 16 }) {
          Text('发现')
            .fontSize(24)
            .fontColor(AppColors.GRAY_900)
            .fontWeight(FontWeight.Bolder)
            .alignSelf(ItemAlign.Start)

          Text('不知道吃什么？随机从全库挑一道菜谱。')
            .fontSize(14)
            .fontColor(AppColors.GRAY_500)
            .alignSelf(ItemAlign.Start)
            .lineHeight(22)

          if (this.errHint.length > 0) {
            Text(this.errHint)
              .fontSize(12)
              .fontColor(Color.Red)
              .alignSelf(ItemAlign.Start)
          }

          // 按钮组
          Row({ space: 12 }) {
            Button() {
              Row({ space: 8 }) {
                Text('🎲')
                  .fontSize(18)

                Text('随机一道')
                  .fontSize(15)
                  .fontColor(Color.White)
                  .fontWeight(FontWeight.Bold)
              }
            }
            .padding({ left: 20, right: 20 })
            .height(44)
            .backgroundColor(AppColors.BRAND_COLOR)
            .borderRadius(12)
            .shadow({
              radius: 12,
              color: 'rgba(255, 71, 87, 0.3)',
              offsetX: 0,
              offsetY: 4
            })
            .onClick(() => {
              this.pickRandomDiscoverWithAnimation();
            })

            if (this.discoverPick.id >= 0) {
              Button() {
                Row({ space: 6 }) {
                  Text('🔄')
                    .fontSize(16)

                  Text('换一道')
                    .fontSize(15)
                    .fontColor(AppColors.BRAND_COLOR)
                    .fontWeight(FontWeight.Medium)
                }
              }
              .padding({ left: 20, right: 20 })
              .height(44)
              .backgroundColor('#E8F5E9')
              .borderRadius(12)
              .onClick(() => {
                // 直接更换,不要动画
                this.pickRandomDiscover();
              })
            }
          }
          .margin({ top: 8 })
          .alignSelf(ItemAlign.Start)

          // 随机动画区域 (全屏菜品名称滚动)
          if (this.showRandomAnimation && this.randomAnimationNames.length > 0) {
            Column() {
              Text(this.randomAnimationNames[this.currentRandomIndex])
                .fontSize(48)
                .fontColor(AppColors.BRAND_COLOR)
                .fontWeight(FontWeight.Bolder)
                .textAlign(TextAlign.Center)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .animation({
                  duration: 50,
                  curve: Curve.Linear
                })
            }
            .width('100%')
            .height(300)
            .justifyContent(FlexAlign.Center)
            .backgroundColor('rgba(255, 245, 235, 0.5)')
            .borderRadius(24)
            .margin({ top: 20 })
          }

          // 显示随机选中的菜谱
          if (!this.showRandomAnimation && this.recipeCount === 0) {
            Column({ space: 12 }) {
              Text('📚')
                .fontSize(48)
                .opacity(0.3)

              Text('暂无菜谱数据')
                .fontSize(14)
                .fontColor(AppColors.GRAY_500)
            }
            .width('100%')
            .margin({ top: 40 })
          } else if (!this.showRandomAnimation && this.discoverPick.id < 0) {
            Column({ space: 12 }) {
              Text('🎲')
                .fontSize(48)
                .opacity(0.3)

              Text('点击「随机一道」开始')
                .fontSize(14)
                .fontColor(AppColors.GRAY_500)
            }
            .width('100%')
            .margin({ top: 40 })
          } else if (!this.showRandomAnimation) {
            // 显示推荐结果(使用小图模式)
            Column({ space: 8 }) {
              Text('今日推荐')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.GRAY_800)
                .alignSelf(ItemAlign.Start)
                .margin({ top: 8 })

              RecipeCard({
                recipe: this.discoverPick,
                mode: RecipeCardMode.SMALL,
                isFavorite: this.isRecipeFavorite(this.discoverPick.id),
                onCardClick: () => {
                  this.openDetailSheet(this.discoverPick);
                },
                onFavoriteClick: () => {
                  this.onTapFavorite(this.discoverPick.id);
                }
              })
                .opacity(this.tabOpacity)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 20, right: 20, top: 4, bottom: 120 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 「我的」Tab - 对应原型中的 #tab-table (餐桌页面)
   */
  @Builder
  buildMyTab() {
    Stack() {
      // 木纹背景图案 (原型中的 radial-gradient 点阵效果)
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(AppColors.TABLE_BG)
        // 可选:添加木纹纹理 .backgroundImage($rawfile('table_texture.png'), ImageRepeat.NoRepeat)

      // 内容区域
      Scroll() {
        Column({ space: 0 }) {
          // 顶部个人信息区域
          Row() {
            Row({ space: 16 }) {
              // 头像
              Column() {
                Text('🧑‍🍳')
                  .fontSize(24)
              }
              .width(48)
              .height(48)
              .borderRadius(24)
              .backgroundColor(Color.White)
              .justifyContent(FlexAlign.Center)
              .shadow({
                radius: 4,
                color: 'rgba(0,0,0,0.05)',
                offsetX: 0,
                offsetY: 2
              })
              .border({
                width: 1,
                color: AppColors.GRAY_100
              })

              Column({ space: 2 }) {
                Text('我的餐桌')
                  .fontSize(22)
                  .fontColor('#4A4036')
                  .fontWeight(FontWeight.Bolder)
                  .letterSpacing(-0.5)

                Text(`已珍藏 ${this.favoriteIds.length} 道私家佳肴`)
                  .fontSize(13)
                  .fontColor('#8B7E6A')
                  .fontWeight(FontWeight.Medium)
              }
              .alignItems(HorizontalAlign.Start)
            }
            .layoutWeight(1)

            // 设置按钮
            Column() {
              Text('⚙️')
                .fontSize(20)
            }
            .width(40)
            .height(40)
            .borderRadius(20)
            .backgroundColor('rgba(255,255,255,0.6)')
            .backdropBlur(12)
            .justifyContent(FlexAlign.Center)
            .shadow({
              radius: 4,
              color: 'rgba(0,0,0,0.05)',
              offsetX: 0,
              offsetY: 2
            })
            .onClick(() => {
              router.pushUrl({ url: 'pages/SettingsPage' }).catch((err: Error) => {
                console.error('Navigate to SettingsPage failed:', err);
                this.showToast('页面跳转失败');
              });
            })
          }
          .width('100%')
          .padding({ left: 24, right: 24, top: 16, bottom: 24 })

          // 瓷盘网格 (2列布局,第二列向下偏移)
          if (this.favoriteIds.length > 0) {
            Column({ space: 48 }) {
              // 使用Grid实现瓷盘网格布局
              GridRow({ columns: 2, gutter: { x: 24, y: 48 } }) {
                ForEach(this.favoriteIds.slice(0, 6), (recipeId: number, index: number) => {
                  GridCol({ span: 1 }) {
                    Column() {
                      PlateCard({
                        dishName: RecipeRepository.getInstance().getById(recipeId)?.name || '未知菜品',
                        emoji: this.getRecipeEmoji(recipeId),
                        onPlateClick: () => {
                          const recipe = RecipeRepository.getInstance().getById(recipeId);
                          if (recipe) {
                            this.openDetailSheet(recipe);
                          }
                        }
                      })
                    }
                    .margin({ top: index % 2 === 1 ? 48 : 0 }) // 第二列向下偏移
                  }
                }, (recipeId: number) => `plate-${recipeId}`)
              }
              .width('100%')
              .padding({ left: 24, right: 24 })
            }
          } else {
            // 空状态
            Column({ space: 16 }) {
              Text('🍽️')
                .fontSize(64)
                .opacity(0.3)

              Text('餐桌还空着呢')
                .fontSize(16)
                .fontColor('#8B7E6A')
                .fontWeight(FontWeight.Medium)

              Text('去收藏一些喜欢的菜谱吧')
                .fontSize(13)
                .fontColor('#8B7E6A')
            }
            .width('100%')
            .margin({ top: 80 })
          }

          // 底部功能入口
          Column({ space: 16 }) {
            // 浏览历史
            Row() {
              Column({ space: 6 }) {
                Text('浏览历史')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#4A4036')

                Text(this.keepLocalData ? `共 ${this.historyIds.length} 条` : '关闭本地数据时不记录')
                  .fontSize(12)
                  .fontColor('#8B7E6A')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Text('›')
                .fontSize(22)
                .fontColor('#CCCCCC')
            }
            .width('100%')
            .padding(16)
            .backgroundColor('rgba(255,255,255,0.85)')
            .backdropBlur(8)
            .borderRadius(16)
            .shadow({
              radius: 8,
              color: 'rgba(139, 126, 110, 0.1)',
              offsetX: 0,
              offsetY: 4
            })
            .onClick(() => {
              router.pushUrl({ url: 'pages/HistoryPage' }).catch(() => {
                console.error('router HistoryPage failed');
              });
            })
          }
          .width('100%')
          .padding({ left: 24, right: 24, top: 32 })
        }
        .width('100%')
        .padding({ bottom: 120 })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 获取菜谱的Emoji图标
   */
  private getRecipeEmoji(recipeId: number): string {
    const recipe = RecipeRepository.getInstance().getById(recipeId);
    if (recipe?.emojis && recipe.emojis.length > 0) {
      return recipe.emojis.join('');
    }
    return '🍽️';
  }

  /**
   * 切换Tab时带淡入淡出动效
   */
  private switchTabWithAnimation(targetIndex: number): void {
    // 淡出
    animateTo({
      duration: 100,
      curve: Curve.EaseOut
    }, () => {
      this.tabOpacity = 0;
    });

    // 切换Tab
    setTimeout(() => {
      this.mainTabIndex = targetIndex;

      // 淡入
      animateTo({
        duration: 150,
        curve: Curve.EaseIn
      }, () => {
        this.tabOpacity = 1.0;
      });
    }, 100);
  }

  build() {
    Stack() {
      // 主内容区域
      Column() {
        // Tab 内容区域(带淡入淡出动效)
        Column() {
          if (this.mainTabIndex === 0) {
            this.buildCookTab();
          } else if (this.mainTabIndex === 1) {
            this.buildLibraryTab();
          } else if (this.mainTabIndex === 2) {
            this.buildDiscoverTab();
          } else {
            this.buildMyTab();
          }
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ top: this.mainNavTopInsetVp })
        .opacity(this.tabOpacity)
        .animation({
          duration: 200,
          curve: Curve.EaseInOut
        })

        // 底部毛玻璃导航栏
        Column() {
          Row() {
            // Tab 1: 冰箱
            Column({ space: 4 }) {
              Text('🧊')
                .fontSize(24)
                .opacity(this.mainTabIndex === 0 ? 1.0 : 0.4)

              Text('冰箱')
                .fontSize(10)
                .fontColor(this.mainTabIndex === 0 ? AppColors.GRAY_900 : AppColors.GRAY_400)
                .fontWeight(this.mainTabIndex === 0 ? FontWeight.Bold : FontWeight.Medium)
            }
            .layoutWeight(1)
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              if (this.mainTabIndex !== 0) {
                this.switchTabWithAnimation(0);
              }
            })

            // Tab 2: 菜谱
            Column({ space: 4 }) {
              Text('📖')
                .fontSize(24)
                .opacity(this.mainTabIndex === 1 ? 1.0 : 0.4)

              Text('菜谱')
                .fontSize(10)
                .fontColor(this.mainTabIndex === 1 ? AppColors.GRAY_900 : AppColors.GRAY_400)
                .fontWeight(this.mainTabIndex === 1 ? FontWeight.Bold : FontWeight.Medium)
            }
            .layoutWeight(1)
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              if (this.mainTabIndex !== 1) {
                this.switchTabWithAnimation(1);
              }
            })

            // Tab 3: 发现
            Column({ space: 4 }) {
              Text('🎲')
                .fontSize(24)
                .opacity(this.mainTabIndex === 2 ? 1.0 : 0.4)

              Text('发现')
                .fontSize(10)
                .fontColor(this.mainTabIndex === 2 ? AppColors.GRAY_900 : AppColors.GRAY_400)
                .fontWeight(this.mainTabIndex === 2 ? FontWeight.Bold : FontWeight.Medium)
            }
            .layoutWeight(1)
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              if (this.mainTabIndex !== 2) {
                this.switchTabWithAnimation(2);
              }
            })

            // Tab 4: 餐桌
            Column({ space: 4 }) {
              Text('🍽️')
                .fontSize(24)
                .opacity(this.mainTabIndex === 3 ? 1.0 : 0.4)

              Text('餐桌')
                .fontSize(10)
                .fontColor(this.mainTabIndex === 3 ? AppColors.GRAY_900 : AppColors.GRAY_400)
                .fontWeight(this.mainTabIndex === 3 ? FontWeight.Bold : FontWeight.Medium)
            }
            .layoutWeight(1)
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              if (this.mainTabIndex !== 3) {
                this.switchTabWithAnimation(3);
                void this.refreshHistory();
                void this.refreshFavorites();
              }
            })
          }
          .width('100%')
          .height(56)

          // 底部小白条(iOS风格指示器)
          Column()
            .width(128)
            .height(5)
            .backgroundColor(AppColors.GRAY_200)
            .borderRadius(10)
            .margin({ top: 8, bottom: 8 })
            .alignSelf(ItemAlign.Center)
        }
        .width('100%')
        .backgroundColor('rgba(255, 255, 255, 0.85)')
        .backgroundBlurStyle(BlurStyle.Thick) // 毛玻璃效果
        .borderWidth({ top: 0.5 })
        .borderColor('rgba(0,0,0,0.05)')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.getBackgroundColor())

      // Toast 提示
      ToastView({ message: this.toastMessage, visible: this.toastVisible })

      // 菜谱详情半模态弹窗
      if (this.detailSheetVisible && this.selectedRecipe) {
        RecipeDetailSheet({
          isVisible: $detailSheetVisible,
          recipe: this.selectedRecipe,
          isFavorite: this.isRecipeFavorite(this.selectedRecipe.id),
          onFavoriteToggle: () => {
            if (this.selectedRecipe) {
              this.onTapFavorite(this.selectedRecipe.id);
            }
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
