/**
 * 您吃了么 - 主页面 (API 22 全品类 + 匹配模式切换版)
 * 包含：强类型、原生图标、单列紧凑布局、分类抽取、匹配策略选择
 * 修复：修改了探索页的 Tag 间距，修正了食材选择数量的文案逻辑
 */
import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { RecipeRepository } from '../data/RecipeRepository';
import type { RecipeWithId, SearchMode, StuffItem } from '../model/recipe';
import { RecipeSearchService } from '../service/RecipeSearchService';
import { CookPreferences, UserProfile, FolderItem } from '../store/CookPreferences';
import { getSystemSafeTopVp } from '../util/StatusBarInset';
import { AppColors, ThemeManager } from '../constants/AppColors';
import { IngredientTag, TagType } from '../components/IngredientTag';
import { ToastView } from '../components/ToastView';
import { RandomPickerButton } from '../components/RandomPickerButton';
import { RecipeDetailSheet } from '../components/RecipeDetailSheet';
import { RecipeCard, RecipeCardMode } from '../components/RecipeCard'
import { PlateCard } from '../components/PlateCard'
import { FavoriteToast } from '../components/FavoriteToast'
import { FolderPickerSheet } from '../components/FolderPickerSheet';
import { HistoryHeatmap } from '../components/HistoryHeatmap';
import { DailyDietCircleCard } from '../components/DailyDietCircleCard';
import { generateRecommendations } from '../service/RecipeRecommendationService';
import { DailyRecommendService } from '../service/DailyRecommendService';
import {
  calcNutriScore,
  getNutriScoreColors,
  aggregateNutrition,
  calcNutritionProgress,
  generateNutritionTip,
  SAMPLE_NUTRITION_DATA,
  ADULT_MALE_DRI
} from '../service/NutritionCalculator';
import type { RecipeNutrition } from '../model/recipe';

// 引入统一管理的食材与厨具全库（含细分子分类）
import {
  toolItems, stapleItems,
  mushroomItems, leafyVegItems, rootVegItems, gourdItems, beanItems, otherVegItems,
  eggItems, porkItems, beefLambItems, poultryItems, fishItems, shrimpCrabItems, shellfishItems
} from '../data/foodCatalog';

interface IngredientCategory {
  title: string;
  data: StuffItem[];
  type: TagType;
}

interface NavItem {
  icon: Resource;
  label: string;
  index: number;
}

@Entry
@Component
struct IndexV2 {
  @State mainTabIndex: number = 0
  @State status: string = '加载中…'
  @State recipeCount: number = 0
  @State errHint: string = ''
  @State keepLocalData: boolean = true

  // 核心：搜索条件状态
  @State selectedStuff: string[] = []
  @State curTool: string = ''
  @State searchMode: SearchMode = 'loose' // 默认使用“模糊匹配”

  @State keyword: string = ''
  @State searchHits: RecipeWithId[] = []
  @State libraryKeyword: string = ''
  @State libraryHits: RecipeWithId[] = []
  @State libraryActiveTag: string = '全部'
  @State libraryActiveDifficulty: string = ''
  @State discoverPick: RecipeWithId = { id: -1, name: '', stuff: [], tools: [], steps: [] }
  @State historyIds: number[] = []
  @State favoriteIds: number[] = []
  @State myFavoriteRecipes: RecipeWithId[] = []
  @State mainNavTopInsetVp: number = 48
  @State userProfile: UserProfile = { nickname: '美食家', avatar: '🧑‍🍳' }

  @State toastMessage: string = ''
  @State toastVisible: boolean = false
  @State detailSheetVisible: boolean = false
  @State selectedRecipe: RecipeWithId | null = null
  @State isRandomizing: boolean = false
  @State highlightedTags: Set<string> = new Set()
  @State tabOpacity: number = 1.0

  // 收藏夹相关状态
  @State mySubTab: number = 0
  @State folders: FolderItem[] = []
  private myTabScroller: Scroller = new Scroller()
  @State favoriteToastVisible: boolean = false
  @State pendingFolderRecipeId: number = -1
  @State folderPickerVisible: boolean = false
  @State deleteFolderConfirmVisible: boolean = false
  @State pendingDeleteFolderId: string = ''
  @State pendingDeleteFolderName: string = ''

  // Task4: 收藏夹网格触摸位置记录（非响应式，仅用于判断滑动 vs 点击）
  private folderTouchDownX: number = 0
  private folderTouchDownY: number = 0
  private folderSlopExceeded: boolean = false

  /** 每次 onPageShow 递增，触发 DailyDietCircleCard 刷新今日饮食数据 */
  @State dietRefreshKey: number = 0
  /** 主题切换时递增，触发圆环重绘 */
  @State dietThemeSignal: number = 0

  @State randomAnimationNames: string[] = []
  @State currentRandomIndex: number = 0
  @State showRandomAnimation: boolean = false

  // 分类折叠状态（默认全部折叠以减少滚动距离）
  @State expandedCategoryTitles: string[] = []

  // 搜索历史
  @State searchHistory: string[] = []
  @State searchHistoryVisible: boolean = false
  @State clearHistoryConfirmVisible: boolean = false

  // 个性化推荐
  @State recommendedRecipes: RecipeWithId[] = []
  // 猜你喜欢当前展示的 3 张（动画换卡用独立列表）
  @State displayedRecommends: RecipeWithId[] = []
  // 下一张候选在 recommendedRecipes 中的下标
  @State nextRecommendIndex: number = 3

  // 历史足迹热力图
  @State datedHistoryJson: string = '{}'

  // 今日餐桌
  @State todayMenuIds: number[] = []
  @State todayMenuRecipes: RecipeWithId[] = []
  @State nutritionTip: string = ''

  // 主题颜色状态
  @State currentBgColor: string = AppColors.BG_COLOR
  @State currentCardBgColor: string = AppColors.CARD_BG
  @State currentTextColor: string = AppColors.GRAY_900
  @State currentSecondaryTextColor: string = AppColors.GRAY_500
  @State currentBorderColor: string = AppColors.GRAY_100
  @State lastThemeMode: string = '系统默认' // 当前生效的主题模式（含系统默认解析结果）

  /**
   * 系统深色状态：EntryAbility.onConfigurationUpdate 写入 AppStorage → 此处零延迟更新。
   * @Watch 触发时：若当前为系统默认模式则重算颜色。
   */
  @StorageProp('isSystemDarkMode')
  @Watch('onSystemThemeChange')
  isSystemDark: boolean = false;

  /**
   * 用户选择的主题模式：SettingsPage.changeThemeMode 写入 AppStorage → 此处零延迟更新。
   * @Watch 触发时：更新 lastThemeMode 并重算颜色，替代原有 1s 轮询定时器。
   */
  @StorageProp('currentThemeMode')
  @Watch('onStoredThemeModeChange')
  storedThemeMode: string = '系统默认';

  /**
   * 每日推荐通知点击标记：EntryAbility.onNewWant 将其置为 true。
   * 使用 @StorageProp @Watch 而非仅在 onPageShow 读取，解决"App 在后台时
   * onPageShow 可能早于 onNewWant 执行"的竞态问题——AppStorage 变更会
   * 立即唤醒 @Watch 回调，无需等待下一次页面生命周期。
   */
  @StorageProp('pendingDailyReminder')
  @Watch('onPendingDailyReminderChange')
  pendingDailyReminder: boolean = false;

  // 利用外部 foodCatalog.ets 的细分子分类数据进行装配
  private readonly ingredientCategories: IngredientCategory[] = [
    // 荤菜细分
    { title: '🥚 蛋类', data: eggItems, type: TagType.MEAT },
    { title: '🐷 猪肉类', data: porkItems, type: TagType.MEAT },
    { title: '🥩 牛羊类', data: beefLambItems, type: TagType.MEAT },
    { title: '🍗 禽类', data: poultryItems, type: TagType.MEAT },
    { title: '🐟 鱼类', data: fishItems, type: TagType.MEAT },
    { title: '🦐 虾蟹头足', data: shrimpCrabItems, type: TagType.MEAT },
    { title: '🐚 贝类', data: shellfishItems, type: TagType.MEAT },
    // 素菜细分
    { title: '🍄 菌菇类', data: mushroomItems, type: TagType.VEG },
    { title: '🥬 叶菜类', data: leafyVegItems, type: TagType.VEG },
    { title: '🥕 根茎笋类', data: rootVegItems, type: TagType.VEG },
    { title: '🫑 瓜茄类', data: gourdItems, type: TagType.VEG },
    { title: '🫘 豆类及制品', data: beanItems, type: TagType.VEG },
    { title: '🌊 其他', data: otherVegItems, type: TagType.VEG },
    // 碳水
    { title: '🍚 碳水辅料', data: stapleItems, type: TagType.CARB },
  ];

  private readonly navItems: NavItem[] = [
    { icon: $r('sys.symbol.house'), label: '冰箱', index: 0 },
    { icon: $r('sys.symbol.bookmark'), label: '菜谱', index: 1 },
    { icon: $r('sys.symbol.compass'), label: '发现', index: 2 },
    { icon: $r('sys.symbol.person'), label: '餐桌', index: 3 }
  ];

  private readonly filterTags: string[] = ['全部', '今日推荐', '减脂餐', '快手早餐', '广式', '川香', '烘焙', '汤羹'];

  async aboutToAppear(): Promise<void> {
    void this.bootstrapData();
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (ctx !== undefined) {
      void getSystemSafeTopVp(ctx).then((vp: number) => {
        this.mainNavTopInsetVp = vp;
      });
    }
    
    // 初始化主题颜色（从 Preferences 读取初始值，后续由 @StorageProp 驱动）
    await this.updateThemeColors();
  }

  onPageShow(): void {
    void this.refreshHistory();
    void this.refreshFavorites();
    void this.refreshFolders();
    void this.refreshUserProfile();
    void this.refreshSearchHistory();
    void this.refreshDatedHistory();
    void this.refreshTodayMenu();
    this.dietRefreshKey++;

    // 页面从后台恢复时立即重算颜色：
    // 解决"从 SettingsPage 返回后主题未更新"的问题。
    // 即使 @StorageProp @Watch 已在后台触发过，也需在页面可见时做一次同步确认。
    this.applyThemeColors(this.storedThemeMode);

    // 处理通知点击携带的推荐菜谱：从 AppStorage 读取并打开详情
    this.handlePendingRecommendRecipe();

    const ctx2 = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (ctx2 !== undefined) {
      void getSystemSafeTopVp(ctx2).then((vp: number) => {
        this.mainNavTopInsetVp = vp;
      });
    }
  }

  /**
   * 检查并处理来自每日推荐通知的打开请求。
   * 同时在 onPageShow（冷启动兜底）和 onPendingDailyReminderChange（后台唤醒）
   * 两处调用，保证所有启动路径均能触发。
   */
  private handlePendingRecommendRecipe(): void {
    if (!this.pendingDailyReminder) return

    const allRecipes = RecipeRepository.getInstance().getAll()
    // 菜谱尚未加载完成时不重置 flag，等 bootstrapData 结束后再次触发
    if (allRecipes.length === 0) return

    // 确认菜谱已就绪后再重置，防止冷启动时 onPageShow 先于数据加载执行
    AppStorage.setOrCreate<boolean>('pendingDailyReminder', false)

    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (ctx === undefined) {
      // 无 context 时退化为随机推荐
      const r = DailyRecommendService.pickRecipe(allRecipes, [], [])
      if (r !== null) { this.mainTabIndex = 1; this.openDetailSheet(r.recipe) }
      return
    }

    // 读取用户推荐偏好与冰箱食材，按偏好选菜后写入推荐历史
    void Promise.all([
      CookPreferences.getDailyRecommendPreference(ctx),
      CookPreferences.getSelectedStuff(ctx),
      CookPreferences.getRecommendHistory(ctx),
    ]).then((vals: [string, string[], number[]]) => {
      const preference: string   = vals[0]
      const selectedStuff: string[] = vals[1]
      const historyIds: number[] = vals[2]
      const stuffForPick: string[] = preference === 'fridge_first' ? selectedStuff : []
      const result = DailyRecommendService.pickRecipe(allRecipes, stuffForPick, historyIds)
      if (result === null) return
      this.mainTabIndex = 1
      this.openDetailSheet(result.recipe)
      void CookPreferences.addToRecommendHistory(ctx, result.recipe.id)
    }).catch(() => {
      // 偏好读取失败时退化为随机推荐
      const r = DailyRecommendService.pickRecipe(allRecipes, [], [])
      if (r !== null) { this.mainTabIndex = 1; this.openDetailSheet(r.recipe) }
    })
  }

  aboutToDisappear(): void {
  }

  private async bootstrapData(): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!host) {
      this.status = '加载失败';
      this.errHint = '无法获取 UIAbility 上下文';
      return;
    }
    try {
      this.mainNavTopInsetVp = await getSystemSafeTopVp(host);
    } catch { }
    try {
      await RecipeRepository.getInstance().load(host);
      this.recipeCount = RecipeRepository.getInstance().getCount();
      this.status = '菜谱已加载';
      this.errHint = '';
      // 菜谱就绪后补充触发：处理冷启动时通知点击携带的推荐请求
      // （onPageShow 在此之前已调用但因菜谱未加载而跳过，flag 此时仍为 true）
      this.handlePendingRecommendRecipe();
    } catch {
      this.status = '加载失败';
      this.recipeCount = 0;
      this.errHint = '菜谱数据加载失败';
      return;
    }

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
    }
    this.runSearch();
    this.runLibrarySearch();
    await this.refreshHistory();
    await this.refreshFavorites();
    await this.refreshUserProfile();
    await this.refreshSearchHistory();
    await this.refreshDatedHistory();
    await this.refreshTodayMenu();
    this.injectSampleNutrition();
    this.refreshRecommendations();
    this.pickRandomDiscover();
  }

  /** 将示例营养数据注入内存菜谱（仅按名称匹配，不持久化） */
  private injectSampleNutrition(): void {
    const all = RecipeRepository.getInstance().getAll()
    for (let i = 0; i < all.length; i++) {
      const r = all[i]
      const sample = SAMPLE_NUTRITION_DATA.get(r.name)
      if (sample !== undefined && r.nutrition === undefined) {
        r.nutrition = sample
      }
    }
  }

  private isRecipeFavorite(recipeId: number): boolean {
    return this.favoriteIds.includes(recipeId);
  }

  private async refreshFavorites(): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!host || !this.keepLocalData) {
      if (!this.keepLocalData) {
        this.favoriteIds = [];
        this.myFavoriteRecipes = [];
      }
      return;
    }
    
    try {
      console.log('[收藏] 开始刷新收藏列表');
      const raw = await CookPreferences.getFavoriteIds(host);
      const n = RecipeRepository.getInstance().getCount();
      const filteredIds = raw.filter(id => id >= 0 && id < n);
      
      console.log(`[收藏] 从存储获取: ${raw.length} 条，过滤后: ${filteredIds.length} 条`);
      
      this.favoriteIds = filteredIds;
      const repo = RecipeRepository.getInstance();
      const recipeList: RecipeWithId[] = [];
      for (let i = 0; i < filteredIds.length; i++) {
        const r = repo.getById(filteredIds[i]);
        if (r !== null) recipeList.push(r);
      }
      this.myFavoriteRecipes = recipeList;
    } catch (error) {
      console.error('[收藏] 刷新收藏列表失败', error);
      this.favoriteIds = [];
    }
  }

  private onTapFavorite(recipeId: number): void {
    console.log(`[收藏] onTapFavorite 被调用，菜谱ID: ${recipeId}`);

    if (!this.keepLocalData) {
      console.log('[收藏] 本地数据存储已关闭，无法收藏');
      this.showToast('请开启本地数据存储以使用收藏功能');
      return;
    }

    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!host) {
      console.error('[收藏] 无法获取UIAbility上下文');
      this.showToast('系统错误：无法获取应用上下文');
      return;
    }

    const wasFavorite = this.isRecipeFavorite(recipeId);
    console.log(`[收藏] 开始切换收藏状态，菜谱ID: ${recipeId}，当前状态: ${wasFavorite ? '已收藏' : '未收藏'}`);

    void CookPreferences.toggleFavoriteId(host, recipeId).then(async () => {
      console.log(`[收藏] 数据存储成功，菜谱ID: ${recipeId}`);
      await this.refreshFavorites();
      if (wasFavorite) {
        // toggleFavoriteId 已内联处理收藏夹移除，这里只需刷新 UI
        await this.refreshFolders();
        this.refreshRecommendations();
        this.showToast('已取消收藏');
      } else {
        // 新增收藏：弹出收藏夹选择器
        this.pendingFolderRecipeId = recipeId;
        if (this.detailSheetVisible) {
          // 详情页内触发：直接在详情页内部显示收藏夹选择器（跳过 Toast，Toast 在系统弹层后看不到）
          this.folderPickerVisible = true;
        } else {
          // 卡片星标触发：先显示 Toast，点"加入收藏夹"再打开选择器
          this.favoriteToastVisible = false;
          setTimeout(() => { this.favoriteToastVisible = true; }, 50);
        }
      }
    }).catch((error: Error) => {
      console.error(`[收藏] 数据存储失败，菜谱ID: ${recipeId}`, error);
      this.showToast('收藏操作失败，请重试');
    });
  }

  private async refreshFolders(): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!host) return;
    try {
      this.folders = await CookPreferences.getFolders(host);
    } catch { }
  }

  private async onAddToFolder(folderId: string): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!host || this.pendingFolderRecipeId < 0) return;
    await CookPreferences.addRecipeToFolder(host, folderId, this.pendingFolderRecipeId);
    await this.refreshFolders();
    this.folderPickerVisible = false;
    this.showToast('已加入收藏夹');
  }

  private async onCreateAndAddToFolder(name: string): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!host || this.pendingFolderRecipeId < 0) return;
    const folder = await CookPreferences.createFolder(host, name);
    await CookPreferences.addRecipeToFolder(host, folder.id, this.pendingFolderRecipeId);
    await this.refreshFolders();
    this.folderPickerVisible = false;
    this.showToast('已创建收藏夹并加入');
  }

  private async onConfirmDeleteFolder(): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!host || !this.pendingDeleteFolderId) return;
    await CookPreferences.deleteFolder(host, this.pendingDeleteFolderId);
    await this.refreshFolders();
    await this.refreshFavorites();
    this.deleteFolderConfirmVisible = false;
    this.pendingDeleteFolderId = '';
    this.pendingDeleteFolderName = '';
    this.showToast('收藏夹已删除');
  }

  private async refreshHistory(): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!host || !this.keepLocalData) {
      if (!this.keepLocalData) this.historyIds = [];
      return;
    }
    try {
      const raw = await CookPreferences.getHistoryIds(host);
      const n = RecipeRepository.getInstance().getCount();
      this.historyIds = raw.filter(id => id >= 0 && id < n);
    } catch { }
  }

  private async refreshUserProfile(): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!host) return;
    try {
      this.userProfile = await CookPreferences.getUserProfile(host);
    } catch { }
  }

  private isAvatarImage(avatar: string): boolean {
    return avatar.startsWith('file://') || avatar.startsWith('/');
  }

  /**
   * 冷启动初始化：从 Preferences 读取用户选择的主题模式，并同步到 AppStorage。
   * 后续所有实时变化由 @StorageProp @Watch 驱动，无需再次读 Preferences。
   */
  private async updateThemeColors(): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!host) return;
    try {
      const themeSettings = await CookPreferences.getThemeSettings(host);
      // AppStorage 优先（当次会话实时值）；冷启动时 AppStorage 无值则用 Preferences
      const liveMode = AppStorage.get<string>('currentThemeMode')
      const effectiveTheme: string = (liveMode !== undefined && liveMode.length > 0)
        ? liveMode
        : themeSettings.themeMode
      AppStorage.setOrCreate<string>('currentThemeMode', effectiveTheme);
      this.applyThemeColors(effectiveTheme);
    } catch (error) {
      console.error('updateThemeColors failed:', error);
    }
  }

  /** @Watch 回调：系统深色状态变化（EntryAbility.onConfigurationUpdate 写入） */
  private onSystemThemeChange(): void {
    if (this.lastThemeMode === '系统默认') {
      this.applyThemeColors('系统默认');
    }
  }

  /** @Watch 回调：用户在 SettingsPage 选择了新主题（AppStorage 广播） */
  private onStoredThemeModeChange(): void {
    this.applyThemeColors(this.storedThemeMode);
  }

  /**
   * @Watch 回调：每日推荐通知点击（EntryAbility.onNewWant 写入 AppStorage）。
   * 无论 App 是冷启动还是从后台唤醒，此回调均可靠触发；
   * 冷启动时 onPageShow 也会调用 handlePendingRecommendRecipe 做一次兜底。
   */
  onPendingDailyReminderChange(): void {
    if (this.pendingDailyReminder) {
      this.handlePendingRecommendRecipe()
    }
  }

  /** 同步计算并写入所有主题颜色 @State，保证同帧完成无闪烁 */
  private applyThemeColors(mode: string): void {
    this.currentBgColor = ThemeManager.getBackgroundColor(mode);
    this.currentCardBgColor = ThemeManager.getCardBackgroundColor(mode);
    this.currentTextColor = ThemeManager.getTextColor(mode);
    this.currentSecondaryTextColor = ThemeManager.getSecondaryTextColor(mode);
    this.currentBorderColor = ThemeManager.getBorderColor(mode);
    this.lastThemeMode = mode;
    this.dietThemeSignal++;
  }

  private runSearch(): void {
    const all = RecipeRepository.getInstance().getAll();
    this.searchHits = RecipeSearchService.search(all, this.selectedStuff, this.curTool, this.searchMode, this.keyword.trim());
  }

  private runLibrarySearch(): void {
    if (this.libraryActiveTag === '搜索结果') {
      this.libraryHits = RecipeSearchService.filterByDifficulty(this.searchHits, this.libraryActiveDifficulty);
    } else {
      let result = RecipeRepository.getInstance().getAll();
      result = RecipeSearchService.filterLibraryByName(result, this.libraryKeyword);

      if (this.libraryActiveTag !== '全部') {
        result = RecipeSearchService.filterByTag(result, this.libraryActiveTag);
      }

      this.libraryHits = RecipeSearchService.filterByDifficulty(result, this.libraryActiveDifficulty);
    }
  }

  // 切换搜索模式
  private switchSearchMode(mode: SearchMode): void {
    this.searchMode = mode;
    this.runSearch();

    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (host) {
      void CookPreferences.setSearchMode(host, mode);
    }

    const tip = mode === 'survival' ? '生存模式：仅展示现有食材能做的菜' :
      mode === 'loose' ? '模糊匹配：展示包含已选食材的菜' : '严格匹配：食材与厨具均需符合';
    this.showToast(tip);
  }

  private cloneRecipeForDiscoverState(source: RecipeWithId): RecipeWithId {
    return JSON.parse(JSON.stringify(source));
  }

  private pickRandomDiscover(): void {
    const all = RecipeRepository.getInstance().getAll();
    if (all.length === 0) {
      this.discoverPick = { id: -1, name: '', stuff: [], tools: [], steps: [] };
      return;
    }
    let pool = all;
    if (this.discoverPick.id >= 0 && all.length > 1) {
      pool = all.filter(r => r.id !== this.discoverPick.id);
    }
    this.discoverPick = this.cloneRecipeForDiscoverState(pool[Math.floor(Math.random() * pool.length)]);
  }

  private pickRandomDiscoverWithAnimation(): void {
    if (this.isRandomizing) return;
    this.isRandomizing = true;
    this.showRandomAnimation = true;

    const all = RecipeRepository.getInstance().getAll();
    if (all.length === 0) {
      this.showRandomAnimation = false;
      this.isRandomizing = false;
      this.pickRandomDiscover();
      return;
    }

    const shuffled = [...all].sort(() => Math.random() - 0.5);
    this.randomAnimationNames = shuffled.slice(0, Math.min(20, shuffled.length)).map(r => r.name);
    this.currentRandomIndex = 0;

    let counter = 0;
    const interval = setInterval(() => {
      this.currentRandomIndex = (this.currentRandomIndex + 1) % this.randomAnimationNames.length;
      if (++counter >= 30) {
        clearInterval(interval);
        setTimeout(() => {
          this.showRandomAnimation = false;
          this.pickRandomDiscover();
          animateTo({ duration: 400, curve: Curve.EaseOut }, () => this.tabOpacity = 1.0);
          this.isRandomizing = false;
        }, 200);
      }
    }, 50);

    animateTo({ duration: 200, curve: Curve.EaseOut }, () => this.tabOpacity = 0.3);
  }

  private async persistCookIfNeeded(): Promise<void> {
    if (!this.keepLocalData) return;
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!host) return;
    await CookPreferences.setSelectedStuff(host, this.selectedStuff);
    await CookPreferences.setCurTool(host, this.curTool);
    await CookPreferences.setSearchMode(host, this.searchMode);
  }

  private toggleStuff(name: string): void {
    if (this.isRandomizing) return;
    if (this.selectedStuff.includes(name)) {
      this.selectedStuff = this.selectedStuff.filter(item => item !== name);
    } else {
      this.selectedStuff.push(name);
    }
    this.runSearch();
    void this.persistCookIfNeeded();
  }

  private toggleTool(name: string): void {
    if (this.isRandomizing) return;
    this.curTool = this.curTool === name ? '' : name;
    this.runSearch();
    void this.persistCookIfNeeded();
  }

  private resetSelection(): void {
    if (this.isRandomizing) return;
    if (this.selectedStuff.length > 0 || this.curTool.length > 0) {
      this.selectedStuff = [];
      this.curTool = '';
      this.runSearch();
      void this.persistCookIfNeeded();
      this.showToast('已清空冰箱已选食材');
    }
  }

  private isCategoryExpanded(title: string): boolean {
    return this.expandedCategoryTitles.includes(title);
  }

  private toggleCategory(title: string): void {
    if (this.expandedCategoryTitles.includes(title)) {
      this.expandedCategoryTitles = this.expandedCategoryTitles.filter(t => t !== title);
    } else {
      this.expandedCategoryTitles = this.expandedCategoryTitles.concat([title]);
    }
  }

  private selectedCountInCategory(cat: IngredientCategory): number {
    let count = 0;
    for (let i = 0; i < cat.data.length; i++) {
      if (this.selectedStuff.includes(cat.data[i].name)) {
        count++;
      }
    }
    return count;
  }

  private showToast(message: string): void {
    this.toastMessage = message;
    this.toastVisible = true;
    setTimeout(() => this.toastVisible = false, 2500);
  }

  private openDetailSheet(recipe: RecipeWithId): void {
    this.selectedRecipe = recipe;
    this.detailSheetVisible = true;
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (host !== undefined && this.keepLocalData) {
      void CookPreferences.recordHistoryVisit(host, recipe.id).then(async () => {
        await this.refreshHistory();
        this.refreshRecommendations();
        await this.refreshDatedHistory();
      });
    }
  }

  private getBackgroundColor(): string {
    return this.mainTabIndex === 3 ? this.currentCardBgColor : this.currentBgColor;
  }

  /**
   * 当前是否处于深色渲染状态。
   * 正确处理"系统默认"模式：此时跟随 @StorageProp isSystemDark。
   */
  private isEffectivelyDark(): boolean {
    if (this.lastThemeMode === '深色模式') return true;
    if (this.lastThemeMode === '浅色模式') return false;
    return this.isSystemDark; // 系统默认
  }

  private getNavButtonBgColor(): string {
    return this.isEffectivelyDark() ? 'rgba(255,255,255,0.1)' : 'rgba(255,255,255,0.4)';
  }

  private getNavBarBgColor(): string {
    return this.isEffectivelyDark() ? 'rgba(255,255,255,0.05)' : 'rgba(255,255,255,0.7)';
  }

  private getSearchModeActiveTextColor(): string {
    return this.isEffectivelyDark() ? 'rgba(255,255,255,0.9)' : 'rgba(255,255,255,0.8)';
  }

  private getRandomAnimationBgColor(): string {
    return this.isEffectivelyDark() ? 'rgba(30, 30, 30, 0.5)' : 'rgba(255, 245, 235, 0.5)';
  }

  private getNavBarBorderColor(): string {
    return this.isEffectivelyDark() ? 'rgba(255,255,255,0.05)' : 'rgba(0,0,0,0.05)';
  }

  private startRandomAnimation(): void {
    if (this.isRandomizing) return;
    this.isRandomizing = true;
    this.selectedStuff = [];
    this.curTool = '';
    this.highlightedTags = new Set();

    const allIngredients = this.ingredientCategories.flatMap(c => c.data.map(i => i.name));
    let round = 0;

    const animationInterval = setInterval(() => {
      this.highlightedTags = new Set();
      for (let i = 0; i < 2; i++) {
        this.highlightedTags.add(allIngredients[Math.floor(Math.random() * allIngredients.length)]);
      }
      if (++round >= 10) {
        clearInterval(animationInterval);
        this.highlightedTags = new Set();

        const meats = this.ingredientCategories.find(c => c.type === TagType.MEAT)?.data.map(i => i.name) || [];
        const vegs = this.ingredientCategories.find(c => c.type === TagType.VEG)?.data.map(i => i.name) || [];

        const m = meats[Math.floor(Math.random() * meats.length)];
        const v1 = vegs[Math.floor(Math.random() * vegs.length)];

        this.selectedStuff = [m, v1];
        this.isRandomizing = false;
        this.runSearch();
        void this.persistCookIfNeeded();
        this.showToast('✨ 搭配完成，去看看做法吧！');
      }
    }, 75);
  }

  private switchTabWithAnimation(targetIndex: number): void {
    animateTo({ duration: 100, curve: Curve.EaseOut }, () => this.tabOpacity = 0);
    setTimeout(() => {
      this.mainTabIndex = targetIndex;
      animateTo({ duration: 150, curve: Curve.EaseIn }, () => this.tabOpacity = 1.0);
      // 进入发现 Tab 时刷新推荐
      if (targetIndex === 2) {
        this.refreshRecommendations();
      }
    }, 100);
  }

  // ── 搜索历史 ──────────────────────────────────────────────────────────

  private async refreshSearchHistory(): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!host) return;
    try {
      this.searchHistory = await CookPreferences.getSearchHistory(host);
    } catch { }
  }

  private async saveSearchKeyword(kw: string): Promise<void> {
    if (kw.trim().length === 0) return;
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!host) return;
    await CookPreferences.addSearchHistory(host, kw.trim());
    await this.refreshSearchHistory();
  }

  private async clearSearchHistory(): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!host) return;
    await CookPreferences.clearSearchHistory(host);
    this.searchHistory = [];
    this.clearHistoryConfirmVisible = false;
    this.showToast('搜索历史已清空');
  }

  // ── 个性化推荐 ────────────────────────────────────────────────────────

  private refreshRecommendations(): void {
    const all = RecipeRepository.getInstance().getAll();
    if (all.length === 0) return;
    // 使用收藏+历史的并集作为种子，历史优先
    const seedIds: number[] = [];
    const seen = new Set<number>();
    for (let i = 0; i < this.historyIds.length && seedIds.length < 10; i++) {
      if (!seen.has(this.historyIds[i])) {
        seedIds.push(this.historyIds[i]);
        seen.add(this.historyIds[i]);
      }
    }
    for (let i = 0; i < this.favoriteIds.length && seedIds.length < 10; i++) {
      if (!seen.has(this.favoriteIds[i])) {
        seedIds.push(this.favoriteIds[i]);
        seen.add(this.favoriteIds[i]);
      }
    }
    this.recommendedRecipes = generateRecommendations(all, seedIds, 15);
    this.displayedRecommends = this.recommendedRecipes.slice(0, 3);
    this.nextRecommendIndex = 3;
  }

  /** 一键刷新全部 3 张推荐卡片；候选池耗尽时重新生成 */
  private refreshAllRecommends(): void {
    if (this.nextRecommendIndex < this.recommendedRecipes.length) {
      const end = Math.min(this.nextRecommendIndex + 3, this.recommendedRecipes.length);
      this.displayedRecommends = this.recommendedRecipes.slice(this.nextRecommendIndex, end);
      this.nextRecommendIndex = end;
    } else {
      this.refreshRecommendations();
    }
  }

  // ── 历史热力图 ────────────────────────────────────────────────────────

  private async refreshDatedHistory(): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!host) return;
    try {
      const data = await CookPreferences.getDatedHistory(host);
      this.datedHistoryJson = JSON.stringify(data);
    } catch { }
  }

  // ── 今日餐桌 ─────────────────────────────────────────────────────────

  private async refreshTodayMenu(): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!host) return;
    try {
      const ids = await CookPreferences.getTodayMenuIds(host);
      const n = RecipeRepository.getInstance().getCount();
      this.todayMenuIds = ids.filter(id => id >= 0 && id < n);
      const repo = RecipeRepository.getInstance();
      const list: RecipeWithId[] = [];
      for (let i = 0; i < this.todayMenuIds.length; i++) {
        const r = repo.getById(this.todayMenuIds[i]);
        if (r !== null) list.push(r);
      }
      this.todayMenuRecipes = list;
      this.recalcNutritionTip();
    } catch { }
  }

  private async toggleTodayMenu(recipeId: number): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!host) return;
    const added = await CookPreferences.toggleTodayMenuItem(host, recipeId);
    await this.refreshTodayMenu();
    this.showToast(added ? '已加入今日餐桌' : '已从今日餐桌移除');
  }

  private recalcNutritionTip(): void {
    if (this.todayMenuRecipes.length === 0) {
      this.nutritionTip = '';
      return;
    }
    const nutritionList: RecipeNutrition[] = [];
    for (let i = 0; i < this.todayMenuRecipes.length; i++) {
      const n = this.todayMenuRecipes[i].nutrition;
      if (n !== undefined) nutritionList.push(n);
    }
    if (nutritionList.length === 0) {
      this.nutritionTip = '';
      return;
    }
    const total = aggregateNutrition(nutritionList);
    const progress = calcNutritionProgress(total, ADULT_MALE_DRI);
    this.nutritionTip = generateNutritionTip(progress);
  }

  private isTodayMenuItem(recipeId: number): boolean {
    for (let i = 0; i < this.todayMenuIds.length; i++) {
      if (this.todayMenuIds[i] === recipeId) return true;
    }
    return false;
  }

  private getRecipeNutriScore(r: RecipeWithId): string {
    if (r.nutrition === undefined) return '';
    return calcNutriScore(r.nutrition, r.tags ?? []);
  }

  private getRecipeNutriBg(r: RecipeWithId): string {
    if (r.nutrition === undefined) return '#9CA3AF';
    return getNutriScoreColors(calcNutriScore(r.nutrition, r.tags ?? [])).bg;
  }

  private getRecipeNutriText(r: RecipeWithId): string {
    if (r.nutrition === undefined) return '#FFFFFF';
    return getNutriScoreColors(calcNutriScore(r.nutrition, r.tags ?? [])).text;
  }

  /**
   * 测试收藏功能是否正常工作
   */
  private testFavoriteFunction(): void {
    if (!this.keepLocalData) {
      this.showToast('请先开启本地数据存储');
      return;
    }
    
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!host) {
      this.showToast('无法获取应用上下文');
      return;
    }
    
    // 测试第一个菜谱的收藏功能
    const testRecipeId = 0;
    console.log(`[测试] 开始测试收藏功能，菜谱ID: ${testRecipeId}`);
    
    void CookPreferences.toggleFavoriteId(host, testRecipeId).then(async () => {
      await this.refreshFavorites();
      const isFavorite = this.isRecipeFavorite(testRecipeId);
      this.showToast(`收藏功能测试${isFavorite ? '成功' : '失败'}`);
      console.log(`[测试] 收藏功能测试${isFavorite ? '成功' : '失败'}`);
    }).catch((error: Error) => {
      console.error('[测试] 收藏功能测试失败', error);
      this.showToast('收藏功能测试失败');
    });
  }

  @Builder
  buildCookTab() {
    Stack() {
      Scroll() {
        // 【核心优化】将全局模块间距统一收紧为 16vp
        Column({ space: 16 }) {

          // --- 模块 1：顶部标题区 ---
          Row() {
            Column({ space: 4 }) {
              Text('准备做点什么？')
                .fontSize(32)
                .fontColor(this.currentTextColor)
                .fontWeight(FontWeight.Bolder)
                .letterSpacing(-1)

              Text('点选食材，匹配最佳做法')
                .fontSize(14)
                .fontColor(this.currentSecondaryTextColor)
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)

            Row({ space: 4 }) {
              SymbolGlyph($r('sys.symbol.trash')).fontSize(14).fontColor([this.currentSecondaryTextColor])
              Text('清空')
                .fontSize(13).fontColor(this.currentSecondaryTextColor).fontWeight(FontWeight.Medium)
            }
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor(this.currentBorderColor).borderRadius(100)
            .onClick(() => this.resetSelection())
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 24 })
          // 💡 关键修改：通过 margin 增加标题与下方按钮的特定呼吸感（16 + 12 = 28vp 间距）
          .margin({ bottom: 12 })

          // --- 模块 2：随机按钮区 ("没有灵感") ---
          RandomPickerButton({ disabled: this.isRandomizing, onRandomComplete: () => this.startRandomAnimation() })
            .padding({ left: 20, right: 20 })

          // --- 模块 3：匹配策略 ---
          Column({ space: 10 }) {
            Text('匹配策略')
              .fontSize(15).fontColor(this.currentTextColor).fontWeight(FontWeight.Bold).alignSelf(ItemAlign.Center)

            Row({ space: 8 }) {
              ForEach([
                { mode: 'loose', label: '模糊匹配', desc: '包含即可' },
                { mode: 'survival', label: '生存模式', desc: '仅限现有' },
                { mode: 'strict', label: '严格模式', desc: '工具符合' }
              ], (item: Record<string, string>) => {
                Column({ space: 2 }) {
                  Text(item.label)
                    .fontSize(14)
                    .fontWeight(this.searchMode === item.mode ? FontWeight.Bold : FontWeight.Normal)
                    .fontColor(this.searchMode === item.mode ? Color.White : this.currentTextColor)
                  Text(item.desc)
                    .fontSize(10)
                    .fontColor(this.searchMode === item.mode ? this.getSearchModeActiveTextColor() : this.currentSecondaryTextColor)
                }
                .layoutWeight(1).padding({ top: 8, bottom: 8 })
                .backgroundColor(this.searchMode === item.mode ? AppColors.BRAND_COLOR : this.currentCardBgColor)
                .borderRadius(12)
                .border({ width: 1, color: this.searchMode === item.mode ? AppColors.BRAND_COLOR : this.currentBorderColor })
                .onClick(() => this.switchSearchMode(item.mode as SearchMode))
              }, (item: Record<string, string>) => item.mode)
            }.width('100%')
          }.width('100%').padding({ left: 20, right: 20 })

          // --- 模块 4：食材与厨具分类（可折叠，减少滚动） ---
          Column({ space: 8 }) {
            ForEach(this.ingredientCategories, (cat: IngredientCategory) => {
              Column() {
                // 标题行：始终显示，点击展开/折叠
                Row() {
                  Text(cat.title)
                    .fontSize(15)
                    .fontColor(this.currentTextColor)
                    .fontWeight(FontWeight.Bold)
                  if (this.selectedCountInCategory(cat) > 0) {
                    Text(`${this.selectedCountInCategory(cat)}`)
                      .fontSize(11)
                      .fontColor(AppColors.BRAND_COLOR)
                      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                      .backgroundColor(AppColors.BRAND_COLOR_LIGHT)
                      .borderRadius(100)
                      .margin({ left: 6 })
                  }
                  Blank()
                  SymbolGlyph(this.isCategoryExpanded(cat.title)
                    ? $r('sys.symbol.chevron_up')
                    : $r('sys.symbol.chevron_down'))
                    .fontSize(14)
                    .fontColor([this.currentSecondaryTextColor])
                }
                .width('100%')
                .padding({ left: 14, right: 14, top: 12, bottom: 12 })
                .onClick(() => this.toggleCategory(cat.title))

                // 折叠时：仅展示已选中的 chip 预览
                if (!this.isCategoryExpanded(cat.title) && this.selectedCountInCategory(cat) > 0) {
                  Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignItems: ItemAlign.Center }) {
                    ForEach(cat.data, (item: StuffItem) => {
                      if (this.selectedStuff.includes(item.name)) {
                        IngredientTag({
                          label: item.name, emoji: item.emoji, tagType: cat.type,
                          isActive: true, isHighlighted: false,
                          onTagClick: () => this.toggleStuff(item.name)
                        }).margin({ left: 5, right: 5, bottom: 8 })
                      }
                    }, (item: StuffItem) => item.name)
                  }
                  .width('100%')
                  .padding({ left: 14, right: 14, bottom: 12 })
                }

                // 展开时：显示全部 chip
                if (this.isCategoryExpanded(cat.title)) {
                  Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
                    ForEach(cat.data, (item: StuffItem) => {
                      IngredientTag({
                        label: item.name, emoji: item.emoji, tagType: cat.type,
                        isActive: this.selectedStuff.includes(item.name),
                        isHighlighted: this.highlightedTags.has(item.name),
                        onTagClick: () => this.toggleStuff(item.name)
                      }).margin({ left: 5, right: 5, bottom: 10 })
                    }, (item: StuffItem) => item.name)
                  }
                  .width('100%')
                  .padding({ left: 14, right: 14, bottom: 12 })
                }
              }
              .backgroundColor(this.currentCardBgColor)
              .borderRadius(12)
              .borderWidth(0.5)
              .borderColor(this.currentBorderColor)
              .clip(true)
            }, (cat: IngredientCategory) => cat.title)

            // 厨具区（同样可折叠）
            Column() {
              Row() {
                Text('🍳 厨具')
                  .fontSize(15)
                  .fontColor(this.currentTextColor)
                  .fontWeight(FontWeight.Bold)
                if (this.curTool.length > 0) {
                  Text('1')
                    .fontSize(11)
                    .fontColor(AppColors.BRAND_COLOR)
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .backgroundColor(AppColors.BRAND_COLOR_LIGHT)
                    .borderRadius(100)
                    .margin({ left: 6 })
                }
                Blank()
                SymbolGlyph(this.isCategoryExpanded('__tool__')
                  ? $r('sys.symbol.chevron_up')
                  : $r('sys.symbol.chevron_down'))
                  .fontSize(14)
                  .fontColor([this.currentSecondaryTextColor])
              }
              .width('100%')
              .padding({ left: 14, right: 14, top: 12, bottom: 12 })
              .onClick(() => this.toggleCategory('__tool__'))

              if (!this.isCategoryExpanded('__tool__') && this.curTool.length > 0) {
                Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
                  ForEach(toolItems, (item: StuffItem) => {
                    if (item.name === this.curTool) {
                      IngredientTag({
                        label: item.name, emoji: item.emoji, tagType: TagType.TOOL,
                        isActive: true, isHighlighted: false,
                        onTagClick: () => this.toggleTool(item.name)
                      }).margin({ left: 5, right: 5, bottom: 8 })
                    }
                  }, (item: StuffItem) => item.name)
                }
                .width('100%')
                .padding({ left: 14, right: 14, bottom: 12 })
              }

              if (this.isCategoryExpanded('__tool__')) {
                Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
                  ForEach(toolItems, (item: StuffItem) => {
                    IngredientTag({
                      label: item.label ?? item.name, emoji: item.emoji, tagType: TagType.TOOL,
                      isActive: this.curTool === item.name, isHighlighted: false,
                      onTagClick: () => this.toggleTool(item.name)
                    }).margin({ left: 5, right: 5, bottom: 10 })
                  }, (item: StuffItem) => item.name)
                }
                .width('100%')
                .padding({ left: 14, right: 14, bottom: 12 })
              }
            }
            .backgroundColor(this.currentCardBgColor)
            .borderRadius(12)
            .borderWidth(0.5)
            .borderColor(this.currentBorderColor)
            .clip(true)
          }
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 140 })

        }.width('100%')
      }
      .width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)

      // 底部固定操作按钮
      Column() {
        Button() {
          Text(this.selectedStuff.length > 0 ? `查看这 ${this.selectedStuff.length} 种组合能做什么` : '请先选择食材')
            .fontSize(15).fontColor(Color.White).fontWeight(FontWeight.Bold)
        }
        .width('100%').height(56)
        .backgroundColor(this.selectedStuff.length > 0 ? AppColors.BRAND_COLOR : this.currentBorderColor)
        .borderRadius(16)
        .enabled(this.selectedStuff.length > 0)
        .onClick(() => {
          if (this.selectedStuff.length > 0) {
            this.libraryActiveTag = '搜索结果';
            this.runLibrarySearch();
            this.switchTabWithAnimation(1);
          }
        })
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 20 })
      .position({ x: 0, y: '100%' })
      .markAnchor({ y: '100%' })
    }.width('100%').height('100%')
  }

  @Builder
  buildLibraryTab() {
    Column() {
      Column() {
        Text('探索').fontSize(24).fontColor(this.currentTextColor).fontWeight(FontWeight.Bold).alignSelf(ItemAlign.Start).margin({ bottom: 16 })

        // 搜索框 + 历史联想
        Column() {
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.magnifyingglass')).fontSize(18).fontColor([this.currentSecondaryTextColor])
            TextInput({ placeholder: '搜索菜谱或食材', text: this.libraryKeyword })
              .backgroundColor(Color.Transparent).layoutWeight(1).fontSize(15).placeholderColor(this.currentSecondaryTextColor)
              .onFocus(() => { this.searchHistoryVisible = true; })
              .onChange((v: string) => {
                this.libraryKeyword = v;
                this.runLibrarySearch();
              })
              .onSubmit(() => {
                void this.saveSearchKeyword(this.libraryKeyword);
                this.searchHistoryVisible = false;
              })
          }.width('100%').height(48).padding({ left: 16, right: 16 }).backgroundColor(this.currentBorderColor).borderRadius(12)

          // 历史联想浮层
          if (this.searchHistoryVisible) {
            Column({ space: 0 }) {
              Row() {
                Text('搜索历史')
                  .fontSize(13).fontColor(this.currentSecondaryTextColor).layoutWeight(1)
                if (this.searchHistory.length > 0) {
                  Text('清空')
                    .fontSize(12).fontColor('#EF4444')
                    .onClick(() => { this.clearHistoryConfirmVisible = true; })
                }
                SymbolGlyph($r('sys.symbol.xmark')).fontSize(14).fontColor([this.currentSecondaryTextColor])
                  .margin({ left: 10 })
                  .onClick(() => { this.searchHistoryVisible = false; })
              }
              .width('100%').padding({ left: 12, right: 12, top: 10, bottom: 6 })

              if (this.searchHistory.length === 0) {
                Text('暂无搜索历史')
                  .fontSize(13).fontColor(this.currentSecondaryTextColor)
                  .padding({ left: 12, right: 12, top: 4, bottom: 12 })
              } else {
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.searchHistory.slice(0, 12), (kw: string) => {
                    Text(kw)
                      .fontSize(13).fontColor(this.currentTextColor)
                      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                      .backgroundColor(this.currentBorderColor).borderRadius(100)
                      .margin({ right: 8, bottom: 8 })
                      .onClick(() => {
                        this.libraryKeyword = kw;
                        this.runLibrarySearch();
                        this.searchHistoryVisible = false;
                        void this.saveSearchKeyword(kw);
                      })
                  }, (kw: string) => `sh-${kw}`)
                }.width('100%').padding({ left: 12, right: 12, bottom: 8 })
              }
            }
            .width('100%')
            .backgroundColor(this.currentCardBgColor)
            .borderRadius(12)
            .borderWidth(0.5).borderColor(this.currentBorderColor)
            .shadow({ radius: 8, color: 'rgba(0,0,0,0.08)', offsetX: 0, offsetY: 4 })
            .margin({ top: 4 })
            .zIndex(100)
          }
        }.width('100%')

        Scroll() {
          // 修复：Row间距从8减小到6，缩减视觉留白
          Row({ space: 8 }) {
            if (this.searchHits.length > 0) {
              Text(`搜索结果 ${this.searchHits.length}`)
                .fontSize(12).fontColor(this.libraryActiveTag === '搜索结果' ? Color.White : AppColors.BRAND_COLOR)
              // 修复：左右padding从14减小到12
                .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                .backgroundColor(this.libraryActiveTag === '搜索结果' ? AppColors.BRAND_COLOR : this.currentCardBgColor)
                .borderRadius(8)
                .onClick(() => { this.libraryActiveTag = '搜索结果'; this.libraryActiveDifficulty = ''; this.runLibrarySearch(); })
            }
            ForEach(this.filterTags, (tag: string) => {
              Text(tag)
                .fontSize(12).fontColor(this.libraryActiveTag === tag ? Color.White : this.currentSecondaryTextColor)
              // 修复：左右padding从14减小到12
                .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                .backgroundColor(this.libraryActiveTag === tag ? AppColors.BRAND_COLOR : this.currentCardBgColor)
                .borderRadius(8)
                .onClick(() => {
                  this.libraryActiveTag = tag;
                  this.runLibrarySearch();
                })
            }, (tag: string) => tag)
          }.padding({ right: 4 })
        }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%').margin({ top: 16 })
      }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 12 }).backgroundColor(this.currentBgColor)

      Scroll() {
        Column({ space: 20 }) {
          if (this.libraryActiveTag === '搜索结果') {
            Row({ space: 6 }) {
              SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize(14).fontColor([this.currentSecondaryTextColor])
              Text(`已选：${this.selectedStuff.join('、')}${this.curTool ? ' · ' + this.curTool : ''}`)
                .fontSize(13).fontColor(this.currentSecondaryTextColor).layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            }.width('100%').padding({ left: 14, right: 14, top: 8, bottom: 8 }).backgroundColor(this.currentCardBgColor).borderRadius(10)
          }

          if (this.libraryHits.length > 0) {
            GridRow({ columns: 1, gutter: { x: 0, y: 13 } }) {
              ForEach(this.libraryHits, (item: RecipeWithId) => {
                GridCol({ span: 1 }) {
                  RecipeCard({
                    recipe: item,
                    mode: RecipeCardMode.LARGE,
                    isFavorite: this.isRecipeFavorite(item.id),
                    onCardClick: () => this.openDetailSheet(item),
                    onFavoriteClick: () => this.onTapFavorite(item.id)
                  })
                }
              }, (item: RecipeWithId) => `recipe-${item.id}`)
            }
          } else {
            Column({ space: 12 }) {
              SymbolGlyph($r('sys.symbol.info_circle')).fontSize(48).fontColor([this.currentBorderColor])
              Text(this.recipeCount === 0 ? '暂无菜谱数据' : '暂无匹配的菜谱').fontSize(14).fontColor(this.currentSecondaryTextColor)
            }.width('100%').margin({ top: 60 })
          }
        }.width('100%').padding({ left: 20, right: 20, top: 8, bottom: 120 })
      }.layoutWeight(1).scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
    }.width('100%').height('100%')
  }

  @Builder
  buildDiscoverTab() {
    Column() {
      Scroll() {
        Column({ space: 16 }) {
          Row() {
            Text('发现')
              .fontSize(24)
              .fontColor(this.currentTextColor)
              .fontWeight(FontWeight.Bold)
            Blank()
            Text('?')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.currentSecondaryTextColor)
              .width(32)
              .height(32)
              .textAlign(TextAlign.Center)
              .lineHeight(32)
              .backgroundColor(this.currentCardBgColor)
              .borderRadius(16)
              .onClick(() => {
                router.pushUrl({ url: 'pages/DietaryStructurePage' }).catch((e: Error) => {
                  console.error(`路由跳转 DietaryStructurePage 失败: ${e.message}`)
                })
              })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          Text('不知道吃什么？随机从全库挑一道菜谱。').fontSize(14).fontColor(this.currentSecondaryTextColor).alignSelf(ItemAlign.Start)

          Row({ space: 12 }) {
            Button() {
              Row({ space: 8 }) {
                SymbolGlyph($r('sys.symbol.arrow_clockwise')).fontSize(18).fontColor([Color.White]);
                Text('随机一道').fontSize(15).fontColor(Color.White).fontWeight(FontWeight.Bold)
              }
            }
            .padding({ left: 20, right: 20 }).height(44).backgroundColor(AppColors.BRAND_COLOR).borderRadius(12).onClick(() => this.pickRandomDiscoverWithAnimation())

            if (this.discoverPick.id >= 0) {
              Button() {
                Row({ space: 6 }) {
                  SymbolGlyph($r('sys.symbol.arrow_clockwise')).fontSize(16).fontColor([AppColors.BRAND_COLOR]);
                  Text('换一道').fontSize(15).fontColor(AppColors.BRAND_COLOR).fontWeight(FontWeight.Medium)
                }
              }
              .padding({ left: 20, right: 20 }).height(44).backgroundColor(this.currentCardBgColor).borderRadius(12).onClick(() => this.pickRandomDiscover())
            }
          }.margin({ top: 8 }).alignSelf(ItemAlign.Start)

          if (this.showRandomAnimation && this.randomAnimationNames.length > 0) {
            Column() {
              Text(this.randomAnimationNames[this.currentRandomIndex])
                .fontSize(48).fontColor(AppColors.BRAND_COLOR).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            }.width('100%').height(300).justifyContent(FlexAlign.Center).backgroundColor(this.getRandomAnimationBgColor()).borderRadius(24).margin({ top: 20 })
          } else if (!this.showRandomAnimation && this.discoverPick.id >= 0) {
            Column({ space: 8 }) {
              Text('今日推荐').fontSize(15).fontWeight(FontWeight.Bold).fontColor(this.currentTextColor).alignSelf(ItemAlign.Start).margin({ top: 8 })
              RecipeCard({
                recipe: this.discoverPick, mode: RecipeCardMode.SMALL, isFavorite: this.isRecipeFavorite(this.discoverPick.id),
                onCardClick: () => this.openDetailSheet(this.discoverPick),
                onFavoriteClick: () => this.onTapFavorite(this.discoverPick.id)
              }).opacity(this.tabOpacity)
            }.width('100%').alignItems(HorizontalAlign.Start)
          }

          // ── 猜你喜欢（Item-based 推荐，单列 Top 3，支持换卡动画）──
          Column({ space: 12 }) {
            Row() {
              Text('猜你喜欢')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.currentTextColor)
              Blank()
              Text(`${this.displayedRecommends.length} 道`)
                .fontSize(12)
                .fontColor(AppColors.BRAND_COLOR)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .backgroundColor(AppColors.BRAND_COLOR_LIGHT)
                .borderRadius(100)
                .visibility(this.displayedRecommends.length > 0 ? Visibility.Visible : Visibility.Hidden)
                .margin({ right: 8 })
              // 一键刷新全部推荐
              Column() {
                SymbolGlyph($r('sys.symbol.arrow_clockwise'))
                  .fontSize(16)
                  .fontColor([this.currentSecondaryTextColor])
              }
              .width(28).height(28)
              .borderRadius(14)
              .backgroundColor(this.currentCardBgColor)
              .justifyContent(FlexAlign.Center)
              .hitTestBehavior(HitTestMode.Block)
              .visibility(this.displayedRecommends.length > 0 ? Visibility.Visible : Visibility.Hidden)
              .onClick(() => { this.refreshAllRecommends() })
            }.width('100%').alignItems(VerticalAlign.Center)

            if (this.displayedRecommends.length === 0) {
              Row({ space: 10 }) {
                Text('🥬').fontSize(22)
                Text('收藏或浏览一些菜谱后，这里会出现专属推荐')
                  .fontSize(13).fontColor(this.currentSecondaryTextColor).layoutWeight(1)
              }
              .width('100%')
              .padding({ top: 4, bottom: 8 })
            } else {
              Column({ space: 10 }) {
                ForEach(this.displayedRecommends, (r: RecipeWithId) => {
                  RecipeCard({
                      recipe: r,
                      mode: RecipeCardMode.SMALL,
                      isFavorite: this.isRecipeFavorite(r.id),
                      onCardClick: () => this.openDetailSheet(r),
                      onFavoriteClick: () => this.onTapFavorite(r.id)
                  })
                  .width('100%')
                  // 入场：从右侧滑入 + 淡入；出场：向左滑出 + 淡出 + 轻微缩小
                  .transition(
                    TransitionEffect.asymmetric(
                      TransitionEffect.OPACITY
                        .combine(TransitionEffect.translate({ x: 56 }))
                        .animation({ duration: 360, curve: Curve.FastOutSlowIn }),
                      TransitionEffect.OPACITY
                        .combine(TransitionEffect.translate({ x: -48 }))
                        .combine(TransitionEffect.scale({ x: 0.94, y: 0.94 }))
                        .animation({ duration: 240, curve: Curve.EaseIn })
                    )
                  )
                }, (r: RecipeWithId) => `rec-${r.id}`)
              }
              .width('100%')
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 20, right: 20, top: 4, bottom: 120 })
      }.width('100%').layoutWeight(1).scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
    }.width('100%').height('100%')
  }

  @Builder
  MySectionHeader(title: string, count: number, actionLabel: string, onAction: () => void) {
    Row() {
      Row({ space: 8 }) {
        Text(title)
          .fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.currentTextColor)
        if (count > 0) {
          Text(`${count}`)
            .fontSize(11).fontColor(AppColors.BRAND_COLOR)
            .padding({ left: 7, right: 7, top: 2, bottom: 2 })
            .backgroundColor(AppColors.BRAND_COLOR_LIGHT)
            .borderRadius(100)
        }
      }
      if (actionLabel.length > 0) {
        Row({ space: 3 }) {
          Text(actionLabel).fontSize(13).fontColor(AppColors.BRAND_COLOR)
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(12).fontColor([AppColors.BRAND_COLOR])
        }.onClick(onAction)
      }
    }
    .width('100%').justifyContent(FlexAlign.SpaceBetween)
    .padding({ left: 20, right: 20, top: 24, bottom: 12 })
  }

  @Builder
  buildMyTab() {
    Stack() {
      Column().width('100%').height('100%').backgroundColor(this.getBackgroundColor())
      Scroll(this.myTabScroller) {
        Column({ space: 0 }) {

          // ── 头部：头像 + 昵称 + 双数据统计 + 设置 ──
          Row() {
            Row({ space: 14 }) {
              // 头像
              Column() {
                if (this.isAvatarImage(this.userProfile.avatar)) {
                  Image(this.userProfile.avatar)
                    .width(56).height(56).borderRadius(28).objectFit(ImageFit.Cover)
                } else {
                  Text(this.userProfile.avatar).fontSize(30)
                }
              }
              .width(56).height(56).borderRadius(28)
              .backgroundColor(this.currentBorderColor)
              .justifyContent(FlexAlign.Center).clip(true)

              // 昵称 + 统计
              Column({ space: 5 }) {
                Text(this.userProfile.nickname)
                  .fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.currentTextColor)
                Row({ space: 6 }) {
                  Text(`${this.favoriteIds.length} 收藏`)
                    .fontSize(12).fontColor(this.currentSecondaryTextColor)
                  Text('·').fontSize(12).fontColor(this.currentBorderColor)
                  Text(`${this.historyIds.length} 浏览`)
                    .fontSize(12).fontColor(this.currentSecondaryTextColor)
                  Text('·').fontSize(12).fontColor(this.currentBorderColor)
                  Text(`${this.folders.length} 收藏夹`)
                    .fontSize(12).fontColor(this.currentSecondaryTextColor)
                }
              }.alignItems(HorizontalAlign.Start)
            }.layoutWeight(1)

            // 设置入口
            Column() {
              SymbolGlyph($r('sys.symbol.gearshape')).fontSize(20).fontColor([this.currentSecondaryTextColor])
            }
            .width(40).height(40).borderRadius(20)
            .backgroundColor(this.getNavButtonBgColor())
            .backgroundBlurStyle(BlurStyle.Thin)
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              router.pushUrl({ url: 'pages/SettingsPage' }).catch((e: Error) => {
                console.error(`SettingsPage: ${e.message}`)
              })
            })
          }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 8 })

          // ── 今日饮食圆环卡片 ──
          DailyDietCircleCard({
            refreshKey:     this.dietRefreshKey,
            themeSignal:    this.dietThemeSignal,
            bgColor:        this.currentCardBgColor,
            textColor:      this.currentTextColor,
            secondaryColor: this.currentSecondaryTextColor,
            dividerColor:   this.currentBorderColor,
            isDark:         this.isEffectivelyDark(),
          }).margin({ left: 16, right: 16, top: 8 })

          // ── 今日菜单独立卡片 ──
          if (this.todayMenuRecipes.length > 0) {
            Column({ space: 0 }) {
              // 标题行
              Row() {
                Row({ space: 8 }) {
                  Text('今日菜单')
                    .fontSize(15).fontWeight(FontWeight.Bold).fontColor(this.currentTextColor)
                  Text(`${this.todayMenuIds.length}`)
                    .fontSize(11).fontColor(AppColors.BRAND_COLOR)
                    .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                    .backgroundColor(AppColors.BRAND_COLOR_LIGHT)
                    .borderRadius(100)
                }
                Text('清空')
                  .fontSize(13).fontColor(AppColors.GRAY_400)
                  .onClick(() => {
                    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
                    if (host) {
                      void CookPreferences.clearTodayMenu(host).then(() => {
                        void this.refreshTodayMenu();
                        this.showToast('今日餐桌已清空');
                      });
                    }
                  })
              }
              .width('100%').justifyContent(FlexAlign.SpaceBetween)
              .padding({ left: 16, right: 16, top: 14, bottom: 10 })

              // 菜单列表
              Column({ space: 8 }) {
                ForEach(this.todayMenuRecipes, (r: RecipeWithId) => {
                  Row() {
                    Text(r.emojis?.[0] ?? '🍽️').fontSize(22).margin({ right: 10 }).flexShrink(0)
                    Column({ space: 3 }) {
                      Text(r.name)
                        .fontSize(14).fontColor(this.currentTextColor).fontWeight(FontWeight.Medium)
                        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                      if (r.nutrition !== undefined) {
                        Text(`${r.nutrition.calories} kcal · 蛋白 ${r.nutrition.protein}g · 脂肪 ${r.nutrition.fat}g`)
                          .fontSize(11).fontColor(this.currentSecondaryTextColor)
                      }
                    }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                    if (r.nutrition !== undefined) {
                      Text(this.getRecipeNutriScore(r))
                        .fontSize(11).fontColor(this.getRecipeNutriText(r)).fontWeight(FontWeight.Bold)
                        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                        .backgroundColor(this.getRecipeNutriBg(r)).borderRadius(100)
                        .margin({ right: 8 }).flexShrink(0)
                    }
                    SymbolGlyph($r('sys.symbol.minus_circle'))
                      .fontSize(18).fontColor([AppColors.GRAY_300]).flexShrink(0)
                      .onClick(() => { void this.toggleTodayMenu(r.id); })
                  }
                  .width('100%')
                  .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                  .backgroundColor(this.currentBorderColor)
                  .borderRadius(12)
                  .alignItems(VerticalAlign.Center)
                }, (r: RecipeWithId) => `today-${r.id}`)
              }.width('100%').padding({ left: 14, right: 14, bottom: 14 })

              // 营养汇总 tip
              if (this.nutritionTip.length > 0) {
                Row({ space: 8 }) {
                  Text('💡').fontSize(14).flexShrink(0)
                  Text(this.nutritionTip)
                    .fontSize(12).fontColor(AppColors.BRAND_COLOR).layoutWeight(1).lineHeight(18)
                }
                .width('100%')
                .padding({ left: 14, right: 14, top: 10, bottom: 12 })
                .backgroundColor(AppColors.BRAND_COLOR_LIGHT)
                .borderRadius({ bottomLeft: 16, bottomRight: 16 })
              }
            }
            .width('100%')
            .backgroundColor(this.currentCardBgColor)
            .borderRadius(16)
            .shadow({ radius: 8, color: '#08000000', offsetX: 0, offsetY: 2 })
            .margin({ left: 16, right: 16, top: 10 })
            .clip(true)
          }

          Divider().color(this.currentBorderColor).margin({ left: 20, right: 20, top: 16 })

          // ── Section 1：珍藏菜肴（横向滚动餐盘）──
          this.MySectionHeader(
            '珍藏',
            this.myFavoriteRecipes.length,
            this.myFavoriteRecipes.length > 5 ? '全部' : '',
            () => {
              router.pushUrl({ url: 'pages/FavoritesPage' }).catch((e: Error) => {
                console.error(`FavoritesPage: ${e.message}`)
              })
            }
          )

          if (this.myFavoriteRecipes.length > 0) {
            Scroll() {
              Row({ space: 18 }) {
                ForEach(this.myFavoriteRecipes.slice(0, 8), (recipe: RecipeWithId) => {
                  PlateCard({
                    dishName: recipe.name,
                    emoji: recipe.emojis?.[0] ?? '🍽️',
                    isFavorite: this.isRecipeFavorite(recipe.id),
                    onPlateClick: () => this.openDetailSheet(recipe),
                    onFavoriteClick: () => this.onTapFavorite(recipe.id)
                  })
                }, (r: RecipeWithId) => `plate-${r.id}`)
              }.padding({ left: 20, right: 20, bottom: 4 })
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
            .width('100%')
          } else {
            Row({ space: 10 }) {
              Text('🍽️').fontSize(22)
              Text('在菜谱中点 ☆ 开始收藏').fontSize(14).fontColor(this.currentSecondaryTextColor)
            }
            .width('100%').padding({ left: 20, right: 20, top: 8, bottom: 16 })
          }

          Divider().color(this.currentBorderColor).margin({ left: 20, right: 20, top: 8 })

          // ── Section 2：收藏夹（2列网格）──
          Row() {
            Row({ space: 8 }) {
              Text('收藏夹')
                .fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.currentTextColor)
              if (this.folders.length > 0) {
                Text(`${this.folders.length}`)
                  .fontSize(11).fontColor(AppColors.BRAND_COLOR)
                  .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                  .backgroundColor(AppColors.BRAND_COLOR_LIGHT)
                  .borderRadius(100)
              }
            }
            Row({ space: 5 }) {
              SymbolGlyph($r('sys.symbol.plus')).fontSize(14).fontColor([AppColors.BRAND_COLOR])
              Text('新建').fontSize(13).fontColor(AppColors.BRAND_COLOR)
            }
            .onClick(() => {
              router.pushUrl({ url: 'pages/CreateFolderPage' }).catch((e: Error) => {
                console.error(`CreateFolderPage: ${e.message}`)
              })
            })
          }
          .width('100%').justifyContent(FlexAlign.SpaceBetween)
          .padding({ left: 20, right: 20, top: 24, bottom: 12 })

          if (this.folders.length === 0) {
            Row({ space: 10 }) {
              Text('📂').fontSize(22)
              Text('新建收藏夹来整理菜谱').fontSize(14).fontColor(this.currentSecondaryTextColor)
            }
            .width('100%').padding({ left: 20, right: 20, top: 4, bottom: 16 })
          } else {
            GridRow({ columns: 2, gutter: { x: 12, y: 12 } }) {
              ForEach(this.folders, (folder: FolderItem) => {
                GridCol() {
                  Column({ space: 10 }) {
                    // 封面 emoji
                    Column() {
                      Text(
                        folder.recipeIds.length > 0
                          ? (RecipeRepository.getInstance().getById(folder.recipeIds[0])?.emojis?.[0] ?? '📁')
                          : '📁'
                      ).fontSize(36)
                    }
                    .width('100%').height(88)
                    .backgroundColor(this.currentBorderColor)
                    .borderRadius(12)
                    .justifyContent(FlexAlign.Center)

                    // 文字区
                    Row() {
                      Column({ space: 2 }) {
                        Text(folder.name)
                          .fontSize(13).fontColor(this.currentTextColor).fontWeight(FontWeight.Medium)
                          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                        Text(`${folder.recipeIds.length} 道`)
                          .fontSize(11).fontColor(this.currentSecondaryTextColor)
                      }.layoutWeight(1).alignItems(HorizontalAlign.Start)

                      SymbolGlyph($r('sys.symbol.trash'))
                        .fontSize(15).fontColor([AppColors.GRAY_300])
                        .padding({ left: 8, top: 4, bottom: 4 })
                        .hitTestBehavior(HitTestMode.Block)
                        .onClick(() => {
                          this.pendingDeleteFolderId = folder.id
                          this.pendingDeleteFolderName = folder.name
                          this.deleteFolderConfirmVisible = true
                        })
                    }.width('100%')
                  }
                  .width('100%')
                  .padding(12)
                  .backgroundColor(this.currentCardBgColor)
                  .borderRadius(16)
                  // Task4: 使用 onTouch + 滑动阈值检测替换 onClick，避免 Scroll 内轻微滑动误触打开文件夹
                  .onTouch((event: TouchEvent) => {
                    if (event.type === TouchType.Down) {
                      this.folderTouchDownX = event.touches[0].x
                      this.folderTouchDownY = event.touches[0].y
                      this.folderSlopExceeded = false
                    } else if (event.type === TouchType.Move) {
                      const dx = event.touches[0].x - this.folderTouchDownX
                      const dy = event.touches[0].y - this.folderTouchDownY
                      if (dx * dx + dy * dy > 25) { // 5vp² = 25
                        this.folderSlopExceeded = true
                      }
                    } else if (event.type === TouchType.Up && !this.folderSlopExceeded) {
                      router.pushUrl({ url: 'pages/FolderDetailPage', params: { folderId: folder.id } }).catch((e: Error) => {
                        console.error(`FolderDetailPage: ${e.message}`)
                      })
                    }
                  })
                }
              }, (f: FolderItem) => `folder-${f.id}`)
            }.width('100%').padding({ left: 20, right: 20 })
          }

          Divider().color(this.currentBorderColor).margin({ left: 20, right: 20, top: 20 })

          // ── Section 3：最近浏览（横向 Chip 滚动）──
          this.MySectionHeader(
            '最近浏览',
            this.historyIds.length,
            this.historyIds.length > 0 ? '全部' : '',
            () => {
              router.pushUrl({ url: 'pages/HistoryPage' }).catch((e: Error) => {
                console.error(`HistoryPage: ${e.message}`)
              })
            }
          )

          if (this.historyIds.length > 0) {
            Scroll() {
              Row({ space: 10 }) {
                ForEach(this.historyIds.slice(0, 10), (recipeId: number) => {
                  Text(RecipeRepository.getInstance().getById(recipeId)?.name ?? '')
                    .fontSize(13)
                    .fontColor(this.currentTextColor)
                    .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                    .backgroundColor(this.currentCardBgColor)
                    .borderRadius(100)
                    .borderWidth(0.5)
                    .borderColor(this.currentBorderColor)
                    .maxLines(1)
                    .onClick(() => {
                      const r = RecipeRepository.getInstance().getById(recipeId)
                      if (r) this.openDetailSheet(r)
                    })
                }, (id: number) => `hist-chip-${id}`)
              }.padding({ left: 20, right: 20, bottom: 4 })
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
            .width('100%')
          } else {
            Row({ space: 10 }) {
              Text('🔍').fontSize(22)
              Text('浏览菜谱后这里会有记录').fontSize(14).fontColor(this.currentSecondaryTextColor)
            }
            .width('100%').padding({ left: 20, right: 20, top: 4, bottom: 8 })
          }

          Divider().color(this.currentBorderColor).margin({ left: 20, right: 20, top: 16 })

          // ── Section 4：历史足迹热力图 ──
          Column({ space: 0 }) {
            Row() {
              Text('足迹热力图')
                .fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.currentTextColor)
            }
            .width('100%').padding({ left: 20, right: 20, top: 24, bottom: 12 })

            Column() {
              HistoryHeatmap({
                datedHistory: this.datedHistoryJson,
                textColor: this.currentTextColor,
                secondaryColor: this.currentSecondaryTextColor,
                cardBgColor: this.currentCardBgColor
              })
            }.width('100%').padding({ left: 20, right: 20 })
          }.width('100%')


        }.width('100%').padding({ bottom: 120 })
      }.width('100%').height('100%').scrollBar(BarState.Off)
    }.width('100%').height('100%')
  }

  @Builder
  DetailSheetBuilder() {
    if (this.selectedRecipe) {
      Stack() {
        RecipeDetailSheet({
          recipe: this.selectedRecipe,
          selectedStuff: this.selectedStuff.concat([]),
          isFavorite: this.isRecipeFavorite(this.selectedRecipe.id),
          isTodayMenu: this.isTodayMenuItem(this.selectedRecipe.id),
          onFavoriteToggle: () => {
            if (this.selectedRecipe) {
              this.onTapFavorite(this.selectedRecipe.id);
            }
          },
          onTodayMenuToggle: () => {
            if (this.selectedRecipe) {
              void this.toggleTodayMenu(this.selectedRecipe.id);
            }
          },
          onRequestClose: () => {
            this.detailSheetVisible = false;
          }
        })

        // 文件夹选择覆盖层：在详情页内部渲染，层级天然正确
        if (this.folderPickerVisible) {
          Stack() {
            Column()
              .width('100%').height('100%')
              .backgroundColor('rgba(0,0,0,0.45)')
              .onClick(() => { this.folderPickerVisible = false })
            Column() {
              FolderPickerSheet({
                folders: this.folders,
                onAddToFolder: (folderId: string) => { void this.onAddToFolder(folderId) },
                onCreateAndAdd: (name: string) => { void this.onCreateAndAddToFolder(name) },
                onClose: () => { this.folderPickerVisible = false }
              })
            }
            .width('100%').height(480)
            .position({ x: 0, y: '100%' })
            .markAnchor({ x: 0, y: '100%' })
          }
          .width('100%').height('100%')
          .zIndex(100)
        }
      }
      .width('100%').height('100%')
    }
  }

  @Builder
  FolderPickerBuilder() {
    FolderPickerSheet({
      folders: this.folders,
      onAddToFolder: (folderId: string) => { void this.onAddToFolder(folderId) },
      onCreateAndAdd: (name: string) => { void this.onCreateAndAddToFolder(name) },
      onClose: () => { this.folderPickerVisible = false }
    })
  }

  build() {
    Stack() {
      Column() {
        // 隐藏的测试区域（长按触发收藏功能测试）
        Column() {
          if (this.mainTabIndex === 0) { this.buildCookTab(); }
          else if (this.mainTabIndex === 1) { this.buildLibraryTab(); }
          else if (this.mainTabIndex === 2) { this.buildDiscoverTab(); }
          else { this.buildMyTab(); }
        }
        .width('100%').layoutWeight(1).padding({ top: this.mainNavTopInsetVp })
        
        .opacity(this.tabOpacity)

        Column() {
          Row() {
            ForEach(this.navItems, (item: NavItem) => {
              Column({ space: 4 }) {
                SymbolGlyph(item.icon)
                  .fontSize(24)
                  .fontColor([this.mainTabIndex === item.index ? AppColors.BRAND_COLOR : this.currentSecondaryTextColor])

                Text(item.label)
                  .fontSize(10)
                  .fontColor(this.mainTabIndex === item.index ? this.currentTextColor : this.currentSecondaryTextColor)
                  .fontWeight(this.mainTabIndex === item.index ? FontWeight.Bold : FontWeight.Medium)
              }
              .layoutWeight(1).height('100%').justifyContent(FlexAlign.Center)
              .onClick(() => { if (this.mainTabIndex !== item.index) this.switchTabWithAnimation(item.index); })
            }, (item: NavItem) => `tab-${item.index}`)
          }.width('100%').height(56)

          Column().width(128).height(5).backgroundColor(this.currentBorderColor).borderRadius(10).margin({ top: 8, bottom: 8 }).alignSelf(ItemAlign.Center)
        }
        .width('100%')
        .backgroundColor(this.getNavBarBgColor())
        .backgroundBlurStyle(BlurStyle.Thin)
        .borderWidth({ top: 0.5 }).borderColor(this.getNavBarBorderColor()).expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.getBackgroundColor())

      ToastView({ message: this.toastMessage, visible: this.toastVisible })

      // 收藏成功底部提示（仅在详情页未打开时显示）
      Column() {
        FavoriteToast({
          visible: this.favoriteToastVisible,
          onAddToFolder: () => {
            this.favoriteToastVisible = false;
            this.folderPickerVisible = true;
          },
          // 动画消失后重置状态，确保底部导航不被透明遮层持续拦截
          onHide: () => { this.favoriteToastVisible = false; }
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 80 })
      .position({ x: 0, y: '100%' })
      .markAnchor({ x: 0, y: '100%' })
      .zIndex(9997)
      .hitTestBehavior(this.favoriteToastVisible ? HitTestMode.Default : HitTestMode.Transparent)

      // 非详情页收藏夹选择（详情页内触发时由 DetailSheetBuilder 内部覆盖层处理）
      if (this.folderPickerVisible && !this.detailSheetVisible) {
        Stack() {
          Column()
            .width('100%').height('100%')
            .backgroundColor('rgba(0,0,0,0.4)')
            .onClick(() => { this.folderPickerVisible = false })
          Column() {
            FolderPickerSheet({
              folders: this.folders,
              onAddToFolder: (folderId: string) => { void this.onAddToFolder(folderId) },
              onCreateAndAdd: (name: string) => { void this.onCreateAndAddToFolder(name) },
              onClose: () => { this.folderPickerVisible = false }
            })
          }
          .width('100%').height(480)
          .position({ x: 0, y: '100%' })
          .markAnchor({ x: 0, y: '100%' })
        }
        .width('100%').height('100%')
        .zIndex(9999)
      }

      // 清空搜索历史确认弹窗
      if (this.clearHistoryConfirmVisible) {
        Stack() {
          Column()
            .width('100%').height('100%')
            .backgroundColor('rgba(0,0,0,0.5)')
            .onClick(() => { this.clearHistoryConfirmVisible = false; })
          Column({ space: 0 }) {
            Text('清空搜索历史')
              .fontSize(17).fontWeight(FontWeight.Bold).fontColor('#1F2937')
              .padding({ top: 24, bottom: 8 })
            Text('确定清空所有搜索历史？')
              .fontSize(14).fontColor('#6B7280').padding({ left: 24, right: 24, bottom: 24 })
            Divider().color('#F3F4F6').strokeWidth(1)
            Row() {
              Text('取消').fontSize(16).fontColor('#6B7280').layoutWeight(1).textAlign(TextAlign.Center)
                .padding({ top: 16, bottom: 16 })
                .onClick(() => { this.clearHistoryConfirmVisible = false; })
              Divider().vertical(true).height(48).color('#F3F4F6').strokeWidth(1)
              Text('清空').fontSize(16).fontColor('#EF4444').fontWeight(FontWeight.Medium).layoutWeight(1).textAlign(TextAlign.Center)
                .padding({ top: 16, bottom: 16 })
                .onClick(() => { void this.clearSearchHistory(); })
            }.width('100%')
          }
          .width('80%').backgroundColor(Color.White).borderRadius(16)
        }
        .width('100%').height('100%').zIndex(10000)
      }

      // 删除收藏夹确认弹窗
      if (this.deleteFolderConfirmVisible) {
        Stack() {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0,0,0,0.5)')
            .onClick(() => {
              this.deleteFolderConfirmVisible = false;
            })

          Column({ space: 0 }) {
            Text('删除收藏夹')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1F2937')
              .padding({ top: 24, bottom: 8 })

            Text(`确定删除「${this.pendingDeleteFolderName}」？\n收藏夹内的菜谱将全部取消收藏。`)
              .fontSize(14)
              .fontColor('#6B7280')
              .textAlign(TextAlign.Center)
              .padding({ left: 24, right: 24, bottom: 24 })

            Divider().color('#F3F4F6').strokeWidth(1)

            Row() {
              Text('取消')
                .fontSize(16)
                .fontColor('#6B7280')
                .layoutWeight(1)
                .textAlign(TextAlign.Center)
                .padding({ top: 16, bottom: 16 })
                .onClick(() => {
                  this.deleteFolderConfirmVisible = false;
                })

              Divider().vertical(true).height(48).color('#F3F4F6').strokeWidth(1)

              Text('删除')
                .fontSize(16)
                .fontColor('#EF4444')
                .fontWeight(FontWeight.Medium)
                .layoutWeight(1)
                .textAlign(TextAlign.Center)
                .padding({ top: 16, bottom: 16 })
                .onClick(() => {
                  void this.onConfirmDeleteFolder();
                })
            }.width('100%')
          }
          .width('80%')
          .backgroundColor(Color.White)
          .borderRadius(16)
        }
        .width('100%')
        .height('100%')
        .zIndex(10000)
      }

    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.detailSheetVisible, this.DetailSheetBuilder(), {
      height: SheetSize.LARGE,
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      dragBar: false,
      backgroundColor: Color.Transparent,
      showClose: false,
      preferType: SheetType.BOTTOM
    })
  }
}
