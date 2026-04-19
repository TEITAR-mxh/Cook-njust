import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { meatItems, stapleItems, toolItems, vegetableItems } from '../data/foodCatalog';
import { RecipeRepository } from '../data/RecipeRepository';
import type { RecipeWithId, SearchMode, StuffItem } from '../model/recipe';
import { RecipeSearchService } from '../service/RecipeSearchService';
import { CookPreferences } from '../store/CookPreferences';
import { getSystemSafeTopVp } from '../util/StatusBarInset';

@Entry
@Component
struct Index {
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
  /** 发现 Tab：随机选中的菜谱；id 为 -1 表示未选 */
  @State discoverPick: RecipeWithId = { id: -1, name: '', stuff: [], tools: [], steps: [] }
  /** 浏览历史：id 从新到旧，与 Preferences 一致 */
  @State historyIds: number[] = []
  /** 收藏：id 顺序为最近收藏在前 */
  @State favoriteIds: number[] = []
  /** 主界面顶栏：状态栏/挖孔下内边距（vp） */
  @State mainNavTopInsetVp: number = 48

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

  /** 从 Preferences 同步收藏 id，并剔除当前菜谱库里不存在的 id */
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
    void CookPreferences.toggleFavoriteId(host, recipeId).then(() => {
      void this.refreshFavorites();
    });
  }

  /** 从 Preferences 同步历史 id，并剔除当前菜谱库里不存在的 id */
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
    const all = RecipeRepository.getInstance().getAll();
    this.libraryHits = RecipeSearchService.filterLibraryByName(all, this.libraryKeyword);
  }

  private emptyDiscoverPick(): RecipeWithId {
    const r: RecipeWithId = { id: -1, name: '', stuff: [], tools: [], steps: [] };
    return r;
  }

  /**
   * 发现 Tab 写入 @State 必须用新对象引用，否则与仓库同一引用时「换一道」不触发刷新。
   */
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

  /** 从全库中随机选一道菜谱 */
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
    this.selectedStuff = [];
    this.curTool = '';
    this.runSearch();
    void this.persistCookIfNeeded();
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

  private modeButtonBg(mode: SearchMode): string {
    return this.searchMode === mode ? '#C8E6C9' : '#EEEEEE';
  }

  private tabLabelColor(idx: number): string {
    return this.mainTabIndex === idx ? '#18A058' : '#666666';
  }

  private tabFontWeight(idx: number): FontWeight {
    return this.mainTabIndex === idx ? FontWeight.Medium : FontWeight.Normal;
  }

  @Builder
  sectionTitle(title: string) {
    Text(title)
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .margin({ top: 8, bottom: 6 })
      .alignSelf(ItemAlign.Start)
  }

  @Builder
  recipeHitRow(item: RecipeWithId) {
    Row() {
      Row() {
        Text(item.name)
          .fontSize(15)
          .layoutWeight(1)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor(Color.Black)
        Text((item.difficulty !== undefined && item.difficulty.length > 0) ? item.difficulty : ' ')
          .fontSize(12)
          .fontColor('#888888')
          .width(40)
      }
      .layoutWeight(1)

      if (this.keepLocalData) {
        Text(this.isRecipeFavorite(item.id) ? '★' : '☆')
          .fontSize(22)
          .fontColor(this.isRecipeFavorite(item.id) ? '#FFB020' : '#CCCCCC')
          .padding({ left: 8, right: 4 })
          .onClick(() => {
            this.onTapFavorite(item.id);
          })
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#F9F9F9')
    .borderRadius(8)
    .margin({ bottom: 8 })
  }

  /**
   * 发现 Tab 专用：禁止写 recipeHitRow(this.discoverPick)。
   * 对象作 @Builder 入参时 ArkUI 常无法对 @State 整对象替换建立依赖，界面不刷新。
   */
  @Builder
  discoverPickHitRow() {
    Row() {
      Row() {
        Text(this.discoverPick.name)
          .fontSize(15)
          .layoutWeight(1)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor(Color.Black)
        Text((this.discoverPick.difficulty !== undefined && this.discoverPick.difficulty.length > 0) ?
          this.discoverPick.difficulty : ' ')
          .fontSize(12)
          .fontColor('#888888')
          .width(40)
      }
      .layoutWeight(1)

      if (this.keepLocalData && this.discoverPick.id >= 0) {
        Text(this.isRecipeFavorite(this.discoverPick.id) ? '★' : '☆')
          .fontSize(22)
          .fontColor(this.isRecipeFavorite(this.discoverPick.id) ? '#FFB020' : '#CCCCCC')
          .padding({ left: 8, right: 4 })
          .onClick(() => {
            this.onTapFavorite(this.discoverPick.id);
          })
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#F9F9F9')
    .borderRadius(8)
    .margin({ bottom: 8 })
  }

  @Builder
  chipWrap(items: StuffItem[], isTool: boolean) {
    Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
      ForEach(items, (item: StuffItem) => {
        Text(this.chipLabel(item))
          .fontSize(13)
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .margin({ right: 8, bottom: 8 })
          .backgroundColor(isTool ?
            (this.curTool === item.name ? '#C8E6C9' : '#EFEFEF') :
            (this.selectedStuff.includes(item.name) ? '#C8E6C9' : '#EFEFEF'))
          .borderRadius(16)
          .onClick(() => {
            if (isTool) {
              this.toggleTool(item.name);
            } else {
              this.toggleStuff(item.name);
            }
          })
      }, (item: StuffItem) => item.name)
    }
    .width('100%')
  }

  @Builder
  buildCookTab() {
    Column() {
      Scroll() {
        Column({ space: 8 }) {
          Row() {
            Text('好的，今天我们来做菜！')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .layoutWeight(1)
            Text('清空')
              .fontSize(14)
              .fontColor('#18A058')
              .onClick(() => {
                this.resetSelection();
              })
          }
          .width('100%')

          Text(`${this.status} · 全库 ${this.recipeCount} 条`)
            .fontSize(12)
            .fontColor('#888888')

          if (this.errHint.length > 0) {
            Text(this.errHint)
              .fontSize(12)
              .fontColor(Color.Red)
          }

          Text('匹配模式')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .alignSelf(ItemAlign.Start)
            .margin({ top: 4 })

          Row({ space: 8 }) {
            Text('模糊')
              .fontSize(13)
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .backgroundColor(this.modeButtonBg('loose'))
              .borderRadius(8)
              .onClick(() => {
                this.applySearchMode('loose');
              })
            Text('严格')
              .fontSize(13)
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .backgroundColor(this.modeButtonBg('strict'))
              .borderRadius(8)
              .onClick(() => {
                this.applySearchMode('strict');
              })
            Text('生存')
              .fontSize(13)
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .backgroundColor(this.modeButtonBg('survival'))
              .borderRadius(8)
              .onClick(() => {
                this.applySearchMode('survival');
              })
          }

          TextInput({ placeholder: '搜索菜名', text: this.keyword })
            .width('100%')
            .height(40)
            .onChange((v: string) => {
              this.keyword = v;
              this.runSearch();
            })
            .margin({ top: 4 })

          this.sectionTitle('素菜');
          this.chipWrap(vegetableItems, false);

          this.sectionTitle('荤菜');
          this.chipWrap(meatItems, false);

          this.sectionTitle('主食');
          this.chipWrap(stapleItems, false);

          this.sectionTitle('厨具');
          this.chipWrap(toolItems, true);

          Text(`匹配结果 ${this.searchHits.length} 条`)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .margin({ top: 12, bottom: 8 })
            .alignSelf(ItemAlign.Start)

          ForEach(this.searchHits, (item: RecipeWithId) => {
            this.recipeHitRow(item);
          }, (item: RecipeWithId) => item.id.toString())
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 16, right: 16, bottom: 24 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.TopStart)
    }
    .width('100%')
    .height('100%')
    .padding({ top: 8 })
  }

  @Builder
  buildLibraryTab() {
    Column() {
      Scroll() {
        Column({ space: 8 }) {
          Text('菜谱')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .alignSelf(ItemAlign.Start)

          Text(`${this.status} · 全库 ${this.recipeCount} 条`)
            .fontSize(12)
            .fontColor('#888888')
            .alignSelf(ItemAlign.Start)

          if (this.errHint.length > 0) {
            Text(this.errHint)
              .fontSize(12)
              .fontColor(Color.Red)
              .alignSelf(ItemAlign.Start)
          }

          TextInput({ placeholder: '搜索菜名', text: this.libraryKeyword })
            .width('100%')
            .height(40)
            .onChange((v: string) => {
              this.libraryKeyword = v;
              this.runLibrarySearch();
            })
            .margin({ top: 4 })

          Text(`列表 ${this.libraryHits.length} 条`)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .margin({ top: 12, bottom: 8 })
            .alignSelf(ItemAlign.Start)

          if (this.libraryHits.length === 0) {
            Text(this.recipeCount === 0 ? '暂无菜谱数据' : '暂无匹配的菜名')
              .fontSize(14)
              .fontColor('#888888')
              .alignSelf(ItemAlign.Start)
          } else {
            ForEach(this.libraryHits, (item: RecipeWithId) => {
              this.recipeHitRow(item);
            }, (item: RecipeWithId) => item.id.toString())
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 16, right: 16, bottom: 24 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.TopStart)
    }
    .width('100%')
    .height('100%')
    .padding({ top: 8 })
  }

  @Builder
  buildDiscoverTab() {
    Column() {
      Scroll() {
        Column({ space: 12 }) {
          Text('发现')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .alignSelf(ItemAlign.Start)

          Text('不知道吃什么？随机从全库挑一道菜谱。')
            .fontSize(14)
            .fontColor('#888888')
            .alignSelf(ItemAlign.Start)

          if (this.errHint.length > 0) {
            Text(this.errHint)
              .fontSize(12)
              .fontColor(Color.Red)
              .alignSelf(ItemAlign.Start)
          }

          Row({ space: 12 }) {
            Text('随机一道')
              .fontSize(15)
              .fontColor(Color.White)
              .padding({ left: 20, right: 20, top: 10, bottom: 10 })
              .backgroundColor('#18A058')
              .borderRadius(8)
              .onClick(() => {
                this.pickRandomDiscover();
              })

            if (this.discoverPick.id >= 0) {
              Text('换一道')
                .fontSize(15)
                .fontColor('#18A058')
                .padding({ left: 20, right: 20, top: 10, bottom: 10 })
                .backgroundColor('#E8F5E9')
                .borderRadius(8)
                .onClick(() => {
                  this.pickRandomDiscover();
                })
            }
          }
          .margin({ top: 8 })
          .alignSelf(ItemAlign.Start)

          if (this.recipeCount === 0) {
            Text('暂无菜谱数据')
              .fontSize(14)
              .fontColor('#888888')
              .alignSelf(ItemAlign.Start)
              .margin({ top: 16 })
          } else if (this.discoverPick.id < 0) {
            Text('点击「随机一道」开始')
              .fontSize(14)
              .fontColor('#888888')
              .alignSelf(ItemAlign.Start)
              .margin({ top: 16 })
          } else {
            Column({ space: 8 }) {
              Text('今日推荐')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .alignSelf(ItemAlign.Start)
                .margin({ top: 8 })

              this.discoverPickHitRow();
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 16, right: 16, bottom: 24 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.TopStart)
    }
    .width('100%')
    .height('100%')
    .padding({ top: 8 })
  }

  @Builder
  buildMyTab() {
    Column() {
      Scroll() {
        Column({ space: 16 }) {
          Text('我的')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .alignSelf(ItemAlign.Start)

          Row({ space: 12 }) {
            Text('保留本地选料等数据')
              .fontSize(16)
              .layoutWeight(1)

            Toggle({ type: ToggleType.Switch, isOn: this.keepLocalData })
              .onChange((isOn: boolean) => {
                void this.onKeepLocalChange(isOn);
              })
          }
          .width('100%')

          Text('数据')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#666666')
            .alignSelf(ItemAlign.Start)
            .margin({ top: 4 })

          Row() {
            Column({ space: 6 }) {
              Text('浏览历史')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
              Text(this.keepLocalData ? `共 ${this.historyIds.length} 条` : '关闭本地数据时不记录')
                .fontSize(12)
                .fontColor('#888888')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Text('›')
              .fontSize(22)
              .fontColor('#CCCCCC')
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#F9F9F9')
          .borderRadius(10)
          .onClick(() => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/HistoryPage' }).catch(() => {
              console.error('router HistoryPage failed');
            });
          })

          Row() {
            Column({ space: 6 }) {
              Text('我的收藏')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
              Text(this.keepLocalData ? `共 ${this.favoriteIds.length} 条` : '需开启本地数据')
                .fontSize(12)
                .fontColor('#888888')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Text('›')
              .fontSize(22)
              .fontColor('#CCCCCC')
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#F9F9F9')
          .borderRadius(10)
          .onClick(() => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/FavoritesPage' }).catch(() => {
              console.error('router FavoritesPage failed');
            });
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 20, right: 20, top: 16, bottom: 24 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.TopStart)
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Column() {
      Column() {
        Row() {
          Text('今天来做菜')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.Black)
            .layoutWeight(1)
            .maxLines(1)
            .textAlign(TextAlign.Center)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .height(48)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding({ top: this.mainNavTopInsetVp })
      .backgroundColor('#F5F5F5')
      .borderWidth({ bottom: 1 })
      .borderColor('#E8E8E8')

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

      Row() {
        Column({ space: 4 }) {
          Text('做菜')
            .fontSize(12)
            .fontColor(this.tabLabelColor(0))
            .fontWeight(this.tabFontWeight(0))
        }
        .layoutWeight(1)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.mainTabIndex = 0;
        })

        Column({ space: 4 }) {
          Text('菜谱')
            .fontSize(12)
            .fontColor(this.tabLabelColor(1))
            .fontWeight(this.tabFontWeight(1))
        }
        .layoutWeight(1)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.mainTabIndex = 1;
        })

        Column({ space: 4 }) {
          Text('发现')
            .fontSize(12)
            .fontColor(this.tabLabelColor(2))
            .fontWeight(this.tabFontWeight(2))
        }
        .layoutWeight(1)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.mainTabIndex = 2;
        })

        Column({ space: 4 }) {
          Text('我的')
            .fontSize(12)
            .fontColor(this.tabLabelColor(3))
            .fontWeight(this.tabFontWeight(3))
        }
        .layoutWeight(1)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.mainTabIndex = 3;
          void this.refreshHistory();
          void this.refreshFavorites();
        })
      }
      .width('100%')
      .height(52)
      .backgroundColor('#F5F5F5')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}
